use axum::{
    extract::FromRequestParts,
    http::{HeaderMap, request::Parts},
};
use uuid::Uuid;

use crate::{AppState, auth::require_auth, error::ApiError};

/// Authenticated bearer identity extracted from a validated access token.
#[derive(Debug, Clone, Copy)]
pub(crate) struct AuthBearer {
    pub(crate) user_id: Uuid,
}

impl FromRequestParts<AppState> for AuthBearer {
    type Rejection = ApiError;

    async fn from_request_parts(
        parts: &mut Parts,
        state: &AppState,
    ) -> Result<Self, Self::Rejection> {
        let auth = require_auth(state)?;
        let token = bearer_token(&parts.headers)?;

        // The AuthBearer extractor is the authorization boundary for protected routes.
        // It accepts only `Authorization: Bearer <jwt>` and delegates verification to
        // JwtConfig::verify, which validates signature, expiration, issuer, and audience.
        let claims = auth.jwt.verify(token)?;
        Ok(Self {
            user_id: claims.sub,
        })
    }
}

/// Extracts a non-empty bearer token from the Authorization header.
fn bearer_token(headers: &HeaderMap) -> Result<&str, ApiError> {
    let header = headers
        .get(axum::http::header::AUTHORIZATION)
        .and_then(|value| value.to_str().ok())
        .ok_or_else(|| ApiError::unauthorized("missing Authorization bearer token"))?;

    header
        .strip_prefix("Bearer ")
        .filter(|token| !token.trim().is_empty())
        .ok_or_else(|| ApiError::unauthorized("invalid Authorization bearer token"))
}
