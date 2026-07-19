#Requires -Version 7.0

BeforeAll {
    $script:validator = Join-Path $PSScriptRoot '../scripts/powershell/validate-mainline-notes.ps1'
    $script:workspaceRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
    $script:productionContract = Get-Content -LiteralPath (
        Join-Path $script:workspaceRoot 'studio/runtime/shared-runtime-contract.json'
    ) -Raw | ConvertFrom-Json -AsHashtable

    function Write-TestJson {
        param([string]$Path, [object]$Value)
        $directory = Split-Path -Parent $Path
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
        $json = $Value | ConvertTo-Json -Depth 12
        [System.IO.File]::WriteAllText($Path, (($json -replace "`r`n?", "`n") + "`n"), [System.Text.UTF8Encoding]::new($false))
    }

    function Write-TestNote {
        param(
            [string]$Root,
            [string]$Name = '2099-01-01-test.md',
            [string]$Status = 'Ready',
            [string]$Commits = 'abcdef1',
            [string]$ReconciliationStatus = 'Closed',
            [string[]]$Rows = @()
        )
        $path = Join-Path $Root "docs/mainline-updates/$Name"
        $lines = @(
            '# Mainline Update Note: Test',
            '',
            '**Date**: 2099-01-01',
            '**Source Branch**: `test`',
            '**Target Branch**: `main`',
            "**Status**: $Status",
            "**Related Commits**: $Commits",
            '**Related PR**: N/A'
        )
        if ($ReconciliationStatus) {
            $lines += "**Reconciliation Status**: $ReconciliationStatus"
        }
        $lines += @(
            '',
            '## Scope',
            '',
            '- Fixture shared-layer scope.',
            '',
            '## Impact',
            '',
            '- Fixture governance impact.',
            '',
            '## Impact Reconciliation',
            '',
            '| Target | Impact | Disposition | Evidence |',
            '|--------|--------|-------------|----------|'
        )
        $lines += $Rows
        $lines += @(
            '',
            '## Validation',
            '',
            '- Fixture validation evidence.',
            ''
        )
        [System.IO.File]::WriteAllText($path, (($lines -join "`n") + "`n"), [System.Text.UTF8Encoding]::new($false))
        return $path
    }

    function Write-TestIndex {
        param(
            [string]$Root,
            [string]$Name = '2099-01-01-test.md',
            [string]$Status = 'Ready'
        )
        $topic = [System.IO.Path]::GetFileNameWithoutExtension($Name).Substring(11)
        $content = @(
            '# Mainline Update Notes',
            '',
            '| Date | Topic | Source Branch | Status | Summary |',
            '|------|-------|---------------|--------|---------|',
            "| 2099-01-01 | [$topic](./$Name) | `test` | $Status | Fixture |",
            ''
        ) -join "`n"
        [System.IO.File]::WriteAllText((Join-Path $Root 'docs/mainline-updates/README.md'), $content, [System.Text.UTF8Encoding]::new($false))
    }

    function Initialize-MainlineFixture {
        $root = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path (Join-Path $root 'docs/mainline-updates') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $root 'studio/runtime') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $root '.github/agents') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $root '.claude/agents') -Force | Out-Null

        Write-TestJson -Path (Join-Path $root 'studio/runtime/mainline-note-validation-baseline.json') -Value ([ordered]@{
            schemaVersion = 1
            entries = @()
        })
        Write-TestJson -Path (Join-Path $root 'studio/runtime/shared-runtime-contract.json') -Value ([ordered]@{
            sharedGatePaths = @($script:productionContract.sharedGatePaths)
        })
        Write-TestJson -Path (Join-Path $root 'studio/runtime/impact-registry.json') -Value ([ordered]@{
            impactRouting = @(
                [ordered]@{
                    changeType = 'agent_change'
                    trigger = '.github/agents/*.agent.md'
                    rules = @(
                        [ordered]@{
                            target = '.claude/agents/*.md'
                            impact = 'must_update'
                            reason = 'Mirror source agent changes.'
                        }
                    )
                }
            )
        })
        New-Item -ItemType File -Path (Join-Path $root '.github/agents/example.agent.md') -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $root '.claude/agents/example.md') -Force | Out-Null
        Write-TestNote -Root $root | Out-Null
        Write-TestIndex -Root $root
        return $root
    }

    function Invoke-MainlineValidator {
        param(
            [string]$Root,
            [string[]]$ChangedPaths = @(),
            [string]$BaseRef,
            [string]$HeadRef = 'HEAD',
            [switch]$RequireReady,
            [switch]$OmitReadinessScope,
            [ValidateSet('Aggregate', 'Batch')]
            [string]$ReadinessScope = 'Batch'
        )
        $commandArguments = @('-NoLogo', '-NoProfile', '-File', $script:validator, '-WorkspaceRoot', $Root, '-Json')
        if ($BaseRef) {
            $commandArguments += @('-BaseRef', $BaseRef, '-HeadRef', $HeadRef)
        } elseif ($ChangedPaths.Count -gt 0) {
            $changedPathsJson = $ChangedPaths | ConvertTo-Json -Compress
            $commandArguments += @('-ChangedPathsJson', $changedPathsJson)
        }
        if ($RequireReady) {
            $commandArguments += '-RequireReady'
            if (-not $OmitReadinessScope) {
                $commandArguments += @('-ReadinessScope', $ReadinessScope)
            }
        }
        $output = @(& pwsh @commandArguments 2>&1)
        $exitCode = $LASTEXITCODE
        $raw = $output -join "`n"
        return [pscustomobject]@{
            ExitCode = $exitCode
            Raw = $raw
            Data = $raw | ConvertFrom-Json
        }
    }

    function Write-FixtureText {
        param([string]$Path, [string]$Content)
        $directory = Split-Path -Parent $Path
        if (-not (Test-Path -LiteralPath $directory)) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
        }
        [System.IO.File]::WriteAllText(
            $Path,
            (($Content -replace "`r`n?", "`n").TrimEnd() + "`n"),
            [System.Text.UTF8Encoding]::new($false)
        )
    }

    function Invoke-FixtureGit {
        param([string]$Root, [string[]]$Arguments)
        $output = @(& git -C $Root @Arguments 2>&1)
        if ($LASTEXITCODE -ne 0) {
            throw "Fixture git failed: git $($Arguments -join ' ')`n$($output -join "`n")"
        }
        return @($output)
    }

    function Complete-FixtureCommit {
        param([string]$Root, [string]$Message)
        Invoke-FixtureGit -Root $Root -Arguments @('add', '-A') | Out-Null
        Invoke-FixtureGit -Root $Root -Arguments @('commit', '--quiet', '-m', $Message) | Out-Null
        $revisionOutput = @(Invoke-FixtureGit -Root $Root -Arguments @('rev-parse', 'HEAD'))
        return ([string]$revisionOutput[-1]).Trim()
    }

    function Initialize-GitMainlineFixture {
        $root = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path (Join-Path $root 'docs/mainline-updates') -Force | Out-Null
        Write-TestJson -Path (Join-Path $root 'studio/runtime/mainline-note-validation-baseline.json') -Value ([ordered]@{
            schemaVersion = 1
            entries = @()
        })
        Write-TestJson -Path (Join-Path $root 'studio/runtime/shared-runtime-contract.json') -Value ([ordered]@{
            sharedGatePaths = @($script:productionContract.sharedGatePaths)
            mainlineReadiness = [ordered]@{
                repositorySlug = [string]$script:productionContract.mainlineReadiness.repositorySlug
                aggregateNotePaths = @($script:productionContract.mainlineReadiness.aggregateNotePaths)
            }
        })
        Write-TestJson -Path (Join-Path $root 'studio/runtime/impact-registry.json') -Value ([ordered]@{
            impactRouting = @()
        })
        Write-FixtureText -Path (Join-Path $root 'docs/mainline-updates/README.md') -Content @'
# Mainline Update Notes

| Date | Topic | Source Branch | Status | Summary |
|------|-------|---------------|--------|---------|
'@
        Write-FixtureText -Path (Join-Path $root 'studio/scripts/powershell/example.ps1') -Content "'base'"
        Write-FixtureText -Path (Join-Path $root 'studio/scripts/powershell/add-extension.ps1') -Content "'governed base'"
        Write-FixtureText -Path (Join-Path $root 'studio/scripts/powershell/setup-eci.ps1') -Content "'governed base'"

        & git -C $root init --quiet --initial-branch=main
        if ($LASTEXITCODE -ne 0) { throw 'Unable to initialize Git fixture.' }
        Invoke-FixtureGit -Root $root -Arguments @('config', 'user.name', 'Governance Fixture') | Out-Null
        Invoke-FixtureGit -Root $root -Arguments @('config', 'user.email', 'fixture@example.invalid') | Out-Null
        Invoke-FixtureGit -Root $root -Arguments @(
            'remote', 'add', 'origin', 'https://github.com/dtgfdgfgf/SDD-WorkSpace.git'
        ) | Out-Null
        $base = Complete-FixtureCommit -Root $root -Message 'test: base'
        Invoke-FixtureGit -Root $root -Arguments @('switch', '--quiet', '-c', 'feature/test') | Out-Null

        Write-FixtureText -Path (Join-Path $root 'studio/scripts/powershell/example.ps1') -Content "'feature'"
        $evidence = Complete-FixtureCommit -Root $root -Message 'fix: shared change'
        Write-TestNote -Root $root -Commits $evidence | Out-Null
        Write-TestIndex -Root $root
        Complete-FixtureCommit -Root $root -Message 'docs: ready note' | Out-Null

        return [pscustomobject]@{
            Root = $root
            Base = $base
            Evidence = $evidence
        }
    }
}

Describe 'validate-mainline-notes state and branch reconciliation' {
    BeforeEach {
        $script:fixtureRoot = Initialize-MainlineFixture
    }

    AfterEach {
        if (Test-Path -LiteralPath $script:fixtureRoot) {
            Remove-Item -LiteralPath $script:fixtureRoot -Recurse -Force
        }
    }

    It 'accepts a Ready note with concrete commit evidence and matching index' {
        $result = Invoke-MainlineValidator -Root $script:fixtureRoot

        $result.ExitCode | Should -Be 0
        $result.Data.VALID | Should -BeTrue
        $result.Data.ERROR_COUNT | Should -Be 0
    }

    It 'rejects a Ready note whose commit and PR evidence are both unresolved' {
        Write-TestNote -Root $script:fixtureRoot -Commits 'TBD' | Out-Null
        $result = Invoke-MainlineValidator -Root $script:fixtureRoot

        $result.ExitCode | Should -Be 1
        $result.Data.ERRORS.category | Should -Contain 'ready-evidence'
    }

    It 'requires a final commit hash for Merged even when a PR reference exists' {
        $notePath = Write-TestNote -Root $script:fixtureRoot -Status 'Merged' -Commits 'TBD'
        $content = (Get-Content -LiteralPath $notePath -Raw).Replace('**Related PR**: N/A', '**Related PR**: #123')
        [System.IO.File]::WriteAllText($notePath, $content, [System.Text.UTF8Encoding]::new($false))
        Write-TestIndex -Root $script:fixtureRoot -Status 'Merged'

        $result = Invoke-MainlineValidator -Root $script:fixtureRoot

        $result.ExitCode | Should -Be 1
        $result.Data.ERRORS.category | Should -Contain 'ready-evidence'
    }

    It 'allows only an exact hash-bound legacy Ready/TBD baseline entry' {
        $notePath = Write-TestNote -Root $script:fixtureRoot -Commits 'TBD'
        $hash = (Get-FileHash -LiteralPath $notePath -Algorithm SHA256).Hash.ToLowerInvariant()
        Write-TestJson -Path (Join-Path $script:fixtureRoot 'studio/runtime/mainline-note-validation-baseline.json') -Value ([ordered]@{
            schemaVersion = 1
            entries = @([ordered]@{ path = 'docs/mainline-updates/2099-01-01-test.md'; sha256 = $hash })
        })

        $result = Invoke-MainlineValidator -Root $script:fixtureRoot

        $result.ExitCode | Should -Be 0
        $result.Data.WARNING_COUNT | Should -Be 0
        $result.Data.LEGACY_BASELINE_APPLIED | Should -Contain 'docs/mainline-updates/2099-01-01-test.md'
    }

    It 'invalidates the legacy exception when the note bytes change' {
        $notePath = Write-TestNote -Root $script:fixtureRoot -Commits 'TBD'
        $hash = (Get-FileHash -LiteralPath $notePath -Algorithm SHA256).Hash.ToLowerInvariant()
        Write-TestJson -Path (Join-Path $script:fixtureRoot 'studio/runtime/mainline-note-validation-baseline.json') -Value ([ordered]@{
            schemaVersion = 1
            entries = @([ordered]@{ path = 'docs/mainline-updates/2099-01-01-test.md'; sha256 = $hash })
        })
        Add-Content -LiteralPath $notePath -Value 'changed'

        $result = Invoke-MainlineValidator -Root $script:fixtureRoot

        $result.ExitCode | Should -Be 1
        $result.Data.ERRORS.category | Should -Contain 'legacy-baseline-stale'
        $result.Data.ERRORS.category | Should -Contain 'ready-evidence'
    }

    It 'rejects index status drift' {
        Write-TestIndex -Root $script:fixtureRoot -Status 'Draft'
        $result = Invoke-MainlineValidator -Root $script:fixtureRoot

        $result.ExitCode | Should -Be 1
        $result.Data.ERRORS.category | Should -Contain 'note-index-status'
    }

    It 'accepts a structurally closed reconciliation with explicit changed paths in nonblocking mode' {
        Write-TestNote -Root $script:fixtureRoot -Rows @(
            '| `.claude/agents/*.md` | `must_update` | `updated` | Re-seeded from the changed canonical agent source. |'
        ) | Out-Null
        $result = Invoke-MainlineValidator -Root $script:fixtureRoot -ChangedPaths @(
            '.github/agents/example.agent.md',
            '.claude/agents/example.md',
            'docs/mainline-updates/2099-01-01-test.md'
        )

        $result.ExitCode | Should -Be 0
        $result.Data.REQUIRED_RECONCILIATIONS.target | Should -Contain '.claude/agents/*.md'
    }

    It 'denies blocking readiness with explicit changed paths because BaseRef evidence is unavailable' {
        $result = Invoke-MainlineValidator -Root $script:fixtureRoot -ChangedPaths @(
            'studio/scripts/powershell/example.ps1',
            'docs/mainline-updates/2099-01-01-test.md'
        ) -RequireReady

        $result.ExitCode | Should -Be 1
        $result.Data.ERRORS.category | Should -Contain 'arguments'
        $result.Data.ERRORS.category | Should -Contain 'commit-evidence-git-context-required'
    }

    It 'rejects a missing must_update target from the aggregate branch diff' {
        Write-TestNote -Root $script:fixtureRoot -Rows @(
            '| `.claude/agents/*.md` | `must_update` | `updated` | Claimed mirror update. |'
        ) | Out-Null
        $result = Invoke-MainlineValidator -Root $script:fixtureRoot -ChangedPaths @(
            '.github/agents/example.agent.md',
            'docs/mainline-updates/2099-01-01-test.md'
        ) -RequireReady

        $result.ExitCode | Should -Be 1
        $result.Data.ERRORS.category | Should -Contain 'must-update-target-missing'
    }

    It 'rejects an omitted reconciliation row for a required target' {
        $result = Invoke-MainlineValidator -Root $script:fixtureRoot -ChangedPaths @(
            '.github/agents/example.agent.md',
            '.claude/agents/example.md',
            'docs/mainline-updates/2099-01-01-test.md'
        ) -RequireReady

        $result.ExitCode | Should -Be 1
        $result.Data.ERRORS.category | Should -Contain 'must-update-reconciliation-missing'
    }

    It 'rejects a Draft note at the merge gate but global validation does not block incremental work' {
        Write-TestNote -Root $script:fixtureRoot -Status 'Draft' -Commits 'TBD' -ReconciliationStatus 'Open' | Out-Null
        Write-TestIndex -Root $script:fixtureRoot -Status 'Draft'

        $global = Invoke-MainlineValidator -Root $script:fixtureRoot
        $branch = Invoke-MainlineValidator -Root $script:fixtureRoot -ChangedPaths @(
            'studio/scripts/powershell/example.ps1',
            'docs/mainline-updates/2099-01-01-test.md'
        ) -RequireReady

        $global.ExitCode | Should -Be 0
        $branch.ExitCode | Should -Be 1
        $branch.Data.ERRORS.category | Should -Contain 'branch-note-not-ready'
    }

    It 'rejects a changed Ready note that omits reconciliation state even in a note-only diff' {
        Write-TestNote -Root $script:fixtureRoot -ReconciliationStatus '' | Out-Null
        $result = Invoke-MainlineValidator -Root $script:fixtureRoot -ChangedPaths @(
            'docs/mainline-updates/2099-01-01-test.md'
        ) -RequireReady

        $result.ExitCode | Should -Be 1
        $result.Data.ERRORS.category | Should -Contain 'reconciliation-state'
    }

    It 'does not accept a reconciliation row outside the named section' {
        $notePath = Write-TestNote -Root $script:fixtureRoot -Rows @(
            '| `.claude/agents/*.md` | `must_update` | `updated` | Fake row outside the required section. |'
        )
        $content = (Get-Content -LiteralPath $notePath -Raw).Replace('## Impact Reconciliation', '## Other Table')
        [System.IO.File]::WriteAllText($notePath, $content, [System.Text.UTF8Encoding]::new($false))

        $result = Invoke-MainlineValidator -Root $script:fixtureRoot -ChangedPaths @(
            '.github/agents/example.agent.md',
            '.claude/agents/example.md',
            'docs/mainline-updates/2099-01-01-test.md'
        ) -RequireReady

        $result.ExitCode | Should -Be 1
        $result.Data.ERRORS.category | Should -Contain 'reconciliation-section-missing'
        $result.Data.ERRORS.category | Should -Contain 'must-update-reconciliation-missing'
    }

    It 'does not accept a reconciliation row hidden in an HTML comment' {
        Write-TestNote -Root $script:fixtureRoot -Rows @(
            '<!--',
            '| `.claude/agents/*.md` | `must_update` | `updated` | Hidden fake evidence. |',
            '-->'
        ) | Out-Null
        $result = Invoke-MainlineValidator -Root $script:fixtureRoot -ChangedPaths @(
            '.github/agents/example.agent.md',
            '.claude/agents/example.md',
            'docs/mainline-updates/2099-01-01-test.md'
        ) -RequireReady

        $result.ExitCode | Should -Be 1
        $result.Data.ERRORS.category | Should -Contain 'must-update-reconciliation-missing'
    }

    It 'does not accept a reconciliation section hidden in a fenced block' {
        $notePath = Write-TestNote -Root $script:fixtureRoot -Rows @(
            '| `.claude/agents/*.md` | `must_update` | `updated` | Hidden fake evidence. |'
        )
        $content = Get-Content -LiteralPath $notePath -Raw
        $content = $content.Replace('## Impact Reconciliation', ('```md' + "`n" + '## Impact Reconciliation'))
        $content += '```' + "`n"
        [System.IO.File]::WriteAllText($notePath, $content, [System.Text.UTF8Encoding]::new($false))

        $result = Invoke-MainlineValidator -Root $script:fixtureRoot -ChangedPaths @(
            '.github/agents/example.agent.md',
            '.claude/agents/example.md',
            'docs/mainline-updates/2099-01-01-test.md'
        ) -RequireReady

        $result.ExitCode | Should -Be 1
        $result.Data.ERRORS.category | Should -Contain 'reconciliation-section-missing'
    }

    It 'does not accept rows after an unclosed HTML comment inside reconciliation' {
        Write-TestNote -Root $script:fixtureRoot -Rows @(
            '<!-- unclosed comment',
            '| `.claude/agents/*.md` | `must_update` | `updated` | Hidden fake evidence. |'
        ) | Out-Null

        $result = Invoke-MainlineValidator -Root $script:fixtureRoot -ChangedPaths @(
            '.github/agents/example.agent.md',
            '.claude/agents/example.md',
            'docs/mainline-updates/2099-01-01-test.md'
        ) -RequireReady

        $result.ExitCode | Should -Be 1
        $result.Data.ERRORS.category | Should -Contain 'reconciliation-section-malformed'
        $result.Data.ERRORS.category | Should -Contain 'must-update-reconciliation-missing'
    }

    It 'does not accept rows after an unclosed fenced block inside reconciliation' {
        Write-TestNote -Root $script:fixtureRoot -Rows @(
            '```md',
            '| `.claude/agents/*.md` | `must_update` | `updated` | Hidden fake evidence. |'
        ) | Out-Null

        $result = Invoke-MainlineValidator -Root $script:fixtureRoot -ChangedPaths @(
            '.github/agents/example.agent.md',
            '.claude/agents/example.md',
            'docs/mainline-updates/2099-01-01-test.md'
        ) -RequireReady

        $result.ExitCode | Should -Be 1
        $result.Data.ERRORS.category | Should -Contain 'reconciliation-section-malformed'
        $result.Data.ERRORS.category | Should -Contain 'must-update-reconciliation-missing'
    }

    It 'rejects a changed Ready/TBD note even when the baseline hash is refreshed' {
        $notePath = Write-TestNote -Root $script:fixtureRoot -Commits 'TBD'
        $hash = (Get-FileHash -LiteralPath $notePath -Algorithm SHA256).Hash.ToLowerInvariant()
        Write-TestJson -Path (Join-Path $script:fixtureRoot 'studio/runtime/mainline-note-validation-baseline.json') -Value ([ordered]@{
            schemaVersion = 1
            entries = @([ordered]@{ path = 'docs/mainline-updates/2099-01-01-test.md'; sha256 = $hash })
        })

        $result = Invoke-MainlineValidator -Root $script:fixtureRoot -ChangedPaths @(
            'studio/runtime/mainline-note-validation-baseline.json',
            'docs/mainline-updates/2099-01-01-test.md'
        ) -RequireReady

        $result.ExitCode | Should -Be 1
        $result.Data.ERRORS.category | Should -Contain 'legacy-baseline-note-changed'
    }
}

Describe 'validate-mainline-notes Git-backed evidence integrity' {
    BeforeEach {
        $script:gitFixture = Initialize-GitMainlineFixture
    }

    AfterEach {
        if ($script:gitFixture -and (Test-Path -LiteralPath $script:gitFixture.Root)) {
            Remove-Item -LiteralPath $script:gitFixture.Root -Recurse -Force
        }
    }

    It 'accepts a Batch Ready note whose in-range commit is the shared path last touch' {
        $result = Invoke-MainlineValidator -Root $script:gitFixture.Root `
            -BaseRef $script:gitFixture.Base -RequireReady -ReadinessScope Batch

        $result.ExitCode | Should -Be 0 -Because $result.Raw
        $result.Data.VALID | Should -BeTrue
    }

    It 'requires an explicit readiness scope at a blocking gate' {
        $result = Invoke-MainlineValidator -Root $script:gitFixture.Root `
            -BaseRef $script:gitFixture.Base -RequireReady -OmitReadinessScope

        $result.ExitCode | Should -Be 1
        $result.Data.ERRORS.category | Should -Contain 'arguments'
    }

    It 'does not reuse historical Git evidence when blocking readiness omits BaseRef' {
        $result = Invoke-MainlineValidator -Root $script:gitFixture.Root -ChangedPaths @(
            'studio/scripts/powershell/example.ps1',
            'docs/mainline-updates/2099-01-01-test.md'
        ) -RequireReady -ReadinessScope Batch

        $result.ExitCode | Should -Be 1
        $result.Data.ERRORS.category | Should -Contain 'arguments'
        $result.Data.BASE_REF_MODE | Should -BeFalse
    }

    It 'rejects deadbee as a nonexistent commit object' {
        Write-TestNote -Root $script:gitFixture.Root -Commits 'deadbee' | Out-Null
        $result = Invoke-MainlineValidator -Root $script:gitFixture.Root `
            -BaseRef $script:gitFixture.Base -RequireReady -ReadinessScope Batch

        $result.ExitCode | Should -Be 1
        $result.Data.ERRORS.category | Should -Contain 'commit-evidence-object-invalid'
    }

    It 'rejects a Git object that is not a commit' {
        $blobPath = Join-Path $script:gitFixture.Root 'untracked-blob.txt'
        Write-FixtureText -Path $blobPath -Content 'not a commit'
        $blobOutput = @(Invoke-FixtureGit -Root $script:gitFixture.Root -Arguments @(
            'hash-object', '-w', $blobPath
        ))
        $blobHash = ([string]$blobOutput[-1]).Trim()
        Write-TestNote -Root $script:gitFixture.Root -Commits $blobHash | Out-Null

        $result = Invoke-MainlineValidator -Root $script:gitFixture.Root `
            -BaseRef $script:gitFixture.Base -RequireReady -ReadinessScope Batch

        $result.ExitCode | Should -Be 1
        $result.Data.ERRORS.category | Should -Contain 'commit-evidence-object-invalid'
    }

    It 'rejects an existing commit outside merge-base through HeadRef' {
        Write-TestNote -Root $script:gitFixture.Root -Commits $script:gitFixture.Base | Out-Null
        $result = Invoke-MainlineValidator -Root $script:gitFixture.Root `
            -BaseRef $script:gitFixture.Base -RequireReady -ReadinessScope Batch

        $result.ExitCode | Should -Be 1
        $result.Data.ERRORS.category | Should -Contain 'commit-evidence-out-of-range'
    }

    It 'does not let an unrelated in-range commit cover another shared path' {
        Write-FixtureText -Path (
            Join-Path $script:gitFixture.Root 'studio/scripts/powershell/nested/uncovered.ps1'
        ) -Content "'uncovered'"
        Complete-FixtureCommit -Root $script:gitFixture.Root -Message 'fix: unrelated shared path' | Out-Null

        $result = Invoke-MainlineValidator -Root $script:gitFixture.Root `
            -BaseRef $script:gitFixture.Base -RequireReady -ReadinessScope Batch

        $result.ExitCode | Should -Be 1
        $result.Data.ERRORS.category | Should -Contain 'branch-evidence-coverage-missing'
        $result.Data.ERRORS.path | Should -Contain 'studio/scripts/powershell/nested/uncovered.ps1'
    }

    It 'matches recursive category rules for nested shared paths when their last touch is cited' {
        $nestedPath = Join-Path $script:gitFixture.Root 'studio/scripts/powershell/nested/covered.ps1'
        Write-FixtureText -Path $nestedPath -Content "'covered'"
        $nestedCommit = Complete-FixtureCommit -Root $script:gitFixture.Root -Message 'fix: nested shared path'
        Write-TestNote -Root $script:gitFixture.Root -Commits "$($script:gitFixture.Evidence); $nestedCommit" | Out-Null
        Complete-FixtureCommit -Root $script:gitFixture.Root -Message 'docs: cover nested path' | Out-Null

        $result = Invoke-MainlineValidator -Root $script:gitFixture.Root `
            -BaseRef $script:gitFixture.Base -RequireReady -ReadinessScope Batch

        $result.ExitCode | Should -Be 0 -Because $result.Raw
    }

    It 'rejects a fully qualified pull request from another repository' {
        $notePath = Write-TestNote -Root $script:gitFixture.Root -Commits 'TBD'
        $content = (Get-Content -LiteralPath $notePath -Raw).Replace(
            '**Related PR**: N/A',
            '**Related PR**: https://github.com/other/repository/pull/3'
        )
        Write-FixtureText -Path $notePath -Content $content

        $result = Invoke-MainlineValidator -Root $script:gitFixture.Root `
            -BaseRef $script:gitFixture.Base -RequireReady -ReadinessScope Batch

        $result.ExitCode | Should -Be 1
        $result.Data.ERRORS.category | Should -Contain 'pr-evidence-repository-mismatch'
    }

    It 'does not let a mutable wrong origin redefine the contract-bound PR repository' {
        Invoke-FixtureGit -Root $script:gitFixture.Root -Arguments @(
            'remote', 'set-url', 'origin', 'https://github.com/other/repository.git'
        ) | Out-Null
        $notePath = Write-TestNote -Root $script:gitFixture.Root -Commits $script:gitFixture.Evidence
        $content = (Get-Content -LiteralPath $notePath -Raw).Replace(
            '**Related PR**: N/A',
            '**Related PR**: https://github.com/other/repository/pull/3'
        )
        Write-FixtureText -Path $notePath -Content $content

        $result = Invoke-MainlineValidator -Root $script:gitFixture.Root `
            -BaseRef $script:gitFixture.Base -RequireReady -ReadinessScope Batch

        $result.ExitCode | Should -Be 1
        $result.Data.ERRORS.category | Should -Contain 'pr-evidence-repository-mismatch'
    }

    It 'does not accept an unqualified pull-request number as repository proof' {
        $notePath = Write-TestNote -Root $script:gitFixture.Root -Commits 'TBD'
        $content = (Get-Content -LiteralPath $notePath -Raw).Replace(
            '**Related PR**: N/A',
            '**Related PR**: #3'
        )
        Write-FixtureText -Path $notePath -Content $content

        $result = Invoke-MainlineValidator -Root $script:gitFixture.Root `
            -BaseRef $script:gitFixture.Base -RequireReady -ReadinessScope Batch

        $result.ExitCode | Should -Be 1
        $result.Data.ERRORS.category | Should -Contain 'pr-evidence-unqualified'
    }

    It 'rejects a changed Ready note with a missing required section' {
        $notePath = Write-TestNote -Root $script:gitFixture.Root -Commits $script:gitFixture.Evidence
        $content = (Get-Content -LiteralPath $notePath -Raw).Replace('## Scope', '### Scope')
        Write-FixtureText -Path $notePath -Content $content
        $result = Invoke-MainlineValidator -Root $script:gitFixture.Root `
            -BaseRef $script:gitFixture.Base -RequireReady -ReadinessScope Batch

        $result.ExitCode | Should -Be 1
        $result.Data.ERRORS.category | Should -Contain 'required-section-missing'
    }

    It 'does not count a required section hidden in an HTML comment' {
        $notePath = Write-TestNote -Root $script:gitFixture.Root -Commits $script:gitFixture.Evidence
        $content = (Get-Content -LiteralPath $notePath -Raw).Replace(
            '## Scope',
            "<!--`n## Scope`n-->"
        )
        Write-FixtureText -Path $notePath -Content $content
        $result = Invoke-MainlineValidator -Root $script:gitFixture.Root `
            -BaseRef $script:gitFixture.Base -RequireReady -ReadinessScope Batch

        $result.ExitCode | Should -Be 1
        $result.Data.ERRORS.category | Should -Contain 'required-section-missing'
    }

    It 'does not count a required section hidden in a fenced block' {
        $notePath = Write-TestNote -Root $script:gitFixture.Root -Commits $script:gitFixture.Evidence
        $content = (Get-Content -LiteralPath $notePath -Raw).Replace(
            '## Scope',
            ('```md' + "`n" + '## Scope' + "`n" + '```')
        )
        Write-FixtureText -Path $notePath -Content $content
        $result = Invoke-MainlineValidator -Root $script:gitFixture.Root `
            -BaseRef $script:gitFixture.Base -RequireReady -ReadinessScope Batch

        $result.ExitCode | Should -Be 1
        $result.Data.ERRORS.category | Should -Contain 'required-section-missing'
    }

    It 'does not let a shorter fence close expose required sections from a four-backtick block' {
        $notePath = Write-TestNote -Root $script:gitFixture.Root -Commits $script:gitFixture.Evidence
        $content = (Get-Content -LiteralPath $notePath -Raw).Replace(
            '## Scope',
            ('````md' + "`n" + '```' + "`n" + '## Scope')
        )
        Write-FixtureText -Path $notePath -Content $content

        $result = Invoke-MainlineValidator -Root $script:gitFixture.Root `
            -BaseRef $script:gitFixture.Base -RequireReady -ReadinessScope Batch
        $scopeErrors = @(
            $result.Data.ERRORS |
                Where-Object category -eq 'required-section-missing' |
                Select-Object -ExpandProperty message
        )

        $result.ExitCode | Should -Be 1
        ($scopeErrors -join "`n") | Should -Match ([regex]::Escape("'## Scope'"))
    }

    It 'does not let a shorter fence close expose reconciliation from a four-backtick block' {
        $notePath = Write-TestNote -Root $script:gitFixture.Root -Commits $script:gitFixture.Evidence
        $content = (Get-Content -LiteralPath $notePath -Raw).Replace(
            '## Impact Reconciliation',
            ('````md' + "`n" + '```' + "`n" + '## Impact Reconciliation')
        )
        Write-FixtureText -Path $notePath -Content $content

        $result = Invoke-MainlineValidator -Root $script:gitFixture.Root `
            -BaseRef $script:gitFixture.Base -RequireReady -ReadinessScope Batch

        $result.ExitCode | Should -Be 1
        $result.Data.ERRORS.category | Should -Contain 'reconciliation-section-missing'
    }

    It 'does not count indented-code headings as visible required sections' {
        foreach ($indent in @('    ', "`t")) {
            $notePath = Write-TestNote -Root $script:gitFixture.Root -Commits $script:gitFixture.Evidence
            $content = (Get-Content -LiteralPath $notePath -Raw).Replace('## Scope', ($indent + '## Scope'))
            Write-FixtureText -Path $notePath -Content $content

            $result = Invoke-MainlineValidator -Root $script:gitFixture.Root `
                -BaseRef $script:gitFixture.Base -RequireReady -ReadinessScope Batch
            $scopeErrors = @(
                $result.Data.ERRORS |
                    Where-Object category -eq 'required-section-missing' |
                    Select-Object -ExpandProperty message
            )

            $result.ExitCode | Should -Be 1
            ($scopeErrors -join "`n") | Should -Match ([regex]::Escape("'## Scope'"))
        }
    }

    It 'does not accept governance metadata hidden in an HTML comment' {
        $notePath = Write-TestNote -Root $script:gitFixture.Root -Commits $script:gitFixture.Evidence
        $content = Get-Content -LiteralPath $notePath -Raw
        $content = $content.Replace('**Status**: Ready', ('<!--' + "`n" + '**Status**: Ready'))
        $content = $content.Replace('**Reconciliation Status**: Closed', ('**Reconciliation Status**: Closed' + "`n" + '-->'))
        Write-FixtureText -Path $notePath -Content $content

        $result = Invoke-MainlineValidator -Root $script:gitFixture.Root `
            -BaseRef $script:gitFixture.Base -RequireReady -ReadinessScope Batch

        $result.ExitCode | Should -Be 1
        $result.Data.ERRORS.category | Should -Contain 'note-metadata-count'
    }

    It 'does not accept governance metadata hidden in a fenced block' {
        $notePath = Write-TestNote -Root $script:gitFixture.Root -Commits $script:gitFixture.Evidence
        $content = Get-Content -LiteralPath $notePath -Raw
        $content = $content.Replace('**Status**: Ready', ('```text' + "`n" + '**Status**: Ready'))
        $content = $content.Replace('**Reconciliation Status**: Closed', ('**Reconciliation Status**: Closed' + "`n" + '```'))
        Write-FixtureText -Path $notePath -Content $content

        $result = Invoke-MainlineValidator -Root $script:gitFixture.Root `
            -BaseRef $script:gitFixture.Base -RequireReady -ReadinessScope Batch

        $result.ExitCode | Should -Be 1
        $result.Data.ERRORS.category | Should -Contain 'note-metadata-count'
    }

    It 'does not accept governance metadata rendered inside a raw preformatted HTML block' {
        $notePath = Write-TestNote -Root $script:gitFixture.Root -Commits $script:gitFixture.Evidence
        $content = Get-Content -LiteralPath $notePath -Raw
        $content = $content.Replace('**Status**: Ready', ('<pre>' + "`n" + '**Status**: Ready'))
        $content = $content.Replace('**Reconciliation Status**: Closed', ('**Reconciliation Status**: Closed' + "`n" + '</pre>'))
        Write-FixtureText -Path $notePath -Content $content

        $result = Invoke-MainlineValidator -Root $script:gitFixture.Root `
            -BaseRef $script:gitFixture.Base -RequireReady -ReadinessScope Batch

        $result.ExitCode | Should -Be 1
        $result.Data.ERRORS.category | Should -Contain 'note-metadata-count'
    }

    It 'does not accept required sections or reconciliation inside a raw preformatted HTML block' {
        $notePath = Write-TestNote -Root $script:gitFixture.Root -Commits $script:gitFixture.Evidence
        $content = (Get-Content -LiteralPath $notePath -Raw).Replace(
            '## Scope',
            ('<pre>' + "`n" + '## Scope')
        )
        $content += '</pre>' + "`n"
        Write-FixtureText -Path $notePath -Content $content

        $result = Invoke-MainlineValidator -Root $script:gitFixture.Root `
            -BaseRef $script:gitFixture.Base -RequireReady -ReadinessScope Batch

        $result.ExitCode | Should -Be 1
        $result.Data.ERRORS.category | Should -Contain 'required-section-missing'
        $result.Data.ERRORS.category | Should -Contain 'reconciliation-section-missing'
    }

    It 'does not count a required section inside a block-tag HTML container' {
        $notePath = Write-TestNote -Root $script:gitFixture.Root -Commits $script:gitFixture.Evidence
        $content = (Get-Content -LiteralPath $notePath -Raw).Replace(
            '## Scope',
            ('<div>' + "`n" + '## Scope' + "`n" + '</div>')
        )
        Write-FixtureText -Path $notePath -Content $content

        $result = Invoke-MainlineValidator -Root $script:gitFixture.Root `
            -BaseRef $script:gitFixture.Base -RequireReady -ReadinessScope Batch

        $result.ExitCode | Should -Be 1
        $result.Data.ERRORS.category | Should -Contain 'required-section-missing'
    }

    It 'does not count a required section inside a multiline block-tag HTML container' {
        $notePath = Write-TestNote -Root $script:gitFixture.Root -Commits $script:gitFixture.Evidence
        $content = (Get-Content -LiteralPath $notePath -Raw).Replace(
            '## Scope',
            ('<div' + "`n" + 'class="fixture">' + "`n" + '## Scope' + "`n" + '</div>')
        )
        Write-FixtureText -Path $notePath -Content $content

        $result = Invoke-MainlineValidator -Root $script:gitFixture.Root `
            -BaseRef $script:gitFixture.Base -RequireReady -ReadinessScope Batch

        $result.ExitCode | Should -Be 1
        $result.Data.ERRORS.category | Should -Contain 'required-section-missing'
    }

    It 'rejects duplicate visible governance metadata even when values agree' {
        $notePath = Write-TestNote -Root $script:gitFixture.Root -Commits $script:gitFixture.Evidence
        $content = (Get-Content -LiteralPath $notePath -Raw).Replace(
            '**Status**: Ready',
            ('**Status**: Ready' + "`n" + '**Status**: Ready')
        )
        Write-FixtureText -Path $notePath -Content $content

        $result = Invoke-MainlineValidator -Root $script:gitFixture.Root `
            -BaseRef $script:gitFixture.Base -RequireReady -ReadinessScope Batch

        $result.ExitCode | Should -Be 1
        $result.Data.ERRORS.category | Should -Contain 'note-metadata-count'
    }

    It 'blocks a Draft aggregate anchor while allowing the same coherent Batch evidence' {
        $aggregatePath = [string]$script:productionContract.mainlineReadiness.aggregateNotePaths[0]
        $aggregateName = Split-Path -Leaf $aggregatePath
        Write-TestNote -Root $script:gitFixture.Root -Name $aggregateName `
            -Status Draft -Commits TBD -ReconciliationStatus Open | Out-Null
        $indexPath = Join-Path $script:gitFixture.Root 'docs/mainline-updates/README.md'
        $index = Get-Content -LiteralPath $indexPath -Raw
        $index += "| 2026-05-05 | [aggregate](./$aggregateName) | ``feature/test`` | Draft | Aggregate fixture |`n"
        Write-FixtureText -Path $indexPath -Content $index
        Complete-FixtureCommit -Root $script:gitFixture.Root -Message 'docs: add Draft aggregate anchor' | Out-Null

        $aggregate = Invoke-MainlineValidator -Root $script:gitFixture.Root `
            -BaseRef $script:gitFixture.Base -RequireReady -ReadinessScope Aggregate
        $batch = Invoke-MainlineValidator -Root $script:gitFixture.Root `
            -BaseRef $script:gitFixture.Base -RequireReady -ReadinessScope Batch

        $aggregate.ExitCode | Should -Be 1
        $aggregate.Data.ERRORS.category | Should -Contain 'aggregate-note-not-ready'
        $batch.ExitCode | Should -Be 0 -Because $batch.Raw
    }

    It 'blocks an unchanged Draft aggregate anchor while a later coherent Batch note covers the diff' {
        $aggregatePath = [string]$script:productionContract.mainlineReadiness.aggregateNotePaths[0]
        $aggregateName = Split-Path -Leaf $aggregatePath
        Write-TestNote -Root $script:gitFixture.Root -Name $aggregateName `
            -Status Draft -Commits TBD -ReconciliationStatus Open | Out-Null
        $indexPath = Join-Path $script:gitFixture.Root 'docs/mainline-updates/README.md'
        $index = Get-Content -LiteralPath $indexPath -Raw
        $index += "| 2026-05-05 | [aggregate](./$aggregateName) | ``feature/test`` | Draft | Aggregate fixture |`n"
        Write-FixtureText -Path $indexPath -Content $index
        $anchorBase = Complete-FixtureCommit -Root $script:gitFixture.Root -Message 'docs: establish Draft aggregate anchor'

        Write-FixtureText -Path (
            Join-Path $script:gitFixture.Root 'studio/scripts/powershell/example.ps1'
        ) -Content "'later feature change'"
        $laterEvidence = Complete-FixtureCommit -Root $script:gitFixture.Root -Message 'fix: later shared change'
        Write-TestNote -Root $script:gitFixture.Root -Commits $laterEvidence | Out-Null
        Complete-FixtureCommit -Root $script:gitFixture.Root -Message 'docs: document later batch' | Out-Null

        $aggregate = Invoke-MainlineValidator -Root $script:gitFixture.Root `
            -BaseRef $anchorBase -RequireReady -ReadinessScope Aggregate
        $batch = Invoke-MainlineValidator -Root $script:gitFixture.Root `
            -BaseRef $anchorBase -RequireReady -ReadinessScope Batch

        $aggregate.ExitCode | Should -Be 1
        $aggregate.Data.ERRORS.category | Should -Contain 'aggregate-note-not-ready'
        $batch.ExitCode | Should -Be 0 -Because $batch.Raw
    }

    It 'fails closed when Aggregate scope has no machine-configured anchor' {
        $contractPath = Join-Path $script:gitFixture.Root 'studio/runtime/shared-runtime-contract.json'
        $contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
        $contract.mainlineReadiness.aggregateNotePaths = @()
        $contract | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $contractPath -Encoding utf8

        $result = Invoke-MainlineValidator -Root $script:gitFixture.Root `
            -BaseRef $script:gitFixture.Base -RequireReady -ReadinessScope Aggregate

        $result.ExitCode | Should -Be 1
        $result.Data.ERRORS.category | Should -Contain 'aggregate-note-policy-missing'
    }

    It 'retains both sides of a governed rename so moving source outside the gate is blocked' {
        Write-FixtureText -Path (
            Join-Path $script:gitFixture.Root 'studio/scripts/powershell/example.ps1'
        ) -Content "'base'"
        Remove-Item -LiteralPath (
            Join-Path $script:gitFixture.Root 'docs/mainline-updates/2099-01-01-test.md'
        ) -Force
        Write-FixtureText -Path (
            Join-Path $script:gitFixture.Root 'docs/mainline-updates/README.md'
        ) -Content @'
# Mainline Update Notes

| Date | Topic | Source Branch | Status | Summary |
|------|-------|---------------|--------|---------|
'@
        New-Item -ItemType Directory -Path (Join-Path $script:gitFixture.Root 'outside') -Force | Out-Null
        Invoke-FixtureGit -Root $script:gitFixture.Root -Arguments @(
            'mv',
            'studio/scripts/powershell/add-extension.ps1',
            'outside/add-extension.ps1'
        ) | Out-Null
        Complete-FixtureCommit -Root $script:gitFixture.Root -Message 'test: rename governed source out' | Out-Null

        $result = Invoke-MainlineValidator -Root $script:gitFixture.Root `
            -BaseRef $script:gitFixture.Base -RequireReady -ReadinessScope Batch

        $result.ExitCode | Should -Be 1
        $result.Data.ERRORS.category | Should -Contain 'branch-note-missing'
        $result.Data.CHANGED_PATHS | Should -Contain 'studio/scripts/powershell/add-extension.ps1'
        $result.Data.CHANGED_PATHS | Should -Contain 'outside/add-extension.ps1'
        @($result.Data.CHANGED_PATH_RECORDS.status | Where-Object { $_ -match '^R\d+$' }).Count |
            Should -BeGreaterThan 0
    }

    It 'blocks an add-extension change with no mainline note through the real branch validator' {
        Remove-Item -LiteralPath (
            Join-Path $script:gitFixture.Root 'docs/mainline-updates/2099-01-01-test.md'
        ) -Force
        Write-FixtureText -Path (
            Join-Path $script:gitFixture.Root 'docs/mainline-updates/README.md'
        ) -Content @'
# Mainline Update Notes

| Date | Topic | Source Branch | Status | Summary |
|------|-------|---------------|--------|---------|
'@
        Write-FixtureText -Path (
            Join-Path $script:gitFixture.Root 'studio/scripts/powershell/add-extension.ps1'
        ) -Content "'changed without note'"
        Write-FixtureText -Path (
            Join-Path $script:gitFixture.Root 'studio/scripts/powershell/example.ps1'
        ) -Content "'base'"
        Complete-FixtureCommit -Root $script:gitFixture.Root -Message 'test: change omitted shared script' | Out-Null

        $result = Invoke-MainlineValidator -Root $script:gitFixture.Root `
            -BaseRef $script:gitFixture.Base -RequireReady -ReadinessScope Batch

        $result.ExitCode | Should -Be 1
        $result.Data.ERRORS.category | Should -Contain 'branch-note-missing'
        $result.Data.CHANGED_PATHS | Should -Contain 'studio/scripts/powershell/add-extension.ps1'
        @($result.Data.CHANGED_PATHS).Count | Should -Be 1
    }

    It 'blocks deletion of another formerly omitted shared script with no mainline note' {
        Remove-Item -LiteralPath (
            Join-Path $script:gitFixture.Root 'docs/mainline-updates/2099-01-01-test.md'
        ) -Force
        Write-FixtureText -Path (
            Join-Path $script:gitFixture.Root 'docs/mainline-updates/README.md'
        ) -Content @'
# Mainline Update Notes

| Date | Topic | Source Branch | Status | Summary |
|------|-------|---------------|--------|---------|
'@
        Remove-Item -LiteralPath (
            Join-Path $script:gitFixture.Root 'studio/scripts/powershell/setup-eci.ps1'
        ) -Force
        Write-FixtureText -Path (
            Join-Path $script:gitFixture.Root 'studio/scripts/powershell/example.ps1'
        ) -Content "'base'"
        Complete-FixtureCommit -Root $script:gitFixture.Root -Message 'test: delete omitted shared script' | Out-Null

        $result = Invoke-MainlineValidator -Root $script:gitFixture.Root `
            -BaseRef $script:gitFixture.Base -RequireReady -ReadinessScope Batch

        $result.ExitCode | Should -Be 1
        $result.Data.ERRORS.category | Should -Contain 'branch-note-missing'
        $result.Data.CHANGED_PATHS | Should -Contain 'studio/scripts/powershell/setup-eci.ps1'
        @($result.Data.CHANGED_PATHS).Count | Should -Be 1
    }
}
