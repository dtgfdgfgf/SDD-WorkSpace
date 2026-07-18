#!/usr/bin/env pwsh
#Requires -Module Pester

# Locks the first built-in workflow:
#   - workflow.yml schema-validates
#   - readiness switch covers all 8 primary statuses
#   - nested ECI switch covers all 4 authorization outcomes
#   - three bounded ECI outcomes re-enter a second Readiness step
#   - ECI NOT_READY fails closed before second Readiness or Plan
#   - all seven SDD stages plus speckit.eci are referenced
#   - every dispatch: agent step's expected_artifact stays under specs/<feature>/

BeforeDiscovery {
    $script:yamlAvailable = [bool](Get-Module -ListAvailable -Name 'powershell-yaml')
}

BeforeAll {
    . "$PSScriptRoot/governance.config.ps1"
    $script:workflowPath = Join-Path $WorkspaceRoot 'studio/workflows/sdd-pipeline/workflow.yml'
    $script:manifestPath = Join-Path $WorkspaceRoot 'studio/workflows/sdd-pipeline/manifest.json'
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
    It 'contains every one of the 4 ECI authorization outcomes' {
        $content = Get-Content -LiteralPath $script:workflowPath -Raw
        foreach ($auth in 'READY_FOR_MAINLINE_IMPLEMENTATION', 'READY_FOR_SANDBOX_ONLY', 'READY_FOR_SPIKE_ONLY', 'NOT_READY') {
            $content | Should -Match $auth
        }
    }
}

Describe 'sdd-pipeline routes validated initial and post-ECI Readiness state' -Skip:(-not $script:yamlAvailable) {
    BeforeAll {
        Import-Module -Name 'powershell-yaml' -ErrorAction Stop
        $script:pipelineDocument = ConvertFrom-Yaml `
            -Yaml (Get-Content -LiteralPath $script:workflowPath -Raw) `
            -Ordered
    }

    It 'keeps workflow.yml and manifest.json on the same 1.1.0 graph version' {
        $manifest = Get-Content -LiteralPath $script:manifestPath -Raw | ConvertFrom-Json
        $script:pipelineDocument.workflow.version | Should -Be '1.1.0'
        $manifest.version | Should -Be '1.1.0'
    }

    It 'uses the exact fresh Readiness primary status and a setup-eci gate for the initial ECI decision' {
        $ids = @($script:pipelineDocument.steps | ForEach-Object id)
        $validationIndex = [array]::IndexOf($ids, 'stage-readiness-routing-validation')
        $eciIndex = [array]::IndexOf($ids, 'branch-readiness-eci')

        $validationIndex | Should -BeGreaterThan ([array]::IndexOf($ids, 'stage-readiness'))
        $validationIndex | Should -BeLessThan $eciIndex

        $validation = $script:pipelineDocument.steps[$validationIndex]
        $validation.script | Should -Be 'studio/scripts/powershell/validate-feature-structure.ps1'
        @($validation.args) | Should -Contain '-DeferEciDossier'
        $validation.capture.json | Should -BeTrue
        $validation.revalidate_on_resume | Should -BeTrue

        $eciBranch = $script:pipelineDocument.steps[$eciIndex]
        $eciBranch.condition |
            Should -Be "vars.steps.stage-readiness-routing-validation.json.READINESS_PRIMARY_STATUS == 'ROUTE_TO_ECI'"
        $eciBranch.condition | Should -Not -Match '\{\{'

        $thenIds = @($eciBranch.then | ForEach-Object id)
        [array]::IndexOf($thenIds, 'stage-eci-entry-gate') |
            Should -BeLessThan ([array]::IndexOf($thenIds, 'stage-eci'))
        $entryGate = @($eciBranch.then | Where-Object id -eq 'stage-eci-entry-gate')[0]
        $entryGate.script | Should -Be 'studio/scripts/powershell/setup-eci.ps1'
        @($entryGate.args) | Should -Be @(
            '-FeatureDir',
            'specs/{{ inputs.feature }}',
            '-Json'
        )
        $entryGate.capture.json | Should -BeTrue
        $entryGate.Contains('revalidate_on_resume') | Should -BeFalse
    }

    It 'freshly validates the ECI dossier before routing the authorization outcome' {
        $eciBranch = @($script:pipelineDocument.steps | Where-Object id -eq 'branch-readiness-eci')[0]
        $thenIds = @($eciBranch.then | ForEach-Object id)
        $dossierIndex = [array]::IndexOf($thenIds, 'stage-eci-dossier-validation')
        $switchIndex = [array]::IndexOf($thenIds, 'branch-eci-authorization')

        $dossierIndex | Should -BeGreaterThan ([array]::IndexOf($thenIds, 'stage-eci'))
        $dossierIndex | Should -BeLessThan $switchIndex

        $dossierValidation = $eciBranch.then[$dossierIndex]
        $dossierValidation.script | Should -Be 'studio/scripts/powershell/validate-feature-structure.ps1'
        @($dossierValidation.args) | Should -Contain '-RequireEciDossier'
        $dossierValidation.capture.json | Should -BeTrue
        $dossierValidation.revalidate_on_resume | Should -BeTrue

        $outcomeSwitch = $eciBranch.then[$switchIndex]
        $outcomeSwitch.subject | Should -Be "{{ vars.steps.stage-eci-dossier-validation.json.ECI_AUTHORIZATION_OUTCOME | default('NOT_READY') }}"
        $outcomeSwitch.subject | Should -Not -Match 'vars\.eci_authorization_outcome'
    }

    It 're-enters Readiness only inside the exact ROUTE_TO_ECI branch' {
        $eciBranch = @($script:pipelineDocument.steps | Where-Object id -eq 'branch-readiness-eci')
        $eciBranch.Count | Should -Be 1
        $thenIds = @($eciBranch[0].then | ForEach-Object id)

        $eciBranch[0].condition |
            Should -Be "vars.steps.stage-readiness-routing-validation.json.READINESS_PRIMARY_STATUS == 'ROUTE_TO_ECI'"
        $eciBranch[0].condition | Should -Not -Match 'ECI_REQUIRED'
        [array]::IndexOf($thenIds, 'stage-readiness-reentry') |
            Should -BeGreaterThan ([array]::IndexOf($thenIds, 'branch-eci-authorization'))
        [array]::IndexOf($thenIds, 'stage-readiness-reentry-validation') |
            Should -BeGreaterThan ([array]::IndexOf($thenIds, 'stage-readiness-reentry'))

        $reentry = @($eciBranch[0].then | Where-Object id -eq 'stage-readiness-reentry')[0]
        $reentry.agent_command | Should -Be '/speckit.readiness'
        $reentry.expected_artifact | Should -Be 'specs/{{ inputs.feature }}/readiness/readiness-assessment.md'
        $reentry.Contains('extract') | Should -BeFalse

        $reentryValidation = @($eciBranch[0].then | Where-Object id -eq 'stage-readiness-reentry-validation')[0]
        @($reentryValidation.args) | Should -Contain '-RequireEciDossier'
        $reentryValidation.revalidate_on_resume | Should -BeTrue
    }

    It 'runs a fresh top-level validation immediately before final Readiness routing' {
        $ids = @($script:pipelineDocument.steps | ForEach-Object id)
        $validationIndex = [array]::IndexOf($ids, 'stage-latest-readiness-routing-validation')
        $switchIndex = [array]::IndexOf($ids, 'branch-readiness-status')

        $validationIndex | Should -BeGreaterThan ([array]::IndexOf($ids, 'branch-readiness-eci'))
        $validationIndex | Should -Be ($switchIndex - 1)

        $validation = $script:pipelineDocument.steps[$validationIndex]
        $validation.script | Should -Be 'studio/scripts/powershell/validate-feature-structure.ps1'
        $validation.capture.json | Should -BeTrue
        $validation.revalidate_on_resume | Should -BeTrue

        $latestSwitch = $script:pipelineDocument.steps[$switchIndex]
        $latestSwitch.subject | Should -Be "{{ vars.steps.stage-latest-readiness-routing-validation.json.READINESS_PRIMARY_STATUS | default('NOT_READY') }}"
        $latestSwitch.subject | Should -Not -Match 'vars\.readiness_primary_status'
    }

    It 'routes latest Readiness status <Status> to <ExpectedStep>' -ForEach @(
        @{ Status = 'READY_FOR_PLAN'; ExpectedStep = 'ready-confirm' }
        @{ Status = 'ROUTE_TO_ECI'; ExpectedStep = 'route-eci-repeat-halt' }
        @{ Status = 'ROUTE_TO_REPO_CONTEXT'; ExpectedStep = 'route-repo-context-halt' }
        @{ Status = 'ROUTE_TO_DECISION'; ExpectedStep = 'route-decision-halt' }
        @{ Status = 'ROUTE_TO_VALIDATION'; ExpectedStep = 'route-validation-halt' }
        @{ Status = 'ROUTE_TO_ACCESS'; ExpectedStep = 'route-access-halt' }
        @{ Status = 'EXPLORATORY_ONLY'; ExpectedStep = 'exploratory-halt' }
        @{ Status = 'NOT_READY'; ExpectedStep = 'not-ready-halt' }
    ) {
        $latestSwitch = @($script:pipelineDocument.steps | Where-Object id -eq 'branch-readiness-status')[0]
        @($latestSwitch.cases[$Status])[0].id | Should -Be $ExpectedStep
    }

    It 'routes ECI outcome <Outcome> through <ExpectedValidator>' -ForEach @(
        @{ Outcome = 'READY_FOR_MAINLINE_IMPLEMENTATION'; ExpectedValidator = 'validate-eci-mainline-reentry' }
        @{ Outcome = 'READY_FOR_SANDBOX_ONLY'; ExpectedValidator = 'validate-eci-sandbox-reentry' }
        @{ Outcome = 'READY_FOR_SPIKE_ONLY'; ExpectedValidator = 'validate-eci-spike-reentry' }
        @{ Outcome = 'NOT_READY'; ExpectedValidator = 'deny-eci-not-ready-reentry' }
    ) {
        $eciBranch = @($script:pipelineDocument.steps | Where-Object id -eq 'branch-readiness-eci')[0]
        $outcomeSwitch = @($eciBranch.then | Where-Object id -eq 'branch-eci-authorization')[0]
        $validator = @($outcomeSwitch.cases[$Outcome])[0]

        $validator.id | Should -Be $ExpectedValidator
        $validator.script | Should -Be 'studio/scripts/powershell/validate-feature-structure.ps1'
        @($validator.args) | Should -Contain '-RequireEciReentry'
        $validator.revalidate_on_resume | Should -BeTrue
    }

    It 'does not route any if or switch from agent-extracted persisted status variables' {
        $decisionExpressions = [System.Collections.Generic.List[string]]::new()
        function script:Collect-DecisionExpressions {
            param($Steps)
            foreach ($step in @($Steps)) {
                if ($step.type -eq 'if') {
                    $decisionExpressions.Add([string]$step.condition)
                    Collect-DecisionExpressions -Steps $step.then
                    if ($step.else) { Collect-DecisionExpressions -Steps $step.else }
                }
                if ($step.type -eq 'switch') {
                    $decisionExpressions.Add([string]$step.subject)
                    foreach ($key in $step.cases.Keys) {
                        Collect-DecisionExpressions -Steps $step.cases[$key]
                    }
                    if ($step.default) { Collect-DecisionExpressions -Steps $step.default }
                }
                if ($step.type -eq 'gate' -and $step.on_reject) {
                    Collect-DecisionExpressions -Steps $step.on_reject
                }
            }
        }

        Collect-DecisionExpressions -Steps $script:pipelineDocument.steps
        ($decisionExpressions -join "`n") | Should -Not -Match 'vars\.(readiness_primary_status|eci_authorization_outcome)'
    }

    It 'marks only the exact read-only validator shape for resume revalidation' {
        $revalidators = [System.Collections.Generic.List[object]]::new()
        function script:Collect-Revalidators {
            param($Steps)
            foreach ($step in @($Steps)) {
                if ($step.Contains('revalidate_on_resume')) { $revalidators.Add($step) }
                foreach ($branch in 'then', 'else', 'on_reject', 'default') {
                    if ($step.Contains($branch) -and $step[$branch]) {
                        Collect-Revalidators -Steps $step[$branch]
                    }
                }
                if ($step.Contains('cases') -and $step.cases) {
                    foreach ($key in $step.cases.Keys) {
                        Collect-Revalidators -Steps $step.cases[$key]
                    }
                }
            }
        }

        Collect-Revalidators -Steps $script:pipelineDocument.steps
        $revalidators.Count | Should -BeGreaterThan 2
        foreach ($step in $revalidators) {
            $step.revalidate_on_resume | Should -BeTrue
            $step.dispatch | Should -Be 'script'
            $step.script | Should -Be 'studio/scripts/powershell/validate-feature-structure.ps1'
            $step.capture.json | Should -BeTrue
            @($step.args | Where-Object { $_ -eq '-Json' }).Count | Should -Be 1
        }
    }

    It 'places the Plan entry gate only after validated latest-status routing' {
        $ids = @($script:pipelineDocument.steps | ForEach-Object id)
        [array]::IndexOf($ids, 'stage-plan-prep') |
            Should -BeGreaterThan ([array]::IndexOf($ids, 'branch-readiness-status'))
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

    It 'makes setup-eci the non-bypassable first action on canonical and Claude ECI agents' {
        foreach ($path in @(
            (Join-Path $WorkspaceRoot '.github/agents/speckit.eci.agent.md'),
            (Join-Path $WorkspaceRoot '.claude/agents/speckit-eci.md')
        )) {
            $content = Get-Content -LiteralPath $path -Raw
            $content | Should -Match 'Non-bypassable first action'
            $content | Should -Match 'setup-eci\.ps1 -Json'
            $content | Should -Match 'ECI_REQUIREMENT_LATCHED'
            $content | Should -Match 'There is no operator-confirmation or force bypass'
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

Describe 'Analyze uses the machine-readable authorization artifact' {
    It 'requires analysis-result.json and treats the Markdown checklist as informational only' {
        $content = Get-Content -LiteralPath $script:workflowPath -Raw
        $match = [regex]::Match($content, '(?ms)^\s*- id: stage-analyze\s+.*?(?=^\s*# 8\. Implement)')
        $match.Success | Should -BeTrue
        $match.Value | Should -Match 'expected_artifact:\s*"specs/\{\{ inputs\.feature \}\}/analysis-result\.json"'
        $match.Value | Should -Match 'exact schema-valid machine-result JSON'
        $match.Value | Should -Match 'analysis-checklist\.md is informational only'
        $match.Value | Should -Not -Match 'expected_artifact:.*analysis-checklist\.md'
    }
}
