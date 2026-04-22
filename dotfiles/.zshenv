# ==============================================================
# .zshenv — Environment Variables
# ==============================================================
# Loaded for ALL zsh instances (login and non-login).
# Managed via dotfiles repo (symlinked from repo/dotfiles/.zshenv).
# Do NOT edit ~/.zshenv directly; edit this file in the repo instead.
# ==============================================================

# XDG: tell zsh to look for .zshrc and other configs in ~/.config/zsh/
# instead of dumping them directly in the home directory.
export ZDOTDIR="$HOME/.config/zsh"

# Homebrew: add brew to PATH for all shell types
# Handles Apple Silicon (/opt/homebrew), Intel (/usr/local), and Linux (/home/linuxbrew)
if [[ -x "/opt/homebrew/bin/brew" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x "/usr/local/bin/brew" ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
elif [[ -x "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
elif [[ -x "$HOME/.linuxbrew/bin/brew" ]]; then
  eval "$("$HOME/.linuxbrew/bin/brew" shellenv)"
fi

# Mise: runtime version manager
# Ensures mise tools are available in PATH
export MISE_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/mise"

# Ensure local bin directory is on PATH
# Useful for locally installed tools
export PATH="$HOME/.local/bin:$PATH"

# ==============================================================
# Add custom environment variables below as needed
# ==============================================================
# Examples:
#   export MY_VAR="value"
#   export CUSTOM_PATH="/path/to/tool"
