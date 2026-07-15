#!/usr/bin/env pwsh
#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/governance.config.ps1"

    $script:setupClarify   = Join-Path $WorkspaceRoot 'studio/scripts/powershell/setup-clarify.ps1'
    $script:setupReadiness = Join-Path $WorkspaceRoot 'studio/scripts/powershell/setup-readiness.ps1'
    $script:setupTasks     = Join-Path $WorkspaceRoot 'studio/scripts/powershell/setup-tasks.ps1'
    $script:setupAnalyze   = Join-Path $WorkspaceRoot 'studio/scripts/powershell/setup-analyze.ps1'
    $script:setupImplement = Join-Path $WorkspaceRoot 'studio/scripts/powershell/setup-implement.ps1'
    $script:analysisResultSchema = Join-Path $WorkspaceRoot 'studio/runtime/analysis-result.schema.json'

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
            New-Item -ItemType Directory -Path (Join-Path $readinessDir 'eci') -Force | Out-Null
            $With.Readiness | Set-Content -LiteralPath (Join-Path $readinessDir 'readiness-assessment.md') -NoNewline
        }
        if ($With.ContainsKey('IntentLedger')) {
            $With.IntentLedger | Set-Content -LiteralPath (Join-Path $featureDir 'intent-ledger.md') -NoNewline
        }
        if ($With.ContainsKey('AnalysisChecklist')) {
            $With.AnalysisChecklist | Set-Content -LiteralPath (Join-Path $featureDir 'analysis-checklist.md') -NoNewline
        }

        return $featureDir
    }

    function script:Get-TestArtifactBindingHash {
        param(
            [Parameter(Mandatory = $true)][string]$Path,
            [switch]$NormalizeTaskCheckboxes
        )

        if (-not $NormalizeTaskCheckboxes) {
            return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
        }

        $content = [System.IO.File]::ReadAllText($Path, [System.Text.UTF8Encoding]::new($false, $true))
        $normalized = [regex]::Replace(
            $content,
            '(?m)^(- )\[(?: |x|X)\](\s+T\d{3}\b)',
            '$1[ ]$2'
        )
        $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($normalized)
        $digest = [System.Security.Cryptography.SHA256]::HashData($bytes)
        return ([System.Convert]::ToHexString($digest)).ToLowerInvariant()
    }

    function script:Write-AnalysisResult {
        param(
            [Parameter(Mandatory = $true)][string]$FeatureDir,
            [string]$Outcome = 'IMPLEMENTATION_READY',
            [AllowEmptyCollection()][object[]]$CriticalFindings = @(),
            [string]$IntentDriftStatus = 'PASS',
            [string]$IntentStatus,
            [AllowEmptyCollection()][object[]]$IntentItems,
            [hashtable]$HashOverrides = @{},
            [string]$FeatureId
        )

        $intentLedgerPath = Join-Path $FeatureDir 'intent-ledger.md'
        $intentLedgerExists = Test-Path -LiteralPath $intentLedgerPath -PathType Leaf
        $eciArtifactPaths = [ordered]@{
            'readiness/eci-trigger.md' = Join-Path $FeatureDir 'readiness/eci-trigger.md'
            'readiness/eci/eci-assessment.md' = Join-Path $FeatureDir 'readiness/eci/eci-assessment.md'
            'readiness/eci/source-manifest.md' = Join-Path $FeatureDir 'readiness/eci/source-manifest.md'
            'readiness/eci/adoption-record.md' = Join-Path $FeatureDir 'readiness/eci/adoption-record.md'
            'readiness/eci/authorization-record.md' = Join-Path $FeatureDir 'readiness/eci/authorization-record.md'
        }
        $eciRequired = @($eciArtifactPaths.Values | Where-Object {
            Test-Path -LiteralPath $_ -PathType Leaf
        }).Count -gt 0
        if (-not $PSBoundParameters.ContainsKey('IntentStatus')) {
            $IntentStatus = if ($intentLedgerExists) { 'ACCOUNTED' } else { 'NOT_REQUIRED' }
        }
        if (-not $PSBoundParameters.ContainsKey('IntentItems')) {
            $IntentItems = if ($intentLedgerExists) {
                @([ordered]@{
                    sourceIntentItem = 'FR-002'
                    classification   = 'deferred'
                    status           = 'ACCOUNTED'
                    evidence         = 'Tracked by the current intent ledger and plan obligations.'
                })
            } else {
                @()
            }
        }

        $hashes = [ordered]@{
            'spec.md' = Get-TestArtifactBindingHash -Path (Join-Path $FeatureDir 'spec.md')
            'readiness/readiness-assessment.md' = Get-TestArtifactBindingHash -Path (Join-Path $FeatureDir 'readiness/readiness-assessment.md')
            'readiness/eci-trigger.md' = if (Test-Path -LiteralPath $eciArtifactPaths['readiness/eci-trigger.md'] -PathType Leaf) { Get-TestArtifactBindingHash -Path $eciArtifactPaths['readiness/eci-trigger.md'] } else { $null }
            'readiness/eci/eci-assessment.md' = if (Test-Path -LiteralPath $eciArtifactPaths['readiness/eci/eci-assessment.md'] -PathType Leaf) { Get-TestArtifactBindingHash -Path $eciArtifactPaths['readiness/eci/eci-assessment.md'] } else { $null }
            'readiness/eci/source-manifest.md' = if (Test-Path -LiteralPath $eciArtifactPaths['readiness/eci/source-manifest.md'] -PathType Leaf) { Get-TestArtifactBindingHash -Path $eciArtifactPaths['readiness/eci/source-manifest.md'] } else { $null }
            'readiness/eci/adoption-record.md' = if (Test-Path -LiteralPath $eciArtifactPaths['readiness/eci/adoption-record.md'] -PathType Leaf) { Get-TestArtifactBindingHash -Path $eciArtifactPaths['readiness/eci/adoption-record.md'] } else { $null }
            'readiness/eci/authorization-record.md' = if (Test-Path -LiteralPath $eciArtifactPaths['readiness/eci/authorization-record.md'] -PathType Leaf) { Get-TestArtifactBindingHash -Path $eciArtifactPaths['readiness/eci/authorization-record.md'] } else { $null }
            'intent-ledger.md' = if ($intentLedgerExists) { Get-TestArtifactBindingHash -Path $intentLedgerPath } else { $null }
            'plan.md' = Get-TestArtifactBindingHash -Path (Join-Path $FeatureDir 'plan.md')
            'tasks.md' = Get-TestArtifactBindingHash -Path (Join-Path $FeatureDir 'tasks.md') -NormalizeTaskCheckboxes
        }
        foreach ($key in $HashOverrides.Keys) {
            $hashes[$key] = $HashOverrides[$key]
        }

        $normalizedCriticalFindings = [object[]]@($CriticalFindings | Where-Object { $null -ne $_ })
        $normalizedIntentItems = [object[]]@($IntentItems | Where-Object { $null -ne $_ })
        $document = [ordered]@{
            schemaVersion = '1.0.0'
            featureId = if ($FeatureId) { $FeatureId } else { Split-Path -Leaf $FeatureDir }
            outcome = $Outcome
            eciRequired = $eciRequired
            artifactHashes = $hashes
            criticalFindings = $normalizedCriticalFindings
            intentDriftCheck = [ordered]@{
                status = $IntentDriftStatus
                summary = if ($IntentDriftStatus -eq 'PASS') { 'Intent drift checks passed.' } else { 'Intent drift remains unresolved.' }
            }
            intentObligations = [ordered]@{
                status = $IntentStatus
                items = $normalizedIntentItems
            }
        }

        $path = Join-Path $FeatureDir 'analysis-result.json'
        $document | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $path -Encoding utf8
        return $path
    }

    function script:New-ImplementGateHarness {
        param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$ValidatorBody)

        $root = Join-Path $TestDrive ("implement-harness-{0}" -f ([System.Guid]::NewGuid().ToString('N')))
        $scriptsDir = Join-Path $root 'studio/scripts/powershell'
        $runtimeDir = Join-Path $root 'studio/runtime'
        New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
        New-Item -ItemType Directory -Path $runtimeDir -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $root 'studio/constitution') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $root 'studio/constitution/constitution.md') -Value '# fixture' -Encoding utf8
        Copy-Item -LiteralPath (Join-Path $WorkspaceRoot 'studio/scripts/powershell/common.ps1') -Destination (Join-Path $scriptsDir 'common.ps1')
        Copy-Item -LiteralPath $script:setupImplement -Destination (Join-Path $scriptsDir 'setup-implement.ps1')
        Copy-Item -LiteralPath $script:analysisResultSchema -Destination (Join-Path $runtimeDir 'analysis-result.schema.json')
        @"
param([string]`$FeatureDir, [switch]`$Json)
$ValidatorBody
"@ | Set-Content -LiteralPath (Join-Path $scriptsDir 'validate-feature-structure.ps1') -Encoding utf8
        return (Join-Path $scriptsDir 'setup-implement.ps1')
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
        $result.ANALYSIS_RESULT | Should -Be (Join-Path $featureDir 'analysis-result.json')
        $result.ANALYSIS_RESULT_SCHEMA | Should -Be $script:analysisResultSchema
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

    It 'advertises the trusted Analyze schema beside setup-analyze despite SDD_STUDIO_ROOT' {
        $featureDir = New-FeatureFixture -With @{
            Spec      = $script:cleanSpec
            Plan      = $script:cleanPlan
            Tasks     = $script:cleanTasks
            Readiness = $script:cleanReadiness
        }
        $untrustedStudio = Join-Path $TestDrive ("untrusted-analyze-studio-{0}" -f ([guid]::NewGuid().ToString('N')))
        New-Item -ItemType Directory -Path (Join-Path $untrustedStudio 'runtime') -Force | Out-Null
        '{}' | Set-Content -LiteralPath (Join-Path $untrustedStudio 'runtime/analysis-result.schema.json')

        $priorStudioRoot = $env:SDD_STUDIO_ROOT
        try {
            $env:SDD_STUDIO_ROOT = $untrustedStudio
            $output = pwsh -NoProfile -File $script:setupAnalyze -FeatureDir $featureDir -Json
            $LASTEXITCODE | Should -Be 0
        } finally {
            $env:SDD_STUDIO_ROOT = $priorStudioRoot
        }
        (($output -join "`n") | ConvertFrom-Json).ANALYSIS_RESULT_SCHEMA | Should -Be $script:analysisResultSchema
    }
}

Describe 'setup-implement entry gate' {
    BeforeAll {
        $script:completeChecklist = @"
# Analysis Checklist: Fixture

## Legacy Analyze Gate
**Analysis Status**: COMPLETE
"@

        $script:twoPendingTasks = @"
# Tasks: Fixture

**Feature ID**: ``001-fixture``
**Version**: 1.1.0

- [ ] T001 [P1] [Risk: Low] [Story: Foundation] Initialize project skeleton
- [ ] T002 [P1] [Risk: Low] [Story: Foundation] Add verification
"@

        $script:canonicalIntentLedger = @"
# Intent Ledger

| source_intent_item | spec_anchor | current_classification | current_representation | defer_or_drop_reason | reentry_trigger | follow_on_feature_hint | surface_disclosure_required | owner_signoff_required |
|--------------------|-------------|------------------------|------------------------|----------------------|-----------------|------------------------|-----------------------------|------------------------|
| FR-002 | FR-002 | deferred | None in current scope | Deferred to preserve the approved scope | Revisit when dependency lands | 002-follow-on | yes | no |
"@

        function script:Add-EciDossier {
            param(
                [Parameter(Mandatory = $true)][string]$FeatureDir,
                [string]$AuthorizationOutcome = 'READY_FOR_MAINLINE_IMPLEMENTATION'
            )

            $eciDir = Join-Path $FeatureDir 'readiness/eci'
            New-Item -ItemType Directory -Path $eciDir -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $FeatureDir 'readiness/eci-trigger.md') -Value "# ECI Trigger`n" -Encoding utf8
            Set-Content -LiteralPath (Join-Path $eciDir 'eci-assessment.md') -Value "# ECI Assessment`n" -Encoding utf8
            Set-Content -LiteralPath (Join-Path $eciDir 'source-manifest.md') -Value "# Source Manifest`n" -Encoding utf8
            Set-Content -LiteralPath (Join-Path $eciDir 'adoption-record.md') -Value "# Adoption Record`n" -Encoding utf8
            Set-Content -LiteralPath (Join-Path $eciDir 'authorization-record.md') -Value @"
# Authorization Record

**Authorization Outcome**: ``$AuthorizationOutcome``
"@ -Encoding utf8
        }
    }

    It 'reports READY only from a schema-valid current machine result' {
        $featureDir = New-FeatureFixture -With @{
            Spec              = $script:cleanSpec
            Plan              = $script:cleanPlan
            Tasks             = $script:cleanTasks
            Readiness         = $script:cleanReadiness
            AnalysisChecklist = $script:completeChecklist
        }
        Write-AnalysisResult -FeatureDir $featureDir | Out-Null
        $output = pwsh -NoProfile -File $script:setupImplement -FeatureDir $featureDir -Json
        $LASTEXITCODE | Should -Be 0
        $result = ($output | ConvertFrom-Json)
        $result.READY | Should -BeTrue
        $result.ANALYZE_STATE | Should -Be 'complete'
        $result.PENDING_TASKS.Count | Should -BeGreaterThan 0
        $result.PENDING_TASKS[0].Id | Should -Be 'T001'
    }

    It 'permits zero pending tasks only for terminal completion revalidation' {
        $featureDir = New-FeatureFixture -With @{
            Spec              = $script:cleanSpec
            Plan              = $script:cleanPlan
            Tasks             = $script:cleanTasks
            Readiness         = $script:cleanReadiness
            AnalysisChecklist = $script:completeChecklist
        }
        Write-AnalysisResult -FeatureDir $featureDir | Out-Null
        (Get-Content -LiteralPath (Join-Path $featureDir 'tasks.md') -Raw) -replace '\- \[ \]', '- [x]' |
            Set-Content -LiteralPath (Join-Path $featureDir 'tasks.md') -NoNewline

        $normalOutput = pwsh -NoProfile -File $script:setupImplement -FeatureDir $featureDir -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        (($normalOutput -join "`n") | ConvertFrom-Json).BLOCKERS -join "`n" | Should -Match 'no pending canonical'

        $completionOutput = pwsh -NoProfile -File $script:setupImplement -FeatureDir $featureDir -CompletionValidation -Json
        $LASTEXITCODE | Should -Be 0
        $completionResult = ($completionOutput -join "`n") | ConvertFrom-Json
        $completionResult.READY | Should -BeTrue
        $completionResult.COMPLETION_VALIDATION | Should -BeTrue
        @($completionResult.PENDING_TASKS).Count | Should -Be 0
    }

    It 'rejects a forged COMPLETE Markdown checklist when analysis-result.json is missing' {
        $featureDir = New-FeatureFixture -With @{
            Spec              = $script:cleanSpec
            Plan              = $script:cleanPlan
            Tasks             = $script:cleanTasks
            Readiness         = $script:cleanReadiness
            AnalysisChecklist = $script:completeChecklist
        }
        $output = pwsh -NoProfile -File $script:setupImplement -FeatureDir $featureDir -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        $result.READY | Should -BeFalse
        $result.ANALYZE_STATE | Should -Be 'missing'
        ($result.BLOCKERS -join "`n") | Should -Match 'analyze has not run|analysis-result\.json is missing'
    }

    It 'returns structured blockers for malformed analysis-result JSON' {
        $featureDir = New-FeatureFixture -With @{
            Spec              = $script:cleanSpec
            Plan              = $script:cleanPlan
            Tasks             = $script:cleanTasks
            Readiness         = $script:cleanReadiness
            AnalysisChecklist = $script:completeChecklist
        }
        Set-Content -LiteralPath (Join-Path $featureDir 'analysis-result.json') -Value '{not-json' -Encoding utf8
        $output = pwsh -NoProfile -File $script:setupImplement -FeatureDir $featureDir -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        $result.ANALYZE_STATE | Should -Be 'invalid'
        ($result.BLOCKERS -join "`n") | Should -Match 'invalid JSON'
    }

    It 'returns structured blockers when analysis-result violates its schema' {
        $featureDir = New-FeatureFixture -With @{
            Spec              = $script:cleanSpec
            Plan              = $script:cleanPlan
            Tasks             = $script:cleanTasks
            Readiness         = $script:cleanReadiness
            AnalysisChecklist = $script:completeChecklist
        }
        Set-Content -LiteralPath (Join-Path $featureDir 'analysis-result.json') -Value '[]' -Encoding utf8
        $output = pwsh -NoProfile -File $script:setupImplement -FeatureDir $featureDir -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        $result.ANALYZE_STATE | Should -Be 'invalid'
        ($result.BLOCKERS -join "`n") | Should -Match 'schema|conform'
    }

    It 'rejects a stale machine result after an analyzed plan changes' {
        $featureDir = New-FeatureFixture -With @{
            Spec              = $script:cleanSpec
            Plan              = $script:cleanPlan
            Tasks             = $script:cleanTasks
            Readiness         = $script:cleanReadiness
            AnalysisChecklist = $script:completeChecklist
        }
        Write-AnalysisResult -FeatureDir $featureDir | Out-Null
        Add-Content -LiteralPath (Join-Path $featureDir 'plan.md') -Value "`n## Changed after Analyze`n"
        $output = pwsh -NoProfile -File $script:setupImplement -FeatureDir $featureDir -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        ($result.BLOCKERS -join "`n") | Should -Match 'hash mismatch for plan\.md'
    }

    It 'keeps Analyze evidence current when only canonical task checkboxes progress' {
        $featureDir = New-FeatureFixture -With @{
            Spec              = $script:cleanSpec
            Plan              = $script:cleanPlan
            Tasks             = $script:twoPendingTasks
            Readiness         = $script:cleanReadiness
            AnalysisChecklist = $script:completeChecklist
        }
        Write-AnalysisResult -FeatureDir $featureDir | Out-Null
        $tasksPath = Join-Path $featureDir 'tasks.md'
        $tasks = Get-Content -LiteralPath $tasksPath -Raw
        $tasks = $tasks -replace '(?m)^- \[ \] T001\b', '- [x] T001'
        Set-Content -LiteralPath $tasksPath -Value $tasks -NoNewline -Encoding utf8
        $output = pwsh -NoProfile -File $script:setupImplement -FeatureDir $featureDir -Json
        $LASTEXITCODE | Should -Be 0
        $result = ($output | ConvertFrom-Json)
        $result.READY | Should -BeTrue
        @($result.PENDING_TASKS.Id) | Should -Contain 'T002'
    }

    It 'invalidates Analyze evidence when a task definition changes' {
        $featureDir = New-FeatureFixture -With @{
            Spec              = $script:cleanSpec
            Plan              = $script:cleanPlan
            Tasks             = $script:twoPendingTasks
            Readiness         = $script:cleanReadiness
            AnalysisChecklist = $script:completeChecklist
        }
        Write-AnalysisResult -FeatureDir $featureDir | Out-Null
        $tasksPath = Join-Path $featureDir 'tasks.md'
        $tasks = (Get-Content -LiteralPath $tasksPath -Raw) -replace 'Initialize project skeleton', 'Replace project skeleton'
        Set-Content -LiteralPath $tasksPath -Value $tasks -NoNewline -Encoding utf8
        $output = pwsh -NoProfile -File $script:setupImplement -FeatureDir $featureDir -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        ($result.BLOCKERS -join "`n") | Should -Match 'hash mismatch for tasks\.md'
    }

    It 'blocks machine-readable unresolved Critical findings even when Markdown claims COMPLETE' {
        $featureDir = New-FeatureFixture -With @{
            Spec              = $script:cleanSpec
            Plan              = $script:cleanPlan
            Tasks             = $script:cleanTasks
            Readiness         = $script:cleanReadiness
            AnalysisChecklist = $script:completeChecklist
        }
        $critical = @([ordered]@{
            id = 'C001'
            status = 'OPEN'
            summary = 'Critical coverage is missing.'
            resolution = 'Implementation remains blocked pending remediation.'
        })
        Write-AnalysisResult -FeatureDir $featureDir -Outcome BLOCKED -CriticalFindings $critical | Out-Null
        $output = pwsh -NoProfile -File $script:setupImplement -FeatureDir $featureDir -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        ($result.BLOCKERS -join "`n") | Should -Match 'unresolved Critical finding \[C001\]'
    }

    It 'blocks a failed Intent Drift Check' {
        $featureDir = New-FeatureFixture -With @{
            Spec              = $script:cleanSpec
            Plan              = $script:cleanPlan
            Tasks             = $script:cleanTasks
            Readiness         = $script:cleanReadiness
            AnalysisChecklist = $script:completeChecklist
        }
        Write-AnalysisResult -FeatureDir $featureDir -Outcome BLOCKED -IntentDriftStatus FAIL | Out-Null
        $output = pwsh -NoProfile -File $script:setupImplement -FeatureDir $featureDir -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        ($result.BLOCKERS -join "`n") | Should -Match 'Intent Drift Check is'
    }

    It 'requires machine-readable accounting when intent-ledger.md exists' {
        $readiness = $script:cleanReadiness -replace 'Not Required', 'Update ``intent-ledger.md``'
        $featureDir = New-FeatureFixture -With @{
            Spec              = $script:cleanSpec
            Plan              = $script:cleanPlan
            Tasks             = $script:cleanTasks
            Readiness         = $readiness
            IntentLedger      = $script:canonicalIntentLedger
            AnalysisChecklist = $script:completeChecklist
        }
        Write-AnalysisResult -FeatureDir $featureDir -IntentStatus NOT_REQUIRED -IntentItems @() | Out-Null
        $output = pwsh -NoProfile -File $script:setupImplement -FeatureDir $featureDir -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        ($result.BLOCKERS -join "`n") | Should -Match 'does not account for its intent obligations'
    }

    It 'accepts exactly one accounted machine obligation for each intent-ledger row' {
        $readiness = $script:cleanReadiness -replace 'Not Required', 'Update ``intent-ledger.md``'
        $featureDir = New-FeatureFixture -With @{
            Spec              = $script:cleanSpec
            Plan              = $script:cleanPlan
            Tasks             = $script:cleanTasks
            Readiness         = $readiness
            IntentLedger      = $script:canonicalIntentLedger
            AnalysisChecklist = $script:completeChecklist
        }
        Write-AnalysisResult -FeatureDir $featureDir | Out-Null
        $output = pwsh -NoProfile -File $script:setupImplement -FeatureDir $featureDir -Json
        $LASTEXITCODE | Should -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        $result.READY | Should -BeTrue
    }

    It 'rejects an intent ledger whose header omits canonical columns' {
        $intentLedger = @"
# Intent Ledger

| source_intent_item | spec_anchor | current_classification |
|--------------------|-------------|------------------------|
| FR-002 | FR-002 | deferred |
"@
        $readiness = $script:cleanReadiness -replace 'Not Required', 'Update ``intent-ledger.md``'
        $featureDir = New-FeatureFixture -With @{
            Spec = $script:cleanSpec; Plan = $script:cleanPlan; Tasks = $script:cleanTasks
            Readiness = $readiness; IntentLedger = $intentLedger; AnalysisChecklist = $script:completeChecklist
        }
        Write-AnalysisResult -FeatureDir $featureDir | Out-Null

        $output = pwsh -NoProfile -File $script:setupImplement -FeatureDir $featureDir -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        (($output -join "`n") | ConvertFrom-Json).BLOCKERS -join "`n" | Should -Match 'canonical nine columns'
    }

    It 'rejects an undersized intent ledger data row instead of silently ignoring it' {
        $intentLedger = $script:canonicalIntentLedger + "`n| FR-003 | FR-003 |"
        $readiness = $script:cleanReadiness -replace 'Not Required', 'Update ``intent-ledger.md``'
        $featureDir = New-FeatureFixture -With @{
            Spec = $script:cleanSpec; Plan = $script:cleanPlan; Tasks = $script:cleanTasks
            Readiness = $readiness; IntentLedger = $intentLedger; AnalysisChecklist = $script:completeChecklist
        }
        Write-AnalysisResult -FeatureDir $featureDir | Out-Null

        $output = pwsh -NoProfile -File $script:setupImplement -FeatureDir $featureDir -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        (($output -join "`n") | ConvertFrom-Json).BLOCKERS -join "`n" | Should -Match 'has 2 columns; exactly nine'
    }

    It 'rejects an invalid intent classification instead of silently ignoring the row' {
        $intentLedger = $script:canonicalIntentLedger + "`n| FR-003 | FR-003 | postponed | None | Later | Trigger | 003-follow-on | yes | no |"
        $readiness = $script:cleanReadiness -replace 'Not Required', 'Update ``intent-ledger.md``'
        $featureDir = New-FeatureFixture -With @{
            Spec = $script:cleanSpec; Plan = $script:cleanPlan; Tasks = $script:cleanTasks
            Readiness = $readiness; IntentLedger = $intentLedger; AnalysisChecklist = $script:completeChecklist
        }
        Write-AnalysisResult -FeatureDir $featureDir | Out-Null

        $output = pwsh -NoProfile -File $script:setupImplement -FeatureDir $featureDir -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        (($output -join "`n") | ConvertFrom-Json).BLOCKERS -join "`n" | Should -Match "invalid current_classification 'postponed'"
    }

    It 'rejects a placeholder intent row instead of silently ignoring it' {
        $intentLedger = $script:canonicalIntentLedger + "`n| [source] | FR-003 | deferred | None | Later | Trigger | 003-follow-on | yes | no |"
        $readiness = $script:cleanReadiness -replace 'Not Required', 'Update ``intent-ledger.md``'
        $featureDir = New-FeatureFixture -With @{
            Spec = $script:cleanSpec; Plan = $script:cleanPlan; Tasks = $script:cleanTasks
            Readiness = $readiness; IntentLedger = $intentLedger; AnalysisChecklist = $script:completeChecklist
        }
        Write-AnalysisResult -FeatureDir $featureDir | Out-Null

        $output = pwsh -NoProfile -File $script:setupImplement -FeatureDir $featureDir -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        (($output -join "`n") | ConvertFrom-Json).BLOCKERS -join "`n" | Should -Match 'empty or placeholder canonical cell.*source_intent_item'
    }

    It 'rejects a nine-column deferred row with a placeholder reentry trigger' {
        $intentLedger = $script:canonicalIntentLedger -replace 'Revisit when dependency lands', '[trigger]'
        $readiness = $script:cleanReadiness -replace 'Not Required', 'Update ``intent-ledger.md``'
        $featureDir = New-FeatureFixture -With @{
            Spec = $script:cleanSpec; Plan = $script:cleanPlan; Tasks = $script:cleanTasks
            Readiness = $readiness; IntentLedger = $intentLedger; AnalysisChecklist = $script:completeChecklist
        }
        Write-AnalysisResult -FeatureDir $featureDir | Out-Null

        $output = pwsh -NoProfile -File $script:setupImplement -FeatureDir $featureDir -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        (($output -join "`n") | ConvertFrom-Json).BLOCKERS -join "`n" | Should -Match 'empty or placeholder canonical cell.*reentry_trigger'
    }

    It 'fails closed when readiness evidence is removed after Analyze' {
        $featureDir = New-FeatureFixture -With @{
            Spec              = $script:cleanSpec
            Plan              = $script:cleanPlan
            Tasks             = $script:cleanTasks
            Readiness         = $script:cleanReadiness
            AnalysisChecklist = $script:completeChecklist
        }
        Write-AnalysisResult -FeatureDir $featureDir | Out-Null
        Remove-Item -LiteralPath (Join-Path $featureDir 'readiness') -Recurse -Force
        $output = pwsh -NoProfile -File $script:setupImplement -FeatureDir $featureDir -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        ($result.BLOCKERS -join "`n") | Should -Match 'readiness-dir-missing|readiness-assessment\.md is required'
    }

    It 'fails closed when the readiness ECI container is removed' {
        $featureDir = New-FeatureFixture -With @{
            Spec              = $script:cleanSpec
            Plan              = $script:cleanPlan
            Tasks             = $script:cleanTasks
            Readiness         = $script:cleanReadiness
            AnalysisChecklist = $script:completeChecklist
        }
        Write-AnalysisResult -FeatureDir $featureDir | Out-Null
        Remove-Item -LiteralPath (Join-Path $featureDir 'readiness/eci') -Recurse -Force
        $output = pwsh -NoProfile -File $script:setupImplement -FeatureDir $featureDir -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        ($result.BLOCKERS -join "`n") | Should -Match 'eci-dir-missing'
    }

    It 'denies a non-mainline ECI authorization even when readiness says READY_FOR_PLAN' {
        $featureDir = New-FeatureFixture -With @{
            Spec              = $script:cleanSpec
            Plan              = $script:cleanPlan
            Tasks             = $script:cleanTasks
            Readiness         = $script:cleanReadiness
            AnalysisChecklist = $script:completeChecklist
        }
        Add-EciDossier -FeatureDir $featureDir -AuthorizationOutcome READY_FOR_SANDBOX_ONLY
        Write-AnalysisResult -FeatureDir $featureDir | Out-Null
        $output = pwsh -NoProfile -File $script:setupImplement -FeatureDir $featureDir -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        ($result.BLOCKERS -join "`n") | Should -Match 'READY_FOR_SANDBOX_ONLY.*not authorized'
    }

    It 'accepts complete Analyze-bound ECI evidence for mainline implementation' {
        $featureDir = New-FeatureFixture -With @{
            Spec = $script:cleanSpec; Plan = $script:cleanPlan; Tasks = $script:cleanTasks
            Readiness = $script:cleanReadiness; AnalysisChecklist = $script:completeChecklist
        }
        Add-EciDossier -FeatureDir $featureDir
        Write-AnalysisResult -FeatureDir $featureDir | Out-Null

        $output = pwsh -NoProfile -File $script:setupImplement -FeatureDir $featureDir -Json
        $LASTEXITCODE | Should -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        $result.READY | Should -BeTrue
        $result.ECI_REQUIRED | Should -BeTrue
        $result.ECI_AUTHORIZATION | Should -Be 'READY_FOR_MAINLINE_IMPLEMENTATION'
    }

    It 'denies completion when all Analyze-bound ECI evidence is deleted' {
        $featureDir = New-FeatureFixture -With @{
            Spec = $script:cleanSpec; Plan = $script:cleanPlan; Tasks = $script:cleanTasks
            Readiness = $script:cleanReadiness; AnalysisChecklist = $script:completeChecklist
        }
        Add-EciDossier -FeatureDir $featureDir
        Write-AnalysisResult -FeatureDir $featureDir | Out-Null
        (Get-Content -LiteralPath (Join-Path $featureDir 'tasks.md') -Raw) -replace '\- \[ \]', '- [x]' |
            Set-Content -LiteralPath (Join-Path $featureDir 'tasks.md') -NoNewline
        Remove-Item -LiteralPath (Join-Path $featureDir 'readiness/eci-trigger.md') -Force
        Get-ChildItem -LiteralPath (Join-Path $featureDir 'readiness/eci') -File | Remove-Item -Force

        $output = pwsh -NoProfile -File $script:setupImplement -FeatureDir $featureDir -CompletionValidation -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        $result.READY | Should -BeFalse
        $result.ECI_REQUIRED | Should -BeTrue
        ($result.BLOCKERS -join "`n") | Should -Match 'ECI requirement.*contradicts|records required ECI evidence'
    }

    It 'denies stale Analyze-bound ECI evidence after a dossier file changes' {
        $featureDir = New-FeatureFixture -With @{
            Spec = $script:cleanSpec; Plan = $script:cleanPlan; Tasks = $script:cleanTasks
            Readiness = $script:cleanReadiness; AnalysisChecklist = $script:completeChecklist
        }
        Add-EciDossier -FeatureDir $featureDir
        Write-AnalysisResult -FeatureDir $featureDir | Out-Null
        Add-Content -LiteralPath (Join-Path $featureDir 'readiness/eci/eci-assessment.md') -Value 'Tampered after Analyze.'

        $output = pwsh -NoProfile -File $script:setupImplement -FeatureDir $featureDir -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        (($output -join "`n") | ConvertFrom-Json).BLOCKERS -join "`n" |
            Should -Match 'hash mismatch for readiness/eci/eci-assessment\.md'
    }

    It 'rejects -Task when the requested ID is not pending' {
        $featureDir = New-FeatureFixture -With @{
            Spec              = $script:cleanSpec
            Plan              = $script:cleanPlan
            Tasks             = $script:cleanTasks
            Readiness         = $script:cleanReadiness
            AnalysisChecklist = $script:completeChecklist
        }
        Write-AnalysisResult -FeatureDir $featureDir | Out-Null
        $output = pwsh -NoProfile -File $script:setupImplement -FeatureDir $featureDir -Task T999 -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        ($result.BLOCKERS -join "`n") | Should -Match 'is not pending'
    }

    It 'has no -Force parameter and rejects the former bypass' {
        (Get-Command $script:setupImplement).Parameters.Keys | Should -Not -Contain 'Force'
        $featureDir = New-FeatureFixture
        $output = pwsh -NoProfile -File $script:setupImplement -FeatureDir $featureDir -Force -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match 'parameter.*Force|Force.*parameter'
    }

    It 'fails closed with structured JSON when the structure validator returns no result' {
        $featureDir = New-FeatureFixture -With @{
            Spec              = $script:cleanSpec
            Plan              = $script:cleanPlan
            Tasks             = $script:cleanTasks
            Readiness         = $script:cleanReadiness
            AnalysisChecklist = $script:completeChecklist
        }
        Write-AnalysisResult -FeatureDir $featureDir | Out-Null
        $harness = New-ImplementGateHarness -ValidatorBody ''
        $output = pwsh -NoProfile -File $harness -FeatureDir $featureDir -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        $result.STRUCTURE_VALID | Should -BeNullOrEmpty
        ($result.BLOCKERS -join "`n") | Should -Match 'returned no machine-readable result'
    }

    It 'fails closed with structured JSON when the structure validator returns malformed JSON' {
        $featureDir = New-FeatureFixture -With @{
            Spec              = $script:cleanSpec
            Plan              = $script:cleanPlan
            Tasks             = $script:cleanTasks
            Readiness         = $script:cleanReadiness
            AnalysisChecklist = $script:completeChecklist
        }
        Write-AnalysisResult -FeatureDir $featureDir | Out-Null
        $harness = New-ImplementGateHarness -ValidatorBody "Write-Output 'not-json'"
        $output = pwsh -NoProfile -File $harness -FeatureDir $featureDir -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        $result.STRUCTURE_VALID | Should -BeNullOrEmpty
        ($result.BLOCKERS -join "`n") | Should -Match 'returned invalid JSON'
    }

    It 'fails closed when the structure validator emits VALID true but exits nonzero' {
        $featureDir = New-FeatureFixture -With @{
            Spec              = $script:cleanSpec
            Plan              = $script:cleanPlan
            Tasks             = $script:cleanTasks
            Readiness         = $script:cleanReadiness
            AnalysisChecklist = $script:completeChecklist
        }
        Write-AnalysisResult -FeatureDir $featureDir | Out-Null
        $validatorBody = @'
[pscustomobject]@{ VALID = $true; ERROR_COUNT = 0; WARNING_COUNT = 0; ERRORS = @(); WARNINGS = @() } | ConvertTo-Json -Compress
exit 9
'@
        $harness = New-ImplementGateHarness -ValidatorBody $validatorBody
        $output = pwsh -NoProfile -File $harness -FeatureDir $featureDir -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        $result.STRUCTURE_VALID | Should -BeNullOrEmpty
        ($result.BLOCKERS -join "`n") | Should -Match 'exited with code 9'
    }

    It 'anchors Analyze schema validation to the trusted runtime beside setup-implement' {
        $featureDir = New-FeatureFixture -With @{
            Spec              = $script:cleanSpec
            Plan              = $script:cleanPlan
            Tasks             = $script:cleanTasks
            Readiness         = $script:cleanReadiness
            AnalysisChecklist = $script:completeChecklist
        }
        $analysisPath = Write-AnalysisResult -FeatureDir $featureDir
        $analysis = Get-Content -LiteralPath $analysisPath -Raw | ConvertFrom-Json -AsHashtable
        $analysis['forgedExtraProperty'] = $true
        $analysis | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $analysisPath -Encoding utf8

        $untrustedStudio = Join-Path $TestDrive ("untrusted-studio-{0}" -f ([guid]::NewGuid().ToString('N')))
        New-Item -ItemType Directory -Path (Join-Path $untrustedStudio 'runtime') -Force | Out-Null
        '{"$schema":"https://json-schema.org/draft/2020-12/schema","type":"object"}' |
            Set-Content -LiteralPath (Join-Path $untrustedStudio 'runtime/analysis-result.schema.json') -Encoding utf8

        $priorStudioRoot = $env:SDD_STUDIO_ROOT
        try {
            $env:SDD_STUDIO_ROOT = $untrustedStudio
            $output = pwsh -NoProfile -File $script:setupImplement -FeatureDir $featureDir -Json 2>&1
            $LASTEXITCODE | Should -Not -Be 0
        } finally {
            $env:SDD_STUDIO_ROOT = $priorStudioRoot
        }
        $result = ($output -join "`n") | ConvertFrom-Json
        $result.ANALYSIS_RESULT_SCHEMA | Should -Be $script:analysisResultSchema
        ($result.BLOCKERS -join "`n") | Should -Match 'does not conform|schema validation failed'
    }
}

Describe 'direct /speckit.implement entrypoint' {
    BeforeAll {
        $script:implementAgentSource = Join-Path $WorkspaceRoot '.github/agents/speckit.implement.agent.md'
        $script:implementAgentMirror = Join-Path $WorkspaceRoot '.claude/agents/speckit-implement.md'
        $script:analyzeAgentSource = Join-Path $WorkspaceRoot '.github/agents/speckit.analyze.agent.md'
    }

    It 'makes setup-implement.ps1 the first canonical Implement action' {
        $content = Get-Content -LiteralPath $script:implementAgentSource -Raw
        $firstAction = [regex]::Match($content, '(?ms)^## Outline\s*\r?\n\s*1\.\s*(?<body>.*?)(?=\r?\n\s*2\.)')
        $firstAction.Success | Should -BeTrue
        $firstAction.Groups['body'].Value | Should -Match 'setup-implement\.ps1 -Json'
        $firstAction.Groups['body'].Value | Should -Match 'before reading implementation artifacts.*changing any file'
        $firstAction.Groups['body'].Value | Should -Match 'no `-Force` bypass'
        $firstAction.Groups['body'].Value | Should -Not -Match 'check-prerequisites\.ps1'
    }

    It 'seeds the same non-bypassable first action into the Claude mirror' {
        $content = Get-Content -LiteralPath $script:implementAgentMirror -Raw
        $firstAction = [regex]::Match($content, '(?ms)^## Outline\s*\r?\n\s*1\.\s*(?<body>.*?)(?=\r?\n\s*2\.)')
        $firstAction.Success | Should -BeTrue
        $firstAction.Groups['body'].Value | Should -Match 'setup-implement\.ps1 -Json'
        $firstAction.Groups['body'].Value | Should -Match 'no `-Force` bypass'
    }

    It 'keeps Analyze read-only while requiring the canonical result schema and task-definition hash' {
        $content = Get-Content -LiteralPath $script:analyzeAgentSource -Raw
        $content | Should -Match 'STRICTLY READ-ONLY'
        $content | Should -Match 'studio/runtime/analysis-result\.schema\.json'
        $content | Should -Match 'analysis-result\.json.*only Analyze artifact.*authorize'
        $content | Should -Match '\(\?m\)\^\(- \)\\\[\(\?: \|x\|X\)\\\]'
        $content | Should -Match 'Do not write the file yourself'
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
