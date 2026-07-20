#!/usr/bin/env pwsh
#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/governance.config.ps1"

    $script:constitutionPath = Join-Path $WorkspaceRoot 'studio/constitution/constitution.md'
    $script:contractPath = Join-Path $WorkspaceRoot 'studio/runtime/shared-runtime-contract.json'
    $script:registryPath = Join-Path $WorkspaceRoot 'studio/runtime/impact-registry.json'
    $script:generatorPath = Join-Path $WorkspaceRoot 'studio/scripts/powershell/generate-impact-registry.ps1'

    $script:constitution = Get-Content $constitutionPath -Raw
    $script:contract = Get-Content $contractPath -Raw | ConvertFrom-Json -AsHashtable
    $script:registry = Get-Content $registryPath -Raw | ConvertFrom-Json -AsHashtable
}

# ============================================================
# Tier 3: Cross-validation
# ============================================================

Describe 'requiredPromptStubs completeness' {
    It 'every requiredCommand has a matching prompt stub entry' {
        $commands = $contract.requiredCommands
        $stubs = $contract.requiredPromptStubs | ForEach-Object { $_ -replace '\.prompt\.md$', '' }

        foreach ($cmd in $commands) {
            $stubs | Should -Contain $cmd -Because "command '$cmd' needs a prompt stub"
        }
    }

    It 'every prompt stub file exists on disk' {
        $promptsDir = Join-Path $WorkspaceRoot '.github/prompts'
        foreach ($stub in $contract.requiredPromptStubs) {
            $path = Join-Path $promptsDir $stub
            $path | Should -Exist -Because "prompt stub '$stub' is required by contract"
        }
    }
}

Describe 'requiredClaudeAgents completeness' {
    It 'every required Claude agent file exists on disk' {
        $agentsDir = Join-Path $WorkspaceRoot '.claude/agents'
        foreach ($agent in $contract.requiredClaudeAgents) {
            $path = Join-Path $agentsDir $agent
            $path | Should -Exist -Because "Claude agent '$agent' is required by contract"
        }
    }
}

Describe 'required non-command GitHub agent files completeness' {
    It 'declares the three governed non-command files explicitly' {
        $contract.ContainsKey('requiredNonCommandGitHubAgentFiles') | Should -BeTrue
        $expected = @(
            'async-python-reviewer.md',
            'copilot-instructions.md',
            'spec-kit.agent.md'
        ) | Sort-Object
        $actual = @($contract.requiredNonCommandGitHubAgentFiles | ForEach-Object { [string]$_ } | Sort-Object -Unique)

        ($actual -join "`n") | Should -Be ($expected -join "`n")
    }

    It 'every declared non-command GitHub agent file exists on disk' {
        $agentsDir = Join-Path $WorkspaceRoot '.github/agents'
        foreach ($agent in @($contract.requiredNonCommandGitHubAgentFiles)) {
            Join-Path $agentsDir ([string]$agent) | Should -Exist -Because "non-command GitHub agent file '$agent' is required by contract"
        }
    }
}

Describe 'documentAuthority consistency' {
    It 'registry does not contain removed sdd-agents template mirror entry' {
        $entry = $registry.documentAuthority | Where-Object { $_.path -eq 'studio/templates/sdd-agents/*.md' }
        $entry | Should -BeNullOrEmpty -Because 'sdd-agents template mirror layer has been removed'
    }

    It 'registry claude agents authority is dependent' {
        $entry = $registry.documentAuthority | Where-Object { $_.path -eq '.claude/agents/*.md' }
        $entry | Should -Not -BeNullOrEmpty
        $entry.authority | Should -Be 'dependent' -Because 'constitution Section 12 classifies Claude agents as dependent (seeded)'
    }
}

Describe 'constitution heading level consistency' {
    It 'all X.Y subsections use the same heading level' {
        $headings = [regex]::Matches($constitution, '(?m)^(#{2,6})\s+\d+\.\d+')
        $levels = @($headings | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
        $levels.Count | Should -Be 1 -Because "all X.Y subsections should use the same heading level (found: $($levels -join ', '))"
    }
}

Describe 'constitution phase accuracy' {
    It 'Current Phase date is within last quarter (4 months grace period)' {
        $constitution | Should -Match 'Current Phase.*\(as of (\d{4}-\d{2})\)'
        $dateMatch = [regex]::Match($constitution, 'as of (\d{4}-\d{2})')
        $phaseDate = [datetime]::ParseExact($dateMatch.Groups[1].Value, 'yyyy-MM', $null)
        $monthsAgo = ((Get-Date) - $phaseDate).TotalDays / 30
        # 4 months threshold = "at least quarterly review" with one month grace.
        # When this fails: review the Current Phase declaration in studio/constitution/constitution.md §1.1
        # and bump the "(as of YYYY-MM)" stamp once project mix has been reassessed.
        $monthsAgo | Should -BeLessThan 4 -Because 'phase declaration should be reviewed at least quarterly (run a phase reassessment and update the as-of stamp)'
    }
}

Describe 'canonical workspace governance self-application route' {
    BeforeAll {
        $script:selfApplicationMatches = [regex]::Matches(
            $constitution,
            '(?ms)^## 2\.1 Canonical Workspace Governance Self-Application\s*$.*?(?=^## \d)'
        )
        $script:selfApplicationSection = if ($selfApplicationMatches.Count -eq 1) {
            $selfApplicationMatches[0].Value
        } else {
            ''
        }
    }

    It 'defines exactly one section-bounded evidence-equivalent route' {
        $selfApplicationMatches.Count | Should -Be 1
        $selfApplicationSection | Should -Match 'evidence-equivalent self-application'
        $selfApplicationSection | Should -Match 'not a stage waiver'
    }

    It 'binds the route to the contract-designated canonical repository and shared-only scope' {
        $selfApplicationSection | Should -Match 'mainlineReadiness\.repositorySlug'
        $selfApplicationSection | Should -Match 'limited to shared-layer governance'
        $selfApplicationSection | Should -Match 'does not deliver behavior for a consumer project'
    }

    It 'keeps projects learning external repositories and ordinary features on seven stages' {
        $selfApplicationSection | Should -Match 'Work under `projects/`,'
        $selfApplicationSection | Should -Match '`learning/`, any external repository, and\s+ordinary feature delivery'
        $selfApplicationSection | Should -Match 'always remains subject to the\s+seven-stage sequence'
        $selfApplicationSection | Should -Match 'MUST NOT be treated as\s+permission'
    }

    It 'requires owner scope discriminating evidence machine gates and closed Batch accounting' {
        $selfApplicationSection | Should -Match 'dated, owner-authorized remediation plan'
        $selfApplicationSection | Should -Match 'ledger IDs before\s+implementation'
        $selfApplicationSection | Should -Match 'discriminating negative test that fails against the pre-batch implementation'
        $selfApplicationSection | Should -Match 'canonical shared-runtime audit reports zero errors and zero warnings'
        $selfApplicationSection | Should -Match 'complete governance\s+suite passes without reducing the baseline'
        $selfApplicationSection | Should -Match 'dedicated mainline update note is `Ready`'
        $selfApplicationSection | Should -Match 'has `Reconciliation Status: Closed`'
    }

    It 'separates pre-implementation entry from post-implementation closure' {
        $selfApplicationSection | Should -Match 'every entry prerequisite\s+below is satisfied before implementation'
        $selfApplicationSection | Should -Match 'After entry, the batch MUST remain `Draft` and `NOT READY`'
        $selfApplicationSection | Should -Match 'every closure prerequisite'
        $selfApplicationSection | Should -Match 'If any entry prerequisite is missing, the work MUST use the seven mandatory stages'
        $selfApplicationSection | Should -Match 'If any closure\s+prerequisite is missing after valid entry, the batch MUST remain `Draft` and `NOT READY`'
    }

    It 'prevents Batch evidence from replacing Aggregate promotion or fresh-fixture obligations' {
        $selfApplicationSection | Should -Match 'proves only the coherent batch'
        $selfApplicationSection | Should -Match 'MUST NOT make the branch merge-ready'
        $selfApplicationSection | Should -Match 'replace a contract-designated aggregate note'
        $selfApplicationSection | Should -Match 'fresh-fixture seven-stage evidence'
    }

    It 'keeps the constitution version and newest changelog row aligned at 1.9.0' {
        $constitution | Should -Match '(?m)^\*\*Version:\*\* 1\.9\.0$'
        $changelogRows = @(
            [regex]::Matches($constitution, '(?m)^\| (1\.\d+\.\d+) \| \d{4}-\d{2}-\d{2} \|') |
                ForEach-Object { $_.Groups[1].Value }
        )
        $changelogRows.Count | Should -BeGreaterThan 0
        $changelogRows[0] | Should -Be '1.9.0'
    }

    It 'propagates the scoped route and 1.9.0 version through root adapters and templates' {
        $paths = @(
            'AGENTS.md',
            'CLAUDE.md',
            '.github/copilot-instructions.md',
            'studio/templates/sdd-docs/agents-md-template.md',
            'studio/templates/sdd-docs/claude-md-template.md',
            'studio/templates/sdd-docs/copilot-instructions-template.md'
        )
        foreach ($relativePath in $paths) {
            $content = Get-Content -LiteralPath (Join-Path $WorkspaceRoot $relativePath) -Raw
            $content | Should -Match 'Project and consumer-feature delivery follows: specify, clarify, readiness, plan, tasks, analyze, implement\.'
            $content | Should -Match 'canonical workspace governance repository may enter Constitution Section 2\.1 only after every entry prerequisite is proven and must remain Draft until every closure prerequisite is proven\.'
            if ($relativePath -notmatch 'template\.md$') {
                $content | Should -Match '\*\*Studio Constitution Version:\*\* 1\.9\.0'
            }
        }
    }

    It 'scopes implementation AI and project-structure duties without weakening either route' {
        $constitution | Should -Match '(?m)^During project or consumer-feature implementation:$'
        $constitution | Should -Match 'During a valid Section 2\.1 self-application batch, work MUST stay within the owner-authorized\s+remediation plan, declared ledger IDs, and shared-only scope\.'
        $constitution | Should -Match 'For project and consumer-feature delivery, AI MUST follow spec/readiness/eci/plan/tasks'
        $constitution | Should -Match 'For a Section 2\.1 batch, AI MUST follow the owner-authorized remediation plan, ledger IDs, and\s+declared shared-only scope'
        $constitution | Should -Match 'Each project and consumer-feature delivery surface MUST contain the following base paths\.'
        $constitution | Should -Match 'canonical workspace governance root using Section 2\.1 is\s+not a project or consumer-feature delivery surface'
    }
}

Describe 'requiredMirrorPairs removed' {
    It 'contract no longer contains requiredMirrorPairs' {
        $contract.ContainsKey('requiredMirrorPairs') | Should -BeFalse -Because 'sdd-agents template mirror layer has been removed'
    }
}

# ============================================================
# H11: requiredCommands layering — mandatoryStageCommands + auxiliaryCommands
# ============================================================

Describe 'requiredCommands layering (H11)' {
    It 'contract has mandatoryStageCommands key' {
        $contract.ContainsKey('mandatoryStageCommands') | Should -BeTrue
    }

    It 'contract has auxiliaryCommands key' {
        $contract.ContainsKey('auxiliaryCommands') | Should -BeTrue
    }

    It 'mandatoryStageCommands lists exactly the seven SDD stages' {
        $expected = @(
            'speckit.specify', 'speckit.clarify', 'speckit.readiness',
            'speckit.plan', 'speckit.tasks', 'speckit.analyze', 'speckit.implement'
        )
        $actual = @($contract.mandatoryStageCommands | Sort-Object)
        ($expected | Sort-Object) | ForEach-Object { $actual | Should -Contain $_ }
        $actual.Count | Should -Be 7
    }

    It 'mandatoryStageCommands and auxiliaryCommands are disjoint' {
        $intersect = @($contract.mandatoryStageCommands | Where-Object { $_ -in $contract.auxiliaryCommands })
        $intersect.Count | Should -Be 0
    }

    It 'requiredCommands equals union of mandatory and auxiliary' {
        $union = @($contract.mandatoryStageCommands + $contract.auxiliaryCommands | Sort-Object -Unique)
        $required = @($contract.requiredCommands | Sort-Object -Unique)
        ($union -join ',') | Should -Be ($required -join ',')
    }
}
