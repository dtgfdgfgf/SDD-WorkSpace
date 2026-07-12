#Requires -Version 7.0

BeforeAll {
    $script:validator = Join-Path $PSScriptRoot '../scripts/powershell/validate-mainline-notes.ps1'

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
            '## Impact Reconciliation',
            '',
            '| Target | Impact | Disposition | Evidence |',
            '|--------|--------|-------------|----------|'
        )
        $lines += $Rows
        $lines += ''
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
            sharedGatePaths = @('.github/agents/', '.claude/agents/', 'studio/scripts/powershell/', 'docs/mainline-updates/')
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
            [switch]$RequireReady
        )
        $commandArguments = @('-NoLogo', '-NoProfile', '-File', $script:validator, '-WorkspaceRoot', $Root, '-Json')
        if ($ChangedPaths.Count -gt 0) {
            $changedPathsJson = $ChangedPaths | ConvertTo-Json -Compress
            $commandArguments += @('-ChangedPathsJson', $changedPathsJson)
        }
        if ($RequireReady) {
            $commandArguments += '-RequireReady'
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

    It 'accepts a closed aggregate reconciliation when source and must_update mirror both changed' {
        Write-TestNote -Root $script:fixtureRoot -Rows @(
            '| `.claude/agents/*.md` | `must_update` | `updated` | Re-seeded from the changed canonical agent source. |'
        ) | Out-Null
        $result = Invoke-MainlineValidator -Root $script:fixtureRoot -ChangedPaths @(
            '.github/agents/example.agent.md',
            '.claude/agents/example.md',
            'docs/mainline-updates/2099-01-01-test.md'
        ) -RequireReady

        $result.ExitCode | Should -Be 0
        $result.Data.REQUIRED_RECONCILIATIONS.target | Should -Contain '.claude/agents/*.md'
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
