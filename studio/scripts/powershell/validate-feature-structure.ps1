#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Validate that a feature directory under specs/<feature>/ conforms to the
    structural requirements listed in studio/constitution/constitution.md §11.

.DESCRIPTION
    The validator inspects the canonical SDD artifact set and emits structured
    findings without prescribing the seven-stage order itself (the agents own
    that). It is meant to be invoked manually, by /speckit.analyze, or as a
    per-project advisory pass inside check-speckit-runtime.ps1.

    Validation rules:
    - spec.md MUST exist and MUST contain a Version field.
    - readiness/readiness-assessment.md MUST exist whenever any readiness
      artifact is present (readiness directory must not be partial).
    - When readiness Primary Status is `ROUTE_TO_ECI`, the readiness/eci/
      dossier files (eci-assessment, source-manifest, adoption-record,
      authorization-record) MUST exist.
    - When readiness Intent Ledger Requirement asks for create/update,
      intent-ledger.md MUST exist and contain at least one row.
    - plan.md, tasks.md, research.md, data-model.md, quickstart.md are
      OPTIONAL and only checked for shape when they exist.

.PARAMETER FeatureDir
    Absolute or relative path to the feature directory (typically
    specs/<feature> inside a project root).

.PARAMETER Json
    Emit a single structured JSON object instead of human-readable text.

.PARAMETER WarningsAsErrors
    Promote any WARNING findings to ERRORs (useful for CI gates).

.EXAMPLE
    pwsh ./validate-feature-structure.ps1 -FeatureDir specs/001-feature -Json

.NOTES
    Exit code: 0 on VALID (or VALID-with-warnings unless -WarningsAsErrors), 1 on ERRORS.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$FeatureDir,

    [switch]$Json,

    [switch]$WarningsAsErrors,

    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Output 'Usage: ./validate-feature-structure.ps1 -FeatureDir <path> [-Json] [-WarningsAsErrors]'
    exit 0
}

. "$PSScriptRoot/common.ps1"

function New-Finding {
    param(
        [Parameter(Mandatory = $true)][ValidateSet('error', 'warning', 'info')][string]$Severity,
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$Message,
        [string]$Path
    )

    [ordered]@{
        severity = $Severity
        id       = $Id
        message  = $Message
        path     = $Path
    }
}

$resolvedFeatureDir = Resolve-AbsolutePath -Path $FeatureDir
$findings = @()

if (-not (Test-Path -LiteralPath $resolvedFeatureDir -PathType Container)) {
    $findings += New-Finding -Severity 'error' -Id 'feature-dir-missing' `
        -Message "Feature directory not found: $resolvedFeatureDir"
    if ($Json) {
        [PSCustomObject]@{ VALID = $false; FEATURE_DIR = $resolvedFeatureDir; ERRORS = @($findings); WARNINGS = @() } | ConvertTo-Json -Depth 6
    } else {
        Write-Output "[ERROR] $($findings[0].message)"
    }
    exit 1
}

# spec.md (required)
$specPath = Join-Path $resolvedFeatureDir 'spec.md'
if (-not (Test-Path -LiteralPath $specPath -PathType Leaf)) {
    $findings += New-Finding -Severity 'error' -Id 'spec-missing' `
        -Message 'spec.md is required for every feature.' -Path $specPath
} else {
    $specVersion = Get-MarkdownField -Path $specPath -Field 'Version'
    if (-not $specVersion) {
        $findings += New-Finding -Severity 'warning' -Id 'spec-version-missing' `
            -Message 'spec.md should declare a Version field.' -Path $specPath
    }
}

# readiness/readiness-assessment.md (required if any readiness artifact exists)
$readinessDir = Join-Path $resolvedFeatureDir 'readiness'
$readinessAssessmentPath = Join-Path $readinessDir 'readiness-assessment.md'
$readinessExists = Test-Path -LiteralPath $readinessDir -PathType Container

if ($readinessExists) {
    if (-not (Test-Path -LiteralPath $readinessAssessmentPath -PathType Leaf)) {
        $findings += New-Finding -Severity 'error' -Id 'readiness-assessment-missing' `
            -Message 'readiness/ exists but readiness-assessment.md is missing.' -Path $readinessAssessmentPath
    } else {
        $readinessContent = Get-Content -LiteralPath $readinessAssessmentPath -Raw
        $primaryStatus = Get-MarkdownField -Content $readinessContent -Field 'Primary Status'
        $ledgerRequirement = Get-MarkdownField -Content $readinessContent -Field 'Intent Ledger Requirement'

        if (-not $primaryStatus) {
            $findings += New-Finding -Severity 'error' -Id 'readiness-primary-status-missing' `
                -Message 'readiness-assessment.md must declare a Primary Status.' -Path $readinessAssessmentPath
        }

        if ($primaryStatus -eq 'ROUTE_TO_ECI') {
            $eciDir = Join-Path $readinessDir 'eci'
            $eciRequired = @('eci-assessment.md', 'source-manifest.md', 'adoption-record.md', 'authorization-record.md')
            foreach ($name in $eciRequired) {
                $eciPath = Join-Path $eciDir $name
                if (-not (Test-Path -LiteralPath $eciPath -PathType Leaf)) {
                    $findings += New-Finding -Severity 'error' -Id "eci-missing-$($name -replace '\.md$','')" `
                        -Message "ROUTE_TO_ECI requires readiness/eci/$name." -Path $eciPath
                }
            }
        }

        $intentLedgerPath = Join-Path $resolvedFeatureDir 'intent-ledger.md'
        if ($ledgerRequirement -match 'Create\s+`?intent-ledger\.md`?|Update\s+`?intent-ledger\.md`?') {
            if (-not (Test-Path -LiteralPath $intentLedgerPath -PathType Leaf)) {
                $findings += New-Finding -Severity 'error' -Id 'intent-ledger-missing' `
                    -Message 'Readiness requires intent-ledger.md, but it is missing.' -Path $intentLedgerPath
            } else {
                $ledgerContent = Get-Content -LiteralPath $intentLedgerPath -Raw
                if (-not ($ledgerContent -match '\|.+\|.+\|')) {
                    $findings += New-Finding -Severity 'warning' -Id 'intent-ledger-empty' `
                        -Message 'intent-ledger.md exists but appears to have no rows.' -Path $intentLedgerPath
                }
            }
        }
    }
} else {
    $intentLedgerPath = Join-Path $resolvedFeatureDir 'intent-ledger.md'
    if (Test-Path -LiteralPath $intentLedgerPath) {
        $findings += New-Finding -Severity 'warning' -Id 'intent-ledger-without-readiness' `
            -Message 'intent-ledger.md exists but readiness/ has not been initiated.' -Path $intentLedgerPath
    }
}

# plan.md, tasks.md (optional but checked for emptiness if present)
$optionalArtifacts = @(
    @{ Path = (Join-Path $resolvedFeatureDir 'plan.md');      Id = 'plan-empty';     Description = 'plan.md' }
    @{ Path = (Join-Path $resolvedFeatureDir 'tasks.md');     Id = 'tasks-empty';    Description = 'tasks.md' }
    @{ Path = (Join-Path $resolvedFeatureDir 'research.md');  Id = 'research-empty'; Description = 'research.md' }
    @{ Path = (Join-Path $resolvedFeatureDir 'data-model.md');Id = 'data-empty';     Description = 'data-model.md' }
    @{ Path = (Join-Path $resolvedFeatureDir 'quickstart.md');Id = 'quickstart-empty';Description = 'quickstart.md' }
)
foreach ($entry in $optionalArtifacts) {
    if (Test-Path -LiteralPath $entry.Path -PathType Leaf) {
        $size = (Get-Item -LiteralPath $entry.Path).Length
        if ($size -lt 32) {
            $findings += New-Finding -Severity 'warning' -Id $entry.Id `
                -Message "$($entry.Description) is present but smaller than 32 bytes (likely empty stub)." -Path $entry.Path
        }
    }
}

# tasks.md — when present, must contain at least one canonical checklist line
$tasksPath = Join-Path $resolvedFeatureDir 'tasks.md'
if (Test-Path -LiteralPath $tasksPath -PathType Leaf) {
    $tasksContent = Get-Content -LiteralPath $tasksPath -Raw
    if (-not ($tasksContent -match '(?m)^- \[\s\]\s+T\d{3}\b')) {
        $findings += New-Finding -Severity 'warning' -Id 'tasks-no-canonical-line' `
            -Message 'tasks.md does not contain any canonical "- [ ] T### ..." checklist lines.' -Path $tasksPath
    }
}

if ($WarningsAsErrors) {
    $findings = $findings | ForEach-Object {
        if ($_.severity -eq 'warning') {
            $_.severity = 'error'
        }
        $_
    }
}

$errors   = @($findings | Where-Object { $_.severity -eq 'error' })
$warnings = @($findings | Where-Object { $_.severity -eq 'warning' })
$valid    = $errors.Count -eq 0

$result = [ordered]@{
    VALID         = $valid
    FEATURE_DIR   = $resolvedFeatureDir
    ERROR_COUNT   = $errors.Count
    WARNING_COUNT = $warnings.Count
    ERRORS        = $errors
    WARNINGS      = $warnings
}

if ($Json) {
    [PSCustomObject]$result | ConvertTo-Json -Depth 6
} else {
    Write-Output ("VALID: {0}" -f $valid)
    Write-Output ("FEATURE_DIR: {0}" -f $resolvedFeatureDir)
    Write-Output ("ERRORS: {0}" -f $errors.Count)
    Write-Output ("WARNINGS: {0}" -f $warnings.Count)
    foreach ($e in $errors) {
        Write-Output ("[ERROR] {0}: {1}" -f $e.id, $e.message)
    }
    foreach ($w in $warnings) {
        Write-Output ("[WARN]  {0}: {1}" -f $w.id, $w.message)
    }
}

if (-not $valid) { exit 1 } else { exit 0 }
