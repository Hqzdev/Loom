//! Context inputs layer.
//!
//! Instead of treating the prompt as one opaque blob, we classify *what went
//! into* a call: tool/function definitions, MCP tools, file paths referenced in
//! the system prompt, etc. We store only identifiers (names, paths, hashes,
//! sizes) — never the bodies — so the UI can show context collapsed and expand
//! on demand. `input_hash` is a stable fingerprint of the call's context; it is
//! the anchor that later enables downstream-invalidation on replay.

use std::collections::BTreeSet;

use serde::Serialize;
use serde_json::Value;
use sha2::{Digest, Sha256};

#[derive(Serialize)]
pub(crate) struct ContextInputs {
    pub(crate) sources: Vec<ContextSource>,
    pub(crate) withheld: Vec<String>,
    pub(crate) input_hash: String,
}

#[derive(Serialize)]
pub(crate) struct ContextSource {
    pub(crate) kind: &'static str, // file | mcp | tool | skill | memory | inline
    pub(crate) path_or_id: String,
    pub(crate) hash: String,
    pub(crate) size_bytes: usize,
}

/// Build the context-inputs descriptor for a request body. `system` and `user`
/// are the already-extracted prompt segments (see `trace::extract_prompt`); the
/// raw `request` JSON is used for structured fields like `tools`.
pub(crate) fn from_request(
    request: Option<&Value>,
    system: &str,
    user: &str,
    model: &str,
) -> ContextInputs {
    let mut sources = Vec::new();

    if let Some(request) = request {
        collect_tool_definitions(request, &mut sources);
    }
    collect_referenced_paths(system, &mut sources);
    collect_mcp_tools(system, &mut sources);

    if !system.trim().is_empty() {
        sources.push(ContextSource {
            kind: "inline",
            path_or_id: "system_prompt".to_string(),
            hash: short_hash(system.as_bytes()),
            size_bytes: system.len(),
        });
    }

    ContextInputs {
        sources,
        withheld: detect_withheld(system),
        input_hash: input_hash(model, system, user),
    }
}

/// Stable fingerprint of everything that shapes the model's output for this
/// call. Used as the equality key for replay/invalidation.
pub(crate) fn input_hash(model: &str, system: &str, user: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(model.as_bytes());
    hasher.update([0]);
    hasher.update(system.as_bytes());
    hasher.update([0]);
    hasher.update(user.as_bytes());
    hex(&hasher.finalize())
}

/// Tool/function definitions, both Anthropic (`tools[].name`) and OpenAI
/// (`tools[].function.name` / legacy `functions[].name`).
fn collect_tool_definitions(request: &Value, out: &mut Vec<ContextSource>) {
    let arrays = [request.get("tools"), request.get("functions")];
    for array in arrays.into_iter().flatten() {
        let Some(items) = array.as_array() else {
            continue;
        };
        for item in items {
            let name = item.get("name").and_then(Value::as_str).or_else(|| {
                item.get("function")
                    .and_then(|function| function.get("name"))
                    .and_then(Value::as_str)
            });
            let Some(name) = name else { continue };
            let serialized = serde_json::to_vec(item).unwrap_or_default();
            let kind = if name.starts_with("mcp__") {
                "mcp"
            } else {
                "tool"
            };
            out.push(ContextSource {
                kind,
                path_or_id: name.to_string(),
                hash: short_hash(&serialized),
                size_bytes: serialized.len(),
            });
        }
    }
}

/// Heuristically pull filesystem-looking paths out of the system prompt. Agents
/// like Claude Code embed absolute paths when they inline file context.
fn collect_referenced_paths(system: &str, out: &mut Vec<ContextSource>) {
    let mut seen = BTreeSet::new();
    for raw in system
        .split(|c: char| c.is_whitespace() || matches!(c, '`' | '"' | '\'' | '(' | ')' | '<' | '>'))
    {
        let token = raw.trim_matches(|c: char| matches!(c, ',' | ';' | ':' | '.' | '!' | '?'));
        if !looks_like_path(token) || !seen.insert(token.to_string()) {
            continue;
        }
        out.push(ContextSource {
            kind: "file",
            path_or_id: token.to_string(),
            hash: short_hash(token.as_bytes()),
            size_bytes: token.len(),
        });
    }
}

/// MCP tool identifiers (`mcp__server__tool`) mentioned in the system prompt but
/// not surfaced via a structured `tools` array.
fn collect_mcp_tools(system: &str, out: &mut Vec<ContextSource>) {
    let mut seen: BTreeSet<String> = out
        .iter()
        .filter(|source| source.kind == "mcp")
        .map(|source| source.path_or_id.clone())
        .collect();
    for raw in
        system.split(|c: char| c.is_whitespace() || matches!(c, '`' | '"' | '\'' | '(' | ')' | ','))
    {
        let token = raw.trim_matches(|c: char| matches!(c, '.' | ':' | ';'));
        if !token.starts_with("mcp__") || token.len() < 6 || !seen.insert(token.to_string()) {
            continue;
        }
        out.push(ContextSource {
            kind: "mcp",
            path_or_id: token.to_string(),
            hash: short_hash(token.as_bytes()),
            size_bytes: token.len(),
        });
    }
}

/// Tools the harness advertised as present-but-not-loaded (deferred schemas).
/// Best-effort: we surface the marker so the UI can hint that context was
/// stripped, without trying to reconstruct exact names.
fn detect_withheld(system: &str) -> Vec<String> {
    let mut withheld = Vec::new();
    let haystack = system.to_ascii_lowercase();
    if haystack.contains("deferred") || haystack.contains("schemas are not loaded") {
        withheld.push("deferred-tools".to_string());
    }
    if haystack.contains("not yet available") || haystack.contains("still connecting") {
        withheld.push("pending-connectors".to_string());
    }
    withheld
}

fn looks_like_path(token: &str) -> bool {
    if token.len() < 3 || token.contains(' ') {
        return false;
    }
    let absolute = token.starts_with('/') && token[1..].contains('/');
    let relative = token.starts_with("./") || token.starts_with("../");
    let has_ext_segment = token.contains('/')
        && token
            .rsplit('/')
            .next()
            .map(|seg| seg.contains('.') && !seg.starts_with('.'))
            .unwrap_or(false);
    absolute || relative || has_ext_segment
}

fn short_hash(bytes: &[u8]) -> String {
    let full = hex(&Sha256::digest(bytes));
    full[..16].to_string()
}

fn hex(bytes: &[u8]) -> String {
    use std::fmt::Write as _;
    let mut out = String::with_capacity(bytes.len() * 2);
    for byte in bytes {
        let _ = write!(out, "{byte:02x}");
    }
    out
}
