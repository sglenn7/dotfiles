#!/usr/bin/env bash
set -euo pipefail

# ==============================================================
# backup.sh — Restore a Previous Config Backup
# ==============================================================
# Lists available backups and lets you restore one,
# removing symlinks and copying real files back into place.
#
# Usage:
#   bash backup.sh
#
# ==============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

echo ""
echo "=============================================="
echo "  Config Backup Restore"
echo "=============================================="
echo ""

# Detect VS Code settings path
if [[ "$(uname)" == "Darwin" ]]; then
  VSCODE_SETTINGS_PATH="$HOME/Library/Application Support/Code/User"
else
  VSCODE_SETTINGS_PATH="$HOME/.config/Code/User"
fi

# Find all backups (format: .dotfiles_backup_YYYY-MM-DD)
# Use indexed arrays for bash 3.2 compatibility
backup_index=0
declare -a backup_dirs
while IFS= read -r backup_dir; do
  backup_dirs[$backup_index]="$backup_dir"
  (( ++backup_index ))
done < <(find "$HOME" -maxdepth 1 -type d -name ".dotfiles_backup_*" 2>/dev/null | sort -r)

if [[ $backup_index -eq 0 ]]; then
  warn "No backups found in $HOME/.dotfiles_backup_*"
  echo ""
  exit 0
fi

echo "Available backups:"
echo ""
for ((i = 0; i < backup_index; i++)); do
  backup_date="${backup_dirs[$i]##*/}"
  echo "  [$((i+1))] $backup_date"
done
echo ""

read -rp "Select a backup to restore [1-${backup_index}]: " selection

if ! [[ "$selection" =~ ^[0-9]+$ ]] || (( selection < 1 || selection > backup_index )); then
  error "Invalid selection."
  exit 1
fi

BACKUP_DIR="${backup_dirs[$((selection-1))]}"
backup_name="${BACKUP_DIR##*/}"

echo ""
info "Selected: $backup_name"
echo ""
echo "Contents:"
ls -la "$BACKUP_DIR" | tail -n +4 | awk '{print "  " $0}'
echo ""

read -rp "Restore from this backup? [Y/n]: " confirm
if [[ ! "${confirm:-Y}" =~ ^[Yy]$ ]]; then
  info "Restore cancelled."
  exit 0
fi

echo ""
info "Restoring files from: $BACKUP_DIR"
echo ""

# Restore function: remove symlink if present, then copy file
restore_file() {
  local filename="$1"
  local dest="$2"
  local src="$BACKUP_DIR/$filename"

  # Skip if backup doesn't contain this file
  [[ -e "$src" ]] || return 0

  # Remove symlink if it exists
  if [[ -L "$dest" ]]; then
    rm -f "$dest"
    warn "Removed symlink: $dest"
  fi

  # Copy file
  cp -r "$src" "$dest"
  success "Restored: $dest"
}

restore_file ".zshenv"          "$HOME/.zshenv"
mkdir -p "$HOME/.config/zsh"
restore_file ".zshrc"           "$HOME/.config/zsh/.zshrc"
restore_file ".p10k.zsh"        "$HOME/.config/zsh/.p10k.zsh"
restore_file "settings.json"    "$VSCODE_SETTINGS_PATH/settings.json"
restore_file "keybindings.json" "$VSCODE_SETTINGS_PATH/keybindings.json"

# Restore previous core.hooksPath if one was backed up
if command -v git >/dev/null 2>&1; then
  previous_hooks_path=$(git config --global dotfiles.backup.hooksPath 2>/dev/null || echo "")
  if [[ -n "$previous_hooks_path" ]]; then
    git config --global core.hooksPath "$previous_hooks_path"
    git config --global --unset dotfiles.backup.hooksPath
    success "Restored core.hooksPath to: $previous_hooks_path"
  else
    info "No backed-up core.hooksPath found; leaving existing global core.hooksPath unchanged"
  fi
else
  warn "Git not found in PATH; skipping core.hooksPath restore"
fi

echo ""
success "Restore complete. Open a new terminal for changes to take effect."
echo ""
