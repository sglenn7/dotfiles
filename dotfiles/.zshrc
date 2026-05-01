# ==============================================================
# .zshrc — Interactive Shell Configuration
# ==============================================================
# Managed via dotfiles repo (symlinked from repo/dotfiles/.zshrc).
# Do NOT edit ~/.zshrc directly; edit this file in the repo instead.
#
# For machine-specific or private settings, use ~/.zshrc.local
# (create it locally, it will NOT be committed).
# ==============================================================

# Powerlevel10k instant prompt (keep near top of file)
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ==============================================================
# oh-my-zsh Configuration
# ==============================================================

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

# fzf: must be on PATH before oh-my-zsh plugins load
if command -v fzf &>/dev/null; then
  export FZF_BASE="${${$(command -v fzf):h}:h}"
elif command -v brew &>/dev/null; then
  _fzf_brew_prefix="$(brew --prefix fzf 2>/dev/null)"
  if [[ -n "$_fzf_brew_prefix" && -x "$_fzf_brew_prefix/bin/fzf" ]]; then
    if [[ ":$PATH:" != *":$_fzf_brew_prefix/bin:"* ]]; then
      PATH="${PATH:+${PATH}:}$_fzf_brew_prefix/bin"
    fi
    export FZF_BASE="$_fzf_brew_prefix"
  fi
  unset _fzf_brew_prefix
elif [[ -x "$HOME/.fzf/bin/fzf" ]]; then
  if [[ ":$PATH:" != *":$HOME/.fzf/bin:"* ]]; then
    PATH="${PATH:+${PATH}:}$HOME/.fzf/bin"
  fi
  export FZF_BASE="$HOME/.fzf"
fi

plugins=()
if [[ -f "${ZDOTDIR:-$HOME}/zsh-plugins" ]]; then
  while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    plugins+=("${line%% *}")
  done < "${ZDOTDIR:-$HOME}/zsh-plugins"
fi

source "$ZSH/oh-my-zsh.sh"

# ==============================================================
# Runtime Managers & Tools
# ==============================================================

# Mise: runtime/tool version manager
if command -v mise &>/dev/null; then
  eval "$(mise activate zsh)"
fi

# uv: fast Python package manager
if command -v uv &>/dev/null; then
  uv_bin="$(command -v uv)"
  uv_completion_cache="${XDG_CACHE_HOME:-$HOME/.cache}/uv/completion.zsh"

  mkdir -p "${uv_completion_cache:h}"

  if [[ ! -s "$uv_completion_cache" || "$uv_bin" -nt "$uv_completion_cache" ]]; then
    "$uv_bin" generate-shell-completion zsh >| "$uv_completion_cache"
  fi

  [[ -r "$uv_completion_cache" ]] && source "$uv_completion_cache"
fi

# Dotfiles updater reminder: lightweight startup check with no network calls
_dotfiles_update_reminder_once() {
  [[ -o interactive ]] || return
  [[ -t 1 ]] || return

  local interval_days last_check_file is_recent update_script dotfiles_repo_dir dotfiles_zshrc_path
  interval_days="${DOTFILES_UPDATE_INTERVAL_DAYS:-7}"
  last_check_file="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/last-update-check"
  dotfiles_zshrc_path="${${(%):-%x}:A}"
  dotfiles_repo_dir="${DOTFILES_REPO_DIR:-${dotfiles_zshrc_path:h}}"
  update_script="$dotfiles_repo_dir/update.sh"

  if [[ -f "$last_check_file" ]]; then
    is_recent="$(find "$last_check_file" -mtime "-$interval_days" -print -quit 2>/dev/null || true)"
  else
    is_recent=""
  fi

  if [[ -z "$is_recent" ]]; then
    echo ""
    echo "[dotfiles] Update check is due."
    if [[ -x "$update_script" ]]; then
      echo "[dotfiles] Check updates:   bash $update_script check"
      echo "[dotfiles] Apply updates:   bash $update_script upgrade"
    else
      echo "[dotfiles] Run from your dotfiles repo: bash update.sh check"
    fi

    if [[ "${DOTFILES_UPDATE_STARTUP_PROMPT:-0}" == "1" && -x "$update_script" ]]; then
      read -r "?Run update check now? [y/N]: " _dotfiles_update_answer
      if [[ "$_dotfiles_update_answer" =~ ^[Yy]$ ]]; then
        bash "$update_script" check
      fi
      unset _dotfiles_update_answer
    fi
  fi

  # Run only once per shell session.
  precmd_functions=("${precmd_functions[@]/_dotfiles_update_reminder_once}")
}

if (( ${precmd_functions[(Ie)_dotfiles_update_reminder_once]} == 0 )); then
  precmd_functions+=(_dotfiles_update_reminder_once)
fi

# ssh-agent: use keychain to persist SSH keys across terminal sessions (48 hours)
if command -v keychain &>/dev/null && [[ -f "$HOME/.ssh/id_ed25519" ]]; then
  _dotfiles_ensure_ssh_key_loaded() {
    [[ -t 0 && -t 1 ]] || return
    eval "$(keychain --eval --timeout 2880 --quiet id_ed25519)"
    precmd_functions=("${precmd_functions[@]/_dotfiles_ensure_ssh_key_loaded}")
  }

  if (( ${precmd_functions[(Ie)_dotfiles_ensure_ssh_key_loaded]} == 0 )); then
    precmd_functions+=(_dotfiles_ensure_ssh_key_loaded)
  fi
fi

# ==============================================================
# WSL-specific Configuration
# ==============================================================

if [[ -f /proc/version ]] && grep -qi microsoft /proc/version; then
  export BROWSER="/mnt/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"
fi

# ==============================================================
# Shell Aliases
# ==============================================================
# Custom shortcuts for common commands.

# Directory listing — colorized and detailed
alias la="ls -lah"
alias ll="ls -lh"
alias venv="uv venv .venv && source .venv/bin/activate"
alias activate="source .venv/bin/activate"

# ==============================================================
# Git Aliases (Optional — uncomment to use)
# ==============================================================
# Tip: Use these if you type the same git commands frequently.
# They save time but require memorization. Start with just the
# ones you use daily, add more as needed.

# alias gs="git status"                      # git status
# alias ga="git add"                         # git add
# alias gc="git commit -m"                   # git commit -m (use: gc "message")
# alias gp="git push"                        # git push
# alias gpl="git pull"                       # git pull
# alias gd="git diff"                        # git diff
# alias gco="git checkout"                   # git checkout
# alias gb="git branch"                      # git branch
# alias gl="git log --oneline -n 10"         # git log (last 10 commits)

# ==============================================================
# Dotfiles & User Configurations
# ==============================================================

# Load Powerlevel10k config (generated by `p10k configure`)
[[ -f "${ZDOTDIR:-$HOME}/.p10k.zsh" ]] && source "${ZDOTDIR:-$HOME}/.p10k.zsh"

# Load local-only config (machine-specific secrets, paths, etc.)
# This file should NEVER be committed to the repo.
# Use it for:
#   - API keys or tokens
#   - Employer-specific paths or environment variables
#   - Machine-specific settings
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
