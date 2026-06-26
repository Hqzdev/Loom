//! Provider catalog endpoints.

use std::{
    sync::Arc,
    time::{Duration, Instant},
};

use axum::{Json, Router, extract::State, routing::get};
use serde::{Deserialize, Serialize};
use tokio::sync::RwLock;

use crate::{AppState, error::ApiError, settings::cometapi::load_cometapi_key};

const COMETAPI_MODELS_URL: &str = "https://api.cometapi.com/v1/models";
const MODEL_CACHE_TTL: Duration = Duration::from_secs(60 * 60);
const MODEL_LIMIT: usize = 50;

pub(crate) type CometModelCache = Arc<RwLock<Option<(Instant, Vec<ModelInfo>)>>>;

/// One model option returned to the macOS app.
#[derive(Clone, Debug, Serialize)]
pub(crate) struct ModelInfo {
    pub(crate) id: String,
    pub(crate) name: String,
    pub(crate) provider: String,
}

#[derive(Deserialize)]
struct ModelsResponse {
    data: Vec<RemoteModel>,
}

#[derive(Deserialize)]
struct RemoteModel {
    id: String,
    object: Option<String>,
    #[serde(default)]
    owned_by: Option<String>,
}

/// Mounts provider catalog endpoints.
pub(crate) fn router() -> Router<AppState> {
    Router::new().route("/api/providers/cometapi/models", get(cometapi_models))
}

async fn cometapi_models(State(state): State<AppState>) -> Result<Json<Vec<ModelInfo>>, ApiError> {
    if let Some(models) = cached_models(&state).await {
        return Ok(Json(models));
    }

    let api_key = load_cometapi_key(&state)
        .await?
        .ok_or_else(|| ApiError::unauthorized("CometAPI key is not configured"))?;
    let response = state
        .client
        .get(COMETAPI_MODELS_URL)
        .bearer_auth(api_key)
        .send()
        .await
        .map_err(|error| {
            ApiError::unavailable(format!("CometAPI models request failed: {error}"))
        })?;

    let status = response.status();
    let body = response
        .bytes()
        .await
        .map_err(|error| ApiError::unavailable(format!("CometAPI models read failed: {error}")))?;
    if !status.is_success() {
        return Err(ApiError::new(
            status,
            format!("CometAPI models error: {}", String::from_utf8_lossy(&body)),
        ));
    }

    let decoded: ModelsResponse = serde_json::from_slice(&body)
        .map_err(|error| ApiError::internal(format!("CometAPI models decode failed: {error}")))?;
    let models = sorted_models(decoded.data);
    let mut cache = state.comet_models.write().await;
    *cache = Some((Instant::now(), models.clone()));
    Ok(Json(models))
}

async fn cached_models(state: &AppState) -> Option<Vec<ModelInfo>> {
    let cache = state.comet_models.read().await;
    let Some((stored_at, models)) = &*cache else {
        return None;
    };
    if stored_at.elapsed() <= MODEL_CACHE_TTL {
        Some(models.clone())
    } else {
        None
    }
}

fn sorted_models(models: Vec<RemoteModel>) -> Vec<ModelInfo> {
    let mut models = models
        .into_iter()
        .filter(is_text_model)
        .map(|model| {
            let provider = provider_for(&model);
            ModelInfo {
                name: display_name(&model.id),
                id: model.id,
                provider,
            }
        })
        .collect::<Vec<_>>();
    models.sort_by(|a, b| {
        model_rank(&a.id)
            .cmp(&model_rank(&b.id))
            .then(a.name.cmp(&b.name))
    });
    models.truncate(MODEL_LIMIT);
    models
}

fn is_text_model(model: &RemoteModel) -> bool {
    if model.object.as_deref() != Some("model") {
        return false;
    }
    let id = model.id.to_ascii_lowercase();
    let blocked = [
        "embed",
        "embedding",
        "image",
        "audio",
        "tts",
        "whisper",
        "moderation",
        "rerank",
        "vision",
    ];
    !blocked.iter().any(|needle| id.contains(needle))
}

fn model_rank(id: &str) -> (u8, String) {
    let id = id.to_ascii_lowercase();
    let rank = if id.contains("gpt-4o") {
        0
    } else if id.contains("claude-3-5") || id.contains("claude-3.5") {
        1
    } else if id.contains("gemini-1.5-pro") || id.contains("gemini-1-5-pro") {
        2
    } else {
        3
    };
    (rank, id)
}

fn provider_for(model: &RemoteModel) -> String {
    let id = model.id.to_ascii_lowercase();
    if id.contains("claude") || model.owned_by.as_deref() == Some("anthropic") {
        "anthropic".to_string()
    } else if id.contains("gemini") || model.owned_by.as_deref() == Some("google") {
        "google".to_string()
    } else if id.starts_with("gpt-")
        || id.starts_with("o1")
        || id.starts_with("o3")
        || id.starts_with("o4")
    {
        "openai".to_string()
    } else {
        model
            .owned_by
            .clone()
            .filter(|provider| !provider.trim().is_empty())
            .unwrap_or_else(|| "other".to_string())
    }
}

fn display_name(id: &str) -> String {
    id.split(['-', '_', '/'])
        .filter(|part| !part.is_empty())
        .map(|part| {
            let mut chars = part.chars();
            match chars.next() {
                Some(first) => format!("{}{}", first.to_uppercase(), chars.as_str()),
                None => String::new(),
            }
        })
        .collect::<Vec<_>>()
        .join(" ")
}
