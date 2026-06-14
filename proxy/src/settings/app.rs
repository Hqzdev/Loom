//! App preference route handlers and row mapping helpers.

use axum::{Json, extract::State};
use sqlx::Row;
use uuid::Uuid;

use crate::{
    AppState,
    auth::{extractor::AuthBearer, require_auth},
    error::ApiError,
};

use super::types::{AppSettingsResponse, AppSettingsUpdateRequest};

/// Returns the authenticated user's app preferences.
pub(super) async fn app_settings(
    State(state): State<AppState>,
    auth_bearer: AuthBearer,
) -> Result<Json<AppSettingsResponse>, ApiError> {
    let auth = require_auth(&state)?;
    let row = ensure_settings(&auth.pool, auth_bearer.user_id).await?;
    Ok(Json(row_to_app_settings(row)?))
}

/// Updates theme, proxy port, or local-cache preference.
pub(super) async fn update_app_settings(
    State(state): State<AppState>,
    auth_bearer: AuthBearer,
    Json(payload): Json<AppSettingsUpdateRequest>,
) -> Result<Json<AppSettingsResponse>, ApiError> {
    let auth = require_auth(&state)?;
    let current = ensure_settings(&auth.pool, auth_bearer.user_id).await?;
    let theme = match payload.theme {
        Some(theme) => validate_theme(&theme)?,
        None => current.try_get("theme")?,
    };
    let proxy_port = match payload.proxy_port {
        Some(port) => validate_port(port)?,
        None => current.try_get("proxy_port")?,
    };
    let local_cache_enabled = payload
        .local_cache_enabled
        .unwrap_or(current.try_get("local_cache_enabled")?);

    let row = sqlx::query(
        "UPDATE user_settings
         SET theme = $1, proxy_port = $2, local_cache_enabled = $3
         WHERE user_id = $4
         RETURNING theme, proxy_port, local_cache_enabled, api_key_openai, api_key_anthropic",
    )
    .bind(&theme)
    .bind(proxy_port)
    .bind(local_cache_enabled)
    .bind(auth_bearer.user_id)
    .fetch_one(&auth.pool)
    .await?;

    Ok(Json(row_to_app_settings(row)?))
}

/// Creates a settings row if missing and returns current settings.
pub(super) async fn ensure_settings(
    pool: &sqlx::PgPool,
    user_id: Uuid,
) -> Result<sqlx::postgres::PgRow, ApiError> {
    sqlx::query("INSERT INTO user_settings (user_id) VALUES ($1) ON CONFLICT (user_id) DO NOTHING")
        .bind(user_id)
        .execute(pool)
        .await?;

    sqlx::query(
        "SELECT theme, proxy_port, local_cache_enabled, api_key_openai, api_key_anthropic
         FROM user_settings
         WHERE user_id = $1",
    )
    .bind(user_id)
    .fetch_one(pool)
    .await
    .map_err(Into::into)
}

/// Converts a `user_settings` row into the public app settings response.
pub(super) fn row_to_app_settings(
    row: sqlx::postgres::PgRow,
) -> Result<AppSettingsResponse, ApiError> {
    let openai_key: Option<String> = row.try_get("api_key_openai")?;
    let anthropic_key: Option<String> = row.try_get("api_key_anthropic")?;

    Ok(AppSettingsResponse {
        theme: row.try_get("theme")?,
        proxy_port: row.try_get("proxy_port")?,
        local_cache_enabled: row.try_get("local_cache_enabled")?,
        has_openai_key: openai_key.is_some(),
        has_anthropic_key: anthropic_key.is_some(),
    })
}

/// Validates supported UI theme names.
fn validate_theme(theme: &str) -> Result<String, ApiError> {
    match theme {
        "system" | "light" | "dark" => Ok(theme.to_string()),
        _ => Err(ApiError::bad_request(
            "theme must be system, light, or dark",
        )),
    }
}

/// Validates the local proxy port range.
fn validate_port(port: i32) -> Result<i32, ApiError> {
    if !(1..=65535).contains(&port) {
        return Err(ApiError::bad_request(
            "proxy_port must be between 1 and 65535",
        ));
    }
    Ok(port)
}
