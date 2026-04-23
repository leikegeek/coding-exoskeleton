Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try {

. "$PSScriptRoot\common.ps1"

$payload = Read-HookInput
$mode    = Get-ModeFromState
$config  = Read-HarnessConfig

$designLabel  = [char]0x8BBE + [char]0x8BA1 + [char]0x6A21 + [char]0x5F0F  # 设计模式
$isDesignMode = ($mode -eq "design" -or $mode -eq $designLabel)

# ---------- extract tool name ----------

$tool = ""
$t = Get-Prop $payload "tool_name"
if (-not $t) { $t = Get-Prop $payload "toolName" }
if (-not $t) {
    $toolObj = Get-Prop $payload "tool"
    if ($toolObj) { $t = Get-Prop $toolObj "name" }
}
if (-not $t) { $t = Get-Prop $payload "type" }
if ($t) { $tool = [string]$t }

# ---------- extract target path ----------

$pathText = ""
$pt = Get-Prop $payload "path"
if (-not $pt) { $pt = Get-Prop $payload "file_path" }
if (-not $pt) { $pt = Get-Prop $payload "targetPath" }
if (-not $pt) {
    $toolInput = Get-Prop $payload "tool_input"
    if ($toolInput) {
        if ($toolInput -is [string]) {
            try { $toolInput = $toolInput | ConvertFrom-Json } catch {}
        }
        if ($toolInput -and $toolInput -isnot [string]) {
            $pt = Get-Prop $toolInput "path"
            if (-not $pt) { $pt = Get-Prop $toolInput "file_path" }
            if (-not $pt) { $pt = Get-Prop $toolInput "targetPath" }
        }
    }
}
if (-not $pt) {
    $inputObj = Get-Prop $payload "input"
    if ($inputObj) { $pt = Get-Prop $inputObj "path" }
}
if (-not $pt) {
    $args2 = Get-Prop $payload "arguments"
    if ($args2) {
        $argsJson = ($args2 | ConvertTo-Json -Depth 8 -Compress)
        if ($argsJson -match '"path"\s*:\s*"([^"]+)"') { $pt = $Matches[1] }
    }
}
if ($pt) { $pathText = [string]$pt }

# ---------- identify write tools ----------

$writeTools = @(
    "Write", "Edit", "MultiEdit", "StrReplace",
    "Delete", "DeleteFile", "CreateFile", "Create",
    "NotebookEdit", "EditNotebook"
)
$isWriteTool = $false
foreach ($name in $writeTools) {
    if ($tool -match $name) { $isWriteTool = $true; break }
}

if (-not $isWriteTool) {
    Allow-Hook -Message "non-write tool, pass"
}

# ---------- build whitelist from harness-config.json ----------

$whitelist = @()
if ($config) {
    $pathsCfg = Get-Prop $config "paths"
    if ($pathsCfg) {
        if ($isDesignMode) {
            $dmw = Get-Prop $pathsCfg "designModeWritable"
            if ($dmw) { $whitelist = @($dmw) }
        }
        else {
            $wl = Get-Prop $pathsCfg "pathWhitelist"
            if ($wl) { $whitelist = @($wl) }
        }
    }
}

if ($whitelist.Count -eq 0) {
    Allow-Hook -Message "no harness-config.json found, pass"
}

# ---------- whitelist-based path gating ----------

if ([string]::IsNullOrWhiteSpace($pathText)) {
    if ($isDesignMode) {
        Write-HarnessEvent -EventType "ask" -HookName "preToolUse" `
            -Detail "unknown path in design mode, tool=$tool" -Outcome "ask"
        Ask-Hook -Message "Design mode: write target path unknown, please confirm."
    }
    Allow-Hook -Message "no path info, pass"
}

$inWhitelist = Test-PathInWhitelist -Path $pathText -Whitelist $whitelist
if (-not $inWhitelist) {
    $allowedList = $whitelist -join ", "
    Write-HarnessEvent -EventType "deny" -HookName "preToolUse" `
        -Detail "path=$pathText, allowed=$allowedList" -Outcome "deny"
    if ($isDesignMode) {
        Deny-Hook -Reason "Design mode: only allowed paths are writable. Allowed: $allowedList. Target: $pathText"
    }
    else {
        Deny-Hook -Reason "Path not in whitelist: $pathText. Allowed: $allowedList"
    }
}

Allow-Hook -Message "preToolUse passed"

} catch {
    '{"permission":"allow","decision":"allow","continue":true}'
    exit 0
}
