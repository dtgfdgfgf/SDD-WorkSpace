#!/usr/bin/env pwsh
#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/governance.config.ps1"

    $script:seedScriptSource = Join-Path $WorkspaceRoot 'studio/scripts/powershell/seed-claude-agents.ps1'
    $script:commonScriptSource = Join-Path $WorkspaceRoot 'studio/scripts/powershell/common.ps1'

    function script:Write-AgentFixtureFile {
        param(
            [Parameter(Mandatory)]
            [string]$Path,
            [Parameter(Mandatory)]
            [AllowEmptyString()]
            [string]$Content
        )

        $parent = Split-Path -Parent $Path
        if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        [System.IO.File]::WriteAllText(
            $Path,
            (($Content -replace "`r`n?", "`n").TrimEnd([char[]]@("`n")) + "`n"),
            [System.Text.UTF8Encoding]::new($false)
        )
    }

    function script:New-ClaudeSeedFixture {
        $fixtureRoot = Join-Path $TestDrive ("claude-seed-{0}" -f [System.Guid]::NewGuid().ToString('N'))
        $fixtureScriptDir = Join-Path $fixtureRoot 'studio/scripts/powershell'
        $fixtureSourceDir = Join-Path $fixtureRoot '.github/agents'
        New-Item -ItemType Directory -Path $fixtureScriptDir,$fixtureSourceDir -Force | Out-Null
        Copy-Item -LiteralPath $script:seedScriptSource -Destination $fixtureScriptDir
        Copy-Item -LiteralPath $script:commonScriptSource -Destination $fixtureScriptDir
        return $fixtureRoot
    }

    function script:Invoke-ClaudeSeedFixture {
        param(
            [Parameter(Mandatory)]
            [string]$FixtureRoot,
            [switch]$Verify
        )

        $pwshPath = (Get-Command pwsh -ErrorAction Stop).Source
        $processInfo = [System.Diagnostics.ProcessStartInfo]::new()
        $processInfo.FileName = $pwshPath
        $processInfo.UseShellExecute = $false
        $processInfo.RedirectStandardOutput = $true
        $processInfo.RedirectStandardError = $true
        $processInfo.CreateNoWindow = $true
        foreach ($argument in @(
            '-NoProfile',
            '-File',
            (Join-Path $FixtureRoot 'studio/scripts/powershell/seed-claude-agents.ps1'),
            '-WorkspaceRoot',
            $FixtureRoot
        )) {
            [void]$processInfo.ArgumentList.Add($argument)
        }
        if ($Verify) {
            [void]$processInfo.ArgumentList.Add('-Verify')
        }
        [void]$processInfo.ArgumentList.Add('-Json')

        $process = [System.Diagnostics.Process]::new()
        $process.StartInfo = $processInfo
        [void]$process.Start()
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()

        $parsed = $null
        if (-not [string]::IsNullOrWhiteSpace($stdout)) {
            $parsed = $stdout | ConvertFrom-Json
        }

        return [PSCustomObject]@{
            ExitCode = $process.ExitCode
            Result   = $parsed
            Stdout   = $stdout
            Stderr   = $stderr
        }
    }

    function script:Add-BasicAgentSource {
        param(
            [Parameter(Mandatory)]
            [string]$FixtureRoot,
            [string]$FileName = 'fixture.agent.md'
        )

        $sourcePath = Join-Path $FixtureRoot ".github/agents/$FileName"
        Write-AgentFixtureFile -Path $sourcePath -Content @'
---
name: fixture
description: Fixture agent
tools: ['read', 'grep']
---

Fixture body.
'@
    }
}

Describe 'Specify agent clarification truthfulness' {
    It 'keeps every material marker and hands off only to Clarify in source and generated mirror' {
        foreach ($path in @(
            (Join-Path $WorkspaceRoot '.github/agents/speckit.specify.agent.md'),
            (Join-Path $WorkspaceRoot '.claude/agents/speckit-specify.md')
        )) {
            $content = Get-Content -LiteralPath $path -Raw
            $content | Should -Match ([regex]::Escape('Every material marker MUST remain in the specification and MUST be presented for user resolution; do not cap, discard, or answer any marker by guessing.'))
            $content | Should -Match ([regex]::Escape('`/speckit.clarify` is the only next-phase handoff from Specify; do not route directly to `/speckit.readiness`.'))
            $content | Should -Not -Match '\*\*LIMIT CHECK\*\*'
            $content | Should -Not -Match 'make informed guesses for the rest'
            $content | Should -Not -Match 'For each clarification needed \(max 3\)'
            $content | Should -Not -Match 'Q1, Q2, Q3 - max 3 total'
            $content | Should -Not -Match 'readiness for the next phase \(`/speckit\.clarify` or `/speckit\.readiness`\)'
            $content | Should -Not -Match ([regex]::Escape('`/speckit.clarify` or `/speckit.readiness`'))
            $content | Should -Not -Match '(?i)before\s+`?/speckit\.clarify`?\s+or\s+`?/speckit\.readiness`?'
        }
    }

    It 'never presents Readiness as an alternative direct handoff from Specify' {
        foreach ($path in @(
            (Join-Path $WorkspaceRoot '.github/agents/speckit.specify.agent.md'),
            (Join-Path $WorkspaceRoot '.claude/agents/speckit-specify.md')
        )) {
            $content = Get-Content -LiteralPath $path -Raw
            $content | Should -Not -Match ([regex]::Escape('`/speckit.clarify` or `/speckit.readiness`'))
            $content | Should -Not -Match '(?i)before\s+`?/speckit\.clarify`?\s+or\s+`?/speckit\.readiness`?'
        }
    }
}

Describe 'Implement task priority and parallelism truthfulness' {
    BeforeAll {
        $script:implementAgentPaths = @(
            (Join-Path $WorkspaceRoot '.github/agents/speckit.implement.agent.md'),
            (Join-Path $WorkspaceRoot '.claude/agents/speckit-implement.md')
        )
    }

    It 'treats P-number labels as priority and reads parallelism only from separate dependency metadata' {
        foreach ($path in $script:implementAgentPaths) {
            $content = Get-Content -LiteralPath $path -Raw
            $content | Should -Match ([regex]::Escape('Read `Dependencies`, `Parallel Execution Examples`, and any `Parallel with: T0xx, T0yy` follow-up lines'))
            $content | Should -Match ([regex]::Escape('Do not infer parallel execution from `[P]` or `[P#]` checklist tokens. `[P#]` is delivery priority; inline `[P]` is invalid.'))
            $content | Should -Match ([regex]::Escape('only tasks explicitly declared parallel by the separate dependency/parallelism metadata can run together'))
        }
    }

    It 'rejects the pre-R-D03 inline parallel-marker instructions' {
        $legacyInstructions = @(
            'parallel markers [P]',
            'parallel tasks [P] can run together',
            'For parallel tasks [P]',
            'any non-parallel task fails'
        )

        foreach ($path in $script:implementAgentPaths) {
            $content = Get-Content -LiteralPath $path -Raw
            foreach ($legacyInstruction in $legacyInstructions) {
                $content | Should -Not -Match ([regex]::Escape($legacyInstruction))
            }
        }
    }
}

Describe 'Canonical Claude tool mappings' {
    It 'keeps the Spec Kit QA bot mapping repo-bounded without WebSearch' {
        $source = Get-Content -LiteralPath (Join-Path $WorkspaceRoot '.github/agents/spec-kit.agent.md') -Raw
        $mirror = Get-Content -LiteralPath (Join-Path $WorkspaceRoot '.claude/agents/spec-kit-qa-bot.md') -Raw

        $source | Should -Match ([regex]::Escape("claude-tools: ['Read', 'Glob', 'Grep', 'WebFetch']"))
        $source | Should -Not -Match '(?m)^claude-tools:.*\bWebSearch\b'
        $mirror | Should -Match '(?m)^tools: Read, Glob, Grep, WebFetch$'
        $mirror | Should -Not -Match '(?m)^tools:.*\bWebSearch\b'
    }
}

Describe 'seed-claude-agents deterministic parity and tool safety' {
    It 'accepts line-ending-only differences in a deterministically seeded mirror' {
        $fixtureRoot = New-ClaudeSeedFixture
        Add-BasicAgentSource -FixtureRoot $fixtureRoot

        $seed = Invoke-ClaudeSeedFixture -FixtureRoot $fixtureRoot
        $seed.ExitCode | Should -Be 0 -Because ($seed.Stdout + $seed.Stderr)
        $mirrorPath = Join-Path $fixtureRoot '.claude/agents/fixture.md'
        $content = [System.IO.File]::ReadAllText($mirrorPath)
        [System.IO.File]::WriteAllText(
            $mirrorPath,
            ($content -replace "`n", "`r`n"),
            [System.Text.UTF8Encoding]::new($false)
        )

        $verify = Invoke-ClaudeSeedFixture -FixtureRoot $fixtureRoot -Verify
        $verify.ExitCode | Should -Be 0 -Because ($verify.Stdout + $verify.Stderr)
        $verify.Result.VALID | Should -BeTrue
        $verify.Result.MODE | Should -Be 'verify'
    }

    It 'rejects a blank generated mirror' {
        $fixtureRoot = New-ClaudeSeedFixture
        Add-BasicAgentSource -FixtureRoot $fixtureRoot
        (Invoke-ClaudeSeedFixture -FixtureRoot $fixtureRoot).ExitCode | Should -Be 0
        $mirrorPath = Join-Path $fixtureRoot '.claude/agents/fixture.md'
        [System.IO.File]::WriteAllText($mirrorPath, '', [System.Text.UTF8Encoding]::new($false))

        $verify = Invoke-ClaudeSeedFixture -FixtureRoot $fixtureRoot -Verify
        $verify.ExitCode | Should -Not -Be 0
        $verify.Result.VALID | Should -BeFalse
        @($verify.Result.ERRORS.id) | Should -Contain 'claude-agent-content-drift'
    }

    It 'rejects body drift in a generated mirror' {
        $fixtureRoot = New-ClaudeSeedFixture
        Add-BasicAgentSource -FixtureRoot $fixtureRoot
        (Invoke-ClaudeSeedFixture -FixtureRoot $fixtureRoot).ExitCode | Should -Be 0
        $mirrorPath = Join-Path $fixtureRoot '.claude/agents/fixture.md'
        $content = [System.IO.File]::ReadAllText($mirrorPath)
        [System.IO.File]::WriteAllText(
            $mirrorPath,
            ($content + "`nTampered body.`n"),
            [System.Text.UTF8Encoding]::new($false)
        )

        $verify = Invoke-ClaudeSeedFixture -FixtureRoot $fixtureRoot -Verify
        $verify.ExitCode | Should -Not -Be 0
        @($verify.Result.ERRORS.id) | Should -Contain 'claude-agent-content-drift'
    }

    It 'rejects frontmatter drift in a generated mirror' {
        $fixtureRoot = New-ClaudeSeedFixture
        Add-BasicAgentSource -FixtureRoot $fixtureRoot
        (Invoke-ClaudeSeedFixture -FixtureRoot $fixtureRoot).ExitCode | Should -Be 0
        $mirrorPath = Join-Path $fixtureRoot '.claude/agents/fixture.md'
        $content = [System.IO.File]::ReadAllText($mirrorPath)
        $content = $content.Replace('tools: Read, Grep', 'tools: Read')
        [System.IO.File]::WriteAllText($mirrorPath, $content, [System.Text.UTF8Encoding]::new($false))

        $verify = Invoke-ClaudeSeedFixture -FixtureRoot $fixtureRoot -Verify
        $verify.ExitCode | Should -Not -Be 0
        @($verify.Result.ERRORS.id) | Should -Contain 'claude-agent-content-drift'
    }

    It 'rejects missing and unexpected generated mirrors' {
        $fixtureRoot = New-ClaudeSeedFixture
        Add-BasicAgentSource -FixtureRoot $fixtureRoot
        (Invoke-ClaudeSeedFixture -FixtureRoot $fixtureRoot).ExitCode | Should -Be 0
        $mirrorPath = Join-Path $fixtureRoot '.claude/agents/fixture.md'
        Remove-Item -LiteralPath $mirrorPath -Force
        Write-AgentFixtureFile -Path (Join-Path $fixtureRoot '.claude/agents/rogue.md') -Content '# Rogue'

        $verify = Invoke-ClaudeSeedFixture -FixtureRoot $fixtureRoot -Verify
        $verify.ExitCode | Should -Not -Be 0
        @($verify.Result.ERRORS.id) | Should -Contain 'claude-agent-mirror-missing'
        @($verify.Result.ERRORS.id) | Should -Contain 'claude-agent-mirror-unexpected'
    }

    It 'rejects nested files and directories in the flat generated authority' {
        $fixtureRoot = New-ClaudeSeedFixture
        Add-BasicAgentSource -FixtureRoot $fixtureRoot
        (Invoke-ClaudeSeedFixture -FixtureRoot $fixtureRoot).ExitCode | Should -Be 0
        Write-AgentFixtureFile -Path (Join-Path $fixtureRoot '.claude/agents/nested/rogue.md') -Content '# Nested rogue'

        $verify = Invoke-ClaudeSeedFixture -FixtureRoot $fixtureRoot -Verify
        $verify.ExitCode | Should -Not -Be 0
        @($verify.Result.ERRORS.id) | Should -Contain 'claude-agent-mirror-unexpected-directory'
        @($verify.Result.ERRORS.id) | Should -Contain 'claude-agent-mirror-unexpected'
    }

    It 'fails unknown tool mappings before writing any mirror' {
        $fixtureRoot = New-ClaudeSeedFixture
        Write-AgentFixtureFile -Path (Join-Path $fixtureRoot '.github/agents/a-valid.agent.md') -Content @'
---
name: a-valid
description: Valid source that sorts first
tools: ['read']
---

Valid body.
'@
        Write-AgentFixtureFile -Path (Join-Path $fixtureRoot '.github/agents/z-unknown.agent.md') -Content @'
---
name: z-unknown
description: Unknown tool source
tools: ['read', 'definitelyUnknownTool']
---

Unknown body.
'@
        $sentinelPath = Join-Path $fixtureRoot '.claude/agents/a-valid.md'
        Write-AgentFixtureFile -Path $sentinelPath -Content 'sentinel-before-seed'
        $sentinelHash = (Get-FileHash -LiteralPath $sentinelPath -Algorithm SHA256).Hash

        $seed = Invoke-ClaudeSeedFixture -FixtureRoot $fixtureRoot
        $seed.ExitCode | Should -Not -Be 0
        $seed.Result.VALID | Should -BeFalse
        @($seed.Result.ERRORS.id) | Should -Contain 'unsupported-tool-mapping'
        (Get-FileHash -LiteralPath $sentinelPath -Algorithm SHA256).Hash | Should -Be $sentinelHash
        Join-Path $fixtureRoot '.claude/agents/z-unknown.md' | Should -Not -Exist
    }

    It 'uses an explicit least-privilege Claude mapping for nonportable source tools' {
        $fixtureRoot = New-ClaudeSeedFixture
        Write-AgentFixtureFile -Path (Join-Path $fixtureRoot '.github/agents/explicit.agent.md') -Content @'
---
name: explicit
description: Explicit mapping
tools: ['vscodeAPI', 'usages', 'runSubagent']
claude-tools: ['Read', 'Grep']
---

Explicit body.
'@

        $seed = Invoke-ClaudeSeedFixture -FixtureRoot $fixtureRoot
        $seed.ExitCode | Should -Be 0 -Because ($seed.Stdout + $seed.Stderr)
        $content = Get-Content -LiteralPath (Join-Path $fixtureRoot '.claude/agents/explicit.md') -Raw
        $content | Should -Match '(?m)^tools: Read, Grep$'
        $content | Should -Not -Match '(?m)^tools:\s*$'
    }

    It 'rejects an explicit Claude mapping that broadens portable source permissions' {
        $fixtureRoot = New-ClaudeSeedFixture
        Write-AgentFixtureFile -Path (Join-Path $fixtureRoot '.github/agents/broadening-portable.agent.md') -Content @'
---
name: broadening-portable
description: Invalid explicit mapping
tools: ['read']
claude-tools: ['Write', 'Bash']
---

Body.
'@

        $seed = Invoke-ClaudeSeedFixture -FixtureRoot $fixtureRoot
        $seed.ExitCode | Should -Not -Be 0
        $seed.Result.VALID | Should -BeFalse
        @($seed.Result.ERRORS.id) | Should -Contain 'explicit-tool-permission-broadening'
        Join-Path $fixtureRoot '.claude/agents/broadening-portable.md' | Should -Not -Exist
    }

    It 'rejects malformed frontmatter list value <Value>' -ForEach @(
        @{ Value = '[read.123]' }
        @{ Value = '[123]' }
        @{ Value = "['read'" }
        @{ Value = "['read',]" }
    ) {
        $fixtureRoot = New-ClaudeSeedFixture
        $sourceText = @"
---
name: malformed-list
description: Malformed list
tools: $Value
---

Body.
"@
        Write-AgentFixtureFile -Path (Join-Path $fixtureRoot '.github/agents/malformed-list.agent.md') -Content $sourceText

        $seed = Invoke-ClaudeSeedFixture -FixtureRoot $fixtureRoot
        $seed.ExitCode | Should -Not -Be 0
        $seed.Result.VALID | Should -BeFalse
        @($seed.Result.ERRORS.id) | Should -Contain 'frontmatter-list-invalid'
        Join-Path $fixtureRoot '.claude/agents/malformed-list.md' | Should -Not -Exist
    }

    It 'preserves an explicit empty source tool set as an empty Claude tool set' {
        $fixtureRoot = New-ClaudeSeedFixture
        Write-AgentFixtureFile -Path (Join-Path $fixtureRoot '.github/agents/no-tools.agent.md') -Content @'
---
name: no-tools
description: Explicitly denied tools
tools: []
---

Read-only instruction body with no tool access.
'@

        $seed = Invoke-ClaudeSeedFixture -FixtureRoot $fixtureRoot
        $seed.ExitCode | Should -Be 0 -Because ($seed.Stdout + $seed.Stderr)
        $content = Get-Content -LiteralPath (Join-Path $fixtureRoot '.claude/agents/no-tools.md') -Raw
        $content | Should -Match '(?m)^tools: \[\]$'
        $verify = Invoke-ClaudeSeedFixture -FixtureRoot $fixtureRoot -Verify
        $verify.ExitCode | Should -Be 0 -Because ($verify.Stdout + $verify.Stderr)
    }

    It 'does not allow claude-tools to grant permissions when source tools are empty' {
        $fixtureRoot = New-ClaudeSeedFixture
        Write-AgentFixtureFile -Path (Join-Path $fixtureRoot '.github/agents/broadening.agent.md') -Content @'
---
name: broadening
description: Invalid permission broadening
tools: []
claude-tools: ['Read']
---

Body.
'@

        $seed = Invoke-ClaudeSeedFixture -FixtureRoot $fixtureRoot
        $seed.ExitCode | Should -Not -Be 0
        $seed.Result.VALID | Should -BeFalse
        @($seed.Result.ERRORS.id) | Should -Contain 'claude-tools-permission-broadening'
        Join-Path $fixtureRoot '.claude/agents/broadening.md' | Should -Not -Exist
    }
}
