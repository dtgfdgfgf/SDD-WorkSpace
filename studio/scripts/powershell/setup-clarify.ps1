#!/usr/bin/env pwsh

#Requires -Version 7.0
<#
.SYNOPSIS
    Stage entry gate for /speckit.clarify.

.DESCRIPTION
    Confirms that spec.md exists for the current feature, then enumerates any
    `[NEEDS CLARIFICATION: ...]` markers found in it so the agent can drive the
    clarification round. This script does not scaffold a new artifact; clarify
    work edits spec.md in place.

    Hard gate (constitution §2): /speckit.clarify is the second mandatory stage
    and depends only on spec.md from /speckit.specify. Use `-Force` to override
    the entry gate when investigating an inherited feature mid-stage.

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
    Exit code: 0 ready for clarify, 1 entry-gate failure (unless -Force).
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
    Write-Output 'Usage: ./setup-clarify.ps1 [-FeatureDir <path>] [-Json] [-Force] [-Help]'
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
        }
    }
    return Get-FeaturePathsEnv
}

function Get-NeedsClarificationMarkers {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return @() }
    $content = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($content)) { return @() }
    $rxMatches = [regex]::Matches($content, '\[NEEDS CLARIFICATION:[^\]]*\]')
    return @($rxMatches | ForEach-Object { $_.Value })
}

$paths = Resolve-FeatureContext -Override $FeatureDir
$messages = New-Object System.Collections.Generic.List[string]
$blockers = New-Object System.Collections.Generic.List[string]

if (-not (Test-Path -LiteralPath $paths.FEATURE_SPEC -PathType Leaf)) {
    $blockers.Add("spec.md is required before /speckit.clarify. Run /speckit.specify first: $($paths.FEATURE_SPEC)") | Out-Null
}

$specVersion = $null
if (-not $blockers.Count) {
    $specVersion = Get-MarkdownField -Path $paths.FEATURE_SPEC -Field 'Version'
    if (-not $specVersion) {
        $messages.Add("spec.md has no Version field; clarify MAY proceed but specify stage was incomplete.") | Out-Null
    }
}

$markers = Get-NeedsClarificationMarkers -Path $paths.FEATURE_SPEC
if ($markers.Count -eq 0 -and -not $blockers.Count) {
    $messages.Add('spec.md contains no [NEEDS CLARIFICATION] markers. Clarify MAY still uncover implicit ambiguities.') | Out-Null
}

$ready = ($blockers.Count -eq 0) -or $Force.IsPresent

$stage = 'clarify'
$result = [ordered]@{
    STAGE             = $stage
    READY             = $ready
    FORCED            = $Force.IsPresent
    FEATURE_DIR       = $paths.FEATURE_DIR
    FEATURE_SPEC      = $paths.FEATURE_SPEC
    SPEC_VERSION      = $specVersion
    CLARIFICATION_MARKERS = @($markers)
    BLOCKERS          = @($blockers)
    MESSAGES          = @($messages)
}

if ($Json) {
    [PSCustomObject]$result | ConvertTo-Json -Depth 5 -Compress
} else {
    Write-Output ("STAGE: {0}" -f $stage)
    Write-Output ("READY: {0}" -f $ready)
    Write-Output ("FEATURE_DIR: {0}" -f $paths.FEATURE_DIR)
    Write-Output ("FEATURE_SPEC: {0}" -f $paths.FEATURE_SPEC)
    Write-Output ("SPEC_VERSION: {0}" -f $specVersion)
    Write-Output ("CLARIFICATION_MARKERS: {0}" -f $markers.Count)
    foreach ($m in $markers) { Write-Output "  - $m" }
    foreach ($b in $blockers) { Write-Output "[BLOCKER] $b" }
    foreach ($n in $messages) { Write-Output "[NOTE] $n" }
    if ($Force -and $blockers.Count) {
        Write-Output '[FORCED] Entry gate bypassed by -Force.'
    }
}

if (-not $ready) { exit 1 } else { exit 0 }
