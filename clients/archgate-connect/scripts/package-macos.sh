#!/usr/bin/env bash
# Build ArchGate Connect .app + .dmg and apply ad-hoc codesign (local Gatekeeper friendlier).
# Usage:
#   ./scripts/package-macos.sh
#   SIGN_IDENTITY="Developer ID Application: …" ./scripts/package-macos.sh   # optional real identity
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESKTOP="$ROOT/desktop"
TRIPLE="$(rustc -vV | sed -n 's/^host: //p')"
SIGN_IDENTITY="${SIGN_IDENTITY:--}" # default ad-hoc

echo "=== build CLI sidecar ($TRIPLE) ==="
(cd "$ROOT" && go build -o archgate ./cmd/archgate)
mkdir -p "$DESKTOP/src-tauri/binaries"
cp -f "$ROOT/archgate" "$DESKTOP/src-tauri/binaries/archgate-${TRIPLE}"
cp -f "$ROOT/archgate" "${HOME}/.local/bin/archgate" 2>/dev/null || true

echo "=== tauri build ==="
(cd "$DESKTOP" && npm run tauri build)

APP="$DESKTOP/src-tauri/target/release/bundle/macos/ArchGate Connect.app"
DMG="$DESKTOP/src-tauri/target/release/bundle/dmg/ArchGate Connect_0.2.0_aarch64.dmg"
if [[ ! -d "$APP" ]]; then
  echo "FAIL: app not found at $APP"
  exit 1
fi

echo "=== codesign identity=${SIGN_IDENTITY} ==="
# Remove previous signature if any
codesign --remove-signature "$APP" 2>/dev/null || true
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  codesign --force --deep --sign - "$APP"
else
  codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" "$APP"
fi
codesign --verify --deep --strict --verbose=2 "$APP" || true
echo "signed: $APP"

mkdir -p "$ROOT/dist"
rm -rf "$ROOT/dist/ArchGate Connect.app"
cp -R "$APP" "$ROOT/dist/"
if [[ -f "$DMG" ]]; then
  cp -f "$DMG" "$ROOT/dist/"
fi

echo "=== done ==="
echo "  $ROOT/dist/ArchGate Connect.app"
ls -la "$ROOT/dist/" 2>/dev/null | head -10
echo "Open: open \"$ROOT/dist/ArchGate Connect.app\""
echo "Note: ad-hoc sign is for local use; distribution needs Developer ID + notarize."
