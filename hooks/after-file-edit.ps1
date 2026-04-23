Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. "$PSScriptRoot\common.ps1"

$payload = Read-HookInput
$mode    = Get-ModeFromState

$changedPath = ""
$cp = Get-Prop $payload "file_path"
if (-not $cp) { $cp = Get-Prop $payload "path" }
if (-not $cp) { $cp = Get-Prop $payload "targetPath" }
if (-not $cp) { $cp = Get-Prop $payload "raw" }
if ($cp) { $changedPath = [string]$cp }

$auditDir = Join-Path $script:HarnessDir "hooks\logs"
if (-not (Test-Path $auditDir)) {
    New-Item -ItemType Directory -Path $auditDir -Force | Out-Null
}

$modeLabel = if ([string]::IsNullOrWhiteSpace($mode)) { "unset" } else { $mode }
$line = "{0}`tmode={1}`tpath={2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $modeLabel, $changedPath
Add-Content -Path (Join-Path $auditDir "edit-audit.log") -Value $line -Encoding UTF8

Write-HarnessEvent -EventType "edit" -HookName "afterFileEdit" `
    -Detail $changedPath -Outcome "allow"

Allow-Hook -Message "afterFileEdit audit logged"
