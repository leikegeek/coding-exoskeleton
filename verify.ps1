<#
.SYNOPSIS
    Verify coding-exoskeleton plugin installation.

.DESCRIPTION
    Checks plugin root, plugin.json, and required folders/files.
    Exits with code 0 when all checks pass, otherwise exits with code 1.

.PARAMETER PluginRoot
    Plugin installation path. Defaults to:
    %USERPROFILE%\.cursor\plugins\local\coding-exoskeleton

.PARAMETER Quiet
    If set, prints only final status.
#>
[CmdletBinding()]
param(
    [string]$PluginRoot = (Join-Path $HOME ".cursor\plugins\local\coding-exoskeleton"),
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"
$failed = 0

function Write-Ok([string]$msg) {
    if (-not $Quiet) { Write-Host ("  [OK]   " + $msg) -ForegroundColor Green }
}

function Write-Fail([string]$msg) {
    $script:failed++
    if (-not $Quiet) { Write-Host ("  [FAIL] " + $msg) -ForegroundColor Red }
}

function Check-Path([string]$relativePath, [string]$label) {
    $fullPath = Join-Path $PluginRoot $relativePath
    if (Test-Path $fullPath) {
        Write-Ok ($label + ": " + $relativePath)
    } else {
        Write-Fail ($label + " missing: " + $relativePath)
    }
}

if (-not $Quiet) {
    Write-Host "Exoskeleton installation verification" -ForegroundColor Cyan
    Write-Host ""
}

if (-not (Test-Path $PluginRoot)) {
    Write-Fail ("Plugin root missing: " + $PluginRoot)
    Write-Host ""
    Write-Host "Verification failed: plugin root not found." -ForegroundColor Red
    exit 1
}

Write-Ok ("Plugin root: " + $PluginRoot)

$pluginJsonPath = Join-Path $PluginRoot ".cursor-plugin\plugin.json"
if (Test-Path $pluginJsonPath) {
    try {
        # Some environments may store plugin.json in UTF-16.
        # Try UTF-8 first, then fall back to UTF-16LE.
        $pluginRaw = $null
        try {
            $pluginRaw = Get-Content -Path $pluginJsonPath -Raw -Encoding UTF8
            $plugin = $pluginRaw | ConvertFrom-Json
        } catch {
            $pluginRaw = Get-Content -Path $pluginJsonPath -Raw -Encoding Unicode
            $plugin = $pluginRaw | ConvertFrom-Json
        }
        $name = [string]$plugin.name
        $ver = [string]$plugin.version
        Write-Ok ("plugin.json (" + $name + " v" + $ver + ")")
    } catch {
        Write-Fail "plugin.json exists but is not valid JSON"
    }
} else {
    Write-Fail "plugin.json missing"
}

$requiredDirs = @(
    ".cursor-plugin",
    "hooks",
    "docs"
)

# Dynamically add directories declared in plugin.json
$pluginDeclaredDirs = @("skills", "rules", "commands", "agents")
foreach ($key in $pluginDeclaredDirs) {
    if ($plugin) {
        $val = $null
        try { $val = $plugin.$key } catch {}
        if ($val) {
            $dirName = ([string]$val).TrimStart("./").TrimStart(".\").TrimEnd("/").TrimEnd("\")
            if ($dirName -and $dirName -notin $requiredDirs) {
                $requiredDirs += $dirName
            }
        }
    } else {
        if ($key -notin $requiredDirs) { $requiredDirs += $key }
    }
}

foreach ($dir in $requiredDirs) {
    Check-Path $dir "Directory"
}

# --- Static required files (infrastructure, not declared in plugin.json) ---

$requiredFiles = @(
    "README.md",
    "install.ps1",
    "verify.ps1",
    "hooks\common.ps1",
    "hooks\after-file-edit.ps1",
    "hooks\before-shell-execution.ps1",
    "hooks\before-submit-prompt-lite.ps1",
    "hooks\pre-tool-use.ps1",
    "hooks\harness-report.ps1",
    "docs\user-guide.md",
    "docs\plugin-core-workflow.md"
)

foreach ($file in $requiredFiles) {
    Check-Path $file "File"
}

# --- Dynamic cross-validation: scan plugin.json declared directories ---

function Scan-PluginDir([string]$DirKey, [string]$Pattern, [string]$Label) {
    if (-not $plugin) { return }
    $val = $null
    try { $val = $plugin.$DirKey } catch {}
    if (-not $val) { return }
    $relDir = ([string]$val).TrimStart("./").TrimStart(".\").TrimEnd("/").TrimEnd("\")
    $absDir = Join-Path $PluginRoot $relDir
    if (-not (Test-Path $absDir)) { return }
    $found = Get-ChildItem -Path $absDir -Filter $Pattern -Recurse -File -ErrorAction SilentlyContinue
    if ($found.Count -eq 0) {
        Write-Fail "$Label : no $Pattern files found under $relDir"
    } else {
        foreach ($f in $found) {
            $rel = $f.FullName.Substring($PluginRoot.Length).TrimStart("\")
            Write-Ok "$Label : $rel"
        }
    }
}

if (-not $Quiet) {
    Write-Host ""
    Write-Host "Cross-validating plugin.json declared directories..." -ForegroundColor Cyan
}

Scan-PluginDir -DirKey "commands" -Pattern "*.md"  -Label "Command"
Scan-PluginDir -DirKey "agents"   -Pattern "*.md"  -Label "Agent"
Scan-PluginDir -DirKey "skills"   -Pattern "SKILL.md" -Label "Skill"
Scan-PluginDir -DirKey "rules"    -Pattern "*.mdc" -Label "Rule"

Write-Host ""
if ($failed -eq 0) {
    if (-not $Quiet) {
        Write-Host "Verification passed: all required components are present." -ForegroundColor Green
    }
    exit 0
} else {
    Write-Host ("Verification failed: " + $failed + " check(s) failed.") -ForegroundColor Red
    exit 1
}
