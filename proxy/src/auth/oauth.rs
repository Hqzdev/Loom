use axum::{
    Json,
    extract::{Query, State},
    response::Redirect,
};
use base64::{Engine as _, engine::general_purpose::URL_SAFE_NO_PAD};
use rand_core::{OsRng, RngCore};
use serde::Deserialize;
use sha2::{Digest, Sha256};
use sqlx::Row;
use url::Url;

use crate::{
    AppState,
    auth::{AuthResponse, auth_response, normalize_email, require_auth, row_to_user},
    error::ApiError,
};

use super::google::verify_google_id_token;

const GOOGLE_AUTH_URL: &str = "https://accounts.google.com/o/oauth2/v2/auth";
const GOOGLE_TOKEN_URL: &str = "https://oauth2.googleapis.com/token";

#[derive(Debug, Deserialize)]
pub(crate) struct GoogleCallbackQuery {
    code: String,
    state: String,
}

#[derive(Debug, Deserialize)]
struct GoogleTokenResponse {
    id_token: String,
}

/// Starts a Google OAuth authorization-code flow with PKCE.
pub(crate) async fn google_start(State(state): State<AppState>) -> Result<Redirect, ApiError> {
    let auth = require_auth(&state)?;
    let google = auth
        .google
        .as_ref()
        .ok_or_else(|| ApiError::unavailable("Google OAuth is not configured"))?;

    let state_token = secure_token(32);
    let verifier = secure_token(64);
    let challenge = pkce_challenge(&verifier);
    auth.store_pkce_session(state_token.clone(), verifier)?;

    let mut url = Url::parse(GOOGLE_AUTH_URL)
        .map_err(|_| ApiError::internal("failed to build Google authorization URL"))?;
    url.query_pairs_mut()
        .append_pair("client_id", &google.client_id)
        .append_pair("redirect_uri", &google.redirect_uri)
        .append_pair("response_type", "code")
        .append_pair("scope", "openid email profile")
        .append_pair("state", &state_token)
        .append_pair("code_challenge", &challenge)
        .append_pair("code_challenge_method", "S256")
        .append_pair("prompt", "select_account");

    Ok(Redirect::temporary(url.as_str()))
}

/// Handles the Google OAuth callback and returns an app auth token.
pub(crate) async fn google_callback(
    State(state): State<AppState>,
    Query(query): Query<GoogleCallbackQuery>,
) -> Result<Json<AuthResponse>, ApiError> {
    let auth = require_auth(&state)?;
    let google = auth
        .google
        .as_ref()
        .ok_or_else(|| ApiError::unavailable("Google OAuth is not configured"))?;

    let pkce = auth.take_pkce_session(&query.state)?;
    let token_response = auth
        .http
        .post(GOOGLE_TOKEN_URL)
        .form(&[
            ("code", query.code.as_str()),
            ("client_id", google.client_id.as_str()),
            ("client_secret", google.client_secret.as_str()),
            ("redirect_uri", google.redirect_uri.as_str()),
            ("grant_type", "authorization_code"),
            ("code_verifier", pkce.verifier.as_str()),
        ])
        .send()
        .await
        .map_err(|_| ApiError::unavailable("failed to exchange Google OAuth code"))?;

    if !token_response.status().is_success() {
        return Err(ApiError::bad_request("Google OAuth code exchange failed"));
    }

    let token_response = token_response
        .json::<GoogleTokenResponse>()
        .await
        .map_err(|_| ApiError::bad_request("invalid Google OAuth token response"))?;
    let claims =
        verify_google_id_token(&state, &google.client_id, &token_response.id_token).await?;

    if claims.email_verified != Some(true) {
        return Err(ApiError::forbidden("Google email is not verified"));
    }

    // Google's ID token payload is trusted only after RS256 signature verification
    // against Google's JWKS and after audience/issuer/expiration validation. Once
    // verified, `sub` becomes the stable Google account id and `email/name` are
    // used to find, link, or provision the AgentTrace user.
    let email = normalize_email(&claims.email)?;
    let name = claims
        .name
        .filter(|name| !name.trim().is_empty())
        .unwrap_or_else(|| {
            email
                .split('@')
                .next()
                .unwrap_or("AgentTrace User")
                .to_string()
        });

    let mut tx = auth.pool.begin().await?;
    let existing = sqlx::query(
        "SELECT id, email, name, google_id, created_at
         FROM users
         WHERE google_id = $1 OR email = $2
         ORDER BY CASE WHEN google_id = $1 THEN 0 ELSE 1 END
         LIMIT 1",
    )
    .bind(&claims.sub)
    .bind(&email)
    .fetch_optional(&mut *tx)
    .await?;

    let user = if let Some(row) = existing {
        let user_id = row.try_get::<uuid::Uuid, _>("id")?;
        let linked_google_id = row.try_get::<Option<String>, _>("google_id")?;
        if linked_google_id.as_deref() != Some(claims.sub.as_str()) {
            sqlx::query("UPDATE users SET google_id = $1 WHERE id = $2")
                .bind(&claims.sub)
                .bind(user_id)
                .execute(&mut *tx)
                .await?;
        }
        row_to_user(row)?
    } else {
        let row = sqlx::query(
            "INSERT INTO users (email, name, password_hash, google_id)
             VALUES ($1, $2, NULL, $3)
             RETURNING id, email, name, created_at",
        )
        .bind(&email)
        .bind(&name)
        .bind(&claims.sub)
        .fetch_one(&mut *tx)
        .await?;
        row_to_user(row)?
    };

    sqlx::query("INSERT INTO user_settings (user_id) VALUES ($1) ON CONFLICT (user_id) DO NOTHING")
        .bind(user.id)
        .execute(&mut *tx)
        .await?;
    tx.commit().await?;

    Ok(Json(auth_response(&auth, user)?))
}

/// Generates a URL-safe random token for OAuth state/verifier values.
fn secure_token(bytes_len: usize) -> String {
    let mut bytes = vec![0_u8; bytes_len];
    OsRng.fill_bytes(&mut bytes);
    URL_SAFE_NO_PAD.encode(bytes)
}

/// Computes the S256 PKCE code challenge for an OAuth verifier.
fn pkce_challenge(verifier: &str) -> String {
    let digest = Sha256::digest(verifier.as_bytes());
    URL_SAFE_NO_PAD.encode(digest)
}
