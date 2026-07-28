<#
.SYNOPSIS
    Install Exoskeleton assets into a Claude Code project.

.DESCRIPTION
    Generates project-level Claude Code files from V2 assets:
      - platforms/claude/commands -> .claude/commands
      - platforms/claude/agents   -> .claude/agents
      - src/skills                 -> .claude/skills
      - templates                  -> .claude/settings.json, CLAUDE.md, .claude/exoskeleton-skill-index.md

    Claude Code hooks are enabled through project-level .claude/settings.json.
    Hook adapters are installed into .claude/hooks alongside the shared common.ps1.

.PARAMETER ProjectRoot
    Target business project root. Defaults to current directory.

.PARAMETER SourceRoot
    Exoskeleton repository root. Defaults to two levels above this script.

.PARAMETER Force
    Overwrite existing generated files and asset directories.
#>
[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [string]$SourceRoot,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$InstallerName = "exoskeleton-claude"

function Write-Step([string]$msg) { Write-Host "[$InstallerName] $msg" -ForegroundColor Cyan }
function Write-Warn([string]$msg) { Write-Host "[$InstallerName] WARN: $msg" -ForegroundColor Yellow }
function Write-Err ([string]$msg) { Write-Host "[$InstallerName] ERROR: $msg" -ForegroundColor Red }

function Resolve-FullPath([string]$Path) {
    $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    return $resolved
}

function Assert-Directory([string]$Path, [string]$Label) {
    if (-not (Test-Path $Path -PathType Container)) {
        Write-Err "$Label missing: $Path"
        exit 1
    }
}

function Assert-File([string]$Path, [string]$Label) {
    if (-not (Test-Path $Path -PathType Leaf)) {
        Write-Err "$Label missing: $Path"
        exit 1
    }
}

function Copy-AssetDirectory([string]$SourceDir, [string]$TargetDir, [string]$Label) {
    Assert-Directory -Path $SourceDir -Label $Label

    if (Test-Path $TargetDir) {
        $existing = Get-ChildItem -Path $TargetDir -Force -ErrorAction SilentlyContinue
        if ($existing.Count -gt 0 -and -not $Force) {
            Write-Err "$Label target already contains files: $TargetDir. Re-run with -Force to overwrite generated assets."
            exit 1
        }
        if ($Force) {
            Remove-Item -Path $TargetDir -Recurse -Force
        }
    }

    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    Copy-Item -Path (Join-Path $SourceDir "*") -Destination $TargetDir -Recurse -Force
    Write-Step ("Installed {0}: {1}" -f $Label, $TargetDir)
}

function Copy-TemplateFile([string]$SourceFile, [string]$TargetFile, [string]$Label) {
    Assert-File -Path $SourceFile -Label $Label

    $targetParent = Split-Path $TargetFile -Parent
    if (-not (Test-Path $targetParent)) {
        New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
    }

    if ((Test-Path $TargetFile) -and -not $Force) {
        Write-Warn "$Label already exists, keeping existing file: $TargetFile"
        return
    }

    Copy-Item -Path $SourceFile -Destination $TargetFile -Force
    Write-Step ("Installed {0}: {1}" -f $Label, $TargetFile)
}

if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
    $SourceRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}

$ProjectRoot = Resolve-FullPath -Path $ProjectRoot
$SourceRoot = Resolve-FullPath -Path $SourceRoot

Assert-Directory -Path $ProjectRoot -Label "ProjectRoot"
Assert-Directory -Path (Join-Path $SourceRoot "src") -Label "SourceRoot src"
Assert-Directory -Path (Join-Path $SourceRoot "platforms\claude\commands") -Label "Claude commands"
Assert-Directory -Path (Join-Path $SourceRoot "platforms\claude\agents") -Label "Claude agents"
Assert-Directory -Path (Join-Path $SourceRoot "platforms\claude\hooks") -Label "Claude hooks"
Assert-Directory -Path (Join-Path $SourceRoot "platforms\claude\templates") -Label "Claude templates"

$claudeDir = Join-Path $ProjectRoot ".claude"
New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null

Write-Step "Project root: $ProjectRoot"
Write-Step "Source root : $SourceRoot"

Copy-AssetDirectory -SourceDir (Join-Path $SourceRoot "platforms\claude\commands") -TargetDir (Join-Path $claudeDir "commands") -Label "commands"
Copy-AssetDirectory -SourceDir (Join-Path $SourceRoot "platforms\claude\agents") -TargetDir (Join-Path $claudeDir "agents") -Label "agents"
$hooksTargetDir = Join-Path $claudeDir "hooks"
Copy-AssetDirectory -SourceDir (Join-Path $SourceRoot "platforms\claude\hooks") -TargetDir $hooksTargetDir -Label "hooks"
Copy-Item -Path (Join-Path $SourceRoot "src\hooks\common.ps1") -Destination (Join-Path $hooksTargetDir "common.ps1") -Force
Write-Step ("Installed hook common: {0}" -f (Join-Path $hooksTargetDir "common.ps1"))
Copy-Item -Path (Join-Path $SourceRoot "src\hooks\harness-report.ps1") -Destination (Join-Path $hooksTargetDir "harness-report.ps1") -Force
Write-Step ("Installed harness report: {0}" -f (Join-Path $hooksTargetDir "harness-report.ps1"))
Copy-AssetDirectory -SourceDir (Join-Path $SourceRoot "src\skills") -TargetDir (Join-Path $claudeDir "skills") -Label "skills"

$templateDir = Join-Path $SourceRoot "platforms\claude\templates"
Copy-TemplateFile -SourceFile (Join-Path $templateDir "settings.project.json") -TargetFile (Join-Path $claudeDir "settings.json") -Label "settings.json"
Copy-TemplateFile -SourceFile (Join-Path $templateDir "CLAUDE.md") -TargetFile (Join-Path $ProjectRoot "CLAUDE.md") -Label "CLAUDE.md"
Copy-TemplateFile -SourceFile (Join-Path $templateDir "exoskeleton-skill-index.md") -TargetFile (Join-Path $claudeDir "exoskeleton-skill-index.md") -Label "skill index"
Copy-TemplateFile -SourceFile (Join-Path $templateDir "tool-call-budget.md") -TargetFile (Join-Path $claudeDir "tool-call-budget.md") -Label "Claude tool budget guide"

Write-Host ""
Write-Step "Claude Code installation completed"
Write-Host "  Claude dir : $claudeDir" -ForegroundColor Green
Write-Host "  Hooks      : enabled via .claude/settings.json" -ForegroundColor Green
Write-Host ""
Write-Host "  Next: run platforms\claude\verify-claude.ps1 -ProjectRoot `"$ProjectRoot`"" -ForegroundColor Yellow
