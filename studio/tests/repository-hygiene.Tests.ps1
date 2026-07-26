#!/usr/bin/env pwsh
#Requires -Version 7.0
#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/governance.config.ps1"

    function Get-TrackedGovernedTextFiles {
        $paths = @(& git -C $WorkspaceRoot -c core.quotepath=false ls-files)
        if ($LASTEXITCODE -ne 0) {
            throw 'Unable to enumerate tracked files for repository hygiene tests.'
        }

        return @(
            $paths |
                Where-Object {
                    $leaf = Split-Path -Leaf $_
                    (Test-Path -LiteralPath (Join-Path $WorkspaceRoot $_) -PathType Leaf) -and (
                        $_ -match '\.(?:md|ps1|psm1|psd1|sh|txt|json|jsonc|ya?ml|xml|ini|toml|code-workspace)$' -or
                        $leaf -in @('LICENSE', '.gitignore', '.gitattributes', '.editorconfig', 'pre-commit', 'commit-msg')
                    )
                }
        )
    }
}

Describe 'Repository text hygiene' {
    It 'keeps every tracked governed text file UTF-8 without BOM and free of CR bytes' {
        $violations = [System.Collections.Generic.List[string]]::new()

        foreach ($relativePath in Get-TrackedGovernedTextFiles) {
            $path = Join-Path $WorkspaceRoot $relativePath
            $bytes = [System.IO.File]::ReadAllBytes($path)
            $hasBom = $bytes.Length -ge 3 -and
                $bytes[0] -eq 0xEF -and
                $bytes[1] -eq 0xBB -and
                $bytes[2] -eq 0xBF
            $hasCarriageReturn = [Array]::IndexOf($bytes, [byte]0x0D) -ge 0
            $missingFinalLf = $bytes.Length -gt 0 -and $bytes[-1] -ne 0x0A

            if ($hasBom -or $hasCarriageReturn -or $missingFinalLf) {
                $reasons = @()
                if ($hasBom) { $reasons += 'UTF-8 BOM' }
                if ($hasCarriageReturn) { $reasons += 'CR byte' }
                if ($missingFinalLf) { $reasons += 'missing final LF' }
                $violations.Add(('{0}: {1}' -f $relativePath, ($reasons -join ', ')))
            }
        }

        @($violations) | Should -BeNullOrEmpty
    }

    It 'declares PowerShell 7.0 for every governed runtime PowerShell script' {
        $runtimeScripts = @(& git -C $WorkspaceRoot ls-files '*.ps1' |
            Where-Object { $_ -notmatch '^studio/tests/' } |
            ForEach-Object { Get-Item -LiteralPath (Join-Path $WorkspaceRoot $_) })
        $violations = [System.Collections.Generic.List[string]]::new()

        foreach ($scriptFile in $runtimeScripts) {
            $tokens = $null
            $parseErrors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile(
                $scriptFile.FullName,
                [ref]$tokens,
                [ref]$parseErrors
            )

            if ($parseErrors.Count -gt 0) {
                $violations.Add("$($scriptFile.Name): parse error")
                continue
            }

            $requiredVersion = $ast.ScriptRequirements.RequiredPSVersion
            if ($null -eq $requiredVersion -or $requiredVersion -lt [version]'7.0') {
                $violations.Add("$($scriptFile.Name): missing #Requires -Version 7.0")
            }
        }

        @($violations) | Should -BeNullOrEmpty
    }

    It 'fails fast with the version requirement under Windows PowerShell 5.1' -Skip:(-not $IsWindows -or -not (Get-Command powershell.exe -ErrorAction SilentlyContinue)) {
        $commonScript = Join-Path $WorkspaceRoot 'studio/scripts/powershell/common.ps1'
        $output = @(& powershell.exe -NoLogo -NoProfile -NonInteractive -File $commonScript 2>&1)

        $LASTEXITCODE | Should -Not -Be 0
        ($output | Out-String) | Should -Match 'ScriptRequiresUnmatchedPSVersion'
    }

    It 'keeps root and project-init normalization policies synchronized' {
        $rootAttributes = Get-Content -LiteralPath (Join-Path $WorkspaceRoot '.gitattributes') -Raw
        $templateAttributes = Get-Content -LiteralPath (Join-Path $WorkspaceRoot 'studio/templates/project-init/.gitattributes') -Raw
        $rootEditorConfig = Get-Content -LiteralPath (Join-Path $WorkspaceRoot '.editorconfig') -Raw
        $templateEditorConfig = Get-Content -LiteralPath (Join-Path $WorkspaceRoot 'studio/templates/project-init/.editorconfig') -Raw

        $templateAttributes | Should -BeExactly $rootAttributes
        $templateEditorConfig | Should -BeExactly $rootEditorConfig
        $rootAttributes | Should -Match '(?m)^\* text=auto$'
        $rootAttributes | Should -Match '(?m)^\*\.ps1 text eol=lf$'
        $rootAttributes | Should -Match '(?m)^\*\.md text eol=lf$'
        $rootAttributes | Should -Match '(?m)^\*\.json text eol=lf$'
        $rootAttributes | Should -Match '(?m)^\*\.yml text eol=lf$'
        $rootEditorConfig | Should -Match '(?m)^charset = utf-8$'
        $rootEditorConfig | Should -Match '(?m)^end_of_line = lf$'
        $rootEditorConfig | Should -Match '(?m)^insert_final_newline = true$'
    }

    It 'removes historical Claude backup trees and ignores future backup runs' {
        $backupTrees = @(
            Get-ChildItem -LiteralPath (Join-Path $WorkspaceRoot '.claude') -Directory -Force |
                Where-Object Name -Like '.agent-*-backup'
        )
        $backupTrees | Should -BeNullOrEmpty

        & git -C $WorkspaceRoot check-ignore --quiet --no-index -- '.claude/.agent-fixture-backup/file.md'
        $LASTEXITCODE | Should -Be 0
        & git -C $WorkspaceRoot check-ignore --quiet --no-index -- 'studio/templates/project-init/.claude/.agent-fixture-backup/file.md'
        $LASTEXITCODE | Should -Be 0
    }
}

Describe 'Claude agent seed text output' {
    It 'emits deterministic UTF-8 without BOM using LF line endings' {
        $fixtureRoot = Join-Path $TestDrive 'seed-workspace'
        $fixtureScriptDir = Join-Path $fixtureRoot 'studio/scripts/powershell'
        $fixtureSourceDir = Join-Path $fixtureRoot '.github/agents'
        New-Item -ItemType Directory -Path $fixtureScriptDir -Force | Out-Null
        New-Item -ItemType Directory -Path $fixtureSourceDir -Force | Out-Null

        Copy-Item -LiteralPath (Join-Path $WorkspaceRoot 'studio/scripts/powershell/common.ps1') -Destination $fixtureScriptDir
        Copy-Item -LiteralPath (Join-Path $WorkspaceRoot 'studio/scripts/powershell/seed-claude-agents.ps1') -Destination $fixtureScriptDir

        $fixtureSource = Join-Path $fixtureSourceDir 'fixture.agent.md'
        $sourceText = "---`r`nname: fixture`r`ndescription: Fixture agent`r`ntools: ['read']`r`n---`r`n`r`nFixture body.`r`n"
        [System.IO.File]::WriteAllText(
            $fixtureSource,
            $sourceText,
            [System.Text.UTF8Encoding]::new($false, $true)
        )

        $seedScript = Join-Path $fixtureScriptDir 'seed-claude-agents.ps1'
        $firstRun = @(& pwsh -NoProfile -File $seedScript -WorkspaceRoot $fixtureRoot -Json)
        $LASTEXITCODE | Should -Be 0 -Because ($firstRun -join "`n")

        $generatedPath = Join-Path $fixtureRoot '.claude/agents/fixture.md'
        $generatedPath | Should -Exist
        $firstBytes = [System.IO.File]::ReadAllBytes($generatedPath)
        $firstHash = (Get-FileHash -LiteralPath $generatedPath -Algorithm SHA256).Hash

        ($firstBytes.Length -ge 3 -and $firstBytes[0] -eq 0xEF -and $firstBytes[1] -eq 0xBB -and $firstBytes[2] -eq 0xBF) | Should -BeFalse
        ([Array]::IndexOf($firstBytes, [byte]0x0D) -ge 0) | Should -BeFalse
        $firstBytes[-1] | Should -Be 0x0A

        $secondRun = @(& pwsh -NoProfile -File $seedScript -WorkspaceRoot $fixtureRoot -Json)
        $LASTEXITCODE | Should -Be 0 -Because ($secondRun -join "`n")
        (Get-FileHash -LiteralPath $generatedPath -Algorithm SHA256).Hash | Should -Be $firstHash
    }
}

Describe 'shared-layer suite consumer-space independence (R-A24)' {
    It 'keeps consumer directories out of version control' {
        foreach ($consumerRoot in @('projects', 'learning')) {
            $tracked = @(& git -C $WorkspaceRoot -c core.quotepath=false ls-files ("{0}/*" -f $consumerRoot))
            if ($LASTEXITCODE -ne 0) {
                throw "Unable to enumerate tracked files under '$consumerRoot'."
            }
            $tracked.Count | Should -Be 0 -Because "$consumerRoot is a gitignored consumer space"
        }
    }

    It 'never asserts that an untracked consumer-space path exists' {
        # A shared-layer test that requires consumer state to be present passes only where that
        # state happens to exist locally and fails on every clean checkout. Synthetic consumer
        # strings passed into classification logic stay legal: only existence assertions count.
        $consumerLiteral = [regex]"['`"]((?:projects|learning)/[^'`"]+)['`"]"
        $offenders = [System.Collections.Generic.List[string]]::new()

        foreach ($suiteFile in (Get-ChildItem -LiteralPath (Join-Path $WorkspaceRoot 'studio/tests') -Filter '*.Tests.ps1')) {
            $blocks = [regex]::Split(
                [System.IO.File]::ReadAllText($suiteFile.FullName),
                '(?m)^\s{4}It\s'
            )
            for ($index = 1; $index -lt $blocks.Count; $index++) {
                $block = $blocks[$index]
                if ($block -notmatch 'Should\s+-Exist') { continue }
                foreach ($match in $consumerLiteral.Matches($block)) {
                    $relativePath = $match.Groups[1].Value
                    $tracked = @(& git -C $WorkspaceRoot -c core.quotepath=false ls-files $relativePath)
                    if ($tracked.Count -eq 0) {
                        $offenders.Add(('{0} -> {1}' -f $suiteFile.Name, $relativePath))
                    }
                }
            }
        }

        $offenders | Should -BeNullOrEmpty
    }
}
