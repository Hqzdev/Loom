#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEME_NAME="${TETHER_SCHEME_NAME:-Tether}"
APP_NAME="${TETHER_APP_NAME:-Tether}"
DMG_NAME="${TETHER_DMG_NAME:-Tether.dmg}"
DIST_DIR="$ROOT/dist"
BUILD_DIR="$DIST_DIR/build"
STAGE_DIR="$BUILD_DIR/dmg-stage"
APP_STAGE="$STAGE_DIR/$APP_NAME.app"
DERIVED_DATA="$BUILD_DIR/DerivedData"
WEB_DOWNLOAD_DIR="$ROOT/web/public/downloads"

need() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required command: $1" >&2
    exit 1
  fi
}

need cargo
need xcodebuild
need hdiutil

echo "==> Cleaning package workspace"
rm -rf "$BUILD_DIR"
mkdir -p "$STAGE_DIR" "$DIST_DIR" "$WEB_DOWNLOAD_DIR"

echo "==> Building proxy helper"
cargo build --manifest-path "$ROOT/proxy/Cargo.toml" --release

echo "==> Building macOS app"
xcodebuild \
  -project "$ROOT/ui/Tether.xcodeproj" \
  -scheme "$SCHEME_NAME" \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$DERIVED_DATA" \
  -skipMacroValidation \
  -skipPackagePluginValidation \
  CODE_SIGNING_ALLOWED=NO \
  ENABLE_APP_SANDBOX=NO \
  build

BUILT_APP="$(find "$DERIVED_DATA/Build/Products/Release" -maxdepth 1 -name "$APP_NAME.app" -print -quit)"
if [[ -z "$BUILT_APP" || ! -d "$BUILT_APP" ]]; then
  echo "could not find built app in $DERIVED_DATA/Build/Products/Release" >&2
  exit 1
fi

echo "==> Staging app bundle"
cp -R "$BUILT_APP" "$APP_STAGE"
mkdir -p "$APP_STAGE/Contents/Helpers"
cp "$ROOT/proxy/target/release/tether-proxy" "$APP_STAGE/Contents/Helpers/tether-proxy"
chmod +x "$APP_STAGE/Contents/Helpers/tether-proxy"

echo "==> Normalizing app bundle metadata"
if command -v dot_clean >/dev/null 2>&1; then
  dot_clean -m "$APP_STAGE"
fi
if command -v xattr >/dev/null 2>&1; then
  xattr -cr "$APP_STAGE"
fi

if command -v codesign >/dev/null 2>&1; then
  echo "==> Ad-hoc signing app bundle"
  codesign --force --deep --sign - "$APP_STAGE" >/dev/null
fi

echo "==> Creating DMG"
rm -f "$DIST_DIR/$DMG_NAME"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGE_DIR" \
  -ov \
  -format UDZO \
  "$DIST_DIR/$DMG_NAME"

cp "$DIST_DIR/$DMG_NAME" "$WEB_DOWNLOAD_DIR/$DMG_NAME"

echo "==> DMG ready"
echo "    $DIST_DIR/$DMG_NAME"
echo "    $WEB_DOWNLOAD_DIR/$DMG_NAME"
