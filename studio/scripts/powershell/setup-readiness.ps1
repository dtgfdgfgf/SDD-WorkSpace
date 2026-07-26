#!/usr/bin/env pwsh

#Requires -Version 7.0
<#
.SYNOPSIS
    Stage entry gate for /speckit.readiness.

.DESCRIPTION
    Confirms that /speckit.clarify has resolved every `[NEEDS CLARIFICATION]`
    marker in spec.md, then scaffolds readiness/readiness-assessment.md from
    studio/templates/sdd-docs/readiness-assessment-template.md and creates the
    readiness/eci/ subdirectory so any subsequent ROUTE_TO_ECI workflow has a
    stable home.

    Hard gate (constitution §2 + §4): /speckit.readiness MAY NOT begin while
    clarify-stage `[NEEDS CLARIFICATION]` markers remain unless `-Force` is
    supplied.

.PARAMETER FeatureDir
    Optional override for the feature directory. Defaults to the feature
    directory derived from the current branch via Get-FeaturePathsEnv.

.PARAMETER Json
    Emit a single structured JSON object instead of human-readable text.

.PARAMETER Force
    Bypass entry-gate failures (still emits warnings).

.PARAMETER Help
    Show this help message.

.NOTES
    Exit code: 0 readiness scaffolded, 1 entry-gate failure (unless -Force).
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
    Write-Output 'Usage: ./setup-readiness.ps1 [-FeatureDir <path>] [-Json] [-Force] [-Help]'
    Write-Output '  -FeatureDir  Override feature directory (defaults to current branch).'
    Write-Output '  -Json        Output results as JSON.'
    Write-Output '  -Force       Bypass entry-gate failures (still warns).'
    Write-Output '  -Help        Show this help message.'
    exit 0
}

. "$PSScriptRoot/common.ps1"

function Get-NeedsClarificationMarkers {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return @() }
    $content = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($content)) { return @() }
    $rxMatches = [regex]::Matches($content, '\[NEEDS CLARIFICATION:[^\]]*\]')
    return @($rxMatches | ForEach-Object { $_.Value })
}

$paths = Resolve-FeatureContext -FeatureDir $FeatureDir
Assert-PathInsideRoot -Root $paths.REPO_ROOT -Candidate $paths.FEATURE_DIR -MessagePrefix 'FEATURE_DIR escapes project root'
Assert-PathInsideRoot -Root $paths.REPO_ROOT -Candidate $paths.READINESS_DIR -MessagePrefix 'READINESS_DIR escapes project root'
Assert-PathInsideRoot -Root $paths.REPO_ROOT -Candidate $paths.READINESS_ASSESSMENT -MessagePrefix 'READINESS_ASSESSMENT escapes project root'
Assert-PathInsideRoot -Root $paths.REPO_ROOT -Candidate $paths.ECI_DIR -MessagePrefix 'ECI_DIR escapes project root'

$blockers = New-Object System.Collections.Generic.List[string]
$messages = New-Object System.Collections.Generic.List[string]

if (-not (Test-Path -LiteralPath $paths.FEATURE_SPEC -PathType Leaf)) {
    $blockers.Add("spec.md is required before /speckit.readiness. Run /speckit.specify first: $($paths.FEATURE_SPEC)") | Out-Null
}

$markers = @()
if (-not $blockers.Count) {
    $markers = Get-NeedsClarificationMarkers -Path $paths.FEATURE_SPEC
    if ($markers.Count -gt 0) {
        $blockers.Add("spec.md still has $($markers.Count) [NEEDS CLARIFICATION] marker(s). Run /speckit.clarify before readiness.") | Out-Null
    }
}

$ready = ($blockers.Count -eq 0) -or $Force.IsPresent

$studioRoot = Find-StudioRoot -StartDir $paths.FEATURE_DIR
$template = $null
if ($studioRoot) {
    $candidate = Join-Path $studioRoot 'templates/sdd-docs/readiness-assessment-template.md'
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { $template = $candidate }
}

$scaffolded = $false
$assessmentExists = Test-Path -LiteralPath $paths.READINESS_ASSESSMENT -PathType Leaf
if ($ready) {
    if (-not (Test-Path -LiteralPath $paths.READINESS_DIR -PathType Container)) {
        New-Item -ItemType Directory -Path $paths.READINESS_DIR -Force | Out-Null
    }
    if (-not (Test-Path -LiteralPath $paths.ECI_DIR -PathType Container)) {
        New-Item -ItemType Directory -Path $paths.ECI_DIR -Force | Out-Null
    }
    if ($assessmentExists) {
        $messages.Add("readiness-assessment.md already exists; left untouched.") | Out-Null
    } elseif ($template) {
        Copy-Item -LiteralPath $template -Destination $paths.READINESS_ASSESSMENT -Force
        $scaffolded = $true
        $messages.Add("Scaffolded readiness-assessment.md from $template.") | Out-Null
    } else {
        New-Item -ItemType File -Path $paths.READINESS_ASSESSMENT -Force | Out-Null
        $scaffolded = $true
        $messages.Add('readiness-assessment-template.md not found; created empty file.') | Out-Null
    }
}

$stage = 'readiness'
$result = [ordered]@{
    STAGE                = $stage
    READY                = $ready
    FORCED               = $Force.IsPresent
    FEATURE_DIR          = $paths.FEATURE_DIR
    FEATURE_SPEC         = $paths.FEATURE_SPEC
    READINESS_DIR        = $paths.READINESS_DIR
    READINESS_ASSESSMENT = $paths.READINESS_ASSESSMENT
    ECI_DIR              = $paths.ECI_DIR
    SCAFFOLDED           = $scaffolded
    CLARIFICATION_MARKERS = @($markers)
    BLOCKERS             = @($blockers)
    MESSAGES             = @($messages)
}

if ($Json) {
    [PSCustomObject]$result | ConvertTo-Json -Depth 5 -Compress
} else {
    Write-Output ("STAGE: {0}" -f $stage)
    Write-Output ("READY: {0}" -f $ready)
    Write-Output ("FEATURE_DIR: {0}" -f $paths.FEATURE_DIR)
    Write-Output ("READINESS_ASSESSMENT: {0}" -f $paths.READINESS_ASSESSMENT)
    Write-Output ("ECI_DIR: {0}" -f $paths.ECI_DIR)
    Write-Output ("SCAFFOLDED: {0}" -f $scaffolded)
    foreach ($b in $blockers) { Write-Output "[BLOCKER] $b" }
    foreach ($n in $messages) { Write-Output "[NOTE] $n" }
    if ($Force -and $blockers.Count) {
        Write-Output '[FORCED] Entry gate bypassed by -Force.'
    }
}

if (-not $ready) { exit 1 } else { exit 0 }
