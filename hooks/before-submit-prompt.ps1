Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# 完整契约校验 hook（opt-in，不在任何默认 profile 中）
# 包含 lite 版的全部功能 + 6字段契约完整性检查
# 使用方式：在 hooks.json 中将 before-submit-prompt-lite.ps1 替换为 before-submit-prompt.ps1

. "$PSScriptRoot\common.ps1"

$payload = Read-HookInput
$state   = Read-HarnessState
$config  = Read-HarnessConfig

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
    $isNewTask = $true

    Write-HarnessEvent -EventType "mode_change" -HookName "beforeSubmitPrompt" `
        -Detail "mode=$modeValue" -Outcome "allow"
}

# ---------- smart contract checking ----------

$hasContract    = ((Get-Prop $state "taskContractEstablished") -eq $true)
$isContinuation = -not $isNewTask

if ($isContinuation -and $hasContract) {
    Allow-Hook -Message "contract established, continuation pass"
}

# ---------- read contract fields from config ----------

$fieldNames = @(
    ([string][char]0x6A21 + [char]0x5F0F),                                                   # 模式
    ([string][char]0x76EE + [char]0x6807),                                                   # 目标
    ([string][char]0x8303 + [char]0x56F4),                                                   # 范围
    ([string][char]0x5141 + [char]0x8BB8 + [char]0x5199 + [char]0x5165 + [char]0x8DEF + [char]0x5F84),  # 允许写入路径
    ([string][char]0x7981 + [char]0x6B62 + [char]0x9879),                                    # 禁止项
    ([string][char]0x9A8C + [char]0x6536 + [char]0x6807 + [char]0x51C6)                      # 验收标准
)

if ($config) {
    $contractCfg = Get-Prop $config "contract"
    if ($contractCfg) {
        $cfgFields = Get-Prop $contractCfg "fields"
        if ($cfgFields -and $cfgFields.Count -gt 0) {
            $fieldNames = @($cfgFields)
        }
    }
}

$missing = @()
foreach ($field in $fieldNames) {
    if ($prompt -notmatch [Regex]::Escape($field)) { $missing += $field }
}

if ($missing.Count -gt 0) {
    $sep   = [string][char]0x3001  # 、
    $label = $missing -join $sep
    $msg   = "任务契约不完整，缺少：$label"
    Write-HarnessEvent -EventType "contract_check" -HookName "beforeSubmitPrompt" `
        -Detail "missing: $label" -Outcome "ask"
    Ask-Hook -Message $msg
}

$state = Read-HarnessState
$state.taskContractEstablished = $true
$state.lastTaskStart = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Write-HarnessState -State $state

Write-HarnessEvent -EventType "contract_check" -HookName "beforeSubmitPrompt" `
    -Detail "contract validated" -Outcome "allow"

# ---------- artifact existence check ----------

$svIdPattern = "SV-\d+"
$svMatch = [regex]::Match($prompt, $svIdPattern)
if ($svMatch.Success) {
    $svId = $svMatch.Value
    $projectRoot = $script:ProjectRoot
    $artifactGatePattern = "(?i)(/deliver|deliver|delivery|submit\s+pr|create\s+pr|pull\s+request|B4|交付|提交\s*PR|创建\s*PR)"
    $isArtifactGateIntent = ($prompt -match $artifactGatePattern)
    $artifactChecks = @(
        @{ path = "docs\delivery\$svId-changelist.md"; label = "changelist" },
        @{ path = "docs\delivery\$svId-review-report.md"; label = "review-report" },
        @{ path = "docs\delivery\$svId-tech-ref.md"; label = "tech-ref" }
    )

    $missingArtifacts = @()
    foreach ($a in $artifactChecks) {
        $fullPath = Join-Path $projectRoot $a.path
        if (-not (Test-Path $fullPath)) {
            $missingArtifacts += $a.label
        }
    }

    if ($missingArtifacts.Count -gt 0) {
        $artifactList = $missingArtifacts -join ", "
        $artifactOutcome = if ($isArtifactGateIntent) { "ask" } else { "allow" }
        Write-HarnessEvent -EventType "artifact_check" -HookName "beforeSubmitPrompt" `
            -Detail "missing artifacts for ${svId}: $artifactList" -Outcome $artifactOutcome
        if ($isArtifactGateIntent) {
            Ask-Hook -Message "Artifact gate: missing delivery artifacts for ${svId}: $artifactList. Complete B3/B4 document generation before delivery or PR."
        }
    } else {
        Write-HarnessEvent -EventType "artifact_check" -HookName "beforeSubmitPrompt" `
            -Detail "all artifacts present for $svId" -Outcome "allow"
    }
}

Allow-Hook -Message "contract validated"
