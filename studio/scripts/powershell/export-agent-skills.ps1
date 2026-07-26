#!/usr/bin/env pwsh

#Requires -Version 7.0

[CmdletBinding()]
param(
    [ValidateSet('codex', 'claude')]
    [string]$Target = 'codex',
    [string]$OutputDir,
    [switch]$Json,
    [switch]$Force,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    $helpLines = @(
        'Usage: ./export-agent-skills.ps1 [-Target codex|claude] [-OutputDir <path>] [-Force] [-Json] [-Help]',
        '',
        'Exports workspace `speckit` runtime agents/prompts as generated AI skill packs.',
        '',
        'Options:',
        '  -Target    Export format family. Current supported values: codex, claude',
        '  -OutputDir Target directory. Defaults to resources/agent-skill-packs/<target>',
        '  -Force     Overwrite an existing export directory',
        '  -Json      Output structured JSON summary',
        '  -Help      Show this help message'
    )
    Write-Output ($helpLines -join "`n")
    exit 0
}

. "$PSScriptRoot/common.ps1"

function ConvertTo-YamlSingleQuoted {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Value
    )

    return "'" + $Value.Replace("'", "''") + "'"
}

function Get-AgentDescription {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $lines = Get-Content -LiteralPath $Path
    if ($lines.Count -lt 3 -or $lines[0] -ne '---') {
        return 'Generated skill export for this speckit command.'
    }

    $frontMatter = @()
    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -eq '---') {
            break
        }
        $frontMatter += $lines[$i]
    }

    for ($i = 0; $i -lt $frontMatter.Count; $i++) {
        if ($frontMatter[$i] -match '^description:\s*(.*)$') {
            $value = $Matches[1].Trim()
            if ([string]::IsNullOrWhiteSpace($value) -or $value -eq '>' -or $value -eq '|') {
                $buffer = @()
                for ($j = $i + 1; $j -lt $frontMatter.Count; $j++) {
                    $candidate = $frontMatter[$j]
                    if ($candidate -match '^[A-Za-z0-9_-]+:\s*') {
                        break
                    }
                    if ($candidate -match '^\s+') {
                        $buffer += $candidate.Trim()
                    }
                }
                if ($buffer.Count -gt 0) {
                    return ($buffer -join ' ')
                }
            }

            if (-not [string]::IsNullOrWhiteSpace($value)) {
                return $value.Trim('"', "'")
            }
        }
    }

    return 'Generated skill export for this speckit command.'
}

function Get-CommandNameFromAgentFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AgentFileName
    )

    return $AgentFileName -replace '\.agent\.md$', ''
}

function Get-SkillName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandName
    )

    return ($CommandName -replace '[^a-z0-9]+', '-').Trim('-')
}

function New-SkillMarkdown {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SkillName,
        [Parameter(Mandatory = $true)]
        [string]$CommandName,
        [Parameter(Mandatory = $true)]
        [string]$AgentFileName,
        [Parameter(Mandatory = $true)]
        [string]$AgentDescription,
        [Parameter(Mandatory = $true)]
        [bool]$HasPrompt
    )

    $triggerDescription = "Use when the user explicitly asks for /$CommandName, or when the request matches this workflow: $AgentDescription"
    $promptWorkflowStep = if ($HasPrompt) {
        '2. Read `references/prompt.md` only if you need the runtime prompt routing metadata for this command.'
    } else {
        '2. No separate runtime prompt file exists for this command in the current workspace export.'
    }
    $promptReference = if ($HasPrompt) {
        '- `references/prompt.md` mirrors the matching runtime prompt file.'
    } else {
        '- No separate runtime prompt file exists for this command in the current workspace export.'
    }

    $lines = @(
        '---',
        ('name: {0}' -f (ConvertTo-YamlSingleQuoted -Value $SkillName)),
        ('description: {0}' -f (ConvertTo-YamlSingleQuoted -Value $triggerDescription)),
        '---',
        '',
        ('# {0}' -f $CommandName),
        '',
        '## Trigger',
        '',
        ('- {0}' -f $triggerDescription),
        '',
        '## Workflow',
        '',
        ('1. Read `references/agent.md` for the canonical shared command instructions mirrored from `.github/agents/{0}`.' -f $AgentFileName),
        $promptWorkflowStep,
        '3. Execute the mirrored workflow without treating this skill as a new source of truth.',
        '',
        '## References',
        '',
        '- `references/agent.md` mirrors the runtime agent file.',
        $promptReference,
        '',
        '## Rules',
        '',
        '- This skill is a generated export artifact from workspace runtime sources.',
        '- Do not edit this skill by hand; regenerate it from `.github/agents/` and `.github/prompts/`.',
        '- `studio-first template precedence` remains unchanged.',
        '- Existing projects remain unchanged.'
    )

    return ($lines -join "`n")
}

$paths = Get-StudioSharedLayerPaths -StartDir $PSScriptRoot
$runtimeSources = Get-ExtensionAwareRuntimeSources -StartDir $PSScriptRoot
$workspaceRoot = $paths.WORKSPACE_ROOT

$agentsSource = $runtimeSources.AGENTS_DIR
$promptsSource = $runtimeSources.PROMPTS_DIR

if (-not (Test-Path $agentsSource)) {
    Write-Error "Runtime agents directory not found: $agentsSource"
    exit 1
}

if (-not (Test-Path $promptsSource)) {
    Write-Error "Runtime prompts directory not found: $promptsSource"
    exit 1
}

$resolvedOutputDir = if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    Join-Path $workspaceRoot "resources/agent-skill-packs/$Target"
} else {
    Resolve-AbsolutePath -Path $OutputDir -BaseDir (Get-Location).Path
}

Ensure-DirectoryEmpty -Path $resolvedOutputDir -Force:$Force
$skillsRoot = Join-Path $resolvedOutputDir 'skills'
New-Item -ItemType Directory -Path $skillsRoot -Force | Out-Null

$promptLookup = @{}
Get-ChildItem -LiteralPath $promptsSource -File -Filter 'speckit.*.prompt.md' |
    ForEach-Object {
        $commandName = $_.Name -replace '\.prompt\.md$', ''
        $promptLookup[$commandName] = $_
    }

$exportedSkills = @()

Get-ChildItem -LiteralPath $agentsSource -File -Filter 'speckit.*.agent.md' |
    Sort-Object Name |
    ForEach-Object {
        $commandName = Get-CommandNameFromAgentFile -AgentFileName $_.Name
        $skillName = Get-SkillName -CommandName $commandName
        $skillDir = Join-Path $skillsRoot $skillName
        $referencesDir = Join-Path $skillDir 'references'
        New-Item -ItemType Directory -Path $referencesDir -Force | Out-Null

        $promptFile = $null
        if ($promptLookup.ContainsKey($commandName)) {
            $promptFile = $promptLookup[$commandName]
        }

        $agentDescription = Get-AgentDescription -Path $_.FullName
        $skillMarkdown = New-SkillMarkdown -SkillName $skillName -CommandName $commandName -AgentFileName $_.Name -AgentDescription $agentDescription -HasPrompt ([bool]$promptFile)

        Set-Content -LiteralPath (Join-Path $skillDir 'SKILL.md') -Value $skillMarkdown -Encoding UTF8
        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $referencesDir 'agent.md') -Force

        if ($promptFile) {
            Copy-Item -LiteralPath $promptFile.FullName -Destination (Join-Path $referencesDir 'prompt.md') -Force
        }

        $exportedSkills += [ordered]@{
            skillName  = $skillName
            command    = "/$commandName"
            folder     = $skillDir
            agentFile  = $_.Name
            promptFile = if ($promptFile) { $promptFile.Name } else { $null }
            target     = $Target
        }
    }

$manifest = [ordered]@{
    name        = "studio-first-speckit-skills-$Target"
    generatedAt = Get-IsoTimestamp
    mode        = 'studio-first'
    target      = $Target
    source      = [ordered]@{
        workspaceRoot = $workspaceRoot
        agentsDir     = $agentsSource
        promptsDir    = $promptsSource
        runtimeMode   = $runtimeSources.MODE
        runtimeMirror = $runtimeSources.MANIFEST_PATH
    }
    contents    = [ordered]@{
        skills = $exportedSkills
    }
    nonGoals    = @(
        'No repo-local full .specify migration',
        'No changes to existing projects',
        'No change to studio-first template precedence',
        'No refactor of update-agent-context.ps1',
        'No direct installation into agent home directories'
    )
}

$manifestPath = Join-Path $resolvedOutputDir 'manifest.json'
([PSCustomObject]$manifest | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $manifestPath -Encoding UTF8

$readmeLines = @(
    '# Agent Skill Pack',
    '',
    ('This pack exports the shared workspace `speckit` runtime commands as generated skills for `{0}`.' -f $Target),
    '',
    '## Source of Truth',
    '',
    '- Runtime agents: `.github/agents/`',
    '- Runtime prompts: `.github/prompts/`',
    '- Exported skills under `skills/` are mirrors, not a new authority',
    '',
    '## Intended Use',
    '',
    'Use this pack when you want to consume the current shared `speckit` command set through skill-based',
    'agent ecosystems without modifying any existing project.',
    '',
    '## Rules',
    '',
    '- Re-run the export after workspace updates instead of editing exported skills by hand.',
    '- This export does not install into agent home directories.',
    '- This export does not convert the workspace into repo-local upstream Spec Kit.',
    '- Existing projects are intentionally left unchanged.',
    '- `studio-first template precedence` remains unchanged.',
    '',
    '## Contents',
    '',
    '- `skills/<skill>/SKILL.md` provides concise trigger and workflow guidance.',
    '- `skills/<skill>/references/agent.md` mirrors the canonical runtime agent file.',
    '- `skills/<skill>/references/prompt.md` exists only when a matching runtime prompt file exists.',
    '- `manifest.json` contains generation metadata.'
)
$readmePath = Join-Path $resolvedOutputDir 'README.md'
Set-Content -LiteralPath $readmePath -Value ($readmeLines -join "`n") -Encoding UTF8

$result = [ordered]@{
    TARGET        = $Target
    SOURCE_MODE   = $runtimeSources.MODE
    OUTPUT_DIR    = $resolvedOutputDir
    SKILLS_DIR    = $skillsRoot
    SKILL_COUNT   = $exportedSkills.Count
    MANIFEST_PATH = $manifestPath
    README_PATH   = $readmePath
    COMMANDS      = $exportedSkills | ForEach-Object { $_.command }
}

if ($Json) {
    [PSCustomObject]$result | ConvertTo-Json -Depth 4
    exit 0
}

Write-Output "Exported $($exportedSkills.Count) skill(s) for $Target to: $resolvedOutputDir"
Write-Output "Skills directory: $skillsRoot"
Write-Output "Manifest: $manifestPath"
Write-Output "README: $readmePath"
