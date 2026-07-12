#!/usr/bin/env pwsh
#Requires -Module Pester

# ============================================================
# Patch 6 helpers: Get-MarkdownField, New-CodeWorkspaceContent,
# Initialize-ProjectFromTemplate (extracted from init-project.ps1
# and init-practice.ps1 to remove ~80 lines of duplication).
# ============================================================

BeforeAll {
    . "$PSScriptRoot/governance.config.ps1"
    . (Get-ScriptFunctionsBlock -ScriptPath (Join-Path $WorkspaceRoot 'studio/scripts/powershell/common.ps1'))
}

Describe 'Get-MarkdownField (M4 unified helper)' {
    It 'parses a plain bold-key line' {
        $content = "Some preamble`n**Version:** 1.0.0`nMore text"
        Get-MarkdownField -Content $content -Field 'Version' | Should -Be '1.0.0'
    }

    It 'strips wrapping backticks (M13 round-trip)' {
        $content = "**Primary Status:** ``READY_FOR_PLAN``"
        Get-MarkdownField -Content $content -Field 'Primary Status' | Should -Be 'READY_FOR_PLAN'
    }

    It 'strips wrapping double quotes' {
        $content = '**Title:** "Hello World"'
        Get-MarkdownField -Content $content -Field 'Title' | Should -Be 'Hello World'
    }

    It 'handles list-prefixed lines (- **Field:** value)' {
        $content = "- **Status:** Ready`n- **Note:** other"
        Get-MarkdownField -Content $content -Field 'Status' | Should -Be 'Ready'
    }

    It 'is case-insensitive on the field name' {
        $content = '**Version:** 2.1.0'
        Get-MarkdownField -Content $content -Field 'version' | Should -Be '2.1.0'
    }

    It 'returns $null when the field is absent' {
        $content = '**Other:** something'
        Get-MarkdownField -Content $content -Field 'Missing' | Should -BeNullOrEmpty
    }

    It 'returns $null for empty content' {
        Get-MarkdownField -Content '' -Field 'Anything' | Should -BeNullOrEmpty
    }

    It 'reads from a file when -Path is used' {
        $path = Join-Path $TestDrive 'fixture.md'
        @"
# Fixture
**Version:** 9.9.9
"@ | Set-Content -LiteralPath $path -Encoding utf8
        Get-MarkdownField -Path $path -Field 'Version' | Should -Be '9.9.9'
    }

    It 'returns $null when -Path does not exist' {
        Get-MarkdownField -Path (Join-Path $TestDrive 'nope.md') -Field 'Version' | Should -BeNullOrEmpty
    }

    It 'preserves intermediate backticks within the value' {
        $content = '**Trigger:** Create `intent-ledger.md`'
        Get-MarkdownField -Content $content -Field 'Trigger' | Should -Be 'Create `intent-ledger.md`'
    }
}

Describe 'New-CodeWorkspaceContent (M3 helper)' {
    It 'returns valid JSON with the expected folder ordering' {
        $json = New-CodeWorkspaceContent -ProjectName 'demo'
        $obj = $json | ConvertFrom-Json
        $obj.folders.Count | Should -Be 4
        $obj.folders[0].name | Should -Be 'demo'
        $obj.folders[0].path | Should -Be '.'
        $obj.folders[1].name | Should -Be 'studio (read-only)'
        $obj.folders[2].name | Should -Be 'agents (read-only)'
        $obj.folders[3].name | Should -Be 'claude agents (read-only)'
    }

    It 'marks studio and agent paths as readonly' {
        $json = New-CodeWorkspaceContent -ProjectName 'demo'
        $obj = $json | ConvertFrom-Json
        $obj.settings.'files.readonlyInclude'.'**/studio/**' | Should -BeTrue
        $obj.settings.'files.readonlyInclude'.'**/.github/agents/**' | Should -BeTrue
        $obj.settings.'files.readonlyInclude'.'**/.claude/agents/**' | Should -BeTrue
    }

    It 'allows custom relative paths for derived worktrees' {
        $json = New-CodeWorkspaceContent -ProjectName 'demo' -StudioRelativePath '../../../studio'
        $obj = $json | ConvertFrom-Json
        $obj.folders[1].path | Should -Be '../../../studio'
    }
}

Describe 'Get-RetrospectiveContent' {
    It 'substitutes project tokens when template exists' {
        $studio = Join-Path $TestDrive 'studio'
        New-Item -ItemType Directory -Path (Join-Path $studio 'templates/sdd-docs') -Force | Out-Null
        $tpl = Join-Path $studio 'templates/sdd-docs/retrospective-template.md'
        Set-Content -LiteralPath $tpl -Value @"
# Retrospective: [PROJECT_NAME]

**Project Type:** [PROJECT_TYPE]
**Created:** [CREATED_DATE]
"@ -Encoding utf8

        $content = Get-RetrospectiveContent -ProjectName 'alpha' -ProjectType 'Internal' -StudioRoot $studio -CreatedDate '2026-04-30'
        $content | Should -Match '# Retrospective: alpha'
        $content | Should -Match 'Project Type:\*\* Internal'
        $content | Should -Match 'Created:\*\* 2026-04-30'
    }

    It 'falls back to inline scaffold when template missing' {
        $content = Get-RetrospectiveContent -ProjectName 'beta' -ProjectType 'Client' -StudioRoot (Join-Path $TestDrive 'no-studio') -CreatedDate '2026-04-30'
        $content | Should -Match '# Retrospective: beta'
        $content | Should -Match 'Project Type:\*\* Client'
    }
}

Describe 'Initialize-ProjectFromTemplate (M3 main helper)' {
    BeforeEach {
        $script:workspace = Join-Path $TestDrive ("ws-{0}" -f ([System.Guid]::NewGuid().ToString('N')))
        $script:studio = Join-Path $script:workspace 'studio'
        New-Item -ItemType Directory -Path (Join-Path $script:workspace '.githooks') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:workspace '.github/agents') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:workspace '.claude/agents') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:studio 'scripts/powershell') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:studio 'templates/project-init') -Force | Out-Null

        # Minimal template
        Set-Content -LiteralPath (Join-Path $script:studio 'templates/project-init/README.md') -Value @"
# [PROJECT_NAME]

Project Type: [PROJECT_TYPE]
Description: [PROJECT_DESCRIPTION]
Created: [CREATED_DATE]
"@ -Encoding utf8

        foreach ($policyFile in @('.gitignore', '.gitattributes', '.editorconfig')) {
            Copy-Item `
                -LiteralPath (Join-Path $WorkspaceRoot "studio/templates/project-init/$policyFile") `
                -Destination (Join-Path $script:studio "templates/project-init/$policyFile")
        }

        # Stray .git in template (M21) — must NOT propagate
        $strayGitDir = Join-Path $script:studio 'templates/project-init/.git'
        New-Item -ItemType Directory -Path $strayGitDir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $strayGitDir 'HEAD') -Value 'ref: refs/heads/poison'

        # Stub the bootstrap script that the helper invokes
        $bootstrapStub = Join-Path $script:studio 'scripts/powershell/sync-agent-bootstrap.ps1'
        Set-Content -LiteralPath $bootstrapStub -Value @'
param([string]$ProjectRoot,[string]$ProjectName,[string]$ProjectType,[string]$ProjectDescription,[switch]$Write)
Set-Content -LiteralPath (Join-Path $ProjectRoot 'AGENTS.md')                       -Value "# AGENTS.md stub" -Encoding utf8
Set-Content -LiteralPath (Join-Path $ProjectRoot 'CLAUDE.md')                       -Value "# CLAUDE.md stub" -Encoding utf8
$copilotDir = Join-Path $ProjectRoot '.github'
New-Item -ItemType Directory -Path $copilotDir -Force | Out-Null
Set-Content -LiteralPath (Join-Path $copilotDir 'copilot-instructions.md')          -Value "# Copilot stub" -Encoding utf8
exit 0
'@ -Encoding utf8
    }

    It 'creates the project tree and purges stray .git from template (M21)' {
        $target = Join-Path $script:workspace 'projects/demo'
        $result = Initialize-ProjectFromTemplate `
            -Name 'demo' `
            -TargetDir $target `
            -Type 'Internal' `
            -TemplateDir (Join-Path $script:studio 'templates/project-init') `
            -StudioRoot $script:studio `
            -WorkspaceRoot $script:workspace

        $result.targetDir | Should -Be $target
        Test-Path -LiteralPath $target | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $target 'README.md') | Should -BeTrue

        # The .git directory exists because Initialize-ProjectGitRepository ran git init,
        # but the poisoned HEAD content from the template MUST NOT be present.
        $headPath = Join-Path $target '.git/HEAD'
        Test-Path -LiteralPath $headPath | Should -BeTrue
        $head = Get-Content -LiteralPath $headPath -Raw
        $head | Should -Not -Match 'poison'
    }

    It 'substitutes README placeholders' {
        $target = Join-Path $script:workspace 'projects/sub'
        Initialize-ProjectFromTemplate `
            -Name 'sub' `
            -TargetDir $target `
            -Type 'Internal' `
            -Description 'A custom desc' `
            -TemplateDir (Join-Path $script:studio 'templates/project-init') `
            -StudioRoot $script:studio `
            -WorkspaceRoot $script:workspace | Out-Null

        $readme = Get-Content -LiteralPath (Join-Path $target 'README.md') -Raw
        $readme | Should -Match 'sub'
        $readme | Should -Match 'Internal'
        $readme | Should -Match 'A custom desc'
    }

    It 'copies repository hygiene policies into each independent project' {
        $target = Join-Path $script:workspace 'projects/policies'
        Initialize-ProjectFromTemplate `
            -Name 'policies' `
            -TargetDir $target `
            -Type 'Internal' `
            -TemplateDir (Join-Path $script:studio 'templates/project-init') `
            -StudioRoot $script:studio `
            -WorkspaceRoot $script:workspace | Out-Null

        foreach ($policyFile in @('.gitignore', '.gitattributes', '.editorconfig')) {
            Test-Path -LiteralPath (Join-Path $target $policyFile) | Should -BeTrue
        }

        $ignore = Get-Content -LiteralPath (Join-Path $target '.gitignore') -Raw
        $attributes = Get-Content -LiteralPath (Join-Path $target '.gitattributes') -Raw
        $editorConfig = Get-Content -LiteralPath (Join-Path $target '.editorconfig') -Raw
        $ignore | Should -Match '(?m)^/packages/$'
        $ignore | Should -Match '(?m)^\.claude/settings\.local\.json$'
        $ignore | Should -Match '(?m)^\.claude/\.agent-\*-backup/$'
        $attributes | Should -Match '(?m)^\*\.ps1 text eol=lf$'
        $editorConfig | Should -Match '(?m)^charset = utf-8$'
        $editorConfig | Should -Match '(?m)^end_of_line = lf$'
    }

    It 'creates retrospective.md for Internal projects' {
        $target = Join-Path $script:workspace 'projects/withretro'
        Initialize-ProjectFromTemplate `
            -Name 'withretro' `
            -TargetDir $target `
            -Type 'Internal' `
            -TemplateDir (Join-Path $script:studio 'templates/project-init') `
            -StudioRoot $script:studio `
            -WorkspaceRoot $script:workspace | Out-Null

        Test-Path -LiteralPath (Join-Path $target 'retrospective.md') | Should -BeTrue
    }

    It 'skips retrospective.md for Practice projects' {
        $target = Join-Path $script:workspace 'learning/practice-x'
        Initialize-ProjectFromTemplate `
            -Name 'practice-x' `
            -TargetDir $target `
            -Type 'Practice' `
            -TemplateDir (Join-Path $script:studio 'templates/project-init') `
            -StudioRoot $script:studio `
            -WorkspaceRoot $script:workspace | Out-Null

        Test-Path -LiteralPath (Join-Path $target 'retrospective.md') | Should -BeFalse
    }

    It 'writes a multi-root code-workspace JSON file' {
        $target = Join-Path $script:workspace 'projects/wsfile'
        Initialize-ProjectFromTemplate `
            -Name 'wsfile' `
            -TargetDir $target `
            -Type 'Internal' `
            -TemplateDir (Join-Path $script:studio 'templates/project-init') `
            -StudioRoot $script:studio `
            -WorkspaceRoot $script:workspace | Out-Null

        $wsPath = Join-Path $target 'wsfile.code-workspace'
        Test-Path -LiteralPath $wsPath | Should -BeTrue
        $obj = Get-Content -LiteralPath $wsPath -Raw | ConvertFrom-Json
        $obj.folders[0].name | Should -Be 'wsfile'
        $bytes = [System.IO.File]::ReadAllBytes($wsPath)
        ([Array]::IndexOf($bytes, [byte]0x0D) -ge 0) | Should -BeFalse
        $bytes[-1] | Should -Be 0x0A
    }

    It 'writes initialized governed documents with LF and no BOM' {
        $target = Join-Path $script:workspace 'projects/lfdocs'
        Initialize-ProjectFromTemplate `
            -Name 'lfdocs' `
            -TargetDir $target `
            -Type 'Internal' `
            -TemplateDir (Join-Path $script:studio 'templates/project-init') `
            -StudioRoot $script:studio `
            -WorkspaceRoot $script:workspace | Out-Null

        foreach ($relativePath in @(
            'README.md',
            'retrospective.md',
            '.specify/memory/constitution.md',
            'lfdocs.code-workspace'
        )) {
            $bytes = [System.IO.File]::ReadAllBytes((Join-Path $target $relativePath))
            ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) | Should -BeFalse -Because $relativePath
            ([Array]::IndexOf($bytes, [byte]0x0D) -ge 0) | Should -BeFalse -Because $relativePath
            $bytes[-1] | Should -Be 0x0A -Because $relativePath
        }
    }

    It 'initializes an independent Git repo with workspace hooksPath' {
        $target = Join-Path $script:workspace 'projects/gitinit'
        $result = Initialize-ProjectFromTemplate `
            -Name 'gitinit' `
            -TargetDir $target `
            -Type 'Internal' `
            -TemplateDir (Join-Path $script:studio 'templates/project-init') `
            -StudioRoot $script:studio `
            -WorkspaceRoot $script:workspace

        Test-Path -LiteralPath (Join-Path $target '.git') | Should -BeTrue
        $result.gitRepository.hooksPath | Should -Match '\.\./\.\./\.githooks'
    }

    It 'throws when target already exists (no overwrite)' {
        $target = Join-Path $script:workspace 'projects/dup'
        New-Item -ItemType Directory -Path $target -Force | Out-Null

        {
            Initialize-ProjectFromTemplate `
                -Name 'dup' `
                -TargetDir $target `
                -Type 'Internal' `
                -TemplateDir (Join-Path $script:studio 'templates/project-init') `
                -StudioRoot $script:studio `
                -WorkspaceRoot $script:workspace
        } | Should -Throw -ExpectedMessage '*already exists*'
    }

    It 'throws when template directory does not exist' {
        $target = Join-Path $script:workspace 'projects/notpl'
        {
            Initialize-ProjectFromTemplate `
                -Name 'notpl' `
                -TargetDir $target `
                -Type 'Internal' `
                -TemplateDir (Join-Path $script:studio 'templates/missing-template') `
                -StudioRoot $script:studio `
                -WorkspaceRoot $script:workspace
        } | Should -Throw -ExpectedMessage '*template not found*'
    }

    It 'honors -WhatIf without applying any filesystem changes (M20)' {
        $target = Join-Path $script:workspace 'projects/preview'
        Initialize-ProjectFromTemplate `
            -Name 'preview' `
            -TargetDir $target `
            -Type 'Internal' `
            -TemplateDir (Join-Path $script:studio 'templates/project-init') `
            -StudioRoot $script:studio `
            -WorkspaceRoot $script:workspace `
            -WhatIf | Out-Null

        Test-Path -LiteralPath $target | Should -BeFalse
    }
}

Describe 'init script wrapper smoke (Patch 6 integration)' {
    It 'init-project.ps1 supports -WhatIf at the parameter binder' {
        $cmd = Get-Command (Join-Path $WorkspaceRoot 'studio/scripts/powershell/init-project.ps1')
        $cmd.Parameters.Keys | Should -Contain 'WhatIf'
    }

    It 'init-practice.ps1 supports -WhatIf at the parameter binder' {
        $cmd = Get-Command (Join-Path $WorkspaceRoot 'studio/scripts/powershell/init-practice.ps1')
        $cmd.Parameters.Keys | Should -Contain 'WhatIf'
    }
}
