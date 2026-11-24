import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cash_io/core/media/receipt_vault_service.dart';
import 'package:cash_io/core/security/clipboard_sanitizer.dart';
import 'package:cash_io/core/security/app_privacy_shield.dart';
import 'package:cash_io/core/sync/crdt_sync_engine.dart';
import 'package:cash_io/core/sync/e2ee_packager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return '.';
      },
    );
  });

  // Mock clipboard storage
  String? mockClipboardText;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall methodCall) async {
      if (methodCall.method == 'Clipboard.setData') {
        final args = methodCall.arguments as Map<dynamic, dynamic>?;
        mockClipboardText = args?['text'] as String?;
        return null;
      } else if (methodCall.method == 'Clipboard.getData') {
        return {'text': mockClipboardText};
      }
      return null;
    },
  );

  tearDown(() {
    ClipboardSanitizer.cancelTracking();
    mockClipboardText = null;
  });

  group('ReceiptVaultService E2EE & Lossless Image Tests', () {
    test('Encrypts and decrypts binary image buffer losslessly without corruption', () async {
      final service = ReceiptVaultService.instance;
      // Synthetic JPEG-like binary header and payload with byte values across 0..255
      final rawImage = Uint8List.fromList([
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
        120, 130, 140, 200, 250, 255, 0, 1, 50, 99, 127, 128, 255, 0xD9,
      ]);

      final filename = await service.saveAndEncryptRawBytes(
        rawBytes: rawImage,
        profileId: 'test_vault_profile',
      );

      expect(filename, isNotNull);
      expect(filename!.endsWith('.bin'), isTrue);

      // Decrypt in memory
      final decrypted = await service.decryptReceiptBytes(
        filename: filename,
        profileId: 'test_vault_profile',
      );

      expect(decrypted, isNotNull);
      expect(decrypted!.length, rawImage.length);
      expect(decrypted, equals(rawImage));

      // Attempt decrypt with incorrect profile vault key
      final wrongKeyDecrypted = await service.decryptReceiptBytes(
        filename: filename,
        profileId: 'wrong_profile_id',
      );
      expect(wrongKeyDecrypted, isNull);

      // Delete receipt
      await service.deleteReceipt(filename);
      final existsAfterDelete = await service.hasReceipt(filename);
      expect(existsAfterDelete, isFalse);
    });
  });

  group('ClipboardSanitizer Security Tests', () {
    test('Copies sensitive data to clipboard and auto-sanitizes after timeout', () async {
      const sensitiveMnemonic = 'apple banana cherry desert energy forest grape honey';
      bool wasWiped = false;

      await ClipboardSanitizer.copySensitive(
        text: sensitiveMnemonic,
        timeout: const Duration(milliseconds: 50),
        onAutoWiped: () => wasWiped = true,
      );

      expect(mockClipboardText, sensitiveMnemonic);
      expect(ClipboardSanitizer.isTracking, isTrue);

      // Wait for auto-wipe timer
      await Future.delayed(const Duration(milliseconds: 80));

      expect(mockClipboardText, '');
      expect(wasWiped, isTrue);
      expect(ClipboardSanitizer.isTracking, isFalse);
    });

    test('wipeImmediately zeroizes clipboard instantly', () async {
      const secret = 'super_secret_pin';
      await ClipboardSanitizer.copySensitive(text: secret);
      expect(mockClipboardText, secret);

      await ClipboardSanitizer.wipeImmediately();
      expect(mockClipboardText, '');
      expect(ClipboardSanitizer.isTracking, isFalse);
    });
  });

  group('AppPrivacyShield Widget Tests', () {
    testWidgets('Shield becomes visible on inactive/paused and dismisses on resumed', (tester) async {
      final key = GlobalKey<AppPrivacyShieldState>();

      await tester.pumpWidget(
        MaterialApp(
          home: AppPrivacyShield(
            key: key,
            child: const Scaffold(body: Text('Protected Bank Balance: \$50,000')),
          ),
        ),
      );

      expect(find.text('Protected Bank Balance: \$50,000'), findsOneWidget);
      expect(find.text('AIR-GAPPED PRIVACY SHIELD'), findsNothing);

      // Simulate entering OS App Switcher (inactive)
      key.currentState?.didChangeAppLifecycleState(AppLifecycleState.inactive);
      await tester.pump();

      expect(find.text('AIR-GAPPED PRIVACY SHIELD'), findsOneWidget);
      expect(key.currentState?.isShieldVisible, isTrue);

      // Simulate returning to app (resumed)
      key.currentState?.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();

      expect(find.text('AIR-GAPPED PRIVACY SHIELD'), findsNothing);
      expect(key.currentState?.isShieldVisible, isFalse);
    });
  });

  group('CRDT Sync Engine Deterministic Tie-Breaker Tests', () {
    test('Higher Lamport clock wins concurrent conflict', () {
      final engine = CrdtSyncEngine.instance;
      engine.initialize('device_alpha', 10);

      final localEvents = [
        {
          'event_id': 'evt_local_1',
          'profile_id': 'p1',
          'device_id': 'device_alpha',
          'lamport_clock': 10,
          'entity_type': 'account',
          'entity_id': 'acc_wallet',
          'action': 'update',
          'payload_json': jsonEncode({'balance_cents': 5000}),
        }
      ];

      final remoteEvents = [
        {
          'event_id': 'evt_remote_1',
          'profile_id': 'p1',
          'device_id': 'device_beta',
          'lamport_clock': 12, // Higher clock
          'entity_type': 'account',
          'entity_id': 'acc_wallet',
          'action': 'update',
          'payload_json': jsonEncode({'balance_cents': 6000}),
        }
      ];

      final auditLogs = engine.mergeRemoteEvents(localEvents, remoteEvents);
      expect(auditLogs.length, 1);
      expect(auditLogs.first.resolution.contains('Remote update applied'), isTrue);
    });

    test('Identical clock uses deterministic device ID lexicographical tie-breaker', () {
      final engine = CrdtSyncEngine.instance;
      engine.initialize('device_b', 5);

      final localEvents = [
        {
          'event_id': 'evt_1',
          'profile_id': 'p1',
          'device_id': 'device_b',
          'lamport_clock': 5,
          'entity_type': 'envelope',
          'entity_id': 'env_food',
          'action': 'update',
          'payload_json': jsonEncode({'assigned_cents': 100}),
        }
      ];

      // Remote device_a has lower alphanumeric sorting than device_b
      final remoteEventsLower = [
        {
          'event_id': 'evt_2',
          'profile_id': 'p1',
          'device_id': 'device_a',
          'lamport_clock': 5,
          'entity_type': 'envelope',
          'entity_id': 'env_food',
          'action': 'update',
          'payload_json': jsonEncode({'assigned_cents': 120}),
        }
      ];

      final logs = engine.mergeRemoteEvents(localEvents, remoteEventsLower);
      expect(logs.length, 1);
      expect(logs.first.resolution.contains('Local update retained'), isTrue);
    });
  });

  group('E2EE Packager Security & Tamper Detection Tests', () {
    test('Detects ciphertext bit-flip tampering via HMAC tag verification', () {
      final packager = E2eePackager.instance;
      const plaintext = '{"type":"transaction","amount_cents":100000}';
      const keyHash = 'profile_vault_secret_hash';

      final encrypted = packager.encryptPayload(
        plaintextJson: plaintext,
        vaultKeyHash: keyHash,
      );

      // Decrypts successfully
      final decrypted = packager.decryptPayload(
        encryptedData: encrypted,
        vaultKeyHash: keyHash,
      );
      expect(decrypted, plaintext);

      // Tamper single byte in the ciphertext payload
      final tampered = Uint8List.fromList(encrypted);
      tampered[15] ^= 0xFF; // Bit flip

      final tamperedResult = packager.decryptPayload(
        encryptedData: tampered,
        vaultKeyHash: keyHash,
      );
      expect(tamperedResult, isNull); // HMAC tag check fails!
    });
  });
}
