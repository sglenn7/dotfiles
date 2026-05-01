#!/usr/bin/env bash
set -euo pipefail

# ==============================================================
# install.sh — Dev Environment Setup (macOS / WSL)
# ==============================================================
# Main installer for dotfiles, shell config, Python, and VS Code.
# Safe to re-run; checks for existing installs and skips as needed.
#
# Usage:
#   bash install.sh
#
# Supports: macOS, WSL (Ubuntu)
# ==============================================================

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$REPO_DIR/dotfiles"
VSCODE_DIR="$REPO_DIR/vscode"
BACKUP_TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_BASE="$HOME/.dotfiles_backup_${BACKUP_TIMESTAMP}"

# Python version to install via mise
PYTHON_VERSION="3.14"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging functions
info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
has()     { command -v "$1" &>/dev/null; }

# Don't run as root; Homebrew and git config should be set for the user account.
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  error "Do not run install.sh with sudo/root. Run it as your normal user: bash install.sh"
  exit 1
fi

# ==============================================================
# OS DETECTION
# ==============================================================

detect_os() {
  if [[ "$(uname)" == "Darwin" ]]; then
    OS="mac"
  elif grep -qi microsoft /proc/version 2>/dev/null; then
    OS="wsl"
  else
    OS="linux"
  fi
  info "Detected OS: $OS"
}

# Set VS Code settings path based on OS
set_vscode_path() {
  if [[ "$OS" == "mac" ]]; then
    VSCODE_SETTINGS_PATH="$HOME/Library/Application Support/Code/User"
  else
    VSCODE_SETTINGS_PATH="$HOME/.config/Code/User"
  fi
}

# ==============================================================
# INTERACTIVE PROMPTS
# ==============================================================

prompt_user() {
  echo ""
  echo "=============================================="
  echo "  Dev Environment Setup — Configuration"
  echo "=============================================="
  echo ""

  local default_name default_email
  default_name=$(git config --global user.name 2>/dev/null || echo "")
  default_email=$(git config --global user.email 2>/dev/null || echo "")

  if [[ -n "$default_name" ]]; then
    GIT_NAME="$default_name"
    info "Using existing git user.name: $GIT_NAME"
  else
    read -rp "Git username [enter name]: " GIT_NAME
  fi

  if [[ -n "$default_email" ]]; then
    GIT_EMAIL="$default_email"
    info "Using existing git user.email: $GIT_EMAIL"
  else
    read -rp "Git email [enter email]: " GIT_EMAIL
  fi

  read -rp "Set up VS Code settings and extensions? [Y/n]: " SETUP_VSCODE
  SETUP_VSCODE="${SETUP_VSCODE:-Y}"

  echo ""
}

# ==============================================================
# BACKUP & RESTORE UTILITIES
# ==============================================================

backup_existing() {
  local files_to_backup=(
    "$HOME/.zshenv"
    "$HOME/.config/zsh/.zshrc"
    "$HOME/.config/zsh/.p10k.zsh"
    "$HOME/.config/zsh/zsh-plugins"
    "$VSCODE_SETTINGS_PATH/settings.json"
    "$VSCODE_SETTINGS_PATH/keybindings.json"
  )

  info "Checking for existing configs to back up..."
  echo ""

  local backed_up=false
  local backup_list=()

  for f in "${files_to_backup[@]}"; do
    # If it's a symlink, check if it points to this repo
    if [[ -L "$f" ]]; then
      local target
      target="$(readlink "$f")"
      # Only skip backup if target is within this repo
      if [[ "$target" == "$REPO_DIR"* ]]; then
        info "Symlink found (from previous install): $f — skipping"
        continue
      else
        if [[ "$backed_up" == false ]]; then
          mkdir -p "$BACKUP_BASE"
          success "Created backup directory: $BACKUP_BASE"
          backed_up=true
        fi

        if [[ -e "$f" ]]; then
          # Symlink points elsewhere and target exists; back up the target
          info "Symlink found (external): $f — backing up target"
          cp -r "$f" "$BACKUP_BASE/"
        else
          # Broken symlink; preserve the link itself so install does not abort
          info "Broken symlink found (external): $f — backing up symlink"
          cp -P "$f" "$BACKUP_BASE/"
        fi
        backup_list+=("$f")
        continue
      fi
    fi

    # Back up if real file exists
    if [[ -e "$f" ]]; then
      if [[ "$backed_up" == false ]]; then
        mkdir -p "$BACKUP_BASE"
        success "Created backup directory: $BACKUP_BASE"
        backed_up=true
      fi
      cp -r "$f" "$BACKUP_BASE/"
      backup_list+=("$f")
    fi
  done

  if [[ "$backed_up" == true ]]; then
    echo ""
    echo "Backed up files:"
    for f in "${backup_list[@]}"; do
      echo "  - $f"
    done
    echo ""
    warn "Backups saved to: $BACKUP_BASE"
    warn "Run './backup.sh' anytime to restore a previous backup."
    echo ""
  else
    info "No existing configs found to back up."
    echo ""
  fi
}

symlink() {
  local src="$1"
  local dest="$2"

  # Already correct — skip
  if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
    info "Symlink already correct: $dest"
    return
  fi

  # Remove stale symlink or file
  [[ -e "$dest" || -L "$dest" ]] && rm -f "$dest"

  ln -s "$src" "$dest"
  success "Symlinked: $dest → $src"
}

# ==============================================================
# DEPENDENCY INSTALLATION
# ==============================================================

install_dependencies() {
  echo ""
  echo "=============================================="
  echo "  Installing System Dependencies"
  echo "=============================================="
  echo ""

  # Load Homebrew into PATH for this session if already installed but not yet on PATH.
  # This prevents re-running the installer (and its "add to PATH" warnings) on every run.
  if ! has brew; then
    for _brew_path in "/opt/homebrew/bin/brew" "/usr/local/bin/brew" "/home/linuxbrew/.linuxbrew/bin/brew" "$HOME/.linuxbrew/bin/brew"; do
      if [[ -x "$_brew_path" ]]; then
        eval "$("$_brew_path" shellenv)" 2>/dev/null || true
        break
      fi
    done
  fi

  # Install Homebrew (works on macOS and Linux via Linuxbrew)
  if ! has brew; then
    info "Installing Homebrew..."

    if [[ "$OS" == "mac" ]]; then
      # macOS: non-interactive is safe, no directory pre-creation needed
      NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
      # Linux/WSL: Homebrew installs to /home/linuxbrew/.linuxbrew by default.
      # Pre-create the directory owned by the current user so the installer
      # never needs sudo for it (avoids NONINTERACTIVE permission failures).
      if [[ ! -d "/home/linuxbrew" ]]; then
        sudo mkdir -p /home/linuxbrew
        sudo chown "$USER": /home/linuxbrew
      fi
      # Run interactively (not NONINTERACTIVE) so it can prompt for sudo if needed
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    # Add Homebrew to PATH for this session (handle both macOS and Linux paths)
    if [[ "$OS" == "mac" ]]; then
      # Try Apple Silicon path first, then Intel path
      if [[ -x "/opt/homebrew/bin/brew" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true
      elif [[ -x "/usr/local/bin/brew" ]]; then
        eval "$(/usr/local/bin/brew shellenv)" 2>/dev/null || true
      fi
    else
      # Linux (Linuxbrew) — installs to /home/linuxbrew/.linuxbrew
      if [[ -x "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" 2>/dev/null || true
      elif [[ -x "$HOME/.linuxbrew/bin/brew" ]]; then
        eval "$("$HOME/.linuxbrew/bin/brew" shellenv)" 2>/dev/null || true
      fi
    fi
    success "Homebrew installed."
  else
    info "Homebrew already installed."
  fi

  # Install packages from Brewfile (same on all systems)
  if [[ -f "$REPO_DIR/Brewfile" ]]; then
    info "Installing packages from Brewfile..."
    brew bundle install --file="$REPO_DIR/Brewfile"
    success "Brewfile packages installed."
  else
    warn "Brewfile not found at $REPO_DIR/Brewfile"
  fi

  echo ""
}

# ==============================================================
# SHELL SETUP (oh-my-zsh + plugins)
# ==============================================================

install_shell() {
  echo ""
  echo "=============================================="
  echo "  Setting Up Zsh & Plugins"
  echo "=============================================="
  echo ""

  # oh-my-zsh
  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    info "oh-my-zsh already installed."
  else
    info "Installing oh-my-zsh..."
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    success "oh-my-zsh installed."
  fi

  local ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

  # Powerlevel10k theme
  if [[ -d "$ZSH_CUSTOM/themes/powerlevel10k" ]]; then
    info "Powerlevel10k already installed."
  else
    info "Installing Powerlevel10k..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
    success "Powerlevel10k installed."
  fi

  # Install custom plugins from the shared zsh-plugins file
  local plugins_file="$DOTFILES_DIR/zsh-plugins"
  if [[ ! -f "$plugins_file" ]]; then
    warn "zsh-plugins file not found at $plugins_file — skipping plugin install."
    echo ""
    return
  fi

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" == \#* ]] && continue

    local name url
    read -r name url _ <<< "$line"

    [[ -z "$url" ]] && continue

    if [[ -d "$ZSH_CUSTOM/plugins/$name" ]]; then
      info "$name already installed."
    else
      info "Installing $name..."
      git clone --depth=1 "$url" "$ZSH_CUSTOM/plugins/$name"
      success "$name installed."
    fi
  done < "$plugins_file"

  echo ""
}

# ==============================================================
# DOTFILES SYMLINKING
# ==============================================================

link_dotfiles() {
  echo ""
  echo "=============================================="
  echo "  Linking Dotfiles"
  echo "=============================================="
  echo ""

  # .zshenv stays in home dir — it bootstraps ZDOTDIR for zsh
  symlink "$DOTFILES_DIR/.zshenv" "$HOME/.zshenv"

  # All other zsh configs go under ~/.config/zsh/ (via ZDOTDIR)
  mkdir -p "$HOME/.config/zsh"
  symlink "$DOTFILES_DIR/.zshrc"      "$HOME/.config/zsh/.zshrc"
  symlink "$DOTFILES_DIR/.p10k.zsh"   "$HOME/.config/zsh/.p10k.zsh"
  symlink "$DOTFILES_DIR/zsh-plugins" "$HOME/.config/zsh/zsh-plugins"

  echo ""
}

# ==============================================================
# MISE (Runtime Manager) & PYTHON
# ==============================================================

install_mise() {
  echo ""
  echo "=============================================="
  echo "  Installing Mise & Python"
  echo "=============================================="
  echo ""

  if ! has mise; then
    error "mise not found. Ensure it is listed in the Brewfile and Homebrew packages are installed."
    echo ""
    return
  fi

  # Use the globally configured Python version
  local current_python
  current_python=$(mise current python 2>/dev/null || echo "")

  if [[ "$current_python" == "$PYTHON_VERSION"* ]]; then
    info "Python $PYTHON_VERSION already active."
  else
    info "Installing Python $PYTHON_VERSION (latest stable)..."
    mise install "python@$PYTHON_VERSION"
    mise use -g "python@$PYTHON_VERSION"
    success "Python $PYTHON_VERSION set as global."
  fi

  echo ""
}

# ==============================================================
# UV (Python Package Manager)
# ==============================================================
# uv is installed via Brewfile. This function verifies it's present
# and emits a clear error if it's missing (e.g., Brewfile was skipped).

verify_uv() {
  if ! has uv; then
    error "uv not found. Ensure it is listed in the Brewfile and Homebrew packages are installed."
  else
    success "uv available: $(uv --version 2>/dev/null | head -1)"
  fi
}

# ==============================================================
# GIT CONFIGURATION
# ==============================================================

configure_git() {
  echo ""
  echo "=============================================="
  echo "  Configuring Git"
  echo "=============================================="
  echo ""

  # Set git name only if unset
  if [[ -z "$(git config --global user.name 2>/dev/null)" ]]; then
    if [[ -n "$GIT_NAME" ]]; then
      git config --global user.name "$GIT_NAME"
      success "Git user.name set to: $GIT_NAME"
    fi
  else
    info "Git user.name already configured: $(git config --global user.name)"
  fi

  # Set git email only if unset
  if [[ -z "$(git config --global user.email 2>/dev/null)" ]]; then
    if [[ -n "$GIT_EMAIL" ]]; then
      git config --global user.email "$GIT_EMAIL"
      success "Git user.email set to: $GIT_EMAIL"
    fi
  else
    info "Git user.email already configured: $(git config --global user.email)"
  fi

  echo ""
}

# ==============================================================
# VS CODE SETUP
# ==============================================================

setup_vscode() {
  case "$SETUP_VSCODE" in
    [Yy])
      ;;
    *)
      info "Skipping VS Code setup (optional)."
      return
      ;;
  esac

  echo ""
  echo "=============================================="
  echo "  Setting Up VS Code"
  echo "=============================================="
  echo ""

  mkdir -p "$VSCODE_SETTINGS_PATH"

  # Symlink settings and keybindings
  symlink "$VSCODE_DIR/settings.json"    "$VSCODE_SETTINGS_PATH/settings.json"
  symlink "$VSCODE_DIR/keybindings.json" "$VSCODE_SETTINGS_PATH/keybindings.json"
  
  # Make extension export script executable
  chmod +x "$VSCODE_DIR/export-extensions.sh" 2>/dev/null || true

  # Install extensions
  if has code && [[ -f "$VSCODE_DIR/extensions.txt" ]]; then
    info "Installing VS Code extensions..."
    local installed_extensions
    # Use 'tr' with POSIX character class for bash 3.2 compat
    installed_extensions=$(code --list-extensions 2>/dev/null | tr '[A-Z]' '[a-z]' || echo "")
    
    declare -a failed_extensions
    local fail_index=0
    
    while IFS= read -r ext || [[ -n "$ext" ]]; do
      [[ -z "$ext" || "$ext" == \#* ]] && continue
      
      # Use grep -F for fixed-string matching (safe for IDs with special chars)
      if echo "$installed_extensions" | grep -Fqix "$ext"; then
        info "Extension already installed: $ext"
      else
        info "Installing extension: $ext"
        # Try once, retry once on failure
        if ! code --install-extension "$ext" 2>/dev/null; then
          if ! code --install-extension "$ext" 2>/dev/null; then
            warn "Failed to install extension: $ext"
            failed_extensions[$fail_index]="$ext"
            (( ++fail_index ))
          else
            success "Installed (on retry): $ext"
          fi
        else
          success "Installed: $ext"
        fi
      fi
    done < "$VSCODE_DIR/extensions.txt"

    # Summary of failed extensions
    if [[ $fail_index -gt 0 ]]; then
      echo ""
      warn "Some extensions failed to install:"
      for ((i = 0; i < fail_index; i++)); do
        echo "  - ${failed_extensions[$i]}"
      done
      warn "You can manually install these later with: code --install-extension <extension>"
    fi
  else
    warn "VS Code not found or extensions.txt missing. Skipping extension install."
  fi

  echo ""
}

# ==============================================================
# GLOBAL GIT HOOKS (VS CODE EXTENSION DRIFT CHECK)
# ==============================================================

setup_git_hooks() {
  echo ""
  echo "=============================================="
  echo "  Setting Up Global Git Hooks"
  echo "=============================================="
  echo ""

  local global_hooks_dir="$REPO_DIR/git-hooks"

  # Validate that the pre-commit hook exists and is (or can be made) executable
  local hook_error=""
  if [[ ! -f "$global_hooks_dir/pre-commit" ]]; then
    hook_error="Global pre-commit hook not found at: $global_hooks_dir/pre-commit"
  elif ! chmod +x "$global_hooks_dir/pre-commit" 2>/dev/null; then
    hook_error="Could not make $global_hooks_dir/pre-commit executable."
  fi
  if [[ -n "$hook_error" ]]; then
    error "$hook_error"
    warn "Skipping global hooks setup."
    echo ""
    return
  fi

  # Make all hooks in the directory executable so pass-through wrappers work
  find "$global_hooks_dir" -maxdepth 1 -type f -exec chmod +x {} + 2>/dev/null || true

  # Point git globally to our hooks directory
  local current_hooks_path
  current_hooks_path=$(git config --global core.hooksPath 2>/dev/null || echo "")

  if [[ "$current_hooks_path" == "$global_hooks_dir" ]]; then
    info "core.hooksPath already set to: $global_hooks_dir"
  else
    if [[ -n "$current_hooks_path" ]]; then
      warn "core.hooksPath is currently set to: $current_hooks_path"
      if [[ -r /dev/tty ]]; then
        read -rp "Override with dotfiles hooks directory? [Y/n]: " OVERRIDE_HOOKS </dev/tty || OVERRIDE_HOOKS="N"
      else
        OVERRIDE_HOOKS="N"
        warn "Non-interactive environment detected; skipping global hooks setup."
      fi
      if [[ ! "${OVERRIDE_HOOKS:-Y}" =~ ^[Yy]$ ]]; then
        warn "Skipping global hooks setup."
        echo ""
        return
      fi
      git config --global dotfiles.backup.hooksPath "$current_hooks_path"
      info "Backed up previous core.hooksPath to dotfiles.backup.hooksPath"
    fi
    git config --global core.hooksPath "$global_hooks_dir"
    success "Set core.hooksPath to: $global_hooks_dir"
  fi

  # Clean up old managed hook from .git/hooks/ if it exists
  local old_hook="$REPO_DIR/.git/hooks/pre-commit"
  local managed_marker="# Managed by install.sh"
  if [[ -f "$old_hook" ]] && grep -Fq "$managed_marker" "$old_hook"; then
    rm "$old_hook"
    info "Removed old managed pre-commit hook from .git/hooks/"
    # Restore user's original hook if we backed it up
    local old_backup="$REPO_DIR/.git/hooks/pre-commit.user-backup"
    if [[ -f "$old_backup" ]]; then
      mv "$old_backup" "$old_hook"
      success "Restored original pre-commit hook from backup."
    fi
  fi

  echo ""
}

# ==============================================================
# ZSHELL AS DEFAULT SHELL
# ==============================================================

set_default_shell() {
  echo ""
  echo "=============================================="
  echo "  Setting Zsh as Default Shell"
  echo "=============================================="
  echo ""

  local brew_zsh
  brew_zsh="$(which zsh)"  # zsh path is consistent across Homebrew installs

  if [[ "$SHELL" != "$brew_zsh" ]]; then
    # Ensure zsh is in allowed shells
    if ! grep -Fxq "$brew_zsh" /etc/shells 2>/dev/null; then
      echo "$brew_zsh" | sudo tee -a /etc/shells >/dev/null
    fi
    chsh -s "$brew_zsh"
    success "Default shell set to Zsh: $brew_zsh"
  else
    info "Zsh is already the default shell."
  fi

  echo ""
}

# ==============================================================
# PROMPT SETUP (p10k)
# ==============================================================

prompt_p10k() {
  echo ""
  echo "=============================================="
  echo "  Powerlevel10k Configuration (Optional)"
  echo "=============================================="
  echo ""

  if [[ -f "$HOME/.config/zsh/.p10k.zsh" ]]; then
    info "Existing p10k config found at ~/.config/zsh/.p10k.zsh — skipping reconfiguration will keep it."
    read -rp "Re-run 'p10k configure' to overwrite your existing config? [y/N]: " RUN_P10K
    RUN_P10K="${RUN_P10K:-N}"
  else
    read -rp "Run 'p10k configure' now to customize your prompt? [Y/n]: " RUN_P10K
    RUN_P10K="${RUN_P10K:-Y}"
  fi

  case "$RUN_P10K" in
    [Yy])
      # p10k is a zsh function — unavailable in bash. We can only run it in an interactive zsh session.
      local p10k_script="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k/powerlevel10k.zsh-theme"
      if [[ -f "$p10k_script" ]]; then
        info "Launching p10k configure in an interactive zsh subshell..."
        if zsh -ic "source '$p10k_script' && p10k configure"; then
          success "p10k configured. Your config is at ~/.config/zsh/.p10k.zsh"
          echo ""
          echo "To version-control this config, run:"
          echo "  cp ~/.config/zsh/.p10k.zsh dotfiles/.p10k.zsh"
          echo "  git add dotfiles/.p10k.zsh && git commit -m 'Update p10k config'"
        else
          warn "p10k configure failed. Open a new zsh terminal and run: p10k configure"
        fi
      else
        warn "Powerlevel10k theme not found. Open a new zsh shell first, then run: p10k configure"
      fi
      ;;
    *)
      info "Skipped. Open a new zsh terminal and run 'p10k configure' anytime."
      ;;
  esac

  echo ""
}

# ==============================================================
# POST-INSTALL VERIFICATION
# ==============================================================

verify_install() {
  echo ""
  echo "=============================================="
  echo "  Verifying Installation"
  echo "=============================================="
  echo ""

  declare -a check_keys
  declare -a check_vals
  local checks_index=0
  
  for check_spec in "zsh" "git" "mise" "python" "uv" "code"; do
    check_keys[$checks_index]="$check_spec"
    check_vals[$checks_index]="$(which $check_spec 2>/dev/null || echo 'NOT FOUND')"
    (( ++checks_index ))
  done

  local max_len=0
  for ((i = 0; i < checks_index; i++)); do
    ((${#check_keys[$i]} > max_len)) && max_len=${#check_keys[$i]}
  done

  echo "Command Availability:"
  for ((i = 0; i < checks_index; i++)); do
    printf "  %-$(($max_len + 2))s %s\n" "${check_keys[$i]}" "${check_vals[$i]}"
  done

  echo ""
  echo "Symlinks:"
  [[ -L "$HOME/.zshenv" ]] && echo "  ✓ ~/.zshenv is symlinked" || echo "  ✗ ~/.zshenv is NOT symlinked"
  [[ -L "$HOME/.config/zsh/.zshrc" ]] && echo "  ✓ ~/.config/zsh/.zshrc is symlinked" || echo "  ✗ ~/.config/zsh/.zshrc is NOT symlinked"
  [[ -L "$HOME/.config/zsh/.p10k.zsh" ]] && echo "  ✓ ~/.config/zsh/.p10k.zsh is symlinked" || echo "  ✗ ~/.config/zsh/.p10k.zsh is NOT symlinked"
  [[ -L "$HOME/.config/zsh/zsh-plugins" ]] && echo "  ✓ ~/.config/zsh/zsh-plugins is symlinked" || echo "  ✗ ~/.config/zsh/zsh-plugins is NOT symlinked"

  echo ""
  echo "Git Config:"
  echo "  user.name: $(git config --global user.name 2>/dev/null || echo 'NOT SET')"
  echo "  user.email: $(git config --global user.email 2>/dev/null || echo 'NOT SET')"

  if has code; then
    echo ""
    local ext_count
    ext_count=$(code --list-extensions 2>/dev/null | wc -l)
    echo "VS Code Extensions: $ext_count installed"
  fi

  echo ""
}

# ==============================================================
# MAIN FLOW
# ==============================================================

main() {
  echo ""
  echo "=============================================="
  echo "  Dev Environment Setup"
  echo "=============================================="

  detect_os
  set_vscode_path
  prompt_user

  read -rp "Ready to proceed? [Y/n]: " CONFIRM
  if [[ ! "${CONFIRM:-Y}" =~ ^[Yy]$ ]]; then
    info "Setup cancelled."
    exit 0
  fi

  echo ""
  backup_existing
  install_dependencies
  install_shell
  link_dotfiles
  install_mise
  verify_uv
  configure_git
  setup_vscode
  setup_git_hooks
  set_default_shell
  prompt_p10k
  verify_install

  echo ""
  echo "=============================================="
  success "Setup complete! Open a new terminal to apply all changes."
  echo "=============================================="
  echo ""
  echo "Next steps:"
  echo "  1. Close and reopen your terminal"
  echo "  2. Customize VS Code settings: edit $VSCODE_SETTINGS_PATH/settings.json"
  echo "  3. Add your VS Code extensions: run 'code --list-extensions' and update $VSCODE_DIR/extensions.txt"
  echo ""
}

main "$@"
