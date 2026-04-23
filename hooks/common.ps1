Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::InputEncoding  = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

# 优先使用 Cursor 注入的 CURSOR_PROJECT_DIR 环境变量定位项目根（全局 hooks 和项目级 hooks 均兼容）；
# 回退到 Get-Location（项目级 hooks 的 CWD 即项目根，保持向后兼容）。
$script:ProjectRoot    = if ($env:CURSOR_PROJECT_DIR) { $env:CURSOR_PROJECT_DIR } else { (Get-Location).Path }
$script:HarnessDir     = Join-Path $script:ProjectRoot ".cursor"
$script:ConfigFilePath = Join-Path $script:HarnessDir "harness-config.json"
$script:StateFilePath  = Join-Path $script:HarnessDir "harness-state.json"

# ---------- safe property access ----------

function Get-Prop {
    param($Obj, [string]$Name)
    if ($null -eq $Obj) { return $null }
    if ($Obj -is [hashtable]) {
        if ($Obj.ContainsKey($Name)) { return $Obj[$Name] }
        return $null
    }
    if ($Obj.PSObject.Properties.Name -contains $Name) { return $Obj.$Name }
    return $null
}

# ---------- stdin / payload ----------

function Read-HookInput {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    try   { return $raw | ConvertFrom-Json }
    catch { return [PSCustomObject]@{ raw = $raw } }
}

# ---------- harness config ----------

function Read-HarnessConfig {
    if (-not (Test-Path $script:ConfigFilePath)) { return $null }
    try {
        $content = Get-Content -Path $script:ConfigFilePath -Raw -Encoding UTF8
        return $content | ConvertFrom-Json
    }
    catch { return $null }
}

# ---------- harness state ----------

function New-DefaultState {
    return [PSCustomObject]@{
        mode                    = ""
        taskContractEstablished = $false
        lastTaskStart           = ""
        lastModeChange          = ""
    }
}

function Read-HarnessState {
    if (-not (Test-Path $script:StateFilePath)) {
        $default = New-DefaultState
        if (-not (Test-Path $script:HarnessDir)) {
            New-Item -ItemType Directory -Path $script:HarnessDir -Force | Out-Null
        }
        $default | ConvertTo-Json -Depth 5 | Set-Content -Path $script:StateFilePath -Encoding UTF8
        return $default
    }
    try {
        $content = Get-Content -Path $script:StateFilePath -Raw -Encoding UTF8
        return $content | ConvertFrom-Json
    }
    catch { return New-DefaultState }
}

function Write-HarnessState {
    param([Parameter(Mandatory)] $State)
    if (-not (Test-Path $script:HarnessDir)) {
        New-Item -ItemType Directory -Path $script:HarnessDir -Force | Out-Null
    }
    $State | ConvertTo-Json -Depth 5 | Set-Content -Path $script:StateFilePath -Encoding UTF8
}

$script:ValidModes = @("design", "coding",
    ([char]0x8BBE + [char]0x8BA1 + [char]0x6A21 + [char]0x5F0F),   # 设计模式
    ([char]0x7F16 + [char]0x7801 + [char]0x6A21 + [char]0x5F0F))   # 编码模式

function Get-ModeFromState {
    $state = Read-HarnessState
    $m = Get-Prop $state "mode"
    if ([string]::IsNullOrWhiteSpace($m)) { return "design" }
    $mStr = [string]$m
    if ($mStr -notin $script:ValidModes) { return "design" }
    return $mStr
}

function Update-Mode {
    param([Parameter(Mandatory)][string]$NewMode)
    $state = Read-HarnessState
    $state.mode = $NewMode
    $state.lastModeChange = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    Write-HarnessState -State $state
}

# ---------- structured event logging ----------

function Write-HarnessEvent {
    param(
        [string]$EventType,     # edit | deny | allow | ask | mode_change | new_task | contract_check
        [string]$HookName,      # afterFileEdit | beforeShellExecution | preToolUse | beforeSubmitPrompt
        [string]$Detail = "",
        [string]$Outcome = ""   # allow | deny | ask
    )
    $eventDir = Join-Path $script:HarnessDir "hooks\logs"
    if (-not (Test-Path $eventDir)) {
        New-Item -ItemType Directory -Path $eventDir -Force | Out-Null
    }
    $event = [ordered]@{
        ts      = (Get-Date -Format "yyyy-MM-ddTHH:mm:ss")
        type    = $EventType
        hook    = $HookName
        mode    = (Get-ModeFromState)
        detail  = $Detail
        outcome = $Outcome
        project = (Split-Path $script:ProjectRoot -Leaf)
    }
    $line = $event | ConvertTo-Json -Depth 3 -Compress
    Add-Content -Path (Join-Path $eventDir "harness-events.jsonl") -Value $line -Encoding UTF8
}

# ---------- hook responses (Cursor hooks v1) ----------

function Deny-Hook {
    param([Parameter(Mandatory)][string]$Reason)
    $resp = [ordered]@{
        permission    = "deny"
        decision      = "deny"
        "continue"    = $false
        user_message  = $Reason
        userMessage   = $Reason
        agent_message = $Reason
        agentMessage  = $Reason
        reason        = $Reason
    }
    $resp | ConvertTo-Json -Depth 5 -Compress
    exit 2
}

function Allow-Hook {
    param([string]$Message = "allow")
    $resp = [ordered]@{
        permission = "allow"
        decision   = "allow"
        "continue" = $true
    }
    $resp | ConvertTo-Json -Depth 5 -Compress
    exit 0
}

function Ask-Hook {
    param([Parameter(Mandatory)][string]$Message)
    $resp = [ordered]@{
        permission    = "ask"
        decision      = "ask"
        user_message  = $Message
        userMessage   = $Message
        agent_message = $Message
        agentMessage  = $Message
    }
    $resp | ConvertTo-Json -Depth 5 -Compress
    exit 0
}

# ---------- path utilities ----------

function Normalize-PathText {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
    return $Text.Replace("/", "\").ToLowerInvariant().TrimEnd("\")
}

function Test-PathInWhitelist {
    param([string]$Path, [string[]]$Whitelist)
    $n = Normalize-PathText -Text $Path
    if ([string]::IsNullOrWhiteSpace($n)) { return $true }
    foreach ($w in $Whitelist) {
        if ($n.StartsWith((Normalize-PathText -Text $w))) { return $true }
    }
    return $false
}
