#!/usr/bin/env pwsh
#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/governance.config.ps1"
    . (Get-ScriptFunctionsBlock -ScriptPath (Join-Path $WorkspaceRoot '.githooks/pre-commit.ps1'))
    $script:workspaceRoot = $WorkspaceRoot
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
