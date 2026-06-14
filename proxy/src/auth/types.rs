//! Auth request/response DTOs and row mapping helpers.

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::Row;
use uuid::Uuid;

use crate::error::ApiError;

use super::{AuthContext, jwt::ACCESS_TOKEN_TTL_SECONDS};

/// Authenticated user returned to the app.
#[derive(Debug, Serialize)]
pub(crate) struct UserDto {
    pub(crate) id: Uuid,
    pub(crate) email: String,
    pub(crate) name: String,
    pub(crate) created_at: DateTime<Utc>,
}

/// Local account registration payload.
#[derive(Debug, Deserialize)]
pub(crate) struct RegisterRequest {
    pub(crate) email: String,
    pub(crate) name: String,
    pub(crate) password: String,
}

/// Local account login payload.
#[derive(Debug, Deserialize)]
pub(crate) struct LoginRequest {
    pub(crate) email: String,
    pub(crate) password: String,
}

/// Successful auth response with bearer token and user metadata.
#[derive(Debug, Serialize)]
pub(crate) struct AuthResponse {
    pub(crate) access_token: String,
    pub(crate) token_type: &'static str,
    pub(crate) expires_in: i64,
    pub(crate) user: UserDto,
}

/// Builds the shared auth response format after login/OAuth/register.
pub(crate) fn auth_response(auth: &AuthContext, user: UserDto) -> Result<AuthResponse, ApiError> {
    let access_token = auth.jwt.issue(user.id)?;
    Ok(AuthResponse {
        access_token,
        token_type: "Bearer",
        expires_in: ACCESS_TOKEN_TTL_SECONDS,
        user,
    })
}

/// Converts a Postgres users row into the public user DTO.
pub(crate) fn row_to_user(row: sqlx::postgres::PgRow) -> Result<UserDto, ApiError> {
    Ok(UserDto {
        id: row.try_get("id")?,
        email: row.try_get("email")?,
        name: row.try_get("name")?,
        created_at: row.try_get("created_at")?,
    })
}

/// Normalizes and validates an email address for login/profile usage.
pub(crate) fn normalize_email(email: &str) -> Result<String, ApiError> {
    let email = email.trim().to_ascii_lowercase();
    if !email.contains('@') || email.len() > 320 {
        return Err(ApiError::bad_request("valid email is required"));
    }
    Ok(email)
}
