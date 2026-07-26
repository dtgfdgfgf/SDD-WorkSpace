#!/usr/bin/env pwsh
#Requires -Module Pester

# Unit tests for RunState I/O: atomic write, resume, advisory lock,
# Get-RunStatePath path-boundary.

BeforeAll {
    . "$PSScriptRoot/governance.config.ps1"
    . (Get-ScriptFunctionsBlock -ScriptPath (Join-Path $WorkspaceRoot 'studio/scripts/powershell/common.ps1'))
    . (Get-ScriptFunctionsBlock -ScriptPath (Join-Path $WorkspaceRoot 'studio/scripts/powershell/workflow-engine.ps1'))

    function script:New-FixtureProjectRoot {
        $root = Join-Path $TestDrive ("project-{0}" -f ([System.Guid]::NewGuid().ToString('N')))
        New-Item -ItemType Directory -Path (Join-Path $root 'specs/001-foo') -Force | Out-Null
        return $root
    }
}

Describe 'Get-RunStatePath' {
    It 'creates the run directory outside specs/ so no canonical feature ID is allocated' {
        $root = New-FixtureProjectRoot
        $path = Get-RunStatePath -ProjectRoot $root -Feature '002-new'
        $path | Should -Be (Join-Path $root '.workflow/runs/002-new/state.json')
        Test-Path -LiteralPath (Split-Path -Parent $path) | Should -BeTrue
        (Join-Path $root 'specs/002-new') | Should -Not -Exist
    }

    It 'rejects feature names that escape the project root' {
        $root = New-FixtureProjectRoot
        { Get-RunStatePath -ProjectRoot $root -Feature '..' } | Should -Throw
        { Get-RunStatePath -ProjectRoot $root -Feature '../../escape' } | Should -Throw
    }
}

Describe 'Save-RunState / Read-RunState round-trip' {
    It 'writes atomically and reads back identical fields' {
        $root = New-FixtureProjectRoot
        $path = Get-RunStatePath -ProjectRoot $root -Feature '001-foo'
        $rs = [ordered]@{
            schema_version = '1.1.0'
            run_id = 'abc'
            workflow_id = 'sdd-pipeline'
            workflow_version = '1.0.0'
            workflow_sha256 = ('a' * 64)
            feature = '001-foo'
            status = 'running'
            started_at = Get-IsoTimestamp
            updated_at = Get-IsoTimestamp
            current_step_id = 'stage-x'
            inputs = @{ feature = '001-foo' }
            vars = @{ steps = @{ stage = @{ json = @{ ok = $true } } } }
            history = @()
            gates = @{}
        }
        Save-RunState -RunState $rs -Path $path
        $loaded = Read-RunState -Path $path
        $loaded.workflow_id | Should -Be 'sdd-pipeline'
        $loaded.workflow_sha256 | Should -BeExactly ('a' * 64)
        $loaded.current_step_id | Should -Be 'stage-x'
        $loaded.inputs.feature | Should -Be '001-foo'
    }

    It 'returns null when state.json does not exist' {
        $root = New-FixtureProjectRoot
        $missing = Join-Path $root '.workflow/runs/001-foo/state.json'
        Read-RunState -Path $missing | Should -BeNullOrEmpty
    }
}

Describe 'Lock-RunState advisory lock' {
    It 'rejects a second lock within 60 seconds' {
        $root = New-FixtureProjectRoot
        $path = Get-RunStatePath -ProjectRoot $root -Feature '001-foo'
        $lock = Lock-RunState -Path $path
        try {
            { Lock-RunState -Path $path } | Should -Throw 'Concurrent run-workflow*'
        } finally {
            Unlock-RunState -LockPath $lock
        }
    }

    It 'accepts a re-lock after the first lock is released' {
        $root = New-FixtureProjectRoot
        $path = Get-RunStatePath -ProjectRoot $root -Feature '001-foo'
        $first = Lock-RunState -Path $path
        Unlock-RunState -LockPath $first
        $second = Lock-RunState -Path $path
        Unlock-RunState -LockPath $second
        Test-Path -LiteralPath $second | Should -BeFalse
    }
}
