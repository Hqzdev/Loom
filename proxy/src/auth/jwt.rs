//! JWT issuing and verification for authenticated API calls.

use chrono::Utc;
use jsonwebtoken::{DecodingKey, EncodingKey, Header, Validation, decode, encode};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::error::ApiError;

/// Access-token lifetime used by every issued bearer token.
pub(crate) const ACCESS_TOKEN_TTL_SECONDS: i64 = 60 * 60;

/// HS256 signing and validation configuration.
#[derive(Clone)]
pub(crate) struct JwtConfig {
    encoding_key: EncodingKey,
    decoding_key: DecodingKey,
    issuer: String,
    audience: String,
}

/// JWT claims carried by a validated access token.
#[derive(Debug, Serialize, Deserialize)]
pub(crate) struct Claims {
    pub(crate) sub: Uuid,
    pub(crate) iat: i64,
    pub(crate) exp: i64,
    pub(crate) iss: String,
    pub(crate) aud: String,
}

impl JwtConfig {
    /// Builds signing keys and metadata from a validated shared secret.
    pub(crate) fn from_env_secret(secret: &str) -> Self {
        let issuer = std::env::var("JWT_ISSUER").unwrap_or_else(|_| "agenttrace".to_string());
        let audience =
            std::env::var("JWT_AUDIENCE").unwrap_or_else(|_| "agenttrace-app".to_string());
        Self {
            encoding_key: EncodingKey::from_secret(secret.as_bytes()),
            decoding_key: DecodingKey::from_secret(secret.as_bytes()),
            issuer,
            audience,
        }
    }

    /// Issues a signed bearer token for one user id.
    pub(crate) fn issue(&self, user_id: Uuid) -> Result<String, ApiError> {
        let iat = Utc::now().timestamp();
        let claims = Claims {
            sub: user_id,
            iat,
            exp: iat + ACCESS_TOKEN_TTL_SECONDS,
            iss: self.issuer.clone(),
            aud: self.audience.clone(),
        };
        encode(&Header::default(), &claims, &self.encoding_key)
            .map_err(|_| ApiError::internal("failed to sign access token"))
    }

    /// Verifies signature, expiration, issuer, and audience for a bearer token.
    pub(crate) fn verify(&self, token: &str) -> Result<Claims, ApiError> {
        let mut validation = Validation::default();
        validation.set_issuer(&[self.issuer.as_str()]);
        validation.set_audience(&[self.audience.as_str()]);
        decode::<Claims>(token, &self.decoding_key, &validation)
            .map(|data| data.claims)
            .map_err(|_| ApiError::unauthorized("invalid or expired access token"))
    }
}
