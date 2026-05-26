# Dev Environment Setup

Automated dotfiles and dev environment setup for **macOS**, **WSL**, and **Linux**.

Get a fully configured development environment—shell, Python, and VS Code with repo-managed settings—up and running in minutes.

---

## Prerequisites: Before You Clone

This repo requires git + GitHub SSH auth before you can clone it. Do these steps first on every new machine.

### Step 1: Install Git

**macOS:**
```bash
xcode-select --install   # installs git + other CLI tools
git --version            # verify
```

**WSL (Ubuntu/Debian):**
```bash
sudo apt-get update && sudo apt-get install -y git
git --version            # verify
```

**Windows (for WSL setup):** Install WSL first, then follow the WSL steps above inside your WSL terminal:
```powershell
# As Administrator in PowerShell:
wsl --install
# Reboot, then open WSL terminal and run the apt-get steps above
```

> **Note:** All further steps (SSH key, cloning, install.sh) run **inside the WSL terminal**, not in PowerShell. Open your WSL distro (e.g., Ubuntu) from the Start menu after rebooting.

---

### Step 2: Set Up SSH Key for GitHub

GitHub does not accept passwords over HTTPS. SSH keys are the clean solution — generate once, add to GitHub, never authenticate again.

**How it works:** `ssh-keygen` creates two files — a private key (stays on your machine, never shared) and a public key (given to GitHub). When you `git clone`, your machine proves its identity by signing a challenge with the private key; GitHub verifies it with the public key you registered. No password involved.

```bash
# Generate a key pair using Ed25519 (modern, fast, GitHub-recommended algorithm)
# -t ed25519   → algorithm to use
# -C           → a label embedded in the public key so you can identify it later
#                (e.g. "work-macbook" or "wsl-home") — has no effect on security
ssh-keygen -t ed25519 -C "your-email@github.com"

# Accept the default file location (~/.ssh/id_ed25519) by pressing Enter
# Passphrase is optional — skip it for convenience, set one for extra security
```

This creates:
```
~/.ssh/id_ed25519      ← private key (never share or commit this)
~/.ssh/id_ed25519.pub  ← public key (safe to share — give this to GitHub)
```

**Add the public key to GitHub:**
```bash
# Print your public key
cat ~/.ssh/id_ed25519.pub
# Copy the entire output (starts with "ssh-ed25519 ...")
```

Then in your browser:
1. Go to **github.com → Settings → SSH and GPG keys**
2. Click **New SSH key**
3. Give it a name (e.g. "WSL Home" or "MacBook")
4. Paste the public key → **Add SSH key**

**Test it:**
```bash
ssh -T git@github.com
# Expected: "Hi <username>! You've successfully authenticated..."
```

---

### Step 3: Clone the Repo

Now use the SSH URL (not HTTPS):

```bash
git clone git@github.com:HeinyJR/dotfiles.git
cd dotfiles
```

> **Already cloned via HTTPS?** Switch to SSH:
> ```bash
> git remote set-url origin git@github.com:HeinyJR/dotfiles.git
> ```

---

## Quick Start

### macOS or WSL/Linux

```bash
# After completing prerequisites above:
bash install.sh
```

### Windows (with WSL)

```powershell
# Run as Administrator:
powershell -ExecutionPolicy Bypass -File install.ps1
```

The script will:
- Check/install WSL
- Ask a few questions (Git name/email, VS Code setup)
- Detect existing configs and back them up safely
- Install system dependencies via Homebrew + Brewfile
- Set up your shell, Python environment, and VS Code
- Verify everything works

---

## What Gets Set Up

| Component | Details |
|-----------|---------|
| **Shell** | zsh + oh-my-zsh + Powerlevel10k theme |
| **Shell Plugins** | zsh-autosuggestions, zsh-syntax-highlighting, fzf-tab, zsh-fzf-history-search |
| **Package Manager** | Homebrew (unified across macOS and Linux) |
| **Runtime Manager** | mise (handles Python 3.14 by default + other tools) |
| **Python Tools** | uv (fast package manager) |
| **CLI Utilities** | fd, ripgrep, fzf, tree |
| **Shell Aliases** | Useful shortcuts like `la`, `ll`, `venv`, `activate` (in .zshrc) |
| **Git** | Global user.name/email + global pre-commit hook for VS Code extension drift |
| **VS Code** | Settings, keybindings, and auto-installed extensions (symlinked from repo) |
| **Dotfiles** | Symlinked from repo directly into `~/` |
| **SSH Agent** | Auto-started with 48h key caching (configured in .zshrc) |

The script is **safe to re-run**—it checks before installing and skips anything already in place.

---

## First Hour on a New Machine

After running the install script, you'll have a working environment. Here's what to do next:

### 1. **Open a new terminal** (critical—shell changes won't apply until then)

```bash
# Verify everything is working
bash verify.sh
```

### 2. **Customize your shell prompt** (optional but recommended)

If you didn't run `p10k configure` during install, do it now:

```bash
p10k configure
```

If `~/.p10k.zsh` is symlinked by this repo (default after install), your changes are already in `dotfiles/.p10k.zsh`:

```bash
git add dotfiles/.p10k.zsh && git commit -m "Update p10k config"
git push
```

If you customized p10k before running this installer and don't have the symlink yet, copy once:

```bash
cp ~/.p10k.zsh dotfiles/.p10k.zsh
```

### 3. **Sync your VS Code settings**

Your VS Code settings are symlinked from this repo for the environment where `install.sh` ran. This means:
- Edit settings in VS Code UI as normal
- Changes are saved to the repo automatically
- Any machine using this repo + symlinked files sees those changes after pull

> **Important WSL nuance**: the symlinked files are in WSL (`~/.config/Code/User`).
> Changes are reflected when you're editing settings in a **WSL Remote window**.
> Native Windows VS Code settings are separate and use Windows-side settings (or cloud Settings Sync).

### 4. **Export your VS Code extensions**

The first time you set up, export your extensions to version control:

```bash
# From WSL or macOS terminal:
./vscode/export-extensions.sh

# Commit the export
git add vscode/extensions.txt
git commit -m "Add VS Code extensions"
git push
```

**Going forward**, the global pre-commit hook detects extension drift on each commit and prompts you to update the file if extensions have changed.

Next time you set up on a new machine, these extensions will auto-install.

### 5. **Test on a project**

Create a quick test project:

```bash
mkdir test-project && cd test-project
python --version  # should show Python 3.14
uv init           # initialize a uv project
```

## Keeping Tools Updated

This repo now includes a unified updater script:

```bash
bash update.sh check
bash update.sh upgrade
```

What it does:
- Checks and updates Homebrew package metadata.
- Shows pending Homebrew upgrades.
- Checks mise-managed runtime updates when supported.
- Applies updates for Homebrew and mise when you run upgrade.

Startup reminder behavior:
- Your zsh startup shows a reminder when an update check is overdue.
- Default interval is every 7 days.
- The reminder itself is lightweight and does not run network checks.

Optional tuning in your local config (`~/.zshrc.local`):

```bash
# Change reminder frequency (days)
export DOTFILES_UPDATE_INTERVAL_DAYS=14

# Optional interactive startup prompt to run a check immediately
export DOTFILES_UPDATE_STARTUP_PROMPT=1
```

---

## What's in This Repo

```
install.sh              ← Main installer (run on macOS or WSL)
install.ps1             ← Windows entry point (optional, installs WSL then calls install.sh)
backup.sh               ← Restore a previous backup
verify.sh               ← Check installation status
update.sh               ← Check for and apply tool updates (Homebrew, mise, uv)

Brewfile                ← Package list for Homebrew (macOS + Linux)

dotfiles/
  .zshenv               ← Bootstrap: Homebrew PATH, mise shims (symlinked to ~/.zshenv)
  .zshrc                ← Shell configuration (symlinked to ~/.zshrc)
  .p10k.zsh             ← Prompt theme config (symlinked to ~/.p10k.zsh)
  zsh-plugins           ← Plugin list with git URLs (symlinked to ~/.zsh-plugins)

git-hooks/
  pre-commit            ← Global hook: chains local hooks, checks VS Code extension drift

vscode/
  settings.json         ← VS Code settings (symlinked, version-controlled)
  keybindings.json      ← Keybindings (symlinked, version-controlled)
  extensions.txt        ← List of extensions to auto-install
  export-extensions.sh  ← Helper script to export extensions
```

> **Config location note**: All zsh configs are symlinked directly into `~/` for simplicity and compatibility with tools that expect them there (oh-my-zsh, package installers, etc.).

---

## Customization

### Add Your Own Aliases

Edit `dotfiles/.zshrc` and add your custom aliases in the "Shell Aliases" section:

```bash
# Example: quick git commands
alias gs="git status"
alias gp="git push"
```

Reload your shell to apply:

```bash
source ~/.zshrc
```

### Private/Local-Only Settings

For machine-specific values (API keys, employer paths, etc.), create `~/.zshrc.local`:

```bash
# ~/.zshrc.local (never committed to repo)
export MY_API_KEY="secret"
export WORK_PATH="/employer/path"
```

This file is automatically sourced by `.zshrc` if it exists, and is gitignored.

### Manage Packages

All system packages are defined in `Brewfile`. To add a new package:

```bash
# Install it first
brew install <package>

# Export updated list
brew bundle dump --file=Brewfile --overwrite

# Commit
git add Brewfile && git commit -m "Add <package>"
```

On other machines, packages install automatically when you run `install.sh`.

### Update VS Code Settings

Settings are symlinked directly from this repo, so changes appear immediately:

> On WSL, this applies to settings edited in a **WSL Remote window**. Native Windows VS Code settings are separate.

```bash
# 1. Edit settings in VS Code UI (Cmd+, on macOS, Ctrl+, on others)

# 2. The change is saved to the repo automatically via symlink

# 3. Commit and push
git add vscode/settings.json
git commit -m "Update VS Code settings"
git push

# 4. On other machines — settings apply when you open VS Code:
git pull
# Restart VS Code to reload
```

### Update VS Code Keybindings

Same process as settings:

```bash
# 1. Edit keybindings in VS Code (Preferences → Keyboard Shortcuts)

# 2. Commit (changes saved automatically via symlink)
git add vscode/keybindings.json
git commit -m "Update VS Code keybindings"
git push
```

### Keep Extensions in Sync

```bash
# 1. Install or remove extensions in VS Code as normal

# 2. Export current list to repo (automatic on commit, or manual):
./vscode/export-extensions.sh

# 3. Commit and push
git add vscode/extensions.txt
git commit -m "Update VS Code extensions"
git push

# 4. On another machine:
git pull
bash install.sh   # Re-run to auto-install any new extensions
```

### Update Your Prompt Theme (p10k)

```bash
# 1. Run the interactive prompt wizard
p10k configure

# 2. If your ~/.p10k.zsh is symlinked (default after install),
#    changes already write through to dotfiles/.p10k.zsh
#    If not symlinked yet, copy once:
#    cp ~/.p10k.zsh dotfiles/.p10k.zsh

# 3. Commit and push
git add dotfiles/.p10k.zsh
git commit -m "Update p10k prompt config"
git push

# 4. On another machine — applies automatically via symlink:
git pull
# Open a new terminal to see the updated prompt
```

### Update Your Python Version

Change the global Python version managed by mise:

```bash
# Install a new version
mise install python@3.13

# Set it as global
mise use -g python@3.13

# Verify
python --version
```

Use a different version in a specific project:

```bash
cd my-project
mise use python@3.12
# Creates mise.toml automatically
```

---

## Backup & Restore

Before any changes, `install.sh` automatically backs up existing configs to:

```
~/.dotfiles_backup_YYYY-MM-DD_HH-MM-SS/
```

### Restore a Previous Backup

```bash
bash backup.sh
```

This lists all available backups and lets you pick one to restore. Your symlinks will be removed and old files copied back.

---

## Verification

Check that everything is installed and configured:

```bash
bash verify.sh
```

This prints a table of:
- All required commands (zsh, git, mise, python, uv, code)
- All symlinks (pointing to the right places)
- Git configuration (user.name, user.email)
- Python and VS Code setup

---

## Troubleshooting

### "Command not found" after install

**Cause**: Shell changes need a new terminal session.

**Fix**:
```bash
# Close and reopen your terminal
# Then verify
bash verify.sh
```

### Symlink points to the wrong place

**Fix**: Re-run the installer:

```bash
bash install.sh
```

It will detect and fix broken symlinks.

### VS Code extensions won't install

**Cause**: `code` command not in PATH, or network issue.

**Fixes**:
- On WSL: Ensure the VS Code WSL extension is installed, then run `code .` from WSL terminal
- Retry manually: `code --install-extension <extension-id>`
- Check `verify.sh` output to see what failed

### Restore failed

**Cause**: Backup directory missing or corrupted.

**Fix**:
```bash
# List available backups
ls -la ~/ | grep dotfiles_backup

# Manually copy files if needed
cp ~/.dotfiles_backup_2026-04-17/.zshrc ~/.zshrc
```

### Git config not set

**Cause**: Skipped during install, or using different machine.

**Fix**:
```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

### Python not found (but mise shows it installed)

**Cause**: mise shims aren't on PATH. This happens if `~/.zshenv` wasn't sourced (e.g. running in plain bash without opening a new terminal after install).

**Fix**:
```bash
# Open a new terminal (sources .zshenv which adds shims to PATH)
python --version

# Or manually add shims for the current session:
export PATH="${XDG_DATA_HOME:-$HOME/.local/share}/mise/shims:$PATH"
python --version
```

### Python version mismatch

**Cause**: Installed version doesn't match what's in mise config.

**Fix**:
```bash
mise install python@3.14
mise use -g python@3.14
python --version
```

### Pre-commit hook not running extension export

**Cause**: Global hooks path not configured, or hook not executable.

**Fix**:
```bash
# Re-run install.sh (it sets up global core.hooksPath)
bash install.sh

# Or verify manually:
git config --global core.hooksPath    # should show <repo>/git-hooks
chmod +x git-hooks/pre-commit
```

---

## Git Authentication

SSH key setup is covered in detail in the **Prerequisites** section at the top of this document — follow those steps before cloning.

**Quick reference if your key is already set up:**
```bash
ssh -T git@github.com                          # verify key is working
git remote set-url origin git@github.com:HeinyJR/dotfiles.git  # switch existing clone to SSH
```

**If you skipped the SSH setup and cloned via HTTPS**, you'll get this error when pushing:
```
remote: Invalid username or token. Password authentication is not supported.
```
Fix it by setting up an SSH key (see Prerequisites) and switching the remote URL above.

---

## VS Code WSL Setup (Windows Only)

If you use VS Code on Windows with WSL:

1. **Install the extension**: Install the "WSL" extension from VS Code Marketplace
2. **Clone dotfiles in WSL**: Run `install.sh` from WSL terminal
3. **Open in WSL**: From WSL terminal, run `code .` in your project directory
4. **Settings scope**: In a WSL window, VS Code uses the symlinked WSL settings from this repo

Your native Windows VS Code app settings are separate and can be managed with VS Code Settings Sync.

---

## Platform-Specific Notes

### macOS

- Homebrew is installed automatically to `/opt/homebrew` (Apple Silicon) or `/usr/local` (Intel)
- VS Code settings are symlinked from `~/Library/Application Support/Code/User/`
- Zsh is already the default shell on newer macOS versions
- Command Line Tools are required (installed on first run)

### WSL (Ubuntu/Debian)

- Linuxbrew (Homebrew on Linux) is installed automatically
- VS Code settings are symlinked from `~/.config/Code/User/`
- The `code` command requires the VS Code WSL extension
- Run commands from WSL terminal after the WSL extension is installed

### Windows

- `install.ps1` must be run as Administrator
- WSL is installed automatically if not present (reboot required)
- VS Code on Windows reads cloud Settings Sync + WSL extension communicates to WSL settings
- Git for Windows recommended: https://git-scm.com/download/win

---

## Questions or Issues?

- Check `verify.sh` output first—it often identifies the problem
- Review the troubleshooting section above
- Inspect the backup directory to recover files: `ls ~/.dotfiles_backup_*/`
- Re-run `install.sh`—it's safe to run multiple times
- Revisit this README for install, customization, and troubleshooting workflows

---

## License

MIT. Feel free to fork and customize for your own setup.
