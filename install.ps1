# install.ps1 — Windows / WSL Entry Point
#
# Run this in PowerShell as Administrator.
# It will ensure WSL is installed, then hand off to install.sh inside WSL.
#
# Usage:
#   Right-click → "Run with PowerShell" (as Administrator)
#   or: powershell -ExecutionPolicy Bypass -File install.ps1

$ErrorActionPreference = "Stop"

function Write-Info  { param($msg) Write-Host "[INFO]  $msg" -ForegroundColor Cyan }
function Write-OK    { param($msg) Write-Host "[OK]    $msg" -ForegroundColor Green }
function Write-Warn  { param($msg) Write-Host "[WARN]  $msg" -ForegroundColor Yellow }
function Write-Err   { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }

Write-Host ""
Write-Host "==============================================" -ForegroundColor White
Write-Host "  Dotfiles Setup — Windows / WSL Entry Point" -ForegroundColor White
Write-Host "==============================================" -ForegroundColor White
Write-Host ""

# Require Administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Err "Please run this script as Administrator (right-click → Run as Administrator)."
    exit 1
}

# Check if WSL is installed by attempting to list distros
$wslReady = $false
try {
    $null = wsl --list --quiet 2>&1
    if ($LASTEXITCODE -eq 0) { $wslReady = $true }
} catch {
    $wslReady = $false
}

if (-not $wslReady) {
    Write-Warn "WSL does not appear to be installed or configured."
    $confirm = Read-Host "Install WSL now? A reboot will be required afterward. [Y/n]"
    if ($confirm -eq '' -or $confirm -match '^[Yy]') {
        Write-Info "Running: wsl --install"
        wsl --install
        Write-Host ""
        Write-Warn "WSL installation started. Please reboot, then re-run this script."
        Read-Host "Press Enter to exit"
        exit 0
    } else {
        Write-Err "WSL is required. Exiting."
        exit 1
    }
} else {
    Write-OK "WSL is installed."
}

# Convert the Windows path of this script's directory to a WSL path
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$wslScriptDir = (wsl wslpath -u "$($scriptDir -replace '\\', '/')") 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Err "Could not convert script path to WSL path: $scriptDir"
    exit 1
}
$wslScriptDir = $wslScriptDir.Trim()
$wslInstallScript = "$wslScriptDir/install.sh"

Write-Info "Handing off to install.sh in WSL..."
Write-Info "Script path: $wslInstallScript"
Write-Host ""

# Make executable and run
wsl bash -c "chmod +x '$wslInstallScript' && bash '$wslInstallScript'"

if ($LASTEXITCODE -ne 0) {
    Write-Err "install.sh exited with errors (exit code $LASTEXITCODE). See output above."
    exit $LASTEXITCODE
}

Write-OK "Setup complete."
Write-Host ""
Write-Host "VS Code settings are symlinked inside WSL (done by install.sh)." -ForegroundColor Cyan
Write-Host "Open VS Code from your WSL terminal with: code ." -ForegroundColor Cyan
Write-Host "The Remote WSL extension will use your symlinked settings automatically." -ForegroundColor Cyan
Write-Host ""
