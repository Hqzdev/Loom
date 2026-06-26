#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: p1-deploy-manifest.sh <environment> <artifact_path> [output_path]" >&2
  exit 1
fi

environment="$1"
artifact_path="$2"
manifest_path="${3:-./dist/deploy-manifest.json}"

if [[ ! -f "$artifact_path" ]]; then
  echo "artifact not found: $artifact_path" >&2
  exit 1
fi

if command -v sha256sum >/dev/null 2>&1; then
  artifact_sha256="$(sha256sum "$artifact_path" | awk '{print $1}')"
else
  artifact_sha256="$(shasum -a 256 "$artifact_path" | awk '{print $1}')"
fi

if stat -c '%s' "$artifact_path" >/dev/null 2>&1; then
  artifact_size="$(stat -c '%s' "$artifact_path")"
else
  artifact_size="$(stat -f '%z' "$artifact_path")"
fi

git_sha="$(git rev-parse HEAD)"
git_short_sha="$(git rev-parse --short=12 HEAD)"
release_tag="${TETHER_RELEASE_TAG:-${GITHUB_REF_NAME:-local}}"
workflow_id="${GITHUB_WORKFLOW:-manual}"
run_id="${GITHUB_RUN_ID:-manual}"
run_number="${GITHUB_RUN_NUMBER:-manual}"
actor="${GITHUB_ACTOR:-manual}"
built_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

cat > "$manifest_path" <<JSON
{
  "environment": "$environment",
  "release_tag": "$release_tag",
  "git_sha": "$git_sha",
  "git_short_sha": "$git_short_sha",
  "artifact_path": "$artifact_path",
  "artifact_size_bytes": $artifact_size,
  "artifact_sha256": "$artifact_sha256",
  "workflow": "$workflow_id",
  "run_id": "$run_id",
  "run_number": "$run_number",
  "actor": "$actor",
  "built_at": "$built_at"
}
JSON
