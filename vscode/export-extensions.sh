#!/bin/bash
set -euo pipefail

# ==============================================================
# vscode/export-extensions.sh — Export VS Code Extensions
# ==============================================================
# Exports currently installed VS Code extensions to extensions.txt.
# Useful for keeping your extension list in version control.
#
# Usage:
#   ./vscode/export-extensions.sh
#
# This script is automatically run before each git commit via
# a pre-commit hook set up during install.sh.
# ==============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXTENSIONS_FILE="$SCRIPT_DIR/extensions.txt"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Check if VS Code CLI is available
if ! command -v code &>/dev/null; then
    warn "VS Code CLI not found in PATH"
    warn "Install VS Code or add it to your PATH to export extensions"
    exit 0  # Exit gracefully (don't fail the script)
fi

# Export extensions
info "Exporting VS Code extensions to: $EXTENSIONS_FILE"
code --list-extensions > "$EXTENSIONS_FILE.tmp"

if [[ -f "$EXTENSIONS_FILE.tmp" ]]; then
    mv "$EXTENSIONS_FILE.tmp" "$EXTENSIONS_FILE"
    ext_count=$(wc -l < "$EXTENSIONS_FILE")
    success "Exported $ext_count extensions"
else
    error "Failed to export extensions"
    exit 1
fi
