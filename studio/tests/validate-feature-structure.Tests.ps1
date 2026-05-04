#!/usr/bin/env pwsh
#Requires -Module Pester

# ============================================================
# Patch 7: validate-feature-structure.ps1 (M5)
# Per-feature SDD §11 structural validator. Output is structured
# advisory; consumer projects can run it as warnings via
# check-speckit-runtime.ps1.
# ============================================================

BeforeAll {
    . "$PSScriptRoot/governance.config.ps1"
    $script:validatorScript = Join-Path $WorkspaceRoot 'studio/scripts/powershell/validate-feature-structure.ps1'

    function script:Write-FeatureFixture {
        param(
            [string]$FeatureDir,
            [string]$SpecBody = "# Specification: Test`n`n**Version:** 1.0.0`n",
            [string]$ReadinessBody = $null,
            [hashtable]$Optional = @{}
        )
        New-Item -ItemType Directory -Path $FeatureDir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $FeatureDir 'spec.md') -Value $SpecBody -NoNewline -Encoding utf8

        if ($ReadinessBody) {
            $rdir = Join-Path $FeatureDir 'readiness'
            New-Item -ItemType Directory -Path $rdir -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $rdir 'readiness-assessment.md') -Value $ReadinessBody -NoNewline -Encoding utf8
        }

        foreach ($k in $Optional.Keys) {
            Set-Content -LiteralPath (Join-Path $FeatureDir $k) -Value $Optional[$k] -NoNewline -Encoding utf8
        }
    }
}

Describe 'validate-feature-structure (M5)' {
    BeforeEach {
        $script:featureDir = Join-Path $TestDrive ("feat-{0}" -f ([System.Guid]::NewGuid().ToString('N')))
    }

    It 'reports VALID for a minimal spec.md only' {
        Write-FeatureFixture -FeatureDir $script:featureDir
        $output = pwsh -NoProfile -File $script:validatorScript -FeatureDir $script:featureDir -Json
        $LASTEXITCODE | Should -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        $result.VALID | Should -BeTrue
        $result.ERROR_COUNT | Should -Be 0
    }

    It 'fails when spec.md is missing' {
        New-Item -ItemType Directory -Path $script:featureDir -Force | Out-Null
        $output = pwsh -NoProfile -File $script:validatorScript -FeatureDir $script:featureDir -Json
        $LASTEXITCODE | Should -Not -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        $result.VALID | Should -BeFalse
        ($result.ERRORS | Where-Object { $_.id -eq 'spec-missing' }) | Should -Not -BeNullOrEmpty
    }

    It 'fails when feature directory does not exist' {
        $missing = Join-Path $TestDrive 'never-created'
        $output = pwsh -NoProfile -File $script:validatorScript -FeatureDir $missing -Json
        $LASTEXITCODE | Should -Not -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        $result.VALID | Should -BeFalse
        ($result.ERRORS | Where-Object { $_.id -eq 'feature-dir-missing' }) | Should -Not -BeNullOrEmpty
    }

    It 'warns when spec.md has no Version field' {
        Write-FeatureFixture -FeatureDir $script:featureDir -SpecBody "# Specification: Test`n"
        $output = pwsh -NoProfile -File $script:validatorScript -FeatureDir $script:featureDir -Json
        $result = ($output -join "`n") | ConvertFrom-Json
        ($result.WARNINGS | Where-Object { $_.id -eq 'spec-version-missing' }) | Should -Not -BeNullOrEmpty
    }

    It 'fails when readiness/ exists but readiness-assessment.md is missing' {
        Write-FeatureFixture -FeatureDir $script:featureDir
        New-Item -ItemType Directory -Path (Join-Path $script:featureDir 'readiness') -Force | Out-Null
        $output = pwsh -NoProfile -File $script:validatorScript -FeatureDir $script:featureDir -Json
        $LASTEXITCODE | Should -Not -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        ($result.ERRORS | Where-Object { $_.id -eq 'readiness-assessment-missing' }) | Should -Not -BeNullOrEmpty
    }

    It 'fails when ROUTE_TO_ECI is set but ECI dossier is missing' {
        Write-FeatureFixture -FeatureDir $script:featureDir -ReadinessBody @"
# Readiness

**Primary Status**: ROUTE_TO_ECI
**Intent Ledger Requirement**: Not Required
"@
        $output = pwsh -NoProfile -File $script:validatorScript -FeatureDir $script:featureDir -Json
        $LASTEXITCODE | Should -Not -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        $eciErrors = @($result.ERRORS | Where-Object { $_.id -like 'eci-missing-*' })
        $eciErrors.Count | Should -BeGreaterOrEqual 4
    }

    It 'fails when readiness mandates intent-ledger but it is missing' {
        Write-FeatureFixture -FeatureDir $script:featureDir -ReadinessBody @"
# Readiness

**Primary Status**: READY_FOR_PLAN
**Intent Ledger Requirement**: Create ``intent-ledger.md``
"@
        $output = pwsh -NoProfile -File $script:validatorScript -FeatureDir $script:featureDir -Json
        $LASTEXITCODE | Should -Not -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        ($result.ERRORS | Where-Object { $_.id -eq 'intent-ledger-missing' }) | Should -Not -BeNullOrEmpty
    }

    It 'warns when intent-ledger.md exists but readiness has not been initiated' {
        Write-FeatureFixture -FeatureDir $script:featureDir -Optional @{ 'intent-ledger.md' = "# Intent Ledger`n`nstub`n" }
        $output = pwsh -NoProfile -File $script:validatorScript -FeatureDir $script:featureDir -Json
        $result = ($output -join "`n") | ConvertFrom-Json
        ($result.WARNINGS | Where-Object { $_.id -eq 'intent-ledger-without-readiness' }) | Should -Not -BeNullOrEmpty
    }

    It 'warns when tasks.md has no canonical "- [ ] T###" lines' {
        $tasksBody = "# Tasks`n`nNo canonical lines yet`n"
        Write-FeatureFixture -FeatureDir $script:featureDir -Optional @{ 'tasks.md' = $tasksBody }
        $output = pwsh -NoProfile -File $script:validatorScript -FeatureDir $script:featureDir -Json
        $result = ($output -join "`n") | ConvertFrom-Json
        ($result.WARNINGS | Where-Object { $_.id -eq 'tasks-no-canonical-line' }) | Should -Not -BeNullOrEmpty
    }

    It 'accepts canonical tasks.md format' {
        $tasksBody = "# Tasks`n`n- [ ] T001 [P1] [Risk: Low] [Story: A] First task`n"
        Write-FeatureFixture -FeatureDir $script:featureDir -Optional @{ 'tasks.md' = $tasksBody }
        $output = pwsh -NoProfile -File $script:validatorScript -FeatureDir $script:featureDir -Json
        $result = ($output -join "`n") | ConvertFrom-Json
        ($result.WARNINGS | Where-Object { $_.id -eq 'tasks-no-canonical-line' }) | Should -BeNullOrEmpty
    }

    It 'promotes warnings to errors with -WarningsAsErrors' {
        Write-FeatureFixture -FeatureDir $script:featureDir -SpecBody "# Specification: Test`n"  # no Version => warning
        $output = pwsh -NoProfile -File $script:validatorScript -FeatureDir $script:featureDir -Json -WarningsAsErrors
        $LASTEXITCODE | Should -Not -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        $result.VALID | Should -BeFalse
        ($result.ERRORS | Where-Object { $_.id -eq 'spec-version-missing' }) | Should -Not -BeNullOrEmpty
    }

    It 'emits human-readable text without -Json' {
        Write-FeatureFixture -FeatureDir $script:featureDir
        $output = pwsh -NoProfile -File $script:validatorScript -FeatureDir $script:featureDir
        $LASTEXITCODE | Should -Be 0
        ($output -join "`n") | Should -Match 'VALID:\s+True'
    }
}

Describe 'new-project-worktree parameter validation (L9-prime)' {
    BeforeAll {
        $script:worktreeScript = Join-Path $WorkspaceRoot 'studio/scripts/powershell/new-project-worktree.ps1'
    }

    It 'rejects branch names containing spaces' {
        $output = pwsh -NoProfile -File $script:worktreeScript -SourceRoot $TestDrive -Path (Join-Path $TestDrive 'wt') -Branch 'has space' 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match 'Invalid git branch name'
    }

    It 'rejects branch names with .. traversal' {
        $output = pwsh -NoProfile -File $script:worktreeScript -SourceRoot $TestDrive -Path (Join-Path $TestDrive 'wt') -Branch 'foo..bar' 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match 'Invalid git branch name'
    }

    It 'rejects branch names ending in .lock' {
        $output = pwsh -NoProfile -File $script:worktreeScript -SourceRoot $TestDrive -Path (Join-Path $TestDrive 'wt') -Branch 'foo.lock' 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match 'Invalid git branch name'
    }

    It 'accepts valid kebab-case branch names at parameter binding' {
        $cmd = Get-Command $script:worktreeScript
        $cmd.Parameters.Branch.Attributes |
            Where-Object { $_ -is [System.Management.Automation.ValidateScriptAttribute] } |
            Should -Not -BeNullOrEmpty
        $cmd.Parameters.Commitish.Attributes |
            Where-Object { $_ -is [System.Management.Automation.ValidateScriptAttribute] } |
            Should -Not -BeNullOrEmpty
    }
}

Describe 'sync-agent-bootstrap -From parameter validation (L9)' {
    BeforeAll {
        $script:bootstrapScript = Join-Path $WorkspaceRoot 'studio/scripts/powershell/sync-agent-bootstrap.ps1'
    }

    It 'has ValidateScript on -From' {
        $cmd = Get-Command $script:bootstrapScript
        $validateScript = $cmd.Parameters.From.Attributes |
            Where-Object { $_ -is [System.Management.Automation.ValidateScriptAttribute] }
        $validateScript | Should -Not -BeNullOrEmpty
    }

    It 'rejects an unknown -From basename at parameter binding' {
        $output = pwsh -NoProfile -File $script:bootstrapScript -ProjectRoot $TestDrive -From 'random.md' 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match 'Invalid -From value'
    }

    It 'accepts canonical adapter names' {
        # We use a non-existent ProjectRoot to ensure the script fails AFTER parameter binding,
        # which proves -From was accepted by ValidateScript.
        $output = pwsh -NoProfile -File $script:bootstrapScript -ProjectRoot (Join-Path $TestDrive 'nope') -From 'AGENTS.md' 2>&1
        ($output -join "`n") | Should -Not -Match 'Invalid -From value'
    }

    It 'accepts an absolute path whose basename matches a canonical adapter' {
        $absPath = Join-Path $TestDrive 'project/CLAUDE.md'
        $output = pwsh -NoProfile -File $script:bootstrapScript -ProjectRoot (Join-Path $TestDrive 'nope') -From $absPath 2>&1
        ($output -join "`n") | Should -Not -Match 'Invalid -From value'
    }
}

Describe 'new-project-worktree hooksPath configuration (M8)' {
    BeforeAll {
        $script:worktreeScript = Join-Path $WorkspaceRoot 'studio/scripts/powershell/new-project-worktree.ps1'
    }

    It 'configures core.hooksPath relative to the new worktree root' {
        # Build a minimal workspace + project repo on TestDrive
        $ws = Join-Path $TestDrive 'ws-m8'
        $studio = Join-Path $ws 'studio'
        $hooks = Join-Path $ws '.githooks'
        $project = Join-Path $ws 'projects/sample'

        New-Item -ItemType Directory -Path (Join-Path $studio 'constitution') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $studio 'constitution/constitution.md') -Value '# stub' -Encoding utf8
        New-Item -ItemType Directory -Path $hooks -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $ws '.github/agents') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $ws '.claude/agents') -Force | Out-Null
        New-Item -ItemType Directory -Path $project -Force | Out-Null

        Push-Location $project
        try {
            git init -b main . | Out-Null
            git config user.email 'test@example.com'
            git config user.name 'Test'
            'seed' | Set-Content -LiteralPath 'seed.txt'
            git add . | Out-Null
            git commit -m 'feat: seed' | Out-Null
        } finally {
            Pop-Location
        }

        $worktree = Join-Path $ws 'projects/sample-wt'
        pwsh -NoProfile -File $script:worktreeScript -SourceRoot $project -Path $worktree -Branch 'feature-x' -Json | Out-Null
        $LASTEXITCODE | Should -Be 0

        Test-Path -LiteralPath $worktree | Should -BeTrue
        $hooksPath = git -C $worktree config core.hooksPath
        $hooksPath | Should -Not -BeNullOrEmpty
        $hooksPath | Should -Match '\.\./\.githooks'
    }
}

Describe 'upgrade-studio-runtime help clarity (L10)' {
    BeforeAll {
        $script:upgradeScript = Join-Path $WorkspaceRoot 'studio/scripts/powershell/upgrade-studio-runtime.ps1'
    }

    It 'help text states default is dry-run' {
        $output = pwsh -NoProfile -File $script:upgradeScript -UpstreamSnapshotDir $TestDrive -Help
        ($output -join "`n") | Should -Match 'Default behavior: dry-run'
    }

    It 'help text marks -DryRun and -Apply as mutually exclusive' {
        $output = pwsh -NoProfile -File $script:upgradeScript -UpstreamSnapshotDir $TestDrive -Help
        ($output -join "`n") | Should -Match 'mutually exclusive'
    }

    It 'mutual-exclusion error message is clear when both flags supplied' {
        $snap = Join-Path $TestDrive 'snap'
        New-Item -ItemType Directory -Path $snap -Force | Out-Null
        $output = pwsh -NoProfile -File $script:upgradeScript -UpstreamSnapshotDir $snap -DryRun -Apply 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match 'mutually exclusive'
    }
}
