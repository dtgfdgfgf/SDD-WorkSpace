#!/usr/bin/env pwsh
#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/governance.config.ps1"

    $script:syncScript = Join-Path $WorkspaceRoot 'studio/scripts/powershell/sync-agent-bootstrap.ps1'
    $script:checkScript = Join-Path $WorkspaceRoot 'studio/scripts/powershell/check-agent-bootstrap.ps1'
    $script:beginMarker = '<!-- BEGIN GENERATED GOVERNANCE BOOTSTRAP -->'
    $script:endMarker = '<!-- END GENERATED GOVERNANCE BOOTSTRAP -->'

    $script:newAgentBootstrapFixtureProject = {
        param([string]$Root)
    New-Item -ItemType Directory -Path (Join-Path $Root '.specify/memory') -Force | Out-Null
    @"
# Project Constitution: Fixture

**Version:** 1.0.0

## Purpose

Fixture project constitution.

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-04-27 | Initial fixture |
"@ | Set-Content -LiteralPath (Join-Path $Root '.specify/memory/constitution.md') -Encoding utf8
    }

    $script:getGeneratedBlockForTest = {
        param([string]$Path)

        $content = Get-Content -LiteralPath $Path -Raw
        $pattern = '(?s)' + [regex]::Escape($script:beginMarker) + '.*?' + [regex]::Escape($script:endMarker)
        $match = [regex]::Match($content, $pattern)
        if (-not $match.Success) {
            return $null
        }
        return $match.Value.Trim()
    }
}

Describe 'agent bootstrap scripts' {
    BeforeEach {
        $script:projectRoot = Join-Path $TestDrive 'fixture-project'
        New-Item -ItemType Directory -Path $script:projectRoot -Force | Out-Null
        & $script:newAgentBootstrapFixtureProject -Root $script:projectRoot
    }

    It 'creates three runtime adapters with identical generated governance blocks' {
        $output = pwsh -NoProfile -File $script:syncScript -ProjectRoot $script:projectRoot -ProjectName fixture-project -ProjectType Internal -Write -Json
        $LASTEXITCODE | Should -Be 0
        $result = ($output -join [Environment]::NewLine) | ConvertFrom-Json
        $result.CHANGED_COUNT | Should -Be 3

        $agentsPath = Join-Path $script:projectRoot 'AGENTS.md'
        $claudePath = Join-Path $script:projectRoot 'CLAUDE.md'
        $copilotPath = Join-Path $script:projectRoot '.github/copilot-instructions.md'

        $agentsPath | Should -Exist
        $claudePath | Should -Exist
        $copilotPath | Should -Exist

        $agentBlock = & $script:getGeneratedBlockForTest -Path $agentsPath
        $claudeBlock = & $script:getGeneratedBlockForTest -Path $claudePath
        $copilotBlock = & $script:getGeneratedBlockForTest -Path $copilotPath

        $agentBlock | Should -Not -BeNullOrEmpty
        $claudeBlock | Should -Be $agentBlock
        $copilotBlock | Should -Be $agentBlock

        Get-Content -LiteralPath $claudePath -Raw | Should -Match '(?m)^@.*studio/constitution/constitution\.md\s*$'
        Get-Content -LiteralPath $claudePath -Raw | Should -Match '(?m)^@\.specify/memory/constitution\.md\s*$'
    }

    It 'fails check when one generated block drifts' {
        pwsh -NoProfile -File $script:syncScript -ProjectRoot $script:projectRoot -Write -Json | Out-Null
        $agentsPath = Join-Path $script:projectRoot 'AGENTS.md'
        $content = Get-Content -LiteralPath $agentsPath -Raw
        $content = $content -replace 'If documents conflict, flag drift instead of silently choosing\.', 'If documents conflict, flag drift and stop.'
        Set-Content -LiteralPath $agentsPath -Value $content -NoNewline -Encoding utf8

        $output = pwsh -NoProfile -File $script:checkScript -ProjectRoot $script:projectRoot -Json
        $LASTEXITCODE | Should -Not -Be 0
        $result = ($output -join [Environment]::NewLine) | ConvertFrom-Json
        $result.VALID | Should -BeFalse
        @($result.FAILURES.id) | Should -Contain 'bootstrap-block-drift'
    }

    It 'syncs shared block from one adapter to the other two' {
        pwsh -NoProfile -File $script:syncScript -ProjectRoot $script:projectRoot -Write -Json | Out-Null
        $agentsPath = Join-Path $script:projectRoot 'AGENTS.md'
        $claudePath = Join-Path $script:projectRoot 'CLAUDE.md'
        $copilotPath = Join-Path $script:projectRoot '.github/copilot-instructions.md'

        $content = Get-Content -LiteralPath $agentsPath -Raw
        $content = $content -replace 'If documents conflict, flag drift instead of silently choosing\.', 'If documents conflict, flag drift and stop.'
        Set-Content -LiteralPath $agentsPath -Value $content -NoNewline -Encoding utf8

        pwsh -NoProfile -File $script:syncScript -ProjectRoot $script:projectRoot -From $agentsPath -Write -Json | Out-Null
        $LASTEXITCODE | Should -Be 0

        $agentBlock = & $script:getGeneratedBlockForTest -Path $agentsPath
        & $script:getGeneratedBlockForTest -Path $claudePath | Should -Be $agentBlock
        & $script:getGeneratedBlockForTest -Path $copilotPath | Should -Be $agentBlock

        $checkOutput = pwsh -NoProfile -File $script:checkScript -ProjectRoot $script:projectRoot -Json
        $LASTEXITCODE | Should -Be 0
        (($checkOutput -join [Environment]::NewLine) | ConvertFrom-Json).VALID | Should -BeTrue
    }
}
