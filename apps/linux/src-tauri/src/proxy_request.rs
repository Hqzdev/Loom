use serde::{Deserialize, Serialize};

#[derive(Deserialize)]
pub struct ProxyRequest {
    method: String,
    path: String,
    body: Option<String>,
    workspace_id: Option<String>,
}

#[derive(Serialize)]
pub struct ProxyResponse {
    status: u16,
    body: String,
}

#[tauri::command]
pub fn proxy_request(request: ProxyRequest) -> Result<ProxyResponse, String> {
    let client = reqwest::blocking::Client::new();
    let method = request
        .method
        .parse()
        .map_err(|_| "invalid proxy method".to_string())?;
    let response = client
        .request(method, format!("http://127.0.0.1:8080{}", request.path))
        .headers(headers(request.workspace_id))
        .body(request.body.unwrap_or_default())
        .send()
        .map_err(|error| error.to_string())?;
    let status = response.status().as_u16();
    let body = response.text().map_err(|error| error.to_string())?;
    Ok(ProxyResponse { status, body })
}

fn headers(workspace_id: Option<String>) -> reqwest::header::HeaderMap {
    let mut headers = reqwest::header::HeaderMap::new();
    let workspace = workspace_id.unwrap_or_else(|| "local-default".to_string());
    if let Ok(value) = reqwest::header::HeaderValue::from_str(&workspace) {
        headers.insert("x-tether-workspace", value);
    }
    headers.insert(
        reqwest::header::CONTENT_TYPE,
        reqwest::header::HeaderValue::from_static("application/json"),
    );
    headers
}
