//! Context inputs layer.
//!
//! Instead of treating the prompt as one opaque blob, we classify *what went
//! into* a call: tool/function definitions, MCP tools, file paths referenced in
//! the system prompt, etc. We store only identifiers (names, paths, hashes,
//! sizes) by default. Raw source bodies are retained only inside the detail
//! payload so the UI can keep the inspector redacted until the user expands a
//! source. `input_hash` is a stable fingerprint of the call's context; it is the
//! anchor that later enables downstream-invalidation on replay.

use std::collections::BTreeSet;

use serde::Serialize;
use serde_json::Value;
use sha2::{Digest, Sha256};

/// Context descriptor stored beside a trace call so replay can compare inputs.
#[derive(Serialize)]
pub(crate) struct ContextInputs {
    pub(crate) sources: Vec<ContextSource>,
    pub(crate) withheld: Vec<String>,
    pub(crate) input_hash: String,
}

/// One summarized source of context, identified without storing the source body.
#[derive(Serialize)]
pub(crate) struct ContextSource {
    pub(crate) kind: &'static str, // file | mcp | mcp_result | tool | tool_result | skill | memory | search | inline
    pub(crate) path_or_id: String,
    pub(crate) hash: String,
    pub(crate) size_bytes: usize,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub(crate) body: Option<String>,
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
        collect_message_context(request, &mut sources);
    }
    collect_referenced_paths(system, &mut sources);
    collect_mcp_tools(system, &mut sources);
    collect_skill_sources(system, &mut sources);
    collect_memory_sources(system, &mut sources);

    if !system.trim().is_empty() {
        sources.push(ContextSource {
            kind: "inline",
            path_or_id: "system_prompt".to_string(),
            hash: short_hash(system.as_bytes()),
            size_bytes: system.len(),
            body: Some(system.to_string()),
        });
    }
    if !user.trim().is_empty() {
        sources.push(ContextSource {
            kind: "inline",
            path_or_id: "user_prompt".to_string(),
            hash: short_hash(user.as_bytes()),
            size_bytes: user.len(),
            body: Some(user.to_string()),
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
                body: Some(String::from_utf8_lossy(&serialized).to_string()),
            });
        }
    }
}

/// Tool/function result bodies that became part of the conversation context.
fn collect_message_context(request: &Value, out: &mut Vec<ContextSource>) {
    let Some(messages) = request.get("messages").and_then(Value::as_array) else {
        collect_anthropic_content_blocks(request, out);
        return;
    };

    for (index, message) in messages.iter().enumerate() {
        let role = message
            .get("role")
            .and_then(Value::as_str)
            .unwrap_or_default();
        if role != "tool" && role != "function" {
            continue;
        }
        let content = text_content(message.get("content"));
        if content.trim().is_empty() {
            continue;
        }
        let name = message
            .get("name")
            .and_then(Value::as_str)
            .or_else(|| message.get("tool_call_id").and_then(Value::as_str))
            .unwrap_or("tool_result");
        out.push(ContextSource {
            kind: context_result_kind(name, &content),
            path_or_id: format!("{name}#{index}"),
            hash: short_hash(content.as_bytes()),
            size_bytes: content.len(),
            body: Some(content),
        });
    }

    collect_anthropic_content_blocks(request, out);
}

/// Anthropic-style `tool_result` content blocks embedded in user messages.
fn collect_anthropic_content_blocks(request: &Value, out: &mut Vec<ContextSource>) {
    let Some(messages) = request.get("messages").and_then(Value::as_array) else {
        return;
    };

    for (message_index, message) in messages.iter().enumerate() {
        let Some(blocks) = message.get("content").and_then(Value::as_array) else {
            continue;
        };
        for (block_index, block) in blocks.iter().enumerate() {
            let Some("tool_result") = block.get("type").and_then(Value::as_str) else {
                continue;
            };
            let content = text_content(block.get("content"));
            if content.trim().is_empty() {
                continue;
            }
            let tool_use_id = block
                .get("tool_use_id")
                .and_then(Value::as_str)
                .unwrap_or("tool_result");
            out.push(ContextSource {
                kind: context_result_kind(tool_use_id, &content),
                path_or_id: format!("{tool_use_id}#{message_index}.{block_index}"),
                hash: short_hash(content.as_bytes()),
                size_bytes: content.len(),
                body: Some(content),
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
            body: None,
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
            body: None,
        });
    }
}

/// Skill declarations in agent system prompts, usually rendered as
/// `- name: description (file: /.../skills/name/SKILL.md)`.
fn collect_skill_sources(system: &str, out: &mut Vec<ContextSource>) {
    let mut seen = BTreeSet::new();
    for line in system.lines() {
        let lower = line.to_ascii_lowercase();
        let Some(file_marker) = lower.find("(file:") else {
            continue;
        };
        if !lower[file_marker..].contains("/skills/") {
            continue;
        }
        let name = line
            .trim_start()
            .strip_prefix("- ")
            .and_then(|value| value.split(':').next())
            .unwrap_or("skill")
            .trim();
        let path = line[file_marker + "(file:".len()..]
            .trim()
            .trim_end_matches(')')
            .trim();
        let id = if path.is_empty() {
            name.to_string()
        } else {
            format!("{name} · {path}")
        };
        if !seen.insert(id.clone()) {
            continue;
        }
        out.push(ContextSource {
            kind: "skill",
            path_or_id: id,
            hash: short_hash(line.as_bytes()),
            size_bytes: line.len(),
            body: Some(line.trim().to_string()),
        });
    }
}

/// Memory or search references that are visible in the prompt shell.
fn collect_memory_sources(system: &str, out: &mut Vec<ContextSource>) {
    let mut seen = BTreeSet::new();
    for line in system.lines() {
        let lower = line.to_ascii_lowercase();
        let kind = if lower.contains("memory") || lower.contains("/memory/") {
            "memory"
        } else if lower.contains("web search")
            || lower.contains("search result")
            || lower.contains("memory/search")
        {
            "search"
        } else {
            continue;
        };
        let trimmed = line.trim();
        if trimmed.is_empty() || !seen.insert(trimmed.to_string()) {
            continue;
        }
        out.push(ContextSource {
            kind,
            path_or_id: first_line_id(trimmed),
            hash: short_hash(trimmed.as_bytes()),
            size_bytes: trimmed.len(),
            body: Some(trimmed.to_string()),
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
    if haystack.contains("truncated") || haystack.contains("omitted children") {
        withheld.push("truncated-context".to_string());
    }
    if haystack.contains("redacted") || haystack.contains("filtered") {
        withheld.push("system-filtered-content".to_string());
    }
    if haystack.contains("lazy-loaded") || haystack.contains("not loaded") {
        withheld.push("lazy-loaded-schemas".to_string());
    }
    withheld
}

/// Returns whether a token looks enough like a filesystem path to expose as context.
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

/// Shortens a SHA-256 digest for UI-friendly context source ids.
pub(crate) fn short_hash(bytes: &[u8]) -> String {
    let full = hex(&Sha256::digest(bytes));
    full[..16].to_string()
}

/// Classifies tool-result content into the context buckets shown by the UI.
fn context_result_kind(name: &str, content: &str) -> &'static str {
    let haystack = format!(
        "{} {}",
        name.to_ascii_lowercase(),
        content.to_ascii_lowercase()
    );
    if haystack.contains("mcp__") || haystack.contains("mcp result") {
        "mcp_result"
    } else if haystack.contains("search") || haystack.contains("web.run") {
        "search"
    } else if haystack.contains("memory") {
        "memory"
    } else {
        "tool_result"
    }
}

/// Extracts readable text from provider content values.
fn text_content(value: Option<&Value>) -> String {
    match value {
        Some(Value::String(text)) => text.clone(),
        Some(Value::Array(items)) => items
            .iter()
            .filter_map(|item| {
                item.as_str().map(ToOwned::to_owned).or_else(|| {
                    item.get("text")
                        .and_then(Value::as_str)
                        .map(ToOwned::to_owned)
                })
            })
            .collect::<Vec<_>>()
            .join("\n"),
        Some(other) => serde_json::to_string(other).unwrap_or_default(),
        None => String::new(),
    }
}

/// Returns a compact identifier for a prompt line.
fn first_line_id(value: &str) -> String {
    let first = value.lines().next().unwrap_or(value).trim();
    if first.len() <= 96 {
        first.to_string()
    } else {
        format!("{}...", first.chars().take(96).collect::<String>())
    }
}

/// Encodes bytes as lower-case hexadecimal.
fn hex(bytes: &[u8]) -> String {
    use std::fmt::Write as _;
    let mut out = String::with_capacity(bytes.len() * 2);
    for byte in bytes {
        let _ = write!(out, "{byte:02x}");
    }
    out
}

#[cfg(test)]
mod tests {
    use serde_json::json;

    use super::from_request;

    #[test]
    fn classifies_context_sources_and_withheld_markers() {
        let request = json!({
            "tools": [
                { "function": { "name": "lookup_repo" }, "type": "function" },
                { "name": "mcp__pencil__batch_get", "input_schema": {} }
            ],
            "messages": [
                { "role": "tool", "tool_call_id": "web_search", "content": "search result body" }
            ]
        });
        let system = "- modern-web-guidance: guide (file: /Users/test/.agents/skills/modern-web-guidance/SKILL.md)\n\
                      Read /tmp/project/src/main.rs. Some deferred schemas are not loaded.";
        let inputs = from_request(Some(&request), system, "hello", "gpt-test");
        let kinds = inputs
            .sources
            .iter()
            .map(|source| source.kind)
            .collect::<Vec<_>>();

        assert!(kinds.contains(&"tool"));
        assert!(kinds.contains(&"mcp"));
        assert!(kinds.contains(&"search"));
        assert!(kinds.contains(&"skill"));
        assert!(kinds.contains(&"file"));
        assert!(kinds.contains(&"inline"));
        assert!(inputs.withheld.contains(&"deferred-tools".to_string()));
        assert!(!inputs.input_hash.is_empty());
    }
}
