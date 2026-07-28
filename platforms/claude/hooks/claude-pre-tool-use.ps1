Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$env:EXOSKELETON_HOOK_PLATFORM = "claude"

try {

$commonCandidates = @(
    (Join-Path $PSScriptRoot "common.ps1"),
    (Join-Path $PSScriptRoot "..\..\..\src\hooks\common.ps1")
)
$commonPath = $commonCandidates | Where-Object { Test-Path $_ -PathType Leaf } | Select-Object -First 1
if (-not $commonPath) { throw "common.ps1 not found" }
. $commonPath

$payload = Read-HookInput
$mode    = Get-ModeFromState
$config  = Read-HarnessConfig

$tool = ""
$t = Get-Prop $payload "tool_name"
if (-not $t) { $t = Get-Prop $payload "toolName" }
if ($t) { $tool = [string]$t }

$toolInput = Get-Prop $payload "tool_input"
if (-not $toolInput) { $toolInput = Get-Prop $payload "input" }
if ($toolInput -is [string]) {
    try { $toolInput = $toolInput | ConvertFrom-Json } catch {}
}

function Match-Rule {
    param([string]$Text, [Object[]]$Rules)
    foreach ($rule in $Rules) {
        if ($Text -match $rule.pattern) { return $rule }
    }
    return $null
}

if ($tool -match "^(Bash|PowerShell)$") {
    $command = ""
    $c = Get-Prop $toolInput "command"
    if ($c) { $command = [string]$c }
    $normalizedCmd = [regex]::Replace($command.ToLowerInvariant(), "\s+", " ").Trim()

    $denyRules = @(
        @{ id = "fs.rmrf"; pattern = "(^|\s)rm\s+-r[fF](\s|$)" },
        @{ id = "fs.del"; pattern = "(^|\s)del\s+/f\s+/s\s+/q(\s|$)" },
        @{ id = "fs.format"; pattern = "(^|\s)format(\s|$)" },
        @{ id = "fs.rmdir"; pattern = "(^|\s)(rd|rmdir)\s+/s\s+/q(\s|$)" },
        @{ id = "git.resetHard"; pattern = "(^|\s)git\s+reset\s+--hard(\s|$)" },
        @{ id = "git.cleanFdx"; pattern = "(^|\s)git\s+clean\s+-[^\s]*f[^\s]*d[^\s]*x[^\s]*(\s|$)" },
        @{ id = "git.pushForce"; pattern = "(^|\s)git\s+push(\s+[^|;&]+)?\s+--force(\s|$)|(^|\s)git\s+push(\s+[^|;&]+)?\s+-f(\s|$)" },
        @{ id = "db.dropTable"; pattern = "(^|\s)drop\s+table(\s|$)" },
        @{ id = "db.dropDatabase"; pattern = "(^|\s)drop\s+database(\s|$)" },
        @{ id = "db.truncate"; pattern = "(^|\s)truncate(\s+table)?(\s|$)" },
        @{ id = "release.npmPublish"; pattern = "(^|\s)npm\s+publish(\s|$)" },
        @{ id = "release.mvnRelease"; pattern = "(^|\s)mvn\s+release(\s|$)" },
        @{ id = "release.mvnDeploy"; pattern = "(^|\s)mvn\s+deploy(\s|$)" }
    )

    $matchedDeny = Match-Rule -Text $normalizedCmd -Rules $denyRules
    if ($matchedDeny) {
        Write-HarnessEvent -EventType "deny" -HookName "claudePreToolUse" -Detail "deny-rule: $($matchedDeny.id) | cmd: $command" -Outcome "deny"
        Deny-Hook -Reason "Blocked high-risk command: $($matchedDeny.id)"
    }

    $askRules = @(
        @{ id = "git.rebase"; pattern = "(^|\s)git\s+rebase(\s|$)" },
        @{ id = "git.push"; pattern = "(^|\s)git\s+push(\s|$)" },
        @{ id = "git.merge"; pattern = "(^|\s)git\s+merge(\s|$)" },
        @{ id = "git.stashDrop"; pattern = "(^|\s)git\s+stash\s+drop(\s|$)" }
    )

    $matchedAsk = Match-Rule -Text $normalizedCmd -Rules $askRules
    if ($matchedAsk) {
        Write-HarnessEvent -EventType "ask" -HookName "claudePreToolUse" -Detail "ask-rule: $($matchedAsk.id) | cmd: $command" -Outcome "ask"
        Ask-Hook -Message "Please confirm risky command: $($matchedAsk.id)"
    }

    Allow-Hook -Message "claude shell pre-tool passed"
}

$writeTools = @("Write", "Edit", "MultiEdit", "NotebookEdit")
$isWriteTool = $false
foreach ($name in $writeTools) {
    if ($tool -eq $name) { $isWriteTool = $true; break }
}
if (-not $isWriteTool) { Allow-Hook -Message "non-governed tool, pass" }

$pathText = ""
$pt = Get-Prop $toolInput "file_path"
if (-not $pt) { $pt = Get-Prop $toolInput "path" }
if ($pt) { $pathText = [string]$pt }

$designLabel  = [char]0x8BBE + [char]0x8BA1 + [char]0x6A21 + [char]0x5F0F
$isDesignMode = ($mode -eq "design" -or $mode -eq $designLabel)
$whitelist = @()
if ($config) {
    $pathsCfg = Get-Prop $config "paths"
    if ($pathsCfg) {
        if ($isDesignMode) {
            $dmw = Get-Prop $pathsCfg "designModeWritable"
            if ($dmw) { $whitelist = @($dmw) }
        } else {
            $wl = Get-Prop $pathsCfg "pathWhitelist"
            if ($wl) { $whitelist = @($wl) }
        }
    }
}

if ($whitelist.Count -eq 0) { Allow-Hook -Message "no harness-config.json found, pass" }
if ([string]::IsNullOrWhiteSpace($pathText)) {
    if ($isDesignMode) { Ask-Hook -Message "Design mode: write target path unknown, please confirm." }
    Allow-Hook -Message "no path info, pass"
}

if (-not (Test-PathInWhitelist -Path $pathText -Whitelist $whitelist)) {
    $allowedList = $whitelist -join ", "
    Write-HarnessEvent -EventType "deny" -HookName "claudePreToolUse" -Detail "path=$pathText, allowed=$allowedList" -Outcome "deny"
    Deny-Hook -Reason "Path not in whitelist: $pathText. Allowed: $allowedList"
}

Allow-Hook -Message "claude write pre-tool passed"

} catch {
    Allow-Hook -Message "claude pre-tool fallback allow"
}
