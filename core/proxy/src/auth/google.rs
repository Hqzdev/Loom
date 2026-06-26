//! Google ID-token verification against Google's JWKS.

use jsonwebtoken::{Algorithm, DecodingKey, Validation, decode, decode_header};
use serde::Deserialize;

use crate::{AppState, error::ApiError};

const GOOGLE_JWKS_URL: &str = "https://www.googleapis.com/oauth2/v3/certs";

/// Claims extracted from a verified Google ID token.
#[derive(Debug, Deserialize)]
pub(crate) struct GoogleIdClaims {
    pub(crate) sub: String,
    pub(crate) email: String,
    pub(crate) email_verified: Option<bool>,
    pub(crate) name: Option<String>,
}

#[derive(Debug, Deserialize)]
struct GoogleJwks {
    keys: Vec<GoogleJwk>,
}

#[derive(Debug, Deserialize)]
struct GoogleJwk {
    kid: String,
    n: String,
    e: String,
}

/// Verifies a Google ID token with RS256 signature, issuer, and audience checks.
pub(crate) async fn verify_google_id_token(
    state: &AppState,
    google_client_id: &str,
    id_token: &str,
) -> Result<GoogleIdClaims, ApiError> {
    let header =
        decode_header(id_token).map_err(|_| ApiError::bad_request("invalid Google ID token"))?;
    let kid = header
        .kid
        .ok_or_else(|| ApiError::bad_request("Google ID token is missing key id"))?;
    let jwk = fetch_google_jwk(state, &kid).await?;
    let decoding_key = DecodingKey::from_rsa_components(&jwk.n, &jwk.e)
        .map_err(|_| ApiError::internal("invalid Google signing key"))?;

    let mut validation = Validation::new(Algorithm::RS256);
    validation.set_audience(&[google_client_id]);
    validation.set_issuer(&["https://accounts.google.com", "accounts.google.com"]);
    decode::<GoogleIdClaims>(id_token, &decoding_key, &validation)
        .map(|data| data.claims)
        .map_err(|_| ApiError::unauthorized("invalid Google ID token"))
}

/// Downloads Google's current public key matching a JWT key id.
async fn fetch_google_jwk(state: &AppState, kid: &str) -> Result<GoogleJwk, ApiError> {
    let jwks = state
        .client
        .get(GOOGLE_JWKS_URL)
        .send()
        .await
        .map_err(|_| ApiError::unavailable("failed to fetch Google public keys"))?
        .json::<GoogleJwks>()
        .await
        .map_err(|_| ApiError::unavailable("invalid Google public keys response"))?;

    jwks.keys
        .into_iter()
        .find(|key| key.kid == kid)
        .ok_or_else(|| ApiError::unauthorized("Google signing key not found"))
}
