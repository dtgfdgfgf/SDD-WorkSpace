#!/usr/bin/env pwsh
#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/governance.config.ps1"
    . (Get-ScriptFunctionsBlock -ScriptPath (Join-Path $WorkspaceRoot 'studio/scripts/powershell/generate-impact-registry.ps1'))
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
