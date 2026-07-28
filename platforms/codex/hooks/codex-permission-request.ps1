Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$env:EXOSKELETON_HOOK_PLATFORM = "codex"

function Complete-ApprovalHook {
    param(
        [ValidateSet("allow", "ask", "deny")]
        [string]$Decision = "allow",
        [string]$Reason = "allow"
    )

    $resp = [ordered]@{
        "continue" = $true
        hookSpecificOutput = [ordered]@{
            hookEventName            = "PermissionRequest"
            permissionDecision       = $Decision
            permissionDecisionReason = $Reason
        }
    }
    if ($Decision -eq "deny") {
        $resp["continue"] = $false
        $resp["stopReason"] = $Reason
    }
    $resp | ConvertTo-Json -Depth 5 -Compress
    if ($Decision -eq "deny") { exit 2 }
    exit 0
}

try {
    $commonCandidates = @(
        (Join-Path $PSScriptRoot "common.ps1"),
        (Join-Path $PSScriptRoot "..\..\..\src\hooks\common.ps1")
    )
    $commonPath = $commonCandidates | Where-Object { Test-Path $_ -PathType Leaf } | Select-Object -First 1
    if (-not $commonPath) { throw "common.ps1 not found" }
    . $commonPath

    $payload = Read-HookInput
    $tool = ""
    $t = Get-Prop $payload "tool_name"
    if (-not $t) { $t = Get-Prop $payload "toolName" }
    if ($t) { $tool = [string]$t }

    $toolInput = Get-Prop $payload "tool_input"
    if (-not $toolInput) { $toolInput = Get-Prop $payload "input" }
    if ($toolInput -is [string]) {
        try { $toolInput = $toolInput | ConvertFrom-Json } catch {}
    }

    $command = ""
    $c = Get-Prop $toolInput "command"
    if ($c) { $command = [string]$c }
    $normalizedCmd = [regex]::Replace($command.ToLowerInvariant(), "\s+", " ").Trim()

    $denyPatterns = @(
        @{ id = "fs.rmrf"; pattern = "(^|\s)rm\s+-[^\s]*r[^\s]*f|(^|\s)rm\s+-[^\s]*f[^\s]*r" },
        @{ id = "git.resetHard"; pattern = "(^|\s)git\s+reset\s+--hard(\s|$)" },
        @{ id = "git.cleanFdx"; pattern = "(^|\s)git\s+clean\s+-[^\s]*f[^\s]*d[^\s]*x[^\s]*(\s|$)" },
        @{ id = "git.pushForce"; pattern = "(^|\s)git\s+push(\s+[^|;&]+)?\s+--force(\s|$)|(^|\s)git\s+push(\s+[^|;&]+)?\s+-f(\s|$)" },
        @{ id = "db.dropTable"; pattern = "(^|\s)drop\s+table(\s|$)" },
        @{ id = "db.dropDatabase"; pattern = "(^|\s)drop\s+database(\s|$)" },
        @{ id = "db.truncate"; pattern = "(^|\s)truncate(\s+table)?(\s|$)" }
    )

    foreach ($rule in $denyPatterns) {
        if ($normalizedCmd -match $rule.pattern) {
            Write-HarnessEvent -EventType "deny" -HookName "codexPermissionRequest" -Detail "deny-rule: $($rule.id) | tool=$tool | cmd: $command" -Outcome "deny"
            Complete-ApprovalHook -Decision "deny" -Reason "Blocked high-risk approval request: $($rule.id)"
        }
    }

    Write-HarnessEvent -EventType "allow" -HookName "codexPermissionRequest" -Detail "tool=$tool | cmd: $command" -Outcome "allow"
    Complete-ApprovalHook -Decision "allow" -Reason "approval request passed Exoskeleton policy"
} catch {
    Complete-ApprovalHook -Decision "allow" -Reason "permission request fallback allow"
}
