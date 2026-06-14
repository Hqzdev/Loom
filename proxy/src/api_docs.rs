//! Static API documentation endpoints.

use axum::{
    Router,
    http::{HeaderValue, header::CONTENT_TYPE},
    response::IntoResponse,
    routing::get,
};

use crate::AppState;

const OPENAPI_JSON: &str = include_str!("../../docs/api/openapi.json");

/// Mounts documentation endpoints that do not touch application state.
pub(crate) fn router() -> Router<AppState> {
    Router::new().route("/openapi.json", get(openapi_json))
}

/// Serves the committed OpenAPI contract used by the Swift app and docs.
async fn openapi_json() -> impl IntoResponse {
    (
        [(CONTENT_TYPE, HeaderValue::from_static("application/json"))],
        OPENAPI_JSON,
    )
}
