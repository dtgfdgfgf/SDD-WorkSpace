#!/usr/bin/env pwsh
#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/governance.config.ps1"
    . (Get-ScriptFunctionsBlock -ScriptPath (Join-Path $WorkspaceRoot 'studio/scripts/powershell/common.ps1'))
}

# ============================================================
# Tier 2: High-risk path functions
# ============================================================

Describe 'Test-PathInsideRoot' {
    It 'returns true for child path' {
        $root = $TestDrive
        $child = Join-Path $TestDrive 'sub/file.txt'
        Test-PathInsideRoot -Root $root -Candidate $child | Should -BeTrue
    }

    It 'returns false for path outside root' {
        $root = Join-Path $TestDrive 'workspace'
        $outside = Join-Path $TestDrive 'other/file.txt'
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        Test-PathInsideRoot -Root $root -Candidate $outside | Should -BeFalse
    }

    It 'returns false for root itself (root is not a child)' {
        $root = $TestDrive
        Test-PathInsideRoot -Root $root -Candidate $root | Should -BeFalse
    }

    It 'handles mixed separators' {
        $root = $TestDrive
        $child = "$TestDrive\sub\file.txt"
        Test-PathInsideRoot -Root $root -Candidate $child | Should -BeTrue
    }
}

Describe 'Assert-PathInsideRoot' {
    It 'does not throw for valid child path' {
        $root = $TestDrive
        $child = Join-Path $TestDrive 'valid/file.txt'
        { Assert-PathInsideRoot -Root $root -Candidate $child } | Should -Not -Throw
    }

    It 'throws for path outside root' {
        $root = Join-Path $TestDrive 'workspace'
        $outside = Join-Path $TestDrive 'other/file.txt'
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        { Assert-PathInsideRoot -Root $root -Candidate $outside } | Should -Throw
    }
}

Describe 'Read-JsonFile' {
    It 'reads valid JSON file into hashtable' {
        $jsonPath = Join-Path $TestDrive 'test.json'
        '{"key": "value", "num": 42}' | Set-Content $jsonPath
        $result = Read-JsonFile -Path $jsonPath
        $result | Should -Not -BeNullOrEmpty
        $result['key'] | Should -Be 'value'
        $result['num'] | Should -Be 42
    }

    It 'returns null for non-existent file' {
        $result = Read-JsonFile -Path (Join-Path $TestDrive 'missing.json')
        $result | Should -BeNullOrEmpty
    }
}

Describe 'Test-PathInsideRoot edge cases' {
    It 'detects .. traversal escape attempts' {
        $root = Join-Path $TestDrive 'workspace'
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        $escape = Join-Path $root '../etc/passwd'
        Test-PathInsideRoot -Root $root -Candidate $escape | Should -BeFalse
    }
}
