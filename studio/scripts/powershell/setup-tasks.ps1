#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Stage entry gate for /speckit.tasks.

.DESCRIPTION
    Confirms that plan.md exists and declares a Version field, then scaffolds
    tasks.md from studio/templates/sdd-docs/tasks-template.md when not present.

    Hard gate (constitution §2 + §6): /speckit.tasks MAY NOT begin until the
    plan stage has produced a versioned plan.md. Use `-Force` to override the
    entry gate when investigating an inherited feature mid-stage.

.PARAMETER FeatureDir
    Optional override for the feature directory.

.PARAMETER Json
    Emit a single structured JSON object instead of human-readable text.

.PARAMETER Force
    Bypass entry-gate failures (still emits warnings).

.PARAMETER Help
    Show this help message.

.NOTES
    Exit code: 0 tasks scaffolded, 1 entry-gate failure (unless -Force).
#>

[CmdletBinding()]
param(
    [string]$FeatureDir,
    [switch]$Json,
    [switch]$Force,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Output 'Usage: ./setup-tasks.ps1 [-FeatureDir <path>] [-Json] [-Force] [-Help]'
    Write-Output '  -FeatureDir  Override feature directory (defaults to current branch).'
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
            FEATURE_DIR  = $resolved
            FEATURE_SPEC = Join-Path $resolved 'spec.md'
            IMPL_PLAN    = Join-Path $resolved 'plan.md'
            TASKS        = Join-Path $resolved 'tasks.md'
        }
    }
    return Get-FeaturePathsEnv
}

$paths = Resolve-FeatureContext -Override $FeatureDir
$blockers = New-Object System.Collections.Generic.List[string]
$messages = New-Object System.Collections.Generic.List[string]

if (-not (Test-Path -LiteralPath $paths.FEATURE_SPEC -PathType Leaf)) {
    $blockers.Add("spec.md is required before /speckit.tasks. Run /speckit.specify first: $($paths.FEATURE_SPEC)") | Out-Null
}
if (-not (Test-Path -LiteralPath $paths.IMPL_PLAN -PathType Leaf)) {
    $blockers.Add("plan.md is required before /speckit.tasks. Run /speckit.plan first: $($paths.IMPL_PLAN)") | Out-Null
}

$planVersion = $null
if (Test-Path -LiteralPath $paths.IMPL_PLAN -PathType Leaf) {
    $planVersion = Get-MarkdownField -Path $paths.IMPL_PLAN -Field 'Version'
    if (-not $planVersion) {
        $blockers.Add('plan.md has no Version field; tasks MAY NOT begin until the plan is finalized.') | Out-Null
    }
}

$ready = ($blockers.Count -eq 0) -or $Force.IsPresent

$studioRoot = Find-StudioRoot -StartDir $paths.FEATURE_DIR
$template = $null
if ($studioRoot) {
    $candidate = Join-Path $studioRoot 'templates/sdd-docs/tasks-template.md'
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { $template = $candidate }
}

$scaffolded = $false
$tasksExists = Test-Path -LiteralPath $paths.TASKS -PathType Leaf
if ($ready) {
    if (-not (Test-Path -LiteralPath $paths.FEATURE_DIR -PathType Container)) {
        New-Item -ItemType Directory -Path $paths.FEATURE_DIR -Force | Out-Null
    }
    if ($tasksExists) {
        $messages.Add('tasks.md already exists; left untouched.') | Out-Null
    } elseif ($template) {
        Copy-Item -LiteralPath $template -Destination $paths.TASKS -Force
        $scaffolded = $true
        $messages.Add("Scaffolded tasks.md from $template.") | Out-Null
    } else {
        New-Item -ItemType File -Path $paths.TASKS -Force | Out-Null
        $scaffolded = $true
        $messages.Add('tasks-template.md not found; created empty file.') | Out-Null
    }
}

$stage = 'tasks'
$result = [ordered]@{
    STAGE        = $stage
    READY        = $ready
    FORCED       = $Force.IsPresent
    FEATURE_DIR  = $paths.FEATURE_DIR
    FEATURE_SPEC = $paths.FEATURE_SPEC
    IMPL_PLAN    = $paths.IMPL_PLAN
    PLAN_VERSION = $planVersion
    TASKS        = $paths.TASKS
    SCAFFOLDED   = $scaffolded
    BLOCKERS     = @($blockers)
    MESSAGES     = @($messages)
}

if ($Json) {
    [PSCustomObject]$result | ConvertTo-Json -Depth 5 -Compress
} else {
    Write-Output ("STAGE: {0}" -f $stage)
    Write-Output ("READY: {0}" -f $ready)
    Write-Output ("FEATURE_DIR: {0}" -f $paths.FEATURE_DIR)
    Write-Output ("IMPL_PLAN: {0}" -f $paths.IMPL_PLAN)
    Write-Output ("PLAN_VERSION: {0}" -f $planVersion)
    Write-Output ("TASKS: {0}" -f $paths.TASKS)
    Write-Output ("SCAFFOLDED: {0}" -f $scaffolded)
    foreach ($b in $blockers) { Write-Output "[BLOCKER] $b" }
    foreach ($n in $messages) { Write-Output "[NOTE] $n" }
    if ($Force -and $blockers.Count) {
        Write-Output '[FORCED] Entry gate bypassed by -Force.'
    }
}

if (-not $ready) { exit 1 } else { exit 0 }
