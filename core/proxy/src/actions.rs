use axum::{Json, Router, extract::State, http::StatusCode, response::IntoResponse, routing::post};
use rusqlite::params;
use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::AppState;

pub(crate) fn router() -> Router<AppState> {
    Router::new().route("/internal/actions/execute", post(execute_action))
}

#[derive(Deserialize)]
struct ExecuteRequest {
    action_id: String,
    action_type: String,
    payload: Value,
    token: Option<String>,
}

#[derive(Serialize)]
struct ExecuteResponse {
    action_id: String,
    status: String,
    error: String,
}

async fn execute_action(
    State(state): State<AppState>,
    Json(req): Json<ExecuteRequest>,
) -> impl IntoResponse {
    let has_token = req.token.as_ref().is_some_and(|token| !token.is_empty());
    let result = serde_json::json!({
        "error": "action execution is not implemented",
        "has_token": has_token
    });
    let response = ExecuteResponse {
        action_id: req.action_id.clone(),
        status: "failed".to_string(),
        error: "action execution is not implemented".to_string(),
    };
    let db = state.db.clone();

    let write_result = tokio::task::spawn_blocking(move || {
        let conn = db.lock().expect("tether: trace database lock poisoned");
        conn.execute(
            "INSERT OR REPLACE INTO repair_actions (
                id,
                session_id,
                caused_by,
                action_type,
                payload,
                status,
                result,
                created_at
            ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, unixepoch())",
            params![
                req.action_id,
                "local-default",
                req.payload
                    .get("caused_by")
                    .and_then(Value::as_str)
                    .unwrap_or("unknown"),
                req.action_type,
                req.payload.to_string(),
                "failed",
                result.to_string()
            ],
        )
    })
    .await;

    match write_result {
        Ok(Ok(_)) => (StatusCode::NOT_IMPLEMENTED, Json(response)).into_response(),
        Ok(Err(error)) => (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ExecuteResponse {
                action_id: response.action_id,
                status: "failed".to_string(),
                error: error.to_string(),
            }),
        )
            .into_response(),
        Err(error) => (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ExecuteResponse {
                action_id: response.action_id,
                status: "failed".to_string(),
                error: error.to_string(),
            }),
        )
            .into_response(),
    }
}
