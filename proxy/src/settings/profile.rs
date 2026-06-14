//! Profile settings route handlers.

use axum::{Json, extract::State};
use sqlx::Row;

use crate::{
    AppState,
    auth::{extractor::AuthBearer, normalize_email, require_auth},
    error::ApiError,
};

use super::types::{ProfileResponse, ProfileUpdateRequest};

/// Returns the authenticated user's current profile.
pub(super) async fn profile(
    State(state): State<AppState>,
    auth_bearer: AuthBearer,
) -> Result<Json<ProfileResponse>, ApiError> {
    let auth = require_auth(&state)?;
    let row = sqlx::query("SELECT id, email, name, created_at FROM users WHERE id = $1")
        .bind(auth_bearer.user_id)
        .fetch_optional(&auth.pool)
        .await?
        .ok_or_else(|| ApiError::unauthorized("user no longer exists"))?;

    Ok(Json(ProfileResponse {
        id: row.try_get("id")?,
        email: row.try_get("email")?,
        name: row.try_get("name")?,
        created_at: row.try_get("created_at")?,
    }))
}

/// Updates the authenticated user's name and/or email.
pub(super) async fn update_profile(
    State(state): State<AppState>,
    auth_bearer: AuthBearer,
    Json(payload): Json<ProfileUpdateRequest>,
) -> Result<Json<ProfileResponse>, ApiError> {
    let auth = require_auth(&state)?;
    let current = sqlx::query("SELECT email, name FROM users WHERE id = $1")
        .bind(auth_bearer.user_id)
        .fetch_optional(&auth.pool)
        .await?
        .ok_or_else(|| ApiError::unauthorized("user no longer exists"))?;

    let name = match payload.name {
        Some(name) => normalize_name(&name)?,
        None => current.try_get("name")?,
    };
    let email = match payload.email {
        Some(email) => normalize_email(&email)?,
        None => current.try_get("email")?,
    };

    let row = sqlx::query(
        "UPDATE users
         SET name = $1, email = $2
         WHERE id = $3
         RETURNING id, email, name, created_at",
    )
    .bind(&name)
    .bind(&email)
    .bind(auth_bearer.user_id)
    .fetch_one(&auth.pool)
    .await
    .map_err(map_unique_email_error)?;

    Ok(Json(ProfileResponse {
        id: row.try_get("id")?,
        email: row.try_get("email")?,
        name: row.try_get("name")?,
        created_at: row.try_get("created_at")?,
    }))
}

/// Normalizes and validates a display name for profile storage.
fn normalize_name(name: &str) -> Result<String, ApiError> {
    let name = name.trim();
    if name.is_empty() || name.len() > 120 {
        return Err(ApiError::bad_request(
            "name must be between 1 and 120 characters",
        ));
    }
    Ok(name.to_string())
}

/// Maps duplicate email updates to the settings API conflict response.
fn map_unique_email_error(error: sqlx::Error) -> ApiError {
    if let sqlx::Error::Database(db_error) = &error {
        if db_error.code().as_deref() == Some("23505") {
            return ApiError::conflict("email already exists");
        }
    }
    error.into()
}
