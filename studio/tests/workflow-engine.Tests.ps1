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
        param([Parameter(Mandatory)] [string]$WorkflowYaml)
        $project = Join-Path $TestDrive ("proj-{0}" -f ([System.Guid]::NewGuid().ToString('N')))
        New-Item -ItemType Directory -Path (Join-Path $project '.specify/memory') -Force | Out-Null
        '# fixture' | Set-Content -LiteralPath (Join-Path $project '.specify/memory/constitution.md')
        $featureDir = Join-Path $project 'specs/999-fixture'
        New-Item -ItemType Directory -Path $featureDir -Force | Out-Null
        '# spec' | Set-Content -LiteralPath (Join-Path $featureDir 'spec.md')
        # Install the workflow into the studio/workflows/ tree so run-workflow.ps1 can resolve it.
        $wfId = "fixture-{0}" -f ([System.Guid]::NewGuid().ToString('N').Substring(0, 8))
        $wfDir = Join-Path $script:workflowsRoot $wfId
        New-Item -ItemType Directory -Path $wfDir -Force | Out-Null
        $WorkflowYaml | Set-Content -LiteralPath (Join-Path $wfDir 'workflow.yml') -NoNewline
        return [pscustomobject]@{ ProjectRoot = $project; FeatureName = '999-fixture'; WorkflowId = $wfId; WorkflowDir = $wfDir }
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
        $env:SDD_STUDIO_ROOT = Join-Path $WorkspaceRoot 'studio'
        $argv = @('-Id', $Fixture.WorkflowId, '-Feature', $Fixture.FeatureName, '-Json') + $ExtraArgs
        $output = pwsh -NoProfile -File $script:runWorkflow @argv 2>&1
        $exitCode = $LASTEXITCODE
        $json = $null
        try { $json = ($output -join "`n") | ConvertFrom-Json } catch { $json = $null }
        return [pscustomobject]@{ Output = $output; ExitCode = $exitCode; Json = $json }
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

        $script:fixture = New-WorkflowFixtureProject -WorkflowYaml 'PLACEHOLDER'
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
