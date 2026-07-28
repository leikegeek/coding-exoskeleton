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

    Write-HarnessEvent -EventType "compact_post" -HookName "codexPostCompact" -Detail "trigger=$trigger" -Outcome "allow"
    Allow-Hook -Message "codex post-compact event recorded"
} catch {
    Allow-Hook -Message "codex post-compact fallback allow"
}
