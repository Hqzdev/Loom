//! User settings service: profile, app preferences, and stored provider keys.

mod app;
pub(crate) mod cometapi;
mod keys;
mod profile;
mod types;
mod validation;

use axum::{Router, routing::get};

use crate::AppState;

/// Mounts profile, app settings, and API-key settings endpoints.
pub(crate) fn router() -> Router<AppState> {
    Router::new()
        .route("/api/settings/profile", get(profile::profile))
        .route(
            "/api/settings/profile/update",
            axum::routing::post(profile::update_profile),
        )
        .route("/api/settings/app", get(app::app_settings))
        .route(
            "/api/settings/app/update",
            axum::routing::post(app::update_app_settings),
        )
        .route(
            "/api/settings/keys",
            axum::routing::post(keys::update_api_keys),
        )
        .route(
            "/api/settings/cometapi-key",
            get(cometapi::get_cometapi_key_status).put(cometapi::put_cometapi_key),
        )
}
