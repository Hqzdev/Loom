//! Local CometAPI settings backed by the proxy SQLite database.

use axum::{Json, extract::State};
use rusqlite::{OptionalExtension, params};

use crate::{AppState, error::ApiError};

use super::{
    types::{CometApiKeyRequest, CometApiKeyStatus, UpdateResponse},
    validation,
};

const COMETAPI_KEY: &str = "cometapi_key";

/// Stores or clears the CometAPI key in the local proxy settings table.
pub(super) async fn put_cometapi_key(
    State(state): State<AppState>,
    Json(payload): Json<CometApiKeyRequest>,
) -> Result<Json<UpdateResponse>, ApiError> {
    let db = state.db.clone();
    let api_key = validation::provider_key(&payload.api_key, "CometAPI key")?.unwrap_or_default();
    tokio::task::spawn_blocking(move || {
        let conn = db
            .lock()
            .map_err(|_| ApiError::internal("settings database lock poisoned"))?;
        if api_key.is_empty() {
            conn.execute(
                "DELETE FROM provider_settings WHERE key = ?1",
                [COMETAPI_KEY],
            )
            .map_err(|error| ApiError::internal(format!("settings database error: {error}")))?;
        } else {
            conn.execute(
                "INSERT INTO provider_settings (key, value)
                 VALUES (?1, ?2)
                 ON CONFLICT(key) DO UPDATE SET value = excluded.value",
                params![COMETAPI_KEY, api_key],
            )
            .map_err(|error| ApiError::internal(format!("settings database error: {error}")))?;
        }
        Ok::<_, ApiError>(())
    })
    .await
    .map_err(|error| ApiError::internal(format!("settings worker failed: {error}")))??;
    *state.comet_models.write().await = None;

    Ok(Json(UpdateResponse { ok: true }))
}

/// Returns whether a CometAPI key is configured without exposing the key.
pub(super) async fn get_cometapi_key_status(
    State(state): State<AppState>,
) -> Result<Json<CometApiKeyStatus>, ApiError> {
    let configured = load_cometapi_key(&state).await?.is_some();
    Ok(Json(CometApiKeyStatus { configured }))
}

/// Loads the CometAPI key for backend-only provider calls.
pub(crate) async fn load_cometapi_key(state: &AppState) -> Result<Option<String>, ApiError> {
    let db = state.db.clone();
    tokio::task::spawn_blocking(move || {
        let conn = db
            .lock()
            .map_err(|_| ApiError::internal("settings database lock poisoned"))?;
        conn.query_row(
            "SELECT value FROM provider_settings WHERE key = ?1",
            [COMETAPI_KEY],
            |row| row.get::<_, String>(0),
        )
        .optional()
        .map_err(|error| ApiError::internal(format!("settings database error: {error}")))
    })
    .await
    .map_err(|error| ApiError::internal(format!("settings worker failed: {error}")))?
}
