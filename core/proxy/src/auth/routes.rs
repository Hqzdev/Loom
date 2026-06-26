//! Local auth route handlers and auth router assembly.

use axum::{Json, Router, extract::State, http::StatusCode, routing::get};
use sqlx::Row;

use crate::{AppState, error::ApiError};

use super::{
    AuthResponse, LoginRequest, RegisterRequest, auth_response, normalize_email, oauth,
    password::{hash_password, validate_password, verify_password},
    require_auth, row_to_user,
};

/// Mounts local credential and Google OAuth auth endpoints.
pub(crate) fn router() -> Router<AppState> {
    Router::new()
        .route("/api/auth/register", axum::routing::post(register))
        .route("/api/auth/login", axum::routing::post(login))
        .route("/api/auth/oauth/google", get(oauth::google_start))
        .route(
            "/api/auth/oauth/google/callback",
            get(oauth::google_callback),
        )
}

/// Creates a local account and returns its bearer token.
async fn register(
    State(state): State<AppState>,
    Json(payload): Json<RegisterRequest>,
) -> Result<(StatusCode, Json<AuthResponse>), ApiError> {
    let auth = require_auth(&state)?;
    let email = normalize_email(&payload.email)?;
    let name = normalize_name(&payload.name)?;
    validate_password(&payload.password)?;
    let password_hash = hash_password(&payload.password)?;

    let mut tx = auth.pool.begin().await?;
    let user = sqlx::query(
        "INSERT INTO users (email, name, password_hash)
         VALUES ($1, $2, $3)
         RETURNING id, email, name, created_at",
    )
    .bind(&email)
    .bind(&name)
    .bind(&password_hash)
    .fetch_one(&mut *tx)
    .await
    .map_err(map_unique_user_error)?;

    let user = row_to_user(user)?;
    sqlx::query("INSERT INTO user_settings (user_id) VALUES ($1)")
        .bind(user.id)
        .execute(&mut *tx)
        .await?;
    tx.commit().await?;
    auth.ensure_default_role(user.id).await?;

    Ok((StatusCode::CREATED, Json(auth_response(&auth, user)?)))
}

/// Verifies local credentials and returns a bearer token.
async fn login(
    State(state): State<AppState>,
    Json(payload): Json<LoginRequest>,
) -> Result<Json<AuthResponse>, ApiError> {
    let auth = require_auth(&state)?;
    let email = normalize_email(&payload.email)?;
    let row = sqlx::query(
        "SELECT id, email, name, password_hash, created_at
         FROM users
         WHERE email = $1",
    )
    .bind(&email)
    .fetch_optional(&auth.pool)
    .await?
    .ok_or_else(|| ApiError::unauthorized("invalid email or password"))?;

    let password_hash = row
        .try_get::<Option<String>, _>("password_hash")?
        .ok_or_else(|| ApiError::unauthorized("this account uses Google sign-in"))?;
    verify_password(&payload.password, &password_hash)?;

    let user = row_to_user(row)?;
    Ok(Json(auth_response(&auth, user)?))
}

/// Normalizes and validates a user's display name.
fn normalize_name(name: &str) -> Result<String, ApiError> {
    let name = name.trim();
    if name.is_empty() || name.len() > 120 {
        return Err(ApiError::bad_request(
            "name must be between 1 and 120 characters",
        ));
    }
    Ok(name.to_string())
}

/// Maps unique-email database failures to a stable auth API error.
fn map_unique_user_error(error: sqlx::Error) -> ApiError {
    if let sqlx::Error::Database(db_error) = &error
        && db_error.code().as_deref() == Some("23505")
    {
        return ApiError::conflict("email already exists");
    }
    error.into()
}
