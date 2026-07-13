#!/usr/bin/env pwsh
#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/governance.config.ps1"
    $script:setupPlanScript = Join-Path $WorkspaceRoot 'studio/scripts/powershell/setup-plan.ps1'
    $script:checkPrerequisitesScript = Join-Path $WorkspaceRoot 'studio/scripts/powershell/check-prerequisites.ps1'

    function script:Write-ReadinessFixture {
        param(
            [string]$PrimaryStatus = 'READY_FOR_PLAN',
            [string]$LedgerRequirement = 'Not Required'
        )

        $readinessDir = Join-Path $script:featureDir 'readiness'
        New-Item -ItemType Directory -Path $readinessDir -Force | Out-Null
        @"
# Readiness Assessment: Fixture

**Date**: 2026-04-30
**Primary Status**: $PrimaryStatus
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
        ($output -join "`n") | Should -Match 'requires intent-ledger\.md'
    }

    It 'fails when ECI authorization does not allow mainline implementation' {
        Write-ReadinessFixture
        $eciDir = Join-Path $script:featureDir 'readiness/eci'
        New-Item -ItemType Directory -Path $eciDir -Force | Out-Null
        @"
# ECI Authorization Record: Fixture

**Authorization Outcome**: READY_FOR_SANDBOX_ONLY
"@ | Set-Content -LiteralPath (Join-Path $eciDir 'authorization-record.md')

        $output = pwsh -NoProfile -File $script:setupPlanScript -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match 'READY_FOR_SANDBOX_ONLY'
    }
}
