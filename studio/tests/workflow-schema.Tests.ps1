#!/usr/bin/env pwsh
#Requires -Module Pester

# Validates studio/workflows/manifest.schema.json against valid + invalid fixtures.
# Skips engine-execution tests when powershell-yaml is missing (detection-only).

BeforeDiscovery {
    . "$PSScriptRoot/governance.config.ps1"
    $script:yamlAvailable = [bool](Get-Module -ListAvailable -Name 'powershell-yaml')
}

BeforeAll {
    . "$PSScriptRoot/governance.config.ps1"

    $script:validateScript = Join-Path $WorkspaceRoot 'studio/scripts/powershell/validate-workflow.ps1'
    $script:listScript     = Join-Path $WorkspaceRoot 'studio/scripts/powershell/list-workflows.ps1'
    $script:setStateScript = Join-Path $WorkspaceRoot 'studio/scripts/powershell/set-workflow-state.ps1'
    $script:schemaPath     = Join-Path $WorkspaceRoot 'studio/workflows/manifest.schema.json'
    $script:catalogPath    = Join-Path $WorkspaceRoot 'studio/workflows/catalog.json'
    $script:statePath      = Join-Path $WorkspaceRoot 'studio/workflows/state.json'

    function script:New-WorkflowFixture {
        param([Parameter(Mandatory)] [string]$Yaml)
        $dir = Join-Path $TestDrive ("wf-{0}" -f ([System.Guid]::NewGuid().ToString('N')))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $file = Join-Path $dir 'workflow.yml'
        $Yaml | Set-Content -LiteralPath $file -NoNewline
        return $file
    }
}

Describe 'studio/workflows/ scaffolding presence' {
    It 'manifest.schema.json exists and is valid JSON' {
        Test-Path -LiteralPath $script:schemaPath | Should -BeTrue
        { Get-Content -LiteralPath $script:schemaPath -Raw | ConvertFrom-Json } | Should -Not -Throw
    }

    It 'catalog.json exists and conforms to its schema shape' {
        Test-Path -LiteralPath $script:catalogPath | Should -BeTrue
        $catalog = Get-Content -LiteralPath $script:catalogPath -Raw | ConvertFrom-Json
        $catalog.PSObject.Properties.Name | Should -Contain 'version'
        $catalog.PSObject.Properties.Name | Should -Contain 'policy'
        $catalog.PSObject.Properties.Name | Should -Contain 'workflows'
        $catalog.policy.mode | Should -Be 'studio-first'
    }

    It 'state.json exists and starts empty' {
        Test-Path -LiteralPath $script:statePath | Should -BeTrue
        $state = Get-Content -LiteralPath $script:statePath -Raw | ConvertFrom-Json
        $state.states.PSObject.Properties.Name.Count | Should -Be 0
    }

    It 'POLICY.md exists' {
        Test-Path -LiteralPath (Join-Path $WorkspaceRoot 'studio/workflows/POLICY.md') | Should -BeTrue
    }
}

Describe 'list-workflows.ps1 against the live catalog' {
    It 'reports VALID=true and registers sdd-pipeline' {
        $output = pwsh -NoProfile -File $script:listScript -Json
        $LASTEXITCODE | Should -Be 0
        $r = ($output -join "`n") | ConvertFrom-Json
        $r.VALID | Should -BeTrue
        $r.ERROR_COUNT | Should -Be 0
        @($r.WORKFLOWS.id) | Should -Contain 'sdd-pipeline'
    }

    It 'advertises sdd-pipeline as experimental and disabled until promotion' {
        $catalog = Get-Content -LiteralPath $script:catalogPath -Raw | ConvertFrom-Json
        $entry = @($catalog.workflows | Where-Object id -eq 'sdd-pipeline')[0]

        $entry.reviewStatus | Should -Be 'experimental'
        $entry.trustLevel | Should -Be 'experimental'
        $entry.defaultEnabled | Should -BeFalse
        $entry.approvedBy | Should -BeNullOrEmpty
        $entry.approvedAt | Should -BeNullOrEmpty

        $output = pwsh -NoProfile -File $script:listScript -Id 'sdd-pipeline' -Json
        $LASTEXITCODE | Should -Be 0
        $listed = (($output -join "`n") | ConvertFrom-Json).WORKFLOWS[0]
        $listed.enabled | Should -BeFalse
    }
}

Describe 'validate-workflow.ps1 detection-only behavior when powershell-yaml is missing' -Skip:($script:yamlAvailable) {
    It 'reports YAML_AVAILABLE=false and exits non-zero with install hint' {
        $valid = @"
schema_version: "1.0.0"
workflow:
  id: stub
  name: Stub
  version: "1.0.0"
  integration: studio-first
steps:
  - id: noop
    type: command
    dispatch: script
    script: studio/scripts/powershell/check-speckit-runtime.ps1
"@
        $file = New-WorkflowFixture -Yaml $valid
        $output = pwsh -NoProfile -File $script:validateScript -Path $file -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match 'powershell-yaml'
        ($output -join "`n") | Should -Match 'Install-Module'
    }
}

Describe 'validate-workflow.ps1 schema accepts valid Wave-3 step types' -Skip:(-not $script:yamlAvailable) {
    It 'accepts a minimal command + agent + gate + if + switch workflow' {
        $valid = @"
schema_version: "1.0.0"
workflow:
  id: minimal
  name: Minimal
  version: "1.0.0"
  integration: studio-first
inputs:
  - name: feature
    type: feature-id
    required: true
steps:
  - id: stage-script
    type: command
    dispatch: script
    script: studio/scripts/powershell/check-speckit-runtime.ps1
    args: ["-Json"]
  - id: stage-agent
    type: command
    dispatch: agent
    agent_command: /speckit.specify
    expected_artifact: "specs/{{ inputs.feature }}/spec.md"
  - id: review
    type: gate
    prompt: "Approve?"
  - id: branch-check
    type: if
    condition: "{{ steps.stage-script.outcome == 'success' }}"
    then:
      - { id: ok-step, type: command, dispatch: script, script: noop }
  - id: branch-status
    type: switch
    subject: "{{ vars.status | default('NOT_READY') }}"
    cases:
      READY_FOR_PLAN:
        - { id: plan-step, type: command, dispatch: script, script: noop }
    default:
      - { id: halt, type: command, dispatch: script, script: noop }
"@
        $file = New-WorkflowFixture -Yaml $valid
        $output = pwsh -NoProfile -File $script:validateScript -Path $file -Json
        $LASTEXITCODE | Should -Be 0
        $r = ($output -join "`n") | ConvertFrom-Json
        $r.VALID | Should -BeTrue
        $r.SCHEMA_VALID | Should -BeTrue
    }
}

Describe 'validate-workflow.ps1 schema rejects malformed step shapes' -Skip:(-not $script:yamlAvailable) {
    It 'rejects a workflow missing schema_version' {
        $bad = @"
workflow:
  id: x
  name: x
  version: "1.0.0"
  integration: studio-first
steps:
  - id: a
    type: command
    dispatch: script
    script: noop
"@
        $file = New-WorkflowFixture -Yaml $bad
        $output = pwsh -NoProfile -File $script:validateScript -Path $file -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
    }

    It 'rejects a command step with neither script nor agent_command' {
        $bad = @"
schema_version: "1.0.0"
workflow:
  id: x
  name: x
  version: "1.0.0"
  integration: studio-first
steps:
  - id: orphan
    type: command
    dispatch: script
"@
        $file = New-WorkflowFixture -Yaml $bad
        $output = pwsh -NoProfile -File $script:validateScript -Path $file -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
    }

    It 'rejects an unknown step type' {
        $bad = @"
schema_version: "1.0.0"
workflow:
  id: x
  name: x
  version: "1.0.0"
  integration: studio-first
steps:
  - id: bogus
    type: while
    condition: "true"
"@
        $file = New-WorkflowFixture -Yaml $bad
        $output = pwsh -NoProfile -File $script:validateScript -Path $file -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
    }
}
