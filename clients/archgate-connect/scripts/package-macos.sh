#!/usr/bin/env bash
# Build ArchGate Connect .app + .dmg, codesign, optional notarize.
#
# Usage:
#   ./scripts/package-macos.sh
#   SIGN_IDENTITY="Developer ID Application: …" ./scripts/package-macos.sh
#   SIGN_IDENTITY="Developer ID Application: …" NOTARY_PROFILE=archgate ./scripts/package-macos.sh --notarize
#
# See: documentos/runbooks/archgate-connect-macos-notarize.md
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESKTOP="$ROOT/desktop"
TRIPLE="$(rustc -vV | sed -n 's/^host: //p')"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
DO_NOTARY=0
for a in "$@"; do
  case "$a" in
    --notarize) DO_NOTARY=1 ;;
  esac
done

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
codesign --remove-signature "$APP" 2>/dev/null || true
# Sign nested archgate first, then the app bundle.
if [[ -x "$APP/Contents/MacOS/archgate" ]]; then
  if [[ "$SIGN_IDENTITY" == "-" ]]; then
    codesign --force --sign - "$APP/Contents/MacOS/archgate"
  else
    codesign --force --options runtime --sign "$SIGN_IDENTITY" "$APP/Contents/MacOS/archgate"
  fi
fi
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  codesign --force --deep --sign - "$APP"
else
  codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" "$APP"
fi
codesign --verify --deep --strict --verbose=2 "$APP"
echo "signed: $APP"

if [[ "$DO_NOTARY" == "1" ]]; then
  if [[ "$SIGN_IDENTITY" == "-" ]]; then
    echo "FAIL: --notarize requires SIGN_IDENTITY=Developer ID Application: …"
    exit 1
  fi
  if [[ -z "$NOTARY_PROFILE" ]]; then
    echo "FAIL: set NOTARY_PROFILE (from: xcrun notarytool store-credentials …)"
    exit 1
  fi
  ZIP="${TMPDIR:-/tmp}/ArchGate-Connect-notarize.zip"
  echo "=== notarize profile=$NOTARY_PROFILE ==="
  ditto -c -k --keepParent "$APP" "$ZIP"
  xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
  if [[ -f "$DMG" ]]; then
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait || true
    xcrun stapler staple "$DMG" 2>/dev/null || true
  fi
  echo "notarized + stapled"
  spctl --assess --type execute -vv "$APP" || true
fi

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
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  echo "Note: ad-hoc sign is local-only. See documentos/runbooks/archgate-connect-macos-notarize.md"
fi
