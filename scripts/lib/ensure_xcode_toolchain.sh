#!/usr/bin/env bash
# SwiftUI (@State, @Preview, etc.) needs SwiftUIMacros from full Xcode.app.
# Command Line Tools alone only ship SwiftMacros — builds fail with:
#   plugin for module 'SwiftUIMacros' not found

_xcode_has_swiftui_macros() {
  local dev="$1"
  [[ -f "$dev/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins/libSwiftUIMacros.dylib" ]] \
    || [[ -f "$dev/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/plugins/libSwiftUIMacros.dylib" ]]
}

ensure_xcode_toolchain() {
  if [[ -n "${DEVELOPER_DIR:-}" ]] && _xcode_has_swiftui_macros "$DEVELOPER_DIR"; then
    export PATH="$DEVELOPER_DIR/usr/bin:$PATH"
    return 0
  fi

  local candidates=(
    "/Applications/Xcode-beta.app/Contents/Developer"
    "/Applications/Xcode.app/Contents/Developer"
  )

  for dev in "${candidates[@]}"; do
    if _xcode_has_swiftui_macros "$dev"; then
      export DEVELOPER_DIR="$dev"
      export PATH="$DEVELOPER_DIR/usr/bin:$PATH"
      return 0
    fi
  done

  echo "error: SwiftUI requires Xcode.app — SwiftUIMacros is not in Command Line Tools." >&2
  echo "" >&2
  echo "Install Xcode (or Xcode-beta), open it once to finish setup, then run one of:" >&2
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
  echo "  sudo xcode-select -s /Applications/Xcode-beta.app/Contents/Developer" >&2
  echo "" >&2
  echo "Active developer dir: $(xcode-select -p 2>/dev/null || echo 'unknown')" >&2
  return 1
}

swift_scripts_use_xcode_toolchain() {
  local use_stable_xcode="${1:-${SWIFT_SCRIPTS_USE_STABLE_XCODE:-0}}"
  if [[ "$use_stable_xcode" == 1 ]]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
  fi
  ensure_xcode_toolchain
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  ensure_xcode_toolchain || exit 1
  echo "Using DEVELOPER_DIR=$DEVELOPER_DIR"
  exec swift "$@"
fi
