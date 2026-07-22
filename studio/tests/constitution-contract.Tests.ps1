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

Describe 'agent authority partition contract' {
    It 'binds fourteen pattern inputs plus async and excludes the dependent adapter' {
        $partition = $contract.agentAuthorityPartition

        ($partition.canonicalAgentPattern -is [string]) | Should -BeTrue
        $partition.canonicalAgentPattern | Should -BeExactly '.github/agents/*.agent.md'
        $partition.expectedPatternInputCount | Should -BeOfType ([long])
        $partition.expectedPatternInputCount | Should -Be 14
        ($partition.canonicalAdditionalFiles -is [array]) | Should -BeTrue
        @($partition.canonicalAdditionalFiles | Where-Object { $_ -isnot [string] }).Count | Should -Be 0
        @($partition.canonicalAdditionalFiles) | Should -Be @('.github/agents/async-python-reviewer.md')
        ($partition.dependentExcludedFiles -is [array]) | Should -BeTrue
        @($partition.dependentExcludedFiles | Where-Object { $_ -isnot [string] }).Count | Should -Be 0
        @($partition.dependentExcludedFiles) | Should -Be @('.github/agents/copilot-instructions.md')
        ($partition.dependentMirrorPattern -is [string]) | Should -BeTrue
        $partition.dependentMirrorPattern | Should -BeExactly '.claude/agents/*.md'
        $partition.expectedCanonicalInputCount | Should -Be 15
        $partition.expectedDependentMirrorCount | Should -Be 15

        @(Get-ChildItem -LiteralPath (Join-Path $WorkspaceRoot '.github/agents') -File -Filter '*.agent.md').Count |
            Should -Be 14
        @(Get-ChildItem -LiteralPath (Join-Path $WorkspaceRoot '.claude/agents') -File -Filter '*.md').Count |
            Should -Be 15
    }

    It 'keeps the same exact partition in the generated registry' {
        $entries = @($registry.documentAuthority)
        ($entries | Where-Object path -EQ '.github/agents/*.agent.md').authority | Should -BeExactly 'source_of_truth'
        ($entries | Where-Object path -EQ '.github/agents/async-python-reviewer.md').authority | Should -BeExactly 'source_of_truth'
        ($entries | Where-Object path -EQ '.github/agents/copilot-instructions.md').authority | Should -BeExactly 'dependent'
        ($entries | Where-Object path -EQ '.claude/agents/*.md').authority | Should -BeExactly 'dependent'

        $route = @($registry.impactRouting | Where-Object changeType -EQ 'agent_change')
        $route.Count | Should -Be 1
        $route[0].trigger | Should -BeExactly '.github/agents/*.agent.md|.github/agents/async-python-reviewer.md'
    }
}

Describe 'artifact-scoped Markdown formatting policy' {
    It 'declares the repaired R-G04 strategy as strict without absorbing unrelated history' {
        $expected = @(
            'studio/constitution/constitution.md',
            'AGENTS.md',
            'CLAUDE.md',
            '.github/copilot-instructions.md',
            '.github/agents/copilot-instructions.md',
            'specs/**/*.md',
            'studio/templates/sdd-docs/**/*.md',
            'docs/README.md',
            'docs/project-governance-status.md',
            'docs/project-worktree-parity-governance.md',
            'docs/yuanxi_sdd_pack_strategy_zhTW.md',
            'docs/sdd-workspace-*.md',
            'docs/mainline-updates/*.md',
            'studio/workflows/POLICY.md',
            'studio/extensions/POLICY.md',
            'WORKSPACE_STRUCTURE.md'
        )

        $contract.artifactMarkdownPolicy.schemaVersion | Should -BeOfType ([long])
        $contract.artifactMarkdownPolicy.schemaVersion | Should -Be 1
        ($contract.artifactMarkdownPolicy.defaultClassification -is [string]) | Should -BeTrue
        $contract.artifactMarkdownPolicy.defaultClassification | Should -BeExactly 'out_of_scope'
        ($contract.artifactMarkdownPolicy.strictPathPatterns -is [array]) | Should -BeTrue
        @($contract.artifactMarkdownPolicy.strictPathPatterns | Where-Object { $_ -isnot [string] }).Count | Should -Be 0
        (@($contract.artifactMarkdownPolicy.strictPathPatterns) -join "`n") |
            Should -BeExactly ($expected -join "`n")
        @($contract.artifactMarkdownPolicy.strictPathPatterns) |
            Should -Not -Contain 'docs/**'
        @($contract.artifactMarkdownPolicy.strictPathPatterns) |
            Should -Contain 'docs/yuanxi_sdd_pack_strategy_zhTW.md'
    }

    It 'bounds semantic exceptions to declared agents prompts and mirrors while keeping the adapter strict' {
        $exceptions = $contract.artifactMarkdownPolicy.semanticExceptionSources

        @($exceptions.Keys | Sort-Object) | Should -Be @(
            'agentPartitionRef',
            'claudeMirrorFilesRef',
            'claudeMirrorPartitionRef',
            'claudeMirrorRoot',
            'promptFilesRef',
            'promptRoot'
        )
        @($exceptions.Values | Where-Object { $_ -isnot [string] }).Count | Should -Be 0
        $exceptions.agentPartitionRef | Should -BeExactly 'agentAuthorityPartition'
        $exceptions.promptRoot | Should -BeExactly '.github/prompts'
        $exceptions.promptFilesRef | Should -BeExactly 'requiredPromptStubs'
        $exceptions.claudeMirrorPartitionRef | Should -BeExactly 'agentAuthorityPartition'
        $exceptions.claudeMirrorRoot | Should -BeExactly '.claude/agents'
        $exceptions.claudeMirrorFilesRef | Should -BeExactly 'requiredClaudeAgents'
        @($contract.artifactMarkdownPolicy.strictlyExcludedFromException) |
            Should -Be @('.github/agents/copilot-instructions.md')
        @($contract.artifactMarkdownPolicy.semanticSymbolAllowlist).Count | Should -Be 7
        @($contract.artifactMarkdownPolicy.legacyNonGrowthAllowances).Count | Should -Be 2
        $contract.artifactMarkdownPolicy.limits.maxAllowedSymbolOccurrencesPerFile | Should -BeOfType ([long])
        $contract.artifactMarkdownPolicy.limits.maxAllowedSymbolOccurrencesPerFile | Should -Be 27
        $contract.artifactMarkdownPolicy.limits.maxDistinctAllowedSymbolsPerFile | Should -Be 3
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
    It 'pins the reviewed July 2026 phase in the Constitution and Copilot adapter' {
        $constitution | Should -Match '(?m)^\*\*Current Phase:\*\* Practice \+ Internal \(as of 2026-07\)$'
        $constitution | Should -Not -Match '(?m)^\*\*Current Phase:\*\* Practice \+ Internal \(as of 2026-04\)$'
        $copilotAdapter = Get-Content -Raw -LiteralPath (Join-Path $WorkspaceRoot '.github/copilot-instructions.md')
        $copilotAdapter | Should -Match '(?m)^- \*\*Current Phase:\*\* Practice \+ Internal \(as of 2026-07\)$'
        $copilotAdapter | Should -Not -Match '(?m)^- \*\*Current Phase:\*\* Practice \(as of 2025-12\)$'
    }

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

Describe 'current README workflow and upstream path truthfulness' {
    BeforeAll {
        $script:rootReadme = Get-Content -Raw -LiteralPath (Join-Path $WorkspaceRoot 'README.md')
    }

    It 'pins workflow denial in the core model and the workflow runtime in the directory table' {
        $rootReadme | Should -Match '(?m)^- `studio/workflows/` 是共享 workflow runtime；內建 `sdd-pipeline` 目前維持 experimental、預設停用且禁止執行$'
        $rootReadme | Should -Match '(?m)^\| `studio/workflows/` \| workspace 級 workflow schemas、catalog、state、policy 與 workflow definitions \|$'
    }

    It 'pins both corrected upstream guide paths' {
        $rootReadme | Should -Match ([regex]::Escape('`docs/0308upstreams/spec-kit-upstream-wave2-transition-guide.md`'))
        $rootReadme | Should -Match ([regex]::Escape('`docs/0308upstreams/spec-kit-studio-first-upstream-usage-guide-2026-03-08.md`'))
        $rootReadme | Should -Not -Match '(?m)^- `spec-kit-upstream-wave2-transition-guide\.md`$'
        $rootReadme | Should -Not -Match '(?m)^- `spec-kit-studio-first-upstream-usage-guide-2026-03-08\.md`$'
    }
}

Describe 'workspace structure current metadata and root rows' {
    BeforeAll {
        $script:workspaceStructure = Get-Content -Raw -LiteralPath (Join-Path $WorkspaceRoot 'WORKSPACE_STRUCTURE.md')
    }

    It 'pins version date and root hook/editor rows' {
        $workspaceStructure | Should -Match '(?m)^\*\*Version:\*\* 1\.10\.0$'
        $workspaceStructure | Should -Match '(?m)^\*\*Updated:\*\* 2026-07-22$'
        $workspaceStructure | Should -Not -Match '(?m)^\*\*Version:\*\* 1\.9\.0$'
        $workspaceStructure | Should -Not -Match '(?m)^\*\*Updated:\*\* 2026-07-20$'
        $workspaceStructure | Should -Match '(?m)^\| `\.githooks/` \| Shared machine-enforced Git hooks used by the workspace and consumer repositories \|$'
        $workspaceStructure | Should -Match '(?m)^\| `\.vscode/` \| Workspace-level editor tasks and settings \|$'
    }

    It 'pins the fixed Wave 2 guide path and matching changelog row' {
        $workspaceStructure | Should -Match ([regex]::Escape('| `docs/0308upstreams/spec-kit-upstream-wave2-transition-guide.md` | Wave 2 upstream alignment execution guide |'))
        $workspaceStructure | Should -Match ([regex]::Escape('| 1.10.0 | 2026-07-22 | Reconcile canonical agent sources with generated Claude mirrors, document root hooks and editor configuration, and repair the Wave 2 guide path |'))
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

    It 'keeps the constitution version and newest changelog row aligned at 1.10.0' {
        $constitution | Should -Match '(?m)^\*\*Version:\*\* 1\.10\.0$'
        $changelogRows = @(
            [regex]::Matches($constitution, '(?m)^\| (1\.\d+\.\d+) \| \d{4}-\d{2}-\d{2} \|') |
                ForEach-Object { $_.Groups[1].Value }
        )
        $changelogRows.Count | Should -BeGreaterThan 0
        $changelogRows[0] | Should -Be '1.10.0'
    }

    It 'propagates the scoped route and 1.10.0 version through root adapters and templates' {
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
                $content | Should -Match '\*\*Studio Constitution Version:\*\* 1\.10\.0'
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
