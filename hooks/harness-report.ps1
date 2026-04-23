#Requires -Version 5.1
<#
.SYNOPSIS
    Exoskeleton 事件统计报告

.DESCRIPTION
    解析 .cursor/hooks/logs/harness-events.jsonl，生成可读的统计报告。
    支持按时间范围筛选，输出拦截统计、模式分布、高频编辑路径等。

.PARAMETER Project
    目标项目路径，默认当前目录

.PARAMETER Days
    统计最近 N 天的事件，默认 7

.PARAMETER OutputJson
    以 JSON 格式输出（适合程序消费），默认关闭

.EXAMPLE
    .\scripts\harness-report.ps1 -Project C:\MyProject -Days 14
#>
[CmdletBinding()]
param(
    [string] $Project = ".",
    [int]    $Days    = 7,
    [switch] $OutputJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$ProjectPath = (Resolve-Path $Project).Path
$eventsFile  = Join-Path $ProjectPath ".cursor\hooks\logs\harness-events.jsonl"

if (-not (Test-Path $eventsFile)) {
    Write-Host "未找到事件日志：$eventsFile" -ForegroundColor Red
    Write-Host "请确认项目已安装 harness 且有过 hook 触发记录。" -ForegroundColor Yellow
    exit 1
}

# ---------- parse events ----------

$cutoff = (Get-Date).AddDays(-$Days)
$events = [System.Collections.Generic.List[object]]::new()

foreach ($line in [System.IO.File]::ReadLines($eventsFile, [System.Text.UTF8Encoding]::new($false))) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    try {
        $evt = $line | ConvertFrom-Json
        $ts  = [datetime]::ParseExact($evt.ts, "yyyy-MM-ddTHH:mm:ss", $null)
        if ($ts -ge $cutoff) {
            $evt | Add-Member -NotePropertyName "parsed_ts" -NotePropertyValue $ts -Force
            $events.Add($evt)
        }
    }
    catch { continue }
}

if ($events.Count -eq 0) {
    Write-Host "最近 $Days 天内没有事件记录。" -ForegroundColor Yellow
    exit 0
}

# ---------- compute statistics ----------

$totalCount = $events.Count
$editCount  = ($events | Where-Object { $_.type -eq "edit" }).Count
$denyEvents = @($events | Where-Object { $_.outcome -eq "deny" })
$askEvents  = @($events | Where-Object { $_.outcome -eq "ask" })
$denyCount  = $denyEvents.Count
$askCount   = $askEvents.Count
$modeChanges = @($events | Where-Object { $_.type -eq "mode_change" })
$newTasks    = @($events | Where-Object { $_.type -eq "new_task" })

# mode distribution (from edit events, most representative)
$modeGroups = $events | Group-Object -Property mode
$modeDistribution = @{}
foreach ($g in $modeGroups) {
    $label = if ([string]::IsNullOrWhiteSpace($g.Name)) { "unset" } else { $g.Name }
    $modeDistribution[$label] = $g.Count
}

# top denied commands/paths
$topDenied = @()
if ($denyEvents.Count -gt 0) {
    $topDenied = $denyEvents |
        Group-Object -Property detail |
        Sort-Object -Property Count -Descending |
        Select-Object -First 5 |
        ForEach-Object { [PSCustomObject]@{ Detail = $_.Name; Count = $_.Count } }
}

# top edited paths (extract last path segment for grouping)
$editEvents = @($events | Where-Object { $_.type -eq "edit" -and -not [string]::IsNullOrWhiteSpace($_.detail) })
$topEdited = @()
if ($editEvents.Count -gt 0) {
    $topEdited = $editEvents |
        ForEach-Object {
            $d = $_.detail
            # group by COLA layer pattern
            if ($d -match '[\\/](adapter|application|domain|infrastructure|start)[\\/]') {
                $Matches[1]
            }
            elseif ($d -match '\.(mdc|json|ps1|md)$') {
                "*." + $Matches[1]
            }
            else {
                $ext = [System.IO.Path]::GetExtension($d)
                if ($ext) { "*$ext" } else { "other" }
            }
        } |
        Group-Object |
        Sort-Object -Property Count -Descending |
        Select-Object -First 5 |
        ForEach-Object { [PSCustomObject]@{ Category = $_.Name; Count = $_.Count } }
}

# ---------- subagent coverage analysis ----------

$expectedAgents = @(
    @{ name = "architect";             stage = "A2" },
    @{ name = "tdd-guide";            stage = "B2" },
    @{ name = "build-error-resolver"; stage = "B3-V1" },
    @{ name = "security-reviewer";    stage = "B3-V4" },
    @{ name = "doc-updater";          stage = "B4" },
    @{ name = "code-reviewer";        stage = "B3" }
)

$agentEvents = @($events | Where-Object {
    $_.type -eq "subagent_invoke" -or
    ($_.detail -and $_.detail -match "agent[=:]\s*\w")
})

$triggeredAgents = @{}
foreach ($ae in $agentEvents) {
    foreach ($ea in $expectedAgents) {
        if ($ae.detail -match $ea.name) {
            $triggeredAgents[$ea.name] = $true
        }
    }
}

$missingAgents = @()
foreach ($ea in $expectedAgents) {
    if (-not $triggeredAgents.ContainsKey($ea.name)) {
        $missingAgents += [PSCustomObject]@{ Agent = $ea.name; Stage = $ea.stage }
    }
}

# ---------- artifact gap analysis ----------

$artifactEvents = @($events | Where-Object { $_.type -eq "artifact_check" })
$artifactGaps = @()
foreach ($ae in $artifactEvents) {
    if ($ae.detail -match "missing artifacts") {
        $artifactGaps += $ae.detail
    }
}

# ---------- output ----------

$startDate = $cutoff.ToString("yyyy-MM-dd")
$endDate   = (Get-Date).ToString("yyyy-MM-dd")

if ($OutputJson) {
    $report = [ordered]@{
        period           = "$startDate ~ $endDate"
        totalEvents      = $totalCount
        edits            = $editCount
        denials          = $denyCount
        asks             = $askCount
        modeChanges      = $modeChanges.Count
        newTasks         = $newTasks.Count
        modeDistribution = $modeDistribution
        topDenied        = $topDenied
        topEdited        = $topEdited
        missingAgents    = $missingAgents
        artifactGaps     = $artifactGaps
    }
    $report | ConvertTo-Json -Depth 5
    exit 0
}

$ciLabel  = [string]([char]0x6B21)                                                 # 次

Write-Host ""
Write-Host "====== Harness Report ($startDate ~ $endDate) ======" -ForegroundColor Cyan
Write-Host ""
Write-Host "  $([char]0x603B)$([char]0x4E8B)$([char]0x4EF6)$([char]0x6570):            $totalCount" -ForegroundColor White
Write-Host "  $([char]0x7F16)$([char]0x8F91)$([char]0x64CD)$([char]0x4F5C):            $editCount" -ForegroundColor White
Write-Host "  $([char]0x62E6)$([char]0x622A)$([char]0x6B21)$([char]0x6570):            $denyCount (deny: $denyCount, ask: $askCount)" -ForegroundColor White
Write-Host "  $([char]0x6A21)$([char]0x5F0F)$([char]0x5207)$([char]0x6362):            $($modeChanges.Count)" -ForegroundColor White
Write-Host "  $([char]0x65B0)$([char]0x4EFB)$([char]0x52A1):              $($newTasks.Count)" -ForegroundColor White

if ($topDenied.Count -gt 0) {
    Write-Host ""
    Write-Host "  Top 5 $([char]0x88AB)$([char]0x62E6)$([char]0x622A)$([char]0x4E8B)$([char]0x4EF6):" -ForegroundColor Yellow
    $rank = 1
    foreach ($d in $topDenied) {
        $detail = if ($d.Detail.Length -gt 60) { $d.Detail.Substring(0, 57) + "..." } else { $d.Detail }
        Write-Host "    $rank. $detail ($($d.Count)$ciLabel)" -ForegroundColor White
        $rank++
    }
}

if ($topEdited.Count -gt 0) {
    Write-Host ""
    Write-Host "  Top 5 $([char]0x7F16)$([char]0x8F91)$([char]0x5206)$([char]0x5E03):" -ForegroundColor Yellow
    $rank = 1
    foreach ($e in $topEdited) {
        Write-Host "    $rank. $($e.Category) ($($e.Count)$ciLabel)" -ForegroundColor White
        $rank++
    }
}

Write-Host ""
Write-Host "  $([char]0x6A21)$([char]0x5F0F)$([char]0x5206)$([char]0x5E03):" -ForegroundColor Yellow
foreach ($key in $modeDistribution.Keys) {
    $pct = [math]::Round($modeDistribution[$key] / $totalCount * 100, 1)
    Write-Host "    $key : $($modeDistribution[$key]) ($pct%)" -ForegroundColor White
}

if ($missingAgents.Count -gt 0) {
    Write-Host ""
    Write-Host "  $([char]0x672A)$([char]0x89E6)$([char]0x53D1)$([char]0x7684)$([char]0x5B50)$([char]0x4EE3)$([char]0x7406):" -ForegroundColor Yellow
    foreach ($ma in $missingAgents) {
        Write-Host "    - $($ma.Agent) ($([char]0x9636)$([char]0x6BB5): $($ma.Stage))" -ForegroundColor White
    }
}

if ($artifactGaps.Count -gt 0) {
    Write-Host ""
    Write-Host "  $([char]0x4EA7)$([char]0x7269)$([char]0x7F3A)$([char]0x5931)$([char]0x8BB0)$([char]0x5F55):" -ForegroundColor Yellow
    $rank = 1
    foreach ($ag in $artifactGaps) {
        $detail = if ($ag.Length -gt 60) { $ag.Substring(0, 57) + "..." } else { $ag }
        Write-Host "    $rank. $detail" -ForegroundColor White
        $rank++
    }
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""
