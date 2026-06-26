//! HTTP helper functions for the transparent proxy gateway.

use axum::{
    body::Body,
    http::{HeaderMap, HeaderName, HeaderValue, StatusCode, header::CONTENT_TYPE},
    response::Response,
};
use bytes::Bytes;
use tether_cache::CachedResponse;

/// Builds the upstream request headers, dropping hop-by-hop/framing headers.
pub(super) fn upstream_headers(source: &HeaderMap) -> HeaderMap {
    let mut headers = HeaderMap::new();
    for (name, value) in source.iter() {
        if is_hop_by_hop(name) || name == "host" || name == "content-length" {
            continue;
        }
        headers.insert(name.clone(), value.clone());
    }
    headers
}

/// Builds the downstream response headers and marks cache misses explicitly.
pub(super) fn miss_response_headers(source: &HeaderMap) -> HeaderMap {
    let mut headers = HeaderMap::new();
    for (name, value) in source.iter() {
        if is_hop_by_hop(name) || name == "content-length" {
            continue;
        }
        headers.insert(name.clone(), value.clone());
    }
    headers.insert(
        HeaderName::from_static("x-tether-cache"),
        HeaderValue::from_static("miss"),
    );
    headers
}

/// Builds an HTTP response that replays a cached payload.
pub(super) fn cached_response(cached: CachedResponse) -> Response {
    let mut response = Response::new(Body::from(Bytes::from(cached.body)));
    *response.status_mut() = StatusCode::from_u16(cached.status).unwrap_or(StatusCode::OK);
    let headers = response.headers_mut();
    if !cached.content_type.is_empty()
        && let Ok(value) = HeaderValue::from_str(&cached.content_type)
    {
        headers.insert(CONTENT_TYPE, value);
    }
    headers.insert(
        HeaderName::from_static("x-tether-cache"),
        HeaderValue::from_static("hit"),
    );
    response
}

/// Returns whether a header must not cross proxy boundaries.
fn is_hop_by_hop(name: &HeaderName) -> bool {
    matches!(
        name.as_str(),
        "connection"
            | "keep-alive"
            | "proxy-authenticate"
            | "proxy-authorization"
            | "proxy-connection"
            | "te"
            | "trailer"
            | "transfer-encoding"
            | "upgrade"
    )
}
