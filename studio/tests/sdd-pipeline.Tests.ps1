#!/usr/bin/env pwsh
#Requires -Module Pester

# Locks the first built-in workflow:
#   - workflow.yml schema-validates
#   - readiness switch covers all 8 primary statuses
#   - nested ECI switch covers all 3 authorization outcomes
#   - all seven SDD stages plus speckit.eci are referenced
#   - every dispatch: agent step's expected_artifact stays under specs/<feature>/

BeforeDiscovery {
    $script:yamlAvailable = [bool](Get-Module -ListAvailable -Name 'powershell-yaml')
}

BeforeAll {
    . "$PSScriptRoot/governance.config.ps1"
    $script:workflowPath = Join-Path $WorkspaceRoot 'studio/workflows/sdd-pipeline/workflow.yml'
    $script:validateScript = Join-Path $WorkspaceRoot 'studio/scripts/powershell/validate-workflow.ps1'
}

Describe 'sdd-pipeline.workflow.yml exists and is schema-valid' -Skip:(-not $script:yamlAvailable) {
    It 'validate-workflow.ps1 -Id sdd-pipeline reports VALID=true' {
        $output = pwsh -NoProfile -File $script:validateScript -Id sdd-pipeline -Json
        $LASTEXITCODE | Should -Be 0
        $r = ($output -join "`n") | ConvertFrom-Json
        $r.VALID | Should -BeTrue
        $r.SCHEMA_VALID | Should -BeTrue
        $r.WORKFLOW_META.id | Should -Be 'sdd-pipeline'
    }
}

Describe 'sdd-pipeline.workflow.yml encodes all readiness primary statuses' {
    It 'contains every one of the 8 readiness primary statuses' {
        $content = Get-Content -LiteralPath $script:workflowPath -Raw
        foreach ($status in 'READY_FOR_PLAN', 'ROUTE_TO_ECI', 'ROUTE_TO_REPO_CONTEXT',
                            'ROUTE_TO_DECISION', 'ROUTE_TO_VALIDATION', 'ROUTE_TO_ACCESS',
                            'EXPLORATORY_ONLY', 'NOT_READY') {
            $content | Should -Match $status
        }
    }
    It 'contains every one of the 3 ECI authorization outcomes' {
        $content = Get-Content -LiteralPath $script:workflowPath -Raw
        foreach ($auth in 'READY_FOR_MAINLINE_IMPLEMENTATION', 'READY_FOR_SANDBOX_ONLY', 'READY_FOR_SPIKE_ONLY') {
            $content | Should -Match $auth
        }
    }
}

Describe 'sdd-pipeline references every SDD agent slash command' {
    It 'references all seven mandatory stages plus /speckit.eci' {
        $content = Get-Content -LiteralPath $script:workflowPath -Raw
        foreach ($cmd in '/speckit.specify', '/speckit.clarify', '/speckit.readiness',
                         '/speckit.plan', '/speckit.tasks', '/speckit.analyze',
                         '/speckit.implement', '/speckit.eci') {
            $content | Should -Match ([regex]::Escape($cmd))
        }
    }
}

Describe 'every agent dispatch step targets specs/<feature>/' -Skip:(-not $script:yamlAvailable) {
    It 'no expected_artifact escapes the feature directory' {
        Import-Module -Name 'powershell-yaml' -ErrorAction Stop
        $doc = ConvertFrom-Yaml -Yaml (Get-Content -LiteralPath $script:workflowPath -Raw) -Ordered
        function script:Walk-Steps {
            param($Steps)
            foreach ($s in $Steps) {
                if ($s.type -eq 'command' -and $s.dispatch -eq 'agent') {
                    $s.expected_artifact | Should -Match '^specs/'
                }
                if ($s.type -eq 'if') {
                    if ($s.then) { Walk-Steps -Steps $s.then }
                    if ($s.else) { Walk-Steps -Steps $s.else }
                }
                if ($s.type -eq 'switch') {
                    foreach ($k in $s.cases.Keys) { Walk-Steps -Steps $s.cases[$k] }
                    if ($s.default) { Walk-Steps -Steps $s.default }
                }
                if ($s.type -eq 'gate' -and $s.on_reject) { Walk-Steps -Steps $s.on_reject }
            }
        }
        Walk-Steps -Steps $doc.steps
    }
}

Describe 'plan preparation binds to the workflow feature' -Skip:(-not $script:yamlAvailable) {
    It 'passes the explicit specs feature directory to setup-plan.ps1' {
        Import-Module -Name 'powershell-yaml' -ErrorAction Stop
        $doc = ConvertFrom-Yaml -Yaml (Get-Content -LiteralPath $script:workflowPath -Raw) -Ordered
        $step = @($doc.steps | Where-Object { $_.id -eq 'stage-plan-prep' })

        $step.Count | Should -Be 1
        $step[0].script | Should -Be 'studio/scripts/powershell/setup-plan.ps1'
        ($step[0].args -join '|') | Should -Be '-FeatureDir|specs/{{ inputs.feature }}|-Json'

        $agentStep = @($doc.steps | Where-Object { $_.id -eq 'stage-plan' })
        $agentStep.Count | Should -Be 1
        $agentStep[0].operator_message | Should -Match '/speckit\.plan -FeatureDir specs/\{\{ inputs\.feature \}\}'
    }
}
