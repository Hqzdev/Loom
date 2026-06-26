use std::collections::{HashMap, HashSet};
use std::sync::Arc;
use std::time::{Duration, Instant};

use axum::{
    Json,
    body::{Body, to_bytes},
    extract::State,
    http::{
        HeaderMap, HeaderName, HeaderValue, Method, Request, StatusCode, header::AUTHORIZATION,
    },
    middleware::Next,
    response::{IntoResponse, Response},
};
use bytes::Bytes;
use serde::Serialize;
use serde_json::json;
use sha2::{Digest, Sha256};

use crate::{AppState, auth::require_auth, diagnostics};

const IDEMPOTENCY_HEADER: &str = "idempotency-key";
const IDEMPOTENCY_TTL_SECONDS: u64 = 600;
const IDEMPOTENCY_BODY_LIMIT_BYTES: usize = 1024 * 1024;

#[derive(Clone)]
pub(crate) struct FeatureFlags {
    disabled: HashSet<String>,
}

impl FeatureFlags {
    pub(crate) fn from_env() -> Self {
        let disabled = std::env::var("TETHER_DISABLED_FEATURES")
            .unwrap_or_default()
            .split(',')
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(|value| value.to_ascii_lowercase())
            .collect();
        Self { disabled }
    }

    pub(crate) fn is_enabled(&self, feature: &str) -> bool {
        !self.disabled.contains(&feature.to_ascii_lowercase())
    }
}

#[derive(Clone, Copy)]
struct RateLimitProfile {
    limit: u32,
    window: Duration,
}

#[derive(Clone)]
pub(crate) struct RateLimiter {
    buckets: Arc<tokio::sync::Mutex<HashMap<String, RateBucket>>>,
}

#[derive(Clone)]
struct RateBucket {
    used: u32,
    window_until: Instant,
}

impl RateLimiter {
    pub(crate) fn new() -> Self {
        Self {
            buckets: Arc::new(tokio::sync::Mutex::new(HashMap::new())),
        }
    }

    async fn check_and_record(&self, key: String, profile: RateLimitProfile) -> Option<u64> {
        let now = Instant::now();
        let mut buckets = self.buckets.lock().await;
        let bucket = buckets.entry(key).or_insert(RateBucket {
            used: 0,
            window_until: now + profile.window,
        });

        if now >= bucket.window_until {
            bucket.used = 0;
            bucket.window_until = now + profile.window;
        }

        if bucket.used >= profile.limit {
            return Some((bucket.window_until - now).as_secs().max(1));
        }

        bucket.used += 1;
        None
    }
}

#[derive(Clone)]
pub(crate) struct IdempotencyStore {
    entries: Arc<tokio::sync::Mutex<HashMap<String, IdempotencyEntry>>>,
}

#[derive(Clone)]
enum IdempotencyEntry {
    InProgress { expires_at: Instant },
    Completed { response: IdempotentResponse },
}

#[derive(Clone)]
struct IdempotentResponse {
    status: StatusCode,
    headers: axum::http::HeaderMap,
    body: Bytes,
    fingerprint: String,
    expires_at: Instant,
}

#[derive(Clone)]
enum IdempotencyDecision {
    Allow,
    Replay(IdempotentResponse),
    InProgress,
    Conflict,
}

impl IdempotencyStore {
    pub(crate) fn new() -> Self {
        Self {
            entries: Arc::new(tokio::sync::Mutex::new(HashMap::new())),
        }
    }

    async fn prune_expired(&self) {
        let now = Instant::now();
        let mut entries = self.entries.lock().await;
        entries.retain(|_, entry| match entry {
            IdempotencyEntry::InProgress { expires_at } => *expires_at > now,
            IdempotencyEntry::Completed { response } => response.expires_at > now,
        });
    }

    async fn start_or_replay(&self, key: &str, fingerprint: &str) -> IdempotencyDecision {
        self.prune_expired().await;
        let mut entries = self.entries.lock().await;

        match entries.get(key) {
            Some(IdempotencyEntry::Completed { response }) => {
                if response.fingerprint == fingerprint {
                    return IdempotencyDecision::Replay(response.clone());
                }
                return IdempotencyDecision::Conflict;
            }
            Some(IdempotencyEntry::InProgress { .. }) => return IdempotencyDecision::InProgress,
            None => {
                entries.insert(
                    key.to_string(),
                    IdempotencyEntry::InProgress {
                        expires_at: Instant::now() + Duration::from_secs(IDEMPOTENCY_TTL_SECONDS),
                    },
                );
                IdempotencyDecision::Allow
            }
        }
    }

    async fn complete(
        &self,
        key: &str,
        fingerprint: String,
        status: StatusCode,
        headers: axum::http::HeaderMap,
        body: Bytes,
    ) {
        let mut entries = self.entries.lock().await;
        entries.insert(
            key.to_string(),
            IdempotencyEntry::Completed {
                response: IdempotentResponse {
                    status,
                    headers,
                    body,
                    fingerprint,
                    expires_at: Instant::now() + Duration::from_secs(IDEMPOTENCY_TTL_SECONDS),
                },
            },
        );
    }
}

#[derive(Clone)]
struct RoutePolicy {
    permission: Option<&'static str>,
    rate: RateLimitProfile,
    require_auth: bool,
    idempotent: bool,
    feature: &'static str,
}

impl RoutePolicy {
    const fn public() -> Self {
        Self {
            permission: None,
            rate: RateLimitProfile {
                limit: 300,
                window: Duration::from_secs(60),
            },
            require_auth: false,
            idempotent: false,
            feature: "public",
        }
    }

    const fn api(permission: &'static str) -> Self {
        Self {
            permission: Some(permission),
            rate: RateLimitProfile {
                limit: 180,
                window: Duration::from_secs(60),
            },
            require_auth: true,
            idempotent: false,
            feature: "api",
        }
    }
}

#[derive(Serialize)]
struct ErrorBody<'a> {
    error: &'a str,
}

fn is_api_scope(path: &str) -> bool {
    path == "/openapi.json" || path.starts_with("/api") || path.starts_with("/internal")
}

fn route_policy(method: &Method, path: &str) -> RoutePolicy {
    if path == "/openapi.json" {
        return RoutePolicy {
            permission: None,
            rate: RateLimitProfile {
                limit: 180,
                window: Duration::from_secs(60),
            },
            require_auth: false,
            idempotent: false,
            feature: "public",
        };
    }

    if path.starts_with("/api/auth/") {
        return RoutePolicy {
            permission: None,
            rate: RateLimitProfile {
                limit: 40,
                window: Duration::from_secs(60),
            },
            require_auth: false,
            idempotent: method == Method::POST,
            feature: "auth",
        };
    }

    if path == "/api/events" {
        return RoutePolicy {
            permission: Some("traces:write"),
            rate: RateLimitProfile {
                limit: 120,
                window: Duration::from_secs(60),
            },
            require_auth: true,
            idempotent: true,
            feature: "events",
        };
    }

    if path == "/api/events/health" {
        return RoutePolicy {
            permission: None,
            rate: RateLimitProfile {
                limit: 120,
                window: Duration::from_secs(60),
            },
            require_auth: false,
            idempotent: false,
            feature: "events",
        };
    }

    if path == "/api/cache" {
        return RoutePolicy {
            permission: Some("traces:write"),
            rate: RateLimitProfile {
                limit: 120,
                window: Duration::from_secs(60),
            },
            require_auth: true,
            idempotent: method == Method::DELETE,
            feature: "traces",
        };
    }

    if path == "/api/settings/profile" {
        return RoutePolicy {
            permission: Some("settings:read"),
            rate: RateLimitProfile {
                limit: 120,
                window: Duration::from_secs(60),
            },
            require_auth: true,
            idempotent: false,
            feature: "settings",
        };
    }

    if path == "/api/settings/app"
        || path == "/api/settings/profile/update"
        || path == "/api/settings/app/update"
        || path == "/api/settings/keys"
    {
        return RoutePolicy {
            permission: if method == Method::GET {
                Some("settings:read")
            } else {
                Some("settings:write")
            },
            rate: RateLimitProfile {
                limit: 120,
                window: Duration::from_secs(60),
            },
            require_auth: true,
            idempotent: method != Method::GET && method != Method::DELETE,
            feature: "settings",
        };
    }

    if path == "/api/settings/cometapi-key" {
        return RoutePolicy {
            permission: if method == Method::GET {
                Some("settings:read")
            } else {
                Some("settings:write")
            },
            rate: RateLimitProfile {
                limit: 120,
                window: Duration::from_secs(60),
            },
            require_auth: true,
            idempotent: method == Method::PUT,
            feature: "settings",
        };
    }

    if path == "/api/providers/cometapi/models" {
        return RoutePolicy {
            permission: Some("providers:read"),
            rate: RateLimitProfile {
                limit: 60,
                window: Duration::from_secs(60),
            },
            require_auth: true,
            idempotent: false,
            feature: "providers",
        };
    }

    if path == "/internal/actions/execute" {
        return RoutePolicy {
            permission: Some("actions:execute"),
            rate: RateLimitProfile {
                limit: 30,
                window: Duration::from_secs(60),
            },
            require_auth: true,
            idempotent: true,
            feature: "actions",
        };
    }

    if path == "/api/traces/current" {
        if method == &Method::DELETE {
            return RoutePolicy {
                permission: Some("traces:write"),
                rate: RateLimitProfile {
                    limit: 120,
                    window: Duration::from_secs(60),
                },
                require_auth: true,
                idempotent: true,
                feature: "traces",
            };
        }

        return RoutePolicy {
            permission: Some("traces:read"),
            rate: RateLimitProfile {
                limit: 180,
                window: Duration::from_secs(60),
            },
            require_auth: true,
            idempotent: false,
            feature: "traces",
        };
    }

    if path == "/api/traces/current/summary" {
        return RoutePolicy {
            permission: Some("traces:read"),
            rate: RateLimitProfile {
                limit: 180,
                window: Duration::from_secs(60),
            },
            require_auth: true,
            idempotent: false,
            feature: "traces",
        };
    }

    if path.starts_with("/api/traces/") {
        if path.ends_with("/output") {
            return RoutePolicy {
                permission: Some("traces:write"),
                rate: RateLimitProfile {
                    limit: 120,
                    window: Duration::from_secs(60),
                },
                require_auth: true,
                idempotent: method == &Method::PATCH,
                feature: "traces",
            };
        }

        if path.ends_with("/replay") || path.ends_with("/replay-with") {
            return RoutePolicy {
                permission: Some("traces:replay"),
                rate: RateLimitProfile {
                    limit: 60,
                    window: Duration::from_secs(60),
                },
                require_auth: true,
                idempotent: true,
                feature: "traces",
            };
        }

        return RoutePolicy {
            permission: Some("traces:read"),
            rate: RateLimitProfile {
                limit: 180,
                window: Duration::from_secs(60),
            },
            require_auth: true,
            idempotent: false,
            feature: "traces",
        };
    }

    if path.starts_with("/api/") {
        return RoutePolicy::api("access:api");
    }

    if path.starts_with("/internal") {
        return RoutePolicy {
            permission: Some("actions:execute"),
            rate: RateLimitProfile {
                limit: 60,
                window: Duration::from_secs(60),
            },
            require_auth: true,
            idempotent: false,
            feature: "internal",
        };
    }

    RoutePolicy::public()
}

pub(crate) async fn api_security_guard(
    State(state): State<AppState>,
    request: Request<Body>,
    next: Next,
) -> Response {
    let path = request.uri().path().to_string();
    let method = request.method().clone();
    let request_id = request
        .headers()
        .get("x-request-id")
        .and_then(|value| value.to_str().ok())
        .map(str::to_string);
    let has_authorization = request.headers().contains_key(AUTHORIZATION);
    if !is_api_scope(&path) {
        return next.run(request).await;
    }

    let policy = route_policy(&method, &path);
    let started_at = Instant::now();
    let mut outcome = "ok";

    let response = if !state.feature_flags.is_enabled(policy.feature) {
        outcome = "feature_disabled";
        (
            StatusCode::SERVICE_UNAVAILABLE,
            Json(ErrorBody {
                error: "feature disabled",
            }),
        )
            .into_response()
    } else {
        let response = if state.feature_flags.is_enabled("rate-limiting") {
            let key = rate_limit_key(request.headers(), request.method(), &path);
            if let Some(retry_after) = state.rate_limiter.check_and_record(key, policy.rate).await {
                outcome = "rate_limited";
                diagnostics::warn(
                    "rate_limit_exceeded",
                    json!({
                        "path": path,
                        "retry_after_seconds": retry_after,
                    }),
                );
                rate_limit_response(retry_after)
            } else if policy.require_auth {
                if let Some(response) =
                    require_authorization(&state, request.headers(), &path, policy.permission).await
                {
                    outcome = match response.status() {
                        StatusCode::UNAUTHORIZED => "auth_missing",
                        StatusCode::FORBIDDEN => "permission_denied",
                        _ => "authorization_failed",
                    };
                    response
                } else if policy.idempotent && state.feature_flags.is_enabled("idempotency") {
                    process_idempotent(state, request, next).await
                } else {
                    next.run(request).await
                }
            } else if policy.idempotent && state.feature_flags.is_enabled("idempotency") {
                process_idempotent(state, request, next).await
            } else {
                next.run(request).await
            }
        } else if policy.require_auth {
            if let Some(response) =
                require_authorization(&state, request.headers(), &path, policy.permission).await
            {
                outcome = match response.status() {
                    StatusCode::UNAUTHORIZED => "auth_missing",
                    StatusCode::FORBIDDEN => "permission_denied",
                    _ => "authorization_failed",
                };
                response
            } else if policy.idempotent && state.feature_flags.is_enabled("idempotency") {
                process_idempotent(state, request, next).await
            } else {
                next.run(request).await
            }
        } else if policy.idempotent && state.feature_flags.is_enabled("idempotency") {
            process_idempotent(state, request, next).await
        } else {
            next.run(request).await
        };

        response
    };

    emit_api_request_event(
        &method,
        &path,
        response.status(),
        started_at.elapsed(),
        outcome,
        &policy,
        has_authorization,
        request_id.as_deref(),
    );

    response
}

fn rate_limit_key(headers: &HeaderMap, method: &Method, path: &str) -> String {
    match headers
        .get(AUTHORIZATION)
        .and_then(|value| value.to_str().ok())
    {
        Some(token) if token.len() <= 16 => {
            let mut hasher = Sha256::new();
            hasher.update(token.as_bytes());
            format!("token:{:x}|{}|{}", hasher.finalize(), method.as_str(), path)
        }
        _ => {
            let client = request_client(headers);
            format!("{client}|{}|{path}", method.as_str())
        }
    }
}

fn request_client(headers: &HeaderMap) -> String {
    if let Some(raw) = headers
        .get("x-forwarded-for")
        .and_then(|value| value.to_str().ok())
    {
        return raw
            .split(',')
            .next()
            .map(str::trim)
            .unwrap_or("unknown")
            .to_string();
    }

    if let Some(raw) = headers
        .get("x-real-ip")
        .and_then(|value| value.to_str().ok())
    {
        return raw.trim().to_string();
    }

    "unknown".to_string()
}

fn rate_limit_response(retry_after: u64) -> Response {
    let mut response = (
        StatusCode::TOO_MANY_REQUESTS,
        Json(ErrorBody {
            error: "rate limit exceeded",
        }),
    )
        .into_response();
    response.headers_mut().insert(
        HeaderName::from_static("retry-after"),
        HeaderValue::from_str(&retry_after.to_string()).unwrap_or(HeaderValue::from_static("1")),
    );
    response
}

async fn require_authorization(
    state: &AppState,
    headers: &HeaderMap,
    path: &str,
    permission: Option<&str>,
) -> Option<Response> {
    let auth = require_auth(state).ok()?;
    let token = headers
        .get(AUTHORIZATION)
        .and_then(|value| value.to_str().ok())
        .and_then(|value| value.strip_prefix("Bearer "))
        .map(str::trim)
        .filter(|token| !token.is_empty())
        .ok_or_else(|| {
            diagnostics::warn("auth_token_missing", json!({"path": path}));
            StatusCode::UNAUTHORIZED
        })
        .ok()?;

    let claims = match auth.jwt.verify(token) {
        Ok(claims) => claims,
        Err(error) => return Some(error.into_response()),
    };

    let Some(permission) = permission else {
        return None;
    };

    if !state.feature_flags.is_enabled("rbac") {
        return None;
    }

    match auth.has_permission(claims.sub, permission).await {
        Ok(true) => None,
        Ok(false) => Some(
            (
                StatusCode::FORBIDDEN,
                Json(ErrorBody {
                    error: "insufficient permissions",
                }),
            )
                .into_response(),
        ),
        Err(error) => Some(error.into_response()),
    }
}

async fn process_idempotent(state: AppState, request: Request<Body>, next: Next) -> Response {
    let request_key = request
        .headers()
        .get(IDEMPOTENCY_HEADER)
        .and_then(|value| value.to_str().ok())
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(str::to_string);

    let Some(idempotency_key) = request_key else {
        diagnostics::warn(
            "idempotency_key_missing",
            json!({"path": request.uri().path()}),
        );
        return next.run(request).await;
    };

    let (parts, body) = request.into_parts();
    let request_body = match to_bytes(body, IDEMPOTENCY_BODY_LIMIT_BYTES).await {
        Ok(value) => value,
        Err(error) => {
            diagnostics::warn(
                "idempotency_request_read_failed",
                json!({
                    "path": parts.uri.path(),
                    "error": error.to_string(),
                }),
            );
            return (
                StatusCode::BAD_REQUEST,
                Json(ErrorBody {
                    error: "unable to read request body for idempotency",
                }),
            )
                .into_response();
        }
    };

    let request = Request::from_parts(parts, Body::from(request_body.clone()));
    let scope = format!(
        "{}:{}:{}",
        idempotency_subject(request.headers()),
        request.uri().path(),
        idempotency_key
    );
    let fingerprint = request_fingerprint(request.method(), request.uri().path(), &request_body);

    let request_idempotency = state
        .idempotency_store
        .start_or_replay(&scope, &fingerprint)
        .await;
    match request_idempotency {
        IdempotencyDecision::Replay(cached) => {
            return replay_response(cached);
        }
        IdempotencyDecision::Conflict => {
            diagnostics::warn("idempotency_reused_different_body", json!({"scope": scope}));
            return (
                StatusCode::CONFLICT,
                Json(ErrorBody {
                    error: "idempotency key was reused with a different request",
                }),
            )
                .into_response();
        }
        IdempotencyDecision::InProgress => {
            diagnostics::warn("idempotency_key_inflight", json!({"scope": scope}));
            return (
                StatusCode::CONFLICT,
                Json(ErrorBody {
                    error: "idempotency key is still processing",
                }),
            )
                .into_response();
        }
        IdempotencyDecision::Allow => {}
    }

    let response = next.run(request).await;
    let status = response.status();
    let (parts, body) = response.into_parts();
    let response_body = match to_bytes(body, IDEMPOTENCY_BODY_LIMIT_BYTES).await {
        Ok(value) => value,
        Err(error) => {
            diagnostics::warn(
                "idempotency_response_read_failed",
                json!({"error": error.to_string()}),
            );
            return (
                StatusCode::BAD_GATEWAY,
                Json(ErrorBody {
                    error: "unable to cache response body for idempotency",
                }),
            )
                .into_response();
        }
    };

    let headers = parts.headers.clone();
    state
        .idempotency_store
        .complete(&scope, fingerprint, status, headers, response_body.clone())
        .await;

    Response::from_parts(parts, Body::from(response_body))
}

fn idempotency_subject(headers: &HeaderMap) -> String {
    headers
        .get(AUTHORIZATION)
        .and_then(|value| value.to_str().ok())
        .and_then(|value| value.strip_prefix("Bearer "))
        .map(|value| {
            let mut hasher = Sha256::new();
            hasher.update(value.as_bytes());
            format!("{:x}", hasher.finalize())
        })
        .unwrap_or_else(|| request_client(headers))
}

fn replay_response(cached: IdempotentResponse) -> Response {
    let mut response = Response::new(Body::from(cached.body));
    *response.status_mut() = cached.status;
    *response.headers_mut() = cached.headers;
    response.headers_mut().insert(
        HeaderName::from_static("x-idempotency-replayed"),
        HeaderValue::from_static("true"),
    );
    response
}

fn request_fingerprint(method: &Method, path: &str, body: &[u8]) -> String {
    let mut hasher = Sha256::new();
    hasher.update(method.as_str().as_bytes());
    hasher.update(path.as_bytes());
    hasher.update(body);
    format!("{:x}", hasher.finalize())
}

fn emit_api_request_event(
    method: &Method,
    path: &str,
    status: StatusCode,
    latency: Duration,
    outcome: &str,
    policy: &RoutePolicy,
    has_authorization: bool,
    request_id: Option<&str>,
) {
    let level = if status.is_server_error() {
        "error"
    } else if status.is_client_error() {
        "warn"
    } else {
        "info"
    };

    let payload = json!({
        "path": path,
        "method": method.as_str(),
        "status": status.as_u16(),
        "outcome": outcome,
        "feature": policy.feature,
        "permission": policy.permission,
        "has_authorization": has_authorization,
        "idempotent": policy.idempotent,
        "latency_ms": latency.as_millis(),
        "request_id": request_id,
    });

    match level {
        "error" => diagnostics::error("api_request", payload),
        "warn" => diagnostics::warn("api_request", payload),
        _ => diagnostics::info("api_request", payload),
    }
}
