import 'package:flutter_test/flutter_test.dart';
import 'package:cash_io/core/models/finance_models.dart';
import 'package:cash_io/core/storage/vault_repository.dart';
import 'package:cash_io/core/services/update_receiver_service.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() async {
    UpdateReceiverService.instance.resetVersionForTesting(version: '3.0.0', build: 300);
    await VaultRepository.instance.initializeProfile(
      name: 'Update Receiver Test',
      currency: 'USD',
      onlineFx: false,
    );
  });

  group('Phase 6D: Automated Update Receiver & Emergency Rollback Engine Tests', () {
    test('checkForUpdates detects newer GitHub Releases manifest version', () async {
      final service = UpdateReceiverService.instance;
      expect(service.currentVersion, '3.0.0');

      final update = await service.checkForUpdates();
      expect(update, isNotNull);
      expect(update!.version, '3.2.0');
      expect(update.buildNumber, 320);
      expect(update.downloadUrl.startsWith('https://github.com/voidness-x/Cash-IO/'), isTrue);
      expect(update.changelog.isNotEmpty, isTrue);
    });

    test('createEmergencyPreUpdateBackup captures complete vault state with SHA-256 checksum', () async {
      final repo = VaultRepository.instance;
      final service = UpdateReceiverService.instance;

      final asset = repo.accounts.firstWhere((a) => a.type == AccountType.asset);
      final expense = repo.accounts.firstWhere((a) => a.type == AccountType.expense);

      await repo.recordTransaction(
        description: 'Grocery Run',
        postings: [
          PostingModel(accountId: expense.id, amountCents: 4500),
          PostingModel(accountId: asset.id, amountCents: -4500),
        ],
      );

      final snapshot = await service.createEmergencyPreUpdateBackup(
        targetVersion: '3.2.0',
        note: 'Pre-v3.2.0 test snapshot',
      );

      expect(snapshot.fromVersion, '3.0.0');
      expect(snapshot.fromBuild, 300);
      expect(snapshot.targetVersion, '3.2.0');
      expect(snapshot.checksumSha256.length, 64); // SHA-256 hex string
      expect(snapshot.rawVaultData['transactions'], isNotEmpty);
      expect(service.availableRollbackSnapshots.length, 1);
    });

    test('applyUpdate creates snapshot and successfully advances version on healthy ledger', () async {
      final service = UpdateReceiverService.instance;

      const manifest = AppUpdateManifest(
        version: '3.2.0',
        buildNumber: 320,
        releaseDate: '2026-11-24',
        title: 'V3.2 Release',
        changelog: ['Security enhancements'],
        sha256Checksum: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        downloadUrl: 'https://github.com/voidness-x/Cash-IO/releases/download/v3.2.0/cashio-v3.2.0-bundle.enc',
      );

      final result = await service.applyUpdate(manifest);

      expect(result.success, isTrue);
      expect(result.wasRolledBack, isFalse);
      expect(service.currentVersion, '3.2.0');
      expect(service.currentBuild, 320);
      expect(service.availableRollbackSnapshots.isNotEmpty, isTrue);
    });

    test('corrupt update triggers automated instant rollback and preserves previous version and user transactions', () async {
      final repo = VaultRepository.instance;
      final service = UpdateReceiverService.instance;

      final asset = repo.accounts.firstWhere((a) => a.type == AccountType.asset);
      final expense = repo.accounts.firstWhere((a) => a.type == AccountType.expense);
      await repo.recordTransaction(
        description: 'Pre-Update Critical Ledger Entry',
        postings: [
          PostingModel(accountId: expense.id, amountCents: 9900),
          PostingModel(accountId: asset.id, amountCents: -9900),
        ],
      );

      expect(service.currentVersion, '3.0.0');

      const manifest = AppUpdateManifest(
        version: '3.3.0-broken',
        buildNumber: 330,
        releaseDate: '2026-11-24',
        title: 'Broken Release',
        changelog: ['Buggy migration'],
        sha256Checksum: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        downloadUrl: 'https://github.com/voidness-x/Cash-IO/releases/download/v3.3.0/broken.enc',
      );

      // Apply corrupt update with simulation flag
      final result = await service.applyUpdate(manifest, simulateCorruptUpdate: true);

      // Must have failed and rolled back automatically with zero data loss
      expect(result.success, isFalse);
      expect(result.wasRolledBack, isTrue);
      expect(service.currentVersion, '3.0.0');
      expect(service.currentBuild, 300);
      expect(repo.transactions.length, 1);
      expect(repo.transactions.first.description, 'Pre-Update Critical Ledger Entry');
      expect(result.message.contains('breached'), isTrue);
    });

    test('manual rollback restores previous version, build, and ledger state from snapshot archive', () async {
      final repo = VaultRepository.instance;
      final service = UpdateReceiverService.instance;

      final asset = repo.accounts.firstWhere((a) => a.type == AccountType.asset);
      final expense = repo.accounts.firstWhere((a) => a.type == AccountType.expense);
      await repo.recordTransaction(
        description: 'Original v3.0 Entry',
        postings: [
          PostingModel(accountId: expense.id, amountCents: 2500),
          PostingModel(accountId: asset.id, amountCents: -2500),
        ],
      );

      // 1. Advance to 3.2.0
      await service.applyUpdate(UpdateReceiverService.latestAvailableUpdate);
      expect(service.currentVersion, '3.2.0');
      expect(service.currentBuild, 320);

      // Record post-update entry that should be rolled back
      await repo.recordTransaction(
        description: 'Post-v3.2 Experimental Entry',
        postings: [
          PostingModel(accountId: expense.id, amountCents: 1000),
          PostingModel(accountId: asset.id, amountCents: -1000),
        ],
      );
      expect(repo.transactions.length, 2);

      final snapshot = service.availableRollbackSnapshots.first;

      // 2. Rollback manually
      final rollbackSuccess = await service.rollbackToSnapshot(snapshot.snapshotId);
      expect(rollbackSuccess, isTrue);
      expect(service.currentVersion, '3.0.0');
      expect(service.currentBuild, 300);
      expect(repo.transactions.length, 1);
      expect(repo.transactions.first.description, 'Original v3.0 Entry');
    });

    test('tryParseJson parses both signed manifest.json and GitHub Releases API JSON with APK/IPA assets', () {
      final manifest = AppUpdateManifest.tryParseJson({
        'version': '3.1.0',
        'build_number': 30100,
        'release_date': '2026-11-25',
        'title': 'Cash-IO v3.1.0 Mobile Release',
        'changelog': ['Android self-updater'],
        'sha256_checksum': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        'download_url': 'https://github.com/voidness-x/Cash-IO/releases/download/v3.1.0/cashio-v3.1.0-android.apk',
        'apk_download_url': 'https://github.com/voidness-x/Cash-IO/releases/download/v3.1.0/cashio-v3.1.0-android.apk',
        'apk_sha256_checksum': 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        'ios_download_url': 'https://github.com/voidness-x/Cash-IO/releases/download/v3.1.0/cashio-v3.1.0-ios-unsigned.ipa',
      });
      expect(manifest, isNotNull);
      expect(manifest!.version, '3.1.0');
      expect(manifest.buildNumber, 30100);
      expect(manifest.effectiveApkUrl.endsWith('cashio-v3.1.0-android.apk'), isTrue);
      expect(manifest.effectiveIosUrl.endsWith('cashio-v3.1.0-ios-unsigned.ipa'), isTrue);

      final ghApiManifest = AppUpdateManifest.tryParseJson({
        'tag_name': 'v3.2.5',
        'name': 'Cash-IO v3.2.5',
        'published_at': '2026-12-01T10:00:00Z',
        'html_url': 'https://github.com/voidness-x/Cash-IO/releases/tag/v3.2.5',
        'body': '- Faster Argon2id unlock\n- New multi-currency chart',
        'assets': [
          {
            'name': 'cashio-v3.2.5-android.apk',
            'browser_download_url':
                'https://github.com/voidness-x/Cash-IO/releases/download/v3.2.5/cashio-v3.2.5-android.apk',
            'digest': 'sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          },
          {
            'name': 'cashio-v3.2.5-ios-unsigned.ipa',
            'browser_download_url':
                'https://github.com/voidness-x/Cash-IO/releases/download/v3.2.5/cashio-v3.2.5-ios-unsigned.ipa',
          },
        ],
      });
      expect(ghApiManifest, isNotNull);
      expect(ghApiManifest!.version, '3.2.5');
      expect(ghApiManifest.buildNumber, 30205);
      expect(ghApiManifest.changelog.length, 2);
      expect(ghApiManifest.effectiveApkSha256.length, 64);
      expect(UpdateReceiverService.compareSemver('3.2.5', '3.1.0'), greaterThan(0));
    });
  });
}
