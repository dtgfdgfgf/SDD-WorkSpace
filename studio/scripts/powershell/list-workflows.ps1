#!/usr/bin/env pwsh

#Requires -Version 7.0
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
$registry = Get-WorkflowRegistrySnapshot -StudioRoot $studioRoot
$errors = @($registry.ERRORS)
$catalogPath = $registry.CATALOG_PATH
$statePath = $registry.STATE_PATH

$workflows = @()
foreach ($entry in @($registry.WORKFLOWS)) {
    if ($Id -and [string]$entry.ID -ne $Id) { continue }

    $authorization = Get-WorkflowExecutionAuthorization -Registry $registry -Id ([string]$entry.ID)
    $workflows += [ordered]@{
        id                  = [string]$entry.ID
        title               = [string]$entry.TITLE
        version             = [string]$entry.VERSION
        sourcePath          = [string]$entry.SOURCE_PATH
        reviewStatus        = [string]$entry.REVIEW_STATUS
        trustLevel          = [string]$entry.TRUST_LEVEL
        defaultEnabled      = $entry.DEFAULT_ENABLED
        enabled             = $entry.ENABLED
        executionAuthorized = $authorization.AUTHORIZED
        authorizationErrors = @($authorization.ERRORS)
        stepTypesUsed       = @($entry.STEP_TYPES_USED)
        pinnedVersion       = $entry.PINNED_VERSION
        stateSource         = $entry.STATE_SOURCE
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
    if ($result.VALID) { exit 0 } else { exit 1 }
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
