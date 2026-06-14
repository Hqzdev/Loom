//! Password validation and Argon2 hashing helpers.

use argon2::{
    Argon2,
    password_hash::{PasswordHash, PasswordHasher, PasswordVerifier, SaltString},
};
use rand_core::OsRng;

use crate::error::ApiError;

/// Enforces the local-account password floor.
pub(super) fn validate_password(password: &str) -> Result<(), ApiError> {
    if password.len() < 12 {
        return Err(ApiError::bad_request(
            "password must be at least 12 characters",
        ));
    }
    Ok(())
}

/// Hashes a plaintext password for storage using Argon2.
pub(super) fn hash_password(password: &str) -> Result<String, ApiError> {
    let salt = SaltString::generate(&mut OsRng);
    Argon2::default()
        .hash_password(password.as_bytes(), &salt)
        .map(|hash| hash.to_string())
        .map_err(|_| ApiError::internal("failed to hash password"))
}

/// Verifies a plaintext password against an Argon2 password hash.
pub(super) fn verify_password(password: &str, password_hash: &str) -> Result<(), ApiError> {
    let parsed_hash = PasswordHash::new(password_hash)
        .map_err(|_| ApiError::internal("stored password hash is invalid"))?;
    Argon2::default()
        .verify_password(password.as_bytes(), &parsed_hash)
        .map_err(|_| ApiError::unauthorized("invalid email or password"))
}
