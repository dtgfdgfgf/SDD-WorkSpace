#!/usr/bin/env pwsh

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$OutputDir,
    [switch]$Json,
    [switch]$Force,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Output @"
Usage: ./export-generic-agent-pack.ps1 -OutputDir <path> [-Force] [-Json] [-Help]

Exports the workspace runtime agents and prompts as a generic/BYO agent pack.

Options:
  -OutputDir  Target directory for the exported pack
  -Force      Overwrite existing pack contents
  -Json       Output structured JSON summary
  -Help       Show this help message
"@
    exit 0
}

. "$PSScriptRoot/common.ps1"

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

$resolvedOutputDir = Resolve-AbsolutePath -Path $OutputDir -BaseDir (Get-Location).Path
Ensure-DirectoryEmpty -Path $resolvedOutputDir -Force:$Force
$agentsTarget = Join-Path $resolvedOutputDir 'agents'
$promptsTarget = Join-Path $resolvedOutputDir 'prompts'
New-Item -ItemType Directory -Path $agentsTarget -Force | Out-Null
New-Item -ItemType Directory -Path $promptsTarget -Force | Out-Null

Get-ChildItem -LiteralPath $agentsSource -File -Filter '*.md' | Copy-Item -Destination $agentsTarget -Force
Get-ChildItem -LiteralPath $promptsSource -File -Filter '*.md' | Copy-Item -Destination $promptsTarget -Force

$agentFiles = Get-ChildItem -LiteralPath $agentsTarget -File -Filter '*.md' | Sort-Object Name | Select-Object -ExpandProperty Name
$promptFiles = Get-ChildItem -LiteralPath $promptsTarget -File -Filter '*.md' | Sort-Object Name | Select-Object -ExpandProperty Name

$manifest = [ordered]@{
    name        = 'studio-first-speckit-generic-pack'
    generatedAt = Get-IsoTimestamp
    mode        = 'studio-first'
    source      = [ordered]@{
        workspaceRoot = $workspaceRoot
        agentsDir     = $agentsSource
        promptsDir    = $promptsSource
        runtimeMode   = $runtimeSources.MODE
        runtimeMirror = $runtimeSources.MANIFEST_PATH
    }
    contents    = [ordered]@{
        agents  = $agentFiles
        prompts = $promptFiles
    }
    nonGoals    = @(
        'No repo-local full .specify migration',
        'No changes to existing projects',
        'No change to studio-first template precedence',
        'No refactor of update-agent-context.ps1'
    )
}

$manifestPath = Join-Path $resolvedOutputDir 'manifest.json'
([PSCustomObject]$manifest | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $manifestPath -Encoding UTF8

$readme = @"
# Generic Agent Pack

This pack is a studio-first export of the workspace runtime agent sources.

## Source of Truth

- Runtime agents: `.github/agents/`
- Runtime prompts: `.github/prompts/`
- Studio model: centralized runtime sources, project-local consumption

## Intended Use

Use this pack when you want to feed the current shared `speckit` command set into an unsupported or
BYO agent environment.

## Rules

- Treat this pack as a mirror, not a competing authority.
- Re-run the export after workspace updates instead of editing exported files by hand.
- This export does not convert the workspace into repo-local upstream Spec Kit.
- Existing projects are intentionally left unchanged.
- `studio-first template precedence` remains unchanged.

## Contents

- `agents/` contains shared agent definitions.
- `prompts/` contains shared prompt routing files.
- `manifest.json` contains generation metadata.
"@
$readmePath = Join-Path $resolvedOutputDir 'README.md'
Set-Content -LiteralPath $readmePath -Value $readme -Encoding UTF8

$result = [ordered]@{
    SOURCE_MODE   = $runtimeSources.MODE
    OUTPUT_DIR    = $resolvedOutputDir
    AGENTS_DIR    = $agentsTarget
    PROMPTS_DIR   = $promptsTarget
    AGENT_COUNT   = $agentFiles.Count
    PROMPT_COUNT  = $promptFiles.Count
    MANIFEST_PATH = $manifestPath
    README_PATH   = $readmePath
}

if ($Json) {
    [PSCustomObject]$result | ConvertTo-Json -Depth 4
    exit 0
}

Write-Output "Exported generic agent pack to: $resolvedOutputDir"
Write-Output "Agents: $($agentFiles.Count)"
Write-Output "Prompts: $($promptFiles.Count)"
Write-Output "Manifest: $manifestPath"
Write-Output "README: $readmePath"
