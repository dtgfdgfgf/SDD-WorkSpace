#!/usr/bin/env pwsh
#Requires -Version 7.0
#Requires -Module Pester

BeforeDiscovery {
    $script:yamlAvailable = [bool](Get-Module -ListAvailable -Name 'powershell-yaml')
}

BeforeAll {
    . "$PSScriptRoot/governance.config.ps1"

    $script:runWorkflow = Join-Path $WorkspaceRoot 'studio/scripts/powershell/run-workflow.ps1'
    $script:canonicalStudioRoot = Join-Path $WorkspaceRoot 'studio'
    $script:canonicalWorkflowRoot = Join-Path $script:canonicalStudioRoot 'workflows'
    $script:evidenceMarkers = @(
        'R6_FRESH_FIXTURE_CANONICAL_REGISTRY_DENIED'
        'R6_FRESH_FIXTURE_DRYRUN_ISOLATED'
        'R6_FRESH_FIXTURE_WORKFLOW_MUTATION_DENIED'
        'R6_FRESH_FIXTURE_NON_READY_REJECTED'
        'R6_FRESH_FIXTURE_RESTART_ARCHIVED'
        'R6_FRESH_FIXTURE_ECI_REENTRY_COMPLETE'
        'R6_FRESH_FIXTURE_ANALYZE_CRITICAL_BLOCKED'
        'R6_FRESH_FIXTURE_PARTIAL_IMPLEMENT_BLOCKED'
        'R6_FRESH_FIXTURE_TERMINAL_SUCCESS'
    )

    function script:Set-R6Text {
        param(
            [Parameter(Mandatory)] [string]$Path,
            [Parameter(Mandatory)] [AllowEmptyString()] [string]$Content
        )

        $parent = Split-Path -Parent $Path
        if ($parent -and -not (Test-Path -LiteralPath $parent -PathType Container)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        [System.IO.File]::WriteAllText(
            $Path,
            ($Content -replace "`r`n?", "`n"),
            [System.Text.UTF8Encoding]::new($false)
        )
    }

    function script:Set-R6Json {
        param(
            [Parameter(Mandatory)] [string]$Path,
            [Parameter(Mandatory)] $Value
        )

        Set-R6Text -Path $Path -Content ($Value | ConvertTo-Json -Depth 30)
    }

    function script:Get-R6Sha256 {
        param(
            [Parameter(Mandatory)] [string]$Path,
            [switch]$NormalizeTaskCheckboxes
        )

        if (-not $NormalizeTaskCheckboxes) {
            return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
        }

        $content = [System.IO.File]::ReadAllText(
            $Path,
            [System.Text.UTF8Encoding]::new($false, $true)
        )
        $normalized = [regex]::Replace(
            $content,
            '(?m)^(- )\[(?: |x|X)\](\s+T\d{3}\b)',
            '$1[ ]$2'
        )
        $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($normalized)
        return (
            [Convert]::ToHexString(
                [System.Security.Cryptography.SHA256]::HashData($bytes)
            )
        ).ToLowerInvariant()
    }

    function script:Get-R6WorkflowInventory {
        $root = [System.IO.Path]::GetFullPath($script:canonicalWorkflowRoot)
        return @(
            Get-ChildItem -LiteralPath $root -File -Recurse |
                Sort-Object FullName |
                ForEach-Object {
                    $relative = [System.IO.Path]::GetRelativePath($root, $_.FullName).Replace('\', '/')
                    '{0}={1}' -f $relative, (Get-R6Sha256 -Path $_.FullName)
                }
        )
    }

    function script:Get-R6ProtectedGitSurface {
        return @(
            & git -C $WorkspaceRoot status --porcelain=v1 --untracked-files=all -- `
                studio/workflows projects learning
        )
    }

    function script:New-R6FreshFixture {
        $projectRoot = Join-Path $TestDrive (
            'r6-project-{0}' -f [guid]::NewGuid().ToString('N')
        )
        $studioRoot = Join-Path $TestDrive (
            'r6-studio-{0}' -f [guid]::NewGuid().ToString('N')
        )
        $feature = '901-r6-fresh'
        $featureDir = Join-Path $projectRoot "specs/$feature"
        $fixtureWorkflowRoot = Join-Path $studioRoot 'workflows'
        $fixtureWorkflowDir = Join-Path $fixtureWorkflowRoot 'sdd-pipeline'

        New-Item -ItemType Directory -Path (Join-Path $projectRoot '.specify/memory') -Force |
            Out-Null
        New-Item -ItemType Directory -Path $featureDir -Force | Out-Null
        Set-R6Text `
            -Path (Join-Path $projectRoot '.specify/memory/constitution.md') `
            -Content @'
# R6 Fresh Fixture Constitution

This isolated project follows the canonical Studio Constitution.
'@

        New-Item -ItemType Directory -Path $studioRoot -Force | Out-Null
        Copy-Item `
            -LiteralPath (Join-Path $script:canonicalStudioRoot 'constitution') `
            -Destination (Join-Path $studioRoot 'constitution') `
            -Recurse `
            -Force
        New-Item -ItemType Directory -Path (Join-Path $studioRoot 'templates') -Force |
            Out-Null
        Copy-Item `
            -LiteralPath (Join-Path $script:canonicalStudioRoot 'templates/sdd-docs') `
            -Destination (Join-Path $studioRoot 'templates/sdd-docs') `
            -Recurse `
            -Force

        New-Item -ItemType Directory -Path $fixtureWorkflowDir -Force | Out-Null
        foreach ($schemaName in @('catalog.schema.json', 'state.schema.json')) {
            Copy-Item `
                -LiteralPath (Join-Path $script:canonicalWorkflowRoot $schemaName) `
                -Destination (Join-Path $fixtureWorkflowRoot $schemaName) `
                -Force
        }
        foreach ($workflowFile in @('workflow.yml', 'manifest.json')) {
            Copy-Item `
                -LiteralPath (Join-Path $script:canonicalWorkflowRoot "sdd-pipeline/$workflowFile") `
                -Destination (Join-Path $fixtureWorkflowDir $workflowFile) `
                -Force
        }

        $workflowPath = Join-Path $fixtureWorkflowDir 'workflow.yml'
        $workflowBytes = [System.IO.File]::ReadAllBytes($workflowPath)
        $workflowSha256 = Get-R6Sha256 -Path $workflowPath

        $catalog = Get-Content `
            -LiteralPath (Join-Path $script:canonicalWorkflowRoot 'catalog.json') `
            -Raw |
            ConvertFrom-Json -AsHashtable
        $entry = @(
            $catalog['workflows'] |
                Where-Object { [string]$_['id'] -eq 'sdd-pipeline' }
        )[0]
        $entry['reviewStatus'] = 'approved'
        $entry['trustLevel'] = 'curated'
        $entry['defaultEnabled'] = $false
        $entry['approvedBy'] = 'r6-fresh-fixture-only'
        $entry['approvedAt'] = '2026-07-21T00:00:00+08:00'
        $entry['workflowSha256'] = $workflowSha256
        Set-R6Json -Path (Join-Path $fixtureWorkflowRoot 'catalog.json') -Value $catalog

        $state = Get-Content `
            -LiteralPath (Join-Path $script:canonicalWorkflowRoot 'state.json') `
            -Raw |
            ConvertFrom-Json -AsHashtable
        $state['states']['sdd-pipeline'] = [ordered]@{
            enabled       = $true
            pinnedVersion = '1.1.0'
            changedAt     = '2026-07-21T00:00:00+08:00'
            source        = 'manual'
        }
        Set-R6Json -Path (Join-Path $fixtureWorkflowRoot 'state.json') -Value $state

        return [pscustomobject]@{
            ProjectRoot         = $projectRoot
            StudioRoot          = $studioRoot
            Feature             = $feature
            FeatureDir          = $featureDir
            WorkflowPath        = $workflowPath
            WorkflowBytes       = $workflowBytes
            WorkflowSha256      = $workflowSha256
            StatePath           = Join-Path $projectRoot ".workflow/runs/$feature/state.json"
            CanonicalInventory  = @(Get-R6WorkflowInventory)
            ProtectedGitSurface = @(Get-R6ProtectedGitSurface)
        }
    }

    function script:Invoke-R6Run {
        param(
            [Parameter(Mandatory)] $Fixture,
            [string]$StudioRoot = $Fixture.StudioRoot,
            [string[]]$ExtraArgs = @()
        )

        $oldProjectRoot = $env:SDD_PROJECT_ROOT
        $oldStudioRoot = $env:SDD_STUDIO_ROOT
        try {
            $env:SDD_PROJECT_ROOT = $Fixture.ProjectRoot
            $env:SDD_STUDIO_ROOT = $StudioRoot
            $arguments = @(
                '-Id', 'sdd-pipeline',
                '-Feature', $Fixture.Feature,
                '-Json'
            ) + $ExtraArgs
            $output = & pwsh -NoProfile -File $script:runWorkflow @arguments 2>&1
            $exitCode = $LASTEXITCODE
        } finally {
            if ($null -eq $oldProjectRoot) {
                Remove-Item Env:SDD_PROJECT_ROOT -ErrorAction SilentlyContinue
            } else {
                $env:SDD_PROJECT_ROOT = $oldProjectRoot
            }
            if ($null -eq $oldStudioRoot) {
                Remove-Item Env:SDD_STUDIO_ROOT -ErrorAction SilentlyContinue
            } else {
                $env:SDD_STUDIO_ROOT = $oldStudioRoot
            }
        }

        $raw = @($output) -join "`n"
        $json = $null
        try {
            $json = $raw | ConvertFrom-Json -ErrorAction Stop
        } catch {
            throw "run-workflow.ps1 returned non-JSON output (exit $exitCode): $raw"
        }

        return [pscustomobject]@{
            ExitCode = $exitCode
            Json     = $json
            Raw      = $raw
        }
    }

    function script:Assert-R6AgentHalt {
        param(
            [Parameter(Mandatory)] $Run,
            [Parameter(Mandatory)] [string]$AgentCommand
        )

        $Run.ExitCode | Should -Be 42 -Because $Run.Raw
        $Run.Json.STATUS | Should -BeExactly 'awaiting_agent' -Because $Run.Raw
        $Run.Json.HALT_DISPATCH.agent_command |
            Should -BeExactly $AgentCommand -Because $Run.Raw
    }

    function script:Assert-R6GateHalt {
        param(
            [Parameter(Mandatory)] $Run,
            [Parameter(Mandatory)] [string]$GateId
        )

        $Run.ExitCode | Should -Be 43 -Because $Run.Raw
        $Run.Json.STATUS | Should -BeExactly 'awaiting_gate' -Because $Run.Raw
        $Run.Json.HALT_DISPATCH.gate_id |
            Should -BeExactly $GateId -Because $Run.Raw
    }

    function script:Write-R6Spec {
        param(
            [Parameter(Mandatory)] $Fixture,
            [Parameter(Mandatory)] [string]$Revision
        )

        Set-R6Text -Path (Join-Path $Fixture.FeatureDir 'spec.md') -Content @"
# Feature Specification: R6 Fresh Fixture

**Feature ID**: ``$($Fixture.Feature)``
**Version**: 1.0.0
**Revision**: $Revision

## Functional Requirements

- **FR-001**: The isolated workflow MUST preserve every governed stage boundary.
- **FR-002**: Terminal completion MUST retain and complete both baseline task IDs.

## Clarifications

- No material clarification markers remain for revision $Revision.
"@
    }

    function script:Write-R6Readiness {
        param(
            [Parameter(Mandatory)] $Fixture,
            [Parameter(Mandatory)] [string]$PrimaryStatus,
            [Parameter(Mandatory)] [string]$ReentryStatus,
            [Parameter(Mandatory)] [string]$EvidenceSha256,
            [Parameter(Mandatory)] [string]$Revision
        )

        Set-R6Text `
            -Path (Join-Path $Fixture.FeatureDir 'readiness/readiness-assessment.md') `
            -Content @"
# Readiness Assessment: R6 Fresh Fixture

**Date**: 2026-07-21
**Primary Status**: ``$PrimaryStatus``
**ECI Re-entry Status**: ``$ReentryStatus``
**ECI Evidence SHA-256**: ``$EvidenceSha256``
**Recommended Next Step**: Continue only through the governed workflow.
**Assessment Revision**: $Revision

## Planability vs Intent Obligations

- **Planability Resolved**: $(if ($PrimaryStatus -eq 'READY_FOR_PLAN') { 'Yes' } else { 'No' })
- **Intent Obligations Retained**: None
- **Intent Ledger Requirement**: Not Required
- **Intent Ledger Path**: N/A

## Primary Blocker Analysis

- This assessment is the isolated R6 evidence state for revision $Revision.
"@
    }

    function script:Write-R6EciDossier {
        param([Parameter(Mandatory)] $Fixture)

        Set-R6Text `
            -Path (Join-Path $Fixture.FeatureDir 'readiness/eci-trigger.md') `
            -Content @'
# ECI Trigger

The R6 fresh fixture adopts the canonical sdd-pipeline workflow bytes.
'@
        Set-R6Text `
            -Path (Join-Path $Fixture.FeatureDir 'readiness/eci/eci-assessment.md') `
            -Content @'
# ECI Assessment

**ECI Level**: `STANDARD_ECI`
**Recommended Authorization**: `READY_FOR_MAINLINE_IMPLEMENTATION`
'@
        Set-R6Text `
            -Path (Join-Path $Fixture.FeatureDir 'readiness/eci/source-manifest.md') `
            -Content @'
# Source Manifest

- Canonical source: `studio/workflows/sdd-pipeline/workflow.yml`
- Fixture use: isolated validation only
'@
        Set-R6Text `
            -Path (Join-Path $Fixture.FeatureDir 'readiness/eci/adoption-record.md') `
            -Content @'
# Adoption Record

- Scope: isolated R6 fresh fixture
- Promotion authority: none
'@
        Set-R6Text `
            -Path (Join-Path $Fixture.FeatureDir 'readiness/eci/authorization-record.md') `
            -Content @'
# Authorization Record

**Authorization Outcome**: `READY_FOR_MAINLINE_IMPLEMENTATION`
'@
    }

    function script:Get-R6EciEvidenceDigest {
        param([Parameter(Mandatory)] $Fixture)

        $readinessDir = Join-Path $Fixture.FeatureDir 'readiness'
        $relativePaths = @(
            'eci-trigger.md'
            'eci/eci-assessment.md'
            'eci/source-manifest.md'
            'eci/adoption-record.md'
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
                $contentLengthBytes = [System.BitConverter]::GetBytes(
                    [uint64]$contentBytes.LongLength
                )
                if ([System.BitConverter]::IsLittleEndian) {
                    [System.Array]::Reverse($contentLengthBytes)
                }
                $hasher.AppendData($pathLengthBytes)
                $hasher.AppendData($pathBytes)
                $hasher.AppendData($contentLengthBytes)
                $hasher.AppendData($contentBytes)
            }
            return [Convert]::ToHexString(
                $hasher.GetHashAndReset()
            ).ToLowerInvariant()
        } finally {
            $hasher.Dispose()
        }
    }

    function script:Write-R6Plan {
        param(
            [Parameter(Mandatory)] $Fixture,
            [Parameter(Mandatory)] [string]$Revision
        )

        Set-R6Text -Path (Join-Path $Fixture.FeatureDir 'plan.md') -Content @"
# Implementation Plan: R6 Fresh Fixture

**Feature ID**: ``$($Fixture.Feature)``
**Version**: 1.0.0
**Revision**: $Revision

The plan preserves the isolated evidence boundary.
"@
    }

    function script:Write-R6Tasks {
        param(
            [Parameter(Mandatory)] $Fixture,
            [bool]$T001Complete = $false,
            [bool]$T002Complete = $false,
            [Parameter(Mandatory)] [string]$Revision
        )

        $first = if ($T001Complete) { 'x' } else { ' ' }
        $second = if ($T002Complete) { 'x' } else { ' ' }
        Set-R6Text -Path (Join-Path $Fixture.FeatureDir 'tasks.md') -Content @"
# Tasks: R6 Fresh Fixture

**Feature ID**: ``$($Fixture.Feature)``
**Version**: 1.0.0
**Revision**: $Revision

- [$first] T001 [P1] [Risk: High] [Story: Foundation] Preserve the first baseline task
- [$second] T002 [P1] [Risk: High] [Story: Foundation] Preserve the second baseline task
"@
    }

    function script:Write-R6Analysis {
        param(
            [Parameter(Mandatory)] $Fixture,
            [switch]$OpenCritical
        )

        $featureDir = $Fixture.FeatureDir
        $hashes = [ordered]@{
            'spec.md' = Get-R6Sha256 -Path (Join-Path $featureDir 'spec.md')
            'readiness/readiness-assessment.md' = Get-R6Sha256 `
                -Path (Join-Path $featureDir 'readiness/readiness-assessment.md')
            'readiness/eci-trigger.md' = Get-R6Sha256 `
                -Path (Join-Path $featureDir 'readiness/eci-trigger.md')
            'readiness/eci/eci-assessment.md' = Get-R6Sha256 `
                -Path (Join-Path $featureDir 'readiness/eci/eci-assessment.md')
            'readiness/eci/source-manifest.md' = Get-R6Sha256 `
                -Path (Join-Path $featureDir 'readiness/eci/source-manifest.md')
            'readiness/eci/adoption-record.md' = Get-R6Sha256 `
                -Path (Join-Path $featureDir 'readiness/eci/adoption-record.md')
            'readiness/eci/authorization-record.md' = Get-R6Sha256 `
                -Path (Join-Path $featureDir 'readiness/eci/authorization-record.md')
            'intent-ledger.md' = $null
            'plan.md' = Get-R6Sha256 -Path (Join-Path $featureDir 'plan.md')
            'tasks.md' = Get-R6Sha256 `
                -Path (Join-Path $featureDir 'tasks.md') `
                -NormalizeTaskCheckboxes
        }
        $criticalFindings = [System.Collections.Generic.List[object]]::new()
        if ($OpenCritical) {
            $criticalFindings.Add(
                [ordered]@{
                    id         = 'R6-CRITICAL-001'
                    status     = 'OPEN'
                    summary    = 'Fixture Critical finding remains unresolved.'
                    resolution = 'Repair and rerun Analyze before Implement.'
                }
            ) | Out-Null
        }
        $intentItems = [System.Collections.Generic.List[object]]::new()
        $analysis = [ordered]@{
            schemaVersion     = '1.0.0'
            featureId         = $Fixture.Feature
            outcome           = if ($OpenCritical) { 'BLOCKED' } else { 'IMPLEMENTATION_READY' }
            eciRequired       = $true
            artifactHashes    = $hashes
            criticalFindings  = $criticalFindings
            intentDriftCheck  = [ordered]@{
                status  = 'PASS'
                summary = 'The isolated fixture preserves the declared intent.'
            }
            intentObligations = [ordered]@{
                status = 'NOT_REQUIRED'
                items  = $intentItems
            }
        }
        Set-R6Json -Path (Join-Path $featureDir 'analysis-result.json') -Value $analysis
    }

    function script:Add-R6EvidenceMarker {
        param(
            [Parameter(Mandatory)]
            [AllowEmptyCollection()]
            [System.Collections.Generic.List[string]]$Observed,
            [Parameter(Mandatory)] [string]$Marker
        )

        $Observed.Add($Marker) | Out-Null
        Write-Host $Marker
    }
}

Describe 'R6 fresh-fixture seven-stage acceptance' -Skip:(-not $script:yamlAvailable) {
    It 'replays denial, recovery, ECI, Analyze, and terminal completion without canonical writes' {
        $fixture = New-R6FreshFixture
        $observed = [System.Collections.Generic.List[string]]::new()

        try {
            $canonicalDenied = Invoke-R6Run `
                -Fixture $fixture `
                -StudioRoot $script:canonicalStudioRoot `
                -ExtraArgs @('-DryRun')
            $canonicalDenied.ExitCode | Should -Be 1 -Because $canonicalDenied.Raw
            $canonicalDenied.Json.STATUS |
                Should -BeExactly 'denied' -Because $canonicalDenied.Raw
            $canonicalDenied.Raw | Should -Match 'registry authorization denied'
            Test-Path -LiteralPath $fixture.StatePath | Should -BeFalse
            Add-R6EvidenceMarker `
                -Observed $observed `
                -Marker 'R6_FRESH_FIXTURE_CANONICAL_REGISTRY_DENIED'

            $dryRun = Invoke-R6Run -Fixture $fixture -ExtraArgs @('-DryRun')
            $dryRun.ExitCode | Should -Be 43 -Because $dryRun.Raw
            $dryRun.Json.STATUS | Should -BeExactly 'awaiting_gate' -Because $dryRun.Raw
            $dryRun.Json.RUN_STATE_PATH | Should -Match 'state\.dryrun\.json$'
            Test-Path -LiteralPath $fixture.StatePath | Should -BeFalse
            $dryResume = Invoke-R6Run -Fixture $fixture -ExtraArgs @('-Resume')
            $dryResume.ExitCode | Should -Be 1 -Because $dryResume.Raw
            $dryResume.Raw | Should -Match 'No RunState to resume'
            Add-R6EvidenceMarker `
                -Observed $observed `
                -Marker 'R6_FRESH_FIXTURE_DRYRUN_ISOLATED'

            $first = Invoke-R6Run -Fixture $fixture
            Assert-R6AgentHalt -Run $first -AgentCommand '/speckit.specify'
            $firstState = Get-Content -LiteralPath $fixture.StatePath -Raw | ConvertFrom-Json

            $tamperedBytes = [System.Collections.Generic.List[byte]]::new()
            $tamperedBytes.AddRange([byte[]]$fixture.WorkflowBytes)
            $tamperedBytes.AddRange(
                [System.Text.UTF8Encoding]::new($false).GetBytes(
                    "`n# R6 fixture-only unapproved mutation`n"
                )
            )
            [System.IO.File]::WriteAllBytes(
                $fixture.WorkflowPath,
                $tamperedBytes.ToArray()
            )
            $mutationDenied = Invoke-R6Run -Fixture $fixture -ExtraArgs @('-Resume')
            $mutationDenied.ExitCode | Should -Be 1 -Because $mutationDenied.Raw
            $mutationDenied.Json.STATUS |
                Should -BeExactly 'denied' -Because $mutationDenied.Raw
            $mutationDenied.Raw | Should -Match 'approval digest mismatch'
            [System.IO.File]::WriteAllBytes($fixture.WorkflowPath, $fixture.WorkflowBytes)
            Get-R6Sha256 -Path $fixture.WorkflowPath |
                Should -BeExactly $fixture.WorkflowSha256
            Add-R6EvidenceMarker `
                -Observed $observed `
                -Marker 'R6_FRESH_FIXTURE_WORKFLOW_MUTATION_DENIED'

            Write-R6Spec -Fixture $fixture -Revision 'initial-specify'
            $afterSpecify = Invoke-R6Run -Fixture $fixture -ExtraArgs @('-Resume')
            Assert-R6AgentHalt -Run $afterSpecify -AgentCommand '/speckit.clarify'

            Write-R6Spec -Fixture $fixture -Revision 'initial-clarified'
            $afterClarify = Invoke-R6Run -Fixture $fixture -ExtraArgs @('-Resume')
            Assert-R6AgentHalt -Run $afterClarify -AgentCommand '/speckit.readiness'

            Write-R6Readiness `
                -Fixture $fixture `
                -PrimaryStatus 'NOT_READY' `
                -ReentryStatus 'NOT_REQUIRED' `
                -EvidenceSha256 'N/A' `
                -Revision 'initial-not-ready'
            $notReady = Invoke-R6Run -Fixture $fixture -ExtraArgs @('-Resume')
            Assert-R6GateHalt -Run $notReady -GateId 'not-ready-halt'

            $rejected = Invoke-R6Run `
                -Fixture $fixture `
                -ExtraArgs @('-Resume', '-RejectGate', 'not-ready-halt')
            $rejected.ExitCode | Should -Be 44 -Because $rejected.Raw
            $rejected.Json.STATUS | Should -BeExactly 'rejected' -Because $rejected.Raw
            $resumeRejected = Invoke-R6Run -Fixture $fixture -ExtraArgs @('-Resume')
            $resumeRejected.ExitCode | Should -Be 1 -Because $resumeRejected.Raw
            $resumeRejected.Raw | Should -Match 'Cannot resume a rejected run'
            Add-R6EvidenceMarker `
                -Observed $observed `
                -Marker 'R6_FRESH_FIXTURE_NON_READY_REJECTED'

            $restartAfterReject = Invoke-R6Run -Fixture $fixture -ExtraArgs @('-Restart')
            Assert-R6AgentHalt `
                -Run $restartAfterReject `
                -AgentCommand '/speckit.specify'
            $secondState = Get-Content -LiteralPath $fixture.StatePath -Raw | ConvertFrom-Json
            $secondState.run_id | Should -Not -BeExactly $firstState.run_id

            Write-R6Spec -Fixture $fixture -Revision 'eci-restart-specify'
            $eciClarify = Invoke-R6Run -Fixture $fixture -ExtraArgs @('-Resume')
            Assert-R6AgentHalt -Run $eciClarify -AgentCommand '/speckit.clarify'

            Write-R6Spec -Fixture $fixture -Revision 'eci-restart-clarified'
            $eciReadiness = Invoke-R6Run -Fixture $fixture -ExtraArgs @('-Resume')
            Assert-R6AgentHalt -Run $eciReadiness -AgentCommand '/speckit.readiness'

            Write-R6Readiness `
                -Fixture $fixture `
                -PrimaryStatus 'ROUTE_TO_ECI' `
                -ReentryStatus 'PENDING' `
                -EvidenceSha256 'N/A' `
                -Revision 'eci-route'
            Set-R6Text `
                -Path (Join-Path $fixture.FeatureDir 'readiness/eci-trigger.md') `
                -Content @'
# ECI Trigger

Readiness routes the isolated canonical workflow adoption through ECI.
'@
            $eciAgent = Invoke-R6Run -Fixture $fixture -ExtraArgs @('-Resume')
            Assert-R6AgentHalt -Run $eciAgent -AgentCommand '/speckit.eci'
            $eciRequirement = Join-Path (
                Split-Path -Parent $fixture.StatePath
            ) 'eci-requirement.json'
            Test-Path -LiteralPath $eciRequirement -PathType Leaf | Should -BeTrue
            $eciRequirementDocument = Get-Content `
                -LiteralPath $eciRequirement `
                -Raw |
                ConvertFrom-Json
            $eciRequirementDocument.eci_required | Should -BeTrue
            $eciRequirementDocument.feature | Should -BeExactly $fixture.Feature

            Write-R6EciDossier -Fixture $fixture
            $eciReentryAgent = Invoke-R6Run -Fixture $fixture -ExtraArgs @('-Resume')
            Assert-R6AgentHalt `
                -Run $eciReentryAgent `
                -AgentCommand '/speckit.readiness'

            $eciDigest = Get-R6EciEvidenceDigest -Fixture $fixture
            Write-R6Readiness `
                -Fixture $fixture `
                -PrimaryStatus 'READY_FOR_PLAN' `
                -ReentryStatus 'COMPLETE' `
                -EvidenceSha256 $eciDigest `
                -Revision 'eci-complete'
            $readyGate = Invoke-R6Run -Fixture $fixture -ExtraArgs @('-Resume')
            Assert-R6GateHalt -Run $readyGate -GateId 'ready-confirm'
            Add-R6EvidenceMarker `
                -Observed $observed `
                -Marker 'R6_FRESH_FIXTURE_ECI_REENTRY_COMPLETE'

            $planAgent = Invoke-R6Run `
                -Fixture $fixture `
                -ExtraArgs @('-Resume', '-ConfirmGate', 'ready-confirm')
            Assert-R6AgentHalt -Run $planAgent -AgentCommand '/speckit.plan'

            Write-R6Plan -Fixture $fixture -Revision 'critical-path'
            $tasksAgent = Invoke-R6Run -Fixture $fixture -ExtraArgs @('-Resume')
            Assert-R6AgentHalt -Run $tasksAgent -AgentCommand '/speckit.tasks'

            Write-R6Tasks -Fixture $fixture -Revision 'critical-path'
            $analyzeAgent = Invoke-R6Run -Fixture $fixture -ExtraArgs @('-Resume')
            Assert-R6AgentHalt -Run $analyzeAgent -AgentCommand '/speckit.analyze'

            Write-R6Analysis -Fixture $fixture -OpenCritical
            $criticalBlocked = Invoke-R6Run -Fixture $fixture -ExtraArgs @('-Resume')
            $criticalBlocked.ExitCode | Should -Be 1 -Because $criticalBlocked.Raw
            $criticalBlocked.Json.STATUS |
                Should -BeExactly 'failed' -Because $criticalBlocked.Raw
            $criticalBlocked.Raw | Should -Match 'R6-CRITICAL-001|Critical'
            $failedState = Get-Content -LiteralPath $fixture.StatePath -Raw | ConvertFrom-Json
            $failedState.status | Should -BeExactly 'failed'
            Add-R6EvidenceMarker `
                -Observed $observed `
                -Marker 'R6_FRESH_FIXTURE_ANALYZE_CRITICAL_BLOCKED'

            $restartAfterCritical = Invoke-R6Run -Fixture $fixture -ExtraArgs @('-Restart')
            Assert-R6AgentHalt `
                -Run $restartAfterCritical `
                -AgentCommand '/speckit.specify'
            $thirdState = Get-Content -LiteralPath $fixture.StatePath -Raw | ConvertFrom-Json
            $thirdState.run_id | Should -Not -BeExactly $secondState.run_id
            $archives = @(
                Get-ChildItem `
                    -LiteralPath (Split-Path -Parent $fixture.StatePath) `
                    -Filter 'state.json.*.restarted.json'
            )
            $archives.Count | Should -Be 2
            $archivedRunIds = @(
                $archives |
                    ForEach-Object {
                        (
                            Get-Content -LiteralPath $_.FullName -Raw |
                                ConvertFrom-Json
                        ).run_id
                    }
            )
            $archivedRunIds | Should -Contain $firstState.run_id
            $archivedRunIds | Should -Contain $secondState.run_id
            $archivedRunIds | Should -Not -Contain $thirdState.run_id
            Add-R6EvidenceMarker `
                -Observed $observed `
                -Marker 'R6_FRESH_FIXTURE_RESTART_ARCHIVED'

            Write-R6Spec -Fixture $fixture -Revision 'terminal-restart-specify'
            $terminalClarify = Invoke-R6Run -Fixture $fixture -ExtraArgs @('-Resume')
            Assert-R6AgentHalt `
                -Run $terminalClarify `
                -AgentCommand '/speckit.clarify'

            Write-R6Spec -Fixture $fixture -Revision 'terminal-restart-clarified'
            $terminalReadiness = Invoke-R6Run -Fixture $fixture -ExtraArgs @('-Resume')
            Assert-R6AgentHalt `
                -Run $terminalReadiness `
                -AgentCommand '/speckit.readiness'

            Write-R6Readiness `
                -Fixture $fixture `
                -PrimaryStatus 'READY_FOR_PLAN' `
                -ReentryStatus 'COMPLETE' `
                -EvidenceSha256 $eciDigest `
                -Revision 'terminal-restart-ready'
            $terminalReadyGate = Invoke-R6Run -Fixture $fixture -ExtraArgs @('-Resume')
            Assert-R6GateHalt -Run $terminalReadyGate -GateId 'ready-confirm'

            $terminalPlan = Invoke-R6Run `
                -Fixture $fixture `
                -ExtraArgs @('-Resume', '-ConfirmGate', 'ready-confirm')
            Assert-R6AgentHalt -Run $terminalPlan -AgentCommand '/speckit.plan'

            Write-R6Plan -Fixture $fixture -Revision 'terminal-restart'
            $terminalTasks = Invoke-R6Run -Fixture $fixture -ExtraArgs @('-Resume')
            Assert-R6AgentHalt -Run $terminalTasks -AgentCommand '/speckit.tasks'

            Write-R6Tasks -Fixture $fixture -Revision 'terminal-restart'
            $terminalAnalyze = Invoke-R6Run -Fixture $fixture -ExtraArgs @('-Resume')
            Assert-R6AgentHalt `
                -Run $terminalAnalyze `
                -AgentCommand '/speckit.analyze'

            Write-R6Analysis -Fixture $fixture
            $terminalImplement = Invoke-R6Run -Fixture $fixture -ExtraArgs @('-Resume')
            Assert-R6AgentHalt `
                -Run $terminalImplement `
                -AgentCommand '/speckit.implement'

            $terminalState = Get-Content -LiteralPath $fixture.StatePath -Raw | ConvertFrom-Json
            @($terminalState.vars.steps.'stage-implement'.baseline_task_ids) |
                Should -Be @('T001', 'T002')
            $baselineSidecar = [string]$terminalState.vars.steps.'stage-implement'.baseline_sidecar
            Test-Path -LiteralPath $baselineSidecar -PathType Leaf | Should -BeTrue
            $baseline = Get-Content -LiteralPath $baselineSidecar -Raw | ConvertFrom-Json
            @($baseline.task_ids) | Should -Be @('T001', 'T002')

            Write-R6Tasks `
                -Fixture $fixture `
                -T001Complete $true `
                -T002Complete $false `
                -Revision 'terminal-restart'
            $partial = Invoke-R6Run -Fixture $fixture -ExtraArgs @('-Resume')
            Assert-R6AgentHalt -Run $partial -AgentCommand '/speckit.implement'
            $partialState = Get-Content -LiteralPath $fixture.StatePath -Raw |
                ConvertFrom-Json
            $partialState.halt_reason | Should -Match 'T002|postcondition'
            @($partialState.vars.steps.'stage-implement'.baseline_task_ids) |
                Should -Be @('T001', 'T002')
            Add-R6EvidenceMarker `
                -Observed $observed `
                -Marker 'R6_FRESH_FIXTURE_PARTIAL_IMPLEMENT_BLOCKED'

            Write-R6Tasks `
                -Fixture $fixture `
                -T001Complete $true `
                -T002Complete $true `
                -Revision 'terminal-restart'
            $completed = Invoke-R6Run -Fixture $fixture -ExtraArgs @('-Resume')
            $completed.ExitCode | Should -Be 0 -Because $completed.Raw
            $completed.Json.STATUS | Should -BeExactly 'completed' -Because $completed.Raw
            $completedState = Get-Content -LiteralPath $fixture.StatePath -Raw | ConvertFrom-Json
            $completedState.status | Should -BeExactly 'completed'
            Add-R6EvidenceMarker `
                -Observed $observed `
                -Marker 'R6_FRESH_FIXTURE_TERMINAL_SUCCESS'

            foreach ($marker in $script:evidenceMarkers) {
                @($observed) | Should -Contain $marker
            }
            @($observed | Sort-Object -Unique).Count |
                Should -Be $script:evidenceMarkers.Count

            @(Get-R6WorkflowInventory) |
                Should -Be $fixture.CanonicalInventory
            @(Get-R6ProtectedGitSurface) |
                Should -Be $fixture.ProtectedGitSurface
        } finally {
            if (
                $fixture -and
                (Test-Path -LiteralPath $fixture.WorkflowPath -PathType Leaf)
            ) {
                [System.IO.File]::WriteAllBytes(
                    $fixture.WorkflowPath,
                    $fixture.WorkflowBytes
                )
            }
        }
    }
}
