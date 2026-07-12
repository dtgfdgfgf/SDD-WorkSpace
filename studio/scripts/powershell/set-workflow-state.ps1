#!/usr/bin/env pwsh

#Requires -Version 7.0
<#
.SYNOPSIS
    Update the studio workflow enable state ledger.

.DESCRIPTION
    Writes one entry into studio/workflows/state.json. The workflow MUST already
    exist in catalog.json. Workflows in reviewStatus other than approved or
    deprecated cannot be enabled. Mirrors the shape of set-extension-state.ps1.

.PARAMETER Id
    The workflow id to update.

.PARAMETER State
    enabled or disabled.

.PARAMETER Json
    Emit a structured JSON summary.

.PARAMETER Help
    Show this help message.
#>

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
    Write-Output 'Usage: ./set-workflow-state.ps1 -Id <workflow-id> -State enabled|disabled [-Json] [-Help]'
    exit 0
}

. "$PSScriptRoot/common.ps1"

$studioRoot = Find-StudioRoot -StartDir $PSScriptRoot
if (-not $studioRoot) { throw 'Unable to resolve studio root.' }
$workflowsRoot = Join-Path $studioRoot 'workflows'
$catalogPath = Join-Path $workflowsRoot 'catalog.json'
$statePath = Join-Path $workflowsRoot 'state.json'

if (-not (Test-Path -LiteralPath $catalogPath)) { throw "catalog.json not found: $catalogPath" }
if (-not (Test-Path -LiteralPath $statePath)) { throw "state.json not found: $statePath" }

$catalog = Read-JsonFile -Path $catalogPath
$workflowEntry = $null
foreach ($entry in @($catalog.workflows)) {
    if (-not $entry) { continue }
    $entryHt = if ($entry -is [hashtable]) { $entry } else {
        $h = @{}
        $entry.PSObject.Properties | ForEach-Object { $h[$_.Name] = $_.Value }
        $h
    }
    if ([string]$entryHt.id -eq $Id) {
        $workflowEntry = $entryHt
        break
    }
}

if (-not $workflowEntry) {
    Write-Error "Workflow not found in catalog: $Id"
    exit 1
}

if ($State -eq 'enabled' -and [string]$workflowEntry.reviewStatus -notin @('approved', 'deprecated')) {
    Write-Error "Workflow reviewStatus '$($workflowEntry.reviewStatus)' cannot be enabled: $Id"
    exit 1
}

$stateData = Read-JsonFile -Path $statePath
if (-not $stateData) {
    $stateData = [ordered]@{
        version = '1.0.0'
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
    pinnedVersion = [string]$workflowEntry.version
    changedAt     = Get-IsoTimestamp
    source        = 'manual'
}
$stateData.updated = Get-IsoTimestamp

Write-JsonFile -Path $statePath -Data $stateData -Depth 8

$result = [ordered]@{
    ID             = $Id
    STATE          = $State
    ENABLED        = $enabled
    PINNED_VERSION = [string]$workflowEntry.version
    REVIEW_STATUS  = [string]$workflowEntry.reviewStatus
    STATE_PATH     = $statePath
}

if ($Json) {
    [PSCustomObject]$result | ConvertTo-Json -Depth 5
    exit 0
}

Write-Output ("Updated workflow state: {0} -> {1}" -f $Id, $State)
Write-Output "State file: $statePath"
