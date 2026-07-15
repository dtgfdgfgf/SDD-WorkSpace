#!/usr/bin/env pwsh
#Requires -Module Pester

# Integration tests for the workflow-engine state machine: command (script + agent),
# gate (halt + ConfirmGate + RejectGate), if (then/else), switch (cases + default),
# and the deferred step types raising "step-type-not-implemented".

BeforeDiscovery {
    $script:yamlAvailable = [bool](Get-Module -ListAvailable -Name 'powershell-yaml')
}

BeforeAll {
    . "$PSScriptRoot/governance.config.ps1"

    $script:runWorkflow = Join-Path $WorkspaceRoot 'studio/scripts/powershell/run-workflow.ps1'
    $script:workflowsRoot = Join-Path $WorkspaceRoot 'studio/workflows'

    function script:New-WorkflowFixtureProject {
        param(
            [Parameter(Mandatory)] [string]$WorkflowYaml,
            [string]$ReviewStatus = 'approved',
            [string]$TrustLevel = 'curated',
            [bool]$DefaultEnabled = $true,
            [switch]$SkipCatalogEntry,
            [string]$ManifestVersion = '1.0.0',
            [string]$CatalogVersion = '1.0.0',
            [object]$StateEnabled = $null,
            [string]$WorkflowIdOverride = $null
        )
        $project = Join-Path $TestDrive ("proj-{0}" -f ([System.Guid]::NewGuid().ToString('N')))
        New-Item -ItemType Directory -Path (Join-Path $project '.specify/memory') -Force | Out-Null
        '# fixture' | Set-Content -LiteralPath (Join-Path $project '.specify/memory/constitution.md')
        $featureDir = Join-Path $project 'specs/999-fixture'
        New-Item -ItemType Directory -Path $featureDir -Force | Out-Null
        '# spec' | Set-Content -LiteralPath (Join-Path $featureDir 'spec.md')

        # Build an isolated mini studio root in TestDrive: run-workflow.ps1 resolves the
        # workflows tree (catalog, state ledger, workflow dirs) from SDD_STUDIO_ROOT, so
        # fixtures register through the legitimate governance path and never write into
        # the real studio/workflows/ tree. The catalog id must equal the id declared inside
        # workflow.yml (the runner binds the executed document to the authorized identity),
        # unless a test deliberately exercises a mismatch.
        if ($WorkflowIdOverride) {
            $wfId = $WorkflowIdOverride
        } elseif ($WorkflowYaml -match '(?m)^\s{2}id:\s*(\S+)\s*$') {
            $wfId = $Matches[1]
        } else {
            $wfId = "fixture-{0}" -f ([System.Guid]::NewGuid().ToString('N').Substring(0, 8))
        }
        $studioFixture = Join-Path $TestDrive ("studio-{0}" -f ([System.Guid]::NewGuid().ToString('N').Substring(0, 8)))
        $wfDir = Join-Path $studioFixture "workflows/$wfId"
        New-Item -ItemType Directory -Path $wfDir -Force | Out-Null
        foreach ($schemaName in @('catalog.schema.json', 'state.schema.json')) {
            Copy-Item `
                -LiteralPath (Join-Path $script:workflowsRoot $schemaName) `
                -Destination (Join-Path $studioFixture "workflows/$schemaName") `
                -Force
        }
        $WorkflowYaml | Set-Content -LiteralPath (Join-Path $wfDir 'workflow.yml') -NoNewline

        [ordered]@{
            id = $wfId; version = $ManifestVersion; title = 'Engine Test Fixture'
            kind = 'workflow'; status = 'active'; owner = 'studio'
        } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $wfDir 'manifest.json')

        $catalogWorkflows = @()
        if (-not $SkipCatalogEntry) {
            $catalogWorkflows += [ordered]@{
                id = $wfId; version = $CatalogVersion; title = 'Engine Test Fixture'
                sourcePath = "workflows/$wfId"; reviewStatus = $ReviewStatus
                trustLevel = $TrustLevel; defaultEnabled = $DefaultEnabled; owner = 'studio'
                approvedBy = 'governance-test'; approvedAt = '2026-07-14T00:00:00+08:00'
                stepTypesUsed = @('command', 'gate', 'if', 'switch'); notes = 'Isolated workflow-engine fixture.'
            }
        }
        $catalogPolicy = [ordered]@{
            mode = 'studio-first'; curatedOnly = $true; autoEnableNewWorkflows = $false
            reviewStatuses = @('draft', 'approved', 'experimental', 'deprecated', 'rejected')
            trustLevels = @('core', 'curated', 'experimental')
            stateSources = @('default', 'manual', 'sync')
        }
        [ordered]@{ version = '1.0.0'; updated = '2026-07-14T00:00:00+08:00'; policy = $catalogPolicy; workflows = $catalogWorkflows } |
            ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $studioFixture 'workflows/catalog.json')

        $states = [ordered]@{}
        if ($null -ne $StateEnabled) {
            $states[$wfId] = [ordered]@{
                enabled = [bool]$StateEnabled; pinnedVersion = $CatalogVersion
                changedAt = '2026-07-14T00:00:00+08:00'; source = 'manual'
            }
        }
        [ordered]@{ version = '1.0.0'; updated = '2026-07-14T00:00:00+08:00'; states = $states } |
            ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $studioFixture 'workflows/state.json')

        return [pscustomobject]@{ ProjectRoot = $project; FeatureName = '999-fixture'; WorkflowId = $wfId; WorkflowDir = $wfDir; StudioRoot = $studioFixture }
    }

    function script:Remove-WorkflowFixture {
        param($Fixture)
        if (Test-Path -LiteralPath $Fixture.WorkflowDir) {
            Remove-Item -LiteralPath $Fixture.WorkflowDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    function script:Invoke-Run {
        param($Fixture, [string[]]$ExtraArgs = @())
        $env:SDD_PROJECT_ROOT = $Fixture.ProjectRoot
        $env:SDD_STUDIO_ROOT = $Fixture.StudioRoot
        $argv = @('-Id', $Fixture.WorkflowId, '-Feature', $Fixture.FeatureName, '-Json') + $ExtraArgs
        $output = pwsh -NoProfile -File $script:runWorkflow @argv 2>&1
        $exitCode = $LASTEXITCODE
        $json = $null
        try { $json = ($output -join "`n") | ConvertFrom-Json } catch { $json = $null }
        return [pscustomobject]@{ Output = $output; ExitCode = $exitCode; Json = $json }
    }

    function script:Get-WorkflowTestArtifactHash {
        param(
            [Parameter(Mandatory)] [string]$Path,
            [switch]$NormalizeTaskCheckboxes
        )

        if (-not $NormalizeTaskCheckboxes) {
            return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
        }
        $content = [System.IO.File]::ReadAllText($Path, [System.Text.UTF8Encoding]::new($false, $true))
        $normalized = [regex]::Replace($content, '(?m)^(- )\[(?: |x|X)\](\s+T\d{3}\b)', '$1[ ]$2')
        $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($normalized)
        return ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))).ToLowerInvariant()
    }

    function script:Initialize-ImplementGateFeature {
        param($Fixture, [switch]$WithEci)

        $featureDir = Join-Path $Fixture.ProjectRoot 'specs/999-fixture'
        $readinessDir = Join-Path $featureDir 'readiness'
        $eciDir = Join-Path $readinessDir 'eci'
        New-Item -ItemType Directory -Path $eciDir -Force | Out-Null

        @"
# Feature Specification: Fixture

**Feature ID**: ``999-fixture``
**Version**: 1.0.0

## Functional Requirements

- **FR-001**: System MUST preserve terminal authorization.
"@ | Set-Content -LiteralPath (Join-Path $featureDir 'spec.md') -NoNewline
        @"
# Implementation Plan: Fixture

**Feature ID**: ``999-fixture``
**Version**: 1.0.0
"@ | Set-Content -LiteralPath (Join-Path $featureDir 'plan.md') -NoNewline
        @"
# Tasks: Fixture

**Feature ID**: ``999-fixture``
**Version**: 1.0.0

- [ ] T001 [P1] [Risk: Low] [Story: Foundation] Implement the authorized change
"@ | Set-Content -LiteralPath (Join-Path $featureDir 'tasks.md') -NoNewline
        @"
# Readiness Assessment: Fixture

**Date**: 2026-07-15
**Primary Status**: ``READY_FOR_PLAN``

## Planability vs Intent Obligations

- **Intent Ledger Requirement**: Not Required
"@ | Set-Content -LiteralPath (Join-Path $readinessDir 'readiness-assessment.md') -NoNewline

        if ($WithEci) {
            '# ECI Trigger' | Set-Content -LiteralPath (Join-Path $readinessDir 'eci-trigger.md') -NoNewline
            '# ECI Assessment' | Set-Content -LiteralPath (Join-Path $eciDir 'eci-assessment.md') -NoNewline
            '# Source Manifest' | Set-Content -LiteralPath (Join-Path $eciDir 'source-manifest.md') -NoNewline
            '# Adoption Record' | Set-Content -LiteralPath (Join-Path $eciDir 'adoption-record.md') -NoNewline
            @"
# Authorization Record

**Authorization Outcome**: ``READY_FOR_MAINLINE_IMPLEMENTATION``
"@ | Set-Content -LiteralPath (Join-Path $eciDir 'authorization-record.md') -NoNewline
        }

        $analysis = [ordered]@{
            schemaVersion = '1.0.0'
            featureId = '999-fixture'
            outcome = 'IMPLEMENTATION_READY'
            artifactHashes = [ordered]@{
                'spec.md' = Get-WorkflowTestArtifactHash -Path (Join-Path $featureDir 'spec.md')
                'readiness/readiness-assessment.md' = Get-WorkflowTestArtifactHash -Path (Join-Path $readinessDir 'readiness-assessment.md')
                'intent-ledger.md' = $null
                'plan.md' = Get-WorkflowTestArtifactHash -Path (Join-Path $featureDir 'plan.md')
                'tasks.md' = Get-WorkflowTestArtifactHash -Path (Join-Path $featureDir 'tasks.md') -NormalizeTaskCheckboxes
            }
            criticalFindings = [object[]]@()
            intentDriftCheck = [ordered]@{ status = 'PASS'; summary = 'No intent drift.' }
            intentObligations = [ordered]@{ status = 'NOT_REQUIRED'; items = [object[]]@() }
        }
        $analysis | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $featureDir 'analysis-result.json') -Encoding utf8
        return $featureDir
    }
}

Describe 'workflow-engine: command dispatch' -Skip:(-not $script:yamlAvailable) {
    BeforeEach {
        $script:fixture = New-WorkflowFixtureProject -WorkflowYaml @"
schema_version: "1.0.0"
workflow:
  id: cmd-test
  name: Cmd Test
  version: "1.0.0"
  integration: studio-first
steps:
  - id: stage-script
    type: command
    dispatch: script
    script: studio/scripts/powershell/setup-clarify.ps1
    args: ["-FeatureDir", "specs/{{ inputs.feature }}", "-Json"]
    capture: { json: true }
"@
    }
    AfterEach { Remove-WorkflowFixture -Fixture $script:fixture }

    It 'runs a script step and completes (DryRun)' {
        $r = Invoke-Run -Fixture $script:fixture -ExtraArgs @('-DryRun')
        $r.ExitCode | Should -Be 0
        $r.Json.STATUS | Should -Be 'completed'

        $state = Get-Content -LiteralPath $r.Json.RUN_STATE_PATH -Raw | ConvertFrom-Json
        $history = @($state.history)
        $history[-1].outcome | Should -Be 'dry-run-skipped'
        ($history[-1].args -join '|') | Should -Be '-FeatureDir|specs/999-fixture|-Json'
    }

    It 'runs a script step from ProjectRoot when caller cwd differs' {
        $callerDir = Join-Path $TestDrive 'outside-caller'
        New-Item -ItemType Directory -Path $callerDir -Force | Out-Null

        Push-Location -LiteralPath $callerDir
        try {
            $r = Invoke-Run -Fixture $script:fixture
        } finally {
            Pop-Location
        }

        $r.ExitCode | Should -Be 0
        $r.Json.STATUS | Should -Be 'completed'
        $state = Get-Content -LiteralPath $r.Json.RUN_STATE_PATH -Raw | ConvertFrom-Json
        $capturedFeatureDir = $state.vars.steps.'stage-script'.json.FEATURE_DIR
        $expectedFeatureDir = Join-Path $script:fixture.ProjectRoot 'specs/999-fixture'
        [System.IO.Path]::GetFullPath($capturedFeatureDir) | Should -Be ([System.IO.Path]::GetFullPath($expectedFeatureDir))
    }

    It 'rejects an operator input overriding the run feature' {
        $r = Invoke-Run -Fixture $script:fixture -ExtraArgs @('-Inputs', 'feature=888-other', '-DryRun')
        $r.ExitCode | Should -Not -Be 0
        $r.Json.STATUS | Should -Be 'error'
        $r.Json.ERROR | Should -Match "may not override 'feature'"
    }

    It 'accepts a redundant feature input equal to the run feature' {
        $r = Invoke-Run -Fixture $script:fixture -ExtraArgs @('-Inputs', 'feature=999-fixture;scope=full', '-DryRun')
        $r.ExitCode | Should -Be 0
        $r.Json.STATUS | Should -Be 'completed'
    }

    It 'never allocates a canonical specs feature ID when starting a run' {
        Remove-Item -LiteralPath (Join-Path $script:fixture.ProjectRoot 'specs') -Recurse -Force

        $r = Invoke-Run -Fixture $script:fixture -ExtraArgs @('-DryRun')
        $r.ExitCode | Should -Be 0
        $r.Json.RUN_STATE_PATH | Should -Match '[\\/]\.workflow[\\/]runs[\\/]999-fixture[\\/]'
        (Join-Path $script:fixture.ProjectRoot 'specs') | Should -Not -Exist
    }
}

Describe 'workflow-engine: agent dispatch halts and resumes' -Skip:(-not $script:yamlAvailable) {
    BeforeEach {
        $script:fixture = New-WorkflowFixtureProject -WorkflowYaml @"
schema_version: "1.0.0"
workflow:
  id: agent-test
  name: Agent Test
  version: "1.0.0"
  integration: studio-first
steps:
  - id: stage-agent
    type: command
    dispatch: agent
    agent_command: /speckit.specify
    expected_artifact: "specs/{{ inputs.feature }}/spec.md"
"@
    }
    AfterEach { Remove-WorkflowFixture -Fixture $script:fixture }

    It 'halts at agent step when artifact is missing, then resumes when artifact appears' {
        # Remove the spec.md that the fixture pre-created, so the agent step halts.
        $specPath = Join-Path $script:fixture.ProjectRoot 'specs/999-fixture/spec.md'
        Remove-Item -LiteralPath $specPath -Force

        $r = Invoke-Run -Fixture $script:fixture
        $r.ExitCode | Should -Be 42
        $r.Json.STATUS | Should -Be 'awaiting_agent'
        $r.Json.HALT_DISPATCH.agent_command | Should -Be '/speckit.specify'

        # Operator runs the agent: produce the artifact.
        '# spec produced by agent' | Set-Content -LiteralPath $specPath

        $r2 = Invoke-Run -Fixture $script:fixture -ExtraArgs @('-Resume')
        $r2.ExitCode | Should -Be 0
        $r2.Json.STATUS | Should -Be 'completed'
    }

    It 'rejects resuming when the saved state rebinds the run feature' {
        $specPath = Join-Path $script:fixture.ProjectRoot 'specs/999-fixture/spec.md'
        Remove-Item -LiteralPath $specPath -Force

        $r = Invoke-Run -Fixture $script:fixture
        $r.ExitCode | Should -Be 42

        # Tamper the persisted inputs the way a pre-guard halted run (or a hand edit)
        # could leave them: the state anchored at 999-fixture claims another feature.
        $statePath = $r.Json.RUN_STATE_PATH
        $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json -AsHashtable
        $state.inputs.feature = '888-other'
        $state | ConvertTo-Json -Depth 15 | Set-Content -LiteralPath $statePath

        $r2 = Invoke-Run -Fixture $script:fixture -ExtraArgs @('-Resume')
        $r2.ExitCode | Should -Not -Be 0
        $r2.Json.STATUS | Should -Be 'error'
        $r2.Json.ERROR | Should -Match 'Resume mismatch: state inputs\.feature'
    }

    It 'rejects a resume whose operator inputs override the run feature' {
        $specPath = Join-Path $script:fixture.ProjectRoot 'specs/999-fixture/spec.md'
        Remove-Item -LiteralPath $specPath -Force

        $r = Invoke-Run -Fixture $script:fixture
        $r.ExitCode | Should -Be 42

        $r2 = Invoke-Run -Fixture $script:fixture -ExtraArgs @('-Resume', '-Inputs', 'feature=777-x')
        $r2.ExitCode | Should -Not -Be 0
        $r2.Json.STATUS | Should -Be 'error'
        $r2.Json.ERROR | Should -Match "may not override 'feature'"
    }
}

Describe 'workflow-engine: agent step requires a change, not mere existence (C1/C2)' -Skip:(-not $script:yamlAvailable) {
    BeforeEach {
        $script:fixture = New-WorkflowFixtureProject -WorkflowYaml @"
schema_version: "1.0.0"
workflow:
  id: change-test
  name: Change Test
  version: "1.0.0"
  integration: studio-first
steps:
  - id: stage-agent
    type: command
    dispatch: agent
    agent_command: /speckit.specify
    expected_artifact: "specs/{{ inputs.feature }}/spec.md"
"@
        # The fixture pre-creates spec.md with '# spec'. We deliberately KEEP it to prove that a
        # pre-existing (e.g. scaffolded) artifact does NOT count as agent completion.
        $script:specPath = Join-Path $script:fixture.ProjectRoot 'specs/999-fixture/spec.md'
    }
    AfterEach { Remove-WorkflowFixture -Fixture $script:fixture }

    It 'halts even though the artifact already exists, then completes after a real change' {
        $r = Invoke-Run -Fixture $script:fixture
        $r.ExitCode | Should -Be 42
        $r.Json.STATUS | Should -Be 'awaiting_agent'

        '# spec produced by the agent with real content' | Set-Content -LiteralPath $script:specPath
        $r2 = Invoke-Run -Fixture $script:fixture -ExtraArgs @('-Resume')
        $r2.ExitCode | Should -Be 0
        $r2.Json.STATUS | Should -Be 'completed'
    }

    It 'stays halted on resume when the artifact is unchanged, and -AcceptAgent overrides' {
        $r = Invoke-Run -Fixture $script:fixture
        $r.ExitCode | Should -Be 42

        $r2 = Invoke-Run -Fixture $script:fixture -ExtraArgs @('-Resume')
        $r2.ExitCode | Should -Be 42

        $r3 = Invoke-Run -Fixture $script:fixture -ExtraArgs @('-Resume', '-AcceptAgent', 'stage-agent')
        $r3.ExitCode | Should -Be 0
        $r3.Json.STATUS | Should -Be 'completed'
    }
}

Describe 'workflow-engine: resume does not re-run a completed prep (C5)' -Skip:(-not $script:yamlAvailable) {
    BeforeEach {
        $artifactsDir = Join-Path $WorkspaceRoot 'studio/tests/_artifacts'
        New-Item -ItemType Directory -Path $artifactsDir -Force | Out-Null
        $script:counterScript = Join-Path $artifactsDir ("wf-counter-{0}.ps1" -f ([System.Guid]::NewGuid().ToString('N')))
        @'
param([string]$Counter, [string]$Artifact)
Add-Content -LiteralPath $Counter -Value 'x'
Set-Content -LiteralPath $Artifact -Value 'SCAFFOLD' -Force
'@ | Set-Content -LiteralPath $script:counterScript

        $script:fixture = New-WorkflowFixtureProject -WorkflowIdOverride 'resume-skip' -WorkflowYaml 'PLACEHOLDER'
        $script:counterFile = Join-Path $TestDrive ("counter-{0}.txt" -f ([System.Guid]::NewGuid().ToString('N')))
        $script:genArtifact = Join-Path $script:fixture.ProjectRoot 'specs/999-fixture/gen.md'
        $scriptRel = 'studio/tests/_artifacts/' + (Split-Path -Leaf $script:counterScript)
        $counterFwd = ($script:counterFile -replace '\\', '/')
        $genFwd = ($script:genArtifact -replace '\\', '/')
        $yaml = @"
schema_version: "1.0.0"
workflow:
  id: resume-skip
  name: Resume Skip
  version: "1.0.0"
  integration: studio-first
steps:
  - id: prep
    type: command
    dispatch: script
    script: $scriptRel
    args: ["-Counter", "$counterFwd", "-Artifact", "$genFwd"]
  - id: stage-agent
    type: command
    dispatch: agent
    agent_command: /gen
    expected_artifact: "specs/{{ inputs.feature }}/gen.md"
"@
        $yaml | Set-Content -LiteralPath (Join-Path $script:fixture.WorkflowDir 'workflow.yml') -NoNewline
    }
    AfterEach {
        Remove-WorkflowFixture -Fixture $script:fixture
        if (Test-Path -LiteralPath $script:counterScript) { Remove-Item -LiteralPath $script:counterScript -Force }
    }

    It 'skips the completed prep on resume so it cannot overwrite agent output' {
        $r = Invoke-Run -Fixture $script:fixture
        $r.ExitCode | Should -Be 42
        (Get-Content -LiteralPath $script:counterFile).Count | Should -Be 1
        (Get-Content -LiteralPath $script:genArtifact -Raw).Trim() | Should -Be 'SCAFFOLD'

        # Operator runs the agent: replace the scaffold with real content.
        'AGENT REAL OUTPUT' | Set-Content -LiteralPath $script:genArtifact

        $r2 = Invoke-Run -Fixture $script:fixture -ExtraArgs @('-Resume')
        $r2.ExitCode | Should -Be 0
        $r2.Json.STATUS | Should -Be 'completed'
        # Prep did NOT run again (counter still 1) and did NOT clobber the agent output.
        (Get-Content -LiteralPath $script:counterFile).Count | Should -Be 1
        (Get-Content -LiteralPath $script:genArtifact -Raw).Trim() | Should -Be 'AGENT REAL OUTPUT'
    }
}

Describe 'workflow-engine: extract populates a switch subject (C3)' -Skip:(-not $script:yamlAvailable) {
    BeforeEach {
        $script:fixture = New-WorkflowFixtureProject -WorkflowYaml @"
schema_version: "1.0.0"
workflow:
  id: extract-test
  name: Extract Test
  version: "1.0.0"
  integration: studio-first
steps:
  - id: stage-readiness
    type: command
    dispatch: agent
    agent_command: /speckit.readiness
    expected_artifact: "specs/{{ inputs.feature }}/readiness.md"
    extract:
      - var: readiness_primary_status
        field: Primary Status
  - id: branch
    type: switch
    subject: "{{ vars.readiness_primary_status | default('NOT_READY') }}"
    cases:
      ROUTE_TO_DECISION:
        - { id: decision-gate, type: gate, prompt: "decision" }
    default:
      - { id: default-gate, type: gate, prompt: "default" }
"@
        $script:readinessPath = Join-Path $script:fixture.ProjectRoot 'specs/999-fixture/readiness.md'
    }
    AfterEach { Remove-WorkflowFixture -Fixture $script:fixture }

    It 'routes the switch by the value extracted from the agent artifact' {
        $r = Invoke-Run -Fixture $script:fixture
        $r.ExitCode | Should -Be 42

        # Operator produces a readiness artifact with a concrete primary status.
        "# Readiness`n`n**Primary Status**: ``ROUTE_TO_DECISION``" | Set-Content -LiteralPath $script:readinessPath
        $r2 = Invoke-Run -Fixture $script:fixture -ExtraArgs @('-Resume')
        $r2.ExitCode | Should -Be 43
        $r2.Json.HALT_DISPATCH.gate_id | Should -Be 'decision-gate'
    }
}

Describe 'workflow-engine: gate halts then accepts -ConfirmGate' -Skip:(-not $script:yamlAvailable) {
    BeforeEach {
        $script:fixture = New-WorkflowFixtureProject -WorkflowYaml @"
schema_version: "1.0.0"
workflow:
  id: gate-test
  name: Gate Test
  version: "1.0.0"
  integration: studio-first
steps:
  - id: review
    type: gate
    prompt: "Approve?"
"@
    }
    AfterEach { Remove-WorkflowFixture -Fixture $script:fixture }

    It 'halts at gate, then resumes after -ConfirmGate' {
        $r = Invoke-Run -Fixture $script:fixture
        $r.ExitCode | Should -Be 43
        $r.Json.STATUS | Should -Be 'awaiting_gate'
        $r.Json.HALT_DISPATCH.gate_id | Should -Be 'review'

        $r2 = Invoke-Run -Fixture $script:fixture -ExtraArgs @('-Resume', '-ConfirmGate', 'review')
        $r2.ExitCode | Should -Be 0
        $r2.Json.STATUS | Should -Be 'completed'
    }

    It 'ignores a pre-supplied confirm for a gate that has not halted yet' {
        $r = Invoke-Run -Fixture $script:fixture -ExtraArgs @('-ConfirmGate', 'review')
        $r.ExitCode | Should -Be 43
        $r.Json.STATUS | Should -Be 'awaiting_gate'
        $r.Json.HALT_DISPATCH.gate_id | Should -Be 'review'
    }

    It 'treats reject without on_reject as terminal, recoverable only via -Restart' {
        $r = Invoke-Run -Fixture $script:fixture
        $r.ExitCode | Should -Be 43

        $r2 = Invoke-Run -Fixture $script:fixture -ExtraArgs @('-Resume', '-RejectGate', 'review')
        $r2.ExitCode | Should -Be 44
        $r2.Json.STATUS | Should -Be 'rejected'

        $r3 = Invoke-Run -Fixture $script:fixture -ExtraArgs @('-Resume')
        $r3.ExitCode | Should -Not -Be 0
        $r3.Json.ERROR | Should -Match 'Cannot resume a rejected run'

        $r4 = Invoke-Run -Fixture $script:fixture -ExtraArgs @('-Restart')
        $r4.ExitCode | Should -Be 43
        $r4.Json.STATUS | Should -Be 'awaiting_gate'
        $archiveDir = Split-Path -Parent $r4.Json.RUN_STATE_PATH
        @(Get-ChildItem -LiteralPath $archiveDir -Filter 'state.json.*.restarted.json').Count | Should -BeGreaterThan 0
    }

    It 'refuses a fresh run over an existing RunState without -Restart' {
        $r = Invoke-Run -Fixture $script:fixture
        $r.ExitCode | Should -Be 43

        $r2 = Invoke-Run -Fixture $script:fixture
        $r2.ExitCode | Should -Not -Be 0
        $r2.Json.ERROR | Should -Match 'RunState already exists'
    }
}

Describe 'workflow-engine: gate reject routes through on_reject when declared' -Skip:(-not $script:yamlAvailable) {
    BeforeEach {
        $script:fixture = New-WorkflowFixtureProject -WorkflowYaml @"
schema_version: "1.0.0"
workflow:
  id: gate-reject-route
  name: Gate Reject Route
  version: "1.0.0"
  integration: studio-first
steps:
  - id: review
    type: gate
    prompt: "Approve?"
    on_reject:
      - id: remediation
        type: gate
        prompt: "Remediate first."
"@
    }
    AfterEach { Remove-WorkflowFixture -Fixture $script:fixture }

    It 'runs the on_reject branch instead of terminating' {
        $r = Invoke-Run -Fixture $script:fixture
        $r.ExitCode | Should -Be 43
        $r.Json.HALT_DISPATCH.gate_id | Should -Be 'review'

        $r2 = Invoke-Run -Fixture $script:fixture -ExtraArgs @('-Resume', '-RejectGate', 'review')
        $r2.ExitCode | Should -Be 43
        $r2.Json.STATUS | Should -Be 'awaiting_gate'
        $r2.Json.HALT_DISPATCH.gate_id | Should -Be 'remediation'
    }
}

Describe 'workflow-engine: switch routes by subject + default fallback' -Skip:(-not $script:yamlAvailable) {
    BeforeEach {
        $script:fixture = New-WorkflowFixtureProject -WorkflowYaml @"
schema_version: "1.0.0"
workflow:
  id: switch-test
  name: Switch Test
  version: "1.0.0"
  integration: studio-first
inputs:
  - name: status
    type: string
steps:
  - id: branch
    type: switch
    subject: "{{ inputs.status | default('NOT_READY') }}"
    cases:
      READY_FOR_PLAN:
        - { id: ready-noop, type: gate, prompt: "ready ok" }
    default:
      - { id: default-noop, type: gate, prompt: "default fallback" }
"@
    }
    AfterEach { Remove-WorkflowFixture -Fixture $script:fixture }

    It 'matches a case and halts at that nested gate' {
        $r = Invoke-Run -Fixture $script:fixture -ExtraArgs @('-Inputs', 'status=READY_FOR_PLAN')
        $r.ExitCode | Should -Be 43
        $r.Json.HALT_DISPATCH.gate_id | Should -Be 'ready-noop'
    }

    It 'falls back to default when no case matches' {
        $r = Invoke-Run -Fixture $script:fixture -ExtraArgs @('-Inputs', 'status=UNKNOWN_STATUS')
        $r.ExitCode | Should -Be 43
        $r.Json.HALT_DISPATCH.gate_id | Should -Be 'default-noop'
    }
}

Describe 'workflow-engine: rejects deferred step types' -Skip:(-not $script:yamlAvailable) {
    BeforeEach {
        $script:fixture = New-WorkflowFixtureProject -WorkflowYaml @"
schema_version: "1.0.0"
workflow:
  id: deferred-test
  name: Deferred Test
  version: "1.0.0"
  integration: studio-first
steps:
  - id: bogus
    type: while
    condition: "true"
"@
    }
    AfterEach { Remove-WorkflowFixture -Fixture $script:fixture }

    It 'fails schema validation for the deferred step type' {
        $r = Invoke-Run -Fixture $script:fixture
        $r.ExitCode | Should -Not -Be 0
    }
}

Describe 'run-workflow: runner authorization is fail-closed (R-B05)' -Skip:(-not $script:yamlAvailable) {
    BeforeAll {
        $script:gateYaml = @"
schema_version: "1.0.0"
workflow:
  id: authz-test
  name: Authz Test
  version: "1.0.0"
  integration: studio-first
steps:
  - id: review
    type: gate
    prompt: "Approve?"
"@
    }

    It 'refuses an uncataloged workflow even though its directory exists' {
        $fx = New-WorkflowFixtureProject -WorkflowYaml $script:gateYaml -SkipCatalogEntry
        try {
            $r = Invoke-Run -Fixture $fx
            $r.ExitCode | Should -Be 1
            $r.Json.STATUS | Should -Be 'denied'
            $r.Json.ERROR | Should -Match 'not cataloged'
        } finally { Remove-WorkflowFixture -Fixture $fx }
    }

    It 'refuses a cataloged workflow that is not enabled' {
        $fx = New-WorkflowFixtureProject -WorkflowYaml $script:gateYaml -DefaultEnabled $false
        try {
            $r = Invoke-Run -Fixture $fx
            $r.ExitCode | Should -Be 1
            $r.Json.STATUS | Should -Be 'denied'
            $r.Json.ERROR | Should -Match 'not enabled'
        } finally { Remove-WorkflowFixture -Fixture $fx }
    }

    It 'refuses a rejected workflow even when the state ledger enables it' {
        $fx = New-WorkflowFixtureProject -WorkflowYaml $script:gateYaml -ReviewStatus 'rejected' -StateEnabled $true
        try {
            $r = Invoke-Run -Fixture $fx
            $r.ExitCode | Should -Be 1
            $r.Json.STATUS | Should -Be 'denied'
            $r.Json.ERROR | Should -Match 'rejected'
        } finally { Remove-WorkflowFixture -Fixture $fx }
    }

    It 'refuses a manifest whose identity does not match the catalog entry' {
        $fx = New-WorkflowFixtureProject -WorkflowYaml $script:gateYaml -ManifestVersion '9.9.9'
        try {
            $r = Invoke-Run -Fixture $fx
            $r.ExitCode | Should -Be 1
            $r.Json.STATUS | Should -Be 'denied'
            $r.Json.ERROR | Should -Match 'identity mismatch'
        } finally { Remove-WorkflowFixture -Fixture $fx }
    }

    It 'honors an explicit state-ledger enable over defaultEnabled=false' {
        $fx = New-WorkflowFixtureProject -WorkflowYaml $script:gateYaml -DefaultEnabled $false -StateEnabled $true
        try {
            $r = Invoke-Run -Fixture $fx
            $r.ExitCode | Should -Be 43
            $r.Json.STATUS | Should -Be 'awaiting_gate'
        } finally { Remove-WorkflowFixture -Fixture $fx }
    }

    It 'refuses a state-ledger pin that disagrees with the catalog version' {
        $fx = New-WorkflowFixtureProject -WorkflowYaml $script:gateYaml -StateEnabled $true -CatalogVersion '1.0.0'
        try {
            $stateLedgerPath = Join-Path $fx.StudioRoot 'workflows/state.json'
            $ledger = Get-Content -LiteralPath $stateLedgerPath -Raw | ConvertFrom-Json -AsHashtable
            $ledger.states[$fx.WorkflowId].pinnedVersion = '0.9.0'
            $ledger | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $stateLedgerPath

            $r = Invoke-Run -Fixture $fx
            $r.ExitCode | Should -Be 1
            $r.Json.STATUS | Should -Be 'denied'
            $r.Json.ERROR | Should -Match 'pins version'
        } finally { Remove-WorkflowFixture -Fixture $fx }
    }

    It 'refuses a draft workflow that is hand-marked defaultEnabled=true' {
        $fx = New-WorkflowFixtureProject -WorkflowYaml $script:gateYaml -ReviewStatus 'draft' -TrustLevel 'experimental' -DefaultEnabled $true
        try {
            $r = Invoke-Run -Fixture $fx
            $r.ExitCode | Should -Be 1
            $r.Json.STATUS | Should -Be 'denied'
            $r.Json.ERROR | Should -Match 'violates the default-enable policy'
        } finally { Remove-WorkflowFixture -Fixture $fx }
    }

    It 'refuses a state-ledger enable of an experimental workflow' {
        $fx = New-WorkflowFixtureProject -WorkflowYaml $script:gateYaml -ReviewStatus 'experimental' -TrustLevel 'experimental' -DefaultEnabled $false -StateEnabled $true
        try {
            $r = Invoke-Run -Fixture $fx
            $r.ExitCode | Should -Be 1
            $r.Json.STATUS | Should -Be 'denied'
            $r.Json.ERROR | Should -Match 'cannot be enabled via the state ledger'
        } finally { Remove-WorkflowFixture -Fixture $fx }
    }

    It 'refuses when the executed workflow.yml declares an id other than the authorized one' {
        $fx = New-WorkflowFixtureProject -WorkflowIdOverride 'authorized-id' -WorkflowYaml @"
schema_version: "1.0.0"
workflow:
  id: impostor
  name: Impostor
  version: "1.0.0"
  integration: studio-first
steps:
  - id: review
    type: gate
    prompt: "Approve?"
"@
        try {
            $r = Invoke-Run -Fixture $fx
            $r.ExitCode | Should -Be 1
            ($r.Json.STATUS -in 'denied', 'error') | Should -BeTrue
            $r.Json.ERROR | Should -Match 'identity mismatch'
        } finally { Remove-WorkflowFixture -Fixture $fx }
    }

    It 'refuses contradictory confirm and reject of the same gate' {
        $fx = New-WorkflowFixtureProject -WorkflowYaml $script:gateYaml
        try {
            $r = Invoke-Run -Fixture $fx -ExtraArgs @('-ConfirmGate', 'review', '-RejectGate', 'review')
            $r.ExitCode | Should -Be 1
            $r.Json.STATUS | Should -Be 'denied'
            $r.Json.ERROR | Should -Match 'Contradictory gate decision'
        } finally { Remove-WorkflowFixture -Fixture $fx }
    }
}

Describe 'workflow-engine: terminal implement baseline inventory (R-B02/R-B19)' -Skip:(-not $script:yamlAvailable) {
    BeforeEach {
        $script:fixture = New-WorkflowFixtureProject -WorkflowYaml @"
schema_version: "1.0.0"
workflow:
  id: terminal-test
  name: Terminal Test
  version: "1.0.0"
  integration: studio-first
steps:
  - id: stage-implement
    type: command
    dispatch: agent
    agent_command: /speckit.implement
    expected_artifact: "specs/{{ inputs.feature }}/tasks.md"
    terminal: true
    postcondition:
      type: no-pending-tasks
      file: "specs/{{ inputs.feature }}/tasks.md"
"@
        $script:tasksPath = Join-Path $script:fixture.ProjectRoot 'specs/999-fixture/tasks.md'
        @(
            '# Tasks',
            '- [ ] T001 [P1] [Risk: Low] [Story: A] First task',
            '- [ ] T002 [P1] [Risk: Low] [Story: A] Second task'
        ) -join "`n" | Set-Content -LiteralPath $script:tasksPath
    }
    AfterEach { Remove-WorkflowFixture -Fixture $script:fixture }

    It 'does not complete when only part of the tasks are checked off' {
        $r = Invoke-Run -Fixture $script:fixture
        $r.ExitCode | Should -Be 42
        $baselineState = Get-Content -LiteralPath $r.Json.RUN_STATE_PATH -Raw | ConvertFrom-Json
        @($baselineState.vars.steps.'stage-implement'.baseline_task_ids) -join ',' | Should -Be 'T001,T002'

        (Get-Content -LiteralPath $script:tasksPath -Raw) -replace '\- \[ \] T001', '- [x] T001' |
            Set-Content -LiteralPath $script:tasksPath

        $r2 = Invoke-Run -Fixture $script:fixture -ExtraArgs @('-Resume')
        $r2.ExitCode | Should -Be 42
        $r2.Json.STATUS | Should -Be 'awaiting_agent'
        $state = Get-Content -LiteralPath $r2.Json.RUN_STATE_PATH -Raw | ConvertFrom-Json
        $state.halt_reason | Should -Match 'baseline task ID\(s\) remain unchecked: T002'
    }

    It 'completes once every baseline task remains canonical and checked' {
        $r = Invoke-Run -Fixture $script:fixture
        $r.ExitCode | Should -Be 42

        (Get-Content -LiteralPath $script:tasksPath -Raw) -replace '\- \[ \]', '- [x]' |
            Set-Content -LiteralPath $script:tasksPath

        $r2 = Invoke-Run -Fixture $script:fixture -ExtraArgs @('-Resume')
        $r2.ExitCode | Should -Be 0
        $r2.Json.STATUS | Should -Be 'completed'
    }

    It 'rejects completion when a baseline task is deleted' {
        $r = Invoke-Run -Fixture $script:fixture
        $r.ExitCode | Should -Be 42

        @(
            '# Tasks',
            '- [x] T001 [P1] [Risk: Low] [Story: A] First task'
        ) -join "`n" | Set-Content -LiteralPath $script:tasksPath

        $r2 = Invoke-Run -Fixture $script:fixture -ExtraArgs @('-Resume')
        $r2.ExitCode | Should -Be 42
        $r2.Json.STATUS | Should -Be 'awaiting_agent'
        $state = Get-Content -LiteralPath $r2.Json.RUN_STATE_PATH -Raw | ConvertFrom-Json
        $state.halt_reason | Should -Match 'baseline task ID\(s\) missing or non-canonical: T002'
    }

    It 'rejects completion when a baseline task ID is changed' {
        $r = Invoke-Run -Fixture $script:fixture
        $r.ExitCode | Should -Be 42

        @(
            '# Tasks',
            '- [x] T001 [P1] [Risk: Low] [Story: A] First task',
            '- [x] T099 [P1] [Risk: Low] [Story: A] Second task with changed ID'
        ) -join "`n" | Set-Content -LiteralPath $script:tasksPath

        $r2 = Invoke-Run -Fixture $script:fixture -ExtraArgs @('-Resume')
        $r2.ExitCode | Should -Be 42
        $state = Get-Content -LiteralPath $r2.Json.RUN_STATE_PATH -Raw | ConvertFrom-Json
        $state.halt_reason | Should -Match 'baseline task ID\(s\) missing or non-canonical: T002'
    }

    It 'rejects completion when a baseline task line is no longer canonical' {
        $r = Invoke-Run -Fixture $script:fixture
        $r.ExitCode | Should -Be 42

        @(
            '# Tasks',
            '- [x] T001 [P1] [Risk: Low] [Story: A] First task',
            '- [x] T002 [P1] [Risk: Low] Second task without Story metadata'
        ) -join "`n" | Set-Content -LiteralPath $script:tasksPath

        $r2 = Invoke-Run -Fixture $script:fixture -ExtraArgs @('-Resume')
        $r2.ExitCode | Should -Be 42
        $state = Get-Content -LiteralPath $r2.Json.RUN_STATE_PATH -Raw | ConvertFrom-Json
        $state.halt_reason | Should -Match 'baseline task ID\(s\) missing or non-canonical: T002'
    }

    It 'rejects completion when tasks.md is replaced by non-task text' {
        $r = Invoke-Run -Fixture $script:fixture
        $r.ExitCode | Should -Be 42

        "# Tasks`n`nImplementation reported complete without task evidence." |
            Set-Content -LiteralPath $script:tasksPath

        $r2 = Invoke-Run -Fixture $script:fixture -ExtraArgs @('-Resume')
        $r2.ExitCode | Should -Be 42
        $r2.Json.STATUS | Should -Be 'awaiting_agent'
        $state = Get-Content -LiteralPath $r2.Json.RUN_STATE_PATH -Raw | ConvertFrom-Json
        $state.halt_reason | Should -Match 'baseline task ID\(s\) missing or non-canonical: T001, T002'
    }

    It 'rejects completion when tasks.md is blanked to whitespace' {
        $r = Invoke-Run -Fixture $script:fixture
        $r.ExitCode | Should -Be 42

        " `n `n" | Set-Content -LiteralPath $script:tasksPath -NoNewline

        $r2 = Invoke-Run -Fixture $script:fixture -ExtraArgs @('-Resume')
        $r2.ExitCode | Should -Be 42
        $r2.Json.STATUS | Should -Be 'awaiting_agent'
        $state = Get-Content -LiteralPath $r2.Json.RUN_STATE_PATH -Raw | ConvertFrom-Json
        $state.halt_reason | Should -Match 'baseline task ID\(s\) missing or non-canonical: T001, T002'
    }

    It 'refuses -AcceptAgent as a completion substitute on a terminal step' {
        $r = Invoke-Run -Fixture $script:fixture
        $r.ExitCode | Should -Be 42

        $r2 = Invoke-Run -Fixture $script:fixture -ExtraArgs @('-Resume', '-AcceptAgent', 'stage-implement')
        $r2.ExitCode | Should -Be 42
        $state = Get-Content -LiteralPath $r2.Json.RUN_STATE_PATH -Raw | ConvertFrom-Json
        $state.halt_reason | Should -Match 'AcceptAgent is disabled for terminal step'
    }

    It 'completes a terminal step whose postcondition already holds without any artifact change' {
        # tasks.md is fully checked off BEFORE the first arrival at the terminal step, so its
        # hash never changes. The postcondition (not a hash delta) is the completion proof.
        (Get-Content -LiteralPath $script:tasksPath -Raw) -replace '\- \[ \]', '- [x]' |
            Set-Content -LiteralPath $script:tasksPath

        $r = Invoke-Run -Fixture $script:fixture
        $r.ExitCode | Should -Be 42

        $r2 = Invoke-Run -Fixture $script:fixture -ExtraArgs @('-Resume')
        $r2.ExitCode | Should -Be 0
        $r2.Json.STATUS | Should -Be 'completed'
        $state = Get-Content -LiteralPath $r2.Json.RUN_STATE_PATH -Raw | ConvertFrom-Json
        @($state.history | Where-Object { $_.step_id -eq 'stage-implement' -and $_.outcome -eq 'success-postcondition' }).Count | Should -Be 1
    }
}

Describe 'workflow-engine: terminal completion revalidates implement authorization (RVR-02)' -Skip:(-not $script:yamlAvailable) {
    BeforeEach {
        $script:fixture = New-WorkflowFixtureProject -WorkflowYaml @"
schema_version: "1.0.0"
workflow:
  id: terminal-revalidation
  name: Terminal Revalidation
  version: "1.0.0"
  integration: studio-first
steps:
  - id: stage-implement-prep
    type: command
    dispatch: script
    script: studio/scripts/powershell/setup-implement.ps1
    args: ["-FeatureDir", "specs/{{ inputs.feature }}", "-Json"]
    capture: { json: true }
  - id: stage-implement
    type: command
    dispatch: agent
    agent_command: /speckit.implement
    expected_artifact: "specs/{{ inputs.feature }}/tasks.md"
    terminal: true
    postcondition:
      type: no-pending-tasks
      file: "specs/{{ inputs.feature }}/tasks.md"
    completion_validation:
      script: studio/scripts/powershell/setup-implement.ps1
      args: ["-FeatureDir", "specs/{{ inputs.feature }}", "-CompletionValidation", "-Json"]
"@
    }
    AfterEach { Remove-WorkflowFixture -Fixture $script:fixture }

    It 'completes with zero pending tasks when all authorization evidence remains current' {
        $featureDir = Initialize-ImplementGateFeature -Fixture $script:fixture
        $first = Invoke-Run -Fixture $script:fixture
        $first.ExitCode | Should -Be 42

        (Get-Content -LiteralPath (Join-Path $featureDir 'tasks.md') -Raw) -replace '\- \[ \]', '- [x]' |
            Set-Content -LiteralPath (Join-Path $featureDir 'tasks.md') -NoNewline
        $resume = Invoke-Run -Fixture $script:fixture -ExtraArgs @('-Resume')

        $resume.ExitCode | Should -Be 0
        $resume.Json.STATUS | Should -Be 'completed'
    }

    It 'blocks completion after <Name> between first terminal arrival and resume' -TestCases @(
        @{
            Name = 'Analyze result is deleted'; WithEci = $false
            Mutation = { param($FeatureDir) Remove-Item -LiteralPath (Join-Path $FeatureDir 'analysis-result.json') }
        },
        @{
            Name = 'Analyze result is modified'; WithEci = $false
            Mutation = {
                param($FeatureDir)
                $path = Join-Path $FeatureDir 'analysis-result.json'
                $document = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable
                $document['outcome'] = 'BLOCKED'
                $document | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $path -Encoding utf8
            }
        },
        @{
            Name = 'readiness assessment is deleted'; WithEci = $false
            Mutation = { param($FeatureDir) Remove-Item -LiteralPath (Join-Path $FeatureDir 'readiness/readiness-assessment.md') }
        },
        @{
            Name = 'readiness assessment is modified'; WithEci = $false
            Mutation = { param($FeatureDir) Add-Content -LiteralPath (Join-Path $FeatureDir 'readiness/readiness-assessment.md') -Value "`nTampered." }
        },
        @{
            Name = 'plan is deleted'; WithEci = $false
            Mutation = { param($FeatureDir) Remove-Item -LiteralPath (Join-Path $FeatureDir 'plan.md') }
        },
        @{
            Name = 'plan is modified'; WithEci = $false
            Mutation = { param($FeatureDir) Add-Content -LiteralPath (Join-Path $FeatureDir 'plan.md') -Value "`nTampered." }
        },
        @{
            Name = 'ECI authorization is deleted'; WithEci = $true
            Mutation = { param($FeatureDir) Remove-Item -LiteralPath (Join-Path $FeatureDir 'readiness/eci/authorization-record.md') }
        },
        @{
            Name = 'ECI authorization is modified'; WithEci = $true
            Mutation = {
                param($FeatureDir)
                $path = Join-Path $FeatureDir 'readiness/eci/authorization-record.md'
                (Get-Content -LiteralPath $path -Raw) -replace 'READY_FOR_MAINLINE_IMPLEMENTATION', 'READY_FOR_SANDBOX_ONLY' |
                    Set-Content -LiteralPath $path -NoNewline
            }
        }
    ) {
        param($Name, $WithEci, $Mutation)

        $featureDir = Initialize-ImplementGateFeature -Fixture $script:fixture -WithEci:$WithEci
        $first = Invoke-Run -Fixture $script:fixture
        $first.ExitCode | Should -Be 42
        $first.Json.STATUS | Should -Be 'awaiting_agent'

        & $Mutation $featureDir
        (Get-Content -LiteralPath (Join-Path $featureDir 'tasks.md') -Raw) -replace '\- \[ \]', '- [x]' |
            Set-Content -LiteralPath (Join-Path $featureDir 'tasks.md') -NoNewline
        $resume = Invoke-Run -Fixture $script:fixture -ExtraArgs @('-Resume')

        $resume.ExitCode | Should -Be 42
        $resume.Json.STATUS | Should -Be 'awaiting_agent'
        $state = Get-Content -LiteralPath $resume.Json.RUN_STATE_PATH -Raw | ConvertFrom-Json
        $state.halt_reason | Should -Match 'terminal completion validation failed'
        @($state.completed_steps) | Should -Not -Contain 'stage-implement'
    }
}

Describe 'workflow-engine: terminal completion validator output is fail-closed' -Skip:(-not $script:yamlAvailable) {
    It 'blocks <Mode> validator output' -TestCases @(
        @{ Mode = 'empty'; Expected = 'no machine-readable result' },
        @{ Mode = 'malformed'; Expected = 'invalid JSON' },
        @{ Mode = 'nonboolean'; Expected = 'missing Boolean READY' },
        @{ Mode = 'nonzero'; Expected = 'exited with code 9' }
    ) {
        param($Mode, $Expected)
        $fixture = New-WorkflowFixtureProject -WorkflowYaml @"
schema_version: "1.0.0"
workflow:
  id: completion-output-$Mode
  name: Completion Output $Mode
  version: "1.0.0"
  integration: studio-first
steps:
  - id: stage-implement
    type: command
    dispatch: agent
    agent_command: /speckit.implement
    expected_artifact: "specs/{{ inputs.feature }}/tasks.md"
    terminal: true
    postcondition:
      type: no-pending-tasks
      file: "specs/{{ inputs.feature }}/tasks.md"
    completion_validation:
      script: studio/tests/fixtures/terminal-completion-validator.ps1
      args: ["$Mode"]
"@
        try {
            $tasksPath = Join-Path $fixture.ProjectRoot 'specs/999-fixture/tasks.md'
            '- [ ] T001 [P1] [Risk: Low] [Story: Foundation] Task' | Set-Content -LiteralPath $tasksPath -NoNewline
            (Invoke-Run -Fixture $fixture).ExitCode | Should -Be 42
            '- [x] T001 [P1] [Risk: Low] [Story: Foundation] Task' | Set-Content -LiteralPath $tasksPath -NoNewline

            $resume = Invoke-Run -Fixture $fixture -ExtraArgs @('-Resume')
            $resume.ExitCode | Should -Be 42
            $state = Get-Content -LiteralPath $resume.Json.RUN_STATE_PATH -Raw | ConvertFrom-Json
            $state.halt_reason | Should -Match $Expected
        } finally {
            Remove-WorkflowFixture -Fixture $fixture
        }
    }
}

Describe 'workflow-engine: switch replay history is deduplicated (R-B12)' -Skip:(-not $script:yamlAvailable) {
    It 'records a matched-case outcome once across repeated resumes' {
        $fx = New-WorkflowFixtureProject -WorkflowYaml @"
schema_version: "1.0.0"
workflow:
  id: switch-history
  name: Switch History
  version: "1.0.0"
  integration: studio-first
inputs:
  - name: status
    type: string
steps:
  - id: branch
    type: switch
    subject: "{{ inputs.status | default('READY_FOR_PLAN') }}"
    cases:
      READY_FOR_PLAN:
        - { id: gate-a, type: gate, prompt: "A?" }
        - { id: gate-b, type: gate, prompt: "B?" }
    default:
      - { id: gate-default, type: gate, prompt: "default?" }
"@
        try {
            $r1 = Invoke-Run -Fixture $fx
            $r1.ExitCode | Should -Be 43
            $r2 = Invoke-Run -Fixture $fx -ExtraArgs @('-Resume', '-ConfirmGate', 'gate-a')
            $r2.ExitCode | Should -Be 43
            $r3 = Invoke-Run -Fixture $fx -ExtraArgs @('-Resume', '-ConfirmGate', 'gate-b')
            $r3.ExitCode | Should -Be 0

            $state = Get-Content -LiteralPath $r3.Json.RUN_STATE_PATH -Raw | ConvertFrom-Json
            @($state.history | Where-Object { $_.step_id -eq 'branch' -and $_.outcome -like 'matched-case:*' }).Count | Should -Be 1
        } finally { Remove-WorkflowFixture -Fixture $fx }
    }
}

Describe 'workflow-engine: run hygiene' -Skip:(-not $script:yamlAvailable) {
    It 'DryRun leaves no resumable RunState behind' {
        $fx = New-WorkflowFixtureProject -WorkflowYaml @"
schema_version: "1.0.0"
workflow:
  id: hygiene-dryrun
  name: Hygiene DryRun
  version: "1.0.0"
  integration: studio-first
steps:
  - id: stage-script
    type: command
    dispatch: script
    script: studio/scripts/powershell/setup-clarify.ps1
    args: ["-FeatureDir", "specs/{{ inputs.feature }}", "-Json"]
"@
        try {
            $r = Invoke-Run -Fixture $fx -ExtraArgs @('-DryRun')
            $r.ExitCode | Should -Be 0
            $r.Json.RUN_STATE_PATH | Should -Match 'state\.dryrun\.json$'
            (Join-Path $fx.ProjectRoot '.workflow/runs/999-fixture/state.json') | Should -Not -Exist

            $r2 = Invoke-Run -Fixture $fx -ExtraArgs @('-Resume')
            $r2.ExitCode | Should -Not -Be 0
            $r2.Json.ERROR | Should -Match 'No RunState to resume'
        } finally { Remove-WorkflowFixture -Fixture $fx }
    }

    It 'rejects duplicate step ids anywhere in the step tree' {
        $fx = New-WorkflowFixtureProject -WorkflowYaml @"
schema_version: "1.0.0"
workflow:
  id: hygiene-dup
  name: Hygiene Dup
  version: "1.0.0"
  integration: studio-first
steps:
  - id: dup-step
    type: gate
    prompt: "First?"
  - id: outer-gate
    type: gate
    prompt: "Outer?"
    on_reject:
      - id: dup-step
        type: gate
        prompt: "Nested duplicate"
"@
        try {
            $r = Invoke-Run -Fixture $fx -ExtraArgs @('-DryRun')
            $r.ExitCode | Should -Not -Be 0
            $r.Json.ERROR | Should -Match 'Duplicate step id'
        } finally { Remove-WorkflowFixture -Fixture $fx }
    }

    It 'reports failure details in the JSON payload' {
        $fx = New-WorkflowFixtureProject -WorkflowYaml @"
schema_version: "1.0.0"
workflow:
  id: hygiene-fail
  name: Hygiene Fail
  version: "1.0.0"
  integration: studio-first
steps:
  - id: stage-fail
    type: command
    dispatch: script
    script: studio/scripts/powershell/setup-plan.ps1
    args: ["-FeatureDir", "specs/{{ inputs.feature }}", "-Json"]
"@
        try {
            $r = Invoke-Run -Fixture $fx
            $r.ExitCode | Should -Be 1
            $r.Json.STATUS | Should -Be 'failed'
            $r.Json.ERROR | Should -Not -BeNullOrEmpty
            $r.Json.ERROR.ExitCode | Should -Be 1
        } finally { Remove-WorkflowFixture -Fixture $fx }
    }

    It 'does not duplicate replay history entries across resumes' {
        $fx = New-WorkflowFixtureProject -WorkflowYaml @"
schema_version: "1.0.0"
workflow:
  id: hygiene-history
  name: Hygiene History
  version: "1.0.0"
  integration: studio-first
steps:
  - id: stage-script
    type: command
    dispatch: script
    script: studio/scripts/powershell/setup-clarify.ps1
    args: ["-FeatureDir", "specs/{{ inputs.feature }}", "-Json"]
  - id: gate-one
    type: gate
    prompt: "One?"
  - id: gate-two
    type: gate
    prompt: "Two?"
"@
        try {
            $r1 = Invoke-Run -Fixture $fx
            $r1.ExitCode | Should -Be 43

            $r2 = Invoke-Run -Fixture $fx -ExtraArgs @('-Resume', '-ConfirmGate', 'gate-one')
            $r2.ExitCode | Should -Be 43

            $r3 = Invoke-Run -Fixture $fx -ExtraArgs @('-Resume', '-ConfirmGate', 'gate-two')
            $r3.ExitCode | Should -Be 0
            $r3.Json.STATUS | Should -Be 'completed'

            $state = Get-Content -LiteralPath $r3.Json.RUN_STATE_PATH -Raw | ConvertFrom-Json
            $skips = @($state.history | Where-Object { $_.step_id -eq 'stage-script' -and $_.outcome -eq 'skipped-completed' })
            $skips.Count | Should -Be 1
            $gateOneConfirms = @($state.history | Where-Object { $_.step_id -eq 'gate-one' -and $_.outcome -eq 'gate-confirmed' })
            $gateOneConfirms.Count | Should -Be 1
        } finally { Remove-WorkflowFixture -Fixture $fx }
    }
}
