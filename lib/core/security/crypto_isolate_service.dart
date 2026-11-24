import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../results/result.dart';
import '../sync/e2ee_packager.dart';

/// Cryptographic worker isolate parameter bundle
class _KdfParams {
  final String pin;
  final String salt;
  const _KdfParams(this.pin, this.salt);
}

class _EncryptionParams {
  final String plaintextJson;
  final String vaultKeyHash;
  const _EncryptionParams(this.plaintextJson, this.vaultKeyHash);
}

class _DecryptionParams {
  final Uint8List encryptedData;
  final String vaultKeyHash;
  const _DecryptionParams(this.encryptedData, this.vaultKeyHash);
}

/// Service that offloads computationally intensive cryptography (PBKDF2-HMAC-SHA256 KDF,
/// authenticated HKDF + CTR-HMAC envelope encryption, and large payload decryption)
/// to background worker isolates to prevent UI thread frame drops.
class CryptoIsolateService {
  static final CryptoIsolateService instance = CryptoIsolateService._init();
  CryptoIsolateService._init();

  static const int _kdfIterations = 10000;

  /// Derives an encryption key from PIN and salt inside a background isolate.
  Future<Result<String, CryptographicError>> deriveKeyAsync({
    required String pin,
    required String salt,
  }) async {
    if (pin.isEmpty || salt.isEmpty) {
      return const Failure(
        CryptographicError('PIN and salt must not be empty', code: 'ERR_KDF_EMPTY'),
      );
    }

    try {
      final keyHash = await compute(_runKdf, _KdfParams(pin, salt));
      return Success(keyHash);
    } catch (e) {
      return Failure(
        CryptographicError('Key derivation failed: $e', code: 'ERR_KDF_FAILED', cause: e),
      );
    }
  }

  /// Encrypts an arbitrary JSON payload using authenticated encryption inside an isolate.
  Future<Result<Uint8List, CryptographicError>> encryptPayloadAsync({
    required String plaintextJson,
    required String vaultKeyHash,
  }) async {
    if (vaultKeyHash.isEmpty) {
      return const Failure(
        CryptographicError('Vault key hash must not be empty', code: 'ERR_EMPTY_KEY'),
      );
    }
    try {
      final encryptedBytes = await compute(
        _runEncrypt,
        _EncryptionParams(plaintextJson, vaultKeyHash),
      );
      return Success(encryptedBytes);
    } catch (e) {
      return Failure(
        CryptographicError('Payload encryption failed: $e', code: 'ERR_ENCRYPT_FAILED', cause: e),
      );
    }
  }

  /// Decrypts and verifies an authenticated envelope inside an isolate.
  Future<Result<String, CryptographicError>> decryptPayloadAsync({
    required Uint8List encryptedData,
    required String vaultKeyHash,
  }) async {
    if (vaultKeyHash.isEmpty) {
      return const Failure(
        CryptographicError('Vault key hash must not be empty', code: 'ERR_EMPTY_KEY'),
      );
    }
    try {
      final result = await compute(
        _runDecrypt,
        _DecryptionParams(encryptedData, vaultKeyHash),
      );

      if (result == null) {
        return const Failure(
          CryptographicError('HMAC verification failed or ciphertext corrupted', code: 'ERR_TAMPER_DETECTED'),
        );
      }
      return Success(result);
    } catch (e) {
      return Failure(
        CryptographicError('Payload decryption failed: $e', code: 'ERR_DECRYPT_FAILED', cause: e),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Top-level Isolate Worker Functions
  // ---------------------------------------------------------------------------
  static String _runKdf(_KdfParams params) {
    // PBKDF2-HMAC-SHA256 (RFC 8018) with domain-separated salt and 10,000 rounds
    final prf = Hmac(sha256, utf8.encode(params.pin));
    final saltBlock = <int>[
      ...utf8.encode('cashio_kdf_enclave_v3:${params.salt}'),
      0x00,
      0x00,
      0x00,
      0x01,
    ];
    List<int> u = prf.convert(saltBlock).bytes;
    final derived = List<int>.from(u);

    for (int i = 1; i < _kdfIterations; i++) {
      u = prf.convert(u).bytes;
      for (int j = 0; j < derived.length; j++) {
        derived[j] ^= u[j];
      }
    }
    return derived.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Uint8List _runEncrypt(_EncryptionParams params) {
    return E2eePackager.instance.encryptPayload(
      plaintextJson: params.plaintextJson,
      vaultKeyHash: params.vaultKeyHash,
    );
  }

  static String? _runDecrypt(_DecryptionParams params) {
    return E2eePackager.instance.decryptPayload(
      encryptedData: params.encryptedData,
      vaultKeyHash: params.vaultKeyHash,
    );
  }
}
