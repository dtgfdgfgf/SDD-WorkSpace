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

function Read-WorkflowRegistryDocument {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$SchemaPath,
        [Parameter(Mandatory)] [string]$Label,
        [Parameter(Mandatory)] [string]$ExpectedRootProperty
    )

    $documentErrors = @()
    $data = $null
    $raw = $null
    $parseSucceeded = $false
    $schemaValid = $false

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        $documentErrors += "Required $Label file missing: $Path"
    } else {
        try {
            $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
            $data = $raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop
            $parseSucceeded = $true
        } catch {
            $documentErrors += "Invalid $Label JSON: $($_.Exception.Message)"
        }
    }

    if (-not (Test-Path -LiteralPath $SchemaPath -PathType Leaf)) {
        $documentErrors += "Required $Label schema missing: $SchemaPath"
    } elseif ($parseSucceeded) {
        try {
            $schema = Get-Content -LiteralPath $SchemaPath -Raw -ErrorAction Stop
            $schemaDocument = $schema | ConvertFrom-Json -AsHashtable -ErrorAction Stop
            $schemaShapeValid = (
                $schemaDocument -is [System.Collections.IDictionary] -and
                [string]$schemaDocument['type'] -eq 'object' -and
                @($schemaDocument['required']) -contains $ExpectedRootProperty -and
                $schemaDocument['properties'] -is [System.Collections.IDictionary] -and
                $schemaDocument['properties'].Contains($ExpectedRootProperty) -and
                [string]$schemaDocument['$id'] -match ('/' + [regex]::Escape([System.IO.Path]::GetFileName($SchemaPath)) + '$')
            )
            if (-not $schemaShapeValid) {
                $documentErrors += "$Label schema is missing its canonical object shape for '$ExpectedRootProperty': $SchemaPath"
            } else {
                $schemaValid = Test-Json -Json $raw -Schema $schema -ErrorAction Stop
                if (-not $schemaValid) {
                    $documentErrors += "$Label does not conform to schema: $SchemaPath"
                }
            }
        } catch {
            $documentErrors += "$Label schema validation failed: $($_.Exception.Message)"
        }
    }

    return [ordered]@{
        Data           = $data
        ParseSucceeded = $parseSucceeded
        SchemaValid    = $schemaValid
        Errors         = @($documentErrors)
    }
}

$studioRoot = Find-StudioRoot -StartDir $PSScriptRoot
if (-not $studioRoot) { throw 'Unable to resolve studio root.' }
$workflowsRoot = Join-Path $studioRoot 'workflows'
$catalogPath = Join-Path $workflowsRoot 'catalog.json'
$statePath = Join-Path $workflowsRoot 'state.json'
$catalogSchemaPath = Join-Path $workflowsRoot 'catalog.schema.json'
$stateSchemaPath = Join-Path $workflowsRoot 'state.schema.json'

$errors = @()
$catalogValidation = Read-WorkflowRegistryDocument -Path $catalogPath -SchemaPath $catalogSchemaPath -Label 'workflow catalog' -ExpectedRootProperty 'workflows'
$stateValidation = Read-WorkflowRegistryDocument -Path $statePath -SchemaPath $stateSchemaPath -Label 'workflow state' -ExpectedRootProperty 'states'
$errors += @($catalogValidation.Errors)
$errors += @($stateValidation.Errors)
$catalog = if ($catalogValidation.SchemaValid -and $catalogValidation.Data -is [System.Collections.IDictionary]) { $catalogValidation.Data } else { $null }
$state = if ($stateValidation.SchemaValid -and $stateValidation.Data -is [System.Collections.IDictionary]) { $stateValidation.Data } else { $null }

$states = @{}
if ($state -and $state.ContainsKey('states') -and $state.states -is [System.Collections.IDictionary]) {
    $states = $state.states
}

$catalogEntries = if ($catalog -and $catalog.ContainsKey('workflows')) { @($catalog.workflows) } else { @() }
$catalogIds = @($catalogEntries | ForEach-Object { [string]$_.id } | Where-Object { $_ })
foreach ($duplicate in @($catalogIds | Group-Object | Where-Object Count -gt 1)) {
    $errors += "Duplicate workflow catalog id: $($duplicate.Name)"
}

foreach ($stateId in @($states.Keys)) {
    $catalogEntry = @($catalogEntries | Where-Object { [string]$_.id -eq [string]$stateId }) | Select-Object -First 1
    if (-not $catalogEntry) {
        $errors += "Workflow state references unknown catalog id: $stateId"
        continue
    }

    $stateEntry = $states[$stateId]
    if ($stateEntry.pinnedVersion -and ([string]$stateEntry.pinnedVersion -ne [string]$catalogEntry.version)) {
        $errors += "Workflow state pinnedVersion '$($stateEntry.pinnedVersion)' differs from catalog version '$($catalogEntry.version)' for '$stateId'"
    }
}

$workflows = @()
if ($catalogEntries.Count -gt 0) {
    foreach ($entry in $catalogEntries) {
        if (-not $entry) { continue }
        $entryHt = if ($entry -is [System.Collections.IDictionary]) { $entry } else {
            $h = @{}
            $entry.PSObject.Properties | ForEach-Object { $h[$_.Name] = $_.Value }
            $h
        }
        $entryId = [string]$entryHt.id

        $sourceRoot = Join-Path $studioRoot ([string]$entryHt.sourcePath)
        if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) {
            $errors += "Workflow sourcePath does not exist for '$entryId': $($entryHt.sourcePath)"
        }

        $stateEntry = if ($states.ContainsKey($entryId)) { $states[$entryId] } else { $null }
        $reviewStatus = [string]$entryHt.reviewStatus
        $trustLevel = [string]$entryHt.trustLevel
        if ($entryHt.defaultEnabled -eq $true -and ($reviewStatus -ne 'approved' -or $trustLevel -notin @('core', 'curated'))) {
            $errors += "Workflow '$entryId' defaultEnabled=true requires reviewStatus=approved and trustLevel core or curated"
        }
        if ($stateEntry -and $stateEntry.enabled -eq $true -and $reviewStatus -notin @('approved', 'deprecated')) {
            $errors += "Workflow '$entryId' enabled state requires reviewStatus approved or deprecated"
        }

        $effectiveEnabled = $false
        if ($stateEntry -and $null -ne $stateEntry.enabled) {
            $effectiveEnabled = [bool]$stateEntry.enabled
        } elseif ($entryHt.defaultEnabled -eq $true) {
            $effectiveEnabled = $true
        }

        if ($Id -and $entryId -ne $Id) { continue }

        $workflows += [ordered]@{
            id              = $entryId
            title           = [string]$entryHt.title
            version         = [string]$entryHt.version
            sourcePath      = [string]$entryHt.sourcePath
            reviewStatus    = $reviewStatus
            trustLevel      = $trustLevel
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
