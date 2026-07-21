#!/usr/bin/env pwsh
#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/governance.config.ps1"
    $script:generatorPath = Join-Path $WorkspaceRoot 'studio/scripts/powershell/generate-impact-registry.ps1'
    . (Get-ScriptFunctionsBlock -ScriptPath $script:generatorPath)
}

# ============================================================
# Tier 1: Regression test for H6
# ============================================================

Describe 'Read-DriftGovernanceBlock' {
    # Regression: H6 — array += created new array, breaking reference in $result

    It 'parses HTML comment drift-governance block from .md file' {
        $fixturePath = Get-FixturePath 'sample-drift-block.md'
        $result = Read-DriftGovernanceBlock -FilePath $fixturePath
        $result | Should -Not -BeNullOrEmpty
        $result['authority'] | Should -Be 'dependent'
        $result['domain'] | Should -Be 'agent_runtime'
    }

    It 'parses PS block comment drift-governance from .ps1 file' {
        $fixturePath = Get-FixturePath 'sample-drift-block.ps1'
        $result = Read-DriftGovernanceBlock -FilePath $fixturePath
        $result | Should -Not -BeNullOrEmpty
        $result['authority'] | Should -Be 'source_of_truth'
        $result['domain'] | Should -Be 'scripts'
    }

    It 'correctly populates list items (H6 regression)' {
        $fixturePath = Get-FixturePath 'sample-drift-block.md'
        $result = Read-DriftGovernanceBlock -FilePath $fixturePath

        $result['impact_on_change'] | Should -Not -BeNullOrEmpty
        $result['impact_on_change'].Count | Should -Be 2
        $result['impact_on_change'][0]['target'] | Should -Be '.claude/agents/*.md'
        $result['impact_on_change'][0]['level'] | Should -Be 'must_update'
        $result['impact_on_change'][1]['target'] | Should -Be 'README.md'
        $result['impact_on_change'][1]['level'] | Should -Be 'reference'
    }

    It 'handles multiple list keys without losing earlier lists (H6 regression)' {
        $fixturePath = Get-FixturePath 'sample-drift-block.md'
        $result = Read-DriftGovernanceBlock -FilePath $fixturePath

        # Both list keys should be populated
        $result['impact_on_change'] | Should -Not -BeNullOrEmpty
        $result['secondary_list'] | Should -Not -BeNullOrEmpty
        $result['secondary_list'].Count | Should -Be 1
        $result['secondary_list'][0]['target'] | Should -Be 'docs/overview.md'
    }

    It 'returns null for file without drift-governance block' {
        $tempFile = Join-Path $TestDrive 'no-block.md'
        '# Just a normal file' | Set-Content $tempFile
        $result = Read-DriftGovernanceBlock -FilePath $tempFile
        $result | Should -BeNullOrEmpty
    }
}

Describe 'ConvertTo-RegistryJson text hygiene' {
    It 'normalizes host newlines to LF' {
        $json = ConvertTo-RegistryJson -Registry ([ordered]@{
            alpha = 1
            beta = [ordered]@{ value = 2 }
        })

        $json | Should -Match "`n"
        $json | Should -Not -Match "`r"
    }
}

Describe 'Build-Registry scoped authority partitions' {
    BeforeAll {
        $raw = @(& pwsh -NoLogo -NoProfile -File $script:generatorPath 2>&1) -join "`n"
        $LASTEXITCODE | Should -Be 0 -Because $raw
        $script:builtRegistry = $raw | ConvertFrom-Json -AsHashtable
    }

    It 'declares the exact canonical agent inputs and dependent surfaces' {
        $agentEntries = @(
            $script:builtRegistry.documentAuthority |
                Where-Object { $_.path -in @(
                    '.github/agents/*.agent.md',
                    '.github/agents/async-python-reviewer.md',
                    '.github/agents/copilot-instructions.md',
                    '.claude/agents/*.md'
                ) }
        )

        $agentEntries.Count | Should -Be 4
        ($agentEntries | Where-Object path -EQ '.github/agents/*.agent.md').authority |
            Should -BeExactly 'source_of_truth'
        ($agentEntries | Where-Object path -EQ '.github/agents/async-python-reviewer.md').authority |
            Should -BeExactly 'source_of_truth'
        ($agentEntries | Where-Object path -EQ '.github/agents/copilot-instructions.md').authority |
            Should -BeExactly 'dependent'
        ($agentEntries | Where-Object path -EQ '.claude/agents/*.md').authority |
            Should -BeExactly 'dependent'

        ($agentEntries | Where-Object path -EQ '.github/agents/*.agent.md').description |
            Should -Match '^Fourteen canonical shared agent inputs'
        ($agentEntries | Where-Object path -EQ '.claude/agents/*.md').description |
            Should -Match '^Fifteen deterministic Claude-consumable mirrors'
    }

    It 'routes only the fifteen canonical agent inputs into mirror regeneration' {
        $route = $script:builtRegistry.impactRouting |
            Where-Object changeType -EQ 'agent_change'

        @($route).Count | Should -Be 1
        $route.trigger | Should -BeExactly '.github/agents/*.agent.md|.github/agents/async-python-reviewer.md'
        $route.trigger | Should -Not -Match 'copilot-instructions'
        @($route.rules | Where-Object { $_.target -eq '.claude/agents/*.md' -and $_.impact -eq 'must_update' }).Count |
            Should -Be 1
    }

    It 'keeps the ledger informational except for one machine-bounded finding-status scope' {
        $entry = $script:builtRegistry.documentAuthority |
            Where-Object path -EQ 'docs/sdd-workspace-repair-inventory-and-update-plan-2026-07-12_zhTW.md'

        @($entry).Count | Should -Be 1
        $entry.authority | Should -BeExactly 'informational'
        @($entry.authorityScopes).Count | Should -Be 1
        $entry.authorityScopes[0].name | Should -BeExactly 'finding_status'
        $entry.authorityScopes[0].selector | Should -BeExactly 'finding-status-record-v1'
        $entry.authorityScopes[0].authority | Should -BeExactly 'source_of_truth'
        $entry.authorityScopes[0].schemaPath | Should -BeExactly 'studio/runtime/finding-status-record.schema.json'
        $entry.authorityScopes[0].validatorPath | Should -BeExactly 'studio/scripts/powershell/validate-finding-status-ledger.ps1'
    }

    It 'routes ledger changes to the dependent index and contract review' {
        $route = $script:builtRegistry.impactRouting |
            Where-Object changeType -EQ 'finding_status_ledger_change'

        @($route).Count | Should -Be 1
        $route.trigger | Should -BeExactly 'docs/sdd-workspace-repair-inventory-and-update-plan-2026-07-12_zhTW.md'
        @($route.rules | Where-Object { $_.target -eq 'docs/README.md' -and $_.impact -eq 'must_update' }).Count |
            Should -Be 1
        @($route.rules | Where-Object { $_.target -eq 'studio/runtime/shared-runtime-contract.json' -and $_.impact -eq 'must_review' }).Count |
            Should -Be 1
    }
}
