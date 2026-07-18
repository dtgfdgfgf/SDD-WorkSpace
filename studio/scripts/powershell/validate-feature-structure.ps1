#!/usr/bin/env pwsh

#Requires -Version 7.0
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
    - readiness/ and readiness/readiness-assessment.md MUST exist. A missing
      readiness stage is an error, not an advisory absence.
    - readiness/eci/ MUST exist as the canonical ECI container. Readiness MUST
      declare exactly one ECI re-entry status and evidence digest. COMPLETE
      binds the assessment to the names, boundaries, and raw bytes of the ECI
      trigger plus all four canonical dossier files.
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

    [switch]$RequireEciDossier,

    [switch]$RequireEciReentry,

    [switch]$DeferEciDossier,

    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Output 'Usage: ./validate-feature-structure.ps1 -FeatureDir <path> [-Json] [-WarningsAsErrors] [-RequireEciDossier] [-RequireEciReentry] [-DeferEciDossier]'
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

function Get-ExactlyOneMarkdownField {
    param(
        [Parameter(Mandatory = $true)][string]$Content,
        [Parameter(Mandatory = $true)][string]$Field
    )

    $escapedField = [regex]::Escape($Field)
    $pattern = "(?mi)^\s*(?:-\s*)?\*\*$escapedField(?::\*\*|\*\*:)\s*(.+?)\s*$"
    $matches = @([regex]::Matches($Content, $pattern))

    if ($matches.Count -ne 1) {
        return [PSCustomObject]@{
            Valid = $false
            Value = $null
            Error = "Expected exactly one '$Field' field, found $($matches.Count)."
        }
    }

    $value = $matches[0].Groups[1].Value.Trim()
    if ($value -match '^`(.+)`$') {
        $value = $Matches[1]
    } elseif ($value -match '^"(.+)"$') {
        $value = $Matches[1]
    }

    return [PSCustomObject]@{
        Valid = $true
        Value = $value
        Error = $null
    }
}

function Get-ExactlyOneMarkdownEnum {
    param(
        [Parameter(Mandatory = $true)][string]$Content,
        [Parameter(Mandatory = $true)][string]$Field,
        [Parameter(Mandatory = $true)][string[]]$AllowedValues
    )

    $fieldResult = Get-ExactlyOneMarkdownField -Content $Content -Field $Field
    if (-not $fieldResult.Valid) {
        return $fieldResult
    }

    $value = [string]$fieldResult.Value
    $isAllowed = @($AllowedValues | Where-Object {
        [string]::Equals($_, $value, [System.StringComparison]::Ordinal)
    }).Count -eq 1
    if (-not $isAllowed) {
        return [PSCustomObject]@{
            Valid = $false
            Value = $value
            Error = "'$Field' value '$value' is not one of: $($AllowedValues -join ', ')."
        }
    }

    return [PSCustomObject]@{
        Valid = $true
        Value = $value
        Error = $null
    }
}

function Get-EciEvidenceSha256 {
    param(
        [Parameter(Mandatory = $true)][string]$ReadinessDir,
        [Parameter(Mandatory = $true)][string[]]$OrderedRelativePaths
    )

    $hasher = [System.Security.Cryptography.IncrementalHash]::CreateHash(
        [System.Security.Cryptography.HashAlgorithmName]::SHA256
    )
    try {
        foreach ($relativePath in $OrderedRelativePaths) {
            $path = Join-Path $ReadinessDir $relativePath
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
                return $null
            }

            $pathBytes = [System.Text.Encoding]::UTF8.GetBytes($relativePath)
            $pathLengthBytes = [System.BitConverter]::GetBytes([uint32]$pathBytes.Length)
            if ([System.BitConverter]::IsLittleEndian) {
                [System.Array]::Reverse($pathLengthBytes)
            }

            $contentBytes = [System.IO.File]::ReadAllBytes($path)
            $contentLengthBytes = [System.BitConverter]::GetBytes([uint64]$contentBytes.LongLength)
            if ([System.BitConverter]::IsLittleEndian) {
                [System.Array]::Reverse($contentLengthBytes)
            }

            $hasher.AppendData($pathLengthBytes)
            $hasher.AppendData($pathBytes)
            $hasher.AppendData($contentLengthBytes)
            $hasher.AppendData($contentBytes)
        }
        return [System.Convert]::ToHexString($hasher.GetHashAndReset()).ToLowerInvariant()
    } finally {
        $hasher.Dispose()
    }
}

$resolvedFeatureDir = Resolve-AbsolutePath -Path $FeatureDir
$findings = @()
$readinessPrimaryStatus = $null
$eciReentryStatus = $null
$eciEvidenceSha256 = $null
$eciActualEvidenceSha256 = $null
$eciRequired = $RequireEciDossier.IsPresent -or $RequireEciReentry.IsPresent
$eciRequirementPath = $null
$eciRequirementLatched = $false
$eciRequirementMarkerInvalid = $false
$eciLevel = $null
$eciAuthorizationOutcome = $null

if (-not (Test-Path -LiteralPath $resolvedFeatureDir -PathType Container)) {
    $findings += New-Finding -Severity 'error' -Id 'feature-dir-missing' `
        -Message "Feature directory not found: $resolvedFeatureDir"
    if ($Json) {
        [PSCustomObject][ordered]@{
            VALID                      = $false
            FEATURE_DIR                = $resolvedFeatureDir
            READINESS_PRIMARY_STATUS   = $null
            ECI_REENTRY_STATUS         = $null
            ECI_EVIDENCE_SHA256        = $null
            ECI_ACTUAL_EVIDENCE_SHA256 = $null
            ECI_REQUIREMENT_PATH        = $null
            ECI_REQUIREMENT_LATCHED     = $false
            ERRORS                     = @($findings)
            WARNINGS                   = @()
        } | ConvertTo-Json -Depth 6
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

# readiness/readiness-assessment.md and readiness/eci/ (required containers)
$readinessDir = Join-Path $resolvedFeatureDir 'readiness'
$readinessAssessmentPath = Join-Path $readinessDir 'readiness-assessment.md'
$eciDir = Join-Path $readinessDir 'eci'
$eciTriggerPath = Join-Path $readinessDir 'eci-trigger.md'
$eciRequiredNames = @('eci-assessment.md', 'source-manifest.md', 'adoption-record.md', 'authorization-record.md')
$eciEvidenceRelativePaths = @(
    'eci-trigger.md',
    'eci/eci-assessment.md',
    'eci/source-manifest.md',
    'eci/adoption-record.md',
    'eci/authorization-record.md'
)
$readinessStatuses = @(
    'READY_FOR_PLAN',
    'ROUTE_TO_ECI',
    'ROUTE_TO_REPO_CONTEXT',
    'ROUTE_TO_DECISION',
    'ROUTE_TO_VALIDATION',
    'ROUTE_TO_ACCESS',
    'EXPLORATORY_ONLY',
    'NOT_READY'
)
$eciLevels = @('NO_ECI', 'LIGHT_ECI', 'STANDARD_ECI', 'CRITICAL_ECI')
$eciAuthorizationOutcomes = @(
    'READY_FOR_MAINLINE_IMPLEMENTATION',
    'READY_FOR_SPIKE_ONLY',
    'READY_FOR_SANDBOX_ONLY',
    'NOT_READY'
)
$eciReentryStatuses = @('NOT_REQUIRED', 'PENDING', 'COMPLETE')
$readinessExists = Test-Path -LiteralPath $readinessDir -PathType Container
$eciRequirementMarker = $null
try {
    $eciRequirementMarker = Read-EciRequirementMarker -FeatureDir $resolvedFeatureDir
    $eciRequirementPath = $eciRequirementMarker.PATH
    if ($eciRequirementMarker.EXISTS -and -not $eciRequirementMarker.VALID) {
        $eciRequirementMarkerInvalid = $true
        $eciRequired = $true
        $findings += New-Finding -Severity 'error' -Id 'eci-requirement-marker-invalid' `
            -Message "The ECI requirement marker is invalid and cannot be trusted: $($eciRequirementMarker.ERROR)" `
            -Path $eciRequirementMarker.PATH
    } elseif ($eciRequirementMarker.LATCHED) {
        $eciRequirementLatched = $true
        $eciRequired = $true
    }
} catch {
    $findings += New-Finding -Severity 'error' -Id 'eci-requirement-marker-context-invalid' `
        -Message $_.Exception.Message -Path $resolvedFeatureDir
}

if (-not $readinessExists) {
    $findings += New-Finding -Severity 'error' -Id 'readiness-dir-missing' `
        -Message 'readiness/ is required for every governed feature before Analyze or Implement.' -Path $readinessDir

    $intentLedgerPath = Join-Path $resolvedFeatureDir 'intent-ledger.md'
    if (Test-Path -LiteralPath $intentLedgerPath -PathType Leaf) {
        $findings += New-Finding -Severity 'warning' -Id 'intent-ledger-without-readiness' `
            -Message 'intent-ledger.md exists but readiness/ has not been initiated.' -Path $intentLedgerPath
    }
} else {
    if (-not (Test-Path -LiteralPath $eciDir -PathType Container)) {
        $findings += New-Finding -Severity 'error' -Id 'eci-dir-missing' `
            -Message 'readiness/eci/ is required as the canonical ECI dossier container.' -Path $eciDir
    }

    if (-not (Test-Path -LiteralPath $readinessAssessmentPath -PathType Leaf)) {
        $findings += New-Finding -Severity 'error' -Id 'readiness-assessment-missing' `
            -Message 'readiness/ exists but readiness-assessment.md is missing.' -Path $readinessAssessmentPath
    } else {
        $readinessContent = Get-Content -LiteralPath $readinessAssessmentPath -Raw
        $primaryStatusResult = Get-ExactlyOneMarkdownEnum `
            -Content $readinessContent `
            -Field 'Primary Status' `
            -AllowedValues $readinessStatuses
        if ($primaryStatusResult.Valid) {
            $readinessPrimaryStatus = $primaryStatusResult.Value
        } else {
            $findings += New-Finding -Severity 'error' -Id 'readiness-primary-status-invalid' `
                -Message $primaryStatusResult.Error -Path $readinessAssessmentPath
        }

        $eciReentryResult = Get-ExactlyOneMarkdownEnum `
            -Content $readinessContent `
            -Field 'ECI Re-entry Status' `
            -AllowedValues $eciReentryStatuses
        if ($eciReentryResult.Valid) {
            $eciReentryStatus = $eciReentryResult.Value
        } else {
            $findings += New-Finding -Severity 'error' -Id 'readiness-eci-reentry-status-invalid' `
                -Message $eciReentryResult.Error -Path $readinessAssessmentPath
        }

        $eciEvidenceShaResult = Get-ExactlyOneMarkdownField `
            -Content $readinessContent `
            -Field 'ECI Evidence SHA-256'
        if (-not $eciEvidenceShaResult.Valid) {
            $findings += New-Finding -Severity 'error' -Id 'readiness-eci-evidence-sha256-invalid' `
                -Message $eciEvidenceShaResult.Error -Path $readinessAssessmentPath
        } elseif (
            -not [string]::Equals(
                [string]$eciEvidenceShaResult.Value,
                'N/A',
                [System.StringComparison]::Ordinal
            ) -and
            [string]$eciEvidenceShaResult.Value -cnotmatch '^[a-f0-9]{64}$'
        ) {
            $findings += New-Finding -Severity 'error' -Id 'readiness-eci-evidence-sha256-invalid' `
                -Message "ECI Evidence SHA-256 must be exactly 'N/A' or a lowercase 64-character SHA-256 digest." `
                -Path $readinessAssessmentPath
        } else {
            $eciEvidenceSha256 = [string]$eciEvidenceShaResult.Value
        }

        $ledgerRequirement = Get-MarkdownField -Content $readinessContent -Field 'Intent Ledger Requirement'

        $eciTriggerExists = Test-Path -LiteralPath $eciTriggerPath -PathType Leaf
        $eciDossierStarted = @($eciRequiredNames | Where-Object {
            Test-Path -LiteralPath (Join-Path $eciDir $_) -PathType Leaf
        }).Count -gt 0
        $eciContainerHasArtifacts = (
            (Test-Path -LiteralPath $eciDir -PathType Container) -and
            @(
                Get-ChildItem -LiteralPath $eciDir -Force -ErrorAction SilentlyContinue
            ).Count -gt 0
        )
        $eciArtifactsPresent = $eciTriggerExists -or $eciContainerHasArtifacts
        $canDeferInitialEciIntake = (
            $DeferEciDossier.IsPresent -and
            -not $RequireEciDossier.IsPresent -and
            -not $RequireEciReentry.IsPresent -and
            $eciReentryStatus -eq 'PENDING' -and
            $readinessPrimaryStatus -eq 'ROUTE_TO_ECI' -and
            -not $eciContainerHasArtifacts
        )
        $eciIndicatedByCurrentState = (
            $RequireEciDossier.IsPresent -or
            $RequireEciReentry.IsPresent -or
            $readinessPrimaryStatus -eq 'ROUTE_TO_ECI' -or
            $eciReentryStatus -in @('PENDING', 'COMPLETE') -or
            $eciArtifactsPresent
        )
        if (
            $eciIndicatedByCurrentState -and
            -not $eciRequirementLatched -and
            -not $eciRequirementMarkerInvalid -and
            -not $canDeferInitialEciIntake
        ) {
            $findings += New-Finding -Severity 'error' -Id 'eci-requirement-marker-missing' `
                -Message 'Current readiness state or ECI artifacts require a valid operator-local ECI requirement marker. Re-run the non-bypassable /speckit.eci entry gate before governed re-entry.' `
                -Path $eciRequirementPath
        }
        $eciRequired = (
            $eciRequirementLatched -or
            $eciRequirementMarkerInvalid -or
            $RequireEciDossier.IsPresent -or
            $RequireEciReentry.IsPresent -or
            $readinessPrimaryStatus -eq 'ROUTE_TO_ECI' -or
            $eciReentryStatus -in @('PENDING', 'COMPLETE') -or
            $eciArtifactsPresent
        )

        if ($eciReentryStatus -eq 'NOT_REQUIRED') {
            if ($eciRequirementLatched) {
                $findings += New-Finding -Severity 'error' -Id 'eci-requirement-latched-not-required' `
                    -Message 'A latched ECI requirement cannot be rewritten as ECI Re-entry Status NOT_REQUIRED.' `
                    -Path $readinessAssessmentPath
            }
            if ($readinessPrimaryStatus -eq 'ROUTE_TO_ECI') {
                $findings += New-Finding -Severity 'error' -Id 'eci-reentry-not-required-route-invalid' `
                    -Message 'ECI Re-entry Status NOT_REQUIRED cannot be used with Primary Status ROUTE_TO_ECI.' `
                    -Path $readinessAssessmentPath
            }
            if ($eciArtifactsPresent) {
                $findings += New-Finding -Severity 'error' -Id 'eci-reentry-not-required-artifacts-present' `
                    -Message 'ECI Re-entry Status NOT_REQUIRED requires no eci-trigger.md or artifacts under readiness/eci/.' `
                    -Path $readinessAssessmentPath
            }
            if ($eciEvidenceSha256 -and $eciEvidenceSha256 -ne 'N/A') {
                $findings += New-Finding -Severity 'error' -Id 'eci-reentry-not-required-digest-invalid' `
                    -Message "ECI Re-entry Status NOT_REQUIRED requires ECI Evidence SHA-256 'N/A'." `
                    -Path $readinessAssessmentPath
            }
            if ($eciRequirementLatched -and $eciEvidenceSha256 -eq 'N/A') {
                $findings += New-Finding -Severity 'error' -Id 'eci-requirement-latched-digest-na' `
                    -Message "A latched ECI requirement cannot use ECI Evidence SHA-256 'N/A'." `
                    -Path $readinessAssessmentPath
            }
            if ($RequireEciDossier.IsPresent -or $RequireEciReentry.IsPresent) {
                $findings += New-Finding -Severity 'error' -Id 'eci-reentry-required-but-not-required' `
                    -Message 'This validation path requires ECI evidence, but Readiness declares ECI Re-entry Status NOT_REQUIRED.' `
                    -Path $readinessAssessmentPath
            }
        } elseif ($eciReentryStatus -eq 'PENDING') {
            if ($readinessPrimaryStatus -ne 'ROUTE_TO_ECI') {
                $findings += New-Finding -Severity 'error' -Id 'eci-reentry-pending-route-invalid' `
                    -Message 'ECI Re-entry Status PENDING is valid only with the initial Primary Status ROUTE_TO_ECI.' `
                    -Path $readinessAssessmentPath
            }
            if ($eciEvidenceSha256 -and $eciEvidenceSha256 -ne 'N/A') {
                $findings += New-Finding -Severity 'error' -Id 'eci-reentry-pending-digest-invalid' `
                    -Message "ECI Re-entry Status PENDING requires ECI Evidence SHA-256 'N/A' until Readiness re-enters." `
                    -Path $readinessAssessmentPath
            }
        } elseif ($eciReentryStatus -eq 'COMPLETE') {
            if (-not $eciEvidenceSha256 -or $eciEvidenceSha256 -eq 'N/A') {
                $findings += New-Finding -Severity 'error' -Id 'eci-reentry-complete-digest-missing' `
                    -Message 'ECI Re-entry Status COMPLETE requires a lowercase 64-character ECI Evidence SHA-256.' `
                    -Path $readinessAssessmentPath
            }
        }

        if ($readinessPrimaryStatus -eq 'ROUTE_TO_ECI') {
            if (-not $eciTriggerExists) {
                $findings += New-Finding -Severity 'error' -Id 'eci-trigger-missing' `
                    -Message 'ROUTE_TO_ECI requires readiness/eci-trigger.md.' -Path $eciTriggerPath
            } elseif ([string]::IsNullOrWhiteSpace((Get-Content -LiteralPath $eciTriggerPath -Raw))) {
                $findings += New-Finding -Severity 'error' -Id 'eci-trigger-empty' `
                    -Message 'readiness/eci-trigger.md must not be empty.' -Path $eciTriggerPath
            }
        }

        $canDeferDossier = $canDeferInitialEciIntake
        $requireCompleteDossier = (
            $RequireEciDossier.IsPresent -or
            $RequireEciReentry.IsPresent -or
            ($eciRequirementLatched -and -not $canDeferDossier) -or
            $eciReentryStatus -eq 'COMPLETE' -or
            $eciDossierStarted -or
            (
                $eciReentryStatus -eq 'PENDING' -and
                -not $canDeferDossier
            )
        )

        if ($requireCompleteDossier) {
            $eciEvidenceComplete = $true
            if (-not $eciTriggerExists) {
                $eciEvidenceComplete = $false
                if (-not @($findings | Where-Object { $_.id -eq 'eci-trigger-missing' }).Count) {
                    $findings += New-Finding -Severity 'error' -Id 'eci-trigger-missing' `
                        -Message 'Triggered ECI governance requires readiness/eci-trigger.md.' -Path $eciTriggerPath
                }
            } elseif ([string]::IsNullOrWhiteSpace((Get-Content -LiteralPath $eciTriggerPath -Raw))) {
                $eciEvidenceComplete = $false
                if (-not @($findings | Where-Object { $_.id -eq 'eci-trigger-empty' }).Count) {
                    $findings += New-Finding -Severity 'error' -Id 'eci-trigger-empty' `
                    -Message 'readiness/eci-trigger.md must not be empty.' -Path $eciTriggerPath
                }
            }

            foreach ($name in $eciRequiredNames) {
                $eciPath = Join-Path $eciDir $name
                if (-not (Test-Path -LiteralPath $eciPath -PathType Leaf)) {
                    $eciEvidenceComplete = $false
                    $findings += New-Finding -Severity 'error' -Id "eci-missing-$($name -replace '\.md$','')" `
                        -Message "Triggered ECI governance requires readiness/eci/$name." -Path $eciPath
                } elseif ([string]::IsNullOrWhiteSpace((Get-Content -LiteralPath $eciPath -Raw))) {
                    $eciEvidenceComplete = $false
                    $findings += New-Finding -Severity 'error' -Id "eci-empty-$($name -replace '\.md$','')" `
                        -Message "Triggered ECI governance requires non-empty readiness/eci/$name." -Path $eciPath
                }
            }

            if ($eciEvidenceComplete) {
                $eciActualEvidenceSha256 = Get-EciEvidenceSha256 `
                    -ReadinessDir $readinessDir `
                    -OrderedRelativePaths $eciEvidenceRelativePaths
            }
            if ($eciEvidenceComplete -and $eciReentryStatus -eq 'COMPLETE') {
                if (
                    $eciEvidenceSha256 -and
                    $eciEvidenceSha256 -ne 'N/A' -and
                    -not [string]::Equals(
                        $eciEvidenceSha256,
                        $eciActualEvidenceSha256,
                        [System.StringComparison]::Ordinal
                    )
                ) {
                    $findings += New-Finding -Severity 'error' -Id 'eci-evidence-sha256-mismatch' `
                        -Message 'ECI Evidence SHA-256 does not match the canonical framed digest of the five ECI evidence relative paths, boundaries, and raw bytes.' `
                        -Path $readinessAssessmentPath
                }
            }

            $eciAssessmentPath = Join-Path $eciDir 'eci-assessment.md'
            if (
                (Test-Path -LiteralPath $eciAssessmentPath -PathType Leaf) -and
                -not [string]::IsNullOrWhiteSpace((Get-Content -LiteralPath $eciAssessmentPath -Raw))
            ) {
                $eciAssessmentContent = Get-Content -LiteralPath $eciAssessmentPath -Raw
                $eciLevelResult = Get-ExactlyOneMarkdownEnum `
                    -Content $eciAssessmentContent `
                    -Field 'ECI Level' `
                    -AllowedValues $eciLevels
                if ($eciLevelResult.Valid) {
                    $eciLevel = $eciLevelResult.Value
                } else {
                    $findings += New-Finding -Severity 'error' -Id 'eci-level-invalid' `
                        -Message $eciLevelResult.Error -Path $eciAssessmentPath
                }
            }

            $authorizationRecordPath = Join-Path $eciDir 'authorization-record.md'
            if (
                (Test-Path -LiteralPath $authorizationRecordPath -PathType Leaf) -and
                -not [string]::IsNullOrWhiteSpace((Get-Content -LiteralPath $authorizationRecordPath -Raw))
            ) {
                $authorizationContent = Get-Content -LiteralPath $authorizationRecordPath -Raw
                $authorizationResult = Get-ExactlyOneMarkdownEnum `
                    -Content $authorizationContent `
                    -Field 'Authorization Outcome' `
                    -AllowedValues $eciAuthorizationOutcomes
                if ($authorizationResult.Valid) {
                    $eciAuthorizationOutcome = $authorizationResult.Value
                } else {
                    $findings += New-Finding -Severity 'error' -Id 'eci-authorization-outcome-invalid' `
                        -Message $authorizationResult.Error -Path $authorizationRecordPath
                }
            }

            if (
                $RequireEciReentry.IsPresent -and
                [string]::Equals(
                    $eciAuthorizationOutcome,
                    'NOT_READY',
                    [System.StringComparison]::Ordinal
                )
            ) {
                $findings += New-Finding -Severity 'error' -Id 'eci-reentry-not-authorized' `
                    -Message 'ECI Authorization Outcome NOT_READY is fail-closed and cannot enter post-ECI Readiness re-entry.' `
                    -Path $authorizationRecordPath
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
    VALID                          = $valid
    FEATURE_DIR                    = $resolvedFeatureDir
    READINESS_PRIMARY_STATUS       = $readinessPrimaryStatus
    ECI_REENTRY_STATUS             = $eciReentryStatus
    ECI_EVIDENCE_SHA256            = $eciEvidenceSha256
    ECI_ACTUAL_EVIDENCE_SHA256     = $eciActualEvidenceSha256
    ECI_REQUIREMENT_PATH           = $eciRequirementPath
    ECI_REQUIREMENT_LATCHED        = [bool]$eciRequirementLatched
    ECI_REQUIRED                   = $eciRequired
    ECI_LEVEL                      = $eciLevel
    ECI_AUTHORIZATION_OUTCOME      = $eciAuthorizationOutcome
    ERROR_COUNT                    = $errors.Count
    WARNING_COUNT                  = $warnings.Count
    ERRORS                         = $errors
    WARNINGS                       = $warnings
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
