#!/usr/bin/env pwsh
#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/governance.config.ps1"
    $script:commitMsgScript = Join-Path $WorkspaceRoot '.githooks/commit-msg.ps1'
}

# ============================================================
# M6: Conventional Commits validation (commit-msg hook)
# ============================================================

Describe 'commit-msg hook: Conventional Commits format' {
    BeforeEach {
        $script:msgFile = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString('N') + '.msg')
    }

    It 'accepts feat: subject' {
        Set-Content -LiteralPath $script:msgFile -Value 'feat: add new feature' -Encoding UTF8 -NoNewline
        pwsh -NoProfile -File $script:commitMsgScript $script:msgFile 2>&1 | Out-Null
        $LASTEXITCODE | Should -Be 0
    }

    It 'accepts fix(scope): subject' {
        Set-Content -LiteralPath $script:msgFile -Value 'fix(auth): handle expired token' -Encoding UTF8 -NoNewline
        pwsh -NoProfile -File $script:commitMsgScript $script:msgFile 2>&1 | Out-Null
        $LASTEXITCODE | Should -Be 0
    }

    It 'accepts chore(scope-with-hyphen): subject' {
        Set-Content -LiteralPath $script:msgFile -Value 'chore(deps-dev): bump pester version' -Encoding UTF8 -NoNewline
        pwsh -NoProfile -File $script:commitMsgScript $script:msgFile 2>&1 | Out-Null
        $LASTEXITCODE | Should -Be 0
    }

    It 'accepts feat!: breaking change marker' {
        Set-Content -LiteralPath $script:msgFile -Value 'feat!: rewrite API surface' -Encoding UTF8 -NoNewline
        $output = pwsh -NoProfile -File $script:commitMsgScript $script:msgFile 2>&1
        $LASTEXITCODE | Should -Be 0
        ($output -join "`n") | Should -Match 'Breaking change: yes'
    }

    It 'accepts feat(scope)!: breaking change with scope' {
        Set-Content -LiteralPath $script:msgFile -Value 'feat(api)!: drop v1 endpoints' -Encoding UTF8 -NoNewline
        pwsh -NoProfile -File $script:commitMsgScript $script:msgFile 2>&1 | Out-Null
        $LASTEXITCODE | Should -Be 0
    }

    It 'accepts ci: subject' {
        Set-Content -LiteralPath $script:msgFile -Value 'ci: tighten matrix' -Encoding UTF8 -NoNewline
        pwsh -NoProfile -File $script:commitMsgScript $script:msgFile 2>&1 | Out-Null
        $LASTEXITCODE | Should -Be 0
    }

    It 'accepts perf: subject' {
        Set-Content -LiteralPath $script:msgFile -Value 'perf: optimize hot path' -Encoding UTF8 -NoNewline
        pwsh -NoProfile -File $script:commitMsgScript $script:msgFile 2>&1 | Out-Null
        $LASTEXITCODE | Should -Be 0
    }

    It 'accepts build: subject' {
        Set-Content -LiteralPath $script:msgFile -Value 'build: bump pwsh requirement' -Encoding UTF8 -NoNewline
        pwsh -NoProfile -File $script:commitMsgScript $script:msgFile 2>&1 | Out-Null
        $LASTEXITCODE | Should -Be 0
    }

    It 'accepts revert canonical commit subject' {
        Set-Content -LiteralPath $script:msgFile -Value 'Revert "feat: bad feature"' -Encoding UTF8 -NoNewline
        pwsh -NoProfile -File $script:commitMsgScript $script:msgFile 2>&1 | Out-Null
        $LASTEXITCODE | Should -Be 0
    }

    It 'accepts merge commit subject' {
        Set-Content -LiteralPath $script:msgFile -Value 'Merge branch ''feature/x'' into main' -Encoding UTF8 -NoNewline
        pwsh -NoProfile -File $script:commitMsgScript $script:msgFile 2>&1 | Out-Null
        $LASTEXITCODE | Should -Be 0
    }

    It 'detects BREAKING CHANGE footer' {
        $msg = "feat: add config knob`n`nThis adds a new env var.`n`nBREAKING CHANGE: removes legacy fallback."
        Set-Content -LiteralPath $script:msgFile -Value $msg -Encoding UTF8 -NoNewline
        $output = pwsh -NoProfile -File $script:commitMsgScript $script:msgFile 2>&1
        $LASTEXITCODE | Should -Be 0
        ($output -join "`n") | Should -Match 'Breaking change: yes'
    }

    It 'rejects commit with no type prefix' {
        Set-Content -LiteralPath $script:msgFile -Value 'add new feature' -Encoding UTF8 -NoNewline
        $output = pwsh -NoProfile -File $script:commitMsgScript $script:msgFile 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match 'does not follow Conventional Commits format'
    }

    It 'rejects commit with unknown type' {
        Set-Content -LiteralPath $script:msgFile -Value 'wip: half-done' -Encoding UTF8 -NoNewline
        pwsh -NoProfile -File $script:commitMsgScript $script:msgFile 2>&1 | Out-Null
        $LASTEXITCODE | Should -Not -Be 0
    }

    It 'rejects commit with empty subject' {
        Set-Content -LiteralPath $script:msgFile -Value '' -Encoding UTF8 -NoNewline
        pwsh -NoProfile -File $script:commitMsgScript $script:msgFile 2>&1 | Out-Null
        $LASTEXITCODE | Should -Not -Be 0
    }

    It 'rejects commit with only comment lines' {
        Set-Content -LiteralPath $script:msgFile -Value "# comment 1`n# comment 2" -Encoding UTF8 -NoNewline
        pwsh -NoProfile -File $script:commitMsgScript $script:msgFile 2>&1 | Out-Null
        $LASTEXITCODE | Should -Not -Be 0
    }

    It 'skips comment lines and uses first real line as subject' {
        $msg = "# Please enter the commit message`n# Lines starting with # will be ignored`nfix: actual subject line"
        Set-Content -LiteralPath $script:msgFile -Value $msg -Encoding UTF8 -NoNewline
        pwsh -NoProfile -File $script:commitMsgScript $script:msgFile 2>&1 | Out-Null
        $LASTEXITCODE | Should -Be 0
    }

    It 'warns but accepts subject longer than 72 chars' {
        $longMessage = 'feat: ' + ('x' * 80)
        Set-Content -LiteralPath $script:msgFile -Value $longMessage -Encoding UTF8 -NoNewline
        $output = pwsh -NoProfile -File $script:commitMsgScript $script:msgFile 2>&1
        $LASTEXITCODE | Should -Be 0
        ($output -join "`n") | Should -Match 'recommended: <=72'
    }

    It 'warns but accepts subject ending with period' {
        Set-Content -LiteralPath $script:msgFile -Value 'fix: typo in readme.' -Encoding UTF8 -NoNewline
        $output = pwsh -NoProfile -File $script:commitMsgScript $script:msgFile 2>&1
        $LASTEXITCODE | Should -Be 0
        ($output -join "`n") | Should -Match 'should not end with a period'
    }
}
