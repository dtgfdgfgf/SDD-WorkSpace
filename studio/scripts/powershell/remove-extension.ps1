#!/usr/bin/env pwsh

#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Id,
    [switch]$Json,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    $helpLines = @(
        'Usage: ./remove-extension.ps1 -Id <extension-id> [-Json] [-Help]',
        '',
        'Removes a studio-first extension from the shared registry, catalog, and state ledger.',
        '',
        'Options:',
        '  -Id      Extension id to remove',
        '  -Json    Output structured JSON summary',
        '  -Help    Show this help message'
    )
    Write-Output ($helpLines -join "`n")
    exit 0
}

. "$PSScriptRoot/common.ps1"

$paths = Get-StudioSharedLayerPaths -StartDir $PSScriptRoot
$catalog = Read-JsonFile -Path $paths.EXTENSIONS_CATALOG_PATH
$state = Read-JsonFile -Path $paths.EXTENSIONS_STATE_PATH

if ($Id -notmatch '^[a-z0-9][a-z0-9-]{1,63}$') {
    Write-Error "Invalid extension id '$Id'. Expected lowercase letters, digits, and hyphens matching ^[a-z0-9][a-z0-9-]{1,63}$."
    exit 1
}

$targetDir = Join-Path $paths.EXTENSIONS_ROOT $Id
Assert-PathInsideRoot -Root $paths.EXTENSIONS_ROOT -Candidate $targetDir -MessagePrefix 'Extension target escapes extensions root'
$catalogEntry = @($catalog.extensions | Where-Object { $_.id -eq $Id }) | Select-Object -First 1
$hasManifest = Test-Path -LiteralPath (Join-Path $targetDir 'manifest.json')

if (-not $catalogEntry -and -not $hasManifest) {
    Write-Error "Extension not found: $Id"
    exit 1
}

if ($catalogEntry) {
    $catalog.extensions = @($catalog.extensions | Where-Object { $_.id -ne $Id })
    $catalog.updated = Get-IsoTimestamp
    Write-JsonFile -Path $paths.EXTENSIONS_CATALOG_PATH -Data $catalog -Depth 10
}

if ($state -and $state.ContainsKey('states') -and $state.states.ContainsKey($Id)) {
    $state.states.Remove($Id)
    $state.updated = Get-IsoTimestamp
    Write-JsonFile -Path $paths.EXTENSIONS_STATE_PATH -Data $state -Depth 8
}

if (Test-Path -LiteralPath $targetDir) {
    Remove-Item -LiteralPath $targetDir -Recurse -Force
}

$validation = Invoke-JsonScript -ScriptPath $paths.EXTENSIONS_VALIDATOR_PATH -Arguments @('-Json')

$result = [ordered]@{
    ID          = $Id
    REMOVED_DIR = $targetDir
    VALID       = $validation.VALID
    ERROR_COUNT = $validation.ERROR_COUNT
}

if ($Json) {
    [PSCustomObject]$result | ConvertTo-Json -Depth 5
    exit 0
}

Write-Output ("Removed extension: {0}" -f $Id)
Write-Output ("Registry valid: {0}" -f $validation.VALID.ToString().ToLower())
