use axum::{Json, Router, extract::State, http::StatusCode, routing::get};
use chrono::Utc;
use serde::Serialize;
use serde_json::{Value, json, to_value};
use sqlx::query_scalar;
use std::sync::Arc;

use crate::{AppState, auth::AuthContext};

#[derive(Serialize)]
struct CheckStatus {
    status: &'static str,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<String>,
    healthy: bool,
}

pub(crate) fn router() -> Router<AppState> {
    Router::new()
        .route("/healthz", get(healthz))
        .route("/readyz", get(readyz))
}

async fn healthz() -> StatusCode {
    StatusCode::OK
}

async fn readyz(State(state): State<AppState>) -> (StatusCode, Json<Value>) {
    let require_auth_db = matches!(
        std::env::var("TETHER_REQUIRE_AUTH_DB").as_deref(),
        Ok("1") | Ok("true") | Ok("on")
    );
    let sqlite = validate_sqlite(&state).await;
    let auth = validate_auth(state.auth.clone(), require_auth_db).await;
    let ready = sqlite.healthy && auth.healthy;

    let payload = json!({
        "status": if ready { "ok" } else { "degraded" },
        "timestamp": Utc::now(),
        "checks": {
            "sqlite": to_value(sqlite).unwrap_or_else(|_| json!({"status":"unhealthy","error":"cannot serialize sqlite check","healthy":false})),
            "auth": to_value(auth).unwrap_or_else(|_| json!({"status":"unhealthy","error":"cannot serialize auth check","healthy":false})),
            "cache": "ok",
            "version": env!("CARGO_PKG_VERSION")
        }
    });

    if ready {
        (StatusCode::OK, Json(payload))
    } else {
        (StatusCode::SERVICE_UNAVAILABLE, Json(payload))
    }
}

async fn validate_sqlite(state: &AppState) -> CheckStatus {
    let db = state.db.clone();
    let check = tokio::task::spawn_blocking(move || {
        let conn = db.lock().map_err(|error| error.to_string())?;
        let value: i64 = conn
            .query_row("SELECT 1", (), |row| row.get(0))
            .map_err(|error| error.to_string())?;
        if value == 1 {
            Ok(())
        } else {
            Err("sqlite readiness query returned unexpected value".to_string())
        }
    })
    .await;

    match check {
        Ok(Ok(_)) => CheckStatus {
            status: "ok",
            error: None,
            healthy: true,
        },
        Ok(Err(error)) => CheckStatus {
            status: "unhealthy",
            error: Some(error),
            healthy: false,
        },
        Err(error) => CheckStatus {
            status: "unhealthy",
            error: Some(error.to_string()),
            healthy: false,
        },
    }
}

async fn validate_auth(auth: Option<Arc<AuthContext>>, require_auth_db: bool) -> CheckStatus {
    let Some(auth) = auth else {
        if require_auth_db {
            return CheckStatus {
                status: "unhealthy",
                error: Some("DATABASE_URL is not configured".to_string()),
                healthy: false,
            };
        }

        return CheckStatus {
            status: "disabled",
            error: Some("DATABASE_URL is not configured".to_string()),
            healthy: true,
        };
    };

    match query_scalar("SELECT 1")
        .fetch_one(&auth.pool)
        .await
        .map(|value: i32| value == 1)
    {
        Ok(true) => CheckStatus {
            status: "ok",
            error: None,
            healthy: true,
        },
        Ok(false) => CheckStatus {
            status: "unhealthy",
            error: Some("query returned false".to_string()),
            healthy: false,
        },
        Err(error) => CheckStatus {
            status: "unhealthy",
            error: Some(error.to_string()),
            healthy: false,
        },
    }
}
