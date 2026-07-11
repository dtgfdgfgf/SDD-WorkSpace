#!/usr/bin/env pwsh
#Requires -Module Pester

# Regression tests for the Wave-3 path-boundary hardening
# (mirrors upstream github/spec-kit v0.3.0 #1809 + v0.7.5 #2229/#2296).
# Uses the existing common.ps1 helpers Test-PathInsideRoot / Assert-PathInsideRoot.

BeforeAll {
    . "$PSScriptRoot/governance.config.ps1"

    $script:scripts = @{
        SetupReadiness = Join-Path $WorkspaceRoot 'studio/scripts/powershell/setup-readiness.ps1'
        SetupTasks     = Join-Path $WorkspaceRoot 'studio/scripts/powershell/setup-tasks.ps1'
        SetupAnalyze   = Join-Path $WorkspaceRoot 'studio/scripts/powershell/setup-analyze.ps1'
        SetupImplement = Join-Path $WorkspaceRoot 'studio/scripts/powershell/setup-implement.ps1'
        SetupPlan      = Join-Path $WorkspaceRoot 'studio/scripts/powershell/setup-plan.ps1'
        SyncBootstrap  = Join-Path $WorkspaceRoot 'studio/scripts/powershell/sync-agent-bootstrap.ps1'
        UpdateAgentCtx = Join-Path $WorkspaceRoot 'studio/scripts/powershell/update-agent-context.ps1'
        CreateFeature  = Join-Path $WorkspaceRoot 'studio/scripts/powershell/create-new-feature.ps1'
    }
}

Describe '-FeatureDir parameter rejects paths outside the workspace' {
    BeforeEach {
        $script:outside = Join-Path $TestDrive 'outside-of-workspace'
        New-Item -ItemType Directory -Path $script:outside -Force | Out-Null
    }

    It 'setup-readiness.ps1 rejects -FeatureDir outside workspace' {
        $output = pwsh -NoProfile -File $script:scripts.SetupReadiness -FeatureDir $script:outside -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match 'escapes project root'
    }

    It 'setup-tasks.ps1 rejects -FeatureDir outside workspace' {
        $output = pwsh -NoProfile -File $script:scripts.SetupTasks -FeatureDir $script:outside -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match 'escapes project root'
    }

    It 'setup-analyze.ps1 rejects -FeatureDir outside workspace' {
        $output = pwsh -NoProfile -File $script:scripts.SetupAnalyze -FeatureDir $script:outside -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match 'escapes project root'
    }

    It 'setup-implement.ps1 rejects -FeatureDir outside workspace' {
        $output = pwsh -NoProfile -File $script:scripts.SetupImplement -FeatureDir $script:outside -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match 'escapes project root'
    }
}

Describe 'SPECIFY_FEATURE env var cannot escape REPO_ROOT' {
    BeforeEach {
        $script:oldFeature = $env:SPECIFY_FEATURE
    }

    AfterEach {
        $env:SPECIFY_FEATURE = $script:oldFeature
    }

    It 'setup-plan.ps1 rejects SPECIFY_FEATURE that escapes specs/' {
        $env:SPECIFY_FEATURE = '../../etc'
        $output = pwsh -NoProfile -File $script:scripts.SetupPlan -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match 'escapes REPO_ROOT'
    }

    It 'update-agent-context.ps1 rejects SPECIFY_FEATURE that escapes REPO_ROOT' {
        $env:SPECIFY_FEATURE = '../../etc'
        $output = pwsh -NoProfile -File $script:scripts.UpdateAgentCtx 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match 'escapes REPO_ROOT'
    }
}

Describe 'sync-agent-bootstrap.ps1 paranoid adapter-path boundary' {
    # The script accepts any -ProjectRoot by design (consumer projects live anywhere).
    # The path-boundary defense locks adapter target files to inside $context.ProjectRoot
    # so future tainted-input changes cannot redirect writes outside the resolved project.
    It 'paranoid Assert-PathInsideRoot guards every adapter target file' {
        $content = Get-Content -LiteralPath $script:scripts.SyncBootstrap -Raw
        $content | Should -Match 'Assert-PathInsideRoot[^\n]*\$context\.ProjectRoot'
        $content | Should -Match 'adapter path escapes project root'
    }

    It 'accepts the workspace root itself as -ProjectRoot' {
        $output = pwsh -NoProfile -File $script:scripts.SyncBootstrap -ProjectRoot $WorkspaceRoot -Json 2>&1
        $LASTEXITCODE | Should -Be 0
    }
}

Describe 'extension lifecycle scripts reject malicious ids before any mutation' {
    BeforeAll {
        $script:addExt = Join-Path $WorkspaceRoot 'studio/scripts/powershell/add-extension.ps1'
        $script:removeExt = Join-Path $WorkspaceRoot 'studio/scripts/powershell/remove-extension.ps1'
        # Source fixture must live inside the workspace (SourceDir boundary), so use the
        # gitignored test artifacts directory.
        $script:evilSrc = Join-Path $WorkspaceRoot 'studio/tests/_artifacts/evil-ext-fixture'
    }

    AfterEach {
        if (Test-Path -LiteralPath $script:evilSrc) {
            Remove-Item -LiteralPath $script:evilSrc -Recurse -Force
        }
    }

    It 'add-extension.ps1 rejects a manifest id containing path traversal' {
        New-Item -ItemType Directory -Path $script:evilSrc -Force | Out-Null
        $manifest = @{
            id = '../../pwn-target'; version = '1.0.0'; title = 'Evil'; description = 'x'
            kind = 'commands'; status = 'draft'; compatibility = 'studio-first'
        } | ConvertTo-Json
        Set-Content -LiteralPath (Join-Path $script:evilSrc 'manifest.json') -Value $manifest
        $output = pwsh -NoProfile -File $script:addExt -SourceDir $script:evilSrc -Force -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match 'Invalid extension id'
    }

    It 'remove-extension.ps1 rejects an id containing path traversal' {
        $output = pwsh -NoProfile -File $script:removeExt -Id '../../studio' -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match 'Invalid extension id'
    }

    It 'remove-extension.ps1 still reaches normal not-found handling for well-formed ids' {
        $output = pwsh -NoProfile -File $script:removeExt -Id 'no-such-extension' -Json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match 'Extension not found'
    }
}

Describe 'create-new-feature.ps1 contains Assert-PathInsideRoot at construction sites' {
    # ConvertTo-CleanBranchName already strips traversal characters, so the runtime
    # boundary checks are defense-in-depth. We assert the helper calls are present.
    It 'Assert-PathInsideRoot guards the specs/, feature/, and spec.md sites' {
        $content = Get-Content -LiteralPath $script:scripts.CreateFeature -Raw
        $content | Should -Match 'Assert-PathInsideRoot[^\n]*\$specsDir'
        $content | Should -Match 'Assert-PathInsideRoot[^\n]*\$featureDir'
        $content | Should -Match 'Assert-PathInsideRoot[^\n]*\$specFile'
    }
}
