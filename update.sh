#!/usr/bin/env bash
set -euo pipefail

# ==============================================================
# update.sh — Check and Apply Environment Updates
# ==============================================================
# Keeps core dev tooling up to date (Homebrew + mise-managed runtimes).
#
# Usage:
#   bash update.sh check
#   bash update.sh upgrade
#   bash update.sh upgrade --yes
#
# ============================================================== 

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
LAST_CHECK_FILE="$STATE_DIR/last-update-check"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
has()     { command -v "$1" &>/dev/null; }

usage() {
  cat <<'USAGE_EOF'
Usage:
  bash update.sh check
  bash update.sh upgrade [--yes]

Commands:
  check      Refresh package metadata and show available updates.
  upgrade    Apply updates (with confirmation prompt by default).

Options:
  --yes      Skip confirmation prompt for upgrade.
USAGE_EOF
}

record_last_check() {
  mkdir -p "$STATE_DIR"
  date -u +"%Y-%m-%dT%H:%M:%SZ" > "$LAST_CHECK_FILE"
}

supports_mise_subcommand() {
  local subcommand="$1"
  mise help 2>/dev/null | grep -Eq "(^|[[:space:]])${subcommand}([[:space:]]|$)"
}

# Returns 0 if uv is managed by Homebrew, 1 otherwise.
uv_is_brew_managed() {
  has brew && brew list --formula uv >/dev/null 2>&1
}

run_check() {
  local brew_outdated_count=0
  local mise_outdated_count=0
  local uv_tools_count=0
  local brew_outdated_output=""
  local mise_outdated_output=""
  local uv_tools_output=""

  echo ""
  echo "=============================================="
  echo "  Checking for Updates"
  echo "=============================================="
  echo ""

  if has brew; then
    info "Refreshing Homebrew metadata..."
    brew update >/dev/null

    brew_outdated_output="$(brew outdated --quiet 2>/dev/null || true)"
    if [[ -n "$brew_outdated_output" ]]; then
      brew_outdated_count="$(printf '%s\n' "$brew_outdated_output" | wc -l | tr -d ' ')"
    fi
  else
    warn "Homebrew not found. Skipping brew checks."
  fi

  if has mise; then
    if supports_mise_subcommand "outdated"; then
      info "Checking mise-managed runtimes..."
      mise_outdated_output="$(mise outdated 2>/dev/null || true)"
      if [[ -n "$mise_outdated_output" ]]; then
        mise_outdated_count="$(printf '%s\n' "$mise_outdated_output" | wc -l | tr -d ' ')"
      fi
    else
      warn "This mise version does not support 'mise outdated'."
    fi
  else
    warn "mise not found. Skipping runtime checks."
  fi

  if has uv; then
    info "Checking uv-managed tools..."
    uv_tools_output="$(uv tool list 2>/dev/null || true)"
    if [[ -n "$uv_tools_output" ]]; then
      uv_tools_count="$(printf '%s\n' "$uv_tools_output" | wc -l | tr -d ' ')"
    fi
  else
    warn "uv not found. Skipping uv tool checks."
  fi

  record_last_check

  echo ""
  echo "Update Summary:"
  echo ""
  echo "  Homebrew updates available: $brew_outdated_count"
  if [[ $brew_outdated_count -gt 0 ]]; then
    printf '%s\n' "$brew_outdated_output" | sed 's/^/    - /'
  fi

  echo ""
  echo "  mise runtime updates available: $mise_outdated_count"
  if [[ $mise_outdated_count -gt 0 ]]; then
    printf '%s\n' "$mise_outdated_output" | sed 's/^/    - /'
  fi

  echo ""
  if has uv; then
    if uv_is_brew_managed; then
      echo "  uv: managed by Homebrew (upgrades via brew above)"
    else
      echo "  uv: self-managed (run 'uv self update' to upgrade)"
    fi
    echo "  uv tools installed: $uv_tools_count"
    if [[ $uv_tools_count -gt 0 ]]; then
      printf '%s\n' "$uv_tools_output" | sed 's/^/    /'
    fi
  fi

  echo ""
  success "Check complete. Last check timestamp updated at: $LAST_CHECK_FILE"
  echo ""
}

run_upgrade() {
  local assume_yes="${1:-false}"

  echo ""
  echo "=============================================="
  echo "  Applying Updates"
  echo "=============================================="
  echo ""

  if [[ "$assume_yes" != "true" ]]; then
    read -rp "About to update Homebrew packages, mise-managed runtimes, and uv tools. Continue? [Y/n]: " confirm
    if [[ ! "${confirm:-Y}" =~ ^[Yy]$ ]]; then
      info "Update cancelled."
      echo ""
      return 0
    fi
  fi

  if has brew; then
    info "Running: brew update"
    brew update
    info "Running: brew upgrade"
    brew upgrade
    info "Running: brew cleanup"
    brew cleanup
    success "Homebrew updates applied."
  else
    warn "Homebrew not found. Skipping brew updates."
  fi

  if has mise; then
    if supports_mise_subcommand "plugins"; then
      info "Running: mise plugins update --all"
      mise plugins update --all || warn "mise plugins update reported an issue."
    fi

    if supports_mise_subcommand "upgrade"; then
      info "Running: mise upgrade"
      mise upgrade || warn "mise upgrade reported an issue."
      success "mise runtime updates attempted."
    else
      warn "This mise version does not support 'mise upgrade'."
    fi
  else
    warn "mise not found. Skipping runtime updates."
  fi

  if has uv; then
    local uv_tools_output
    uv_tools_output="$(uv tool list 2>/dev/null || true)"
    if [[ -n "$uv_tools_output" ]]; then
      info "Running: uv tool upgrade --all"
      uv tool upgrade --all || warn "uv tool upgrade reported an issue."
      success "uv tools upgraded."
    else
      info "No uv-managed tools installed. Skipping uv tool upgrade."
    fi

    if ! uv_is_brew_managed; then
      info "Running: uv self update"
      uv self update || warn "uv self update reported an issue."
      success "uv self-update attempted."
    else
      info "uv is Homebrew-managed — upgraded via brew above."
    fi
  else
    warn "uv not found. Skipping uv updates."
  fi

  record_last_check

  echo ""
  success "Update run complete."
  echo ""
}

main() {
  local command="${1:-check}"
  local assume_yes="false"

  shift || true

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --yes)
        assume_yes="true"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        error "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
  done

  case "$command" in
    check)
      run_check
      ;;
    upgrade)
      run_upgrade "$assume_yes"
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      error "Unknown command: $command"
      usage
      exit 1
      ;;
  esac
}

main "$@"
