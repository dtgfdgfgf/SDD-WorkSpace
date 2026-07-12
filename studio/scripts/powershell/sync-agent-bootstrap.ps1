#!/usr/bin/env pwsh

#Requires -Version 7.0
<#
.SYNOPSIS
Create or synchronize the three runtime agent bootstrap adapters for one project root.

.DESCRIPTION
Maintains AGENTS.md, CLAUDE.md, and .github/copilot-instructions.md as thin runtime
adapters over the same generated governance bootstrap block. This script does not
modify studio/constitution/constitution.md or .specify/memory/constitution.md.
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [ValidateScript({
        if ([string]::IsNullOrWhiteSpace($_)) { return $true }
        $allowed = @('AGENTS.md', 'CLAUDE.md', '.github/copilot-instructions.md', 'copilot-instructions.md')
        if ($_ -in @('AGENTS.md', 'CLAUDE.md', '.github/copilot-instructions.md')) {
            return $true
        }
        # Allow absolute or relative paths whose basename matches one of the canonical adapters,
        # so that callers in scripts and tests can pass a fully-resolved path.
        $leaf = Split-Path -Leaf $_
        if ($leaf -in $allowed) {
            return $true
        }
        throw "Invalid -From value: '$_'. Must be one of: AGENTS.md, CLAUDE.md, .github/copilot-instructions.md, or a path whose basename matches one of these."
    })]
    [string]$From,
    [string]$StudioConstitutionVersion,
    [string]$ProjectName,
    [string]$ProjectType,
    [string]$ProjectDescription,
    [switch]$Write,
    [switch]$Json,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Output 'Usage: ./sync-agent-bootstrap.ps1 -ProjectRoot <path> [-From <adapter>] [-StudioConstitutionVersion <version>] [-Write] [-Json]'
    exit 0
}

. "$PSScriptRoot/common.ps1"

$script:BeginMarker = '<!-- BEGIN GENERATED GOVERNANCE BOOTSTRAP -->'
$script:EndMarker = '<!-- END GENERATED GOVERNANCE BOOTSTRAP -->'
$script:ManualStart = '<!-- MANUAL ADDITIONS START -->'
$script:ManualEnd = '<!-- MANUAL ADDITIONS END -->'

function Get-StudioConstitutionVersion {
    param([Parameter(Mandatory = $true)][string]$StudioConstitutionPath)

    if (-not (Test-Path -LiteralPath $StudioConstitutionPath)) {
        return 'UNKNOWN'
    }

    $content = Get-Content -LiteralPath $StudioConstitutionPath -Raw
    if ($content -match '(?m)^\*\*Version:\*\*\s*([^\r\n]+)\s*$') {
        return $Matches[1].Trim()
    }

    return 'UNKNOWN'
}

function Convert-ToPortableRelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$FromPath,
        [Parameter(Mandatory = $true)][string]$ToPath
    )

    return ([System.IO.Path]::GetRelativePath($FromPath, $ToPath) -replace '\\', '/')
}

function Get-AgentBootstrapContext {
    param([Parameter(Mandatory = $true)][string]$Root)

    $resolvedProjectRoot = (Resolve-Path -LiteralPath $Root).Path
    $studioRoot = Find-StudioRoot -StartDir $resolvedProjectRoot
    if (-not $studioRoot) {
        $studioRoot = Find-StudioRoot -StartDir $PSScriptRoot
    }
    if (-not $studioRoot) {
        throw 'Unable to resolve studio root.'
    }

    $workspaceRoot = Split-Path -Parent $studioRoot
    $studioConstitutionPath = Join-Path $studioRoot 'constitution/constitution.md'
    $projectConstitutionPath = Join-Path $resolvedProjectRoot '.specify/memory/constitution.md'
    $hasProjectConstitution = Test-Path -LiteralPath $projectConstitutionPath

    $name = if ($ProjectName) { $ProjectName } else { Split-Path -Leaf $resolvedProjectRoot }
    if ([string]::IsNullOrWhiteSpace($name)) { $name = 'Workspace' }

    [ordered]@{
        ProjectRoot               = $resolvedProjectRoot
        WorkspaceRoot             = $workspaceRoot
        StudioRoot                = $studioRoot
        StudioConstitutionPath    = $studioConstitutionPath
        ProjectConstitutionPath   = $projectConstitutionPath
        HasProjectConstitution    = $hasProjectConstitution
        RelativeStudioConstitution = Convert-ToPortableRelativePath -FromPath $resolvedProjectRoot -ToPath $studioConstitutionPath
        RelativeProjectConstitution = '.specify/memory/constitution.md'
        ProjectName               = $name
        ProjectType               = if ($ProjectType) { $ProjectType } else { 'Workspace' }
        ProjectDescription        = if ($ProjectDescription) { $ProjectDescription } else { 'Runtime agent bootstrap context.' }
        StudioVersion             = if ($StudioConstitutionVersion) { $StudioConstitutionVersion } else { Get-StudioConstitutionVersion -StudioConstitutionPath $studioConstitutionPath }
    }
}

function Get-GovernanceBootstrapBlock {
    param([Parameter(Mandatory = $true)][string]$Content)

    $pattern = '(?s)' + [regex]::Escape($script:BeginMarker) + '.*?' + [regex]::Escape($script:EndMarker)
    $match = [regex]::Match($Content, $pattern)
    if (-not $match.Success) {
        return $null
    }

    return $match.Value.Trim()
}

function Get-ManualSection {
    param([string]$Content)

    if ([string]::IsNullOrWhiteSpace($Content)) {
        return ''
    }

    $pattern = '(?s)' + [regex]::Escape($script:ManualStart) + '(.*?)' + [regex]::Escape($script:ManualEnd)
    $match = [regex]::Match($Content, $pattern)
    if (-not $match.Success) {
        return $Content.Trim()
    }

    return $match.Groups[1].Value.Trim()
}

function New-GovernanceBootstrapBlock {
    param([Parameter(Mandatory = $true)][hashtable]$Context)

    $projectLine = if ($Context.HasProjectConstitution) {
        '`' + $Context.RelativeProjectConstitution + '`'
    } else {
        '`N/A (workspace root)`'
    }

    @"
$script:BeginMarker
## Generated Governance Bootstrap

**Bootstrap Version:** 1
**Studio Constitution:** ``$($Context.RelativeStudioConstitution)``
**Studio Constitution Version:** $($Context.StudioVersion)
**Project Constitution:** $projectLine

This runtime adapter participates in dual-layer constitution governance.

Load and apply rules in this order:

1. ``$($Context.RelativeStudioConstitution)``
2. ``$($Context.RelativeProjectConstitution)`` when present
3. This adapter file

If either required constitution is missing or inaccessible, report governance context incomplete before planning or implementation.

Hard rules:

- Studio Constitution has highest authority.
- Project Constitution can only add stricter rules.
- Agent context files are adapters, not constitutions.
- Governed delivery work follows: specify, clarify, readiness, plan, tasks, analyze, implement.
- If documents conflict, flag drift instead of silently choosing.
$script:EndMarker
"@.Trim()
}

function Resolve-FromPath {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectRootPath,
        [Parameter(Mandatory = $true)][string]$FromPath
    )

    if ([System.IO.Path]::IsPathRooted($FromPath)) {
        return [System.IO.Path]::GetFullPath($FromPath)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $ProjectRootPath $FromPath))
}

function Get-AdapterPaths {
    param([Parameter(Mandatory = $true)][string]$ProjectRootPath)

    [ordered]@{
        Agents  = Join-Path $ProjectRootPath 'AGENTS.md'
        Claude  = Join-Path $ProjectRootPath 'CLAUDE.md'
        Copilot = Join-Path $ProjectRootPath '.github/copilot-instructions.md'
    }
}

function New-ManualBlock {
    param([string]$ManualContent)

    $body = if ([string]::IsNullOrWhiteSpace($ManualContent)) { '' } else { $ManualContent.Trim() }
    @"
$script:ManualStart
$body
$script:ManualEnd
"@.TrimEnd()
}

function New-AgentsContent {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Block,
        [string]$ManualContent
    )

    @"
# Agent Runtime Context: $($Context.ProjectName)

This file is the default runtime adapter for Codex and Copilot CLI.

$Block

<!-- governance-anchor: agents-tool-notes -->
## Tool Notes

- Read the governance bootstrap before planning, editing, or running implementation work.
- Keep shared governance additions inside the generated bootstrap block so CLAUDE.md and .github/copilot-instructions.md can be synchronized.

$(New-ManualBlock -ManualContent $ManualContent)
"@.TrimEnd()
}

function New-ClaudeContent {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Block,
        [string]$ManualContent
    )

    $imports = @("@$($Context.RelativeStudioConstitution)")
    if ($Context.HasProjectConstitution) {
        $imports += '@.specify/memory/constitution.md'
    }

    @"
# CLAUDE.md

This file is the Claude Code runtime adapter for $($Context.ProjectName).

<!-- governance-anchor: claude-direct-imports -->
## Direct Imports

$($imports -join "`n")

$Block

<!-- governance-anchor: claude-tool-notes -->
## Tool Notes

- Claude Code should use the direct imports plus the generated bootstrap before planning, editing, or running implementation work.
- Keep shared governance additions inside the generated bootstrap block so AGENTS.md and .github/copilot-instructions.md can be synchronized.

$(New-ManualBlock -ManualContent $ManualContent)
"@.TrimEnd()
}

function New-CopilotContent {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Block,
        [string]$ManualContent
    )

    @"
# Copilot Instructions: $($Context.ProjectName)

This file is the GitHub Copilot runtime adapter for this project.

$Block

## Tool Notes

- GitHub Copilot and Copilot CLI should follow the governance bootstrap before planning, editing, or suggesting implementation work.
- Keep shared governance additions inside the generated bootstrap block so AGENTS.md and CLAUDE.md can be synchronized.

$(New-ManualBlock -ManualContent $ManualContent)
"@.TrimEnd()
}

function Set-TextFileIfChanged {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content,
        [switch]$Write
    )

    $canonicalContent = ConvertTo-LfText -Content $Content
    if (-not $canonicalContent.EndsWith("`n", [System.StringComparison]::Ordinal)) {
        $canonicalContent += "`n"
    }
    $exists = Test-Path -LiteralPath $Path
    $oldContent = if ($exists) { Get-Content -LiteralPath $Path -Raw } else { $null }
    $changed = (-not $exists) -or ($oldContent -ne $canonicalContent)

    if ($changed -and $Write) {
        $parent = Split-Path -Parent $Path
        if ($parent -and -not (Test-Path -LiteralPath $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        Write-Utf8NoBomLfFile -Path $Path -Content $canonicalContent
    }

    return $changed
}

$context = Get-AgentBootstrapContext -Root $ProjectRoot
$adapterPaths = Get-AdapterPaths -ProjectRootPath $context.ProjectRoot

# Path boundary defense: every adapter target file must resolve inside $context.ProjectRoot.
# Get-AdapterPaths uses hardcoded leaf names so this is paranoid, but it locks the contract
# and rejects any future code path that constructs adapter targets from tainted input.
foreach ($adapterKey in $adapterPaths.Keys) {
    Assert-PathInsideRoot -Root $context.ProjectRoot -Candidate $adapterPaths[$adapterKey] -MessagePrefix "$adapterKey adapter path escapes project root"
}

$block = $null
if ($From) {
    $fromFullPath = Resolve-FromPath -ProjectRootPath $context.ProjectRoot -FromPath $From
    if (-not (Test-Path -LiteralPath $fromFullPath)) {
        throw "From adapter not found: $fromFullPath"
    }
    $fromContent = Get-Content -LiteralPath $fromFullPath -Raw
    $block = Get-GovernanceBootstrapBlock -Content $fromContent
    if (-not $block) {
        throw "From adapter does not contain generated governance bootstrap block: $fromFullPath"
    }
} else {
    $block = New-GovernanceBootstrapBlock -Context $context
}

$contents = [ordered]@{}
$currentAgents = if (Test-Path -LiteralPath $adapterPaths.Agents) { Get-Content -LiteralPath $adapterPaths.Agents -Raw } else { '' }
$currentClaude = if (Test-Path -LiteralPath $adapterPaths.Claude) { Get-Content -LiteralPath $adapterPaths.Claude -Raw } else { '' }
$currentCopilot = if (Test-Path -LiteralPath $adapterPaths.Copilot) { Get-Content -LiteralPath $adapterPaths.Copilot -Raw } else { '' }

$contents[$adapterPaths.Agents] = New-AgentsContent -Context $context -Block $block -ManualContent (Get-ManualSection -Content $currentAgents)
$contents[$adapterPaths.Claude] = New-ClaudeContent -Context $context -Block $block -ManualContent (Get-ManualSection -Content $currentClaude)
$contents[$adapterPaths.Copilot] = New-CopilotContent -Context $context -Block $block -ManualContent (Get-ManualSection -Content $currentCopilot)

$changedFiles = @()
foreach ($entry in $contents.GetEnumerator()) {
    if (Set-TextFileIfChanged -Path $entry.Key -Content $entry.Value -Write:$Write) {
        $changedFiles += $entry.Key
    }
}

$result = [ordered]@{
    VALID = $true
    PROJECT_ROOT = $context.ProjectRoot
    STUDIO_CONSTITUTION = $context.StudioConstitutionPath
    STUDIO_CONSTITUTION_VERSION = $context.StudioVersion
    PROJECT_CONSTITUTION = if ($context.HasProjectConstitution) { $context.ProjectConstitutionPath } else { $null }
    WRITE = [bool]$Write
    FROM = $From
    CHANGED_COUNT = $changedFiles.Count
    CHANGED_FILES = $changedFiles
}

if ($Json) {
    [PSCustomObject]$result | ConvertTo-Json -Depth 6
} else {
    Write-Output ("Agent bootstrap changed files: {0}" -f $changedFiles.Count)
    foreach ($file in $changedFiles) {
        Write-Output "- $file"
    }
}

exit 0
