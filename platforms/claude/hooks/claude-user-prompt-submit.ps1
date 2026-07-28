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
$state   = Read-HarnessState

$prompt = ""
$p = Get-Prop $payload "prompt"
if (-not $p) { $p = Get-Prop $payload "userMessage" }
if (-not $p) { $p = Get-Prop $payload "message" }
if (-not $p) { $p = Get-Prop $payload "text" }
if (-not $p) { $p = Get-Prop $payload "raw" }
if ($p) { $prompt = [string]$p }

if ([string]::IsNullOrWhiteSpace($prompt)) {
    Allow-Hook -Message "empty prompt, pass"
}

$isNewTask = $false
$signals = @(
    ([string][char]0x65B0 + [char]0x4EFB + [char]0x52A1),
    ([string][char]0x65B0 + [char]0x9700 + [char]0x6C42),
    ([string][char]0x6A21 + [char]0x5F0F + [char]0xFF1A),
    ([string][char]0x6A21 + [char]0x5F0F + ":")
)
foreach ($kw in $signals) {
    if ($prompt.Contains($kw)) { $isNewTask = $true; break }
}

$modeFullWidth = [string][char]0x6A21 + [char]0x5F0F
$designLabel   = [string][char]0x8BBE + [char]0x8BA1 + [char]0x6A21 + [char]0x5F0F
$codingLabel   = [string][char]0x7F16 + [char]0x7801 + [char]0x6A21 + [char]0x5F0F
$fwColon       = [string][char]0xFF1A
$modePattern   = "${modeFullWidth}[${fwColon}:]\s*(${designLabel}|${codingLabel})"

$declaredMode = ""
if ($prompt -match $modePattern) { $declaredMode = $Matches[1].Trim() }

if (-not [string]::IsNullOrWhiteSpace($declaredMode)) {
    $modeValue = if ($declaredMode -eq $designLabel) { "design" } else { "coding" }
    Update-Mode -NewMode $modeValue
    $state = Read-HarnessState
    $state.taskContractEstablished = $false
    $state.lastTaskStart = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    Write-HarnessState -State $state
    Write-HarnessEvent -EventType "mode_change" -HookName "claudeUserPromptSubmit" -Detail "mode=$modeValue" -Outcome "allow"
}

if ($isNewTask) {
    Write-HarnessEvent -EventType "new_task" -HookName "claudeUserPromptSubmit" -Detail "new task detected" -Outcome "allow"
}

Allow-Hook -Message "claude prompt parsed, pass"

} catch {
    Allow-Hook -Message "claude prompt fallback allow"
}
