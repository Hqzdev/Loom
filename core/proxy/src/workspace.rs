use axum::http::HeaderMap;
use url::form_urlencoded;

pub(crate) const DEFAULT_WORKSPACE_ID: &str = "local-default";
pub(crate) const WORKSPACE_HEADER: &str = "x-tether-workspace";

pub(crate) struct GatewayWorkspace {
    pub(crate) id: String,
    pub(crate) path_and_query: String,
}

pub(crate) fn from_headers(headers: &HeaderMap) -> Result<String, String> {
    match workspace_header(headers) {
        Some(value) => normalize(&value),
        None => Ok(DEFAULT_WORKSPACE_ID.to_string()),
    }
}

pub(crate) fn from_gateway(
    headers: &HeaderMap,
    path: &str,
    query: Option<&str>,
) -> Result<GatewayWorkspace, String> {
    let query_workspace = query.and_then(workspace_from_query);
    let id = match workspace_header(headers).or(query_workspace) {
        Some(value) => normalize(&value)?,
        None => DEFAULT_WORKSPACE_ID.to_string(),
    };

    Ok(GatewayWorkspace {
        id,
        path_and_query: cleaned_path_and_query(path, query),
    })
}

fn workspace_header(headers: &HeaderMap) -> Option<String> {
    headers
        .get(WORKSPACE_HEADER)
        .and_then(|value| value.to_str().ok())
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(ToOwned::to_owned)
}

fn workspace_from_query(query: &str) -> Option<String> {
    form_urlencoded::parse(query.as_bytes())
        .find(|(key, _)| key == "workspace_token" || key == "tether_workspace")
        .map(|(_, value)| value.into_owned())
}

fn cleaned_path_and_query(path: &str, query: Option<&str>) -> String {
    let Some(query) = query else {
        return path.to_string();
    };

    let mut serializer = form_urlencoded::Serializer::new(String::new());
    for (key, value) in form_urlencoded::parse(query.as_bytes()) {
        if key != "workspace_token" && key != "tether_workspace" {
            serializer.append_pair(&key, &value);
        }
    }
    let cleaned = serializer.finish();
    if cleaned.is_empty() {
        path.to_string()
    } else {
        format!("{path}?{cleaned}")
    }
}

fn normalize(value: &str) -> Result<String, String> {
    let trimmed = value.trim();
    let valid_length = (3..=128).contains(&trimmed.len());
    let valid_chars = trimmed
        .bytes()
        .all(|byte| byte.is_ascii_alphanumeric() || byte == b'-' || byte == b'_' || byte == b'.');
    if valid_length && valid_chars {
        Ok(trimmed.to_string())
    } else {
        Err("invalid workspace token".to_string())
    }
}
