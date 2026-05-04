#!/usr/bin/env pwsh
#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/governance.config.ps1"
    $script:checkScript = Join-Path $WorkspaceRoot 'studio/scripts/powershell/check-speckit-runtime.ps1'
    . (Get-ScriptFunctionsBlock -ScriptPath $script:checkScript)
}

Describe 'Test-ContentContract anchor handling (L12 pilot)' {
    It 'returns no missing items when all anchors are present' {
        $content = "intro`n<!-- governance-anchor: alpha -->`nbody`n<!-- governance-anchor: beta -->"
        $missing = Test-ContentContract -Content $content -MustContainAnchors @('alpha', 'beta')
        $missing.Count | Should -Be 0
    }

    It 'flags a missing anchor with the anchor id' {
        $content = "intro`n<!-- governance-anchor: alpha -->`nbody"
        $missing = @(Test-ContentContract -Content $content -MustContainAnchors @('alpha', 'beta'))
        $missing.Count | Should -Be 1
        $missing[0] | Should -Be 'missing anchor: beta'
    }

    It 'distinguishes anchor markers from prose mentioning the same id' {
        $content = "intro`nThe alpha section is important.`nbody"
        $missing = @(Test-ContentContract -Content $content -MustContainAnchors @('alpha'))
        $missing.Count | Should -Be 1
        $missing[0] | Should -Be 'missing anchor: alpha'
    }

    It 'tolerates an empty MustContainAnchors list' {
        $missing = Test-ContentContract -Content 'anything' -MustContainAnchors @()
        $missing.Count | Should -Be 0
    }

    It 'is robust to whitespace-only anchor entries' {
        $content = "<!-- governance-anchor: real -->"
        $missing = Test-ContentContract -Content $content -MustContainAnchors @('  ', 'real')
        $missing.Count | Should -Be 0
    }

    It 'composes with mustContainAll without interference' {
        $content = "literal-text`n<!-- governance-anchor: alpha -->"
        $missing = Test-ContentContract -Content $content -MustContainAll @('literal-text') -MustContainAnchors @('alpha')
        $missing.Count | Should -Be 0
    }
}
