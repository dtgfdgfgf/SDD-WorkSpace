#!/usr/bin/env pwsh
<#
.SYNOPSIS
Post-edit constitution governance checker.

.DESCRIPTION
Use after a human or LLM explicitly edits the Studio or Project Constitution.
This script does not author constitution content. It validates version metadata,
updates generated adapter bootstrap metadata, and runs the relevant bootstrap check.
#>

[CmdletBinding()]
param(
    [ValidateSet('Studio', 'Project')]
    [string]$Scope,

    [string]$ProjectRoot = (Get-Location).Path,
    [string]$Version,
    [string]$Summary = '',
    [switch]$Json,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Output 'Usage: ./update-constitution.ps1 -Scope Studio|Project -Version <version> [-ProjectRoot <path>] [-Summary <text>] [-Json]'
    exit 0
}

if (-not $Scope -or -not $Version) {
    throw 'Scope and Version are required unless -Help is used.'
}

. "$PSScriptRoot/common.ps1"

function New-ConstitutionUpdateFailure {
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

function Get-ConstitutionContent {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    return Get-Content -LiteralPath $Path -Raw
}

function Test-VersionPresent {
    param(
        [string]$Content,
        [string]$ExpectedVersion
    )

    if ([string]::IsNullOrWhiteSpace($Content)) {
        return $false
    }

    return ($Content -match "(?m)^\*\*Version:\*\*\s*$([regex]::Escape($ExpectedVersion))\s*$")
}

function Test-ChangelogPresent {
    param([string]$Content)

    if ([string]::IsNullOrWhiteSpace($Content)) {
        return $false
    }

    return ($Content -match '(?mi)^#{2,4}\s+(Changelog|Change Log|Version History|Constitution Review)\s*$')
}

function Test-ProjectConstitutionDoesNotRelaxStudio {
    param([string]$Content)

    if ([string]::IsNullOrWhiteSpace($Content)) {
        return $true
    }

    $relaxPatterns = @(
        'can\s+relax\s+studio',
        'may\s+skip\s+sdd',
        'override\s+studio\s+constitution',
        'replace\s+studio\s+constitution'
    )

    foreach ($pattern in $relaxPatterns) {
        if ($Content -match $pattern) {
            return $false
        }
    }

    return $true
}

function Invoke-JsonTool {
    param(
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [string[]]$Arguments = @()
    )

    $output = & $ScriptPath @Arguments 2>&1
    $exitCode = if ($null -ne $LASTEXITCODE) { [int]$LASTEXITCODE } else { 0 }
    $raw = if ($output) { $output -join [Environment]::NewLine } else { '' }
    $parsed = $null
    if (-not [string]::IsNullOrWhiteSpace($raw)) {
        try {
            $parsed = $raw | ConvertFrom-Json -AsHashtable
        } catch {
            $parsed = $null
        }
    }

    [ordered]@{
        exitCode = $exitCode
        raw      = $raw
        parsed   = $parsed
    }
}

$failures = @()
$resolvedProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$studioRoot = Find-StudioRoot -StartDir $resolvedProjectRoot
if (-not $studioRoot) {
    $studioRoot = Find-StudioRoot -StartDir $PSScriptRoot
}
if (-not $studioRoot) {
    throw 'Unable to resolve studio root.'
}
$workspaceRoot = Split-Path -Parent $studioRoot
$syncScript = Join-Path $studioRoot 'scripts/powershell/sync-agent-bootstrap.ps1'
$checkScript = Join-Path $studioRoot 'scripts/powershell/check-agent-bootstrap.ps1'
$runtimeAuditScript = Join-Path $studioRoot 'scripts/powershell/check-speckit-runtime.ps1'

if ($Scope -eq 'Studio') {
    $constitutionPath = Join-Path $studioRoot 'constitution/constitution.md'
    $content = Get-ConstitutionContent -Path $constitutionPath
    if (-not $content) {
        $failures += New-ConstitutionUpdateFailure -Id 'missing-studio-constitution' -Message 'Studio Constitution is missing.' -Path $constitutionPath
    } else {
        if (-not (Test-VersionPresent -Content $content -ExpectedVersion $Version)) {
            $failures += New-ConstitutionUpdateFailure -Id 'studio-version-not-updated' -Message "Studio Constitution does not declare version $Version." -Path $constitutionPath
        }
        if (-not (Test-ChangelogPresent -Content $content)) {
            $failures += New-ConstitutionUpdateFailure -Id 'studio-changelog-missing' -Message 'Studio Constitution lacks a recognizable changelog/review section.' -Path $constitutionPath
        }
    }

    $mainlineNote = @(Get-ChildItem -LiteralPath (Join-Path $workspaceRoot 'docs/mainline-updates') -File -Filter '*.md' -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne 'README.md' } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1)
    if ($mainlineNote.Count -eq 0) {
        $failures += New-ConstitutionUpdateFailure -Id 'mainline-note-missing' -Message 'Studio constitution changes require a docs/mainline-updates note.' -Path (Join-Path $workspaceRoot 'docs/mainline-updates')
    }

    if ($failures.Count -eq 0) {
        $sync = Invoke-JsonScriptDetailed -ScriptPath $syncScript -Arguments @('-ProjectRoot', $workspaceRoot, '-StudioConstitutionVersion', $Version, '-Write', '-Json')
        if ($sync.EXIT_CODE -ne 0) {
            $failures += New-ConstitutionUpdateFailure -Id 'root-bootstrap-sync-failed' -Message $sync.RAW -Path $workspaceRoot
        }

        $audit = Invoke-JsonScriptDetailed -ScriptPath $runtimeAuditScript -Arguments @('-Json')
        if ($audit.EXIT_CODE -ne 0) {
            $failures += New-ConstitutionUpdateFailure -Id 'runtime-audit-failed' -Message 'Shared runtime audit failed after Studio Constitution update.' -Path $runtimeAuditScript
        }
    }
} else {
    $constitutionPath = Join-Path $resolvedProjectRoot '.specify/memory/constitution.md'
    $content = Get-ConstitutionContent -Path $constitutionPath
    if (-not $content) {
        $failures += New-ConstitutionUpdateFailure -Id 'missing-project-constitution' -Message 'Project Constitution is missing.' -Path $constitutionPath
    } else {
        if (-not (Test-VersionPresent -Content $content -ExpectedVersion $Version)) {
            $failures += New-ConstitutionUpdateFailure -Id 'project-version-not-updated' -Message "Project Constitution does not declare version $Version." -Path $constitutionPath
        }
        if (-not (Test-ChangelogPresent -Content $content)) {
            $failures += New-ConstitutionUpdateFailure -Id 'project-changelog-missing' -Message 'Project Constitution lacks a recognizable changelog section.' -Path $constitutionPath
        }
        if (-not (Test-ProjectConstitutionDoesNotRelaxStudio -Content $content)) {
            $failures += New-ConstitutionUpdateFailure -Id 'project-constitution-relaxes-studio' -Message 'Project Constitution appears to relax, override, or replace Studio Constitution rules.' -Path $constitutionPath
        }
    }

    if ($failures.Count -eq 0) {
        $sync = Invoke-JsonScriptDetailed -ScriptPath $syncScript -Arguments @('-ProjectRoot', $resolvedProjectRoot, '-Write', '-Json')
        if ($sync.EXIT_CODE -ne 0) {
            $failures += New-ConstitutionUpdateFailure -Id 'project-bootstrap-sync-failed' -Message $sync.RAW -Path $resolvedProjectRoot
        }

        $check = Invoke-JsonScriptDetailed -ScriptPath $checkScript -Arguments @('-ProjectRoot', $resolvedProjectRoot, '-Json')
        if ($check.EXIT_CODE -ne 0) {
            $failures += New-ConstitutionUpdateFailure -Id 'project-bootstrap-check-failed' -Message 'Project agent bootstrap check failed.' -Path $resolvedProjectRoot
        }
    }
}

$result = [ordered]@{
    VALID = ($failures.Count -eq 0)
    ERROR_COUNT = $failures.Count
    SCOPE = $Scope
    PROJECT_ROOT = $resolvedProjectRoot
    VERSION = $Version
    SUMMARY = $Summary
    FAILURES = $failures
}

if ($Json) {
    [PSCustomObject]$result | ConvertTo-Json -Depth 8
} else {
    Write-Output ("Constitution update valid: {0}" -f $result.VALID.ToString().ToLower())
    if ($failures.Count -gt 0) {
        Write-Output 'Failures:'
        foreach ($failure in $failures) {
            $pathSuffix = if ($failure.path) { " [$($failure.path)]" } else { '' }
            Write-Output ("- {0}: {1}{2}" -f $failure.id, $failure.message, $pathSuffix)
        }
    }
}

exit $(if ($result.VALID) { 0 } else { 1 })
