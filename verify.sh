#!/usr/bin/env bash
set -euo pipefail

# ==============================================================
# verify.sh — Verify Installation Status
# ==============================================================
# Checks that all expected tools and symlinks are in place.
# Run after install.sh or anytime to verify setup health.
#
# Usage:
#   bash verify.sh
#
# ==============================================================

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/dotfiles"
VSCODE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/vscode"

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

pass()  { echo -e "${GREEN}✓${NC} $*"; }
fail()  { echo -e "${RED}✗${NC} $*"; }
warn()  { echo -e "${YELLOW}⚠${NC} $*"; }
info()  { echo -e "${CYAN}ℹ${NC} $*"; }

echo ""
echo "=============================================="
echo "  Verifying Dev Environment Setup"
echo "=============================================="
echo ""

# Ensure mise shims are on PATH (verify.sh runs in bash, not interactive zsh)
_mise_shims="${XDG_DATA_HOME:-$HOME/.local/share}/mise/shims"
if [[ -d "$_mise_shims" && ":$PATH:" != *":$_mise_shims:"* ]]; then
  export PATH="$_mise_shims:$PATH"
fi

# Detect VS Code path
if [[ "$(uname)" == "Darwin" ]]; then
  VSCODE_SETTINGS_PATH="$HOME/Library/Application Support/Code/User"
else
  VSCODE_SETTINGS_PATH="$HOME/.config/Code/User"
fi

# ==============================================================
# CHECK COMMANDS
# ==============================================================

echo "Command Availability:"
echo ""

has() { command -v "$1" &>/dev/null; }

# Parallel arrays: command names and descriptions
declare -a cmd_names=("zsh"           "git"                  "mise"               "python"            "uv"                      "code")
declare -a cmd_desc=("Shell"          "Git version control"  "Runtime manager"    "Python (via mise)"  "Python package manager"  "VS Code")

for ((i = 0; i < ${#cmd_names[@]}; i++)); do
  cmd="${cmd_names[$i]}"
  desc="${cmd_desc[$i]}"
  if has "$cmd"; then
    pass "$cmd — $desc"
  else
    fail "$cmd — $desc"
  fi
done

# ==============================================================
# CHECK SYMLINKS
# ==============================================================

echo ""
echo "Symlinks:"
echo ""

check_symlink() {
  local dest="$1"
  local src="$2"
  if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
    pass "$(basename "$dest") → $(basename "$src")"
  else
    fail "$(basename "$dest")"
  fi
}

check_symlink "$HOME/.zshenv" "$DOTFILES_DIR/.zshenv"
check_symlink "$HOME/.zshrc" "$DOTFILES_DIR/.zshrc"
check_symlink "$HOME/.p10k.zsh" "$DOTFILES_DIR/.p10k.zsh"
check_symlink "$HOME/.zsh-plugins" "$DOTFILES_DIR/zsh-plugins"

if [[ -d "$VSCODE_SETTINGS_PATH" ]]; then
  check_symlink "$VSCODE_SETTINGS_PATH/settings.json" "$VSCODE_DIR/settings.json"
  check_symlink "$VSCODE_SETTINGS_PATH/keybindings.json" "$VSCODE_DIR/keybindings.json"
else
  warn "VS Code settings directory not found (VS Code may not be installed)"
fi

# ==============================================================
# CHECK GIT CONFIG
# ==============================================================

echo ""
echo "Git Configuration:"
echo ""

git_name=$(git config --global user.name 2>/dev/null || echo "")
git_email=$(git config --global user.email 2>/dev/null || echo "")

if [[ -n "$git_name" ]]; then
  pass "user.name: $git_name"
else
  fail "user.name not set"
fi

if [[ -n "$git_email" ]]; then
  pass "user.email: $git_email"
else
  fail "user.email not set"
fi

# ==============================================================
# CHECK PYTHON & DEPENDENCIES
# ==============================================================

echo ""
echo "Python Environment:"
echo ""

if has python; then
  py_version=$(python --version 2>&1)
  pass "Python installed: $py_version"
else
  fail "Python not installed"
fi

if has uv; then
  pass "uv available for package management"
else
  fail "uv not available"
fi

# ==============================================================
# CHECK VS CODE EXTENSIONS
# ==============================================================

if has code; then
  echo ""
  echo "VS Code Extensions:"
  echo ""
  
  ext_count=$(code --list-extensions 2>/dev/null | wc -l)
  if [[ $ext_count -gt 0 ]]; then
    pass "$ext_count extensions installed"
  else
    warn "No extensions detected"
  fi
fi

# ==============================================================
# SUMMARY
# ==============================================================

echo ""
echo "=============================================="
info "Verification complete. Check output above for any ✗ marks to address."
echo "=============================================="
echo ""
