import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

class E2eePackager {
  static final E2eePackager instance = E2eePackager._init();
  E2eePackager._init();

  static const int _nonceLength = 12;
  static const int _tagLength = 16;

  /// Constant-time byte slice comparison to prevent timing side-channel attacks.
  static bool constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= (a[i] ^ b[i]) & 0xff;
    }
    return diff == 0;
  }

  /// Constant-time string comparison (UTF-8 byte level).
  static bool constantTimeStringEquals(String a, String b) {
    return constantTimeEquals(utf8.encode(a), utf8.encode(b));
  }

  /// Computes a non-descriptive remote filename hash for Google Drive appdata
  String getRemoteVaultFilename(String profileId) {
    final hash = sha256.convert(utf8.encode('cashio_vault_appdata:$profileId'));
    return 'vault_${hash.toString().substring(0, 16)}.enc';
  }

  /// Derives domain-separated encryption and authentication subkeys via HKDF-HMAC-SHA256.
  static List<int> _deriveSubkey(List<int> masterKeyBytes, List<int> nonce, String contextLabel) {
    final prk = Hmac(sha256, nonce).convert(masterKeyBytes).bytes;
    return Hmac(sha256, prk).convert([...utf8.encode(contextLabel), 0x01]).bytes;
  }

  /// Generates a non-repeating 256-bit counter-mode PRF keystream using HMAC-SHA256.
  static Uint8List _cryptCounterStream(Uint8List input, List<int> encSubkey, List<int> nonce) {
    final output = Uint8List(input.length);
    final hmac = Hmac(sha256, encSubkey);
    int offset = 0;
    int blockCounter = 0;

    while (offset < input.length) {
      final counterBytes = <int>[
        (blockCounter >> 24) & 0xff,
        (blockCounter >> 16) & 0xff,
        (blockCounter >> 8) & 0xff,
        blockCounter & 0xff,
      ];
      final keystreamBlock = hmac.convert([...nonce, ...counterBytes]).bytes;
      final remaining = input.length - offset;
      final chunkLen = remaining < 32 ? remaining : 32;

      for (int i = 0; i < chunkLen; i++) {
        output[offset + i] = input[offset + i] ^ keystreamBlock[i];
      }

      offset += chunkLen;
      blockCounter++;
    }
    return output;
  }

  /// Encrypts the CRDT/backup payload using an authenticated Encrypt-then-MAC envelope.
  /// Format: Nonce (12 bytes) + Ciphertext (N bytes) + HMAC-SHA256-128 Tag (16 bytes).
  Uint8List encryptPayload({
    required String plaintextJson,
    required String vaultKeyHash,
  }) {
    final random = Random.secure();
    final nonce = List<int>.generate(_nonceLength, (_) => random.nextInt(256));
    final plainBytes = Uint8List.fromList(utf8.encode(plaintextJson));
    final masterKeyBytes = sha256.convert(utf8.encode(vaultKeyHash)).bytes;

    final encSubkey = _deriveSubkey(masterKeyBytes, nonce, 'cashio-e2ee-v3-enc');
    final macSubkey = _deriveSubkey(masterKeyBytes, nonce, 'cashio-e2ee-v3-mac');

    final cipherBytes = _cryptCounterStream(plainBytes, encSubkey, nonce);

    // Encrypt-then-MAC over domain label + nonce + ciphertext
    final hmac = Hmac(sha256, macSubkey);
    final tagDigest = hmac.convert([
      ...utf8.encode('cashio-etm-v3'),
      ...nonce,
      ...cipherBytes,
    ]);
    final tag = tagDigest.bytes.sublist(0, _tagLength);

    final result = BytesBuilder(copy: false);
    result.add(nonce);
    result.add(cipherBytes);
    result.add(tag);

    return result.toBytes();
  }

  /// Decrypts and verifies the authenticated encrypted envelope in constant time.
  String? decryptPayload({
    required Uint8List encryptedData,
    required String vaultKeyHash,
  }) {
    if (encryptedData.length < _nonceLength + _tagLength) {
      return null; // 12 nonce + 16 tag minimum
    }

    final nonce = encryptedData.sublist(0, _nonceLength);
    final cipherBytes = encryptedData.sublist(_nonceLength, encryptedData.length - _tagLength);
    final receivedTag = encryptedData.sublist(encryptedData.length - _tagLength);
    final masterKeyBytes = sha256.convert(utf8.encode(vaultKeyHash)).bytes;

    final encSubkey = _deriveSubkey(masterKeyBytes, nonce, 'cashio-e2ee-v3-enc');
    final macSubkey = _deriveSubkey(masterKeyBytes, nonce, 'cashio-e2ee-v3-mac');

    // Verify HMAC tag in constant time BEFORE decrypting (Encrypt-then-MAC)
    final hmac = Hmac(sha256, macSubkey);
    final expectedTag = hmac.convert([
      ...utf8.encode('cashio-etm-v3'),
      ...nonce,
      ...cipherBytes,
    ]).bytes.sublist(0, _tagLength);

    if (!constantTimeEquals(receivedTag, expectedTag)) {
      return null; // Tampering detected or wrong key
    }

    final plainBytes = _cryptCounterStream(cipherBytes, encSubkey, nonce);
    try {
      return utf8.decode(plainBytes);
    } catch (_) {
      return null;
    }
  }
}
