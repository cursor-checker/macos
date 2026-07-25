#!/usr/bin/env bash
# Resolve scripts dir, app repo root (ROOT), and load project config.

swift_scripts_resolve_paths() {
  LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  SCRIPTS_DIR="$(cd "$LIB_DIR/.." && pwd)"
  CHANGELOG_DIR="$LIB_DIR/changelog"

  local legacy_root
  legacy_root="$(cd "$SCRIPTS_DIR/.." && pwd)"

  if [[ -f "$legacy_root/Package.swift" || -f "$legacy_root/scripts.config.sh" ]]; then
    SWIFT_SCRIPTS_MODE="legacy"
    ROOT="$legacy_root"
    PROJECTS_DIR=""
  else
    SWIFT_SCRIPTS_MODE="hub"
    ROOT=""
    PROJECTS_DIR="$SCRIPTS_DIR/projects"
  fi
}

swift_scripts_load_projects_registry() {
  SWIFT_SCRIPTS_PROJECTS=()
  local registry="$SCRIPTS_DIR/projects/projects.sh"
  if [[ -f "$registry" ]]; then
    # shellcheck source=/dev/null
    source "$registry"
  fi
}

swift_scripts_project_config_value() {
  local config="$1"
  local key="$2"
  local line value

  line="$(grep -E "^${key}=" "$config" 2>/dev/null | head -1 || true)"
  [[ -n "$line" ]] || return 1
  value="${line#*=}"
  value="${value#\"}"
  value="${value%\"}"
  value="${value#\'}"
  value="${value%\'}"
  printf '%s' "$value"
}

swift_scripts_project_label() {
  local slug="$1"
  local config="$PROJECTS_DIR/$slug/config.sh"
  local label="" source_repo="" release_repo=""

  if [[ -f "$config" ]]; then
    label="$(swift_scripts_project_config_value "$config" APP_DISPLAY_NAME || true)"
    [[ -n "$label" ]] || label="$(swift_scripts_project_config_value "$config" APP_NAME || true)"
    source_repo="$(swift_scripts_project_config_value "$config" SOURCE_REPO || true)"
    release_repo="$(swift_scripts_project_config_value "$config" RELEASE_REPO || true)"
  fi

  if [[ -n "$label" && -n "$source_repo" && -n "$release_repo" && "$source_repo" != "$release_repo" ]]; then
    printf '%s — %s · %s → %s' "$slug" "$label" "$source_repo" "$release_repo"
  elif [[ -n "$label" ]]; then
    printf '%s — %s' "$slug" "$label"
  else
    printf '%s' "$slug"
  fi
}

swift_scripts_list_projects() {
  local slug

  swift_scripts_load_projects_registry

  for slug in "${SWIFT_SCRIPTS_PROJECTS[@]}"; do
    [[ -n "$slug" && -f "$PROJECTS_DIR/$slug/config.sh" ]] || continue
    printf '%s\n' "$slug"
  done
}

swift_scripts_project_is_registered() {
  local slug="$1"
  local candidate

  swift_scripts_load_projects_registry
  for candidate in "${SWIFT_SCRIPTS_PROJECTS[@]}"; do
    [[ "$candidate" == "$slug" ]] && return 0
  done
  return 1
}

swift_scripts_prompt_project() {
  local -a projects=()
  local slug choice i default_index=1

  while IFS= read -r slug; do
    [[ -n "$slug" ]] && projects+=("$slug")
  done < <(swift_scripts_list_projects)

  if [[ ${#projects[@]} -eq 0 ]]; then
    echo "error: no projects registered (edit projects/projects.sh and add config under projects/<slug>/)" >&2
    exit 1
  fi

  if [[ ! -t 0 || ! -t 1 ]]; then
    swift_scripts_project_usage
    exit 1
  fi

  echo "Select project:"
  for i in "${!projects[@]}"; do
    printf '  %d) %s\n' "$((i + 1))" "$(swift_scripts_project_label "${projects[$i]}")"
  done
  echo

  while true; do
    printf 'Choice [%d]: ' "$default_index"
    read -r choice
    choice="${choice:-$default_index}"

    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#projects[@]} )); then
      SWIFT_SCRIPTS_PROJECT="${projects[$((choice - 1))]}"
      echo "==> Project: $(swift_scripts_project_label "$SWIFT_SCRIPTS_PROJECT")"
      return 0
    fi

    for slug in "${projects[@]}"; do
      if [[ "$choice" == "$slug" ]]; then
        SWIFT_SCRIPTS_PROJECT="$slug"
        echo "==> Project: $(swift_scripts_project_label "$SWIFT_SCRIPTS_PROJECT")"
        return 0
      fi
    done

    echo "Invalid choice: $choice" >&2
  done
}

swift_scripts_project_usage() {
  echo "error: project is required in hub mode." >&2
  echo "Usage: $0 [project] [options...]" >&2
  echo "       SWIFT_SCRIPTS_PROJECT=<project> $0 [options...]" >&2
  local projects
  projects="$(swift_scripts_list_projects)"
  if [[ -n "$projects" ]]; then
    echo "Registered projects:" >&2
    while IFS= read -r project; do
      [[ -n "$project" ]] && echo "  - $(swift_scripts_project_label "$project")" >&2
    done <<< "$projects"
  fi
}

swift_scripts_consume_project_arg() {
  if [[ "$SWIFT_SCRIPTS_MODE" != hub ]]; then
    SWIFT_SCRIPTS_ARGS=("$@")
    return 0
  fi

  if [[ -n "${SWIFT_SCRIPTS_PROJECT:-}" ]]; then
    SWIFT_SCRIPTS_ARGS=("$@")
    return 0
  fi

  if [[ $# -eq 0 || "$1" == --* ]]; then
    SWIFT_SCRIPTS_ARGS=("$@")
    swift_scripts_prompt_project
    return 0
  fi

  if ! swift_scripts_project_is_registered "$1"; then
    echo "error: unknown project '$1' (not listed in projects/projects.sh)" >&2
    swift_scripts_project_usage
    exit 1
  fi

  SWIFT_SCRIPTS_PROJECT="$1"
  shift
  SWIFT_SCRIPTS_ARGS=("$@")
}

swift_scripts_generate_config() {
  local config="$1"

  if [[ ! -f "$ROOT/Package.swift" && ! -f "$ROOT/Resources/Info.plist" ]]; then
    echo "error: missing $config and could not scan project (no Package.swift or Resources/Info.plist)" >&2
    return 1
  fi

  echo "==> Creating scripts.config.sh from project scan"
  python3 "$LIB_DIR/scan_project_config.py" --root "$ROOT" --output "$config"
  echo "    Review RELEASE_REPO in scripts.config.sh before publishing."
}

swift_scripts_apply_config() {
  set -a
  # shellcheck source=/dev/null
  source "$1"
  set +a

  if [[ "$SWIFT_SCRIPTS_MODE" == hub ]]; then
    : "${PROJECT_ROOT:?PROJECT_ROOT must be set in projects/<name>/config.sh}"
    ROOT="$(cd "$PROJECT_ROOT" && pwd)"
  fi

  : "${APP_NAME:?APP_NAME must be set in project config}"
  : "${BUNDLE_ID:?BUNDLE_ID must be set in project config}"
  : "${RELEASE_REPO:?RELEASE_REPO must be set in project config}"
  : "${SOURCES_MODULE_DIR:?SOURCES_MODULE_DIR must be set in project config}"

  SWIFT_MODULE="${SWIFT_MODULE:-$APP_NAME}"
  APP_DISPLAY_NAME="${APP_DISPLAY_NAME:-$APP_NAME}"
  RELEASE_APP_NAME="${RELEASE_APP_NAME:-$APP_DISPLAY_NAME}"
  ENTITLEMENTS="${ENTITLEMENTS:-Resources/${APP_NAME}.entitlements}"
  DMG_VOLUME_NAME="${DMG_VOLUME_NAME:-$APP_DISPLAY_NAME}"
  MACOS_DEPLOYMENT_TARGET="${MACOS_DEPLOYMENT_TARGET:-15.0}"
  CHANGELOG_EN="${CHANGELOG_EN:-}"
  BUNDLED_CHANGELOG="${BUNDLED_CHANGELOG:-$SOURCES_MODULE_DIR/Bundled/CHANGELOG.md}"
  BUNDLED_CHANGELOG_EN="${BUNDLED_CHANGELOG_EN:-$SOURCES_MODULE_DIR/Bundled/CHANGELOG.en.md}"
  CHANGELOG_DATA_SWIFT="${CHANGELOG_DATA_SWIFT:-$SOURCES_MODULE_DIR/Domain/ChangelogData.swift}"
  LOCALIZATIONS_XCSTRINGS="${LOCALIZATIONS_XCSTRINGS:-}"
  CHANGELOG_BILINGUAL="${CHANGELOG_BILINGUAL:-0}"

  SOURCE_REPO="${SOURCE_REPO:-}"

  export ROOT SCRIPTS_DIR LIB_DIR CHANGELOG_DIR SWIFT_SCRIPTS_MODE SWIFT_SCRIPTS_PROJECT PROJECTS_DIR
  export APP_NAME SWIFT_MODULE APP_DISPLAY_NAME RELEASE_APP_NAME
  export BUNDLE_ID SOURCE_REPO RELEASE_REPO SOURCES_MODULE_DIR ENTITLEMENTS DMG_VOLUME_NAME
  export MACOS_DEPLOYMENT_TARGET CHANGELOG_EN BUNDLED_CHANGELOG BUNDLED_CHANGELOG_EN
  export CHANGELOG_DATA_SWIFT LOCALIZATIONS_XCSTRINGS CHANGELOG_BILINGUAL
}

swift_scripts_load_config() {
  local config=""

  if [[ "$SWIFT_SCRIPTS_MODE" == legacy ]]; then
    config="$ROOT/scripts.config.sh"
    if [[ ! -f "$config" ]]; then
      swift_scripts_generate_config "$config" || exit 1
    fi
  else
    if [[ -z "${SWIFT_SCRIPTS_PROJECT:-}" ]]; then
      swift_scripts_prompt_project
    fi

    if ! swift_scripts_project_is_registered "$SWIFT_SCRIPTS_PROJECT"; then
      echo "error: unknown project '$SWIFT_SCRIPTS_PROJECT' (not listed in projects/projects.sh)" >&2
      swift_scripts_project_usage
      exit 1
    fi

    config="$PROJECTS_DIR/$SWIFT_SCRIPTS_PROJECT/config.sh"
    if [[ ! -f "$config" ]]; then
      echo "error: missing config for '$SWIFT_SCRIPTS_PROJECT' ($config)" >&2
      echo "Run: ./lib/init_project.sh $SWIFT_SCRIPTS_PROJECT <app-repo-path>" >&2
      exit 1
    fi
  fi

  swift_scripts_apply_config "$config"
}

swift_scripts_build_release_git_files() {
  RELEASE_GIT_FILES=(
    Resources/Info.plist
    CHANGELOG.md
  )
  if [[ -n "$CHANGELOG_EN" ]]; then
    RELEASE_GIT_FILES+=("$CHANGELOG_EN")
  fi
  RELEASE_GIT_FILES+=("$BUNDLED_CHANGELOG")
  if [[ "$CHANGELOG_BILINGUAL" == 1 ]]; then
    RELEASE_GIT_FILES+=("$BUNDLED_CHANGELOG_EN")
  fi
  RELEASE_GIT_FILES+=("$CHANGELOG_DATA_SWIFT")
}

swift_scripts_sync_changelog_artifacts() {
  if [[ ! -f "$ROOT/CHANGELOG.md" ]]; then
    return 0
  fi

  mkdir -p "$(dirname "$ROOT/$BUNDLED_CHANGELOG")"
  cp "$ROOT/CHANGELOG.md" "$ROOT/$BUNDLED_CHANGELOG"
  if [[ "$CHANGELOG_BILINGUAL" == 1 && -n "$CHANGELOG_EN" && -f "$ROOT/$CHANGELOG_EN" ]]; then
    mkdir -p "$(dirname "$ROOT/$BUNDLED_CHANGELOG_EN")"
    cp "$ROOT/$CHANGELOG_EN" "$ROOT/$BUNDLED_CHANGELOG_EN"
  fi
  python3 "$LIB_DIR/generate_changelog_data.py"
}

swift_scripts_init() {
  swift_scripts_resolve_paths
  swift_scripts_load_config
  cd "$ROOT"
}

swift_scripts_init_with_args() {
  SWIFT_SCRIPTS_ARGS=()
  swift_scripts_resolve_paths
  swift_scripts_consume_project_arg "$@"
  swift_scripts_load_config
  cd "$ROOT"
}

# Bash 3.2 + set -u treats an empty "${arr[@]}" as unbound — use this instead.
swift_scripts_apply_remaining_args() {
  if ((${#SWIFT_SCRIPTS_ARGS[@]} > 0)); then
    set -- "${SWIFT_SCRIPTS_ARGS[@]}"
  else
    set --
  fi
}

swift_scripts_init_minimal() {
  swift_scripts_resolve_paths

  if [[ -n "${ROOT:-}" && -f "$ROOT/Resources/Info.plist" ]]; then
    cd "$ROOT"
    return 0
  fi

  if [[ "$SWIFT_SCRIPTS_MODE" == legacy ]]; then
    cd "$ROOT"
    return 0
  fi

  if [[ -n "${SWIFT_SCRIPTS_PROJECT:-}" ]]; then
    swift_scripts_load_config
    cd "$ROOT"
    return 0
  fi

  cd "$SCRIPTS_DIR"
}
