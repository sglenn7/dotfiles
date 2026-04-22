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

plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
)

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

# ssh-agent: cache SSH key for 48 hours to avoid repeated passphrase prompts
if command -v ssh-agent &>/dev/null && command -v ssh-add &>/dev/null; then
  SSH_AGENT_ENV="$HOME/.ssh/agent.env"

  # Reuse an existing agent across new shells when possible.
  if [[ -f "$SSH_AGENT_ENV" ]]; then
    source "$SSH_AGENT_ENV" >/dev/null 2>&1 || true
  fi

  # Start a new agent if env is missing/stale.
  if [[ -z "${SSH_AUTH_SOCK:-}" ]] || ! ssh-add -l >/dev/null 2>&1; then
    eval "$(ssh-agent -s)" >/dev/null
    mkdir -p "$HOME/.ssh"
    {
      echo "export SSH_AUTH_SOCK=$SSH_AUTH_SOCK"
      echo "export SSH_AGENT_PID=$SSH_AGENT_PID"
    } > "$SSH_AGENT_ENV"
    chmod 600 "$SSH_AGENT_ENV"
  fi

  # Delay key loading until first prompt to avoid instant-prompt console I/O warnings.
  _dotfiles_ensure_ssh_key_loaded() {
    [[ -t 0 && -t 1 ]] || return
    [[ -f "$HOME/.ssh/id_ed25519.pub" ]] || return

    local ssh_pub_key
    ssh_pub_key="$(cut -d' ' -f1,2 "$HOME/.ssh/id_ed25519.pub" 2>/dev/null || true)"

    if [[ -n "$ssh_pub_key" ]] && ! ssh-add -L 2>/dev/null | cut -d' ' -f1,2 | grep -Fqx "$ssh_pub_key"; then
      SSH_ASKPASS_REQUIRE=never ssh-add -t 172800 "$HOME/.ssh/id_ed25519" </dev/tty
    fi

    # Run only once per shell session.
    precmd_functions=("${precmd_functions[@]/_dotfiles_ensure_ssh_key_loaded}")
  }

  if (( ${precmd_functions[(Ie)_dotfiles_ensure_ssh_key_loaded]} == 0 )); then
    precmd_functions+=(_dotfiles_ensure_ssh_key_loaded)
  fi
fi

# ==============================================================
# Shell Aliases
# ==============================================================
# Custom shortcuts for common commands.

# Directory listing — colorized and detailed
alias la="ls -lah"
alias ll="ls -lh"

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
