//! Authentication composition context and short-lived OAuth PKCE state.

use std::{
    collections::HashMap,
    sync::{Arc, Mutex},
    time::{Duration, Instant},
};

use sqlx::{PgPool, postgres::PgPoolOptions};

use loom_crypto::KeyCipher;

use crate::{AppState, error::ApiError};

use super::jwt::JwtConfig;

/// Runtime dependencies and optional providers for authenticated API routes.
#[derive(Clone)]
pub(crate) struct AuthContext {
    pub(crate) pool: PgPool,
    pub(crate) jwt: JwtConfig,
    pub(crate) google: Option<GoogleOAuthConfig>,
    pub(crate) key_cipher: Option<KeyCipher>,
    pub(crate) http: reqwest::Client,
    oauth_states: Arc<Mutex<HashMap<String, PkceSession>>>,
}

/// Google OAuth client settings loaded from environment variables.
#[derive(Clone)]
pub(crate) struct GoogleOAuthConfig {
    pub(crate) client_id: String,
    pub(crate) client_secret: String,
    pub(crate) redirect_uri: String,
}

/// Stored OAuth verifier for one in-flight PKCE authorization flow.
#[derive(Clone)]
pub(crate) struct PkceSession {
    pub(crate) verifier: String,
    expires_at: Instant,
}

impl AuthContext {
    /// Creates auth dependencies when `DATABASE_URL` is set.
    pub(crate) async fn from_env(http: reqwest::Client) -> Result<Option<Self>, ApiError> {
        let Ok(database_url) = std::env::var("DATABASE_URL") else {
            return Ok(None);
        };
        let jwt_secret = jwt_secret()?;
        let pool = PgPoolOptions::new()
            .max_connections(5)
            .connect(&database_url)
            .await
            .map_err(|error| {
                eprintln!("failed to connect auth database: {error}");
                ApiError::unavailable("failed to connect auth database")
            })?;

        sqlx::migrate!("./migrations")
            .run(&pool)
            .await
            .map_err(|error| {
                eprintln!("failed to run auth migrations: {error}");
                ApiError::internal("failed to run auth migrations")
            })?;

        Ok(Some(Self {
            pool,
            jwt: JwtConfig::from_env_secret(&jwt_secret),
            google: google_config_from_env(),
            key_cipher: key_cipher_from_env(),
            http,
            oauth_states: Arc::new(Mutex::new(HashMap::new())),
        }))
    }

    /// Removes and returns a valid PKCE verifier for an OAuth callback state.
    pub(crate) fn take_pkce_session(&self, state: &str) -> Result<PkceSession, ApiError> {
        let mut states = self
            .oauth_states
            .lock()
            .map_err(|_| ApiError::internal("oauth state store is unavailable"))?;
        states.retain(|_, session| session.expires_at > Instant::now());
        let session = states
            .remove(state)
            .ok_or_else(|| ApiError::bad_request("invalid or expired OAuth state"))?;
        if session.expires_at <= Instant::now() {
            return Err(ApiError::bad_request("expired OAuth state"));
        }
        Ok(session)
    }

    /// Stores the verifier for one OAuth callback state with a ten-minute TTL.
    pub(crate) fn store_pkce_session(
        &self,
        state: String,
        verifier: String,
    ) -> Result<(), ApiError> {
        let mut states = self
            .oauth_states
            .lock()
            .map_err(|_| ApiError::internal("oauth state store is unavailable"))?;
        states.insert(
            state,
            PkceSession {
                verifier,
                expires_at: Instant::now() + Duration::from_secs(10 * 60),
            },
        );
        Ok(())
    }
}

/// Returns auth context or a service-unavailable API error.
pub(crate) fn require_auth(state: &AppState) -> Result<Arc<AuthContext>, ApiError> {
    state
        .auth
        .clone()
        .ok_or_else(|| ApiError::unavailable("auth database is not configured"))
}

/// Loads and validates the HS256 signing secret.
fn jwt_secret() -> Result<String, ApiError> {
    let jwt_secret = std::env::var("JWT_SECRET").map_err(|_| {
        ApiError::unavailable("JWT_SECRET must be configured when DATABASE_URL is set")
    })?;
    if jwt_secret.len() < 32 {
        return Err(ApiError::unavailable(
            "JWT_SECRET must be at least 32 bytes for HS256 signing",
        ));
    }
    Ok(jwt_secret)
}

/// Loads optional Google OAuth configuration from environment variables.
fn google_config_from_env() -> Option<GoogleOAuthConfig> {
    match (
        std::env::var("GOOGLE_CLIENT_ID"),
        std::env::var("GOOGLE_CLIENT_SECRET"),
        std::env::var("GOOGLE_REDIRECT_URI"),
    ) {
        (Ok(client_id), Ok(client_secret), Ok(redirect_uri)) => Some(GoogleOAuthConfig {
            client_id,
            client_secret,
            redirect_uri,
        }),
        _ => None,
    }
}

/// Builds the optional API-key cipher when its secret is configured.
fn key_cipher_from_env() -> Option<KeyCipher> {
    std::env::var("AGENTTRACE_KEYS_SECRET")
        .ok()
        .map(|secret| KeyCipher::from_secret(&secret))
}
