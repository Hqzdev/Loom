use axum::{
    Json,
    http::StatusCode,
    response::{IntoResponse, Response},
};
use serde::Serialize;

use crate::diagnostics;

/// HTTP error type returned by proxy API routes.
#[derive(Debug)]
pub(crate) struct ApiError {
    pub(crate) status: StatusCode,
    pub(crate) message: String,
}

#[derive(Serialize)]
struct ErrorBody<'a> {
    error: &'a str,
}

impl ApiError {
    /// Creates an API error with an explicit HTTP status and message.
    pub(crate) fn new(status: StatusCode, message: impl Into<String>) -> Self {
        Self {
            status,
            message: message.into(),
        }
    }

    /// Creates a 400 Bad Request API error.
    pub(crate) fn bad_request(message: impl Into<String>) -> Self {
        Self::new(StatusCode::BAD_REQUEST, message)
    }

    /// Creates a 401 Unauthorized API error.
    pub(crate) fn unauthorized(message: impl Into<String>) -> Self {
        Self::new(StatusCode::UNAUTHORIZED, message)
    }

    /// Creates a 403 Forbidden API error.
    pub(crate) fn forbidden(message: impl Into<String>) -> Self {
        Self::new(StatusCode::FORBIDDEN, message)
    }

    /// Creates a 409 Conflict API error.
    pub(crate) fn conflict(message: impl Into<String>) -> Self {
        Self::new(StatusCode::CONFLICT, message)
    }

    /// Creates a 503 Service Unavailable API error.
    pub(crate) fn unavailable(message: impl Into<String>) -> Self {
        Self::new(StatusCode::SERVICE_UNAVAILABLE, message)
    }

    /// Creates a 500 Internal Server Error API error.
    pub(crate) fn internal(message: impl Into<String>) -> Self {
        Self::new(StatusCode::INTERNAL_SERVER_ERROR, message)
    }
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        if self.status.is_server_error() {
            diagnostics::error(
                "api_error",
                serde_json::json!({
                    "status": self.status.as_u16(),
                    "message": self.message
                }),
            );
        }
        let body = Json(ErrorBody {
            error: self.message.as_str(),
        });
        (self.status, body).into_response()
    }
}

impl From<tether_crypto::CryptoError> for ApiError {
    fn from(error: tether_crypto::CryptoError) -> Self {
        ApiError::internal(error.message())
    }
}

impl From<sqlx::Error> for ApiError {
    fn from(error: sqlx::Error) -> Self {
        if let sqlx::Error::Database(db_error) = &error
            && db_error.code().as_deref() == Some("23505")
        {
            return ApiError::conflict("record already exists");
        }

        diagnostics::error(
            "database_error",
            serde_json::json!({
                "error": error.to_string()
            }),
        );
        ApiError::internal("database error")
    }
}
