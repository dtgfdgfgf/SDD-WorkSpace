#!/usr/bin/env pwsh
#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/governance.config.ps1"
    # check-speckit-runtime.ps1 dot-sources common.ps1 internally,
    # but we import functions directly to avoid running main logic.
    $script:auditScript = Join-Path $WorkspaceRoot 'studio/scripts/powershell/check-speckit-runtime.ps1'
    . (Get-ScriptFunctionsBlock -ScriptPath $script:auditScript)

    function script:New-RuntimeAuditFixture {
        $fixtureRoot = Join-Path $TestDrive ("runtime-audit-{0}" -f ([System.Guid]::NewGuid().ToString('N')))
        New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null

        $workspacePaths = @(& git -C $WorkspaceRoot ls-files --cached --others --exclude-standard)
        if ($LASTEXITCODE -ne 0) {
            throw 'Unable to enumerate workspace files for the runtime audit fixture.'
        }

        foreach ($relativePath in $workspacePaths) {
            $sourcePath = Join-Path $WorkspaceRoot $relativePath
            if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
                continue
            }

            $destinationPath = Join-Path $fixtureRoot $relativePath
            $destinationParent = Split-Path -Parent $destinationPath
            if (-not (Test-Path -LiteralPath $destinationParent)) {
                New-Item -ItemType Directory -Path $destinationParent -Force | Out-Null
            }
            Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force
        }

        return $fixtureRoot
    }

    function script:Invoke-RuntimeAuditFixture {
        param(
            [Parameter(Mandatory)] [string]$FixtureRoot,
            [switch]$WithoutYamlModule
        )

        $fixtureAuditScript = Join-Path $FixtureRoot 'studio/scripts/powershell/check-speckit-runtime.ps1'

        # R-A23: the child pwsh writes UTF-8 to its redirected stdout, so the capture must decode
        # UTF-8 explicitly; the parent console code page (for example CP950) must not participate.
        $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = (Get-Command pwsh).Source
        $startInfo.UseShellExecute = $false
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        $startInfo.StandardOutputEncoding = [System.Text.UTF8Encoding]::new($false)
        $startInfo.StandardErrorEncoding = [System.Text.UTF8Encoding]::new($false)
        if ($WithoutYamlModule) {
            $null = $startInfo.ArgumentList.Add('-NoProfile')
            $null = $startInfo.ArgumentList.Add('-Command')
            $null = $startInfo.ArgumentList.Add('& { param($audit) $env:PSModulePath = ''C:\__sdd_fixture_no_modules__''; & $audit -Json; exit $LASTEXITCODE }')
            $null = $startInfo.ArgumentList.Add($fixtureAuditScript)
        } else {
            $null = $startInfo.ArgumentList.Add('-NoProfile')
            $null = $startInfo.ArgumentList.Add('-File')
            $null = $startInfo.ArgumentList.Add($fixtureAuditScript)
            $null = $startInfo.ArgumentList.Add('-Json')
        }

        $process = [System.Diagnostics.Process]::Start($startInfo)
        try {
            $stdoutTask = $process.StandardOutput.ReadToEndAsync()
            $stderrTask = $process.StandardError.ReadToEndAsync()
            $process.WaitForExit()
            $stdout = $stdoutTask.GetAwaiter().GetResult()
            $stderr = $stderrTask.GetAwaiter().GetResult()
            $exitCode = $process.ExitCode
        } finally {
            $process.Dispose()
        }

        $segments = @($stdout, $stderr) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        $raw = (@($segments) -join [Environment]::NewLine).TrimEnd("`r", "`n")

        try {
            $result = $raw | ConvertFrom-Json
        } catch {
            throw "Runtime audit fixture did not return JSON. Exit=$exitCode Output=$raw"
        }

        return [PSCustomObject]@{
            ExitCode = $exitCode
            Result   = $result
            Raw      = $raw
        }
    }

    function script:Set-ClaudeVerifierFixtureResult {
        param(
            [Parameter(Mandatory)] [string]$FixtureRoot,
            [Parameter(Mandatory)] [string]$ValidExpression,
            [Parameter(Mandatory)] [string]$ErrorCountExpression,
            [Parameter(Mandatory)] [string]$ErrorsExpression
        )

        $seedPath = Join-Path $FixtureRoot 'studio/scripts/powershell/seed-claude-agents.ps1'
        $content = [System.IO.File]::ReadAllText($seedPath)
        $anchor = '$ErrorActionPreference = ''Stop'''
        $replacement = @"
`$ErrorActionPreference = 'Stop'
if (`$Verify) {
    [PSCustomObject][ordered]@{
        VALID       = $ValidExpression
        ERROR_COUNT = $ErrorCountExpression
        ERRORS      = $ErrorsExpression
    } | ConvertTo-Json -Depth 4
    exit 0
}
"@
        $content.Contains($anchor, [System.StringComparison]::Ordinal) | Should -BeTrue
        $content = $content.Replace($anchor, $replacement, [System.StringComparison]::Ordinal)
        [System.IO.File]::WriteAllText(
            $seedPath,
            ($content -replace "`r`n?", "`n"),
            [System.Text.UTF8Encoding]::new($false)
        )
    }

    function script:Set-FindingStatusValidatorFixtureResult {
        param(
            [Parameter(Mandatory)] [string]$FixtureRoot,
            [Parameter(Mandatory)] [string]$ValidExpression,
            [Parameter(Mandatory)] [string]$ErrorCountExpression,
            [Parameter(Mandatory)] [string]$ErrorsExpression,
            [Parameter(Mandatory)] [string]$FindingCountExpression,
            [Parameter(Mandatory)] [string]$LatestRevisionExpression,
            [string]$WarningCountExpression = '0',
            [string]$WarningsExpression = '@()'
        )

        $validatorPath = Join-Path $FixtureRoot 'studio/scripts/powershell/validate-finding-status-ledger.ps1'
        $content = [System.IO.File]::ReadAllText($validatorPath)
        $anchor = '$ErrorActionPreference = ''Stop'''
        $replacement = @"
`$ErrorActionPreference = 'Stop'
if (-not `$Help) {
    [PSCustomObject][ordered]@{
        VALID = $ValidExpression
        ERROR_COUNT = $ErrorCountExpression
        ERRORS = $ErrorsExpression
        WARNING_COUNT = $WarningCountExpression
        WARNINGS = $WarningsExpression
        FINDING_COUNT = $FindingCountExpression
        LATEST_REVISION = $LatestRevisionExpression
        HISTORY_VALID = `$true
    } | ConvertTo-Json -Depth 6
    exit 0
}
"@
        $content.Contains($anchor, [System.StringComparison]::Ordinal) | Should -BeTrue
        $content = $content.Replace($anchor, $replacement, [System.StringComparison]::Ordinal)
        [System.IO.File]::WriteAllText(
            $validatorPath,
            ($content -replace "`r`n?", "`n"),
            [System.Text.UTF8Encoding]::new($false)
        )
    }
}

# ============================================================
# Tier 2: Content contract validation
# ============================================================

Describe 'Test-ContentContract' {
    It 'returns empty when all mustContainAll strings are present' {
        $content = 'This file contains required-text-A and also required-text-B.'
        $result = Test-ContentContract -Content $content -MustContainAll @('required-text-A', 'required-text-B')
        $result.Count | Should -Be 0
    }

    It 'returns missing text when a required string is absent' {
        $content = 'This file contains required-text-A only.'
        $result = @(Test-ContentContract -Content $content -MustContainAll @('required-text-A', 'required-text-B'))
        $result.Count | Should -Be 1
        $result[0] | Should -BeLike '*required-text-B*'
    }

    It 'performs case-sensitive literal matching' {
        $content = 'Required-Text-A'
        $result = Test-ContentContract -Content $content -MustContainAll @('required-text-a')
        $result.Count | Should -Be 1
    }

    It 'returns empty when all mustMatchAll patterns match' {
        $content = 'Version: 1.2.3'
        $result = Test-ContentContract -Content $content -MustMatchAll @('Version:\s*\d+\.\d+')
        $result.Count | Should -Be 0
    }

    It 'returns missing pattern when a regex does not match' {
        $content = 'No version here'
        $result = @(Test-ContentContract -Content $content -MustMatchAll @('Version:\s*\d+\.\d+'))
        $result.Count | Should -Be 1
        $result[0] | Should -BeLike '*missing pattern*'
    }

    It 'handles empty/null mustContainAll gracefully' {
        $result = Test-ContentContract -Content 'anything' -MustContainAll @() -MustMatchAll @()
        $result.Count | Should -Be 0
    }

    It 'ignores null/whitespace entries in mustContainAll' {
        $result = Test-ContentContract -Content 'anything' -MustContainAll @($null, '', '  ')
        $result.Count | Should -Be 0
    }

    It 'rejects additive prohibited legacy text even when required replacement text remains' {
        $content = 'new canonical declaration; old stale authority declaration'
        $result = @(Test-ContentContract -Content $content `
            -MustContainAll @('new canonical declaration') `
            -MustNotContainAny @('old stale authority declaration'))

        $result.Count | Should -Be 1
        $result[0] | Should -BeLike 'prohibited text:*'
    }

    It 'rejects scalar and nested-array coercion in exact contract helpers' {
        (Test-ExactStringArray -Value @('expected') -ExpectedValues @('expected')) | Should -BeTrue
        (Test-ExactStringArray -Value 'expected' -ExpectedValues @('expected')) | Should -BeFalse
        (Test-ExactStringArray -Value @(, @('expected')) -ExpectedValues @('expected')) | Should -BeFalse
        (Test-ExactDictionaryKeys -Value ([ordered]@{ only = 'value' }) -ExpectedKeys @('only')) | Should -BeTrue
        (Test-ExactDictionaryKeys -Value ([ordered]@{ only = 'value'; extra = 'value' }) -ExpectedKeys @('only')) | Should -BeFalse
    }
}

Describe 'artifact Markdown token classification' {
    It 'allows Markdown tables CJK em dashes and inline ASCII arrows' {
        $path = Join-Path $TestDrive 'allowed.md'
        [System.IO.File]::WriteAllText(
            $path,
            "| A | B |`n|---|---|`n一般文字 — A -> B 與 ``--name-only```n",
            [System.Text.UTF8Encoding]::new($false)
        )

        @(Get-ArtifactMarkdownViolations -Path $path).Count | Should -Be 0
    }

    It 'detects <ExpectedClass> even inside Markdown hiding surfaces' -ForEach @(
        @{ Text = 'strict ✅'; ExpectedClass = 'emoji-code-point' }
        @{ Text = 'strict → value'; ExpectedClass = 'unicode-arrow-code-point' }
        @{ Text = '├── child'; ExpectedClass = 'tree-or-box-drawing-code-point' }
        @{ Text = '+-----+'; ExpectedClass = 'ascii-box-border-line' }
        @{ Text = '|-- child'; ExpectedClass = 'ascii-tree-branch-line' }
        @{ Text = '[A] --> [B]'; ExpectedClass = 'ascii-flow-diagram-line' }
        @{ Text = ('```text' + "`n✅`n" + '```'); ExpectedClass = 'emoji-code-point' }
        @{ Text = '<!-- 😀 -->'; ExpectedClass = 'emoji-code-point' }
    ) {
        $path = Join-Path $TestDrive ("prohibited-{0}.md" -f ([guid]::NewGuid().ToString('N')))
        [System.IO.File]::WriteAllText($path, "$Text`n", [System.Text.UTF8Encoding]::new($false))

        $violations = @(Get-ArtifactMarkdownViolations -Path $path)

        @($violations.tokenClass) | Should -Contain $ExpectedClass
    }

    It 'keeps the repaired strategy strict without absorbing unrelated historical paths' {
        $contract = Get-Content -Raw -LiteralPath (Join-Path $WorkspaceRoot 'studio/runtime/shared-runtime-contract.json') |
            ConvertFrom-Json
        $selected = @(
            foreach ($pattern in @($contract.artifactMarkdownPolicy.strictPathPatterns)) {
                Resolve-WorkspaceGlobFiles -RootPath $WorkspaceRoot -Pattern ([string]$pattern) |
                    ForEach-Object { [System.IO.Path]::GetRelativePath($WorkspaceRoot, $_).Replace('\', '/') }
            }
        )

        $selected | Should -Contain 'docs/yuanxi_sdd_pack_strategy_zhTW.md'
        @($selected | Where-Object { $_ -like 'docs/0308upstreams/*' }).Count | Should -Be 0
        @($selected | Where-Object { $_ -like 'docs/readiness_source/*' }).Count | Should -Be 0
    }
}

Describe 'R6-A4 document and configuration truthfulness' {
    It 'rejects an R-G01 governance ledger rollback' {
        foreach ($relativeNoticePath in @(
            'learning/codex-smoke-practice-20260307/docs/governance-status.md',
            'projects/codex-smoke-internal-20260307/docs/governance-status.md',
            'projects/commercial-line-bot/docs/governance-status.md',
            'projects/japanese-learning/docs/governance-status.md',
            'projects/KMS/docs/governance-status.md',
            'projects/personal_website/yuanxi_personal_site_ready/docs/governance-status.md',
            'projects/Trading/docs/governance-status.md',
            'projects/Trading-002-decision-evidence-platform/docs/governance-status.md',
            'projects/Trading-003-stock-selection-backtest/docs/governance-status.md'
        )) {
            Join-Path $WorkspaceRoot $relativeNoticePath | Should -Exist
        }

        $fixtureRoot = New-RuntimeAuditFixture
        $path = Join-Path $fixtureRoot 'docs/project-governance-status.md'
        $content = [System.IO.File]::ReadAllText($path)
        $tampered = $content.Replace(
            '**Updated:** 2026-07-22',
            '**Updated:** 2026-03-23',
            [System.StringComparison]::Ordinal
        ).Replace(
            '| `Trading-002-decision-evidence-platform` | `projects/Trading-002-decision-evidence-platform` | Standalone repo client project | `Mixed` |',
            '| `Trading-002-decision-evidence-platform` | `projects/Trading-002-decision-evidence-platform` | Standalone repo client project | `Legacy` |',
            [System.StringComparison]::Ordinal
        ).Replace(
            '| `Trading-003-stock-selection-backtest` | `projects/Trading-003-stock-selection-backtest` | Standalone repo client project | `Mixed` |',
            '| `Trading-003-stock-selection-backtest` | `projects/Trading-003-stock-selection-backtest` | Standalone repo client project | `Legacy` |',
            [System.StringComparison]::Ordinal
        )
        $tampered | Should -Not -BeExactly $content
        [System.IO.File]::WriteAllText($path, $tampered, [System.Text.UTF8Encoding]::new($false))

        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        @($audit.Result.FAILURES.id) | Should -Contain 'r-g01-project-governance-current-surface'
    }

    It 'rejects an R-G03 superseded-review rollback' {
        $historicalPath = Join-Path $WorkspaceRoot 'docs/yuanxi_sdd_pack_implementation_plan_obstacle_review_zhTW.md'
        $historicalContent = [System.IO.File]::ReadAllText($historicalPath).Replace("`r`n", "`n").Replace("`r", "`n")
        $historicalAnchor = '# Yuanxi SDD Pack Implementation Plan：實作障礙檢查'
        $historicalBody = $historicalContent.Substring(
            $historicalContent.IndexOf($historicalAnchor, [System.StringComparison]::Ordinal)
        ).TrimEnd("`n")
        $historicalHash = [Convert]::ToHexString(
            [System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes($historicalBody))
        ).ToLowerInvariant()
        $historicalHash | Should -BeExactly '25afa95fee40ae0cac15708620465c0ff9aaf7f93f6a762d7f3a364d94e79e6e'

        $fixtureRoot = New-RuntimeAuditFixture
        $fixtureHistoricalPath = Join-Path $fixtureRoot 'docs/yuanxi_sdd_pack_implementation_plan_obstacle_review_zhTW.md'
        $content = [System.IO.File]::ReadAllText($fixtureHistoricalPath)
        $tampered = $content.Replace(
            'status: "superseded"',
            'status: "handoff-draft"',
            [System.StringComparison]::Ordinal
        ).Replace(
            '> **Historical snapshot; superseded for current execution (2026-07-22).**',
            '> Historical review.',
            [System.StringComparison]::Ordinal
        )
        [System.IO.File]::WriteAllText($fixtureHistoricalPath, $tampered, [System.Text.UTF8Encoding]::new($false))
        Remove-Item -LiteralPath (
            Join-Path $fixtureRoot 'docs/yuanxi_sdd_pack_implementation_plan_obstacle_review_2026-07-22_zhTW.md'
        ) -Force

        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        @($audit.Result.FAILURES.id) | Should -Contain 'r-g03-obstacle-review-superseded-quarantine'
        @($audit.Result.FAILURES.id) | Should -Contain 'r-g03-obstacle-review-bounded-revalidation'
    }

    It 'rejects an R-G04 compatibility or formatting rollback' {
        $fixtureRoot = New-RuntimeAuditFixture
        $path = Join-Path $fixtureRoot 'docs/yuanxi_sdd_pack_strategy_zhTW.md'
        $content = [System.IO.File]::ReadAllText($path)
        $tampered = $content.Replace(
            '| 0.1.0 | v0.8.5 | historical-unverified |',
            '| 0.1.0 | v0.8.5 | tested |',
            [System.StringComparison]::Ordinal
        ) + "`n[A] --> [B]`nRestored → stale flow`n"
        [System.IO.File]::WriteAllText($path, $tampered, [System.Text.UTF8Encoding]::new($false))

        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        @($audit.Result.FAILURES.id) | Should -Contain 'r-g04-strategy-baseline-truthfulness'
        $check = $audit.Result.ARTIFACT_MARKDOWN_CHECKS |
            Where-Object path -EQ 'docs/yuanxi_sdd_pack_strategy_zhTW.md'
        @($check.violations.tokenClass) | Should -Contain 'ascii-flow-diagram-line'
        @($check.violations.tokenClass) | Should -Contain 'unicode-arrow-code-point'
    }

    It 'rejects an R-H06 relocation or reference rollback' {
        Test-Path -LiteralPath (Join-Path $WorkspaceRoot 'learning-project-spec-kit-sdd.md') |
            Should -BeFalse

        $historicalPath = Join-Path $WorkspaceRoot 'docs/0308upstreams/learning-project-spec-kit-sdd.md'
        $historicalContent = [System.IO.File]::ReadAllText($historicalPath).Replace("`r`n", "`n").Replace("`r", "`n")
        $historicalAnchor = '# 本工作區 Spec Kit / SDD 流程研究報告（2026-03-08 更新版）'
        $historicalBody = $historicalContent.Substring(
            $historicalContent.IndexOf($historicalAnchor, [System.StringComparison]::Ordinal)
        ).TrimEnd("`n")
        $historicalHash = [Convert]::ToHexString(
            [System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes($historicalBody))
        ).ToLowerInvariant()
        $historicalHash | Should -BeExactly 'dcc5f2b29b78cfe1150a3f23a433b1531bce5facbaa0d025cdb1016968293051'

        $fixtureRoot = New-RuntimeAuditFixture
        $fixtureHistoricalPath = Join-Path $fixtureRoot 'docs/0308upstreams/learning-project-spec-kit-sdd.md'
        Copy-Item -LiteralPath $fixtureHistoricalPath -Destination (
            Join-Path $fixtureRoot 'learning-project-spec-kit-sdd.md'
        ) -Force
        Remove-Item -LiteralPath $fixtureHistoricalPath -Force

        $transitionPath = Join-Path $fixtureRoot 'docs/0308upstreams/spec-kit-upstream-wave2-transition-guide.md'
        $transition = [System.IO.File]::ReadAllText($transitionPath).Replace(
            '| `docs/0308upstreams/learning-project-spec-kit-sdd.md` | 2026-03-08 工作區狀態與第二波目標的歷史快照 |',
            '| `learning-project-spec-kit-sdd.md` | 描述目前工作區狀態與第二波目標定位 |',
            [System.StringComparison]::Ordinal
        ).Replace(
            'Local workspace analysis: `docs/0308upstreams/learning-project-spec-kit-sdd.md`',
            'Local workspace analysis: `learning-project-spec-kit-sdd.md`',
            [System.StringComparison]::Ordinal
        )
        [System.IO.File]::WriteAllText($transitionPath, $transition, [System.Text.UTF8Encoding]::new($false))

        $remainingPath = Join-Path $fixtureRoot 'docs/0308upstreams/spec-kit-upstream-remaining-updates-2026-03-08.md'
        $remaining = [System.IO.File]::ReadAllText($remainingPath).Replace(
            '[learning-project-spec-kit-sdd.md](./learning-project-spec-kit-sdd.md)',
            '[learning-project-spec-kit-sdd.md](C:/Users/user/Workspace/learning-project-spec-kit-sdd.md)',
            [System.StringComparison]::Ordinal
        )
        [System.IO.File]::WriteAllText($remainingPath, $remaining, [System.Text.UTF8Encoding]::new($false))

        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        @($audit.Result.FAILURES.id) | Should -Contain 'r-h06-historical-six-stage-relocation'
        @($audit.Result.FAILURES.id) | Should -Contain 'r-h06-transition-guide-reference-reconciliation'
        @($audit.Result.FAILURES.id) | Should -Contain 'r-h06-remaining-updates-reference-reconciliation'
    }

    It 'rejects an R-H09 VS Code settings rollback' {
        $contract = Get-Content -Raw -LiteralPath (
            Join-Path $WorkspaceRoot 'studio/runtime/shared-runtime-contract.json'
        ) | ConvertFrom-Json
        $invariant = $contract.docInvariants | Where-Object id -EQ 'r-h09-vscode-settings-truthfulness'
        $current = [System.IO.File]::ReadAllText((Join-Path $WorkspaceRoot '.vscode/settings.json'))
        foreach ($staleSetting in @(
            '"markdownlint.ignore"',
            '"**/projects/duotify-*/**"',
            '"chat.tools.terminal.autoApprove"'
        )) {
            $variant = "$current`n$staleSetting"
            @(Test-ContentContract -Content $variant -MustContainAll @($invariant.mustContainAll) `
                -MustNotContainAny @($invariant.mustNotContainAny)).Count | Should -BeGreaterThan 0
        }

        $fixtureRoot = New-RuntimeAuditFixture
        $path = Join-Path $fixtureRoot '.vscode/settings.json'
        $content = [System.IO.File]::ReadAllText($path)
        $tampered = $content.Replace(
            '  // === Code Spell Checker Configuration ===',
            ('  "markdownlint.ignore": ["**/*.md"],' + "`n`n" + '  // === Code Spell Checker Configuration ==='),
            [System.StringComparison]::Ordinal
        ).Replace(
            '    "**/studio/**",',
            ('    "**/studio/**",' + "`n" + '    "**/projects/duotify-*/**",'),
            [System.StringComparison]::Ordinal
        ).Replace(
            ('  "chat.useAgentSkills": true' + "`n" + '}'),
            ('  "chat.useAgentSkills": true,' + "`n" + '  "chat.tools.terminal.autoApprove": {}' + "`n" + '}'),
            [System.StringComparison]::Ordinal
        )
        $tampered | Should -Not -BeExactly $content
        [System.IO.File]::WriteAllText($path, $tampered, [System.Text.UTF8Encoding]::new($false))

        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        @($audit.Result.FAILURES.id) | Should -Contain 'r-h09-vscode-settings-truthfulness'
    }
}

Describe 'check-speckit-runtime.ps1 bad-state fixtures' {
    It 'passes against an isolated copy of the current shared runtime' {
        $fixtureRoot = New-RuntimeAuditFixture
        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Be 0 -Because $audit.Raw
        $audit.Result.VALID | Should -BeTrue
        $audit.Result.ERROR_COUNT | Should -Be 0
        $audit.Raw | Should -Match '"STUDIO_WORKFLOW_ENABLED"\s*:\s*\[\s*\]'
    }

    It 'fails closed when the finding-status validator is missing' {
        $fixtureRoot = New-RuntimeAuditFixture
        Remove-Item -LiteralPath (Join-Path $fixtureRoot 'studio/scripts/powershell/validate-finding-status-ledger.ps1') -Force

        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        $audit.Result.FINDING_STATUS_LEDGER_VALID | Should -BeFalse
        @($audit.Result.FAILURES.id) | Should -Contain 'validator-missing'
    }

    It 'fails when the audit invocation is redirected away from the finding-status validator' {
        $fixtureRoot = New-RuntimeAuditFixture
        $auditPath = Join-Path $fixtureRoot 'studio/scripts/powershell/check-speckit-runtime.ps1'
        $content = [System.IO.File]::ReadAllText($auditPath)
        $originalInvocation = @'
Invoke-JsonScriptDetailed -ScriptPath $findingStatusLedgerScript `
        -Arguments @('-WorkspaceRoot', $paths.WORKSPACE_ROOT, '-Json')
'@
        $bypassedInvocation = @'
[ordered]@{
        EXIT_CODE = 0
        OUTPUT = [ordered]@{
            VALID = $true
            ERROR_COUNT = 0
            ERRORS = @()
            WARNING_COUNT = 0
            WARNINGS = @()
            FINDING_COUNT = 131
            LATEST_REVISION = 1
        }
    }
'@
        $tampered = $content.Replace(
            $originalInvocation,
            $bypassedInvocation,
            [System.StringComparison]::Ordinal
        )
        $tampered | Should -Not -BeExactly $content
        [System.IO.File]::WriteAllText($auditPath, $tampered, [System.Text.UTF8Encoding]::new($false))

        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        @($audit.Result.FAILURES.id) | Should -Contain 'shared-runtime-audit-fail-closed'
    }

    It 'rejects string booleans string counts null arrays and null finding metadata from the finding-status validator' {
        $fixtureRoot = New-RuntimeAuditFixture
        Set-FindingStatusValidatorFixtureResult `
            -FixtureRoot $fixtureRoot `
            -ValidExpression "'false'" `
            -ErrorCountExpression "'0'" `
            -ErrorsExpression '$null' `
            -FindingCountExpression '$null' `
            -LatestRevisionExpression "'1'"

        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        $audit.Result.FINDING_STATUS_LEDGER_VALID | Should -BeFalse
        $audit.Result.FINDING_STATUS_LEDGER_CHECKS[0].validFieldIsBoolean | Should -BeFalse
        $audit.Result.FINDING_STATUS_LEDGER_CHECKS[0].errorCountIsInteger | Should -BeFalse
        $audit.Result.FINDING_STATUS_LEDGER_CHECKS[0].errorsIsArray | Should -BeFalse
        $audit.Result.FINDING_STATUS_LEDGER_CHECKS[0].findingCountIsInteger | Should -BeFalse
        $audit.Result.FINDING_STATUS_LEDGER_CHECKS[0].latestRevisionIsInteger | Should -BeFalse
        @($audit.Result.FAILURES.id) | Should -Contain 'validation-failed'
    }

    It 'rejects a child warning count that does not match the structured warning array' {
        $fixtureRoot = New-RuntimeAuditFixture
        Set-FindingStatusValidatorFixtureResult `
            -FixtureRoot $fixtureRoot `
            -ValidExpression '$true' `
            -ErrorCountExpression '0' `
            -ErrorsExpression '@()' `
            -FindingCountExpression '131' `
            -LatestRevisionExpression '1' `
            -WarningCountExpression '1' `
            -WarningsExpression '@()'

        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        $audit.Result.FINDING_STATUS_LEDGER_VALID | Should -BeFalse
        $audit.Result.FINDING_STATUS_LEDGER_CHECKS[0].warningCountMatchesArray | Should -BeFalse
        @($audit.Result.FAILURES.id) | Should -Contain 'validation-failed'
    }

    It 'rejects a single-element array in a finding-status scalar policy field' {
        $fixtureRoot = New-RuntimeAuditFixture
        $contractPath = Join-Path $fixtureRoot 'studio/runtime/shared-runtime-contract.json'
        $content = [System.IO.File]::ReadAllText($contractPath)
        $tampered = $content.Replace(
            '"path": "docs/sdd-workspace-repair-inventory-and-update-plan-2026-07-12_zhTW.md"',
            '"path": ["docs/sdd-workspace-repair-inventory-and-update-plan-2026-07-12_zhTW.md"]',
            [System.StringComparison]::Ordinal
        )
        $tampered | Should -Not -BeExactly $content
        [System.IO.File]::WriteAllText($contractPath, $tampered, [System.Text.UTF8Encoding]::new($false))

        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        @($audit.Result.FAILURES.id) | Should -Contain 'required-finding-status-ledger-policy-missing'
    }

    It 'rejects a non-canonical finding-status fence marker policy: <Label>' -TestCases @(
        @{ Label = 'missing'; Mutation = { param($policy) $policy.Remove('fenceMarker') | Out-Null } }
        @{ Label = 'null'; Mutation = { param($policy) $policy['fenceMarker'] = $null } }
        @{ Label = 'array'; Mutation = { param($policy) $policy['fenceMarker'] = @('```') } }
        @{ Label = 'wrong marker'; Mutation = { param($policy) $policy['fenceMarker'] = '~~~~' } }
    ) {
        param($Label, $Mutation)

        $fixtureRoot = New-RuntimeAuditFixture
        $contractPath = Join-Path $fixtureRoot 'studio/runtime/shared-runtime-contract.json'
        $contract = Get-Content -Raw -LiteralPath $contractPath | ConvertFrom-Json -AsHashtable
        & $Mutation $contract.findingStatusLedger
        [System.IO.File]::WriteAllText(
            $contractPath,
            (($contract | ConvertTo-Json -Depth 100) + "`n"),
            [System.Text.UTF8Encoding]::new($false)
        )

        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        @($audit.Result.FAILURES.id) | Should -Contain 'required-finding-status-ledger-policy-missing'
    }

    It 'promotes finding-status index tampering into a runtime audit failure' {
        $fixtureRoot = New-RuntimeAuditFixture
        $indexPath = Join-Path $fixtureRoot 'docs/README.md'
        $content = [System.IO.File]::ReadAllText($indexPath)
        $statusPattern = 'statusCounts=COMPLETED:(?<completed>\d+),OPEN:(?<open>\d+)'
        $statusMatches = [regex]::Matches(
            $content,
            $statusPattern,
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )
        $statusMatches.Count | Should -Be 1
        $statusMatch = $statusMatches[0]
        $tamperedCounts = 'statusCounts=COMPLETED:{0},OPEN:{1}' -f (
            [int]$statusMatch.Groups['completed'].Value + 1
        ), $statusMatch.Groups['open'].Value
        $tampered = $content.Replace(
            $statusMatch.Value,
            $tamperedCounts,
            [System.StringComparison]::Ordinal
        )
        $tampered | Should -Not -BeExactly $content
        [System.IO.File]::WriteAllText($indexPath, $tampered, [System.Text.UTF8Encoding]::new($false))

        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        $audit.Result.FINDING_STATUS_LEDGER_VALID | Should -BeFalse
        @($audit.Result.FAILURES.id) | Should -Contain 'status-index-mismatch'
    }

    It 'rejects an ordinal disposition trigger mapping swap even when all literals remain present' {
        $fixtureRoot = New-RuntimeAuditFixture
        $validatorPath = Join-Path $fixtureRoot 'studio/scripts/powershell/validate-finding-status-ledger.ps1'
        $content = [System.IO.File]::ReadAllText($validatorPath)
        $firstTrigger = 'Before adding or materially expanding `mustContainAll` literal assertions, or before the next contract-invariant refactor'
        $secondTrigger = 'Before any workflow promotion, execution authorization, or use of RunState/sidecar data as trusted evidence; deferral is valid only while `sdd-pipeline` stays experimental, default-disabled and execution-denied'
        $placeholder = '__R_E13_DIRECTIONAL_TRIGGER_SWAP__'
        $content.Contains($firstTrigger, [System.StringComparison]::Ordinal) | Should -BeTrue
        $content.Contains($secondTrigger, [System.StringComparison]::Ordinal) | Should -BeTrue
        $tampered = $content.Replace(
            $firstTrigger,
            $placeholder,
            [System.StringComparison]::Ordinal
        ).Replace(
            $secondTrigger,
            $firstTrigger,
            [System.StringComparison]::Ordinal
        ).Replace(
            $placeholder,
            $secondTrigger,
            [System.StringComparison]::Ordinal
        )
        $tampered | Should -Not -BeExactly $content
        [System.IO.File]::WriteAllText(
            $validatorPath,
            ($tampered -replace "`r`n?", "`n"),
            [System.Text.UTF8Encoding]::new($false)
        )

        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        $audit.Result.FINDING_STATUS_LEDGER_VALID | Should -BeFalse
        @($audit.Result.FAILURES.id) | Should -Contain 'status-disposition-policy-invalid'
    }

    It 'rejects removal of the conditional disposition trigger schema through runtime invariants' {
        $fixtureRoot = New-RuntimeAuditFixture
        $schemaPath = Join-Path $fixtureRoot 'studio/runtime/finding-status-record.schema.json'
        $content = [System.IO.File]::ReadAllText($schemaPath)
        $tampered = $content.Replace(
            '"allOf": [',
            '"allOfLegacy": [',
            [System.StringComparison]::Ordinal
        )
        $tampered | Should -Not -BeExactly $content
        [System.IO.File]::WriteAllText(
            $schemaPath,
            ($tampered -replace "`r`n?", "`n"),
            [System.Text.UTF8Encoding]::new($false)
        )

        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        $audit.Result.FINDING_STATUS_LEDGER_VALID | Should -BeFalse
        @($audit.Result.FAILURES.id) | Should -Contain 'finding-status-record-schema'
        @($audit.Result.FAILURES.id) | Should -Contain 'status-schema-contract'
    }

    It 'rejects a wrong-type exact agent authority partition' {
        $fixtureRoot = New-RuntimeAuditFixture
        $contractPath = Join-Path $fixtureRoot 'studio/runtime/shared-runtime-contract.json'
        $contract = Get-Content -Raw -LiteralPath $contractPath | ConvertFrom-Json
        $contract.agentAuthorityPartition.expectedPatternInputCount = '14'
        $contract | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $contractPath -Encoding utf8

        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        $audit.Result.AGENT_AUTHORITY_PARTITION_VALID | Should -BeFalse
        @($audit.Result.FAILURES.id) | Should -Contain 'agent-authority-partition-invalid'
    }

    It 'rejects a nested array in the exact agent authority file set' {
        $fixtureRoot = New-RuntimeAuditFixture
        $contractPath = Join-Path $fixtureRoot 'studio/runtime/shared-runtime-contract.json'
        $content = [System.IO.File]::ReadAllText($contractPath)
        $tampered = [regex]::Replace(
            $content,
            '(?s)"canonicalAdditionalFiles"\s*:\s*\[\s*"\.github/agents/async-python-reviewer\.md"\s*\]',
            '"canonicalAdditionalFiles": [[".github/agents/async-python-reviewer.md"]]',
            1
        )
        $tampered | Should -Not -BeExactly $content
        [System.IO.File]::WriteAllText($contractPath, $tampered, [System.Text.UTF8Encoding]::new($false))

        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        $audit.Result.AGENT_AUTHORITY_PARTITION_VALID | Should -BeFalse
        @($audit.Result.FAILURES.id) | Should -Contain 'agent-authority-partition-invalid'
    }

    It 'rejects an incomplete dependent Claude mirror set' {
        $fixtureRoot = New-RuntimeAuditFixture
        Remove-Item -LiteralPath (Join-Path $fixtureRoot '.claude/agents/speckit-version.md') -Force

        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        $audit.Result.AGENT_AUTHORITY_PARTITION_VALID | Should -BeFalse
        @($audit.Result.FAILURES.id) | Should -Contain 'dependent-mirror-set-mismatch'
    }

    It 'rejects null formatting limits instead of coercing the artifact policy' {
        $fixtureRoot = New-RuntimeAuditFixture
        $contractPath = Join-Path $fixtureRoot 'studio/runtime/shared-runtime-contract.json'
        $contract = Get-Content -Raw -LiteralPath $contractPath | ConvertFrom-Json
        $contract.artifactMarkdownPolicy.limits.maxAllowedSymbolOccurrencesPerFile = $null
        $contract | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $contractPath -Encoding utf8

        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        $audit.Result.ARTIFACT_MARKDOWN_POLICY_VALID | Should -BeFalse
        @($audit.Result.FAILURES.id) | Should -Contain 'artifact-markdown-policy-invalid'
    }

    It 'rejects a single-element array in an artifact-policy scalar field' {
        $fixtureRoot = New-RuntimeAuditFixture
        $contractPath = Join-Path $fixtureRoot 'studio/runtime/shared-runtime-contract.json'
        $content = [System.IO.File]::ReadAllText($contractPath)
        $tampered = $content.Replace(
            '"defaultClassification": "out_of_scope"',
            '"defaultClassification": ["out_of_scope"]',
            [System.StringComparison]::Ordinal
        )
        $tampered | Should -Not -BeExactly $content
        [System.IO.File]::WriteAllText($contractPath, $tampered, [System.Text.UTF8Encoding]::new($false))

        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        $audit.Result.ARTIFACT_MARKDOWN_POLICY_VALID | Should -BeFalse
        @($audit.Result.FAILURES.id) | Should -Contain 'artifact-markdown-policy-invalid'
    }

    It 'keeps both current project governance documents in the strict formatting scope' {
        $fixtureRoot = New-RuntimeAuditFixture
        foreach ($relativePath in @(
            'docs/project-governance-status.md',
            'docs/project-worktree-parity-governance.md'
        )) {
            [System.IO.File]::AppendAllText(
                (Join-Path $fixtureRoot $relativePath),
                "`nStrict fixture ✅`n",
                [System.Text.UTF8Encoding]::new($false)
            )
        }

        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        foreach ($relativePath in @(
            'docs/project-governance-status.md',
            'docs/project-worktree-parity-governance.md'
        )) {
            $check = $audit.Result.ARTIFACT_MARKDOWN_CHECKS | Where-Object path -EQ $relativePath
            $check.classification | Should -BeExactly 'strict'
            @($check.violations.tokenClass) | Should -Contain 'emoji-code-point'
        }
    }

    It 'applies the strict formatting scope to nested SDD document templates' {
        $fixtureRoot = New-RuntimeAuditFixture
        $nestedPath = Join-Path $fixtureRoot 'studio/templates/sdd-docs/nested/future-template.md'
        New-Item -ItemType Directory -Path (Split-Path -Parent $nestedPath) -Force | Out-Null
        [System.IO.File]::WriteAllText($nestedPath, "Nested fixture ✅`n", [System.Text.UTF8Encoding]::new($false))

        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        $check = $audit.Result.ARTIFACT_MARKDOWN_CHECKS |
            Where-Object path -EQ 'studio/templates/sdd-docs/nested/future-template.md'
        $check.classification | Should -BeExactly 'strict'
        @($check.violations.tokenClass) | Should -Contain 'emoji-code-point'
    }

    It 'rejects additive stale phase path metadata and Claude authority guidance' {
        $fixtureRoot = New-RuntimeAuditFixture
        $additions = [ordered]@{
            'studio/constitution/constitution.md' = @(
                '**Current Phase:** Practice + Internal (as of 2026-04)',
                'All AI-generated `.md` files MUST follow these formatting rules:'
            )
            '.github/copilot-instructions.md' = @(
                '- **Current Phase:** Practice (as of 2025-12)',
                '| `.claude/agents/` | Runtime source for shared Claude agents |',
                'Treat workspace `/.claude/agents/` as the Claude shared runtime authority'
            )
            'README.md' = @(
                '`.claude/agents/` 是 Claude shared runtime source of truth',
                '- `spec-kit-upstream-wave2-transition-guide.md`',
                '- `spec-kit-studio-first-upstream-usage-guide-2026-03-08.md`'
            )
            'WORKSPACE_STRUCTURE.md' = @(
                '**Version:** 1.9.0',
                '**Updated:** 2026-07-20',
                '| `.claude/agents/` | Runtime source for shared Claude agents |',
                '| `spec-kit-upstream-wave2-transition-guide.md` | Wave 2 upstream alignment execution guide |'
            )
            'studio/QUICKSTART.md' = @(
                '`.github/agents/`。這是 runtime source。',
                '`/.claude/agents/` 是 Claude shared runtime source of truth'
            )
            'studio/SDD-QUICKSTART-GUIDE.md' = @(
                '`.claude/agents/` 是 shared Claude runtime authority',
                '| Shared Claude Runtime | `.claude/agents/` | workspace 級 Claude shared runtime authority |'
            )
        }
        foreach ($entry in $additions.GetEnumerator()) {
            [System.IO.File]::AppendAllText(
                (Join-Path $fixtureRoot $entry.Key),
                ("`n" + ($entry.Value -join "`n") + "`n"),
                [System.Text.UTF8Encoding]::new($false)
            )
        }

        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        $failureIds = @($audit.Result.FAILURES.id)
        foreach ($expectedId in @(
            'constitution-current-phase-review',
            'constitution-artifact-markdown-formatting',
            'copilot-adapter-current-phase-review',
            'copilot-shared-layer-audit',
            'readme-claude-shared-runtime',
            'readme-upstream-guide-paths',
            'workspace-structure-claude-runtime',
            'workspace-structure-current-surface',
            'quickstart-claude-runtime',
            'sdd-guide-claude-runtime-boundary'
        )) {
            $failureIds | Should -Contain $expectedId
        }
    }

    It 'keeps the agent-scoped instruction adapter strict when it contains an emoji' {
        $fixtureRoot = New-RuntimeAuditFixture
        $adapterPath = Join-Path $fixtureRoot '.github/agents/copilot-instructions.md'
        [System.IO.File]::AppendAllText($adapterPath, "`nStrict fixture ✅`n", [System.Text.UTF8Encoding]::new($false))

        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        $audit.Result.ARTIFACT_MARKDOWN_POLICY_VALID | Should -BeFalse
        @($audit.Result.FAILURES.id) | Should -Contain 'artifact-markdown-prohibited-content'
        @($audit.Result.ARTIFACT_MARKDOWN_CHECKS | Where-Object path -EQ '.github/agents/copilot-instructions.md').classification |
            Should -Contain 'strict'
    }

    It 'rejects non-allowlisted emoji inside a contract-declared prompt exception' {
        $fixtureRoot = New-RuntimeAuditFixture
        $promptPath = Join-Path $fixtureRoot '.github/prompts/speckit.version.prompt.md'
        [System.IO.File]::AppendAllText($promptPath, "`nFixture 🎉`n", [System.Text.UTF8Encoding]::new($false))

        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        $audit.Result.ARTIFACT_MARKDOWN_POLICY_VALID | Should -BeFalse
        @($audit.Result.FAILURES.id) | Should -Contain 'artifact-markdown-prohibited-content'
        $check = $audit.Result.ARTIFACT_MARKDOWN_CHECKS | Where-Object path -EQ '.github/prompts/speckit.version.prompt.md'
        $check.classification | Should -BeExactly 'semantic_exception'
        @($check.violations.codePoint) | Should -Contain 'U+1F389'
    }

    It 'rejects a twenty-eighth allowlisted symbol in one semantic exception file' {
        $fixtureRoot = New-RuntimeAuditFixture
        $promptPath = Join-Path $fixtureRoot '.github/prompts/speckit.version.prompt.md'
        [System.IO.File]::AppendAllText(
            $promptPath,
            ("`n" + ('→' * 28) + "`n"),
            [System.Text.UTF8Encoding]::new($false)
        )

        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        @($audit.Result.ARTIFACT_MARKDOWN_CHECKS.violations.tokenClass) |
            Should -Contain 'semantic-symbol-occurrence-limit'
    }

    It 'rejects a fourth distinct allowlisted symbol in one semantic exception file' {
        $fixtureRoot = New-RuntimeAuditFixture
        $promptPath = Join-Path $fixtureRoot '.github/prompts/speckit.version.prompt.md'
        [System.IO.File]::AppendAllText(
            $promptPath,
            "`n→⚠✅✓`n",
            [System.Text.UTF8Encoding]::new($false)
        )

        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        @($audit.Result.ARTIFACT_MARKDOWN_CHECKS.violations.tokenClass) |
            Should -Contain 'semantic-symbol-distinct-limit'
    }

    It 'rejects growth of the exact legacy symbol allowance in source and mirror' {
        $fixtureRoot = New-RuntimeAuditFixture
        foreach ($relativePath in @(
            '.github/agents/async-python-reviewer.md',
            '.claude/agents/async-python-reviewer.md'
        )) {
            [System.IO.File]::AppendAllText(
                (Join-Path $fixtureRoot $relativePath),
                "`nLegacy growth 🔍`n",
                [System.Text.UTF8Encoding]::new($false)
            )
        }

        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        $audit.Result.ARTIFACT_MARKDOWN_POLICY_VALID | Should -BeFalse
        @($audit.Result.ARTIFACT_MARKDOWN_CHECKS.violations.tokenClass) | Should -Contain 'legacy-symbol-growth'
    }

    It 'fails when the R6 fresh-fixture terminal evidence marker is removed' {
        $fixtureRoot = New-RuntimeAuditFixture
        $e2ePath = Join-Path $fixtureRoot 'studio/tests/r6-fresh-fixture-e2e.Tests.ps1'
        $content = [System.IO.File]::ReadAllText($e2ePath)
        $content = $content.Replace(
            'R6_FRESH_FIXTURE_TERMINAL_SUCCESS',
            'R6_FRESH_FIXTURE_TERMINAL_MARKER_REMOVED'
        )
        [System.IO.File]::WriteAllText(
            $e2ePath,
            ($content -replace "`r`n?", "`n"),
            [System.Text.UTF8Encoding]::new($false)
        )

        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        $audit.Result.VALID | Should -BeFalse
        @($audit.Result.FAILURES.id) | Should -Contain 'r6-fresh-fixture-e2e'
        ($audit.Result.FAILURES.message -join "`n") |
            Should -Match 'R6_FRESH_FIXTURE_TERMINAL_SUCCESS'
    }

    It 'fails when source and mirror jointly restore the pre-R-D03 inline parallel-marker semantics' {
        $fixtureRoot = New-RuntimeAuditFixture
        $paths = @(
            (Join-Path $fixtureRoot '.github/agents/speckit.implement.agent.md'),
            (Join-Path $fixtureRoot '.claude/agents/speckit-implement.md')
        )
        $replacements = [ordered]@{
            '**Task dependencies and parallelism**: Read `Dependencies`, `Parallel Execution Examples`, and any `Parallel with: T0xx, T0yy` follow-up lines' = '**Task dependencies**: Sequential vs parallel execution rules'
            '**Task details**: ID, description, file paths, priority `[P#]`, risk, and story metadata' = '**Task details**: ID, description, file paths, parallel markers [P]'
            '**Priority is not parallelism**: Do not infer parallel execution from `[P]` or `[P#]` checklist tokens. `[P#]` is delivery priority; inline `[P]` is invalid.' = ''
            '**Respect dependencies**: Run tasks in dependency order; only tasks explicitly declared parallel by the separate dependency/parallelism metadata can run together' = '**Respect dependencies**: Run sequential tasks in order, parallel tasks [P] can run together'
            'Halt execution if any task without explicit parallel metadata fails' = 'Halt execution if any non-parallel task fails'
            'For tasks explicitly declared parallel by `Dependencies`, `Parallel Execution Examples`, or `Parallel with:` metadata, continue with successful tasks and report failed ones' = 'For parallel tasks [P], continue with successful tasks, report failed ones'
        }

        foreach ($path in $paths) {
            $content = [System.IO.File]::ReadAllText($path)
            foreach ($entry in $replacements.GetEnumerator()) {
                $content.Contains($entry.Key, [System.StringComparison]::Ordinal) | Should -BeTrue
                $content = $content.Replace($entry.Key, $entry.Value, [System.StringComparison]::Ordinal)
            }
            [System.IO.File]::WriteAllText(
                $path,
                ($content -replace "`r`n?", "`n"),
                [System.Text.UTF8Encoding]::new($false)
            )
        }

        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        $audit.Result.VALID | Should -BeFalse
        $audit.Result.CLAUDE_AGENT_PARITY_VALID | Should -BeTrue
        @($audit.Result.FAILURES.id) | Should -Contain 'implement-agent-task-parallelism-semantics'
        @($audit.Result.FAILURES.id) | Should -Contain 'implement-claude-task-parallelism-semantics'
    }

    It 'fails closed when powershell-yaml is unavailable' {
        $fixtureRoot = New-RuntimeAuditFixture
        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot -WithoutYamlModule

        $audit.ExitCode | Should -Not -Be 0
        $audit.Result.VALID | Should -BeFalse
        $audit.Result.STUDIO_WORKFLOW_YAML_AVAILABLE | Should -BeFalse
        @($audit.Result.FAILURES.id) | Should -Contain 'powershell-yaml-missing'
    }

    It 'promotes a missing workflow state ledger to an audit failure' {
        $fixtureRoot = New-RuntimeAuditFixture
        Remove-Item -LiteralPath (Join-Path $fixtureRoot 'studio/workflows/state.json') -Force
        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        $audit.Result.STUDIO_WORKFLOW_REGISTRY_VALID | Should -BeFalse
        @($audit.Result.FAILURES | Where-Object category -eq 'workflow-registry').Count | Should -BeGreaterThan 0
        ($audit.Result.FAILURES.message -join "`n") | Should -Match 'state.*missing|missing.*state'
    }

    It 'promotes an invalid workflow catalog schema to an audit failure' {
        $fixtureRoot = New-RuntimeAuditFixture
        $catalogPath = Join-Path $fixtureRoot 'studio/workflows/catalog.json'
        $catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json
        $catalog.workflows[0].reviewStatus = 'not-a-review-status'
        $catalog | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $catalogPath -Encoding utf8
        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        $audit.Result.STUDIO_WORKFLOW_REGISTRY_VALID | Should -BeFalse
        @($audit.Result.FAILURES.id) | Should -Contain 'workflow-registry-invalid'
        ($audit.Result.FAILURES.message -join "`n") | Should -Match 'catalog.*schema|schema.*catalog'
    }

    It 'fails when a required GitHub runtime command is absent' {
        $fixtureRoot = New-RuntimeAuditFixture
        Remove-Item -LiteralPath (Join-Path $fixtureRoot '.github/agents/speckit.plan.agent.md') -Force
        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        @($audit.Result.FAILURES.id) | Should -Contain 'speckit.plan'
    }

    It 'fails when the derived impact registry is stale' {
        $fixtureRoot = New-RuntimeAuditFixture
        $registryPath = Join-Path $fixtureRoot 'studio/runtime/impact-registry.json'
        $registryContent = Get-Content -LiteralPath $registryPath -Raw
        $registryContent = $registryContent.Replace('Highest governance authority for all projects and workflows', 'Fixture-only stale authority description')
        Set-Content -LiteralPath $registryPath -Value $registryContent -NoNewline -Encoding utf8
        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        @($audit.Result.FAILURES.id) | Should -Contain 'impact-registry-stale'
    }

    It 'returns an empty workflow semantic array when the shared contract is missing' {
        $fixtureRoot = New-RuntimeAuditFixture
        Remove-Item -LiteralPath (Join-Path $fixtureRoot 'studio/runtime/shared-runtime-contract.json') -Force
        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        @($audit.Result.FAILURES.id) | Should -Contain 'missing-contract'
        $audit.Raw | Should -Match '"WORKFLOW_SEMANTIC_CHECKS"\s*:\s*\[\s*\]'
        @($audit.Result.WORKFLOW_SEMANTIC_CHECKS).Count | Should -Be 0
    }

    It 'rejects an undeclared file in the closed GitHub agents directory' {
        $fixtureRoot = New-RuntimeAuditFixture
        $roguePath = Join-Path $fixtureRoot '.github/agents/rogue-agent.md'
        Set-Content -LiteralPath $roguePath -Value '# Rogue fixture agent' -Encoding utf8
        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        @($audit.Result.FAILURES.id) | Should -Contain 'unexpected-rogue-agent.md'
    }

    It 'fails when a generated Claude agent mirror is blank' {
        $fixtureRoot = New-RuntimeAuditFixture
        $mirrorPath = Join-Path $fixtureRoot '.claude/agents/speckit-specify.md'
        [System.IO.File]::WriteAllText(
            $mirrorPath,
            '',
            [System.Text.UTF8Encoding]::new($false)
        )
        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        $audit.Result.CLAUDE_AGENT_PARITY_VALID | Should -BeFalse
        @($audit.Result.FAILURES.id) | Should -Contain 'claude-agent-mirror-parity'
        @($audit.Result.CLAUDE_AGENT_PARITY_CHECKS[0].errors.id) | Should -Contain 'claude-agent-content-drift'
    }

    It 'fails when a generated Claude agent mirror body drifts from its source' {
        $fixtureRoot = New-RuntimeAuditFixture
        $mirrorPath = Join-Path $fixtureRoot '.claude/agents/speckit-specify.md'
        $content = [System.IO.File]::ReadAllText($mirrorPath)
        [System.IO.File]::WriteAllText(
            $mirrorPath,
            ($content + "`nFixture-only mirror drift.`n"),
            [System.Text.UTF8Encoding]::new($false)
        )
        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        $audit.Result.CLAUDE_AGENT_PARITY_VALID | Should -BeFalse
        @($audit.Result.FAILURES.id) | Should -Contain 'claude-agent-mirror-parity'
        @($audit.Result.CLAUDE_AGENT_PARITY_CHECKS[0].errors.id) | Should -Contain 'claude-agent-content-drift'
    }

    It 'fails when the generated Claude agent authority contains nested entries' {
        $fixtureRoot = New-RuntimeAuditFixture
        $roguePath = Join-Path $fixtureRoot '.claude/agents/nested/rogue.md'
        $rogueParent = Split-Path -Parent $roguePath
        New-Item -ItemType Directory -Path $rogueParent -Force | Out-Null
        [System.IO.File]::WriteAllText(
            $roguePath,
            "# Nested rogue`n",
            [System.Text.UTF8Encoding]::new($false)
        )
        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        $audit.Result.CLAUDE_AGENT_PARITY_VALID | Should -BeFalse
        @($audit.Result.FAILURES.id) | Should -Contain 'claude-agent-mirror-parity'
        @($audit.Result.CLAUDE_AGENT_PARITY_CHECKS[0].errors.id) | Should -Contain 'claude-agent-mirror-unexpected-directory'
        @($audit.Result.CLAUDE_AGENT_PARITY_CHECKS[0].errors.id) | Should -Contain 'claude-agent-mirror-unexpected'
    }

    It 'rejects a string false verdict from the Claude parity verifier' {
        $fixtureRoot = New-RuntimeAuditFixture
        Set-ClaudeVerifierFixtureResult `
            -FixtureRoot $fixtureRoot `
            -ValidExpression "'false'" `
            -ErrorCountExpression '0' `
            -ErrorsExpression '@()'
        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        $audit.Result.CLAUDE_AGENT_PARITY_VALID | Should -BeFalse
        $audit.Result.CLAUDE_AGENT_PARITY_CHECKS[0].validFieldIsBoolean | Should -BeFalse
        @($audit.Result.FAILURES.id) | Should -Contain 'claude-agent-mirror-parity'
    }

    It 'rejects a non-integer error count from an otherwise successful Claude parity verifier' {
        $fixtureRoot = New-RuntimeAuditFixture
        Set-ClaudeVerifierFixtureResult `
            -FixtureRoot $fixtureRoot `
            -ValidExpression '$true' `
            -ErrorCountExpression "'0'" `
            -ErrorsExpression '@()'
        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        $audit.Result.CLAUDE_AGENT_PARITY_VALID | Should -BeFalse
        $audit.Result.CLAUDE_AGENT_PARITY_CHECKS[0].errorCountIsInteger | Should -BeFalse
        @($audit.Result.FAILURES.id) | Should -Contain 'claude-agent-mirror-parity'
    }

    It 'rejects a nonzero native error count from an otherwise successful Claude parity verifier' {
        $fixtureRoot = New-RuntimeAuditFixture
        Set-ClaudeVerifierFixtureResult `
            -FixtureRoot $fixtureRoot `
            -ValidExpression '$true' `
            -ErrorCountExpression '1' `
            -ErrorsExpression '@()'
        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        $audit.Result.CLAUDE_AGENT_PARITY_VALID | Should -BeFalse
        $audit.Result.CLAUDE_AGENT_PARITY_CHECKS[0].errorCountIsInteger | Should -BeTrue
        $audit.Result.CLAUDE_AGENT_PARITY_CHECKS[0].errorCount | Should -Be 1
        @($audit.Result.FAILURES.id) | Should -Contain 'claude-agent-mirror-parity'
    }

    It 'rejects concealed child errors behind a true Claude parity verdict' {
        $fixtureRoot = New-RuntimeAuditFixture
        Set-ClaudeVerifierFixtureResult `
            -FixtureRoot $fixtureRoot `
            -ValidExpression '$true' `
            -ErrorCountExpression '0' `
            -ErrorsExpression "@('concealed error')"
        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        $audit.Result.CLAUDE_AGENT_PARITY_VALID | Should -BeFalse
        $audit.Result.CLAUDE_AGENT_PARITY_CHECKS[0].errorsIsArray | Should -BeTrue
        @($audit.Result.CLAUDE_AGENT_PARITY_CHECKS[0].errors).Count | Should -Be 1
        @($audit.Result.FAILURES.id) | Should -Contain 'claude-agent-mirror-parity'
    }

    It 'rejects a null child error ledger behind a true Claude parity verdict' {
        $fixtureRoot = New-RuntimeAuditFixture
        Set-ClaudeVerifierFixtureResult `
            -FixtureRoot $fixtureRoot `
            -ValidExpression '$true' `
            -ErrorCountExpression '0' `
            -ErrorsExpression '$null'
        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        $audit.Result.CLAUDE_AGENT_PARITY_VALID | Should -BeFalse
        $audit.Result.CLAUDE_AGENT_PARITY_CHECKS[0].errorsIsArray | Should -BeFalse
        @($audit.Result.FAILURES.id) | Should -Contain 'claude-agent-mirror-parity'
    }

    It 'checks requiredCommands layering inside the audit itself' {
        $fixtureRoot = New-RuntimeAuditFixture
        $contractPath = Join-Path $fixtureRoot 'studio/runtime/shared-runtime-contract.json'
        $contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
        $contract.requiredCommands = @($contract.requiredCommands | Where-Object { $_ -ne 'speckit.version' })
        $contract | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $contractPath -Encoding utf8
        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        @($audit.Result.FAILURES.id) | Should -Contain 'required-command-layering-mismatch'
    }

    It 'fails when a category-complete shared gate rule is removed from the contract' {
        $fixtureRoot = New-RuntimeAuditFixture
        $contractPath = Join-Path $fixtureRoot 'studio/runtime/shared-runtime-contract.json'
        $contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
        $contract.sharedGatePaths = @($contract.sharedGatePaths | Where-Object { $_ -ne 'studio/extensions/**' })
        $contract | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $contractPath -Encoding utf8
        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        @($audit.Result.FAILURES.id) | Should -Contain 'required-shared-gate-path-missing'
        ($audit.Result.FAILURES.message -join "`n") | Should -Match ([regex]::Escape('studio/extensions/**'))
    }

    It 'fails when the readiness middle-glob matcher is reverted to the pre-R-A21 expression' {
        $fixtureRoot = New-RuntimeAuditFixture
        $validatorPath = Join-Path $fixtureRoot 'studio/scripts/powershell/validate-mainline-notes.ps1'
        $content = [System.IO.File]::ReadAllText($validatorPath)
        $correctedExpression = '$regexBody = $regexBody -replace ''/\\\*\\\*/'', ''/(?:[^/]+/)*'''
        $legacyExpression = '$regexBody = $regexBody -replace ''/\\\*\\\*/'', ''(?:/.*/)?'''

        $content.Contains($correctedExpression, [System.StringComparison]::Ordinal) |
            Should -BeTrue
        $tampered = $content.Replace(
            $correctedExpression,
            $legacyExpression,
            [System.StringComparison]::Ordinal
        )
        $tampered | Should -Not -BeExactly $content
        [System.IO.File]::WriteAllText(
            $validatorPath,
            ($tampered -replace "`r`n?", "`n"),
            [System.Text.UTF8Encoding]::new($false)
        )

        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        @($audit.Result.FAILURES.id) | Should -Contain 'validate-mainline-notes-gate'
    }

    It 'fails when repository feature binding is reverted to candidate-derived specs authority' {
        $fixtureRoot = New-RuntimeAuditFixture
        $commonPath = Join-Path $fixtureRoot 'studio/scripts/powershell/common.ps1'
        $content = [System.IO.File]::ReadAllText($commonPath)
        $boundExpression = "$" + "specsRoot = [System.IO.Path]::GetFullPath((Join-Path $" + "repoRoot 'specs'))"
        $candidateDerivedExpression = "$" + "specsRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $" + "resolvedFeatureDir))"

        $content.Contains($boundExpression, [System.StringComparison]::Ordinal) |
            Should -BeTrue
        $tampered = $content.Replace(
            $boundExpression,
            $candidateDerivedExpression,
            [System.StringComparison]::Ordinal
        )
        $tampered | Should -Not -BeExactly $content
        [System.IO.File]::WriteAllText(
            $commonPath,
            ($tampered -replace "`r`n?", "`n"),
            [System.Text.UTF8Encoding]::new($false)
        )

        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        @($audit.Result.FAILURES.id) |
            Should -Contain 'common-feature-paths-intent-ledger-awareness'
    }

    It 'fails when feature discovery stops binding branch lookup to the selected repository root' {
        $fixtureRoot = New-RuntimeAuditFixture
        $commonPath = Join-Path $fixtureRoot 'studio/scripts/powershell/common.ps1'
        $content = [System.IO.File]::ReadAllText($commonPath)
        $boundCall = 'Get-CurrentBranch -ProjectRoot $repoRoot'

        $content.Contains($boundCall, [System.StringComparison]::Ordinal) |
            Should -BeTrue
        $tampered = $content.Replace(
            $boundCall,
            'Get-CurrentBranch',
            [System.StringComparison]::Ordinal
        )
        [System.IO.File]::WriteAllText(
            $commonPath,
            ($tampered -replace "`r`n?", "`n"),
            [System.Text.UTF8Encoding]::new($false)
        )

        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        @($audit.Result.FAILURES.id) |
            Should -Contain 'common-feature-paths-intent-ledger-awareness'
    }

    It 'fails when the physical feature-path boundary is removed' {
        $fixtureRoot = New-RuntimeAuditFixture
        $commonPath = Join-Path $fixtureRoot 'studio/scripts/powershell/common.ps1'
        $content = [System.IO.File]::ReadAllText($commonPath)
        $boundCall = 'Resolve-ExistingPathInsideRoot -Root $specsRoot -Candidate $resolvedFeatureDir'

        $content.Contains($boundCall, [System.StringComparison]::Ordinal) |
            Should -BeTrue
        $tampered = $content.Replace(
            $boundCall,
            'Resolve-AbsolutePath -Path $resolvedFeatureDir',
            [System.StringComparison]::Ordinal
        )
        [System.IO.File]::WriteAllText(
            $commonPath,
            ($tampered -replace "`r`n?", "`n"),
            [System.Text.UTF8Encoding]::new($false)
        )

        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        @($audit.Result.FAILURES.id) |
            Should -Contain 'common-feature-paths-intent-ledger-awareness'
    }

    It 'fails when descendant reparse-point rejection is removed from feature binding' {
        $fixtureRoot = New-RuntimeAuditFixture
        $commonPath = Join-Path $fixtureRoot 'studio/scripts/powershell/common.ps1'
        $content = [System.IO.File]::ReadAllText($commonPath)
        $boundCall = 'Assert-NoReparsePointInTree -Root $resolvedFeatureDir'

        $content.Contains($boundCall, [System.StringComparison]::Ordinal) |
            Should -BeTrue
        $tampered = $content.Replace(
            $boundCall,
            'Write-Verbose $resolvedFeatureDir',
            [System.StringComparison]::Ordinal
        )
        [System.IO.File]::WriteAllText(
            $commonPath,
            ($tampered -replace "`r`n?", "`n"),
            [System.Text.UTF8Encoding]::new($false)
        )

        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        @($audit.Result.FAILURES.id) |
            Should -Contain 'common-feature-paths-intent-ledger-awareness'
    }

    It 'fails when Plan stops reusing the discovered absolute FeatureDir' {
        $fixtureRoot = New-RuntimeAuditFixture
        $agentPath = Join-Path $fixtureRoot '.github/agents/speckit.plan.agent.md'
        $content = [System.IO.File]::ReadAllText($agentPath)
        $boundCommand = 'setup-plan.ps1 -FeatureDir "<FEATURE_DIR>" -Json'

        $content.Contains($boundCommand, [System.StringComparison]::Ordinal) |
            Should -BeTrue
        $tampered = $content.Replace(
            $boundCommand,
            'setup-plan.ps1 -FeatureDir <path> -Json',
            [System.StringComparison]::Ordinal
        )
        [System.IO.File]::WriteAllText(
            $agentPath,
            ($tampered -replace "`r`n?", "`n"),
            [System.Text.UTF8Encoding]::new($false)
        )

        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        @($audit.Result.FAILURES.id) |
            Should -Contain 'plan-agent-named-feature-context'
    }

    It 'fails when the Plan checklist handoff drops the resolved FeatureDir' {
        $fixtureRoot = New-RuntimeAuditFixture
        $agentPath = Join-Path $fixtureRoot '.github/agents/speckit.plan.agent.md'
        $content = [System.IO.File]::ReadAllText($agentPath)
        $boundPrompt = 'Create a checklist for the following domain with -FeatureDir <FEATURE_DIR>.'

        $content.Contains($boundPrompt, [System.StringComparison]::Ordinal) |
            Should -BeTrue
        $tampered = $content.Replace(
            $boundPrompt,
            'Create a checklist for the following domain...',
            [System.StringComparison]::Ordinal
        )
        [System.IO.File]::WriteAllText(
            $agentPath,
            ($tampered -replace "`r`n?", "`n"),
            [System.Text.UTF8Encoding]::new($false)
        )

        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        @($audit.Result.FAILURES.id) |
            Should -Contain 'plan-agent-named-feature-context'
    }

    It 'fails when the ECI execution step reintroduces the unnamed gate shorthand' {
        $fixtureRoot = New-RuntimeAuditFixture
        $agentPath = Join-Path $fixtureRoot '.github/agents/speckit.eci.agent.md'
        $mirrorPath = Join-Path $fixtureRoot '.claude/agents/speckit-eci.md'
        $content = [System.IO.File]::ReadAllText($agentPath)
        $boundStep = 'setup-eci.ps1 -FeatureDir "<path>" -Json` entry gate described above as the first action'

        $content.Contains($boundStep, [System.StringComparison]::Ordinal) |
            Should -BeTrue
        $tampered = $content.Replace(
            $boundStep,
            'setup-eci.ps1 -Json` entry gate described above as the first action',
            [System.StringComparison]::Ordinal
        )
        [System.IO.File]::WriteAllText(
            $agentPath,
            ($tampered -replace "`r`n?", "`n"),
            [System.Text.UTF8Encoding]::new($false)
        )
        $mirrorContent = [System.IO.File]::ReadAllText($mirrorPath)
        $mirrorContent.Contains($boundStep, [System.StringComparison]::Ordinal) |
            Should -BeTrue
        [System.IO.File]::WriteAllText(
            $mirrorPath,
            (($mirrorContent.Replace(
                $boundStep,
                'setup-eci.ps1 -Json` entry gate described above as the first action',
                [System.StringComparison]::Ordinal
            )) -replace "`r`n?", "`n"),
            [System.Text.UTF8Encoding]::new($false)
        )

        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        @($audit.Result.FAILURES.id) |
            Should -Contain 'eci-agent-named-feature-context'
        @($audit.Result.FAILURES.id) |
            Should -Not -Contain 'claude-agent-mirror-parity'
    }

    It 'fails when a canonical agent drops the named FeatureDir handoff' {
        $fixtureRoot = New-RuntimeAuditFixture
        $agentPath = Join-Path $fixtureRoot '.github/agents/speckit.tasks.agent.md'
        $content = [System.IO.File]::ReadAllText($agentPath)
        $boundCommand = 'check-prerequisites.ps1 -FeatureDir <path> -Json'

        $content.Contains($boundCommand, [System.StringComparison]::Ordinal) |
            Should -BeTrue
        $tampered = $content.Replace(
            $boundCommand,
            'check-prerequisites.ps1 -Json',
            [System.StringComparison]::Ordinal
        )
        $tampered | Should -Not -BeExactly $content
        [System.IO.File]::WriteAllText(
            $agentPath,
            ($tampered -replace "`r`n?", "`n"),
            [System.Text.UTF8Encoding]::new($false)
        )

        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        @($audit.Result.FAILURES.id) |
            Should -Contain 'tasks-agent-named-feature-context'
    }

    It 'fails when a workflow operator handoff omits the named FeatureDir' {
        $fixtureRoot = New-RuntimeAuditFixture
        $workflowPath = Join-Path $fixtureRoot 'studio/workflows/sdd-pipeline/workflow.yml'
        $content = [System.IO.File]::ReadAllText($workflowPath)
        $boundCommand = '/speckit.analyze -FeatureDir specs/{{ inputs.feature }}'

        $content.Contains($boundCommand, [System.StringComparison]::Ordinal) |
            Should -BeTrue
        $tampered = $content.Replace(
            $boundCommand,
            '/speckit.analyze',
            [System.StringComparison]::Ordinal
        )
        $tampered | Should -Not -BeExactly $content
        [System.IO.File]::WriteAllText(
            $workflowPath,
            ($tampered -replace "`r`n?", "`n"),
            [System.Text.UTF8Encoding]::new($false)
        )

        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        @($audit.Result.FAILURES.id) |
            Should -Contain 'sdd-pipeline-named-feature-context'
    }

    It 'fails when worktree-local hook configuration is reverted to repository-wide config' {
        $fixtureRoot = New-RuntimeAuditFixture
        $commonPath = Join-Path $fixtureRoot 'studio/scripts/powershell/common.ps1'
        $content = Get-Content -LiteralPath $commonPath -Raw
        $content = $content.Replace(
            'config --worktree core.hooksPath',
            'config core.hooksPath'
        )
        [System.IO.File]::WriteAllText(
            $commonPath,
            ($content -replace "`r`n?", "`n"),
            [System.Text.UTF8Encoding]::new($false)
        )
        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        @($audit.Result.FAILURES.id) | Should -Contain 'common-worktree-local-hooks'
    }

    It 'fails when consumer templates stop excluding shared-agent junction roots' {
        $fixtureRoot = New-RuntimeAuditFixture
        $ignorePath = Join-Path $fixtureRoot 'studio/templates/project-init/.gitignore'
        $content = Get-Content -LiteralPath $ignorePath -Raw
        $content = $content.Replace('/.github/agents/', '/.github/runtime-agents/')
        [System.IO.File]::WriteAllText(
            $ignorePath,
            ($content -replace "`r`n?", "`n"),
            [System.Text.UTF8Encoding]::new($false)
        )
        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        @($audit.Result.FAILURES.id) | Should -Contain 'project-template-repository-hygiene-ignore'
    }

    It 'fails when the trusted staged-upgrade audit boundary is removed' {
        $fixtureRoot = New-RuntimeAuditFixture
        $upgradePath = Join-Path $fixtureRoot 'studio/scripts/powershell/upgrade-studio-runtime.ps1'
        $content = Get-Content -LiteralPath $upgradePath -Raw
        $content = $content.Replace(
            'function New-TrustedUpgradeAuditBundle',
            'function New-DisabledUpgradeAuditBundle'
        )
        [System.IO.File]::WriteAllText(
            $upgradePath,
            ($content -replace "`r`n?", "`n"),
            [System.Text.UTF8Encoding]::new($false)
        )
        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        @($audit.Result.FAILURES.id) | Should -Contain 'upgrade-runtime-transaction-boundary'
    }

    It 'fails when extension JSON schema enforcement is replaced by a constant verdict' {
        $fixtureRoot = New-RuntimeAuditFixture
        $helperPath = Join-Path $fixtureRoot 'studio/scripts/powershell/extension-registry-common.ps1'
        $content = Get-Content -LiteralPath $helperPath -Raw
        $content = $content.Replace(
            'Test-Json -Json $raw -Schema $schema -ErrorAction Stop',
            '$true'
        )
        [System.IO.File]::WriteAllText(
            $helperPath,
            ($content -replace "`r`n?", "`n"),
            [System.Text.UTF8Encoding]::new($false)
        )
        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        @($audit.Result.FAILURES.id) | Should -Contain 'extension-registry-schema-path-and-transaction-helpers'
    }

    It 'fails when extension recovery journaling is removed' {
        $fixtureRoot = New-RuntimeAuditFixture
        $helperPath = Join-Path $fixtureRoot 'studio/scripts/powershell/extension-registry-common.ps1'
        $content = Get-Content -LiteralPath $helperPath -Raw
        $content = $content.Replace(
            'function Write-ExtensionTransactionRecoveryJournal',
            'function Write-DisabledExtensionTransactionRecoveryJournal'
        )
        [System.IO.File]::WriteAllText(
            $helperPath,
            ($content -replace "`r`n?", "`n"),
            [System.Text.UTF8Encoding]::new($false)
        )
        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        @($audit.Result.FAILURES.id) | Should -Contain 'extension-registry-schema-path-and-transaction-helpers'
    }

    It 'fails when extension baseline restore stops using atomic replacement' {
        $fixtureRoot = New-RuntimeAuditFixture
        $helperPath = Join-Path $fixtureRoot 'studio/scripts/powershell/extension-registry-common.ps1'
        $content = Get-Content -LiteralPath $helperPath -Raw
        $content = $content.Replace(
            '[System.IO.File]::Move($temporaryPath, $sourcePath, $true)',
            '[System.IO.File]::Copy($temporaryPath, $sourcePath, $true)'
        )
        [System.IO.File]::WriteAllText(
            $helperPath,
            ($content -replace "`r`n?", "`n"),
            [System.Text.UTF8Encoding]::new($false)
        )
        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        @($audit.Result.FAILURES.id) | Should -Contain 'extension-registry-schema-path-and-transaction-helpers'
    }

    It 'fails when the frozen trusted candidate-verification boundary is removed' {
        $fixtureRoot = New-RuntimeAuditFixture
        $upgradePath = Join-Path $fixtureRoot 'studio/scripts/powershell/upgrade-studio-runtime.ps1'
        $content = Get-Content -LiteralPath $upgradePath -Raw
        $content = $content.Replace(
            'function Invoke-UpgradeTrustedCandidateVerification',
            'function Invoke-DisabledUpgradeTrustedCandidateVerification'
        )
        [System.IO.File]::WriteAllText(
            $upgradePath,
            ($content -replace "`r`n?", "`n"),
            [System.Text.UTF8Encoding]::new($false)
        )
        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        @($audit.Result.FAILURES.id) | Should -Contain 'upgrade-runtime-transaction-boundary'
    }

    It 'fails when upgrade rollback stops binding restoration to the baseline hash' {
        $fixtureRoot = New-RuntimeAuditFixture
        $upgradePath = Join-Path $fixtureRoot 'studio/scripts/powershell/upgrade-studio-runtime.ps1'
        $content = Get-Content -LiteralPath $upgradePath -Raw
        $content = $content.Replace(
            '-ExpectedSha256 ([string]$record.hash)',
            '-ExpectedSha256 (Get-FileSha256 -Path ([string]$record.backup))'
        )
        [System.IO.File]::WriteAllText(
            $upgradePath,
            ($content -replace "`r`n?", "`n"),
            [System.Text.UTF8Encoding]::new($false)
        )
        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        @($audit.Result.FAILURES.id) | Should -Contain 'upgrade-runtime-transaction-boundary'
    }

    It 'fails when retained extension recovery evidence is no longer ignored' {
        $fixtureRoot = New-RuntimeAuditFixture
        $ignorePath = Join-Path $fixtureRoot '.gitignore'
        $content = Get-Content -LiteralPath $ignorePath -Raw
        $content = $content.Replace(
            '/resources/studio-runtime/.extension-transactions/',
            '/resources/studio-runtime/.disabled-extension-transactions/'
        )
        [System.IO.File]::WriteAllText(
            $ignorePath,
            ($content -replace "`r`n?", "`n"),
            [System.Text.UTF8Encoding]::new($false)
        )
        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        @($audit.Result.FAILURES.id) | Should -Contain 'workspace-repository-hygiene-ignore'
    }

    It 'fails when the canonical aggregate readiness note is redirected' {
        $fixtureRoot = New-RuntimeAuditFixture
        $contractPath = Join-Path $fixtureRoot 'studio/runtime/shared-runtime-contract.json'
        $contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
        $contract.mainlineReadiness.aggregateNotePaths = @(
            'docs/mainline-updates/2026-07-18-rb-2-execution-identity-and-eci-routing.md'
        )
        $contract | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $contractPath -Encoding utf8
        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        @($audit.Result.FAILURES.id) | Should -Contain 'required-mainline-readiness-policy-missing'
    }

    It 'fails when a Ready mainline note has no concrete commit or PR evidence' {
        $fixtureRoot = New-RuntimeAuditFixture
        $notePath = Join-Path $fixtureRoot 'docs/mainline-updates/2026-07-13-r1-validation-and-merge-enforcement.md'
        $noteContent = Get-Content -LiteralPath $notePath -Raw
        $noteContent = $noteContent -replace '(?m)^\*\*Status\*\*:.*$', '**Status**: Ready'
        $noteContent = $noteContent -replace '(?m)^\*\*Related Commits\*\*:.*$', '**Related Commits**: TBD'
        $noteContent = $noteContent -replace '(?m)^\*\*Related PR\*\*:.*$', '**Related PR**: N/A'
        $noteContent | Should -Match '(?m)^\*\*Status\*\*: Ready$'
        $noteContent | Should -Match '(?m)^\*\*Related Commits\*\*: TBD$'
        $noteContent | Should -Match '(?m)^\*\*Related PR\*\*: N/A$'
        [System.IO.File]::WriteAllText($notePath, ($noteContent -replace "`r`n?", "`n"), [System.Text.UTF8Encoding]::new($false))

        $indexPath = Join-Path $fixtureRoot 'docs/mainline-updates/README.md'
        $indexContent = Get-Content -LiteralPath $indexPath -Raw
        $indexContent = $indexContent -replace '(?m)(r1-validation-and-merge-enforcement.*\| `feature/wave-3-security-and-workflows` \| )(?:Draft|Ready|Merged)( \|)', '$1Ready$2'
        [System.IO.File]::WriteAllText($indexPath, ($indexContent -replace "`r`n?", "`n"), [System.Text.UTF8Encoding]::new($false))

        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        @($audit.Result.FAILURES.id) | Should -Contain 'ready-evidence'
        $audit.Result.MAINLINE_NOTE_VALID | Should -BeFalse
    }

    It 'fails when Governance CI no longer invokes branch reconciliation' {
        $fixtureRoot = New-RuntimeAuditFixture
        $workflowPath = Join-Path $fixtureRoot '.github/workflows/governance.yml'
        $workflowContent = Get-Content -LiteralPath $workflowPath -Raw
        $workflowContent = $workflowContent.Replace('validate-mainline-notes.ps1', 'removed-mainline-validator.ps1')
        [System.IO.File]::WriteAllText($workflowPath, ($workflowContent -replace "`r`n?", "`n"), [System.Text.UTF8Encoding]::new($false))

        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        @($audit.Result.FAILURES.id) | Should -Contain 'governance-ci-enforcement'
    }

    It 'fails when retired extension compatibility fields are reintroduced' {
        $fixtureRoot = New-RuntimeAuditFixture
        $manifestPath = Join-Path $fixtureRoot 'studio/extensions/extension-smoke/manifest.json'
        $content = [System.IO.File]::ReadAllText($manifestPath)
        $currentCompatibility = '"compatibility": {' + "`n" + '    "mode": "studio-first"' + "`n" + '  }'
        $reintroducedCompatibility = '"compatibility": {' + "`n" + '    "mode": "studio-first",' + "`n" + '    "minStudioConstitutionVersion": "1.3.0",' + "`n" + '    "minWorkspaceStructureVersion": "1.2.0"' + "`n" + '  }'
        $content.Contains($currentCompatibility, [System.StringComparison]::Ordinal) |
            Should -BeTrue
        $tampered = $content.Replace(
            $currentCompatibility,
            $reintroducedCompatibility,
            [System.StringComparison]::Ordinal
        )
        [System.IO.File]::WriteAllText(
            $manifestPath,
            ($tampered -replace "`r`n?", "`n"),
            [System.Text.UTF8Encoding]::new($false)
        )

        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        @($audit.Result.FAILURES.id) |
            Should -Contain 'extension-smoke-compatibility-field-retirement'
    }

    It 'fails when retired workflow compatibility fields are reintroduced' {
        $tamperingCases = @(
            @{
                Field = 'minStudioConstitutionVersion'
                ExpectedFailure = 'sdd-pipeline-compatibility-field-retirement'
            },
            @{
                Field = 'MinStudioConstitutionVersion'
                ExpectedFailure = 'workflow-registry-invalid'
            }
        )

        foreach ($case in $tamperingCases) {
            $fixtureRoot = New-RuntimeAuditFixture
            $manifestPath = Join-Path $fixtureRoot 'studio/workflows/sdd-pipeline/manifest.json'
            $content = [System.IO.File]::ReadAllText($manifestPath)
            $currentCompatibility = '"compatibility": {' + "`n" + '    "mode": "studio-first"' + "`n" + '  }'
            $reintroducedCompatibility = '"compatibility": {' + "`n" + '    "mode": "studio-first",' + "`n" +
                ('    "' + $case.Field + '": "1.8.0"') + "`n" + '  }'
            $content.Contains($currentCompatibility, [System.StringComparison]::Ordinal) |
                Should -BeTrue
            $tampered = $content.Replace(
                $currentCompatibility,
                $reintroducedCompatibility,
                [System.StringComparison]::Ordinal
            )
            [System.IO.File]::WriteAllText(
                $manifestPath,
                ($tampered -replace "`r`n?", "`n"),
                [System.Text.UTF8Encoding]::new($false)
            )

            $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

            $audit.ExitCode | Should -Not -Be 0
            @($audit.Result.FAILURES.id) |
                Should -Contain $case.ExpectedFailure
        }
    }

    It 'fails when the retired extension sync source is restored in shared parsing' {
        $fixtureRoot = New-RuntimeAuditFixture
        $commonPath = Join-Path $fixtureRoot 'studio/scripts/powershell/common.ps1'
        $content = [System.IO.File]::ReadAllText($commonPath)
        $retiredSourceSet = "return @('default', 'manual')"
        $legacySourceSet = "return @('default', 'manual', 'sync')"
        $content.Contains($retiredSourceSet, [System.StringComparison]::Ordinal) |
            Should -BeTrue
        $tampered = $content.Replace(
            $retiredSourceSet,
            $legacySourceSet,
            [System.StringComparison]::Ordinal
        )
        [System.IO.File]::WriteAllText(
            $commonPath,
            ($tampered -replace "`r`n?", "`n"),
            [System.Text.UTF8Encoding]::new($false)
        )

        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        @($audit.Result.FAILURES.id) |
            Should -Contain 'extension-shared-state-source-retirement'
    }

    It 'fails when the retired workflow sync source is restored in the catalog schema' {
        $fixtureRoot = New-RuntimeAuditFixture
        $schemaPath = Join-Path $fixtureRoot 'studio/workflows/catalog.schema.json'
        $content = [System.IO.File]::ReadAllText($schemaPath)
        $retiredSourceSet = '"enum": ["default", "manual"]'
        $legacySourceSet = '"enum": ["default", "manual", "sync"]'
        $content.Contains($retiredSourceSet, [System.StringComparison]::Ordinal) |
            Should -BeTrue
        $tampered = $content.Replace(
            $retiredSourceSet,
            $legacySourceSet,
            [System.StringComparison]::Ordinal
        )
        [System.IO.File]::WriteAllText(
            $schemaPath,
            ($tampered -replace "`r`n?", "`n"),
            [System.Text.UTF8Encoding]::new($false)
        )

        $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot

        $audit.ExitCode | Should -Not -Be 0
        @($audit.Result.FAILURES.id) |
            Should -Contain 'workflow-catalog-state-source-retirement'
    }
}

Describe 'governance test coverage configuration' {
    It 'supports Cobertura coverage for the shared PowerShell scripts' {
        $runnerContent = Get-Content -LiteralPath (Join-Path $WorkspaceRoot 'studio/scripts/powershell/run-governance-tests.ps1') -Raw

        $runnerContent | Should -Match '\[switch\]\$CodeCoverage'
        $runnerContent | Should -Match "CodeCoverage\.OutputFormat\s*=\s*'Cobertura'"
        $runnerContent | Should -Match "codeCoverage\.xml"
        $runnerContent | Should -Match 'Run\.Exit\s*=\s*\$true'
        $runnerContent | Should -Match 'Import-Module Pester -RequiredVersion 5\.7\.1'
    }

    It 'enables coverage in the governance CI job and uploads the artifacts directory' {
        $workflowContent = Get-Content -LiteralPath (Join-Path $WorkspaceRoot '.github/workflows/governance.yml') -Raw

        $workflowContent | Should -Match 'run-governance-tests\.ps1 -Output Normal -CodeCoverage'
        $workflowContent | Should -Match 'path:\s*studio/tests/_artifacts/'
        ([regex]::Matches($workflowContent, 'validate-mainline-notes\.ps1 .*?-RequireReady')).Count | Should -Be 2
        $workflowContent | Should -Match 'actions/checkout@9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0'
        $workflowContent | Should -Match 'actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a'
    }

    It 'keeps coverage out of the required push and pull-request gate' {
        $workflowContent = Get-Content -LiteralPath (Join-Path $WorkspaceRoot '.github/workflows/governance.yml') -Raw

        $workflowContent | Should -Match 'timeout-minutes:\s*120'
        $workflowContent | Should -Match "(?s)name: Governance tests \(Pester\)\s*\r?\n\s*if: github\.event_name == 'push' \|\| github\.event_name == 'pull_request'.*?run-governance-tests\.ps1 -Output Normal\s*\r?\n"
        $workflowContent | Should -Match "(?s)name: Governance tests with coverage \(schedule and dispatch\)\s*\r?\n\s*if: github\.event_name == 'schedule' \|\| github\.event_name == 'workflow_dispatch'.*?run-governance-tests\.ps1 -Output Normal -CodeCoverage"
        ([regex]::Matches($workflowContent, '-CodeCoverage')).Count | Should -Be 1
    }
}

Describe 'workspace README truthfulness' {
    It 'discloses that consumer directories are untracked and absent from a public clone' {
        $readmeContent = Get-Content -LiteralPath (Join-Path $WorkspaceRoot 'README.md') -Raw

        $readmeContent | Should -Match '`learning/` 與 `projects/` 是本機的 consumer 工作目錄'
        $readmeContent | Should -Match '被 `\.gitignore` 排除、不納入本 repo 版本控制'
        $readmeContent | Should -Match '公開 clone 不會包含任何練習或交付專案內容'
        $readmeContent | Should -Not -Match '`learning/` 與 `projects/` 放實際練習和交付專案'
    }
}

Describe 'runtime audit fixture output decoding' {
    It 'preserves non-ASCII child audit output when the parent console uses code page 950' {
        $fixtureRoot = Join-Path $TestDrive ("encoding-fixture-{0}" -f ([System.Guid]::NewGuid().ToString('N')))
        $stubDirectory = Join-Path $fixtureRoot 'studio/scripts/powershell'
        New-Item -ItemType Directory -Path $stubDirectory -Force | Out-Null
        $stubScript = Join-Path $stubDirectory 'check-speckit-runtime.ps1'
        $expectedMessage = 'prohibited text: `.claude/agents/` 是 Claude shared runtime source of truth。這是層級檢查'
        $stubLines = @(
            'param([switch]$Json)',
            'if ([Console]::IsOutputRedirected) {',
            '    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)',
            '}',
            '$payload = [ordered]@{',
            '    VALID = $false',
            '    ERROR_COUNT = 1',
            ("    MESSAGE = '{0}'" -f $expectedMessage),
            '}',
            '$payload | ConvertTo-Json',
            'exit 1'
        )
        [System.IO.File]::WriteAllText(
            $stubScript,
            (($stubLines -join "`n") + "`n"),
            [System.Text.UTF8Encoding]::new($true)
        )

        $previousOutputEncoding = [Console]::OutputEncoding
        try {
            [Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding(950)
            $audit = Invoke-RuntimeAuditFixture -FixtureRoot $fixtureRoot
        } finally {
            [Console]::OutputEncoding = $previousOutputEncoding
        }

        $audit.ExitCode | Should -Be 1
        $audit.Result.VALID | Should -BeFalse
        $audit.Result.MESSAGE | Should -BeExactly $expectedMessage
    }
}
