#!/usr/bin/env bash
# Compile Localizable.xcstrings into .lproj/Localizable.strings for runtime lookup.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=project.sh
source "$SCRIPT_DIR/project.sh"
swift_scripts_init

if [[ -z "$LOCALIZATIONS_XCSTRINGS" ]]; then
  echo "LOCALIZATIONS_XCSTRINGS is not set in scripts.config.sh — skipping." >&2
  exit 0
fi

XCSTRINGS="$ROOT/$LOCALIZATIONS_XCSTRINGS"
OUT="$(dirname "$XCSTRINGS")"
EN_STRINGS="$OUT/en.lproj/Localizable.strings"
RU_STRINGS="$OUT/ru.lproj/Localizable.strings"

usage() {
  cat <<'EOF'
Usage: scripts/lib/compile_localizations.sh [--check]

  (default) Compile Localizable.xcstrings -> en.lproj / ru.lproj
  --check   Exit 1 if .lproj files are missing or older than .xcstrings
EOF
}

needs_compile() {
  [[ ! -f "$EN_STRINGS" || ! -f "$RU_STRINGS" ]] && return 0
  [[ "$XCSTRINGS" -nt "$EN_STRINGS" || "$XCSTRINGS" -nt "$RU_STRINGS" ]]
}

compile() {
  if [[ ! -f "$XCSTRINGS" ]]; then
    echo "Missing $XCSTRINGS" >&2
    exit 1
  fi
  xcrun xcstringstool compile "$XCSTRINGS" --output-directory "$OUT"
  echo "Compiled localizations -> $OUT/{en,ru}.lproj"
}

case "${1:-}" in
  --check)
    if needs_compile; then
      echo "Localizations out of date. Run: scripts/lib/compile_localizations.sh" >&2
      exit 1
    fi
    ;;
  --help|-h)
    usage
    ;;
  "")
    compile
    ;;
  *)
    echo "Unknown option: $1" >&2
    usage >&2
    exit 2
    ;;
esac
