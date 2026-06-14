//! Settings request and response DTOs.

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// User profile payload returned by profile endpoints.
#[derive(Debug, Serialize)]
pub(super) struct ProfileResponse {
    pub(super) id: Uuid,
    pub(super) email: String,
    pub(super) name: String,
    pub(super) created_at: DateTime<Utc>,
}

/// Optional profile fields that may be changed.
#[derive(Debug, Deserialize)]
pub(super) struct ProfileUpdateRequest {
    pub(super) name: Option<String>,
    pub(super) email: Option<String>,
}

/// App preference payload consumed by the settings UI.
#[derive(Debug, Serialize)]
pub(super) struct AppSettingsResponse {
    pub(super) theme: String,
    pub(super) proxy_port: i32,
    pub(super) local_cache_enabled: bool,
    pub(super) has_openai_key: bool,
    pub(super) has_anthropic_key: bool,
}

/// Optional app settings fields that may be changed.
#[derive(Debug, Deserialize)]
pub(super) struct AppSettingsUpdateRequest {
    pub(super) theme: Option<String>,
    pub(super) proxy_port: Option<i32>,
    pub(super) local_cache_enabled: Option<bool>,
}

/// Optional provider API-key values; empty strings clear stored keys.
#[derive(Debug, Deserialize)]
pub(super) struct ApiKeysUpdateRequest {
    pub(super) api_key_openai: Option<String>,
    pub(super) api_key_anthropic: Option<String>,
}

/// Generic mutation acknowledgement for key updates.
#[derive(Debug, Serialize)]
pub(super) struct UpdateResponse {
    pub(super) ok: bool,
}
