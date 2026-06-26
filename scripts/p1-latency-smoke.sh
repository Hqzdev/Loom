#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${TETHER_BASE_URL:-${1:-http://127.0.0.1:8080}}"
TARGET_PATH="${2:-/healthz}"
REQUESTS="${3:-${TETHER_LATENCY_REQUESTS:-30}}"
CONCURRENCY="${4:-${TETHER_LATENCY_CONCURRENCY:-1}}"
TIMEOUT_SECONDS="${5:-${TETHER_LATENCY_TIMEOUT_SECONDS:-5}}"
P95_BUDGET_MS="${6:-${TETHER_LATENCY_P95_BUDGET_MS:-300}}"

if ! [[ "$REQUESTS" =~ ^[0-9]+$ ]] || [[ "$REQUESTS" -eq 0 ]]; then
  echo "invalid request count: $REQUESTS" >&2
  exit 1
fi

if ! [[ "$CONCURRENCY" =~ ^[0-9]+$ ]] || [[ "$CONCURRENCY" -eq 0 ]]; then
  echo "invalid concurrency: $CONCURRENCY" >&2
  exit 1
fi

if ! [[ "$TIMEOUT_SECONDS" =~ ^[0-9]+$ ]] || [[ "$TIMEOUT_SECONDS" -eq 0 ]]; then
  echo "invalid timeout: $TIMEOUT_SECONDS" >&2
  exit 1
fi

if ! [[ "$P95_BUDGET_MS" =~ ^[0-9]+$ ]] || [[ "$P95_BUDGET_MS" -eq 0 ]]; then
  echo "invalid p95 budget: $P95_BUDGET_MS" >&2
  exit 1
fi

results_file="$(mktemp)"
latencies_file="$(mktemp)"
sorted_latencies="$(mktemp)"

cleanup() {
  rm -f "$results_file" "$latencies_file" "$sorted_latencies"
}

trap cleanup EXIT

run_request() {
  local url="$BASE_URL$TARGET_PATH"
  local response
  local latency
  local status_code

  response="$(curl -sS -o /dev/null -w '%{time_total} %{http_code}' -m "$TIMEOUT_SECONDS" "$url" || true)"

  if [[ -z "$response" ]]; then
    echo "err" >> "$results_file"
    return
  fi

  latency="$(awk '{print $1}' <<< "$response")"
  status_code="$(awk '{print $2}' <<< "$response")"
  if [[ -z "$latency" || -z "$status_code" ]]; then
    echo "err" >> "$results_file"
    return
  fi

  if [[ "${status_code:0:1}" != "2" && "${status_code:0:1}" != "3" ]]; then
    echo "err" >> "$results_file"
    return
  fi

  printf '%s\n' "$latency" >> "$latencies_file"
  echo "ok" >> "$results_file"
}

active_requests=0
for _ in $(seq 1 "$REQUESTS"); do
  run_request "$_" &
  active_requests=$((active_requests + 1))
  if ((active_requests >= CONCURRENCY)); then
    wait -n
    active_requests=$((active_requests - 1))
  fi
done

wait

success_count="$(grep -c '^ok$' "$results_file" || true)"
error_count="$(grep -c '^err$' "$results_file" || true)"
request_count=$((success_count + error_count))

if [[ "$success_count" -eq 0 ]]; then
  echo "latency_smoke_failed base_url=$BASE_URL target=$TARGET_PATH requests=$request_count errors=$error_count" >&2
  exit 1
fi

sort -n "$latencies_file" > "$sorted_latencies"

min_ms="$(awk 'NR==1 {print $1 * 1000}' "$sorted_latencies")"
max_ms="$(awk 'END {if (NR > 0) print $1 * 1000}' "$sorted_latencies")"
avg_ms="$(awk '{sum += $1} END { if (NR > 0) print (sum / NR) * 1000 }' "$sorted_latencies")"
p95_idx="$(( (success_count * 95 + 99) / 100 ))"
p99_idx="$(( (success_count * 99 + 99) / 100 ))"

p95_ms="$(awk -v p95_idx="$p95_idx" 'NR == p95_idx {print $1 * 1000}' "$sorted_latencies")"
p99_ms="$(awk -v p99_idx="$p99_idx" 'NR == p99_idx {print $1 * 1000}' "$sorted_latencies")"

if [[ -z "$p95_ms" ]]; then
  p95_ms="$max_ms"
fi

if [[ -z "$p99_ms" ]]; then
  p99_ms="$max_ms"
fi

echo "latency_smoke_complete base_url=$BASE_URL target=$TARGET_PATH requests=$request_count success=$success_count errors=$error_count p95_ms=$p95_ms p99_ms=$p99_ms avg_ms=$avg_ms min_ms=$min_ms max_ms=$max_ms concurrency=$CONCURRENCY"

if ! awk -v p95_ms="$p95_ms" -v budget="$P95_BUDGET_MS" 'BEGIN { exit !(p95_ms <= budget) }'; then
  echo "p95 latency budget exceeded target_ms=$P95_BUDGET_MS observed_ms=$p95_ms" >&2
  exit 1
fi

if (( error_count * 10 > request_count )); then
  echo "error ratio too high requests=$request_count errors=$error_count" >&2
  exit 1
fi
