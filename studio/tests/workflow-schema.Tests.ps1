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

    function script:New-WorkflowRegistryFixture {
        $studioRoot = Join-Path $TestDrive ("workflow-registry-{0}/studio" -f ([System.Guid]::NewGuid().ToString('N')))
        $workflowsRoot = Join-Path $studioRoot 'workflows'
        New-Item -ItemType Directory -Path (Join-Path $workflowsRoot 'sdd-pipeline') -Force | Out-Null

        foreach ($name in @('catalog.json', 'catalog.schema.json', 'state.json', 'state.schema.json')) {
            Copy-Item -LiteralPath (Join-Path $WorkspaceRoot "studio/workflows/$name") -Destination (Join-Path $workflowsRoot $name) -Force
        }

        return $studioRoot
    }

    function script:Invoke-WorkflowRegistryFixture {
        param([Parameter(Mandatory)] [string]$StudioRoot)

        $output = & pwsh -NoProfile -Command '& { param($listScript, $studioRoot) $env:SDD_STUDIO_ROOT = $studioRoot; & $listScript -Json; exit $LASTEXITCODE }' $script:listScript $StudioRoot 2>&1
        $exitCode = $LASTEXITCODE
        $raw = $output -join [Environment]::NewLine
        try {
            $result = $raw | ConvertFrom-Json
        } catch {
            throw "Workflow registry fixture did not return JSON. Exit=$exitCode Output=$raw"
        }

        return [PSCustomObject]@{
            ExitCode = $exitCode
            Result   = $result
            Raw      = $raw
        }
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

    It 'retires the unenforced workflow compatibility version field without promoting sdd-pipeline' {
        $manifest = Get-Content `
            -LiteralPath (Join-Path $WorkspaceRoot 'studio/workflows/sdd-pipeline/manifest.json') `
            -Raw |
            ConvertFrom-Json -AsHashtable
        $catalog = Get-Content -LiteralPath $script:catalogPath -Raw | ConvertFrom-Json -AsHashtable
        $entry = @($catalog.workflows | Where-Object { $_.id -eq 'sdd-pipeline' })[0]

        $manifest.compatibility.ContainsKey('minStudioConstitutionVersion') | Should -BeFalse
        $entry.reviewStatus | Should -BeExactly 'experimental'
        $entry.trustLevel | Should -BeExactly 'experimental'
        $entry.defaultEnabled | Should -BeFalse
        $entry.workflowSha256 | Should -BeNullOrEmpty
    }

    It 'limits workflow state provenance to default and manual across catalog and schemas' {
        $catalog = Get-Content -LiteralPath $script:catalogPath -Raw | ConvertFrom-Json
        @($catalog.policy.stateSources) | Should -HaveCount 2
        @($catalog.policy.stateSources) | Should -Contain 'default'
        @($catalog.policy.stateSources) | Should -Contain 'manual'
        @($catalog.policy.stateSources) | Should -Not -Contain 'sync'

        $catalogSchema = Get-Content `
            -LiteralPath (Join-Path $WorkspaceRoot 'studio/workflows/catalog.schema.json') `
            -Raw
        $stateSchema = Get-Content `
            -LiteralPath (Join-Path $WorkspaceRoot 'studio/workflows/state.schema.json') `
            -Raw
        $catalogSchema | Should -Not -Match '"sync"'
        $stateSchema | Should -Not -Match '"sync"'
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
        $entry.version | Should -Be '1.1.0'
        $entry.defaultEnabled | Should -BeFalse
        $entry.approvedBy | Should -BeNullOrEmpty
        $entry.approvedAt | Should -BeNullOrEmpty
        $entry.workflowSha256 | Should -BeNullOrEmpty

        $output = pwsh -NoProfile -File $script:listScript -Id 'sdd-pipeline' -Json
        $LASTEXITCODE | Should -Be 0
        $listed = (($output -join "`n") | ConvertFrom-Json).WORKFLOWS[0]
        $listed.enabled | Should -BeFalse
        $listed.executionAuthorized | Should -BeFalse
        $listed.workflowSha256 | Should -BeNullOrEmpty
        $listed.actualWorkflowSha256 | Should -Match '^[a-f0-9]{64}$'
        $listed.workflowDigestMatches | Should -BeNullOrEmpty
    }
}

Describe 'list-workflows.ps1 registry schema and cross-ledger failures' {
    It 'returns non-zero when state.json is missing' {
        $studioRoot = New-WorkflowRegistryFixture
        Remove-Item -LiteralPath (Join-Path $studioRoot 'workflows/state.json') -Force
        $listing = Invoke-WorkflowRegistryFixture -StudioRoot $studioRoot

        $listing.ExitCode | Should -Not -Be 0
        $listing.Result.VALID | Should -BeFalse
        ($listing.Result.ERRORS -join "`n") | Should -Match 'state.*missing|missing.*state'
    }

    It 'returns non-zero when catalog.json violates catalog.schema.json' {
        $studioRoot = New-WorkflowRegistryFixture
        $catalogPath = Join-Path $studioRoot 'workflows/catalog.json'
        $catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json
        $catalog.workflows[0].reviewStatus = 'not-a-review-status'
        $catalog | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $catalogPath -Encoding utf8
        $listing = Invoke-WorkflowRegistryFixture -StudioRoot $studioRoot

        $listing.ExitCode | Should -Not -Be 0
        $listing.Result.VALID | Should -BeFalse
        ($listing.Result.ERRORS -join "`n") | Should -Match 'catalog.*schema|schema.*catalog'
    }

    It 'returns non-zero when the catalog schema is missing' {
        $studioRoot = New-WorkflowRegistryFixture
        Remove-Item -LiteralPath (Join-Path $studioRoot 'workflows/catalog.schema.json') -Force
        $listing = Invoke-WorkflowRegistryFixture -StudioRoot $studioRoot

        $listing.ExitCode | Should -Not -Be 0
        $listing.Result.VALID | Should -BeFalse
        ($listing.Result.ERRORS -join "`n") | Should -Match 'catalog schema missing|schema missing.*catalog'
    }

    It 'returns structured non-zero output when a registry document is JSON null' {
        $studioRoot = New-WorkflowRegistryFixture
        [System.IO.File]::WriteAllText(
            (Join-Path $studioRoot 'workflows/catalog.json'),
            "null`n",
            [System.Text.UTF8Encoding]::new($false)
        )
        $listing = Invoke-WorkflowRegistryFixture -StudioRoot $studioRoot

        $listing.ExitCode | Should -Not -Be 0
        $listing.Result.VALID | Should -BeFalse
        ($listing.Result.ERRORS -join "`n") | Should -Match 'catalog.*schema|schema.*catalog'
    }

    It 'returns structured non-zero output when a registry document is a JSON scalar' {
        $studioRoot = New-WorkflowRegistryFixture
        [System.IO.File]::WriteAllText(
            (Join-Path $studioRoot 'workflows/state.json'),
            "42`n",
            [System.Text.UTF8Encoding]::new($false)
        )
        $listing = Invoke-WorkflowRegistryFixture -StudioRoot $studioRoot

        $listing.ExitCode | Should -Not -Be 0
        $listing.Result.VALID | Should -BeFalse
        ($listing.Result.ERRORS -join "`n") | Should -Match 'state.*schema|schema.*state'
    }

    It 'rejects a permissive boolean schema instead of trusting it' {
        $studioRoot = New-WorkflowRegistryFixture
        [System.IO.File]::WriteAllText(
            (Join-Path $studioRoot 'workflows/catalog.schema.json'),
            "true`n",
            [System.Text.UTF8Encoding]::new($false)
        )
        $listing = Invoke-WorkflowRegistryFixture -StudioRoot $studioRoot

        $listing.ExitCode | Should -Not -Be 0
        $listing.Result.VALID | Should -BeFalse
        ($listing.Result.ERRORS -join "`n") | Should -Match 'canonical object shape'
    }

    It 'rejects default-enabled experimental workflows even when each JSON document matches its schema' {
        $studioRoot = New-WorkflowRegistryFixture
        $catalogPath = Join-Path $studioRoot 'workflows/catalog.json'
        $catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json
        $catalog.workflows[0].defaultEnabled = $true
        $catalog | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $catalogPath -Encoding utf8
        $listing = Invoke-WorkflowRegistryFixture -StudioRoot $studioRoot

        $listing.ExitCode | Should -Not -Be 0
        $listing.Result.VALID | Should -BeFalse
        ($listing.Result.ERRORS -join "`n") | Should -Match 'defaultEnabled=true requires'
    }

    It 'rejects state activation for an experimental workflow' {
        $studioRoot = New-WorkflowRegistryFixture
        $statePath = Join-Path $studioRoot 'workflows/state.json'
        $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json -AsHashtable
        $state.states['sdd-pipeline'] = [ordered]@{
            enabled       = $true
            pinnedVersion = '1.0.0'
            changedAt     = '2026-07-13T00:00:00+08:00'
            source        = 'manual'
        }
        $state | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $statePath -Encoding utf8
        $listing = Invoke-WorkflowRegistryFixture -StudioRoot $studioRoot

        $listing.ExitCode | Should -Not -Be 0
        $listing.Result.VALID | Should -BeFalse
        ($listing.Result.ERRORS -join "`n") | Should -Match 'enabled state requires'
    }

    It 'returns non-zero when state.json references an unknown workflow id' {
        $studioRoot = New-WorkflowRegistryFixture
        $statePath = Join-Path $studioRoot 'workflows/state.json'
        $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json -AsHashtable
        $state.states['unknown-workflow'] = [ordered]@{
            enabled       = $false
            pinnedVersion = '1.0.0'
            changedAt     = '2026-07-13T00:00:00+08:00'
            source        = 'manual'
        }
        $state | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $statePath -Encoding utf8
        $listing = Invoke-WorkflowRegistryFixture -StudioRoot $studioRoot

        $listing.ExitCode | Should -Not -Be 0
        $listing.Result.VALID | Should -BeFalse
        ($listing.Result.ERRORS -join "`n") | Should -Match 'unknown catalog id'
    }

    It 'returns non-zero when a state pin differs from the catalog version' {
        $studioRoot = New-WorkflowRegistryFixture
        $statePath = Join-Path $studioRoot 'workflows/state.json'
        $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json -AsHashtable
        $state.states['sdd-pipeline'] = [ordered]@{
            enabled       = $false
            pinnedVersion = '9.9.9'
            changedAt     = '2026-07-13T00:00:00+08:00'
            source        = 'manual'
        }
        $state | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $statePath -Encoding utf8
        $listing = Invoke-WorkflowRegistryFixture -StudioRoot $studioRoot

        $listing.ExitCode | Should -Not -Be 0
        $listing.Result.VALID | Should -BeFalse
        ($listing.Result.ERRORS -join "`n") | Should -Match 'pinnedVersion.*differs'
    }

    It 'validates every catalog sourcePath even when Id filters the output' {
        $studioRoot = New-WorkflowRegistryFixture
        $catalogPath = Join-Path $studioRoot 'workflows/catalog.json'
        $catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json -AsHashtable
        $copy = [ordered]@{}
        foreach ($key in $catalog.workflows[0].Keys) { $copy[$key] = $catalog.workflows[0][$key] }
        $copy.id = 'other-workflow'
        $copy.sourcePath = 'workflows/missing-other'
        $catalog.workflows = @($catalog.workflows[0], $copy)
        $catalog | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $catalogPath -Encoding utf8

        $output = & pwsh -NoProfile -Command '& { param($listScript, $studioRoot) $env:SDD_STUDIO_ROOT = $studioRoot; & $listScript -Id sdd-pipeline -Json; exit $LASTEXITCODE }' $script:listScript $studioRoot 2>&1
        $exitCode = $LASTEXITCODE
        $listing = ($output -join [Environment]::NewLine) | ConvertFrom-Json

        $exitCode | Should -Not -Be 0
        $listing.VALID | Should -BeFalse
        ($listing.ERRORS -join "`n") | Should -Match 'missing-other'
    }
}

Describe 'validate-workflow.ps1 detection-only behavior when powershell-yaml is missing' {
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
        $output = pwsh -NoProfile -Command '& { param($validator, $workflow) $env:PSModulePath = ''C:\__sdd_fixture_no_modules__''; & $validator -Path $workflow -Json; exit $LASTEXITCODE }' $script:validateScript $file 2>&1
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
    condition: "steps.stage-script.outcome == 'success'"
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

    It 'accepts the canonical read-only resume revalidation command shape' {
        $valid = @"
schema_version: "1.0.0"
workflow:
  id: revalidate-valid
  name: Revalidate Valid
  version: "1.0.0"
  integration: studio-first
steps:
  - id: validate-current-evidence
    type: command
    dispatch: script
    script: studio/scripts/powershell/validate-feature-structure.ps1
    args: ["-FeatureDir", "specs/{{ inputs.feature }}", "-Json"]
    capture: { json: true }
    revalidate_on_resume: true
"@
        $file = New-WorkflowFixture -Yaml $valid
        $output = pwsh -NoProfile -File $script:validateScript -Path $file -Json
        $LASTEXITCODE | Should -Be 0
        (($output -join "`n") | ConvertFrom-Json).SCHEMA_VALID | Should -BeTrue
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

    It 'rejects unsafe resume revalidation shape: <Name>' -ForEach @(
        @{
            Name = 'arbitrary script'
            StepBody = @'
  - id: unsafe-replay
    type: command
    dispatch: script
    script: studio/scripts/powershell/setup-plan.ps1
    args: ["-Json"]
    capture: { json: true }
    revalidate_on_resume: true
'@
        }
        @{
            Name = 'agent dispatch'
            StepBody = @'
  - id: unsafe-agent-replay
    type: command
    dispatch: agent
    agent_command: /speckit.readiness
    expected_artifact: "specs/{{ inputs.feature }}/readiness/readiness-assessment.md"
    args: ["-Json"]
    capture: { json: true }
    revalidate_on_resume: true
'@
        }
        @{
            Name = 'missing JSON capture'
            StepBody = @'
  - id: missing-capture
    type: command
    dispatch: script
    script: studio/scripts/powershell/validate-feature-structure.ps1
    args: ["-Json"]
    revalidate_on_resume: true
'@
        }
        @{
            Name = 'false JSON capture'
            StepBody = @'
  - id: false-capture
    type: command
    dispatch: script
    script: studio/scripts/powershell/validate-feature-structure.ps1
    args: ["-Json"]
    capture: { json: false }
    revalidate_on_resume: true
'@
        }
        @{
            Name = 'missing Json argument'
            StepBody = @'
  - id: missing-json-arg
    type: command
    dispatch: script
    script: studio/scripts/powershell/validate-feature-structure.ps1
    args: ["-FeatureDir", "specs/{{ inputs.feature }}"]
    capture: { json: true }
    revalidate_on_resume: true
'@
        }
        @{
            Name = 'non-zero expected exit'
            StepBody = @'
  - id: expected-failure
    type: command
    dispatch: script
    script: studio/scripts/powershell/validate-feature-structure.ps1
    args: ["-Json"]
    expected_exit_code: 1
    capture: { json: true }
    revalidate_on_resume: true
'@
        }
        @{
            Name = 'false replay flag'
            StepBody = @'
  - id: false-replay
    type: command
    dispatch: script
    script: studio/scripts/powershell/validate-feature-structure.ps1
    args: ["-Json"]
    capture: { json: true }
    revalidate_on_resume: false
'@
        }
        @{
            Name = 'string replay flag'
            StepBody = @'
  - id: string-replay
    type: command
    dispatch: script
    script: studio/scripts/powershell/validate-feature-structure.ps1
    args: ["-Json"]
    capture: { json: true }
    revalidate_on_resume: "true"
'@
        }
        @{
            Name = 'null replay flag'
            StepBody = @'
  - id: null-replay
    type: command
    dispatch: script
    script: studio/scripts/powershell/validate-feature-structure.ps1
    args: ["-Json"]
    capture: { json: true }
    revalidate_on_resume: null
'@
        }
    ) {
        $bad = @"
schema_version: "1.0.0"
workflow:
  id: revalidate-invalid
  name: Revalidate Invalid
  version: "1.0.0"
  integration: studio-first
steps:
$StepBody
"@
        $file = New-WorkflowFixture -Yaml $bad
        $output = pwsh -NoProfile -File $script:validateScript -Path $file -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
    }
}

Describe 'validate-workflow.ps1 manifest entryPoints existence (R-B15)' -Skip:(-not $script:yamlAvailable) {
    BeforeAll {
        $script:entryYaml = @"
schema_version: "1.0.0"
workflow:
  id: entrypoint-fixture
  name: EntryPoint Fixture
  version: "1.0.0"
  integration: studio-first
steps:
  - id: review
    type: gate
    prompt: "Approve?"
"@
    }

    It 'fails when manifest.json advertises a nonexistent entry point' {
        $file = New-WorkflowFixture -Yaml $script:entryYaml
        '{"id":"entrypoint-fixture","version":"1.0.0","entryPoints":{"scripts":["scripts/does-not-exist.ps1"]}}' |
            Set-Content -LiteralPath (Join-Path (Split-Path -Parent $file) 'manifest.json')

        $output = pwsh -NoProfile -File $script:validateScript -Path $file -Json 2>&1
        $LASTEXITCODE | Should -Be 1
        $result = ($output -join "`n") | ConvertFrom-Json
        $result.VALID | Should -BeFalse
        ($result.ERRORS -join "`n") | Should -Match 'entryPoint does not exist'
    }

    It 'passes when every advertised entry point exists' {
        $file = New-WorkflowFixture -Yaml $script:entryYaml
        $wfDir = Split-Path -Parent $file
        New-Item -ItemType Directory -Path (Join-Path $wfDir 'docs') -Force | Out-Null
        '# fixture doc' | Set-Content -LiteralPath (Join-Path $wfDir 'docs/README.md')
        '{"id":"entrypoint-fixture","version":"1.0.0","entryPoints":{"docs":["docs/README.md"]}}' |
            Set-Content -LiteralPath (Join-Path $wfDir 'manifest.json')

        $output = pwsh -NoProfile -File $script:validateScript -Path $file -Json 2>&1
        $LASTEXITCODE | Should -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        $result.VALID | Should -BeTrue
    }

    It 'validates the live sdd-pipeline manifest entry points' {
        $output = pwsh -NoProfile -File $script:validateScript -Id sdd-pipeline -Json 2>&1
        $LASTEXITCODE | Should -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        $result.VALID | Should -BeTrue
    }
}

Describe 'validate-workflow.ps1 restricts terminal/postcondition to agent dispatch' -Skip:(-not $script:yamlAvailable) {
    It 'rejects a script step carrying a postcondition' {
        $bad = @"
schema_version: "1.0.0"
workflow:
  id: bad-postcondition
  name: Bad Postcondition
  version: "1.0.0"
  integration: studio-first
steps:
  - id: prep
    type: command
    dispatch: script
    script: studio/scripts/powershell/check-speckit-runtime.ps1
    args: ["-Json"]
    terminal: true
    postcondition:
      type: no-pending-tasks
      file: "specs/{{ inputs.feature }}/tasks.md"
"@
        $file = New-WorkflowFixture -Yaml $bad
        $output = pwsh -NoProfile -File $script:validateScript -Path $file -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
    }

    It 'rejects completion validation on a non-terminal agent command' {
        $bad = @"
schema_version: "1.0.0"
workflow:
  id: bad-completion-validation
  name: Bad Completion Validation
  version: "1.0.0"
  integration: studio-first
steps:
  - id: implement
    type: command
    dispatch: agent
    agent_command: /speckit.implement
    expected_artifact: "specs/{{ inputs.feature }}/tasks.md"
    postcondition:
      type: no-pending-tasks
      file: "specs/{{ inputs.feature }}/tasks.md"
    completion_validation:
      script: studio/scripts/powershell/setup-implement.ps1
      args: ["-CompletionValidation", "-Json"]
"@
        $file = New-WorkflowFixture -Yaml $bad
        $output = pwsh -NoProfile -File $script:validateScript -Path $file -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
    }
}
