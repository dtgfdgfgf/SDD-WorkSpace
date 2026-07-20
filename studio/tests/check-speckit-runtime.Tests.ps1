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
        if ($WithoutYamlModule) {
            $output = & pwsh -NoProfile -Command '& { param($audit) $env:PSModulePath = ''C:\__sdd_fixture_no_modules__''; & $audit -Json; exit $LASTEXITCODE }' $fixtureAuditScript 2>&1
        } else {
            $output = & pwsh -NoProfile -File $fixtureAuditScript -Json 2>&1
        }
        $exitCode = $LASTEXITCODE
        $raw = $output -join [Environment]::NewLine

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
}
