#!/usr/bin/env pwsh
#Requires -Module Pester

# Unit tests for the minimal sandboxed expression evaluator
# (Resolve-DottedReference / Resolve-Interpolation / Test-WorkflowCondition).

BeforeAll {
    . "$PSScriptRoot/governance.config.ps1"
    . (Get-ScriptFunctionsBlock -ScriptPath (Join-Path $WorkspaceRoot 'studio/scripts/powershell/common.ps1'))
    . (Get-ScriptFunctionsBlock -ScriptPath (Join-Path $WorkspaceRoot 'studio/scripts/powershell/workflow-engine.ps1'))

    $script:context = @{
        inputs = @{ feature = '001-foo'; scope = 'full'; bare = '' }
        vars = @{
            steps = @{
                readiness = @{ json = @{ PRIMARY_STATUS = 'READY_FOR_PLAN'; nested = @{ ok = $true } } }
            }
            empty = $null
        }
    }
}

Describe 'Resolve-DottedReference' {
    It 'resolves single-level lookups' {
        Resolve-DottedReference -Context $script:context -Reference 'inputs.feature' | Should -Be '001-foo'
    }
    It 'resolves multi-level lookups' {
        Resolve-DottedReference -Context $script:context -Reference 'vars.steps.readiness.json.PRIMARY_STATUS' | Should -Be 'READY_FOR_PLAN'
    }
    It 'returns null for missing path' {
        Resolve-DottedReference -Context $script:context -Reference 'inputs.missing' | Should -BeNullOrEmpty
    }
}

Describe 'Resolve-Interpolation' {
    It 'replaces a single {{ ref }}' {
        Resolve-Interpolation -Template 'specs/{{ inputs.feature }}/spec.md' -Context $script:context | Should -Be 'specs/001-foo/spec.md'
    }
    It 'replaces multiple references' {
        Resolve-Interpolation -Template '{{ inputs.feature }}-{{ inputs.scope }}' -Context $script:context | Should -Be '001-foo-full'
    }
    It 'replaces with default filter when value is missing' {
        Resolve-Interpolation -Template "{{ inputs.missing | default('NOT_READY') }}" -Context $script:context | Should -Be 'NOT_READY'
    }
    It 'replaces with default filter when value is empty string' {
        Resolve-Interpolation -Template "{{ inputs.bare | default('FALLBACK') }}" -Context $script:context | Should -Be 'FALLBACK'
    }
    It 'returns the value when present (default not used)' {
        Resolve-Interpolation -Template "{{ inputs.feature | default('FALLBACK') }}" -Context $script:context | Should -Be '001-foo'
    }
}

Describe 'Test-WorkflowCondition' {
    It 'evaluates equality with dotted ref vs string literal' {
        Test-WorkflowCondition -Expression "inputs.feature == '001-foo'" -Context $script:context | Should -BeTrue
        Test-WorkflowCondition -Expression "inputs.feature == 'other'" -Context $script:context | Should -BeFalse
    }
    It 'evaluates inequality' {
        Test-WorkflowCondition -Expression "inputs.feature != 'other'" -Context $script:context | Should -BeTrue
    }
    It 'short-circuits boolean and / or' {
        Test-WorkflowCondition -Expression "inputs.feature == '001-foo' and inputs.scope == 'full'" -Context $script:context | Should -BeTrue
        Test-WorkflowCondition -Expression "inputs.feature == 'other' or inputs.scope == 'full'" -Context $script:context | Should -BeTrue
        Test-WorkflowCondition -Expression "inputs.feature == 'other' and inputs.scope == 'full'" -Context $script:context | Should -BeFalse
    }
    It 'supports parentheses' {
        Test-WorkflowCondition -Expression "(inputs.feature == 'x' or inputs.scope == 'full') and not (inputs.scope == 'lite')" -Context $script:context | Should -BeTrue
    }
    It 'rejects function-call style tokens (sandboxed)' {
        { Test-WorkflowCondition -Expression "exec('rm -rf /')" -Context $script:context } | Should -Throw
    }
    It 'rejects unexpected operators' {
        { Test-WorkflowCondition -Expression "inputs.feature + 'x'" -Context $script:context } | Should -Throw
    }
}
