#!/usr/bin/env pwsh
#Requires -Module Pester

# Regression tests for the Wave-3 path-boundary hardening
# (mirrors upstream github/spec-kit v0.3.0 #1809 + v0.7.5 #2229/#2296).
# Uses the existing common.ps1 helpers Test-PathInsideRoot / Assert-PathInsideRoot.

BeforeAll {
    . "$PSScriptRoot/governance.config.ps1"

    $script:scripts = @{
        SetupClarify   = Join-Path $WorkspaceRoot 'studio/scripts/powershell/setup-clarify.ps1'
        SetupReadiness = Join-Path $WorkspaceRoot 'studio/scripts/powershell/setup-readiness.ps1'
        SetupEci       = Join-Path $WorkspaceRoot 'studio/scripts/powershell/setup-eci.ps1'
        SetupTasks     = Join-Path $WorkspaceRoot 'studio/scripts/powershell/setup-tasks.ps1'
        SetupAnalyze   = Join-Path $WorkspaceRoot 'studio/scripts/powershell/setup-analyze.ps1'
        SetupImplement = Join-Path $WorkspaceRoot 'studio/scripts/powershell/setup-implement.ps1'
        SetupPlan      = Join-Path $WorkspaceRoot 'studio/scripts/powershell/setup-plan.ps1'
        CheckPrereqs   = Join-Path $WorkspaceRoot 'studio/scripts/powershell/check-prerequisites.ps1'
        ValidateFeature = Join-Path $WorkspaceRoot 'studio/scripts/powershell/validate-feature-structure.ps1'
        SyncBootstrap  = Join-Path $WorkspaceRoot 'studio/scripts/powershell/sync-agent-bootstrap.ps1'
        UpdateAgentCtx = Join-Path $WorkspaceRoot 'studio/scripts/powershell/update-agent-context.ps1'
        CreateFeature  = Join-Path $WorkspaceRoot 'studio/scripts/powershell/create-new-feature.ps1'
    }

    $script:commonScript = Join-Path $WorkspaceRoot 'studio/scripts/powershell/common.ps1'

    function script:New-BoundFeatureFixture {
        param(
            [Parameter(Mandatory = $true)][string]$ProjectRoot,
            [string]$Name = '001-bound-feature'
        )

        $featureDir = Join-Path $ProjectRoot "specs/$Name"
        $readinessDir = Join-Path $featureDir 'readiness'
        New-Item -ItemType Directory -Path (Join-Path $readinessDir 'eci') -Force | Out-Null
        @"
# Feature Specification: Bound fixture

**Feature ID**: ``$Name``
**Version**: 1.0.0
"@ | Set-Content -LiteralPath (Join-Path $featureDir 'spec.md') -Encoding utf8
        @"
# Implementation Plan: Bound fixture

**Feature ID**: ``$Name``
**Version**: 1.0.0
**Language/Version**: R6-A2-Language
**Primary Dependencies**: R6-A2-Framework
**Storage**: N/A
**Project Type**: single
"@ | Set-Content -LiteralPath (Join-Path $featureDir 'plan.md') -Encoding utf8
        @"
# Tasks: Bound fixture

**Feature ID**: ``$Name``
**Version**: 1.0.0

- [ ] T001 [P1] [Risk: Low] [Story: Binding] Preserve the explicit feature identity
"@ | Set-Content -LiteralPath (Join-Path $featureDir 'tasks.md') -Encoding utf8
        @"
# Readiness Assessment: Bound fixture

**Date**: 2026-07-22
**Primary Status**: ``READY_FOR_PLAN``
**ECI Re-entry Status**: ``NOT_REQUIRED``
**ECI Evidence SHA-256**: ``N/A``

## Planability vs Intent Obligations

- **Intent Ledger Requirement**: Not Required
"@ | Set-Content -LiteralPath (Join-Path $readinessDir 'readiness-assessment.md') -Encoding utf8

        return $featureDir
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

    It 'setup-plan.ps1 rejects -FeatureDir outside configured project specs' {
        $oldProjectRoot = $env:SDD_PROJECT_ROOT
        $projectRoot = Join-Path $TestDrive 'configured-project'
        New-Item -ItemType Directory -Path (Join-Path $projectRoot 'specs') -Force | Out-Null
        $env:SDD_PROJECT_ROOT = $projectRoot
        try {
            $output = pwsh -NoProfile -File $script:scripts.SetupPlan -FeatureDir $script:outside -Json 2>&1
            $LASTEXITCODE | Should -Not -Be 0
            ($output -join "`n") | Should -Match 'escapes project root'
        } finally {
            $env:SDD_PROJECT_ROOT = $oldProjectRoot
        }
    }

    It 'check-prerequisites.ps1 rejects -FeatureDir outside configured project specs' {
        $oldProjectRoot = $env:SDD_PROJECT_ROOT
        $projectRoot = Join-Path $TestDrive 'configured-prereq-project'
        New-Item -ItemType Directory -Path (Join-Path $projectRoot 'specs') -Force | Out-Null
        $env:SDD_PROJECT_ROOT = $projectRoot
        try {
            $output = pwsh -NoProfile -File $script:scripts.CheckPrereqs -FeatureDir $script:outside -Json -PathsOnly 2>&1
            $LASTEXITCODE | Should -Not -Be 0
            ($output -join "`n") | Should -Match 'escapes project root'
        } finally {
            $env:SDD_PROJECT_ROOT = $oldProjectRoot
        }
    }
}

Describe 'repository-bound feature context resolver' {
    BeforeAll {
        . $script:commonScript
    }

    BeforeEach {
        $script:oldProjectRoot = $env:SDD_PROJECT_ROOT
        $script:oldStudioRoot = $env:SDD_STUDIO_ROOT
        $script:oldFeature = $env:SPECIFY_FEATURE
        $script:projectRoot = Join-Path $TestDrive 'configured-project'
        $script:localFeature = New-BoundFeatureFixture -ProjectRoot $script:projectRoot -Name '001-local'
        $script:foreignRoot = Join-Path $TestDrive 'foreign-project'
        $script:foreignFeature = New-BoundFeatureFixture -ProjectRoot $script:foreignRoot -Name '002-foreign'
        $script:nearPrefixRoot = "$($script:projectRoot)-near-prefix"
        $script:nearPrefixFeature = New-BoundFeatureFixture -ProjectRoot $script:nearPrefixRoot -Name '003-near-prefix'
        $script:siblingSpecsFeature = Join-Path $script:projectRoot 'sibling/specs/004-sibling'
        New-Item -ItemType Directory -Path $script:siblingSpecsFeature -Force | Out-Null
        $env:SDD_PROJECT_ROOT = $script:projectRoot
        $env:SDD_STUDIO_ROOT = Join-Path $WorkspaceRoot 'studio'
        $env:SPECIFY_FEATURE = '999-rebound'
    }

    AfterEach {
        $env:SDD_PROJECT_ROOT = $script:oldProjectRoot
        $env:SDD_STUDIO_ROOT = $script:oldStudioRoot
        $env:SPECIFY_FEATURE = $script:oldFeature
    }

    It 'accepts a repository-owned absolute direct child despite branch or environment rebinding' {
        $result = Resolve-FeatureContext -FeatureDir $script:localFeature

        $result.REPO_ROOT | Should -Be ([System.IO.Path]::GetFullPath($script:projectRoot))
        $result.FEATURE_ID | Should -Be '001-local'
        $result.FEATURE_DIR | Should -Be ([System.IO.Path]::GetFullPath($script:localFeature))
        $result.CURRENT_BRANCH | Should -Be '999-rebound'
    }

    It 'resolves a normalized relative path from the configured repository root and not caller cwd' {
        $otherCwd = Join-Path $TestDrive 'other-cwd'
        New-Item -ItemType Directory -Path $otherCwd -Force | Out-Null
        Push-Location $otherCwd
        try {
            $result = Resolve-FeatureContext -FeatureDir 'specs/unused/../001-local'
        } finally {
            Pop-Location
        }

        $result.FEATURE_DIR | Should -Be ([System.IO.Path]::GetFullPath($script:localFeature))
    }

    It 'rejects <Kind> after normalization' -ForEach @(
        @{ Kind = 'a foreign repository'; Candidate = { $script:foreignFeature } }
        @{ Kind = 'a near-prefix repository'; Candidate = { $script:nearPrefixFeature } }
        @{ Kind = 'a same-repository sibling specs directory'; Candidate = { $script:siblingSpecsFeature } }
        @{ Kind = 'a nested feature directory'; Candidate = { Join-Path $script:localFeature 'nested' } }
        @{ Kind = 'relative traversal outside specs'; Candidate = { 'specs/001-local/../../../foreign-project/specs/002-foreign' } }
        @{ Kind = 'backslash traversal outside specs'; Candidate = { 'specs\001-local\..\..\..\foreign-project\specs\002-foreign' } }
    ) {
        $candidatePath = & $Candidate

        { Resolve-FeatureContext -FeatureDir $candidatePath } |
            Should -Throw '*FEATURE_DIR escapes project root*'
    }

    It 'rejects a foreign direct specs child across every feature-bound script entrypoint' {
        $cases = @(
            @{ Script = $script:scripts.SetupClarify; Args = @('-Json') }
            @{ Script = $script:scripts.SetupReadiness; Args = @('-Json') }
            @{ Script = $script:scripts.SetupEci; Args = @('-Json') }
            @{ Script = $script:scripts.SetupPlan; Args = @('-Json') }
            @{ Script = $script:scripts.SetupTasks; Args = @('-Json') }
            @{ Script = $script:scripts.SetupAnalyze; Args = @('-Json') }
            @{ Script = $script:scripts.SetupImplement; Args = @('-Json') }
            @{ Script = $script:scripts.CheckPrereqs; Args = @('-Json', '-PathsOnly') }
            @{ Script = $script:scripts.ValidateFeature; Args = @('-Json') }
            @{ Script = $script:scripts.UpdateAgentCtx; Args = @('-AgentType', 'claude') }
        )

        foreach ($case in $cases) {
            $output = pwsh -NoProfile -File $case.Script -FeatureDir $script:foreignFeature @($case.Args) 2>&1
            $LASTEXITCODE | Should -Not -Be 0 -Because $case.Script
            ($output -join "`n") | Should -Match 'FEATURE_DIR escapes project root' -Because $case.Script
        }
    }

    It 'returns parseable fail-closed JSON for a foreign feature structure request' {
        $output = pwsh -NoProfile -File $script:scripts.ValidateFeature `
            -FeatureDir $script:foreignFeature -Json 2>&1

        $LASTEXITCODE | Should -Not -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        $result.VALID | Should -BeFalse
        @($result.ERRORS.id) | Should -Contain 'feature-context-invalid'
    }

    It 'binds omitted FeatureDir discovery to the configured root instead of another cwd repository' {
        $cwdRepo = Join-Path $TestDrive 'caller-repository'
        New-Item -ItemType Directory -Path $cwdRepo -Force | Out-Null
        git -C $cwdRepo init --initial-branch=777-wrong 2>&1 | Out-Null
        $LASTEXITCODE | Should -Be 0
        git -C $cwdRepo config user.name 'R6 A2 Fixture'
        git -C $cwdRepo config user.email 'r6-a2-fixture@example.invalid'
        'fixture' | Set-Content -LiteralPath (Join-Path $cwdRepo 'fixture.txt') -Encoding utf8
        git -C $cwdRepo add fixture.txt
        git -C $cwdRepo commit -m 'fixture' 2>&1 | Out-Null
        $LASTEXITCODE | Should -Be 0
        $env:SPECIFY_FEATURE = $null

        Push-Location $cwdRepo
        try {
            $result = Resolve-FeatureContext
        } finally {
            Pop-Location
        }

        $result.REPO_ROOT | Should -Be ([System.IO.Path]::GetFullPath($script:projectRoot))
        $result.FEATURE_ID | Should -Be '001-local'
        $result.CURRENT_BRANCH | Should -Be '001-local'
        $result.HAS_GIT | Should -BeFalse
    }

    It 'rejects a specs reparse escape before non-git branch fallback can enumerate it' {
        $linkedProject = Join-Path $TestDrive 'linked-specs-project'
        New-Item -ItemType Directory -Path $linkedProject -Force | Out-Null
        $linkedSpecs = Join-Path $linkedProject 'specs'
        $linkType = if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }
        New-Item -ItemType $linkType -Path $linkedSpecs `
            -Target (Join-Path $script:foreignRoot 'specs') | Out-Null
        $env:SDD_PROJECT_ROOT = $linkedProject
        $env:SPECIFY_FEATURE = $null
        Mock Get-ChildItem { throw 'specs enumerated before physical boundary' }

        { Resolve-FeatureContext } |
            Should -Throw '*reparse point*'
        Should -Invoke Get-ChildItem -Times 0 -Exactly
    }

    It 'rejects an existing feature reparse point whose target is outside repository specs' {
        $linkedFeature = Join-Path $script:projectRoot 'specs/005-linked'
        $linkType = if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }
        New-Item -ItemType $linkType -Path $linkedFeature -Target $script:foreignFeature | Out-Null

        { Resolve-FeatureContext -FeatureDir $linkedFeature } |
            Should -Throw '*reparse point*'
    }

    It 'rejects a selected feature reparse alias even when its target remains inside specs' {
        $linkedFeature = Join-Path $script:projectRoot 'specs/006-linked-alias'
        $linkType = if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }
        New-Item -ItemType $linkType -Path $linkedFeature -Target $script:localFeature | Out-Null

        { Resolve-FeatureContext -FeatureDir $linkedFeature } |
            Should -Throw '*reparse point*'
    }

    It 'rejects a descendant reparse point before feature artifact access' {
        $descendantFeature = New-BoundFeatureFixture -ProjectRoot $script:projectRoot -Name '007-descendant-link'
        $readinessPath = Join-Path $descendantFeature 'readiness'
        Remove-Item -LiteralPath $readinessPath -Recurse -Force
        $linkType = if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }
        New-Item -ItemType $linkType -Path $readinessPath `
            -Target (Join-Path $script:foreignFeature 'readiness') | Out-Null

        { Resolve-FeatureContext -FeatureDir $descendantFeature } |
            Should -Throw '*reparse point*'
    }

    It 'does not let -Force bypass repository binding' {
        $output = pwsh -NoProfile -File $script:scripts.SetupClarify `
            -FeatureDir $script:foreignFeature -Force -Json 2>&1

        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match 'FEATURE_DIR escapes project root'
    }

    It 'binds update-agent-context to the explicit feature instead of SPECIFY_FEATURE' {
        $reboundFeature = New-BoundFeatureFixture -ProjectRoot $script:projectRoot -Name '999-rebound'
        (Get-Content -LiteralPath (Join-Path $reboundFeature 'plan.md') -Raw).
            Replace('R6-A2-Language', 'WRONG-REBIND-LANGUAGE') |
            Set-Content -LiteralPath (Join-Path $reboundFeature 'plan.md') -Encoding utf8

        $output = pwsh -NoProfile -File $script:scripts.UpdateAgentCtx `
            -FeatureDir $script:localFeature -AgentType claude 2>&1

        $LASTEXITCODE | Should -Be 0
        ($output -join "`n") | Should -Match 'Found language: R6-A2-Language'
        ($output -join "`n") | Should -Not -Match 'WRONG-REBIND-LANGUAGE'
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
        ($output -join "`n") | Should -Match 'escapes project root'
    }

    It 'update-agent-context.ps1 rejects SPECIFY_FEATURE that escapes REPO_ROOT' {
        $env:SPECIFY_FEATURE = '../../etc'
        $output = pwsh -NoProfile -File $script:scripts.UpdateAgentCtx 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match 'escapes project root'
    }
}

Describe 'canonical feature-bound action recommendations' {
    It 'retains the resolved FeatureDir in every actionable same-feature command' {
        $required = @{
            'speckit.clarify.agent.md' = '/speckit.clarify -FeatureDir "<FEATURE_DIR>"` again later'
            'speckit.readiness.agent.md' = '/speckit.clarify -FeatureDir "<FEATURE_DIR>"` first'
            'speckit.eci.agent.md' = 'setup-eci.ps1 -FeatureDir "<path>" -Json` entry gate described above as the first action'
            'speckit.plan.agent.md' = 'Create a checklist for the following domain with -FeatureDir <FEATURE_DIR>.'
            'speckit.analyze.agent.md' = 'rerun `/speckit.analyze -FeatureDir "<FEATURE_DIR>"`'
        }

        foreach ($entry in $required.GetEnumerator()) {
            $path = Join-Path $WorkspaceRoot ".github/agents/$($entry.Key)"
            (Get-Content -LiteralPath $path -Raw) |
                Should -Match ([regex]::Escape($entry.Value)) -Because $entry.Key
        }
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
