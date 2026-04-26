#!/usr/bin/env pwsh
#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/governance.config.ps1"
    # check-speckit-runtime.ps1 dot-sources common.ps1 internally,
    # but we import functions directly to avoid running main logic.
    . (Get-ScriptFunctionsBlock -ScriptPath (Join-Path $WorkspaceRoot 'studio/scripts/powershell/check-speckit-runtime.ps1'))
}

# ============================================================
# Tier 2: Content contract validation
# ============================================================

Describe 'Test-ContentContract' {
    It 'returns empty when all mustContainAll strings are present' {
        $content = 'This file contains required-text-A and also required-text-B.'
        $result = Test-ContentContract -Content $content -MustContainAll @('required-text-A', 'required-text-B')
        $result.Count | Should -Be 0
    }

    It 'returns missing text when a required string is absent' {
        $content = 'This file contains required-text-A only.'
        $result = @(Test-ContentContract -Content $content -MustContainAll @('required-text-A', 'required-text-B'))
        $result.Count | Should -Be 1
        $result[0] | Should -BeLike '*required-text-B*'
    }

    It 'performs case-sensitive literal matching' {
        $content = 'Required-Text-A'
        $result = Test-ContentContract -Content $content -MustContainAll @('required-text-a')
        $result.Count | Should -Be 1
    }

    It 'returns empty when all mustMatchAll patterns match' {
        $content = 'Version: 1.2.3'
        $result = Test-ContentContract -Content $content -MustMatchAll @('Version:\s*\d+\.\d+')
        $result.Count | Should -Be 0
    }

    It 'returns missing pattern when a regex does not match' {
        $content = 'No version here'
        $result = @(Test-ContentContract -Content $content -MustMatchAll @('Version:\s*\d+\.\d+'))
        $result.Count | Should -Be 1
        $result[0] | Should -BeLike '*missing pattern*'
    }

    It 'handles empty/null mustContainAll gracefully' {
        $result = Test-ContentContract -Content 'anything' -MustContainAll @() -MustMatchAll @()
        $result.Count | Should -Be 0
    }

    It 'ignores null/whitespace entries in mustContainAll' {
        $result = Test-ContentContract -Content 'anything' -MustContainAll @($null, '', '  ')
        $result.Count | Should -Be 0
    }
}
