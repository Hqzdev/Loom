#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${TETHER_BASE_URL:-http://127.0.0.1:8080}"
TIMEOUT_SECONDS="${TETHER_READY_TIMEOUT_SECONDS:-5}"

healthz() {
  local target="$BASE_URL/healthz"
  local status
  status="$(curl -sS -o /dev/null -w '%{http_code}' --max-time "$TIMEOUT_SECONDS" "$target")"
  if [[ "$status" != "200" ]]; then
    echo "unhealthy endpoint=$target status=$status" >&2
    return 1
  fi
}

readyz() {
  local target="$BASE_URL/readyz"
  local body_file
  local code
  local body
  body_file="$(mktemp)"
  code="$(curl -sS -o "$body_file" -w '%{http_code}' --max-time "$TIMEOUT_SECONDS" "$target")"
  body="$(tr -d '\n' <"$body_file")"
  rm -f "$body_file"

  if [[ "$code" != "200" ]]; then
    echo "unhealthy endpoint=$target status=$code body=$body" >&2
    return 1
  fi
  if ! echo "$body" | grep -q '"status":"ok"'; then
    echo "unhealthy endpoint=$target response=$body" >&2
    return 1
  fi
}

healthz
readyz

echo "p1_ready_check_ok url=$BASE_URL"
