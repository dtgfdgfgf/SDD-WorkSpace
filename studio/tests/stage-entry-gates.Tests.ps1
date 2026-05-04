#!/usr/bin/env pwsh
#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/governance.config.ps1"

    $script:setupClarify   = Join-Path $WorkspaceRoot 'studio/scripts/powershell/setup-clarify.ps1'
    $script:setupReadiness = Join-Path $WorkspaceRoot 'studio/scripts/powershell/setup-readiness.ps1'
    $script:setupTasks     = Join-Path $WorkspaceRoot 'studio/scripts/powershell/setup-tasks.ps1'
    $script:setupAnalyze   = Join-Path $WorkspaceRoot 'studio/scripts/powershell/setup-analyze.ps1'
    $script:setupImplement = Join-Path $WorkspaceRoot 'studio/scripts/powershell/setup-implement.ps1'

    function script:New-FeatureFixture {
        param(
            [string]$Name = '001-fixture',
            [hashtable]$With = @{}
        )

        $root = Join-Path $TestDrive ("feature-{0}" -f ([System.Guid]::NewGuid().ToString('N')))
        $featureDir = Join-Path $root "specs/$Name"
        New-Item -ItemType Directory -Path $featureDir -Force | Out-Null

        if ($With.ContainsKey('Spec')) {
            $With.Spec | Set-Content -LiteralPath (Join-Path $featureDir 'spec.md') -NoNewline
        }
        if ($With.ContainsKey('Plan')) {
            $With.Plan | Set-Content -LiteralPath (Join-Path $featureDir 'plan.md') -NoNewline
        }
        if ($With.ContainsKey('Tasks')) {
            $With.Tasks | Set-Content -LiteralPath (Join-Path $featureDir 'tasks.md') -NoNewline
        }
        if ($With.ContainsKey('Readiness')) {
            $readinessDir = Join-Path $featureDir 'readiness'
            New-Item -ItemType Directory -Path $readinessDir -Force | Out-Null
            $With.Readiness | Set-Content -LiteralPath (Join-Path $readinessDir 'readiness-assessment.md') -NoNewline
        }
        if ($With.ContainsKey('AnalysisChecklist')) {
            $With.AnalysisChecklist | Set-Content -LiteralPath (Join-Path $featureDir 'analysis-checklist.md') -NoNewline
        }

        return $featureDir
    }

    $script:cleanSpec = @"
# Feature Specification: Fixture

**Feature ID**: ``001-fixture``
**Version**: 1.0.0

## Functional Requirements

- **FR-001**: System MUST do X.
"@

    $script:specWithMarkers = @"
# Feature Specification: Fixture

**Feature ID**: ``001-fixture``
**Version**: 1.0.0

## Functional Requirements

- **FR-001**: System MUST do [NEEDS CLARIFICATION: which path?].
- **FR-002**: System MUST do [NEEDS CLARIFICATION: how often?].
"@

    $script:cleanPlan = @"
# Implementation Plan: Fixture

**Feature ID**: ``001-fixture``
**Version**: 1.0.0
"@

    $script:planWithoutVersion = @"
# Implementation Plan: Fixture

**Feature ID**: ``001-fixture``
"@

    $script:cleanTasks = @"
# Tasks: Fixture

**Feature ID**: ``001-fixture``
**Version**: 1.1.0

## Phase 1: Setup

- [ ] T001 [P1] [Risk: Low] [Story: Foundation] Initialize project skeleton
"@

    $script:cleanReadiness = @"
# Readiness Assessment: Fixture

**Date**: 2026-05-01
**Primary Status**: ``READY_FOR_PLAN``

## Planability vs Intent Obligations

- **Intent Ledger Requirement**: Not Required
"@
}

Describe 'setup-clarify entry gate' {
    It 'reports READY when spec.md exists with no markers' {
        $featureDir = New-FeatureFixture -With @{ Spec = $script:cleanSpec }
        $output = pwsh -NoProfile -File $script:setupClarify -FeatureDir $featureDir -Json
        $LASTEXITCODE | Should -Be 0
        $result = ($output | ConvertFrom-Json)
        $result.READY | Should -BeTrue
        $result.SPEC_VERSION | Should -Be '1.0.0'
        $result.CLARIFICATION_MARKERS.Count | Should -Be 0
    }

    It 'lists every NEEDS CLARIFICATION marker' {
        $featureDir = New-FeatureFixture -With @{ Spec = $script:specWithMarkers }
        $output = pwsh -NoProfile -File $script:setupClarify -FeatureDir $featureDir -Json
        $LASTEXITCODE | Should -Be 0
        $result = ($output | ConvertFrom-Json)
        $result.READY | Should -BeTrue
        $result.CLARIFICATION_MARKERS.Count | Should -Be 2
        $result.CLARIFICATION_MARKERS[0] | Should -Match 'which path'
    }

    It 'fails when spec.md is missing' {
        $featureDir = New-FeatureFixture
        $output = pwsh -NoProfile -File $script:setupClarify -FeatureDir $featureDir -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match 'spec\.md is required'
    }

    It 'still passes with -Force when spec.md is missing' {
        $featureDir = New-FeatureFixture
        $output = pwsh -NoProfile -File $script:setupClarify -FeatureDir $featureDir -Force -Json
        $LASTEXITCODE | Should -Be 0
        $result = ($output | ConvertFrom-Json)
        $result.READY | Should -BeTrue
        $result.FORCED | Should -BeTrue
        $result.BLOCKERS.Count | Should -BeGreaterThan 0
    }
}

Describe 'setup-readiness entry gate' {
    It 'scaffolds readiness-assessment.md when spec is clean' {
        $featureDir = New-FeatureFixture -With @{ Spec = $script:cleanSpec }
        $output = pwsh -NoProfile -File $script:setupReadiness -FeatureDir $featureDir -Json
        $LASTEXITCODE | Should -Be 0
        $result = ($output | ConvertFrom-Json)
        $result.READY | Should -BeTrue
        $result.SCAFFOLDED | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $featureDir 'readiness/readiness-assessment.md') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $featureDir 'readiness/eci') -PathType Container | Should -BeTrue
    }

    It 'blocks when spec.md still has [NEEDS CLARIFICATION] markers' {
        $featureDir = New-FeatureFixture -With @{ Spec = $script:specWithMarkers }
        $output = pwsh -NoProfile -File $script:setupReadiness -FeatureDir $featureDir -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match '\[NEEDS CLARIFICATION\]'
    }

    It 'leaves an existing readiness-assessment.md untouched' {
        $featureDir = New-FeatureFixture -With @{ Spec = $script:cleanSpec; Readiness = $script:cleanReadiness }
        $output = pwsh -NoProfile -File $script:setupReadiness -FeatureDir $featureDir -Json
        $LASTEXITCODE | Should -Be 0
        $result = ($output | ConvertFrom-Json)
        $result.SCAFFOLDED | Should -BeFalse
        ((Get-Content -LiteralPath (Join-Path $featureDir 'readiness/readiness-assessment.md') -Raw)) | Should -Match 'READY_FOR_PLAN'
    }

    It 'fails fast when spec.md is missing' {
        $featureDir = New-FeatureFixture
        $output = pwsh -NoProfile -File $script:setupReadiness -FeatureDir $featureDir -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match 'spec\.md is required'
    }
}

Describe 'setup-tasks entry gate' {
    It 'scaffolds tasks.md when plan.md exists with a Version' {
        $featureDir = New-FeatureFixture -With @{ Spec = $script:cleanSpec; Plan = $script:cleanPlan }
        $output = pwsh -NoProfile -File $script:setupTasks -FeatureDir $featureDir -Json
        $LASTEXITCODE | Should -Be 0
        $result = ($output | ConvertFrom-Json)
        $result.READY | Should -BeTrue
        $result.SCAFFOLDED | Should -BeTrue
        $result.PLAN_VERSION | Should -Be '1.0.0'
        Test-Path -LiteralPath (Join-Path $featureDir 'tasks.md') | Should -BeTrue
    }

    It 'blocks when plan.md is missing' {
        $featureDir = New-FeatureFixture -With @{ Spec = $script:cleanSpec }
        $output = pwsh -NoProfile -File $script:setupTasks -FeatureDir $featureDir -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match 'plan\.md is required'
    }

    It 'blocks when plan.md has no Version field' {
        $featureDir = New-FeatureFixture -With @{ Spec = $script:cleanSpec; Plan = $script:planWithoutVersion }
        $output = pwsh -NoProfile -File $script:setupTasks -FeatureDir $featureDir -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match 'no Version field'
    }

    It 'leaves an existing tasks.md untouched' {
        $featureDir = New-FeatureFixture -With @{ Spec = $script:cleanSpec; Plan = $script:cleanPlan; Tasks = $script:cleanTasks }
        $output = pwsh -NoProfile -File $script:setupTasks -FeatureDir $featureDir -Json
        $LASTEXITCODE | Should -Be 0
        $result = ($output | ConvertFrom-Json)
        $result.SCAFFOLDED | Should -BeFalse
    }
}

Describe 'setup-analyze entry gate' {
    It 'scaffolds analysis-checklist.md when all prior artifacts exist' {
        $featureDir = New-FeatureFixture -With @{
            Spec      = $script:cleanSpec
            Plan      = $script:cleanPlan
            Tasks     = $script:cleanTasks
            Readiness = $script:cleanReadiness
        }
        $output = pwsh -NoProfile -File $script:setupAnalyze -FeatureDir $featureDir -Json
        $LASTEXITCODE | Should -Be 0
        $result = ($output | ConvertFrom-Json)
        $result.READY | Should -BeTrue
        $result.SCAFFOLDED | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $featureDir 'analysis-checklist.md') | Should -BeTrue
    }

    It 'blocks when readiness is missing' {
        $featureDir = New-FeatureFixture -With @{
            Spec  = $script:cleanSpec
            Plan  = $script:cleanPlan
            Tasks = $script:cleanTasks
        }
        $output = pwsh -NoProfile -File $script:setupAnalyze -FeatureDir $featureDir -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match 'readiness-assessment\.md is required'
    }

    It 'blocks when tasks.md is missing' {
        $featureDir = New-FeatureFixture -With @{
            Spec      = $script:cleanSpec
            Plan      = $script:cleanPlan
            Readiness = $script:cleanReadiness
        }
        $output = pwsh -NoProfile -File $script:setupAnalyze -FeatureDir $featureDir -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match 'tasks\.md is required'
    }

    It 'invokes validate-feature-structure' {
        $featureDir = New-FeatureFixture -With @{
            Spec      = $script:cleanSpec
            Plan      = $script:cleanPlan
            Tasks     = $script:cleanTasks
            Readiness = $script:cleanReadiness
        }
        $output = pwsh -NoProfile -File $script:setupAnalyze -FeatureDir $featureDir -Json
        $LASTEXITCODE | Should -Be 0
        $result = ($output | ConvertFrom-Json)
        $result.STRUCTURE_VALID | Should -BeTrue
    }
}

Describe 'setup-implement entry gate' {
    It 'reports READY when tasks.md has at least one pending canonical task' {
        $featureDir = New-FeatureFixture -With @{
            Spec  = $script:cleanSpec
            Plan  = $script:cleanPlan
            Tasks = $script:cleanTasks
        }
        $output = pwsh -NoProfile -File $script:setupImplement -FeatureDir $featureDir -Json
        $LASTEXITCODE | Should -Be 0
        $result = ($output | ConvertFrom-Json)
        $result.READY | Should -BeTrue
        $result.PENDING_TASKS.Count | Should -BeGreaterThan 0
        $result.PENDING_TASKS[0].Id | Should -Be 'T001'
    }

    It 'blocks when tasks.md has no pending canonical tasks' {
        $tasksAllDone = @"
# Tasks: Fixture

**Version**: 1.1.0

- [x] T001 [P1] [Risk: Low] [Story: Foundation] Done already
"@
        $featureDir = New-FeatureFixture -With @{
            Spec  = $script:cleanSpec
            Plan  = $script:cleanPlan
            Tasks = $tasksAllDone
        }
        $output = pwsh -NoProfile -File $script:setupImplement -FeatureDir $featureDir -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match 'no pending canonical'
    }

    It 'rejects -Task when the requested ID is not pending' {
        $featureDir = New-FeatureFixture -With @{
            Spec  = $script:cleanSpec
            Plan  = $script:cleanPlan
            Tasks = $script:cleanTasks
        }
        $output = pwsh -NoProfile -File $script:setupImplement -FeatureDir $featureDir -Task 'T999' -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match 'is not pending'
    }

    It 'accepts a valid -Task ID' {
        $featureDir = New-FeatureFixture -With @{
            Spec  = $script:cleanSpec
            Plan  = $script:cleanPlan
            Tasks = $script:cleanTasks
        }
        $output = pwsh -NoProfile -File $script:setupImplement -FeatureDir $featureDir -Task 'T001' -Json
        $LASTEXITCODE | Should -Be 0
        $result = ($output | ConvertFrom-Json)
        $result.SELECTED_TASK.Id | Should -Be 'T001'
    }

    It 'blocks when analysis-checklist.md has unresolved Critical findings' {
        $criticalChecklist = @"
# Analysis Checklist: Fixture

## Findings

| ID | Severity | Finding | Resolution |
|----|----------|---------|------------|
| F001 | Critical | Missing test coverage for FR-002 | TBD |
"@
        $featureDir = New-FeatureFixture -With @{
            Spec              = $script:cleanSpec
            Plan              = $script:cleanPlan
            Tasks             = $script:cleanTasks
            AnalysisChecklist = $criticalChecklist
        }
        $output = pwsh -NoProfile -File $script:setupImplement -FeatureDir $featureDir -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match 'unresolved Critical finding'
    }

    It 'allows -Force to bypass blockers' {
        $featureDir = New-FeatureFixture
        $output = pwsh -NoProfile -File $script:setupImplement -FeatureDir $featureDir -Force -Json
        $LASTEXITCODE | Should -Be 0
        $result = ($output | ConvertFrom-Json)
        $result.READY | Should -BeTrue
        $result.FORCED | Should -BeTrue
    }
}

Describe 'stage-entry-gates JSON shape consistency' {
    It 'all five scripts emit STAGE/READY/FORCED/BLOCKERS/MESSAGES at minimum' {
        $featureDir = New-FeatureFixture -With @{
            Spec      = $script:cleanSpec
            Plan      = $script:cleanPlan
            Tasks     = $script:cleanTasks
            Readiness = $script:cleanReadiness
        }
        $scripts = @($script:setupClarify, $script:setupReadiness, $script:setupTasks, $script:setupAnalyze, $script:setupImplement)
        foreach ($s in $scripts) {
            $output = pwsh -NoProfile -File $s -FeatureDir $featureDir -Json
            $result = ($output | ConvertFrom-Json)
            $result.PSObject.Properties.Name | Should -Contain 'STAGE'
            $result.PSObject.Properties.Name | Should -Contain 'READY'
            $result.PSObject.Properties.Name | Should -Contain 'FORCED'
            $result.PSObject.Properties.Name | Should -Contain 'BLOCKERS'
            $result.PSObject.Properties.Name | Should -Contain 'MESSAGES'
        }
    }
}
