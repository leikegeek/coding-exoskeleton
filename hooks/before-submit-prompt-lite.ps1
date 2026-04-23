Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. "$PSScriptRoot\common.ps1"

$payload = Read-HookInput
$state   = Read-HarnessState

# ---------- extract prompt text ----------

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

# ---------- detect new-task signals ----------

$isNewTask = $false
$signals = @(
    ([string][char]0x65B0 + [char]0x4EFB + [char]0x52A1),          # 新任务
    ([string][char]0x65B0 + [char]0x9700 + [char]0x6C42),          # 新需求
    ([string][char]0x6A21 + [char]0x5F0F + [char]0xFF1A),          # 模式：
    ([string][char]0x6A21 + [char]0x5F0F + ":")                     # 模式:
)
foreach ($kw in $signals) {
    if ($prompt.Contains($kw)) { $isNewTask = $true; break }
}

# ---------- parse & persist mode ----------

$modeFullWidth  = [string][char]0x6A21 + [char]0x5F0F  # 模式
$designLabel    = [string][char]0x8BBE + [char]0x8BA1 + [char]0x6A21 + [char]0x5F0F  # 设计模式
$codingLabel    = [string][char]0x7F16 + [char]0x7801 + [char]0x6A21 + [char]0x5F0F  # 编码模式
$fwColon        = [string][char]0xFF1A  # ：
$modePattern    = "${modeFullWidth}[${fwColon}:]\s*(${designLabel}|${codingLabel})"

$declaredMode = ""
if ($prompt -match $modePattern) {
    $declaredMode = $Matches[1].Trim()
}

if (-not [string]::IsNullOrWhiteSpace($declaredMode)) {
    $modeValue = if ($declaredMode -eq $designLabel) { "design" } else { "coding" }
    Update-Mode -NewMode $modeValue
    $state = Read-HarnessState
    $state.taskContractEstablished = $false
    $state.lastTaskStart = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    Write-HarnessState -State $state

    Write-HarnessEvent -EventType "mode_change" -HookName "beforeSubmitPrompt" `
        -Detail "mode=$modeValue" -Outcome "allow"
}

if ($isNewTask) {
    Write-HarnessEvent -EventType "new_task" -HookName "beforeSubmitPrompt" `
        -Detail "new task detected" -Outcome "allow"
}

Allow-Hook -Message "prompt-lite: mode parsed, pass"
