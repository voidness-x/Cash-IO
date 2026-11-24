import 'dart:convert';
import 'dart:io' show Directory, File;
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../sync/e2ee_packager.dart';

class ReceiptVaultService {
  static final ReceiptVaultService instance = ReceiptVaultService._init();
  final ImagePicker _picker = ImagePicker();

  /// Maximum allowed raw receipt payload size (10 MiB) to prevent memory exhaustion DoS.
  static const int maxReceiptSizeBytes = 10 * 1024 * 1024;

  /// Strict allowlist pattern preventing CWE-22 path traversal on receipt filenames.
  static final RegExp _safeFilenamePattern = RegExp(r'^receipt_[A-Za-z0-9_-]+\.bin$');

  static int _receiptCounter = 0;

  // In-memory encrypted store for Flutter Web environment
  final Map<String, Uint8List> _webMediaVault = {};

  ReceiptVaultService._init();

  /// Validates that a receipt filename cannot escape the sandboxed `vault_media` directory.
  static bool isSafeReceiptFilename(String filename) {
    if (filename.isEmpty || filename.length > 128) return false;
    if (filename.contains('..') || filename.contains('/') || filename.contains('\\')) {
      return false;
    }
    return _safeFilenamePattern.hasMatch(filename) && p.basename(filename) == filename;
  }

  Future<Directory?> _getMediaDir() async {
    if (kIsWeb) return null;
    final docs = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(p.join(docs.path, 'vault_media'));
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }
    return mediaDir;
  }

  /// Encrypts raw image bytes (e.g. from camera, picker, or tests) and saves as opaque .bin file.
  Future<String?> saveAndEncryptRawBytes({
    required Uint8List rawBytes,
    required String profileId,
  }) async {
    if (profileId.trim().isEmpty) return null;
    if (rawBytes.isEmpty || rawBytes.length > maxReceiptSizeBytes) {
      return null;
    }

    try {
      // 1. Lossless standard Base64 encoding
      final base64String = base64Encode(rawBytes);

      // 2. Encrypt with authenticated envelope and HMAC-SHA256 tag
      final encryptedBytes = E2eePackager.instance.encryptPayload(
        plaintextJson: base64String,
        vaultKeyHash: 'key_$profileId',
      );

      _receiptCounter++;
      final filename = 'receipt_${DateTime.now().microsecondsSinceEpoch}_$_receiptCounter.bin';

      if (kIsWeb) {
        _webMediaVault[filename] = encryptedBytes;
        return filename;
      } else {
        final mediaDir = await _getMediaDir();
        if (mediaDir == null) return null;
        final file = File(p.join(mediaDir.path, filename));
        await file.writeAsBytes(encryptedBytes);
        return filename;
      }
    } catch (e) {
      debugPrint('ReceiptVaultService error saving receipt: $e');
      return null;
    }
  }

  /// Captures or selects a receipt, applies WebP/JPEG compression (max 1280px, 75% quality),
  /// and encrypts it locally as an opaque .bin file.
  Future<String?> captureAndEncryptReceipt({
    required ImageSource source,
    required String profileId,
  }) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 75, // WebP/JPEG target ~150-250KB per security architecture
      );

      if (photo == null) return null;

      final rawBytes = await photo.readAsBytes();
      return await saveAndEncryptRawBytes(rawBytes: rawBytes, profileId: profileId);
    } catch (e) {
      debugPrint('ReceiptVaultService error capturing receipt: $e');
      return null;
    }
  }

  /// Decrypts the receipt in memory for display without saving unencrypted bytes to disk
  Future<Uint8List?> decryptReceiptBytes({
    required String filename,
    required String profileId,
  }) async {
    if (!isSafeReceiptFilename(filename) || profileId.trim().isEmpty) {
      return null;
    }

    try {
      Uint8List? encryptedBytes;

      if (kIsWeb) {
        encryptedBytes = _webMediaVault[filename];
      } else {
        final mediaDir = await _getMediaDir();
        if (mediaDir == null) return null;
        final file = File(p.join(mediaDir.path, filename));
        if (!await file.exists()) return null;
        encryptedBytes = await file.readAsBytes();
      }

      if (encryptedBytes == null) return null;

      final decryptedBase64 = E2eePackager.instance.decryptPayload(
        encryptedData: encryptedBytes,
        vaultKeyHash: 'key_$profileId',
      );

      if (decryptedBase64 == null) return null;

      // Decode Base64 back to pristine binary image buffer
      return base64Decode(decryptedBase64);
    } catch (e) {
      debugPrint('ReceiptVaultService error decrypting receipt: $e');
      return null;
    }
  }

  /// Securely deletes the encrypted receipt from local storage
  Future<void> deleteReceipt(String filename) async {
    if (!isSafeReceiptFilename(filename)) return;
    try {
      if (kIsWeb) {
        _webMediaVault.remove(filename);
      } else {
        final mediaDir = await _getMediaDir();
        if (mediaDir == null) return;
        final file = File(p.join(mediaDir.path, filename));
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint('ReceiptVaultService error deleting receipt: $e');
    }
  }

  /// Checks if an encrypted receipt file exists
  Future<bool> hasReceipt(String filename) async {
    if (!isSafeReceiptFilename(filename)) return false;
    if (kIsWeb) {
      return _webMediaVault.containsKey(filename);
    } else {
      try {
        final mediaDir = await _getMediaDir();
        if (mediaDir == null) return false;
        final file = File(p.join(mediaDir.path, filename));
        return await file.exists();
      } catch (_) {
        return false;
      }
    }
  }
}
