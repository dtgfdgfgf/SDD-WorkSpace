#!/usr/bin/env pwsh

#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceRoot,
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [ValidateScript({
        if ([string]::IsNullOrWhiteSpace($_)) { return $true }
        # Git ref naming rules (subset): no spaces, no .., no leading/trailing slash,
        # no consecutive slashes, no end with .lock, no @{ sequence.
        if ($_ -match '\s' -or $_ -match '\.\.' -or $_ -match '@\{' -or $_ -match '//' -or $_ -match '\.lock$' -or $_ -match '^/' -or $_ -match '/$') {
            throw "Invalid git branch name: '$_'. Branch names cannot contain spaces, '..', '@{', '//', or end with '.lock'."
        }
        return $true
    })]
    [string]$Branch,
    [ValidateScript({
        if ([string]::IsNullOrWhiteSpace($_)) { return $true }
        if ($_ -match '\s' -or $_ -match '@\{' -or $_ -match '//' -or $_ -match '\.lock$') {
            throw "Invalid git commit-ish: '$_'. Commit-ish cannot contain spaces, '@{', '//', or end with '.lock'."
        }
        return $true
    })]
    [string]$Commitish,
    [switch]$Json
)

$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/common.ps1"

$resolvedSourceRoot = Resolve-AbsolutePath -Path $SourceRoot
$workspaceRoot = Find-WorkspaceRoot -StartDir $resolvedSourceRoot
if (-not $workspaceRoot) {
    throw 'Unable to resolve workspace root from source project.'
}

$gitRootRaw = git -C $resolvedSourceRoot rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0 -or -not $gitRootRaw) {
    throw "Source path is not inside a Git repository: $resolvedSourceRoot"
}

$projectRoot = Resolve-AbsolutePath -Path $gitRootRaw
$targetRoot = Resolve-AbsolutePath -Path $Path -BaseDir (Split-Path -Parent $projectRoot)

if (Test-Path -LiteralPath $targetRoot) {
    throw "Target worktree path already exists: $targetRoot"
}

$gitArguments = @('worktree', 'add')
if ($Branch) {
    $gitArguments += @('-b', $Branch, $targetRoot)
    if ($Commitish) {
        $gitArguments += $Commitish
    }
} elseif ($Commitish) {
    $gitArguments += @($targetRoot, $Commitish)
} else {
    throw 'Specify either -Branch (to create a new branch worktree) or -Commitish (to checkout an existing ref).'
}

& git -C $projectRoot @gitArguments
if ($LASTEXITCODE -ne 0) {
    throw 'git worktree add failed.'
}

# Configure the depth-specific hooks path in this worktree's config.worktree.
# A normal `git config core.hooksPath` write would mutate the repository config
# shared by the source and every linked worktree.
$worktreeHooks = Set-ProjectWorktreeHooksPath -WorktreeRoot $targetRoot -WorkspaceRoot $workspaceRoot

# Restore shared agent junction parity for both .github/agents and .claude/agents.
$junctions = @(Initialize-ProjectSharedAgentJunctions -ProjectRoot $targetRoot -WorkspaceRoot $workspaceRoot)
$copiedFiles = @()

foreach ($relativePath in @('AGENTS.md', 'CLAUDE.md', '.github/copilot-instructions.md')) {
    $sourcePath = Join-Path $projectRoot $relativePath
    $targetPath = Join-Path $targetRoot $relativePath

    if ((Test-Path -LiteralPath $sourcePath) -and -not (Test-Path -LiteralPath $targetPath)) {
        $targetParent = Split-Path -Parent $targetPath
        if ($targetParent -and -not (Test-Path -LiteralPath $targetParent)) {
            New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
        }
        Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force
        $copiedFiles += [ordered]@{
            source = $sourcePath
            target = $targetPath
        }
    }
}

Get-ChildItem -LiteralPath $projectRoot -File -Filter '*.code-workspace' | ForEach-Object {
    $targetWorkspaceFile = Join-Path $targetRoot $_.Name
    if (-not (Test-Path -LiteralPath $targetWorkspaceFile)) {
        Copy-Item -LiteralPath $_.FullName -Destination $targetWorkspaceFile -Force
        $copiedFiles += [ordered]@{
            source = $_.FullName
            target = $targetWorkspaceFile
        }
    }
}

$result = [ordered]@{
    projectRoot      = $projectRoot
    targetRoot       = $targetRoot
    junctions        = $junctions
    copiedFiles      = $copiedFiles
    worktreeHooksPath = $worktreeHooks.hooksPath
    hooksConfigScope  = $worktreeHooks.configScope
}

if ($Json) {
    [PSCustomObject]$result | ConvertTo-Json -Depth 6
    exit 0
}

Write-Output ("Created worktree: {0}" -f $targetRoot)
foreach ($junction in $junctions) {
    if ($junction.available) {
        $verb = if ($junction.created) { 'Created' } else { 'Verified' }
        Write-Output ("- {0} {1} -> {2}" -f $verb, $junction.path, $junction.target)
    } else {
        Write-Warning ("Shared {0} agents source not found: {1}" -f $junction.agentType, $junction.target)
    }
}
foreach ($copyResult in $copiedFiles) {
    Write-Output ("- Copied parity file: {0}" -f $copyResult.target)
}
