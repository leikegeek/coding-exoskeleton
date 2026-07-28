Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$env:EXOSKELETON_HOOK_PLATFORM = "codex"

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

$tool = ""
$t = Get-Prop $payload "tool_name"
if (-not $t) { $t = Get-Prop $payload "toolName" }
if ($t) { $tool = [string]$t }

$toolInput = Get-Prop $payload "tool_input"
if (-not $toolInput) { $toolInput = Get-Prop $payload "input" }
if ($toolInput -is [string]) {
    try { $toolInput = $toolInput | ConvertFrom-Json } catch {}
}

$writeTools = @("Write", "Edit", "MultiEdit", "NotebookEdit")
$isWriteTool = $false
foreach ($name in $writeTools) {
    if ($tool -eq $name) { $isWriteTool = $true; break }
}
if (-not $isWriteTool) { Allow-Hook -Message "non-write tool, pass" }

$changedPath = ""
$cp = Get-Prop $toolInput "file_path"
if (-not $cp) { $cp = Get-Prop $toolInput "path" }
if ($cp) { $changedPath = [string]$cp }

$auditDir = Join-Path $script:HarnessDir "hooks\logs"
if (-not (Test-Path $auditDir)) {
    New-Item -ItemType Directory -Path $auditDir -Force | Out-Null
}

$modeLabel = if ([string]::IsNullOrWhiteSpace($mode)) { "unset" } else { $mode }
$line = "{0}`tmode={1}`tpath={2}`ttool={3}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $modeLabel, $changedPath, $tool
Add-Content -Path (Join-Path $auditDir "edit-audit.log") -Value $line -Encoding UTF8

Write-HarnessEvent -EventType "edit" -HookName "codexPostToolUse" -Detail $changedPath -Outcome "allow"
Allow-Hook -Message "codex post-tool audit logged"

} catch {
    Allow-Hook -Message "codex post-tool fallback allow"
}
