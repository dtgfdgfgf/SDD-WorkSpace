#!/usr/bin/env pwsh

#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Id,
    [Parameter(Mandatory = $true)]
    [ValidateSet('enabled', 'disabled')]
    [string]$State,
    [switch]$Json,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    $helpLines = @(
        'Usage: ./set-extension-state.ps1 -Id <extension-id> -State enabled|disabled [-Json] [-Help]',
        '',
        'Updates the studio-first extension state ledger without touching any project tree.',
        '',
        'Options:',
        '  -Id      Extension id to update',
        '  -State   enabled or disabled',
        '  -Json    Output structured JSON summary',
        '  -Help    Show this help message'
    )
    Write-Output ($helpLines -join "`n")
    exit 0
}

. "$PSScriptRoot/common.ps1"

$paths = Get-StudioSharedLayerPaths -StartDir $PSScriptRoot
$validation = Invoke-JsonScript -ScriptPath $paths.EXTENSIONS_VALIDATOR_PATH -Arguments @('-Json')
$extension = @($validation.EXTENSIONS | Where-Object { $_.id -eq $Id }) | Select-Object -First 1

if (-not $extension) {
    Write-Error "Extension not found: $Id"
    exit 1
}

if (-not $extension.cataloged -or -not $extension.hasManifest) {
    Write-Error "Extension must be cataloged and have a manifest before state can be updated: $Id"
    exit 1
}

if ($State -eq 'enabled' -and $extension.reviewStatus -notin @('approved', 'deprecated')) {
    Write-Error "Extension reviewStatus '$($extension.reviewStatus)' cannot be enabled: $Id"
    exit 1
}

$stateData = Read-JsonFile -Path $paths.EXTENSIONS_STATE_PATH
if (-not $stateData) {
    $stateData = [ordered]@{
        version = '1.1.0'
        updated = Get-IsoTimestamp
        states  = @{}
    }
}

if (-not $stateData.ContainsKey('states') -or $stateData.states -isnot [hashtable]) {
    $stateData.states = @{}
}

$enabled = ($State -eq 'enabled')
$stateData.states[$Id] = [ordered]@{
    enabled       = $enabled
    pinnedVersion = $extension.version
    changedAt     = Get-IsoTimestamp
    source        = 'manual'
}
$stateData.updated = Get-IsoTimestamp

Write-JsonFile -Path $paths.EXTENSIONS_STATE_PATH -Data $stateData -Depth 8

$result = [ordered]@{
    ID            = $Id
    STATE         = $State
    ENABLED       = $enabled
    PINNED_VERSION = $extension.version
    REVIEW_STATUS = $extension.reviewStatus
    STATE_PATH    = $paths.EXTENSIONS_STATE_PATH
}

if ($Json) {
    [PSCustomObject]$result | ConvertTo-Json -Depth 5
    exit 0
}

Write-Output ("Updated extension state: {0} -> {1}" -f $Id, $State)
Write-Output "State file: $($paths.EXTENSIONS_STATE_PATH)"
