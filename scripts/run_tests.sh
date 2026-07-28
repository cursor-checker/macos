#!/usr/bin/env bash
# Run Swift Package Manager unit tests with a compact visual summary.
#
# Usage:
#   ./scripts/run_tests.sh                    # all tests
#   ./scripts/run_tests.sh --old              # force stable Xcode.app
#   ./scripts/run_tests.sh --filter AlertEnginePacingTests
#   ./scripts/run_tests.sh --verbose --filter AlertEnginePacingTests/testMidDaySpendDoesNotShrinkSmartThreshold
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/project.sh
source "$SCRIPT_DIR/lib/project.sh"
swift_scripts_init

USE_STABLE_XCODE=0
TEST_ARGS=()
for arg in "$@"; do
  case "$arg" in
    --old) USE_STABLE_XCODE=1 ;;
    *) TEST_ARGS+=("$arg") ;;
  esac
done

if [[ "$USE_STABLE_XCODE" -eq 1 ]]; then
  export SWIFT_SCRIPTS_USE_STABLE_XCODE=1
fi

# shellcheck source=lib/ensure_xcode_toolchain.sh
source "$SCRIPT_DIR/lib/ensure_xcode_toolchain.sh"
swift_scripts_use_xcode_toolchain "$USE_STABLE_XCODE"
echo "==> Using Xcode: $DEVELOPER_DIR"

if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'
  C_DIM=$'\033[2m'
  C_BOLD=$'\033[1m'
  C_GREEN=$'\033[32m'
  C_RED=$'\033[31m'
  C_YELLOW=$'\033[33m'
  C_CYAN=$'\033[36m'
else
  C_RESET= C_DIM= C_BOLD= C_GREEN= C_RED= C_YELLOW= C_CYAN=
fi

PASSED=0
FAILED=0

echo "==> Running unit tests"
echo

LOG="$(mktemp -t cursor-checker-tests.XXXXXX)"
trap 'rm -f "$LOG"' EXIT

set +e
swift test "${TEST_ARGS[@]+"${TEST_ARGS[@]}"}" >"$LOG" 2>&1
STATUS=$?
set -e

# Strip ANSI / progress redraw noise from SPM build lines.
clean_line() {
  # shellcheck disable=SC2001
  sed -e $'s/\033\\[[0-9;]*[A-Za-z]//g' -e $'s/\r//g' <<<"$1" \
    | tr -d '\200-\377'
}

while IFS= read -r raw || [[ -n "$raw" ]]; do
  line="$(clean_line "$raw")"
  line="${line#"${line%%[![:space:]]*}"}"  # ltrim
  [[ -n "$line" ]] || continue

  # Drop Swift Testing runner chatter (empty second harness when only XCTest exists)
  case "$line" in
    *"Testing Library Version:"*|*"Target Platform:"*|*"Test run started."*|*"Test run with 0 tests"*)
      continue
      ;;
  esac

  # Build progress
  if [[ "$line" == Building* || "$line" == *"Build complete"* ]]; then
    printf '%s%s%s\n' "$C_DIM" "$line" "$C_RESET"
    [[ "$line" == *"Build complete"* ]] && echo
    continue
  fi
  if [[ "$line" == \[*/*\]* ]]; then
    printf '%s%s%s\n' "$C_DIM" "$line" "$C_RESET"
    continue
  fi

  # Suite headers — only real XCTestCase suites
  if [[ "$line" =~ Test\ Suite\ \'([^\']+)\'\ started ]]; then
    suite="${BASH_REMATCH[1]}"
    if [[ "$suite" != "All tests" && "$suite" != *.xctest ]]; then
      printf '%s▸ %s%s\n' "$C_CYAN" "$suite" "$C_RESET"
    fi
    continue
  fi
  if [[ "$line" =~ Test\ Suite\ \'([^\']+)\'\ (passed|failed) ]]; then
    continue
  fi

  # Individual cases: ... ClassName testMethod]' passed/failed (...)
  if [[ "$line" =~ Test\ Case\ \'\-\[[^\ ]+\ ([^]\ ]+)\]\'\ passed ]]; then
    name="${BASH_REMATCH[1]}"
    PASSED=$((PASSED + 1))
    printf '  %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$name"
    continue
  fi
  if [[ "$line" =~ Test\ Case\ \'\-\[[^\ ]+\ ([^]\ ]+)\]\'\ failed ]]; then
    name="${BASH_REMATCH[1]}"
    FAILED=$((FAILED + 1))
    printf '  %s✗%s %s%s failed%s\n' "$C_RED" "$C_RESET" "$C_BOLD" "$name" "$C_RESET"
    continue
  fi
  if [[ "$line" == "Test Case '"*"' started." ]]; then
    continue
  fi
  if [[ "$line" == Executed* ]]; then
    continue
  fi

  # Keep assert / error details
  printf '%s\n' "$line"
done < "$LOG"

TOTAL=$((PASSED + FAILED))

echo
echo "${C_DIM}────────────────────────────────────────${C_RESET}"
if [[ "$STATUS" -eq 0 && "$FAILED" -eq 0 ]]; then
  printf '%s%s✓ %d passed%s' "$C_BOLD" "$C_GREEN" "$PASSED" "$C_RESET"
  if [[ "$TOTAL" -eq 0 ]]; then
    printf ' %s(no XCTest cases matched)%s' "$C_YELLOW" "$C_RESET"
  fi
  echo
  echo "${C_DIM}────────────────────────────────────────${C_RESET}"
  exit 0
fi

printf '%s%s✗ %d failed%s' "$C_BOLD" "$C_RED" "$FAILED" "$C_RESET"
if [[ "$PASSED" -gt 0 ]]; then
  printf ', %s%d passed%s' "$C_GREEN" "$PASSED" "$C_RESET"
fi
echo
echo "${C_DIM}────────────────────────────────────────${C_RESET}"
exit "$STATUS"
