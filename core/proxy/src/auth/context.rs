//! Authentication composition context and short-lived OAuth PKCE state.

use std::{
    borrow::Cow,
    collections::HashMap,
    sync::{Arc, Mutex},
    time::{Duration, Instant},
};

use sqlx::{
    PgPool,
    migrate::{Migration, MigrationType, Migrator},
    postgres::PgPoolOptions,
};
use uuid::Uuid;

use tether_crypto::KeyCipher;

use crate::{AppState, error::ApiError};

use super::jwt::JwtConfig;

#[derive(Clone)]
pub(crate) struct AuthContext {
    pub(crate) pool: PgPool,
    pub(crate) jwt: JwtConfig,
    pub(crate) google: Option<GoogleOAuthConfig>,
    pub(crate) key_cipher: Option<KeyCipher>,
    pub(crate) http: reqwest::Client,
    oauth_states: Arc<Mutex<HashMap<String, PkceSession>>>,
}

#[derive(Clone)]
pub(crate) struct GoogleOAuthConfig {
    pub(crate) client_id: String,
    pub(crate) client_secret: String,
    pub(crate) redirect_uri: String,
}

#[derive(Clone)]
pub(crate) struct PkceSession {
    pub(crate) verifier: String,
    expires_at: Instant,
}

const DEFAULT_ROLE_NAME: &str = "member";
const DEFAULT_PERMISSIONS: [&str; 7] = [
    "access:api",
    "settings:read",
    "settings:write",
    "providers:read",
    "traces:read",
    "traces:write",
    "traces:replay",
];
const ADMIN_PERMISSIONS: [&str; 1] = ["actions:execute"];

impl AuthContext {
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

        auth_migrator().run(&pool).await.map_err(|error| {
            eprintln!("failed to run auth migrations: {error}");
            ApiError::internal("failed to run auth migrations")
        })?;

        let context = Self {
            pool,
            jwt: JwtConfig::from_env_secret(&jwt_secret),
            google: google_config_from_env(),
            key_cipher: key_cipher_from_env(),
            http,
            oauth_states: Arc::new(Mutex::new(HashMap::new())),
        };

        context.seed_access_control().await?;

        Ok(Some(context))
    }

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

    pub(crate) async fn seed_access_control(&self) -> Result<(), ApiError> {
        let mut tx = self.pool.begin().await?;

        sqlx::query(
            "INSERT INTO roles (name, description, is_system, is_default)
             VALUES ('member', 'Default application user', false, true),
                    ('admin', 'Administrative application role', true, false)
             ON CONFLICT (name) DO NOTHING",
        )
        .execute(&mut *tx)
        .await?;

        for permission in DEFAULT_PERMISSIONS {
            sqlx::query("INSERT INTO permissions (name) VALUES ($1) ON CONFLICT (name) DO NOTHING")
                .bind(permission)
                .execute(&mut *tx)
                .await?;
        }

        for permission in ADMIN_PERMISSIONS {
            sqlx::query(
                "INSERT INTO permissions (name, description)
                 VALUES ($1, 'Admin-only privilege')
                 ON CONFLICT (name) DO NOTHING",
            )
            .bind(permission)
            .execute(&mut *tx)
            .await?;
        }

        for permission in DEFAULT_PERMISSIONS.iter().chain(ADMIN_PERMISSIONS.iter()) {
            sqlx::query("INSERT INTO role_permissions (role_name, permission_name) VALUES ('member', $1) ON CONFLICT DO NOTHING")
                .bind(permission)
                .execute(&mut *tx)
                .await?;
            sqlx::query("INSERT INTO role_permissions (role_name, permission_name) VALUES ('admin', $1) ON CONFLICT DO NOTHING")
                .bind(permission)
                .execute(&mut *tx)
                .await?;
        }

        sqlx::query(
            "INSERT INTO user_roles (user_id, role_name)
             SELECT id, $1
             FROM users
             WHERE NOT EXISTS (
                SELECT 1 FROM user_roles ur WHERE ur.user_id = users.id
             )
             ON CONFLICT DO NOTHING",
        )
        .bind(DEFAULT_ROLE_NAME)
        .execute(&mut *tx)
        .await?;

        tx.commit().await?;
        Ok(())
    }

    pub(crate) async fn ensure_default_role(&self, user_id: Uuid) -> Result<(), ApiError> {
        sqlx::query(
            "INSERT INTO user_roles (user_id, role_name)
             VALUES ($1, $2)
             ON CONFLICT DO NOTHING",
        )
        .bind(user_id)
        .bind(DEFAULT_ROLE_NAME)
        .execute(&self.pool)
        .await?;
        Ok(())
    }

    pub(crate) async fn has_permission(
        &self,
        user_id: Uuid,
        permission: &str,
    ) -> Result<bool, ApiError> {
        let allowed = sqlx::query_scalar::<_, bool>(
            "SELECT EXISTS (
                SELECT 1
                FROM user_roles ur
                JOIN role_permissions rp ON rp.role_name = ur.role_name
                WHERE ur.user_id = $1
                  AND rp.permission_name = $2
            )",
        )
        .bind(user_id)
        .bind(permission)
        .fetch_one(&self.pool)
        .await?;
        Ok(allowed)
    }
}

fn auth_migrator() -> Migrator {
    Migrator {
        migrations: Cow::Owned(vec![
            Migration::new(
                20260530000000,
                Cow::Borrowed("auth settings"),
                MigrationType::Simple,
                Cow::Borrowed(include_str!(
                    "../../migrations/20260530000000_auth_settings.sql"
                )),
                false,
            ),
            Migration::new(
                20260601000000,
                Cow::Borrowed("access control"),
                MigrationType::Simple,
                Cow::Borrowed(include_str!(
                    "../../migrations/20260601000000_access_control.sql"
                )),
                false,
            ),
        ]),
        ..Migrator::DEFAULT
    }
}

pub(crate) fn require_auth(state: &AppState) -> Result<Arc<AuthContext>, ApiError> {
    state
        .auth
        .clone()
        .ok_or_else(|| ApiError::unavailable("auth database is not configured"))
}

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

fn key_cipher_from_env() -> Option<KeyCipher> {
    std::env::var("AGENTTRACE_KEYS_SECRET")
        .ok()
        .map(|secret| KeyCipher::from_secret(&secret))
}
