//! Symmetric encryption for secrets at rest (e.g. user-provided API keys).
//!
//! This crate is deliberately transport- and HTTP-agnostic: it returns its own
//! [`CryptoError`] rather than an HTTP error type, so it can be unit-tested and
//! reused without pulling in a web framework. The composition layer maps
//! [`CryptoError`] onto its own error type at the boundary.
//!
//! Ciphertext format (versioned for forward compatibility):
//!
//! ```text
//! v1:<base64url(nonce)>:<base64url(ciphertext)>
//! ```

use aes_gcm::{
    Aes256Gcm, Nonce,
    aead::{Aead, KeyInit},
};
use base64::{Engine as _, engine::general_purpose::URL_SAFE_NO_PAD};
use rand_core::{OsRng, RngCore};
use sha2::{Digest, Sha256};

/// An error produced while encrypting or decrypting a secret.
///
/// Wraps a stable, human-readable message so callers can surface a consistent
/// reason without depending on this crate's internals.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct CryptoError {
    message: &'static str,
}

impl CryptoError {
    /// The stable, user-facing reason for the failure.
    pub fn message(&self) -> &'static str {
        self.message
    }

    const fn new(message: &'static str) -> Self {
        Self { message }
    }
}

impl std::fmt::Display for CryptoError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(self.message)
    }
}

impl std::error::Error for CryptoError {}

/// AES-256-GCM cipher keyed by the SHA-256 digest of a secret string.
///
/// Deriving the key from a digest guarantees a valid 32-byte key for any secret
/// length. Each [`encrypt`](Self::encrypt) call uses a fresh random 96-bit nonce.
#[derive(Clone)]
pub struct KeyCipher {
    cipher: Aes256Gcm,
}

impl KeyCipher {
    /// Builds a cipher from an arbitrary-length secret.
    ///
    /// The secret is hashed with SHA-256 to produce the 32-byte AES key, so any
    /// non-empty configuration string is acceptable.
    pub fn from_secret(secret: &str) -> Self {
        let digest = Sha256::digest(secret.as_bytes());
        let cipher = Aes256Gcm::new_from_slice(&digest).expect("sha256 always yields 32 bytes");
        Self { cipher }
    }

    /// Encrypts `plaintext`, returning the versioned `v1:nonce:ciphertext` string.
    ///
    /// # Errors
    /// Returns [`CryptoError`] if the underlying AEAD encryption fails.
    pub fn encrypt(&self, plaintext: &str) -> Result<String, CryptoError> {
        let mut nonce_bytes = [0_u8; 12];
        OsRng.fill_bytes(&mut nonce_bytes);
        let nonce = Nonce::from_slice(&nonce_bytes);
        let ciphertext = self
            .cipher
            .encrypt(nonce, plaintext.as_bytes())
            .map_err(|_| CryptoError::new("failed to encrypt API key"))?;

        Ok(format!(
            "v1:{}:{}",
            URL_SAFE_NO_PAD.encode(nonce_bytes),
            URL_SAFE_NO_PAD.encode(ciphertext)
        ))
    }

    /// Decrypts a `v1:nonce:ciphertext` string produced by [`encrypt`](Self::encrypt).
    ///
    /// # Errors
    /// Returns [`CryptoError`] if the format is unrecognised, the base64 segments
    /// are malformed, decryption fails, or the plaintext is not valid UTF-8.
    pub fn decrypt(&self, encoded: &str) -> Result<String, CryptoError> {
        let parts = encoded.split(':').collect::<Vec<_>>();
        if parts.len() != 3 || parts[0] != "v1" {
            return Err(CryptoError::new("unsupported encrypted secret format"));
        }

        let nonce = URL_SAFE_NO_PAD
            .decode(parts[1])
            .map_err(|_| CryptoError::new("invalid encrypted secret nonce"))?;
        let ciphertext = URL_SAFE_NO_PAD
            .decode(parts[2])
            .map_err(|_| CryptoError::new("invalid encrypted secret payload"))?;
        let plaintext = self
            .cipher
            .decrypt(Nonce::from_slice(&nonce), ciphertext.as_ref())
            .map_err(|_| CryptoError::new("failed to decrypt API key"))?;

        String::from_utf8(plaintext).map_err(|_| CryptoError::new("decrypted API key is invalid"))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn round_trips_plaintext() {
        let cipher = KeyCipher::from_secret("test-secret");
        let encoded = cipher.encrypt("sk-12345").expect("encrypt");
        assert!(encoded.starts_with("v1:"));
        assert_eq!(cipher.decrypt(&encoded).expect("decrypt"), "sk-12345");
    }

    #[test]
    fn rejects_unknown_format() {
        let cipher = KeyCipher::from_secret("test-secret");
        assert_eq!(
            cipher.decrypt("v2:foo:bar").unwrap_err().message(),
            "unsupported encrypted secret format"
        );
    }
}
