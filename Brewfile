# ==============================================================
# Brewfile — Unified Package Manager (macOS + Linux)
# ==============================================================
# Install dependencies via Homebrew for consistency across
# macOS and Linux (via Linuxbrew).
#
# Usage:
#   brew bundle install [--verbose]
#
# To update this file after installing a new package manually:
#   brew bundle dump --overwrite
#
# ==============================================================

# ==============================================================
# Core Development Tools
# ==============================================================
brew "git"
brew "zsh"
brew "curl"
brew "coreutils"  # GNU coreutils (for gdate, etc. on macOS)

# ==============================================================
# Runtime Managers & Python Tooling
# ==============================================================
brew "mise"        # Runtime version manager (Python, Node, etc.)
brew "uv"          # Fast Python package manager

# ==============================================================
# Build Tools & Dependencies
# ==============================================================
# These are needed for compiling Python, Ruby, and other tools.
brew "openssl"
brew "readline"
brew "sqlite"
brew "xz"
brew "libyaml"

# ==============================================================
# Shell & Utilities
# ==============================================================
brew "stow"        # For dotfile symlink management (optional)
brew "tree"        # Directory tree visualization
brew "fd"          # Fast alternative to find
brew "ripgrep"     # Fast alternative to grep
brew "fzf"         # Fuzzy finder (used by shell history search, fzf-tab)
brew "keychain"    # SSH agent manager (persists keys across terminal sessions)

# ==============================================================
# Cask Applications (macOS only)
# ==============================================================
# Note: Casks are ignored on Linux. On WSL, use WSL app store or apt.
cask "visual-studio-code"     # if managing VS Code via Homebrew
