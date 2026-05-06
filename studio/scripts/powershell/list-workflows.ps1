#!/usr/bin/env pwsh
<#
.SYNOPSIS
    List the studio workflow registry (catalog + state ledger).

.DESCRIPTION
    Reads studio/workflows/catalog.json and studio/workflows/state.json and emits
    a list of registered workflows with their effective enabled state. Mirrors
    the shape of list-extensions.ps1.

.PARAMETER Id
    Show only the entry with this workflow id.

.PARAMETER Json
    Emit a structured JSON summary.

.PARAMETER Help
    Show this help message.
#>

[CmdletBinding()]
param(
    [string]$Id,
    [switch]$Json,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Output 'Usage: ./list-workflows.ps1 [-Id <workflow-id>] [-Json] [-Help]'
    Write-Output ''
    Write-Output 'Lists workflows registered in studio/workflows/catalog.json with their'
    Write-Output 'effective enable state from studio/workflows/state.json.'
    Write-Output ''
    Write-Output 'Options:'
    Write-Output '  -Id      Show details for one workflow id'
    Write-Output '  -Json    Output structured JSON summary'
    Write-Output '  -Help    Show this help message'
    exit 0
}

. "$PSScriptRoot/common.ps1"

$studioRoot = Find-StudioRoot -StartDir $PSScriptRoot
if (-not $studioRoot) { throw 'Unable to resolve studio root.' }
$workflowsRoot = Join-Path $studioRoot 'workflows'
$catalogPath = Join-Path $workflowsRoot 'catalog.json'
$statePath = Join-Path $workflowsRoot 'state.json'

$errors = @()
foreach ($p in @($catalogPath, $statePath)) {
    if (-not (Test-Path -LiteralPath $p)) {
        $errors += "Required file missing: $p"
    }
}

$catalog = if (Test-Path -LiteralPath $catalogPath) { Read-JsonFile -Path $catalogPath } else { $null }
$state = if (Test-Path -LiteralPath $statePath) { Read-JsonFile -Path $statePath } else { $null }

$states = @{}
if ($state -and $state.ContainsKey('states') -and $state.states -is [hashtable]) {
    $states = $state.states
}

$workflows = @()
if ($catalog -and $catalog.ContainsKey('workflows')) {
    foreach ($entry in @($catalog.workflows)) {
        if (-not $entry) { continue }
        $entryHt = if ($entry -is [hashtable]) { $entry } else {
            $h = @{}
            $entry.PSObject.Properties | ForEach-Object { $h[$_.Name] = $_.Value }
            $h
        }
        $entryId = [string]$entryHt.id
        if ($Id -and $entryId -ne $Id) { continue }

        $stateEntry = if ($states.ContainsKey($entryId)) { $states[$entryId] } else { $null }
        $effectiveEnabled = $false
        if ($stateEntry -and $null -ne $stateEntry.enabled) {
            $effectiveEnabled = [bool]$stateEntry.enabled
        } elseif ($entryHt.defaultEnabled -eq $true) {
            $effectiveEnabled = $true
        }

        $workflows += [ordered]@{
            id              = $entryId
            title           = [string]$entryHt.title
            version         = [string]$entryHt.version
            sourcePath      = [string]$entryHt.sourcePath
            reviewStatus    = [string]$entryHt.reviewStatus
            trustLevel      = [string]$entryHt.trustLevel
            defaultEnabled  = [bool]$entryHt.defaultEnabled
            enabled         = $effectiveEnabled
            stepTypesUsed   = @($entryHt.stepTypesUsed)
            pinnedVersion   = if ($stateEntry) { [string]$stateEntry.pinnedVersion } else { $null }
            stateSource     = if ($stateEntry) { [string]$stateEntry.source } else { $null }
        }
    }
}

if ($Id -and $workflows.Count -eq 0 -and $errors.Count -eq 0) {
    Write-Error "Workflow not found: $Id"
    exit 1
}

$result = [ordered]@{
    VALID         = ($errors.Count -eq 0)
    CATALOG_PATH  = $catalogPath
    STATE_PATH    = $statePath
    ERROR_COUNT   = $errors.Count
    ERRORS        = @($errors)
    COUNT         = $workflows.Count
    WORKFLOWS     = $workflows
}

if ($Json) {
    [PSCustomObject]$result | ConvertTo-Json -Depth 10
    exit 0
}

if ($workflows.Count -eq 0) {
    Write-Output 'No workflows registered in studio/workflows/.'
    if ($errors.Count -gt 0) {
        foreach ($e in $errors) { Write-Output "[ERROR] $e" }
        exit 1
    }
    exit 0
}

foreach ($w in $workflows) {
    Write-Output ("- {0} | enabled={1} | review={2} | trust={3} | version={4}" -f $w.id, $w.enabled.ToString().ToLower(), $w.reviewStatus, $w.trustLevel, $w.version)
}
foreach ($e in $errors) { Write-Output "[ERROR] $e" }
if ($errors.Count -gt 0) { exit 1 } else { exit 0 }
