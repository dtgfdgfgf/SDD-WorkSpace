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
    script: studio/scripts/powershell/check-speckit-runtime.ps1
    args: ["-Json"]
    capture: { json: true }
"@
    }
    AfterEach { Remove-WorkflowFixture -Fixture $script:fixture }

    It 'runs a script step and completes (DryRun)' {
        $r = Invoke-Run -Fixture $script:fixture -ExtraArgs @('-DryRun')
        $r.ExitCode | Should -Be 0
        $r.Json.STATUS | Should -Be 'completed'
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
