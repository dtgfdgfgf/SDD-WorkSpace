#!/usr/bin/env pwsh

#Requires -Version 7.0
<#
.SYNOPSIS
    Stage entry gate for /speckit.analyze.

.DESCRIPTION
    Confirms that the canonical artifact set for analyze is complete: spec.md,
    readiness/readiness-assessment.md, plan.md, and tasks.md must all exist.
    Delegates structural validation to validate-feature-structure.ps1 and
    identifies the canonical analysis-result.json target and schema consumed
    by setup-implement.ps1. analysis-checklist.md is scaffolded only as an
    optional human review surface; it is not implementation authorization.
    The machine result carries the required Intent Drift Check and intent
    obligation disposition.

    Hard gate (constitution §2 + §8): /speckit.analyze depends on every prior
    stage. Use `-Force` to override the entry gate when investigating an
    inherited feature mid-stage.

.PARAMETER FeatureDir
    Optional override for the feature directory.

.PARAMETER Json
    Emit a single structured JSON object instead of human-readable text.

.PARAMETER Force
    Bypass entry-gate failures (still emits warnings).

.PARAMETER Help
    Show this help message.

.NOTES
    Exit code: 0 ready to analyze, 1 entry-gate failure (unless -Force).
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
    Write-Output 'Usage: ./setup-analyze.ps1 [-FeatureDir <path>] [-Json] [-Force] [-Help]'
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
        $readinessDir = Join-Path $resolved 'readiness'
        return [PSCustomObject]@{
            FEATURE_DIR          = $resolved
            FEATURE_SPEC         = Join-Path $resolved 'spec.md'
            READINESS_ASSESSMENT = Join-Path $readinessDir 'readiness-assessment.md'
            IMPL_PLAN            = Join-Path $resolved 'plan.md'
            TASKS                = Join-Path $resolved 'tasks.md'
        }
    }
    return Get-FeaturePathsEnv
}

function Invoke-FeatureStructureValidation {
    param([string]$FeatureDir)
    $script = Join-Path $PSScriptRoot 'validate-feature-structure.ps1'
    if (-not (Test-Path -LiteralPath $script -PathType Leaf)) { return $null }
    $raw = & $script -FeatureDir $FeatureDir -Json 2>$null
    if (-not $raw) { return $null }
    try { return ($raw | ConvertFrom-Json) } catch { return $null }
}

$paths = Resolve-FeatureContext -Override $FeatureDir

# Path boundary defense: -FeatureDir override or SPECIFY_FEATURE env var could be tampered to escape the project.
$projectRootForBoundary = if ($FeatureDir) {
    $specsParent = Split-Path -Parent $paths.FEATURE_DIR
    if ((Split-Path -Leaf $specsParent) -ne 'specs') {
        throw "FEATURE_DIR escapes project root: $($paths.FEATURE_DIR) must be located at <project>/specs/<feature>"
    }
    Split-Path -Parent $specsParent
} else {
    Get-RepoRoot
}
if (-not $projectRootForBoundary) { throw 'Unable to resolve project root for path boundary check.' }
Assert-PathInsideRoot -Root $projectRootForBoundary -Candidate $paths.FEATURE_DIR -MessagePrefix 'FEATURE_DIR escapes project root'

$blockers = New-Object System.Collections.Generic.List[string]
$messages = New-Object System.Collections.Generic.List[string]

$required = @(
    @{ Path = $paths.FEATURE_SPEC;         Name = 'spec.md';                          Stage = '/speckit.specify' }
    @{ Path = $paths.READINESS_ASSESSMENT; Name = 'readiness/readiness-assessment.md'; Stage = '/speckit.readiness' }
    @{ Path = $paths.IMPL_PLAN;            Name = 'plan.md';                          Stage = '/speckit.plan' }
    @{ Path = $paths.TASKS;                Name = 'tasks.md';                         Stage = '/speckit.tasks' }
)
foreach ($req in $required) {
    if (-not (Test-Path -LiteralPath $req.Path -PathType Leaf)) {
        $blockers.Add("$($req.Name) is required before /speckit.analyze. Complete $($req.Stage) first: $($req.Path)") | Out-Null
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

$studioRoot = Find-StudioRoot -StartDir $paths.FEATURE_DIR
$template = $null
if ($studioRoot) {
    $candidate = Join-Path $studioRoot 'templates/sdd-docs/checklist-template.md'
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { $template = $candidate }
}

$checklistPath = Join-Path $paths.FEATURE_DIR 'analysis-checklist.md'
$analysisResultPath = Join-Path $paths.FEATURE_DIR 'analysis-result.json'
$trustedStudioRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$analysisResultSchema = Join-Path $trustedStudioRoot 'runtime/analysis-result.schema.json'
$scaffolded = $false
$checklistExists = Test-Path -LiteralPath $checklistPath -PathType Leaf
if ($ready) {
    if (-not (Test-Path -LiteralPath $paths.FEATURE_DIR -PathType Container)) {
        New-Item -ItemType Directory -Path $paths.FEATURE_DIR -Force | Out-Null
    }
    if ($checklistExists) {
        $messages.Add('analysis-checklist.md already exists; left untouched.') | Out-Null
    } elseif ($template) {
        Copy-Item -LiteralPath $template -Destination $checklistPath -Force
        $scaffolded = $true
        $messages.Add("Scaffolded analysis-checklist.md from $template.") | Out-Null
    } else {
        New-Item -ItemType File -Path $checklistPath -Force | Out-Null
        $scaffolded = $true
        $messages.Add('checklist-template.md not found; created empty file.') | Out-Null
    }
    $messages.Add('analysis-checklist.md is informational only. Emit the exact analysis-result.json payload required by the canonical schema; the Analyze agent remains read-only and does not persist it.') | Out-Null
}

$stage = 'analyze'
$result = [ordered]@{
    STAGE                = $stage
    READY                = $ready
    FORCED               = $Force.IsPresent
    FEATURE_DIR          = $paths.FEATURE_DIR
    FEATURE_SPEC         = $paths.FEATURE_SPEC
    READINESS_ASSESSMENT = $paths.READINESS_ASSESSMENT
    IMPL_PLAN            = $paths.IMPL_PLAN
    TASKS                = $paths.TASKS
    ANALYSIS_RESULT      = $analysisResultPath
    ANALYSIS_RESULT_SCHEMA = $analysisResultSchema
    ANALYSIS_CHECKLIST   = $checklistPath
    SCAFFOLDED           = $scaffolded
    STRUCTURE_VALID      = if ($validation) { $validation.VALID } else { $null }
    BLOCKERS             = @($blockers)
    MESSAGES             = @($messages)
}

if ($Json) {
    [PSCustomObject]$result | ConvertTo-Json -Depth 6 -Compress
} else {
    Write-Output ("STAGE: {0}" -f $stage)
    Write-Output ("READY: {0}" -f $ready)
    Write-Output ("FEATURE_DIR: {0}" -f $paths.FEATURE_DIR)
    Write-Output ("ANALYSIS_RESULT: {0}" -f $analysisResultPath)
    Write-Output ("ANALYSIS_RESULT_SCHEMA: {0}" -f $analysisResultSchema)
    Write-Output ("ANALYSIS_CHECKLIST: {0}" -f $checklistPath)
    Write-Output ("SCAFFOLDED: {0}" -f $scaffolded)
    if ($validation) {
        Write-Output ("STRUCTURE_VALID: {0}" -f $validation.VALID)
    }
    foreach ($b in $blockers) { Write-Output "[BLOCKER] $b" }
    foreach ($n in $messages) { Write-Output "[NOTE] $n" }
    if ($Force -and $blockers.Count) {
        Write-Output '[FORCED] Entry gate bypassed by -Force.'
    }
}

if (-not $ready) { exit 1 } else { exit 0 }
