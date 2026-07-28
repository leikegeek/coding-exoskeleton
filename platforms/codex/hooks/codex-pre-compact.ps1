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
    $trigger = Get-Prop $payload "trigger"
    if (-not $trigger) { $trigger = Get-Prop $payload "compactTrigger" }
    if (-not $trigger) { $trigger = "unknown" }

    $state = Read-HarnessState
    $checkpointDir = Join-Path $script:HarnessDir "compaction"
    if (-not (Test-Path $checkpointDir)) {
        New-Item -ItemType Directory -Path $checkpointDir -Force | Out-Null
    }
    $checkpoint = [ordered]@{
        ts      = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
        trigger = [string]$trigger
        mode    = Get-ModeFromState
        state   = $state
    }
    $checkpoint | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $checkpointDir "latest-pre-compact.json") -Encoding UTF8
    Write-HarnessEvent -EventType "compact_pre" -HookName "codexPreCompact" -Detail "trigger=$trigger" -Outcome "allow"
    Allow-Hook -Message "codex pre-compact checkpoint recorded"
} catch {
    Allow-Hook -Message "codex pre-compact fallback allow"
}
