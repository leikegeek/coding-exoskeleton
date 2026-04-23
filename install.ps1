<#
.SYNOPSIS
    Install or upgrade coding-exoskeleton plugin.

.DESCRIPTION
    Install location: ~/.cursor/plugins/local/coding-exoskeleton
    Idempotent behavior:
      - If already installed as a git repo, pull latest from remote branch.
      - If not installed, clone repository.
    Restart Cursor after installation.

.PARAMETER RepoUrl
    Git repository URL (HTTP/HTTPS/SSH).

.PARAMETER Branch
    Branch to install from. Default: master.

.EXAMPLE
    .\install.ps1

.EXAMPLE
    .\install.ps1 -RepoUrl "https://github.com/leikegeek/coding-exoskeleton.git" -Branch "master"
#>
[CmdletBinding()]
param(
    [string]$RepoUrl = "https://github.com/leikegeek/coding-exoskeleton.git",
    [string]$Branch  = "master"
)

$ErrorActionPreference = "Stop"
$PluginName = "coding-exoskeleton"

function Write-Step($msg) { Write-Host "[$PluginName] $msg" -ForegroundColor Cyan }
function Write-Err ($msg) { Write-Host "[$PluginName] ERROR: $msg" -ForegroundColor Red }

# ---------- Preconditions ----------

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Err "git is not installed. Please install it first: https://git-scm.com/download/win"
    exit 1
}

if ([string]::IsNullOrWhiteSpace($RepoUrl)) {
    Write-Err "RepoUrl is empty. Please pass -RepoUrl."
    exit 1
}

# ---------- Target path ----------

$PluginRoot   = Join-Path $HOME ".cursor\plugins\local\$PluginName"
$PluginParent = Split-Path $PluginRoot -Parent

if (-not (Test-Path $PluginParent)) {
    Write-Step "Creating directory: $PluginParent"
    New-Item -ItemType Directory -Path $PluginParent -Force | Out-Null
}

# ---------- Clone or update ----------

if (Test-Path (Join-Path $PluginRoot ".git")) {
    Write-Step "Detected existing install, upgrading..."
    Push-Location $PluginRoot
    try {
        $localChanges = git status --porcelain 2>$null
        if ($localChanges) {
            Write-Host ""
            Write-Host "[$PluginName] WARNING: Local modifications detected in plugin directory:" -ForegroundColor Yellow
            Write-Host $localChanges -ForegroundColor Yellow
            Write-Host ""
            $answer = Read-Host "[$PluginName] Upgrade will OVERWRITE these changes. Continue? (y/N)"
            if ($answer -ne "y" -and $answer -ne "Y") {
                Write-Step "Upgrade cancelled by user."
                exit 0
            }
        }
        git fetch --quiet origin $Branch
        if ($LASTEXITCODE -ne 0) {
            Write-Err "git fetch failed. Please check repository access."
            exit 1
        }
        git reset --hard --quiet "origin/$Branch"
        if ($LASTEXITCODE -ne 0) {
            Write-Err "git reset failed. Please check repository state."
            exit 1
        }
        Write-Step "Upgrade completed"
    } finally {
        Pop-Location
    }
} elseif (Test-Path $PluginRoot) {
    Write-Err "$PluginRoot exists but is not a git repository. Please clean it manually and retry."
    exit 1
} else {
    Write-Step "Cloning repository..."
    git clone --branch $Branch $RepoUrl $PluginRoot
    if ($LASTEXITCODE -ne 0) {
        Write-Err "git clone failed. Please check repository URL and network."
        exit 1
    }
}

# ---------- Verification ----------

# Always use the verify script that ships with the current installer.
# This avoids parse/encoding issues from stale verify.ps1 inside plugin path.
$verifyScript = Join-Path $PSScriptRoot "verify.ps1"
if (Test-Path $verifyScript) {
    Write-Step "Running verification..."
    & $verifyScript -PluginRoot $PluginRoot
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Verification failed. Please check output above."
        exit 1
    }
} else {
    Write-Err "Missing verify script near installer: $verifyScript"
}

# ---------- Write global user-level hooks ----------
#
# Hooks are managed globally via ~/.cursor/hooks.json so they apply to all
# projects without any per-project setup step. Scripts are referenced by
# paths relative to ~/.cursor/ (the CWD for user-level hooks).
# hook scripts use $env:CURSOR_PROJECT_DIR to locate the project root.

Write-Host ""
Write-Step "Writing global hooks config..."

$UserCursorDir  = Join-Path $HOME ".cursor"
$GlobalHooksPath = Join-Path $UserCursorDir "hooks.json"

# Relative to ~/.cursor/ — this is where user-level hooks execute from.
$hooksRelBase = "plugins/local/coding-exoskeleton/hooks"

$hooksObj = [ordered]@{
    version = 1
    hooks   = [ordered]@{
        afterFileEdit        = @(
            [ordered]@{ command = "powershell -ExecutionPolicy Bypass -File `"$hooksRelBase/after-file-edit.ps1`""; timeout = 10 }
        )
        beforeShellExecution = @(
            [ordered]@{ command = "powershell -ExecutionPolicy Bypass -File `"$hooksRelBase/before-shell-execution.ps1`""; timeout = 10; failClosed = $true }
        )
        beforeSubmitPrompt   = @(
            [ordered]@{ command = "powershell -ExecutionPolicy Bypass -File `"$hooksRelBase/before-submit-prompt-lite.ps1`""; timeout = 10 }
        )
    }
}

$hooksObj | ConvertTo-Json -Depth 5 | Set-Content -Path $GlobalHooksPath -Encoding UTF8
Write-Step "  Written: $GlobalHooksPath"

# ---------- Done ----------

Write-Host ""
Write-Step "Installation completed"
Write-Host "  Plugin path  : $PluginRoot" -ForegroundColor Green
Write-Host "  Global hooks : $GlobalHooksPath" -ForegroundColor Green
Write-Host ""
Write-Host "  Next: restart Cursor, then use /start or /code in any project." -ForegroundColor Yellow
Write-Host ""
