#!/usr/bin/env bash
#
# check-file-size.sh — enforce the "one screen of one idea" rule.
#
# Fails if any tracked first-party Rust/Swift source file exceeds MAX_LINES.
# Vendored Swift packages and build artifacts are skipped. Genuinely justified
# exceptions live in scripts/file-size-allowlist.txt (one repo-relative path per
# line; blank lines and `#` comments allowed).
#
# Usage:
#   scripts/check-file-size.sh            # check, exit 1 on any violation
#   MAX_LINES=250 scripts/check-file-size.sh
#
# Note: written to run under macOS' stock bash 3.2 — avoids `&&`-list control
# flow under `set -e` and avoids non-portable grep escapes like `\s`.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAX_LINES="${MAX_LINES:-200}"
ALLOWLIST="${ALLOWLIST:-$ROOT/scripts/file-size-allowlist.txt}"

cd "$ROOT"

# Paths we never police: vendored deps, recovered snapshots, build output.
is_excluded() {
  case "$1" in
    swift-sharing/*|swift-composable-architecture/*|swift-navigation/*|swift-syntax/*) return 0 ;;
    swift-custom-dump/*|swift-identified-collections/*|swift-case-paths/*) return 0 ;;
    swift-concurrency-extras/*|swift-collections/*|combine-schedulers/*) return 0 ;;
    swift-perception/*|swift-clocks/*|xctest-dynamic-overlay/*|swift-dependencies/*) return 0 ;;
    *"/Recovered References/"*|*"/.build/"*|*"/target/"*|*"/Pods/"*) return 0 ;;
    *) return 1 ;;
  esac
}

# Load the allowlist once into a newline-delimited string of bare paths.
ALLOWED=""
if [[ -f "$ALLOWLIST" ]]; then
  while IFS= read -r entry; do
    case "$entry" in
      ""|"#"*) continue ;;
      *) ALLOWED="$ALLOWED$entry"$'\n' ;;
    esac
  done < "$ALLOWLIST"
fi

is_allowlisted() {
  case $'\n'"$ALLOWED" in
    *$'\n'"$1"$'\n'*) return 0 ;;
    *) return 1 ;;
  esac
}

violations=0

# Only inspect files git is tracking, so generated/ignored files never trip us.
while IFS= read -r file; do
  case "$file" in
    *.rs|*.swift) : ;;
    *) continue ;;
  esac

  if is_excluded "$file"; then continue; fi
  if is_allowlisted "$file"; then continue; fi
  if [[ ! -f "$file" ]]; then continue; fi

  lines="$(wc -l < "$file" | tr -d ' ')"
  if (( lines > MAX_LINES )); then
    printf '  %5s lines  %s\n' "$lines" "$file"
    violations=$((violations + 1))
  fi
done < <(git ls-files '*.rs' '*.swift')

if (( violations > 0 )); then
  echo "" >&2
  echo "✗ $violations file(s) exceed ${MAX_LINES} lines (see above)." >&2
  echo "  Split along a real concern boundary, or add a justified path to:" >&2
  echo "  ${ALLOWLIST}" >&2
  exit 1
fi

echo "✓ All tracked Rust/Swift files are within ${MAX_LINES} lines."
