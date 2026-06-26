#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LINUX_APP_DIR="$ROOT/apps/linux"
TAURI_DIR="$LINUX_APP_DIR/src-tauri"
DIST_DIR="$ROOT/dist/linux"
SIDECAR_DIR="$TAURI_DIR/binaries"
TARGET_TRIPLE="$(rustc -vV | awk '/host:/ { print $2 }')"
SIDECAR_NAME="tether-proxy-$TARGET_TRIPLE"

need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required command: $1" >&2
    exit 1
  fi
}

need cargo
need npm
need rustc

echo "==> Building core/proxy sidecar"
cargo build --manifest-path "$ROOT/core/proxy/Cargo.toml" --release

mkdir -p "$SIDECAR_DIR" "$DIST_DIR"
cp "$ROOT/core/proxy/target/release/tether-proxy" "$SIDECAR_DIR/$SIDECAR_NAME"
chmod +x "$SIDECAR_DIR/$SIDECAR_NAME"

echo "==> Installing Linux app dependencies"
npm --prefix "$LINUX_APP_DIR" ci

echo "==> Building Linux desktop app"
TAURI_CONFIG='{"bundle":{"externalBin":["binaries/tether-proxy"]}}' npm --prefix "$LINUX_APP_DIR" run tauri:build

echo "==> Collecting Linux artifacts"
find "$TAURI_DIR/target/release/bundle" -type f \( -name "*.AppImage" -o -name "*.deb" \) -exec cp {} "$DIST_DIR/" \;

echo "==> Linux artifacts ready"
find "$DIST_DIR" -maxdepth 1 -type f -print | sort
