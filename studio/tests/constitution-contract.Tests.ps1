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
    It 'Current Phase date is within last 3 months' {
        $constitution | Should -Match 'Current Phase.*\(as of (\d{4}-\d{2})\)'
        $dateMatch = [regex]::Match($constitution, 'as of (\d{4}-\d{2})')
        $phaseDate = [datetime]::ParseExact($dateMatch.Groups[1].Value, 'yyyy-MM', $null)
        $monthsAgo = ((Get-Date) - $phaseDate).TotalDays / 30
        $monthsAgo | Should -BeLessThan 3 -Because 'phase declaration should be reviewed at least quarterly'
    }
}

Describe 'requiredMirrorPairs removed' {
    It 'contract no longer contains requiredMirrorPairs' {
        $contract.ContainsKey('requiredMirrorPairs') | Should -BeFalse -Because 'sdd-agents template mirror layer has been removed'
    }
}
