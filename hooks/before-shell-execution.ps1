Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try {

. "$PSScriptRoot\common.ps1"

$payload = Read-HookInput
$mode    = Get-ModeFromState

$designLabel  = [char]0x8BBE + [char]0x8BA1 + [char]0x6A21 + [char]0x5F0F  # 设计模式
$isDesignMode = ($mode -eq "design" -or $mode -eq $designLabel)

# ---------- extract command ----------

$command = ""
$c = Get-Prop $payload "command"
if (-not $c) { $c = Get-Prop $payload "rawCommand" }
if (-not $c) { $c = Get-Prop $payload "raw" }
if ($c) { $command = [string]$c }

$cmd = $command.ToLowerInvariant()
$normalizedCmd = [regex]::Replace($cmd, "\s+", " ").Trim()

function Match-Rule {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][Object[]]$Rules
    )
    foreach ($rule in $Rules) {
        if ($Text -match $rule.pattern) {
            return $rule
        }
    }
    return $null
}

# ---------- deny: universal high-risk commands ----------

$universalDenyRules = @(
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

$matchedDeny = Match-Rule -Text $normalizedCmd -Rules $universalDenyRules
if ($matchedDeny) {
    Write-HarnessEvent -EventType "deny" -HookName "beforeShellExecution" `
        -Detail "deny-rule: $($matchedDeny.id) | cmd: $command" -Outcome "deny"
    Deny-Hook -Reason "Blocked high-risk command: $($matchedDeny.id)"
}

# ---------- ask: global caution commands ----------

$globalAskRules = @(
    @{ id = "git.rebase"; pattern = "(^|\s)git\s+rebase(\s|$)" },
    @{ id = "git.push"; pattern = "(^|\s)git\s+push(\s|$)" },
    @{ id = "git.merge"; pattern = "(^|\s)git\s+merge(\s|$)" },
    @{ id = "git.stashDrop"; pattern = "(^|\s)git\s+stash\s+drop(\s|$)" }
)

$matchedGlobalAsk = Match-Rule -Text $normalizedCmd -Rules $globalAskRules
if ($matchedGlobalAsk) {
    Write-HarnessEvent -EventType "ask" -HookName "beforeShellExecution" `
        -Detail "ask-rule: $($matchedGlobalAsk.id) | cmd: $command" -Outcome "ask"
    Ask-Hook -Message "Please confirm risky command: $($matchedGlobalAsk.id)"
}

# ---------- design-mode: extra constraints (ask/deny) ----------

if ($isDesignMode) {
    $designDenyRules = @(
        @{ id = "design.gitCommit"; pattern = "(^|\s)git\s+commit(\s|$)" }
    )

    $matchedDesignDeny = Match-Rule -Text $normalizedCmd -Rules $designDenyRules
    if ($matchedDesignDeny) {
        Write-HarnessEvent -EventType "deny" -HookName "beforeShellExecution" `
            -Detail "design-deny: $($matchedDesignDeny.id) | cmd: $command" -Outcome "deny"
        Deny-Hook -Reason "Design mode blocks command: $($matchedDesignDeny.id)"
    }

    $designAskRules = @(
        @{ id = "design.npmInstall"; pattern = "(^|\s)npm\s+install(\s|$)" },
        @{ id = "design.yarnInstall"; pattern = "(^|\s)yarn\s+install(\s|$)" },
        @{ id = "design.mvnPackage"; pattern = "(^|\s)mvn\s+package(\s|$)" },
        @{ id = "design.gradleBuild"; pattern = "(^|\s)gradle\s+build(\s|$)" },
        @{ id = "design.dotnetPublish"; pattern = "(^|\s)dotnet\s+publish(\s|$)" }
    )

    $matchedDesignAsk = Match-Rule -Text $normalizedCmd -Rules $designAskRules
    if ($matchedDesignAsk) {
        Write-HarnessEvent -EventType "ask" -HookName "beforeShellExecution" `
            -Detail "design-ask: $($matchedDesignAsk.id) | cmd: $command" -Outcome "ask"
        Ask-Hook -Message "Design mode confirmation required: $($matchedDesignAsk.id)"
    }
}

Allow-Hook -Message "beforeShellExecution passed"

} catch {
    '{"permission":"ask","decision":"ask","user_message":"beforeShellExecution failed unexpectedly; please confirm command manually","agent_message":"beforeShellExecution failed unexpectedly; please confirm command manually"}'
    exit 0
}
