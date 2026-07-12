#!/usr/bin/env pwsh
#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/governance.config.ps1"
    . (Join-Path $WorkspaceRoot 'studio/scripts/powershell/common.ps1')
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

Describe 'UTF-8 no-BOM LF writers' {
    It 'writes JSON with LF, no BOM, and a final newline' {
        $jsonPath = Join-Path $TestDrive 'lf-output.json'
        Write-JsonFile -Path $jsonPath -Data ([ordered]@{
            name = 'fixture'
            values = @(1, 2)
        })

        $bytes = [System.IO.File]::ReadAllBytes($jsonPath)
        ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) | Should -BeFalse
        ([Array]::IndexOf($bytes, [byte]0x0D) -ge 0) | Should -BeFalse
        $bytes[-1] | Should -Be 0x0A
        (Read-JsonFile -Path $jsonPath).name | Should -Be 'fixture'
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

Describe 'Initialize-ProjectGitRepository' {
    It 'initializes an independent project repo and configures hooksPath to workspace hooks' {
        $workspace = Join-Path $TestDrive 'workspace'
        $project = Join-Path $workspace 'projects/example'
        New-Item -ItemType Directory -Path (Join-Path $workspace '.githooks') -Force | Out-Null
        New-Item -ItemType Directory -Path $project -Force | Out-Null

        $result = Initialize-ProjectGitRepository -ProjectRoot $project -WorkspaceRoot $workspace

        $result.initialized | Should -BeTrue
        (Test-Path -LiteralPath (Join-Path $project '.git')) | Should -BeTrue
        $hooksPath = git -C $project config core.hooksPath
        $hooksPath | Should -Be '../../.githooks'
    }
}

# ============================================================
# H5 regression: .gitkeep cleanup count safety
# init-project.ps1 / init-practice.ps1 wrap Get-ChildItem in @() so that a
# single result still returns Count = 1 instead of $null.
# ============================================================

Describe '.gitkeep cleanup Count safety (H5 regression)' {
    It 'returns Count = 1 for single sibling when wrapped in @()' {
        $dir = Join-Path $TestDrive 'h5-single'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $dir '.gitkeep') -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $dir 'README.md') -Force | Out-Null

        $count = @(Get-ChildItem -Path $dir -Exclude '.gitkeep').Count
        $count | Should -Be 1
    }

    It 'returns Count = 0 when only .gitkeep exists' {
        $dir = Join-Path $TestDrive 'h5-empty'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $dir '.gitkeep') -Force | Out-Null

        $count = @(Get-ChildItem -Path $dir -Exclude '.gitkeep').Count
        $count | Should -Be 0
    }

    It 'returns Count = N for N siblings' {
        $dir = Join-Path $TestDrive 'h5-many'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $dir '.gitkeep') -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $dir 'a.md') -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $dir 'b.md') -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $dir 'c.md') -Force | Out-Null

        $count = @(Get-ChildItem -Path $dir -Exclude '.gitkeep').Count
        $count | Should -Be 3
    }
}
