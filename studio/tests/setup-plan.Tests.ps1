#!/usr/bin/env pwsh
#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/governance.config.ps1"
    $script:setupPlanScript = Join-Path $WorkspaceRoot 'studio/scripts/powershell/setup-plan.ps1'
    $script:checkPrerequisitesScript = Join-Path $WorkspaceRoot 'studio/scripts/powershell/check-prerequisites.ps1'
    $script:planAgentPath = Join-Path $WorkspaceRoot '.github/agents/speckit.plan.agent.md'

    function script:Write-ReadinessFixture {
        param(
            [string]$PrimaryStatus = 'READY_FOR_PLAN',
            [string]$LedgerRequirement = 'Not Required',
            [string]$EciReentryStatus = 'NOT_REQUIRED',
            [string]$EciEvidenceSha256 = 'N/A'
        )

        $readinessDir = Join-Path $script:featureDir 'readiness'
        New-Item -ItemType Directory -Path $readinessDir -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $readinessDir 'eci') -Force | Out-Null
        @"
# Readiness Assessment: Fixture

**Date**: 2026-04-30
**Primary Status**: $PrimaryStatus
**ECI Re-entry Status**: $EciReentryStatus
**ECI Evidence SHA-256**: $EciEvidenceSha256
**Recommended Next Step**: /speckit.plan

## Summary

- Ready.

## Planability vs Intent Obligations

- **Planability Resolved**: Yes
- **Intent Obligations Retained**: None
- **Intent Ledger Requirement**: $LedgerRequirement
- **Intent Ledger Path**: specs/$script:featureName/intent-ledger.md

## Readiness Dimension Scan

All clear.

## Primary Blocker Analysis

No blockers.

## Allowed / Not Allowed Next Actions

### Allowed

- Run /speckit.plan.

### Not Allowed

- Skip planning.
"@ | Set-Content -LiteralPath (Join-Path $readinessDir 'readiness-assessment.md')
    }

    function script:Write-EciDossier {
        param(
            [string]$AuthorizationOutcome = 'READY_FOR_MAINLINE_IMPLEMENTATION',
            [string]$AuthorizationSuffix = '',
            [switch]$CompleteReadiness
        )

        $readinessDir = Join-Path $script:featureDir 'readiness'
        $eciDir = Join-Path $readinessDir 'eci'
        New-Item -ItemType Directory -Path $eciDir -Force | Out-Null
        "# ECI Trigger`n`n**Provider**: provider-a`n**Scope**: read-only`n" |
            Set-Content -LiteralPath (Join-Path $readinessDir 'eci-trigger.md') -NoNewline
        @"
# ECI Assessment

**ECI Level**: ``STANDARD_ECI``
"@ | Set-Content -LiteralPath (Join-Path $eciDir 'eci-assessment.md') -NoNewline
        "# ECI Source Manifest`n`nCanonical source evidence.`n" |
            Set-Content -LiteralPath (Join-Path $eciDir 'source-manifest.md') -NoNewline
        "# ECI Adoption Record`n`nGoverned adoption boundary.`n" |
            Set-Content -LiteralPath (Join-Path $eciDir 'adoption-record.md') -NoNewline
        @"
# ECI Authorization Record

**Authorization Outcome**: ``$AuthorizationOutcome``
$AuthorizationSuffix
"@ | Set-Content -LiteralPath (Join-Path $eciDir 'authorization-record.md') -NoNewline

        if ($CompleteReadiness) {
            Set-EciReadinessComplete
        }

        Write-EciRequirementMarker
    }

    function script:Write-EciRequirementMarker {
        $markerDir = Join-Path $script:projectRoot ".workflow/runs/$script:featureName"
        New-Item -ItemType Directory -Path $markerDir -Force | Out-Null
        [ordered]@{
            schema_version = '1.0.0'
            feature = $script:featureName
            feature_path = "specs/$script:featureName"
            eci_required = $true
            recorded_at = '2026-07-18T00:00:00.0000000+00:00'
        } | ConvertTo-Json -Compress |
            Set-Content -LiteralPath (Join-Path $markerDir 'eci-requirement.json') -NoNewline -Encoding utf8
    }

    function script:Get-EciEvidenceDigest {
        $readinessDir = Join-Path $script:featureDir 'readiness'
        $relativePaths = @(
            'eci-trigger.md',
            'eci/eci-assessment.md',
            'eci/source-manifest.md',
            'eci/adoption-record.md',
            'eci/authorization-record.md'
        )
        $hasher = [System.Security.Cryptography.IncrementalHash]::CreateHash(
            [System.Security.Cryptography.HashAlgorithmName]::SHA256
        )
        try {
            foreach ($relativePath in $relativePaths) {
                $pathBytes = [System.Text.Encoding]::UTF8.GetBytes($relativePath)
                $pathLengthBytes = [System.BitConverter]::GetBytes([uint32]$pathBytes.Length)
                if ([System.BitConverter]::IsLittleEndian) {
                    [System.Array]::Reverse($pathLengthBytes)
                }

                $contentBytes = [System.IO.File]::ReadAllBytes(
                    (Join-Path $readinessDir $relativePath)
                )
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

    function script:Set-EciReadinessComplete {
        $assessmentPath = Join-Path $script:featureDir 'readiness/readiness-assessment.md'
        $digest = Get-EciEvidenceDigest
        $content = Get-Content -LiteralPath $assessmentPath -Raw
        $content = $content -replace '(?m)^\*\*ECI Re-entry Status\*\*:\s*.+$', '**ECI Re-entry Status**: COMPLETE'
        $content = $content -replace '(?m)^\*\*ECI Evidence SHA-256\*\*:\s*.+$', "**ECI Evidence SHA-256**: $digest"
        $content | Set-Content -LiteralPath $assessmentPath -NoNewline
    }
}

Describe 'setup-plan readiness gate' {
    BeforeEach {
        $script:oldProjectRoot = $env:SDD_PROJECT_ROOT
        $script:oldStudioRoot = $env:SDD_STUDIO_ROOT
        $script:oldSpecifyFeature = $env:SPECIFY_FEATURE

        $script:projectRoot = Join-Path $TestDrive ("fixture-project-{0}" -f ([System.Guid]::NewGuid().ToString('N')))
        $script:featureName = '001-fixture'
        $script:featureDir = Join-Path $script:projectRoot "specs/$script:featureName"
        New-Item -ItemType Directory -Path $script:featureDir -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:projectRoot '.specify/memory') -Force | Out-Null
        '# Fixture constitution' | Set-Content -LiteralPath (Join-Path $script:projectRoot '.specify/memory/constitution.md')
        '# Specification: Fixture' | Set-Content -LiteralPath (Join-Path $script:featureDir 'spec.md')

        $env:SDD_PROJECT_ROOT = $script:projectRoot
        $env:SDD_STUDIO_ROOT = Join-Path $WorkspaceRoot 'studio'
        $env:SPECIFY_FEATURE = $script:featureName
    }

    AfterEach {
        $env:SDD_PROJECT_ROOT = $script:oldProjectRoot
        $env:SDD_STUDIO_ROOT = $script:oldStudioRoot
        $env:SPECIFY_FEATURE = $script:oldSpecifyFeature
    }

    It 'creates plan.md when readiness is READY_FOR_PLAN' {
        Write-ReadinessFixture

        $output = pwsh -NoProfile -File $script:setupPlanScript -Json
        $LASTEXITCODE | Should -Be 0
        $result = ($output[-1] | ConvertFrom-Json)
        $result.IMPL_PLAN | Should -Exist
    }

    It 'uses explicit FeatureDir when current feature context differs' {
        Write-ReadinessFixture
        $env:SPECIFY_FEATURE = '777-other'

        $output = pwsh -NoProfile -File $script:setupPlanScript -FeatureDir $script:featureDir -Json
        $LASTEXITCODE | Should -Be 0
        $result = ($output[-1] | ConvertFrom-Json)

        [System.IO.Path]::GetFullPath($result.SPECS_DIR) | Should -Be ([System.IO.Path]::GetFullPath($script:featureDir))
        [System.IO.Path]::GetFullPath($result.FEATURE_SPEC) | Should -Be ([System.IO.Path]::GetFullPath((Join-Path $script:featureDir 'spec.md')))
        [System.IO.Path]::GetFullPath($result.IMPL_PLAN) | Should -Be ([System.IO.Path]::GetFullPath((Join-Path $script:featureDir 'plan.md')))
        $result.BRANCH | Should -Be '777-other'
        $result.IMPL_PLAN | Should -Exist
        (Join-Path $script:projectRoot 'specs/777-other/plan.md') | Should -Not -Exist
    }

    It 'discovers explicit FeatureDir for the plan agent handoff' {
        $env:SPECIFY_FEATURE = '777-other'

        $output = pwsh -NoProfile -File $script:checkPrerequisitesScript -FeatureDir $script:featureDir -Json -PathsOnly
        $LASTEXITCODE | Should -Be 0
        $result = (($output -join "`n") | ConvertFrom-Json)

        [System.IO.Path]::GetFullPath($result.FEATURE_DIR) | Should -Be ([System.IO.Path]::GetFullPath($script:featureDir))
        [System.IO.Path]::GetFullPath($result.FEATURE_SPEC) | Should -Be ([System.IO.Path]::GetFullPath((Join-Path $script:featureDir 'spec.md')))
        $result.BRANCH | Should -Be '777-other'
    }

    It 'requires every post-discovery plan command to reuse the returned absolute FeatureDir' {
        $agent = Get-Content -LiteralPath $script:planAgentPath -Raw

        $agent | Should -Match 'setup-plan\.ps1 -FeatureDir "<FEATURE_DIR>" -Json'
        $agent | Should -Match 'update-agent-context\.ps1 -FeatureDir "<FEATURE_DIR>" -AgentType copilot'
        $agent | Should -Match 'Create a checklist for the following domain with -FeatureDir <FEATURE_DIR>\.'
        $agent | Should -Match '/speckit\.readiness -FeatureDir "<FEATURE_DIR>"'
        $agent | Should -Not -Match 'setup-plan\.ps1 -Json` from repo root, or'
        $agent | Should -Not -Match 'update-agent-context\.ps1 -AgentType copilot`, or'
        $agent | Should -Not -Match 'prompt: Create a checklist for the following domain\.\.\.'
    }

    It 'rejects explicit FeatureDir outside configured project specs' {
        Write-ReadinessFixture
        $outsideFeature = Join-Path $TestDrive 'outside/001-fixture'
        New-Item -ItemType Directory -Path $outsideFeature -Force | Out-Null

        $output = pwsh -NoProfile -File $script:setupPlanScript -FeatureDir $outsideFeature -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match 'FEATURE_DIR escapes project root'
        (Join-Path $outsideFeature 'plan.md') | Should -Not -Exist
    }

    It 'rejects a nested path instead of a direct specs feature child' {
        $nestedFeature = Join-Path $script:featureDir 'nested'
        New-Item -ItemType Directory -Path $nestedFeature -Force | Out-Null

        $output = pwsh -NoProfile -File $script:setupPlanScript -FeatureDir $nestedFeature -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match 'FEATURE_DIR escapes project root'
        (Join-Path $nestedFeature 'plan.md') | Should -Not -Exist
    }

    It 'fails when readiness assessment is missing' {
        $output = pwsh -NoProfile -File $script:setupPlanScript -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match 'readiness-assessment\.md is required'
    }

    It 'fails when readiness is not READY_FOR_PLAN' {
        Write-ReadinessFixture -PrimaryStatus 'ROUTE_TO_DECISION'

        $output = pwsh -NoProfile -File $script:setupPlanScript -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match 'ROUTE_TO_DECISION'
    }

    It 'fails when readiness requires a missing intent ledger' {
        Write-ReadinessFixture -LedgerRequirement 'Create `intent-ledger.md`'

        $output = pwsh -NoProfile -File $script:setupPlanScript -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match '\[intent-ledger-missing\]'
    }

    It 'fails when ECI authorization does not allow mainline implementation' {
        Write-ReadinessFixture
        Write-EciDossier -AuthorizationOutcome 'READY_FOR_SANDBOX_ONLY' -CompleteReadiness

        $output = pwsh -NoProfile -File $script:setupPlanScript -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match 'READY_FOR_SANDBOX_ONLY'
    }

    It 'accepts a mainline dossier with correctly bound COMPLETE Readiness evidence' {
        Write-ReadinessFixture
        Write-EciDossier -CompleteReadiness

        $output = pwsh -NoProfile -File $script:setupPlanScript -Json
        $LASTEXITCODE | Should -Be 0
        (($output[-1] | ConvertFrom-Json).IMPL_PLAN) | Should -Exist
    }

    It 'denies non-mainline ECI outcome <Outcome> even when readiness says READY_FOR_PLAN' -ForEach @(
        @{ Outcome = 'READY_FOR_SPIKE_ONLY' }
        @{ Outcome = 'READY_FOR_SANDBOX_ONLY' }
        @{ Outcome = 'NOT_READY' }
    ) {
        Write-ReadinessFixture
        Write-EciDossier -AuthorizationOutcome $Outcome -CompleteReadiness

        $output = pwsh -NoProfile -File $script:setupPlanScript -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match ([regex]::Escape($Outcome))
        (Join-Path $script:featureDir 'plan.md') | Should -Not -Exist
    }

    It 'denies a previously triggered ECI dossier when <MissingFile> is missing' -ForEach @(
        @{ MissingFile = 'eci-assessment.md' }
        @{ MissingFile = 'source-manifest.md' }
        @{ MissingFile = 'adoption-record.md' }
        @{ MissingFile = 'authorization-record.md' }
    ) {
        Write-ReadinessFixture
        Write-EciDossier -CompleteReadiness
        Remove-Item -LiteralPath (Join-Path $script:featureDir "readiness/eci/$MissingFile") -Force

        $output = pwsh -NoProfile -File $script:setupPlanScript -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match ([regex]::Escape(($MissingFile -replace '\.md$', '')))
        (Join-Path $script:featureDir 'plan.md') | Should -Not -Exist
    }

    It 'denies direct planning when only the ECI trigger remains after readiness is hand-edited to READY_FOR_PLAN' {
        Write-ReadinessFixture
        "# ECI Trigger`n" |
            Set-Content -LiteralPath (Join-Path $script:featureDir 'readiness/eci-trigger.md') -NoNewline

        $output = pwsh -NoProfile -File $script:setupPlanScript -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match '\[eci-reentry-not-required-artifacts-present\]'
        (Join-Path $script:featureDir 'plan.md') | Should -Not -Exist
    }

    It 'denies duplicate contradictory readiness Primary Status fields' {
        Write-ReadinessFixture
        Add-Content -LiteralPath (Join-Path $script:featureDir 'readiness/readiness-assessment.md') `
            -Value "`n**Primary Status**: ``ROUTE_TO_DECISION``"

        $output = pwsh -NoProfile -File $script:setupPlanScript -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match '\[readiness-primary-status-invalid\]'
        (Join-Path $script:featureDir 'plan.md') | Should -Not -Exist
    }

    It 'denies duplicate contradictory ECI Authorization Outcome fields' {
        Write-ReadinessFixture
        Write-EciDossier `
            -AuthorizationSuffix '**Authorization Outcome**: `READY_FOR_SANDBOX_ONLY`' `
            -CompleteReadiness

        $output = pwsh -NoProfile -File $script:setupPlanScript -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match '\[eci-authorization-outcome-invalid\]'
        (Join-Path $script:featureDir 'plan.md') | Should -Not -Exist
    }

    It 'denies direct planning with a complete dossier but no COMPLETE Readiness evidence' {
        Write-ReadinessFixture
        Write-EciDossier

        $output = pwsh -NoProfile -File $script:setupPlanScript -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match '\[eci-reentry-not-required-artifacts-present\]'
        (Join-Path $script:featureDir 'plan.md') | Should -Not -Exist
    }

    It 'denies direct planning after the trigger and all four dossier files are deleted' {
        Write-ReadinessFixture
        Write-EciDossier -CompleteReadiness
        Remove-Item -LiteralPath (Join-Path $script:featureDir 'readiness/eci-trigger.md') -Force
        Get-ChildItem -LiteralPath (Join-Path $script:featureDir 'readiness/eci') -File |
            Remove-Item -Force

        $output = pwsh -NoProfile -File $script:setupPlanScript -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match '\[eci-trigger-missing\]'
        (Join-Path $script:featureDir 'plan.md') | Should -Not -Exist
    }

    It 'denies direct planning when a COMPLETE evidence digest is stale' {
        Write-ReadinessFixture
        Write-EciDossier -CompleteReadiness
        Add-Content -LiteralPath (Join-Path $script:featureDir 'readiness/eci/adoption-record.md') `
            -Value 'Changed after Readiness.'

        $output = pwsh -NoProfile -File $script:setupPlanScript -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match '\[eci-evidence-sha256-mismatch\]'
        (Join-Path $script:featureDir 'plan.md') | Should -Not -Exist
    }

    It 'denies direct planning after only the trigger provider and scope are changed' {
        Write-ReadinessFixture
        Write-EciDossier -CompleteReadiness
        @"
# ECI Trigger

**Provider**: provider-b
**Scope**: write-enabled
"@ | Set-Content -LiteralPath (Join-Path $script:featureDir 'readiness/eci-trigger.md') -NoNewline

        $output = pwsh -NoProfile -File $script:setupPlanScript -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match '\[eci-evidence-sha256-mismatch\]'
        (Join-Path $script:featureDir 'plan.md') | Should -Not -Exist
    }

    It 'denies direct planning when ECI Evidence SHA-256 is <Kind>' -ForEach @(
        @{ Kind = 'missing'; Digest = $null }
        @{ Kind = 'malformed'; Digest = 'ABC123' }
    ) {
        Write-ReadinessFixture -EciReentryStatus 'COMPLETE' -EciEvidenceSha256 $(if ($null -eq $Digest) { 'N/A' } else { $Digest })
        if ($null -eq $Digest) {
            $assessmentPath = Join-Path $script:featureDir 'readiness/readiness-assessment.md'
            (Get-Content -LiteralPath $assessmentPath -Raw) `
                -replace '(?m)^\*\*ECI Evidence SHA-256\*\*:.*\r?\n?', '' |
                Set-Content -LiteralPath $assessmentPath -NoNewline
        }
        Write-EciDossier

        $output = pwsh -NoProfile -File $script:setupPlanScript -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match '\[readiness-eci-evidence-sha256-invalid\]'
        (Join-Path $script:featureDir 'plan.md') | Should -Not -Exist
    }

    It 'denies direct planning while ECI re-entry remains PENDING' {
        Write-ReadinessFixture `
            -PrimaryStatus 'READY_FOR_PLAN' `
            -EciReentryStatus 'PENDING' `
            -EciEvidenceSha256 'N/A'
        Write-EciDossier

        $output = pwsh -NoProfile -File $script:setupPlanScript -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match '\[eci-reentry-pending-route-invalid\]'
        (Join-Path $script:featureDir 'plan.md') | Should -Not -Exist
    }

    It 'denies direct planning after combined canonical ECI evidence deletion and NOT_REQUIRED rewrite when the marker remains' {
        Write-ReadinessFixture
        Write-EciDossier -CompleteReadiness
        Remove-Item -LiteralPath (Join-Path $script:featureDir 'readiness/eci-trigger.md') -Force
        Get-ChildItem -LiteralPath (Join-Path $script:featureDir 'readiness/eci') -File |
            Remove-Item -Force
        Write-ReadinessFixture -PrimaryStatus 'READY_FOR_PLAN' -EciReentryStatus 'NOT_REQUIRED' -EciEvidenceSha256 'N/A'

        $output = pwsh -NoProfile -File $script:setupPlanScript -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match 'eci-requirement-latched-not-required'
    }

    It 'denies direct planning when a complete ECI dossier has no requirement marker' {
        Write-ReadinessFixture
        Write-EciDossier -CompleteReadiness
        Remove-Item -LiteralPath (
            Join-Path $script:projectRoot ".workflow/runs/$script:featureName/eci-requirement.json"
        ) -Force

        $output = pwsh -NoProfile -File $script:setupPlanScript -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match 'eci-requirement-marker-missing'
        (Join-Path $script:featureDir 'plan.md') | Should -Not -Exist
    }
}
