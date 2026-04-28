#!/usr/bin/env pwsh
<#
.SYNOPSIS
Validate runtime agent bootstrap adapters for one project root.

.DESCRIPTION
Checks AGENTS.md, CLAUDE.md, and .github/copilot-instructions.md for a synchronized
generated governance bootstrap block and dual-layer constitution references.
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$Json,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Output 'Usage: ./check-agent-bootstrap.ps1 -ProjectRoot <path> [-Json]'
    exit 0
}

. "$PSScriptRoot/common.ps1"

$script:BeginMarker = '<!-- BEGIN GENERATED GOVERNANCE BOOTSTRAP -->'
$script:EndMarker = '<!-- END GENERATED GOVERNANCE BOOTSTRAP -->'

function New-BootstrapFailure {
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$Message,
        [string]$Path
    )

    [ordered]@{
        id      = $Id
        message = $Message
        path    = $Path
    }
}

function Convert-ToPortableRelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$FromPath,
        [Parameter(Mandatory = $true)][string]$ToPath
    )

    return ([System.IO.Path]::GetRelativePath($FromPath, $ToPath) -replace '\\', '/')
}

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

function Get-GovernanceBootstrapBlock {
    param([Parameter(Mandatory = $true)][string]$Content)

    $pattern = '(?s)' + [regex]::Escape($script:BeginMarker) + '.*?' + [regex]::Escape($script:EndMarker)
    $match = [regex]::Match($Content, $pattern)
    if (-not $match.Success) {
        return $null
    }

    return $match.Value.Trim()
}

function Get-AgentBootstrapCheckContext {
    param([Parameter(Mandatory = $true)][string]$Root)

    $resolvedProjectRoot = (Resolve-Path -LiteralPath $Root).Path
    $studioRoot = Find-StudioRoot -StartDir $resolvedProjectRoot
    if (-not $studioRoot) {
        $studioRoot = Find-StudioRoot -StartDir $PSScriptRoot
    }
    if (-not $studioRoot) {
        throw 'Unable to resolve studio root.'
    }

    $studioConstitutionPath = Join-Path $studioRoot 'constitution/constitution.md'
    $projectConstitutionPath = Join-Path $resolvedProjectRoot '.specify/memory/constitution.md'

    [ordered]@{
        ProjectRoot                = $resolvedProjectRoot
        StudioRoot                 = $studioRoot
        StudioConstitutionPath     = $studioConstitutionPath
        StudioConstitutionVersion  = Get-StudioConstitutionVersion -StudioConstitutionPath $studioConstitutionPath
        ProjectConstitutionPath    = $projectConstitutionPath
        HasProjectConstitution     = Test-Path -LiteralPath $projectConstitutionPath
        RelativeStudioConstitution = Convert-ToPortableRelativePath -FromPath $resolvedProjectRoot -ToPath $studioConstitutionPath
        RelativeProjectConstitution = '.specify/memory/constitution.md'
        AdapterPaths               = [ordered]@{
            Agents  = Join-Path $resolvedProjectRoot 'AGENTS.md'
            Claude  = Join-Path $resolvedProjectRoot 'CLAUDE.md'
            Copilot = Join-Path $resolvedProjectRoot '.github/copilot-instructions.md'
        }
    }
}

function Test-ContainsInlineStudioConstitution {
    param([string]$Content)

    if ([string]::IsNullOrWhiteSpace($Content)) {
        return $false
    }

    return ($Content -match '(?m)^#\s+Studio Constitution\s*$')
}

$context = Get-AgentBootstrapCheckContext -Root $ProjectRoot
$failures = @()
$checks = @()
$blocks = @{}
$contents = @{}

foreach ($entry in $context.AdapterPaths.GetEnumerator()) {
    $path = $entry.Value
    $exists = Test-Path -LiteralPath $path
    $content = if ($exists) { Get-Content -LiteralPath $path -Raw } else { '' }
    $block = if ($exists) { Get-GovernanceBootstrapBlock -Content $content } else { $null }

    $contents[$entry.Key] = $content
    $blocks[$entry.Key] = $block

    $checks += [ordered]@{
        name     = $entry.Key
        path     = $path
        exists   = $exists
        hasBlock = [bool]$block
    }

    if (-not $exists) {
        $failures += New-BootstrapFailure -Id "missing-$($entry.Key.ToLower())" -Message 'Required runtime adapter is missing.' -Path $path
    } elseif (-not $block) {
        $failures += New-BootstrapFailure -Id "missing-block-$($entry.Key.ToLower())" -Message 'Generated governance bootstrap block is missing.' -Path $path
    }

    if (Test-ContainsInlineStudioConstitution -Content $content) {
        $failures += New-BootstrapFailure -Id "inline-studio-constitution-$($entry.Key.ToLower())" -Message 'Adapter appears to inline-copy the Studio Constitution instead of referencing the centralized source.' -Path $path
    }
}

$presentBlocks = @($blocks.Values | Where-Object { $_ })
if ($presentBlocks.Count -gt 1) {
    $firstBlock = $presentBlocks[0]
    foreach ($block in $presentBlocks) {
        if ($block -ne $firstBlock) {
            $failures += New-BootstrapFailure -Id 'bootstrap-block-drift' -Message 'Generated governance bootstrap blocks are not byte-for-byte identical.' -Path $context.ProjectRoot
            break
        }
    }
}

foreach ($entry in $blocks.GetEnumerator()) {
    if ($entry.Value -and $entry.Value.IndexOf("**Studio Constitution Version:** $($context.StudioConstitutionVersion)", [System.StringComparison]::Ordinal) -lt 0) {
        $failures += New-BootstrapFailure -Id "stale-studio-version-$($entry.Key.ToLower())" -Message "Generated bootstrap does not match current Studio Constitution version $($context.StudioConstitutionVersion)." -Path $context.AdapterPaths[$entry.Key]
    }
}

foreach ($entry in $contents.GetEnumerator()) {
    if (-not [string]::IsNullOrWhiteSpace($entry.Value)) {
        if ($entry.Value.IndexOf($context.RelativeStudioConstitution, [System.StringComparison]::Ordinal) -lt 0) {
            $failures += New-BootstrapFailure -Id "missing-studio-reference-$($entry.Key.ToLower())" -Message "Adapter does not reference the resolved Studio Constitution path: $($context.RelativeStudioConstitution)" -Path $context.AdapterPaths[$entry.Key]
        }

        if ($context.HasProjectConstitution -and $entry.Value.IndexOf($context.RelativeProjectConstitution, [System.StringComparison]::Ordinal) -lt 0) {
            $failures += New-BootstrapFailure -Id "missing-project-reference-$($entry.Key.ToLower())" -Message 'Adapter does not reference .specify/memory/constitution.md.' -Path $context.AdapterPaths[$entry.Key]
        }
    }
}

$claudeContent = [string]$contents.Claude
if (-not [string]::IsNullOrWhiteSpace($claudeContent)) {
    $studioImportPattern = '(?m)^@' + [regex]::Escape($context.RelativeStudioConstitution) + '\s*$'
    if ($claudeContent -notmatch $studioImportPattern) {
        $failures += New-BootstrapFailure -Id 'missing-claude-studio-import' -Message 'CLAUDE.md is missing the direct Studio Constitution @path import.' -Path $context.AdapterPaths.Claude
    }

    if ($context.HasProjectConstitution -and $claudeContent -notmatch '(?m)^@\.specify/memory/constitution\.md\s*$') {
        $failures += New-BootstrapFailure -Id 'missing-claude-project-import' -Message 'CLAUDE.md is missing the direct project constitution @path import.' -Path $context.AdapterPaths.Claude
    }
}

$result = [ordered]@{
    VALID = ($failures.Count -eq 0)
    ERROR_COUNT = $failures.Count
    PROJECT_ROOT = $context.ProjectRoot
    STUDIO_CONSTITUTION = $context.StudioConstitutionPath
    PROJECT_CONSTITUTION = if ($context.HasProjectConstitution) { $context.ProjectConstitutionPath } else { $null }
    CHECKS = $checks
    FAILURES = $failures
}

if ($Json) {
    [PSCustomObject]$result | ConvertTo-Json -Depth 8
} else {
    Write-Output ("Agent bootstrap valid: {0}" -f $result.VALID.ToString().ToLower())
    if ($failures.Count -gt 0) {
        Write-Output 'Failures:'
        foreach ($failure in $failures) {
            $pathSuffix = if ($failure.path) { " [$($failure.path)]" } else { '' }
            Write-Output ("- {0}: {1}{2}" -f $failure.id, $failure.message, $pathSuffix)
        }
    }
}

exit $(if ($result.VALID) { 0 } else { 1 })
