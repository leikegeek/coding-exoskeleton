<#
.SYNOPSIS
    Install Exoskeleton assets for a Codex project.

.DESCRIPTION
    Creates a Codex-native project installation:
      - .agents/skills                 repo-scoped Codex skills
      - .agents/references             platform-neutral commands/rules/agents
      - .codex/agents                  project-scoped Codex custom agents
      - .codex/rules                   project-scoped command approval rules
      - .codex/hooks.json              project-scoped lifecycle hooks
      - .codex/hooks/*.ps1             hook scripts
      - .agents/plugins/marketplace.json and plugins/coding-exoskeleton
        repo-local plugin marketplace assets for Codex plugin installation

    The installer does not modify ~/.codex/config.toml or user-level hooks.

.PARAMETER ProjectRoot
    Target business project root. Defaults to current directory.

.PARAMETER SourceRoot
    Exoskeleton repository root. Defaults to two levels above this script.

.PARAMETER Force
    Overwrite generated Codex assets.
#>
[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [string]$SourceRoot,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$InstallerName = "exoskeleton-codex"

function Write-Step([string]$msg) { Write-Host "[$InstallerName] $msg" -ForegroundColor Cyan }
function Write-Warn([string]$msg) { Write-Host "[$InstallerName] WARN: $msg" -ForegroundColor Yellow }
function Write-Err ([string]$msg) { Write-Host "[$InstallerName] ERROR: $msg" -ForegroundColor Red }

function Resolve-FullPath([string]$Path) {
    return $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
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

function Reset-Directory([string]$Path, [string]$Label) {
    if (Test-Path $Path) {
        $existing = Get-ChildItem -Path $Path -Force -ErrorAction SilentlyContinue
        if ($existing.Count -gt 0 -and -not $Force) {
            Write-Err "$Label target already contains files: $Path. Re-run with -Force to overwrite generated assets."
            exit 1
        }
        if ($Force) {
            Remove-Item -LiteralPath $Path -Recurse -Force
        }
    }
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function Copy-AssetDirectory([string]$SourceDir, [string]$TargetDir, [string]$Label) {
    Assert-Directory -Path $SourceDir -Label $Label
    Reset-Directory -Path $TargetDir -Label $Label
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

function ConvertTo-TomlBasicString([string]$Text) {
    if ($null -eq $Text) { return "" }
    return $Text.Replace("\", "\\").Replace('"', '\"')
}

function Get-FrontMatterField([string]$Text, [string]$FieldName, [string]$Fallback) {
    $pattern = "(?m)^" + [regex]::Escape($FieldName) + ":\s*(.+?)\s*$"
    $match = [regex]::Match($Text, $pattern)
    if (-not $match.Success) { return $Fallback }
    $value = $match.Groups[1].Value.Trim()
    if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
        $value = $value.Substring(1, $value.Length - 2)
    }
    if ([string]::IsNullOrWhiteSpace($value)) { return $Fallback }
    return $value
}

function Convert-AgentDirectory([string]$SourceDir, [string]$TargetDir, [string]$Label) {
    Assert-Directory -Path $SourceDir -Label $Label
    Reset-Directory -Path $TargetDir -Label $Label

    $agentFiles = Get-ChildItem -Path $SourceDir -Filter "*.md" -File | Sort-Object Name
    foreach ($agentFile in $agentFiles) {
        $raw = Get-Content -Path $agentFile.FullName -Raw -Encoding UTF8
        $agentName = [System.IO.Path]::GetFileNameWithoutExtension($agentFile.Name)
        $description = Get-FrontMatterField -Text $raw -FieldName "description" -Fallback ("Exoskeleton specialist agent: " + $agentName)
        $safeName = ConvertTo-TomlBasicString -Text $agentName
        $safeDescription = ConvertTo-TomlBasicString -Text $description
        $safeBody = $raw.Replace("'''", "'''`n# literal quote separator`n'''")

        $toml = @"
name = "$safeName"
description = "$safeDescription"
developer_instructions = '''
$safeBody
'''
"@
        $targetFile = Join-Path $TargetDir ($agentName + ".toml")
        Set-Content -Path $targetFile -Value $toml -Encoding UTF8
    }

    Write-Step ("Installed {0}: {1}" -f $Label, $TargetDir)
}

if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
    $SourceRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}

$ProjectRoot = Resolve-FullPath -Path $ProjectRoot
$SourceRoot = Resolve-FullPath -Path $SourceRoot

Assert-Directory -Path $ProjectRoot -Label "ProjectRoot"
Assert-Directory -Path (Join-Path $SourceRoot "src") -Label "SourceRoot src"
Assert-Directory -Path (Join-Path $SourceRoot "src\commands") -Label "commands"
Assert-Directory -Path (Join-Path $SourceRoot "src\agents") -Label "agents"
Assert-Directory -Path (Join-Path $SourceRoot "src\rules") -Label "rules"
Assert-Directory -Path (Join-Path $SourceRoot "src\skills") -Label "skills"
Assert-Directory -Path (Join-Path $SourceRoot "platforms\codex\hooks") -Label "Codex hooks"
Assert-Directory -Path (Join-Path $SourceRoot "platforms\codex\templates") -Label "Codex templates"
Assert-Directory -Path (Join-Path $SourceRoot "platforms\codex\workflow-skills") -Label "Codex workflow skills"

Write-Step "Project root: $ProjectRoot"
Write-Step "Source root : $SourceRoot"

$agentsDir = Join-Path $ProjectRoot ".agents"
$codexDir = Join-Path $ProjectRoot ".codex"
$pluginRoot = Join-Path $ProjectRoot "plugins\coding-exoskeleton"

New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
New-Item -ItemType Directory -Path $codexDir -Force | Out-Null

# Repo-scoped immediate skills for Codex.
Copy-AssetDirectory -SourceDir (Join-Path $SourceRoot "src\skills") -TargetDir (Join-Path $agentsDir "skills") -Label "repo skills"
Copy-Item -Path (Join-Path $SourceRoot "platforms\codex\workflow-skills\*") -Destination (Join-Path $agentsDir "skills") -Recurse -Force
Write-Step ("Installed workflow skills: {0}" -f (Join-Path $agentsDir "skills"))
Copy-AssetDirectory -SourceDir (Join-Path $SourceRoot "src\commands") -TargetDir (Join-Path $agentsDir "references\commands") -Label "repo workflow references"
Copy-AssetDirectory -SourceDir (Join-Path $SourceRoot "src\rules") -TargetDir (Join-Path $agentsDir "references\rules") -Label "repo rule references"
Copy-AssetDirectory -SourceDir (Join-Path $SourceRoot "src\agents") -TargetDir (Join-Path $agentsDir "references\agents") -Label "repo agent references"

# Project-local hooks. Codex will ask the user to trust changed hooks through /hooks.
Copy-AssetDirectory -SourceDir (Join-Path $SourceRoot "platforms\codex\hooks") -TargetDir (Join-Path $codexDir "hooks") -Label "Codex hooks"
Copy-Item -Path (Join-Path $SourceRoot "src\hooks\common.ps1") -Destination (Join-Path $codexDir "hooks\common.ps1") -Force
Copy-Item -Path (Join-Path $SourceRoot "src\hooks\harness-report.ps1") -Destination (Join-Path $codexDir "hooks\harness-report.ps1") -Force
Copy-TemplateFile -SourceFile (Join-Path $SourceRoot "platforms\codex\templates\hooks.project.json") -TargetFile (Join-Path $codexDir "hooks.json") -Label ".codex hooks.json"
Copy-AssetDirectory -SourceDir (Join-Path $SourceRoot "platforms\codex\templates\rules") -TargetDir (Join-Path $codexDir "rules") -Label "Codex approval rules"
Convert-AgentDirectory -SourceDir (Join-Path $SourceRoot "src\agents") -TargetDir (Join-Path $codexDir "agents") -Label "Codex custom agents"

# Repo-local plugin bundle and marketplace for Codex plugin UX.
Reset-Directory -Path $pluginRoot -Label "Codex plugin"
New-Item -ItemType Directory -Path (Join-Path $pluginRoot ".codex-plugin") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $pluginRoot "references") -Force | Out-Null
Copy-TemplateFile -SourceFile (Join-Path $SourceRoot "platforms\codex\templates\plugin.json") -TargetFile (Join-Path $pluginRoot ".codex-plugin\plugin.json") -Label "plugin manifest"
Copy-AssetDirectory -SourceDir (Join-Path $SourceRoot "src\skills") -TargetDir (Join-Path $pluginRoot "skills") -Label "plugin skills"
Copy-Item -Path (Join-Path $SourceRoot "platforms\codex\workflow-skills\*") -Destination (Join-Path $pluginRoot "skills") -Recurse -Force
Copy-AssetDirectory -SourceDir (Join-Path $SourceRoot "src\commands") -TargetDir (Join-Path $pluginRoot "references\commands") -Label "workflow references"
Copy-AssetDirectory -SourceDir (Join-Path $SourceRoot "src\rules") -TargetDir (Join-Path $pluginRoot "references\rules") -Label "rule references"
Copy-AssetDirectory -SourceDir (Join-Path $SourceRoot "src\agents") -TargetDir (Join-Path $pluginRoot "references\agents") -Label "agent references"

$marketplaceDir = Join-Path $agentsDir "plugins"
New-Item -ItemType Directory -Path $marketplaceDir -Force | Out-Null
Copy-TemplateFile -SourceFile (Join-Path $SourceRoot "platforms\codex\templates\marketplace.json") -TargetFile (Join-Path $marketplaceDir "marketplace.json") -Label "repo marketplace"

if (-not (Test-Path (Join-Path $ProjectRoot "AGENTS.md") -PathType Leaf)) {
    Write-Warn "AGENTS.md not found. Run the exoskeleton-init skill before governed workflows."
}

Write-Host ""
Write-Step "Codex installation completed"
Write-Host "  Skills      : $(Join-Path $agentsDir "skills")" -ForegroundColor Green
Write-Host "  Agents      : $(Join-Path $codexDir "agents")" -ForegroundColor Green
Write-Host "  Rules       : $(Join-Path $codexDir "rules")" -ForegroundColor Green
Write-Host "  Hooks       : $(Join-Path $codexDir "hooks.json")" -ForegroundColor Green
Write-Host "  Marketplace : $(Join-Path $marketplaceDir "marketplace.json")" -ForegroundColor Green
Write-Host ""
Write-Host "  Next: restart Codex or reload skills, then review/trust hooks with /hooks." -ForegroundColor Yellow
