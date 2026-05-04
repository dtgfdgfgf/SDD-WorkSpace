#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Stage entry gate for /speckit.implement.

.DESCRIPTION
    Confirms that tasks.md contains at least one canonical `- [ ] T### ...`
    checklist line, that the analysis-checklist.md (when present) has no
    unresolved Critical findings, and that validate-feature-structure.ps1
    reports VALID. Optionally accepts a `-Task T###` filter and surfaces the
    next pending tasks for dry-run inspection.

    Hard gate (constitution §2 + §8 + §9): /speckit.implement depends on every
    prior stage and on Critical analyze findings being resolved before
    implementation. Use `-Force` to override the entry gate when investigating
    an inherited feature mid-stage.

.PARAMETER FeatureDir
    Optional override for the feature directory.

.PARAMETER Task
    Optional task ID filter (e.g. T001) to validate before driving a single
    task implementation pass.

.PARAMETER Json
    Emit a single structured JSON object instead of human-readable text.

.PARAMETER Force
    Bypass entry-gate failures (still emits warnings).

.PARAMETER Help
    Show this help message.

.NOTES
    Exit code: 0 ready for implement, 1 entry-gate failure (unless -Force).
#>

[CmdletBinding()]
param(
    [string]$FeatureDir,
    [string]$Task,
    [switch]$Json,
    [switch]$Force,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Output 'Usage: ./setup-implement.ps1 [-FeatureDir <path>] [-Task T###] [-Json] [-Force] [-Help]'
    Write-Output '  -FeatureDir  Override feature directory (defaults to current branch).'
    Write-Output '  -Task        Validate readiness for a specific task ID (e.g. T001).'
    Write-Output '  -Json        Output results as JSON.'
    Write-Output '  -Force       Bypass entry-gate failures (still warns).'
    Write-Output '  -Help        Show this help message.'
    exit 0
}

. "$PSScriptRoot/common.ps1"

function Resolve-FeatureContext {
    param([string]$Override)
    if ($Override) {
        $resolved = Resolve-AbsolutePath -Path $Override
        return [PSCustomObject]@{
            FEATURE_DIR        = $resolved
            FEATURE_SPEC       = Join-Path $resolved 'spec.md'
            IMPL_PLAN          = Join-Path $resolved 'plan.md'
            TASKS              = Join-Path $resolved 'tasks.md'
            ANALYSIS_CHECKLIST = Join-Path $resolved 'analysis-checklist.md'
        }
    }
    $base = Get-FeaturePathsEnv
    return [PSCustomObject]@{
        FEATURE_DIR        = $base.FEATURE_DIR
        FEATURE_SPEC       = $base.FEATURE_SPEC
        IMPL_PLAN          = $base.IMPL_PLAN
        TASKS              = $base.TASKS
        ANALYSIS_CHECKLIST = Join-Path $base.FEATURE_DIR 'analysis-checklist.md'
    }
}

function Invoke-FeatureStructureValidation {
    param([string]$FeatureDir)
    $script = Join-Path $PSScriptRoot 'validate-feature-structure.ps1'
    if (-not (Test-Path -LiteralPath $script -PathType Leaf)) { return $null }
    $raw = & $script -FeatureDir $FeatureDir -Json 2>$null
    if (-not $raw) { return $null }
    try { return ($raw | ConvertFrom-Json) } catch { return $null }
}

function Get-PendingTasks {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return @() }
    $content = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrEmpty($content)) { return @() }
    $rxMatches = [regex]::Matches($content, '(?m)^- \[\s\]\s+(T\d{3})\b.*$')
    return @($rxMatches | ForEach-Object { @{ Id = $_.Groups[1].Value; Line = $_.Value.Trim() } })
}

function Get-UnresolvedCriticalFindings {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return @() }
    $content = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrEmpty($content)) { return @() }
    $rxMatches = [regex]::Matches($content, '(?m)^\|\s*([A-Z0-9-]+)\s*\|\s*Critical\s*\|([^|]+)\|\s*([^|]*)\|')
    $unresolved = @()
    foreach ($m in $rxMatches) {
        $resolution = $m.Groups[3].Value.Trim()
        if ([string]::IsNullOrWhiteSpace($resolution) -or $resolution -match '^\s*(?:TBD|TODO)\s*$') {
            $unresolved += @{ Id = $m.Groups[1].Value.Trim(); Finding = $m.Groups[2].Value.Trim() }
        }
    }
    return $unresolved
}

$paths = Resolve-FeatureContext -Override $FeatureDir
$blockers = New-Object System.Collections.Generic.List[string]
$messages = New-Object System.Collections.Generic.List[string]

$required = @(
    @{ Path = $paths.FEATURE_SPEC; Name = 'spec.md'; Stage = '/speckit.specify' }
    @{ Path = $paths.IMPL_PLAN;    Name = 'plan.md'; Stage = '/speckit.plan' }
    @{ Path = $paths.TASKS;        Name = 'tasks.md'; Stage = '/speckit.tasks' }
)
foreach ($req in $required) {
    if (-not (Test-Path -LiteralPath $req.Path -PathType Leaf)) {
        $blockers.Add("$($req.Name) is required before /speckit.implement. Complete $($req.Stage) first: $($req.Path)") | Out-Null
    }
}

$pendingTasks = Get-PendingTasks -Path $paths.TASKS
if ($pendingTasks.Count -eq 0 -and (Test-Path -LiteralPath $paths.TASKS -PathType Leaf)) {
    $blockers.Add('tasks.md has no pending canonical "- [ ] T### ..." lines. Either run /speckit.tasks or mark tasks pending again.') | Out-Null
}

$selectedTask = $null
if ($Task) {
    $selectedTask = $pendingTasks | Where-Object { $_.Id -eq $Task } | Select-Object -First 1
    if (-not $selectedTask) {
        $blockers.Add("Task $Task is not pending in tasks.md. Available pending IDs: $((@($pendingTasks | ForEach-Object { $_.Id }) -join ', '))") | Out-Null
    }
}

$criticalFindings = Get-UnresolvedCriticalFindings -Path $paths.ANALYSIS_CHECKLIST
if ($criticalFindings.Count -gt 0) {
    foreach ($cf in $criticalFindings) {
        $blockers.Add("analysis-checklist.md has unresolved Critical finding [$($cf.Id)]: $($cf.Finding)") | Out-Null
    }
}

$validation = $null
if ((Test-Path -LiteralPath $paths.FEATURE_DIR -PathType Container)) {
    $validation = Invoke-FeatureStructureValidation -FeatureDir $paths.FEATURE_DIR
    if ($validation -and -not $validation.VALID) {
        foreach ($err in $validation.ERRORS) {
            $blockers.Add("validate-feature-structure: [$($err.id)] $($err.message)") | Out-Null
        }
    }
    if ($validation -and $validation.WARNING_COUNT -gt 0) {
        foreach ($w in $validation.WARNINGS) {
            $messages.Add("validate-feature-structure warning: [$($w.id)] $($w.message)") | Out-Null
        }
    }
}

$ready = ($blockers.Count -eq 0) -or $Force.IsPresent

$stage = 'implement'
$result = [ordered]@{
    STAGE              = $stage
    READY              = $ready
    FORCED             = $Force.IsPresent
    FEATURE_DIR        = $paths.FEATURE_DIR
    IMPL_PLAN          = $paths.IMPL_PLAN
    TASKS              = $paths.TASKS
    ANALYSIS_CHECKLIST = $paths.ANALYSIS_CHECKLIST
    PENDING_TASKS      = @($pendingTasks)
    SELECTED_TASK      = $selectedTask
    UNRESOLVED_CRITICAL = @($criticalFindings)
    STRUCTURE_VALID    = if ($validation) { $validation.VALID } else { $null }
    BLOCKERS           = @($blockers)
    MESSAGES           = @($messages)
}

if ($Json) {
    [PSCustomObject]$result | ConvertTo-Json -Depth 6 -Compress
} else {
    Write-Output ("STAGE: {0}" -f $stage)
    Write-Output ("READY: {0}" -f $ready)
    Write-Output ("FEATURE_DIR: {0}" -f $paths.FEATURE_DIR)
    Write-Output ("PENDING_TASKS: {0}" -f $pendingTasks.Count)
    foreach ($t in $pendingTasks) { Write-Output ("  - {0}: {1}" -f $t.Id, $t.Line) }
    if ($selectedTask) { Write-Output ("SELECTED_TASK: {0}" -f $selectedTask.Id) }
    if ($validation) { Write-Output ("STRUCTURE_VALID: {0}" -f $validation.VALID) }
    foreach ($b in $blockers) { Write-Output "[BLOCKER] $b" }
    foreach ($n in $messages) { Write-Output "[NOTE] $n" }
    if ($Force -and $blockers.Count) {
        Write-Output '[FORCED] Entry gate bypassed by -Force.'
    }
}

if (-not $ready) { exit 1 } else { exit 0 }
