use aes_gcm::{
    aead::{Aead, KeyInit},
    Aes256Gcm, Nonce,
};
use argon2::{Algorithm, Argon2, Params, Version};
use bip39::{Language, Mnemonic};
use thiserror::Error;
use zeroize::{Zeroize, ZeroizeOnDrop};

#[derive(Error, Debug)]
pub enum CryptoError {
    #[error("Key derivation failed: {0}")]
    KdfError(String),
    #[error("Encryption failed: {0}")]
    EncryptionError(String),
    #[error("Decryption failed: {0}")]
    DecryptionError(String),
    #[error("Mnemonic generation failed: {0}")]
    MnemonicError(String),
}

/// Cryptographically secure Zero-Knowledge vault key container.
/// Automatically zeroes memory when dropped out of scope.
#[derive(Zeroize, ZeroizeOnDrop)]
pub struct VaultKey {
    pub key_bytes: [u8; 32],
}

pub struct CryptoEngine;

impl CryptoEngine {
    /// Generates a statistically unique 12-word BIP-39 mnemonic seed phrase
    /// using OS cryptographically secure random number generator (128 bits entropy).
    pub fn generate_12_word_mnemonic() -> Result<String, CryptoError> {
        let mut entropy = [0u8; 16];
        getrandom::getrandom(&mut entropy)
            .map_err(|e| CryptoError::MnemonicError(e.to_string()))?;

        let mnemonic = Mnemonic::from_entropy_in(Language::English, &entropy)
            .map_err(|e| CryptoError::MnemonicError(e.to_string()))?;

        Ok(mnemonic.to_string())
    }

    /// Derives a 256-bit vault encryption key using Argon2id with mobile-tuned parameters:
    /// Memory: 64 MB, Time: 3 iterations, Parallelism: 4 threads.
    pub fn derive_key_from_pin(pin: &str, salt_bytes: &[u8]) -> Result<VaultKey, CryptoError> {
        let params = Params::new(64 * 1024, 3, 4, Some(32))
            .map_err(|e| CryptoError::KdfError(e.to_string()))?;
        let argon2 = Argon2::new(Algorithm::Argon2id, Version::V0x13, params);

        let mut output_key = [0u8; 32];
        argon2
            .hash_password_into(pin.as_bytes(), salt_bytes, &mut output_key)
            .map_err(|e| CryptoError::KdfError(e.to_string()))?;

        Ok(VaultKey { key_bytes: output_key })
    }

    /// Encrypts an arbitrary payload using AES-256-GCM with a 96-bit random nonce.
    /// Output format: Nonce (12 bytes) + Ciphertext + Tag (16 bytes).
    pub fn encrypt_aes_gcm(key: &VaultKey, plaintext: &[u8]) -> Result<Vec<u8>, CryptoError> {
        let cipher = Aes256Gcm::new_from_slice(&key.key_bytes)
            .map_err(|e| CryptoError::EncryptionError(e.to_string()))?;

        let mut nonce_bytes = [0u8; 12];
        getrandom::getrandom(&mut nonce_bytes)
            .map_err(|e| CryptoError::EncryptionError(e.to_string()))?;
        let nonce = Nonce::from_slice(&nonce_bytes);

        let mut ciphertext = cipher
            .encrypt(nonce, plaintext)
            .map_err(|e| CryptoError::EncryptionError(e.to_string()))?;

        let mut package = Vec::with_capacity(12 + ciphertext.len());
        package.extend_from_slice(&nonce_bytes);
        package.append(&mut ciphertext);

        Ok(package)
    }

    /// Decrypts a payload encrypted with AES-256-GCM.
    pub fn decrypt_aes_gcm(key: &VaultKey, payload: &[u8]) -> Result<Vec<u8>, CryptoError> {
        if payload.len() < 28 {
            return Err(CryptoError::DecryptionError("Payload too short".to_string()));
        }

        let cipher = Aes256Gcm::new_from_slice(&key.key_bytes)
            .map_err(|e| CryptoError::DecryptionError(e.to_string()))?;

        let nonce = Nonce::from_slice(&payload[..12]);
        let ciphertext = &payload[12..];

        cipher
            .decrypt(nonce, ciphertext)
            .map_err(|e| CryptoError::DecryptionError(e.to_string()))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_aes_256_gcm_roundtrip_and_tamper_detection() {
        let key = CryptoEngine::derive_key_from_pin("849201", b"unique_profile_salt_32bytes_long").unwrap();
        let plaintext = b"{\"account\":\"Cash Vault\",\"balance_cents\":500000}";
        let mut encrypted = CryptoEngine::encrypt_aes_gcm(&key, plaintext).unwrap();

        let decrypted = CryptoEngine::decrypt_aes_gcm(&key, &encrypted).unwrap();
        assert_eq!(decrypted, plaintext);

        // Flip 1 bit in ciphertext and assert authentication tag failure
        let last_idx = encrypted.len() - 1;
        encrypted[last_idx] ^= 0x01;
        assert!(CryptoEngine::decrypt_aes_gcm(&key, &encrypted).is_err());
    }
}
