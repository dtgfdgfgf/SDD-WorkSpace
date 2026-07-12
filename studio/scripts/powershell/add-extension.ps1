#!/usr/bin/env pwsh

#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceDir,
    [switch]$Force,
    [switch]$Json,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    $helpLines = @(
        'Usage: ./add-extension.ps1 -SourceDir <path> [-Force] [-Json] [-Help]',
        '',
        'Adds a workspace-local extension into the studio-first shared registry and catalog.',
        '',
        'Options:',
        '  -SourceDir Local extension source directory containing manifest.json',
        '  -Force     Replace an existing extension directory with the same id',
        '  -Json      Output structured JSON summary',
        '  -Help      Show this help message'
    )
    Write-Output ($helpLines -join "`n")
    exit 0
}

. "$PSScriptRoot/common.ps1"

$paths = Get-StudioSharedLayerPaths -StartDir $PSScriptRoot
$resolvedSourceDir = Resolve-AbsolutePath -Path $SourceDir -BaseDir (Get-Location).Path
Assert-PathInsideRoot -Root $paths.WORKSPACE_ROOT -Candidate $resolvedSourceDir -MessagePrefix 'Extension source must stay inside the workspace'

if (-not (Test-Path -LiteralPath $resolvedSourceDir -PathType Container)) {
    Write-Error "Source directory not found: $resolvedSourceDir"
    exit 1
}

$sourceManifestPath = Join-Path $resolvedSourceDir 'manifest.json'
if (-not (Test-Path -LiteralPath $sourceManifestPath)) {
    Write-Error "manifest.json not found in source directory: $resolvedSourceDir"
    exit 1
}

$manifest = Read-JsonFile -Path $sourceManifestPath
if (-not $manifest) {
    Write-Error "Unable to parse manifest: $sourceManifestPath"
    exit 1
}

foreach ($field in @('id', 'version', 'title', 'description', 'kind', 'status', 'compatibility')) {
    if (-not $manifest.ContainsKey($field) -or [string]::IsNullOrWhiteSpace([string]$manifest[$field])) {
        Write-Error "Manifest missing required field '$field': $sourceManifestPath"
        exit 1
    }
}

if ([string]$manifest.id -notmatch '^[a-z0-9][a-z0-9-]{1,63}$') {
    Write-Error "Invalid extension id '$($manifest.id)'. Expected lowercase letters, digits, and hyphens matching ^[a-z0-9][a-z0-9-]{1,63}$."
    exit 1
}

$targetDir = Join-Path $paths.EXTENSIONS_ROOT $manifest.id
Assert-PathInsideRoot -Root $paths.EXTENSIONS_ROOT -Candidate $targetDir -MessagePrefix 'Extension target escapes extensions root'
$sourceIsTarget = ([System.IO.Path]::GetFullPath($resolvedSourceDir) -eq [System.IO.Path]::GetFullPath($targetDir))

if (-not $sourceIsTarget) {
    if (Test-Path -LiteralPath $targetDir) {
        if (-not $Force) {
            Write-Error "Extension already exists: $($manifest.id). Use -Force to replace."
            exit 1
        }

        Remove-Item -LiteralPath $targetDir -Recurse -Force
    }

    Copy-Item -LiteralPath $resolvedSourceDir -Destination $targetDir -Recurse
}

$catalog = Read-JsonFile -Path $paths.EXTENSIONS_CATALOG_PATH
if (-not $catalog) {
    $catalog = [ordered]@{
        version    = '1.1.0'
        updated    = Get-IsoTimestamp
        policy     = [ordered]@{
            mode                    = 'studio-first'
            curatedOnly             = $true
            autoEnableNewExtensions = $false
            reviewStatuses          = Get-ExtensionRegistryReviewStatuses
            trustLevels             = Get-ExtensionRegistryTrustLevels
            stateSources            = Get-ExtensionStateSources
        }
        extensions = @()
    }
}

$existingEntry = @($catalog.extensions | Where-Object { $_.id -eq $manifest.id }) | Select-Object -First 1
$newEntry = [ordered]@{
    id             = $manifest.id
    version        = $manifest.version
    title          = $manifest.title
    sourcePath     = "extensions/$($manifest.id)"
    reviewStatus   = if ($existingEntry) { $existingEntry.reviewStatus } else { 'draft' }
    trustLevel     = if ($existingEntry) { $existingEntry.trustLevel } else { 'experimental' }
    defaultEnabled = if ($existingEntry -and $existingEntry.defaultEnabled -ne $null) { [bool]$existingEntry.defaultEnabled } else { $false }
    owner          = if ($existingEntry -and $existingEntry.owner) { $existingEntry.owner } elseif ($manifest.owner) { $manifest.owner } else { 'studio' }
    approvedBy     = if ($existingEntry) { $existingEntry.approvedBy } else { $null }
    approvedAt     = if ($existingEntry) { $existingEntry.approvedAt } else { $null }
    runtimeScopes  = if ($manifest.runtimeScopes) { @($manifest.runtimeScopes) } else { @() }
    capabilities   = if ($manifest.capabilities) { @($manifest.capabilities) } else { @() }
    notes          = if ($existingEntry) { $existingEntry.notes } elseif ($manifest.notes) { $manifest.notes } else { 'Added via add-extension.ps1' }
}

$catalog.extensions = @($catalog.extensions | Where-Object { $_.id -ne $manifest.id }) + @($newEntry)
$catalog.updated = Get-IsoTimestamp
Write-JsonFile -Path $paths.EXTENSIONS_CATALOG_PATH -Data $catalog -Depth 10

$validation = Invoke-JsonScript -ScriptPath $paths.EXTENSIONS_VALIDATOR_PATH -Arguments @('-Json', '-Id', $manifest.id)

$result = [ordered]@{
    ID              = $manifest.id
    SOURCE_DIR      = $resolvedSourceDir
    TARGET_DIR      = $targetDir
    SOURCE_IS_TARGET = $sourceIsTarget
    REVIEW_STATUS   = $newEntry.reviewStatus
    TRUST_LEVEL     = $newEntry.trustLevel
    DEFAULT_ENABLED = $newEntry.defaultEnabled
    VALID           = $validation.VALID
    ERROR_COUNT     = $validation.ERROR_COUNT
}

if ($Json) {
    [PSCustomObject]$result | ConvertTo-Json -Depth 6
    exit 0
}

Write-Output ("Added extension: {0}" -f $manifest.id)
Write-Output ("Target dir: {0}" -f $targetDir)
Write-Output ("Registry valid: {0}" -f $validation.VALID.ToString().ToLower())
