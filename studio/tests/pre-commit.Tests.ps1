#!/usr/bin/env pwsh
#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/governance.config.ps1"
    . (Get-ScriptFunctionsBlock -ScriptPath (Join-Path $WorkspaceRoot '.githooks/pre-commit.ps1'))
    $script:workspaceRoot = $WorkspaceRoot
    $script:repoRoot = $WorkspaceRoot
    $script:isWorkspaceRepo = $true
}

# ============================================================
# Tier 1: Regression tests for fixed bugs
# ============================================================

Describe 'Convert-ToRepoRelativePath' {
    # Regression: C1 — TrimStart("./") was char-set removal, not prefix removal

    It 'preserves leading dot in .github paths' {
        Convert-ToRepoRelativePath -Path '.github/agents/foo.md' | Should -Be '.github/agents/foo.md'
    }

    It 'preserves leading dot in .claude paths' {
        Convert-ToRepoRelativePath -Path '.claude/agents/bar.md' | Should -Be '.claude/agents/bar.md'
    }

    It 'preserves leading dot in .githooks paths' {
        Convert-ToRepoRelativePath -Path '.githooks/pre-commit.ps1' | Should -Be '.githooks/pre-commit.ps1'
    }

    It 'removes ./ prefix correctly' {
        Convert-ToRepoRelativePath -Path './studio/foo.md' | Should -Be 'studio/foo.md'
    }

    It 'converts backslashes to forward slashes' {
        Convert-ToRepoRelativePath -Path 'studio\scripts\foo.ps1' | Should -Be 'studio/scripts/foo.ps1'
    }

    It 'handles combined backslash and ./ prefix' {
        Convert-ToRepoRelativePath -Path '.\studio\foo.md' | Should -Be 'studio/foo.md'
    }

    It 'returns empty string for empty input' {
        Convert-ToRepoRelativePath -Path '' | Should -Be ''
    }

    It 'returns empty string for null input (PowerShell coerces null to empty string)' {
        Convert-ToRepoRelativePath -Path $null | Should -Be ''
    }

    It 'handles paths without prefix unchanged' {
        Convert-ToRepoRelativePath -Path 'studio/constitution/constitution.md' | Should -Be 'studio/constitution/constitution.md'
    }

    It 'does not strip leading dots from filenames like ...dots.md' {
        Convert-ToRepoRelativePath -Path '...dots.md' | Should -Be '...dots.md'
    }
}

Describe 'Get-EdgeCaseCount' {
    Context 'with dedicated Edge Cases section' {
        It 'counts bullet items under Edge Cases heading' {
            $content = Get-Content (Get-FixturePath 'sample-spec-with-section.md') -Raw
            Get-EdgeCaseCount -Content $content | Should -Be 4
        }

        It 'counts items under Chinese heading 邊界情況' {
            $content = @"
## 邊界情況

- 輸入為空值
- 超時回應
- 無效格式
"@
            Get-EdgeCaseCount -Content $content | Should -Be 3
        }
    }

    Context 'fallback regex — regression for H1' {
        # H1: fallback pattern was over-matching standalone error/null/empty

        It 'does NOT count bullet with standalone "error" word' {
            $content = @"
## Requirements

- This function handles ErrorActionPreference
- System logs error messages to file
"@
            Get-EdgeCaseCount -Content $content | Should -Be 0
        }

        It 'does NOT count bullet with standalone "null" word' {
            $content = @"
## Design

- Returns null on success
- Check if null before proceeding
"@
            Get-EdgeCaseCount -Content $content | Should -Be 0
        }

        It 'does NOT count bullet with standalone "empty" word' {
            $content = @"
## Notes

- Empty response body is valid
- Start with empty configuration
"@
            Get-EdgeCaseCount -Content $content | Should -Be 0
        }

        It 'DOES count bullet with "edge case" compound phrase' {
            $content = @"
## Notes

- edge case: user submits twice
- boundary condition at max int
- exception handling for timeout
"@
            Get-EdgeCaseCount -Content $content | Should -Be 3
        }

        It 'DOES count bullet with qualified error/null/empty phrases' {
            $content = @"
## Considerations

- error handling when API fails
- null value returned unexpectedly
- empty input causes crash
"@
            Get-EdgeCaseCount -Content $content | Should -Be 3
        }

        It 'DOES count Chinese edge case terms' {
            $content = @"
## 設計考量

- 邊界情況：輸入為零
- 例外處理：逾時
- 異常狀態：連線中斷
"@
            Get-EdgeCaseCount -Content $content | Should -Be 3
        }
    }
}

Describe 'Get-ChangeTypesFromPaths' {
    # Regression: C2 — impact routing failed for dotfile paths

    BeforeAll {
        $script:mockRegistry = @{
            impactRouting = @(
                @{
                    changeType  = 'agent_change'
                    trigger     = '.github/agents/*.agent.md'
                    description = 'Agent definition change'
                    rules       = @()
                },
                @{
                    changeType  = 'constitution_change'
                    trigger     = 'studio/constitution/constitution.md'
                    description = 'Constitution change'
                    rules       = @()
                },
                @{
                    changeType  = 'hook_change'
                    trigger     = '.githooks/'
                    description = 'Hook change'
                    rules       = @()
                },
                @{
                    changeType  = 'feature_spec_change'
                    trigger     = 'specs/<feature>/spec.md'
                    description = 'Feature spec change'
                    rules       = @()
                }
            )
        }
    }

    It 'matches .github/agents glob trigger (C2 regression)' {
        $result = Get-ChangeTypesFromPaths -StagedPaths @('.github/agents/speckit.analyze.agent.md') -Registry $mockRegistry
        $result.Keys | Should -Contain 'agent_change'
    }

    It 'matches .githooks/ directory trigger (C2 regression)' {
        $result = Get-ChangeTypesFromPaths -StagedPaths @('.githooks/pre-commit.ps1') -Registry $mockRegistry
        $result.Keys | Should -Contain 'hook_change'
    }

    It 'matches exact path trigger' {
        $result = Get-ChangeTypesFromPaths -StagedPaths @('studio/constitution/constitution.md') -Registry $mockRegistry
        $result.Keys | Should -Contain 'constitution_change'
    }

    It 'captures feature name from <feature> placeholder' {
        $result = Get-ChangeTypesFromPaths -StagedPaths @('specs/001-login/spec.md') -Registry $mockRegistry
        $result.Keys | Should -Contain 'feature_spec_change'
        $result['feature_spec_change'].FeatureName | Should -Be '001-login'
    }

    It 'returns empty for unmatched paths' {
        $result = Get-ChangeTypesFromPaths -StagedPaths @('src/main.js') -Registry $mockRegistry
        $result.Keys.Count | Should -Be 0
    }

    It 'handles backslash-prefixed paths from git' {
        $result = Get-ChangeTypesFromPaths -StagedPaths @('.github\agents\speckit.readiness.agent.md') -Registry $mockRegistry
        $result.Keys | Should -Contain 'agent_change'
    }
}

Describe 'staged change parsing' {
    It 'parses delete and rename records from name-status -z output' {
        $raw = "D`0studio/templates/sdd-docs/spec-template.md`0R100`0README.md`0README-new.md`0"
        $result = ConvertFrom-GitNameStatusZ -Raw $raw

        $result.Count | Should -Be 2
        $result[0].Status | Should -Be 'D'
        $result[0].Path | Should -Be 'studio/templates/sdd-docs/spec-template.md'
        $result[1].Status | Should -Be 'R100'
        $result[1].OldPath | Should -Be 'README.md'
        $result[1].Path | Should -Be 'README-new.md'
    }

    It 'detects shared gate hits for staged delete and rename paths' {
        $raw = "D`0studio/templates/sdd-docs/spec-template.md`0R100`0studio/runtime/shared-runtime-contract.json`0studio/runtime/contract-renamed.json`0"
        $changes = ConvertFrom-GitNameStatusZ -Raw $raw
        $touched = Get-StagedTouchedPaths -Changes $changes

        @($touched | Where-Object {
            Test-IsSharedGateHit -Path $_ -GatePaths @(
                'studio/runtime/shared-runtime-contract.json',
                'studio/templates/sdd-docs/spec-template.md'
            )
        }).Count | Should -Be 2
    }
}

Describe 'agent bootstrap path helpers' {
    It 'treats root adapter files as workspace root bootstrap files' {
        Get-AgentBootstrapProjectRootForPath -Path 'AGENTS.md' | Should -Be $WorkspaceRoot
        Get-AgentBootstrapProjectRootForPath -Path 'CLAUDE.md' | Should -Be $WorkspaceRoot
        Get-AgentBootstrapProjectRootForPath -Path '.github/copilot-instructions.md' | Should -Be $WorkspaceRoot
    }

    It 'treats root project constitution as the current repository root' {
        Get-AgentBootstrapProjectRootForPath -Path '.specify/memory/constitution.md' | Should -Be $WorkspaceRoot
    }

    It 'resolves nested project adapter paths to their project root' {
        $expected = Join-Path $WorkspaceRoot 'projects/example'
        Get-AgentBootstrapProjectRootForPath -Path 'projects/example/AGENTS.md' | Should -Be $expected
        Get-AgentBootstrapProjectRootForPath -Path 'projects/example/CLAUDE.md' | Should -Be $expected
        Get-AgentBootstrapProjectRootForPath -Path 'projects/example/.github/copilot-instructions.md' | Should -Be $expected
    }

    It 'resolves project constitution path to its project root' {
        $expected = Join-Path $WorkspaceRoot 'projects/example'
        Get-AgentBootstrapProjectRootForPath -Path 'projects/example/.specify/memory/constitution.md' | Should -Be $expected
    }

    It 'detects adapter and project constitution paths' {
        Test-IsAgentAdapterPath -Path 'AGENTS.md' | Should -BeTrue
        Test-IsAgentAdapterPath -Path 'projects/example/.github/copilot-instructions.md' | Should -BeTrue
        Test-IsProjectConstitutionPath -Path 'projects/example/.specify/memory/constitution.md' | Should -BeTrue
        Test-IsAgentAdapterPath -Path '.github/agents/copilot-instructions.md' | Should -BeFalse
    }
}

Describe 'pre-commit integration gates' {
    BeforeAll {
        $script:preCommitScript = Join-Path $WorkspaceRoot '.githooks/pre-commit.ps1'
        $script:syncScript = Join-Path $WorkspaceRoot 'studio/scripts/powershell/sync-agent-bootstrap.ps1'
    }

    It 'fails when only part of the adapter set is staged' {
        $repo = Join-Path $TestDrive 'partial-adapters'
        New-Item -ItemType Directory -Path (Join-Path $repo '.specify/memory') -Force | Out-Null
        '# Project Constitution' | Set-Content -LiteralPath (Join-Path $repo '.specify/memory/constitution.md')
        git init -b main $repo | Out-Null

        pwsh -NoProfile -File $script:syncScript -ProjectRoot $repo -ProjectName fixture -ProjectType Internal -Write -Json | Out-Null
        git -C $repo add AGENTS.md CLAUDE.md | Out-Null

        Push-Location $repo
        try {
            $output = pwsh -NoProfile -File $script:preCommitScript 2>&1
            $exitCode = $LASTEXITCODE
        } finally {
            Pop-Location
        }
        $exitCode | Should -Not -Be 0
        ($output -join "`n") | Should -Match 'Runtime adapter must be staged with its synchronized set'
    }

    It 'fails when a staged plan has no staged readiness approval' {
        $repo = Join-Path $TestDrive 'plan-without-readiness'
        New-Item -ItemType Directory -Path (Join-Path $repo 'specs/001-fixture') -Force | Out-Null
        git init -b main $repo | Out-Null

        @"
# Plan: Fixture

## Architecture
Text
## Technology
Text
## Integration
Text
## Data Flow
Text
## Risks
Text
## Why Not
Text
## Estimated timeline
Text
**Version**: v1.0.0
"@ | Set-Content -LiteralPath (Join-Path $repo 'specs/001-fixture/plan.md')
        git -C $repo add specs/001-fixture/plan.md | Out-Null

        Push-Location $repo
        try {
            $output = pwsh -NoProfile -File $script:preCommitScript 2>&1
            $exitCode = $LASTEXITCODE
        } finally {
            Pop-Location
        }
        $exitCode | Should -Not -Be 0
        ($output -join "`n") | Should -Match 'without readiness-assessment\.md'
    }

    It 'fails when project constitution changes without staging the adapter set' {
        $repo = Join-Path $TestDrive 'constitution-without-adapters'
        New-Item -ItemType Directory -Path (Join-Path $repo '.specify/memory') -Force | Out-Null
        '# Project Constitution' | Set-Content -LiteralPath (Join-Path $repo '.specify/memory/constitution.md')
        git init -b main $repo | Out-Null

        pwsh -NoProfile -File $script:syncScript -ProjectRoot $repo -ProjectName fixture -ProjectType Internal -Write -Json | Out-Null
        git -C $repo add .specify/memory/constitution.md | Out-Null

        Push-Location $repo
        try {
            $output = pwsh -NoProfile -File $script:preCommitScript 2>&1
            $exitCode = $LASTEXITCODE
        } finally {
            Pop-Location
        }
        $exitCode | Should -Not -Be 0
        ($output -join "`n") | Should -Match 'Runtime adapter must be staged with its synchronized set'
    }
}

# ============================================================
# H1 regression: mainline-update note enforcement helpers
# ============================================================

Describe 'Get-NonNoteSharedLayerFiles (H1)' {
    It 'excludes docs/mainline-updates/* paths from shared-layer files' {
        $files = @(
            'studio/constitution/constitution.md',
            'docs/mainline-updates/2026-04-30-foo.md',
            'docs/mainline-updates/README.md',
            '.githooks/pre-commit.ps1'
        )
        $result = Get-NonNoteSharedLayerFiles -SharedLayerFiles $files
        $result | Should -Contain 'studio/constitution/constitution.md'
        $result | Should -Contain '.githooks/pre-commit.ps1'
        $result | Should -Not -Contain 'docs/mainline-updates/2026-04-30-foo.md'
        $result | Should -Not -Contain 'docs/mainline-updates/README.md'
    }

    It 'returns empty array for empty input' {
        $result = Get-NonNoteSharedLayerFiles -SharedLayerFiles @()
        $result.Count | Should -Be 0
    }

    It 'returns empty array when all files are mainline-updates entries' {
        $files = @('docs/mainline-updates/a.md', 'docs/mainline-updates/README.md')
        $result = Get-NonNoteSharedLayerFiles -SharedLayerFiles $files
        $result.Count | Should -Be 0
    }
}

Describe 'Get-StagedMainlineUpdateNotes (H1)' {
    It 'matches docs/mainline-updates/<date>-<topic>.md' {
        $files = @(
            'docs/mainline-updates/2026-04-30-critical-bug-cleanup.md',
            'docs/mainline-updates/README.md',
            'studio/constitution/constitution.md'
        )
        $result = Get-StagedMainlineUpdateNotes -StagedFiles $files
        $result | Should -Contain 'docs/mainline-updates/2026-04-30-critical-bug-cleanup.md'
        $result | Should -Not -Contain 'docs/mainline-updates/README.md'
        $result | Should -Not -Contain 'studio/constitution/constitution.md'
    }

    It 'rejects subdirectory paths (only flat <date>-<topic>.md files)' {
        $files = @('docs/mainline-updates/archive/old.md', 'docs/mainline-updates/2026-04-30-foo.md')
        $result = Get-StagedMainlineUpdateNotes -StagedFiles $files
        $result | Should -Not -Contain 'docs/mainline-updates/archive/old.md'
        $result | Should -Contain 'docs/mainline-updates/2026-04-30-foo.md'
    }

    It 'returns empty for no staged notes' {
        $result = Get-StagedMainlineUpdateNotes -StagedFiles @('README.md', 'src/main.js')
        $result.Count | Should -Be 0
    }
}

# ============================================================
# H4 regression: Invoke-SharedRuntimeAuditOnStagedSnapshot
# defensive marker presence check (inspection-based regression).
# Ensures future refactors do not silently remove the $auditConfirmed
# safety net that catches uncovered failure paths.
# ============================================================

Describe 'Invoke-SharedRuntimeAuditOnStagedSnapshot defensive marker (H4)' {
    BeforeAll {
        $script:hookContent = Get-Content -LiteralPath (Join-Path $WorkspaceRoot '.githooks/pre-commit.ps1') -Raw
    }

    It 'declares $auditConfirmed local marker' {
        $hookContent | Should -Match '\$auditConfirmed\s*=\s*\$false'
    }

    It 'sets $auditConfirmed = $true on the success path' {
        $hookContent | Should -Match 'Write-HookSuccess[^\r\n]*Shared runtime audit passed against staged snapshot[\s\S]*?\$auditConfirmed\s*=\s*\$true'
    }

    It 'has finally fallback that flags uncovered failure paths' {
        $hookContent | Should -Match 'if\s*\(\s*-not\s+\$auditConfirmed\s+-and\s+-not\s+\$script:hasErrors\s*\)'
    }
}

# ============================================================
# H3 e2e: Invoke-SharedRuntimeAuditOnStagedSnapshot end-to-end failure path.
# Mirrors a minimum subset of the workspace into TestDrive so the hook treats
# it as the workspace repo and runs check-speckit-runtime against the staged
# snapshot. Then breaks the contract on purpose and asserts the hook fails.
# ============================================================

Describe 'staged snapshot audit fails on broken contract (H3)' {
    BeforeAll {
        $script:fixtureRoot = Join-Path $TestDrive 'audit-failure-fixture'
        New-Item -ItemType Directory -Path $script:fixtureRoot -Force | Out-Null

        # Mirror minimum workspace structure required by check-speckit-runtime.
        $dirsToMirror = @('.githooks', '.github', '.claude', 'studio')
        foreach ($dir in $dirsToMirror) {
            $src = Join-Path $WorkspaceRoot $dir
            if (Test-Path -LiteralPath $src) {
                $dst = Join-Path $script:fixtureRoot $dir
                Copy-Item -Path $src -Destination $dst -Recurse -Force
            }
        }
        foreach ($file in @('AGENTS.md', 'CLAUDE.md', 'README.md', 'WORKSPACE_STRUCTURE.md')) {
            $src = Join-Path $WorkspaceRoot $file
            if (Test-Path -LiteralPath $src) {
                Copy-Item -Path $src -Destination (Join-Path $script:fixtureRoot $file) -Force
            }
        }

        git init -b main $script:fixtureRoot 2>&1 | Out-Null
        git -C $script:fixtureRoot config user.email 'test@example.com' | Out-Null
        git -C $script:fixtureRoot config user.name 'Test' | Out-Null
        git -C $script:fixtureRoot add -A 2>&1 | Out-Null
        git -C $script:fixtureRoot commit -m 'chore: baseline' --no-verify 2>&1 | Out-Null
    }

    It 'fails when staged contract introduces a missing required prompt stub' {
        # Stage a sharedGatePaths file (constitution) so the audit triggers.
        $constitutionPath = Join-Path $script:fixtureRoot 'studio/constitution/constitution.md'
        Add-Content -LiteralPath $constitutionPath -Value "`n<!-- harmless edit for H3 fixture -->"

        # Break the contract: add a requiredPromptStub for a file that does not exist.
        $contractPath = Join-Path $script:fixtureRoot 'studio/runtime/shared-runtime-contract.json'
        $contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json -AsHashtable
        $contract.requiredPromptStubs = @(@($contract.requiredPromptStubs) + 'speckit.does-not-exist.prompt.md')
        ($contract | ConvertTo-Json -Depth 100) | Set-Content -LiteralPath $contractPath -Encoding UTF8

        # Add a mainline-update note so H1 rule does not fire instead of audit.
        $notePath = Join-Path $script:fixtureRoot 'docs/mainline-updates/2099-01-01-h3-fixture.md'
        New-Item -ItemType Directory -Path (Split-Path $notePath) -Force | Out-Null
        Set-Content -LiteralPath $notePath -Value "# H3 fixture note`n`nFor staged-snapshot audit failure test." -Encoding UTF8

        git -C $script:fixtureRoot add studio/constitution/constitution.md studio/runtime/shared-runtime-contract.json docs/mainline-updates/2099-01-01-h3-fixture.md 2>&1 | Out-Null

        Push-Location $script:fixtureRoot
        try {
            $output = pwsh -NoProfile -File (Join-Path $script:fixtureRoot '.githooks/pre-commit.ps1') 2>&1
            $exitCode = $LASTEXITCODE
        } finally {
            Pop-Location
        }

        $exitCode | Should -Not -Be 0
        ($output -join "`n") | Should -Match 'Shared runtime audit failed against staged snapshot'
    }
}

Describe 'Get-ManifestPendingItems' {
    # Regression: M1 — Status regex \w+ could not match hyphenated values

    It 'parses simple status value' {
        $content = "**Status**: open`n"
        $result = Get-ManifestPendingItems -Content $content
        $result.Status | Should -Be 'open'
    }

    It 'parses hyphenated status value (M1 regression)' {
        $content = "**Status**: in-progress`n"
        $result = Get-ManifestPendingItems -Content $content
        $result.Status | Should -Be 'in-progress'
    }

    It 'returns unknown when no status found' {
        $content = "No status here"
        $result = Get-ManifestPendingItems -Content $content
        $result.Status | Should -Be 'unknown'
    }

    It 'extracts pending must_update items' {
        $content = Get-Content (Get-FixturePath 'sample-manifest.md') -Raw
        $result = Get-ManifestPendingItems -Content $content
        $result.Status | Should -Be 'in-progress'
        $result.PendingMustUpdate.Count | Should -Be 1
        $result.PendingMustReview.Count | Should -Be 1
    }
}

# ============================================================
# Tier 2: High-risk functions
# ============================================================

Describe 'Get-ReadinessValidationErrors' {
    It 'returns no errors for valid readiness-assessment.md' {
        $content = @"
# Readiness Assessment: Test Feature

**Date**: 2026-04-12
**Primary Status**: READY_FOR_PLAN
**Recommended Next Step**: /speckit.plan

## Summary

Feature is ready.

## Readiness Dimension Scan

All clear.

## Primary Blocker Analysis

No blockers.

## Allowed / Not Allowed Next Actions

### Allowed

- Proceed to plan

### Not Allowed

- Skip to implementation

## Planability vs Intent Obligations

All in scope.
"@
        $errors = Get-ReadinessValidationErrors -Path 'readiness-assessment.md' -Content $content
        $errors.Count | Should -Be 0
    }

    It 'detects missing sections in readiness-assessment.md' {
        $content = @"
# Readiness Assessment: Test

**Date**: 2026-04-12
**Primary Status**: READY_FOR_PLAN
**Recommended Next Step**: /speckit.plan

## Summary

Done.
"@
        $errors = Get-ReadinessValidationErrors -Path 'readiness-assessment.md' -Content $content
        $errors.Count | Should -BeGreaterThan 0
        $errors | Should -Contain 'Readiness Dimension Scan section'
    }

    It 'validates eci-trigger.md structure' {
        $content = @"
**Preliminary Recommendation**: ROUTE_TO_ECI

## Why This Blocks Planning

External dependency needed.

## Return Condition

When ECI clears.
"@
        $errors = Get-ReadinessValidationErrors -Path 'eci-trigger.md' -Content $content
        $errors.Count | Should -Be 0
    }

    It 'returns empty for unknown file types' {
        $errors = Get-ReadinessValidationErrors -Path 'unknown-file.md' -Content 'anything'
        $errors.Count | Should -Be 0
    }
}
