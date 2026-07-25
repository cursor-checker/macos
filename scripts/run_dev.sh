#!/usr/bin/env bash
# Run the app from source (debug) as a real .app bundle.
#
# Usage:
#   ./scripts/run_dev.sh           # prefer Xcode-beta, then Xcode
#   ./scripts/run_dev.sh --old     # force stable Xcode.app
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/project.sh
source "$SCRIPT_DIR/lib/project.sh"
swift_scripts_init

USE_STABLE_XCODE=0
APP_ARGS=()
for arg in "$@"; do
  case "$arg" in
    --old) USE_STABLE_XCODE=1 ;;
    *) APP_ARGS+=("$arg") ;;
  esac
done

if [[ "$USE_STABLE_XCODE" -eq 1 ]]; then
  export SWIFT_SCRIPTS_USE_STABLE_XCODE=1
fi

# shellcheck source=lib/ensure_xcode_toolchain.sh
source "$SCRIPT_DIR/lib/ensure_xcode_toolchain.sh"
swift_scripts_use_xcode_toolchain "$USE_STABLE_XCODE"
echo "==> Using Xcode: $DEVELOPER_DIR"

APP="$ROOT/.build/${APP_NAME}-dev.app"

echo "==> Stopping running instances"
osascript -e "quit app \"$APP_DISPLAY_NAME\"" 2>/dev/null || true
pkill -x "$APP_NAME" 2>/dev/null || true
sleep 0.3

if [[ -n "$LOCALIZATIONS_XCSTRINGS" ]]; then
  echo "==> Compiling localizations"
  "$LIB_DIR/compile_localizations.sh"
fi

echo "==> Building debug binary"
swift build --product "$APP_NAME"

BIN="$(swift build --show-bin-path)/${APP_NAME}"
MODULE_BUNDLE="$(swift build --show-bin-path)/${APP_NAME}_${APP_NAME}.bundle"
if [[ ! -d "$MODULE_BUNDLE" ]]; then
  MODULE_BUNDLE="$(find "$ROOT/.build" -name "${APP_NAME}_${APP_NAME}.bundle" -type d | head -1)"
fi

echo "==> Assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$APP_NAME"
if [[ -d "$MODULE_BUNDLE" ]]; then
  cp -R "$MODULE_BUNDLE" "$APP/Contents/Resources/"
fi
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
codesign -s - -f --deep --force "$APP" >/dev/null 2>&1 || true
xattr -cr "$APP" 2>/dev/null || true

echo "==> Launching (debug)"
exec "$APP/Contents/MacOS/$APP_NAME" "${APP_ARGS[@]+"${APP_ARGS[@]}"}"
