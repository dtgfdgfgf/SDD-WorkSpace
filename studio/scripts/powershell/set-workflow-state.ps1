#!/usr/bin/env pwsh

#Requires -Version 7.0
<#
.SYNOPSIS
    Update the studio workflow enable state ledger.

.DESCRIPTION
    Writes one entry into studio/workflows/state.json. The workflow MUST already
    exist in a valid shared registry. Only approved workflows can be newly
    enabled. A deprecated workflow enable request is accepted only as a
    byte-preserving no-op for an already-enabled state pinned to the current
    catalog version.

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

$registry = Get-WorkflowRegistrySnapshot -StudioRoot $studioRoot
if (-not $registry.VALID) {
    Write-Error ("Workflow registry is invalid; refusing state mutation: {0}" -f (@($registry.ERRORS) -join '; '))
    exit 1
}

$workflow = @($registry.WORKFLOWS | Where-Object { [string]$_.ID -eq $Id }) |
    Select-Object -First 1
if (-not $workflow) {
    Write-Error "Workflow not found in catalog: $Id"
    exit 1
}
$workflowEntry = $workflow.CATALOG_ENTRY
$reviewStatus = [string]$workflow.REVIEW_STATUS

if ($State -eq 'enabled') {
    if ($reviewStatus -eq 'deprecated') {
        if ($workflow.DEPRECATED_ENABLE_NOOP_ELIGIBLE -ne $true) {
            Write-Error ("Deprecated workflow cannot be newly enabled: {0}" -f (@($workflow.DEPRECATED_ENABLE_ERRORS) -join '; '))
            exit 1
        }

        $result = [ordered]@{
            ID             = $Id
            STATE          = $State
            ENABLED        = $true
            PINNED_VERSION = [string]$workflow.VERSION
            REVIEW_STATUS  = $reviewStatus
            STATE_PATH     = $statePath
            CHANGED        = $false
            NO_OP          = $true
        }

        if ($Json) {
            [PSCustomObject]$result | ConvertTo-Json -Depth 5
            exit 0
        }

        Write-Output ("Workflow state unchanged: {0} is deprecated and already enabled at pinned version {1}." -f $Id, $workflow.VERSION)
        Write-Output "State file: $statePath"
        exit 0
    }

    if ($reviewStatus -ne 'approved') {
        Write-Error "Workflow reviewStatus '$reviewStatus' cannot be enabled: $Id"
        exit 1
    }
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
    REVIEW_STATUS  = $reviewStatus
    STATE_PATH     = $statePath
    CHANGED        = $true
    NO_OP          = $false
}

if ($Json) {
    [PSCustomObject]$result | ConvertTo-Json -Depth 5
    exit 0
}

Write-Output ("Updated workflow state: {0} -> {1}" -f $Id, $State)
Write-Output "State file: $statePath"
