#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/Tether-e2e.XXXXXX")"
PROXY_PORT="${TETHER_E2E_PROXY_PORT:-18080}"
UPSTREAM_PORT="${TETHER_E2E_UPSTREAM_PORT:-18081}"
DB_PATH="$TMP_DIR/Tether-e2e.sqlite"
MOCK_LOG="$TMP_DIR/mock-upstream.log"
PROXY_LOG="$TMP_DIR/tether-proxy.log"
MOCK_PID=""
PROXY_PID=""

cleanup() {
  if [[ -n "$PROXY_PID" ]]; then
    kill "$PROXY_PID" >/dev/null 2>&1 || true
  fi
  if [[ -n "$MOCK_PID" ]]; then
    kill "$MOCK_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required command: $1" >&2
    exit 1
  fi
}

wait_for() {
  local url="$1"
  local label="$2"
  local attempts=80

  for _ in $(seq 1 "$attempts"); do
    if curl -fsS "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.15
  done

  echo "timed out waiting for $label at $url" >&2
  echo "--- mock upstream log ---" >&2
  test -f "$MOCK_LOG" && tail -80 "$MOCK_LOG" >&2
  echo "--- core/proxy log ---" >&2
  test -f "$PROXY_LOG" && tail -120 "$PROXY_LOG" >&2
  exit 1
}

need cargo
need curl
need node
need sqlite3

cat >"$TMP_DIR/mock-upstream.mjs" <<'JS'
import http from "node:http";

const port = Number(process.env.PORT || "18081");

const server = http.createServer((req, res) => {
  if (req.url === "/health") {
    res.writeHead(200, { "content-type": "text/plain" });
    res.end("ok");
    return;
  }

  let body = "";
  req.setEncoding("utf8");
  req.on("data", (chunk) => {
    body += chunk;
  });
  req.on("end", () => {
    if (req.method !== "POST" || req.url !== "/v1/chat/completions") {
      res.writeHead(404, { "content-type": "application/json" });
      res.end(JSON.stringify({ error: "not found", method: req.method, url: req.url }));
      return;
    }

    const parsed = JSON.parse(body || "{}");
    const response = {
      id: "chatcmpl-Tether-smoke",
      object: "chat.completion",
      model: parsed.model || "smoke-model",
      choices: [
        {
          index: 0,
          message: {
            role: "assistant",
            content: "Smoke trace captured by Tether."
          },
          finish_reason: "stop"
        }
      ],
      usage: {
        prompt_tokens: 12,
        completion_tokens: 6,
        total_tokens: 18
      }
    };

    res.writeHead(200, {
      "content-type": "application/json",
      "openai-request-id": "req_Tether_smoke"
    });
    res.end(JSON.stringify(response));
  });
});

server.listen(port, "127.0.0.1", () => {
  console.log(`mock upstream listening on 127.0.0.1:${port}`);
});
JS

if [[ "${TETHER_E2E_SKIP_BUILD:-0}" == "1" ]]; then
  echo "==> Skipping core/proxy build"
else
  echo "==> Building core/proxy"
  cargo build --manifest-path "$ROOT/core/proxy/Cargo.toml" >/dev/null
fi

echo "==> Starting mock OpenAI upstream on :$UPSTREAM_PORT"
PORT="$UPSTREAM_PORT" node "$TMP_DIR/mock-upstream.mjs" >"$MOCK_LOG" 2>&1 &
MOCK_PID="$!"
wait_for "http://127.0.0.1:$UPSTREAM_PORT/health" "mock upstream"

echo "==> Starting Tether proxy on :$PROXY_PORT"
TETHER_ADDR="127.0.0.1:$PROXY_PORT" \
TETHER_DB="$DB_PATH" \
TETHER_CACHE=on \
TETHER_REQUIRE_AUTH_DB=0 \
OPENAI_UPSTREAM="http://127.0.0.1:$UPSTREAM_PORT" \
ANTHROPIC_UPSTREAM="http://127.0.0.1:$UPSTREAM_PORT" \
"$ROOT/core/proxy/target/debug/tether-proxy" >"$PROXY_LOG" 2>&1 &
PROXY_PID="$!"
wait_for "http://127.0.0.1:$PROXY_PORT/api/traces/current" "Tether proxy"
TETHER_BASE_URL="http://127.0.0.1:$PROXY_PORT" scripts/p1-ready-check.sh

curl -fsS -X DELETE "http://127.0.0.1:$PROXY_PORT/api/traces/current" >/dev/null || true

echo "==> Sending agent request through core/proxy"
RESPONSE="$(
  curl -fsS \
    -X POST "http://127.0.0.1:$PROXY_PORT/v1/chat/completions" \
    -H "content-type: application/json" \
    -H "authorization: Bearer smoke-test-key" \
    --data '{"model":"gpt-4o-mini","temperature":0.2,"messages":[{"role":"system","content":"You are a smoke test."},{"role":"user","content":"Trace this request."}]}'
)"

RESPONSE="$RESPONSE" node - <<'JS'
const response = JSON.parse(process.env.RESPONSE);
const text = response.choices?.[0]?.message?.content;
if (text !== "Smoke trace captured by Tether.") {
  console.error("unexpected upstream response", response);
  process.exit(1);
}
JS

TRACE_JSON=""
TRACE_READY=0
for _ in $(seq 1 80); do
  TRACE_JSON="$(curl -fsS "http://127.0.0.1:$PROXY_PORT/api/traces/current")"
  if TRACE_JSON="$TRACE_JSON" node - <<'JS'
const snapshot = JSON.parse(process.env.TRACE_JSON);
const node = snapshot.nodes?.[0];
if (
  node &&
  node.status === "success" &&
  node.step_name === "OPENAI completions" &&
  node.provider === "openai" &&
  node.model === "gpt-4o-mini" &&
  node.request_id === "req_Tether_smoke" &&
  typeof node.input_hash === "string" &&
  node.input_hash.length > 0 &&
  typeof node.output_hash === "string" &&
  node.output_hash.length > 0 &&
  Array.isArray(node.context_inputs?.sources) &&
  node.context_inputs.sources.length > 0 &&
  node.prompt.user.includes("Trace this request") &&
  node.response.text.includes("Smoke trace captured")
) {
  process.exit(0);
}
process.exit(1);
JS
  then
    TRACE_READY=1
    break
  fi
  sleep 0.15
done

if [[ "$TRACE_READY" != "1" ]]; then
  echo "trace API never exposed the expected UI-readable node" >&2
  echo "$TRACE_JSON" >&2
  exit 1
fi

TRACE_JSON="$TRACE_JSON" node - <<'JS'
const snapshot = JSON.parse(process.env.TRACE_JSON);
const node = snapshot.nodes?.[0];
if (!node) {
  console.error("trace API did not expose a UI-readable snapshot", snapshot);
  process.exit(1);
}
const stepName = node.step_name || node.stepName;
console.log(`    UI API node: ${stepName} / ${node.status} / ${node.provider}/${node.model} / #${node.output_hash}`);
JS

TRACE_COUNT="$(sqlite3 "$DB_PATH" "select count(*) from trace_calls where path = '/v1/chat/completions' and status_code = 200;")"
if [[ "$TRACE_COUNT" != "1" ]]; then
  echo "expected 1 stored SQLite trace row, got $TRACE_COUNT" >&2
  sqlite3 "$DB_PATH" "select id,path,status_code,model,request_id from trace_calls;" >&2 || true
  exit 1
fi

echo "==> E2E OK"
echo "    agent -> proxy -> SQLite -> UI API is proven"
echo "    db: $DB_PATH"
