//! Provider API-key settings route handler.

use axum::{Json, extract::State};
use sqlx::Row;

use crate::{
    AppState,
    auth::{extractor::AuthBearer, require_auth},
    error::ApiError,
};

use super::{
    app::ensure_settings,
    types::{ApiKeysUpdateRequest, UpdateResponse},
    validation,
};

/// Updates or clears encrypted provider API keys for the authenticated user.
pub(super) async fn update_api_keys(
    State(state): State<AppState>,
    auth_bearer: AuthBearer,
    Json(payload): Json<ApiKeysUpdateRequest>,
) -> Result<Json<UpdateResponse>, ApiError> {
    let auth = require_auth(&state)?;
    let cipher = auth
        .key_cipher
        .as_ref()
        .ok_or_else(|| ApiError::unavailable("AGENTTRACE_KEYS_SECRET is not configured"))?;
    let current = ensure_settings(&auth.pool, auth_bearer.user_id).await?;

    let openai_key = match payload.api_key_openai {
        Some(value) => validation::provider_key(&value, "OpenAI API key")?
            .map(|value| cipher.encrypt(&value))
            .transpose()?,
        None => current.try_get("api_key_openai")?,
    };
    let anthropic_key = match payload.api_key_anthropic {
        Some(value) => validation::provider_key(&value, "Anthropic API key")?
            .map(|value| cipher.encrypt(&value))
            .transpose()?,
        None => current.try_get("api_key_anthropic")?,
    };

    sqlx::query(
        "UPDATE user_settings
         SET api_key_openai = $1, api_key_anthropic = $2
         WHERE user_id = $3",
    )
    .bind(openai_key)
    .bind(anthropic_key)
    .bind(auth_bearer.user_id)
    .execute(&auth.pool)
    .await?;

    Ok(Json(UpdateResponse { ok: true }))
}
