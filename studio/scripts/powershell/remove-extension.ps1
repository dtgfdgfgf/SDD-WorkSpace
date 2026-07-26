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
. "$PSScriptRoot/extension-registry-common.ps1"

$paths = Get-StudioSharedLayerPaths -StartDir $PSScriptRoot

if ($Id -notmatch '^[a-z0-9][a-z0-9-]{1,63}$') {
    Write-Error "Invalid extension id '$Id'. Expected lowercase letters, digits, and hyphens matching ^[a-z0-9][a-z0-9-]{1,63}$."
    exit 1
}

$catalogDocument = Test-ExtensionJsonDocument -Path $paths.EXTENSIONS_CATALOG_PATH -SchemaPath $paths.EXTENSIONS_CATALOG_SCHEMA -Label 'extension catalog'
$stateDocument = Test-ExtensionJsonDocument -Path $paths.EXTENSIONS_STATE_PATH -SchemaPath $paths.EXTENSIONS_STATE_SCHEMA -Label 'extension state'
if (-not $catalogDocument.VALID -or -not $stateDocument.VALID) {
    $preflightErrors = @($catalogDocument.ERRORS) + @($stateDocument.ERRORS)
    Write-Error ("Extension registry is invalid before removal: {0}" -f ($preflightErrors -join '; '))
    exit 1
}

$catalog = $catalogDocument.DATA
$state = $stateDocument.DATA
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
}

$stateChanged = $state.states.ContainsKey($Id)
if ($stateChanged) {
    $state.states.Remove($Id)
    $state.updated = Get-IsoTimestamp
}

$prospectiveCatalog = Test-ExtensionJsonValue -Data $catalog -SchemaPath $paths.EXTENSIONS_CATALOG_SCHEMA -Label 'prospective extension catalog'
$prospectiveState = Test-ExtensionJsonValue -Data $state -SchemaPath $paths.EXTENSIONS_STATE_SCHEMA -Label 'prospective extension state'
if (-not $prospectiveCatalog.VALID -or -not $prospectiveState.VALID) {
    $prospectiveErrors = @($prospectiveCatalog.ERRORS) + @($prospectiveState.ERRORS)
    Write-Error ("Extension removal is invalid before mutation: {0}" -f ($prospectiveErrors -join '; '))
    exit 1
}

$transactionDir = New-ExtensionTransactionDirectory -Paths $paths -Operation 'remove'
$catalogBaseline = Save-ExtensionTransactionFileBaseline -TransactionDir $transactionDir -SourcePath $paths.EXTENSIONS_CATALOG_PATH -Name 'catalog.json'
$stateBaseline = Save-ExtensionTransactionFileBaseline -TransactionDir $transactionDir -SourcePath $paths.EXTENSIONS_STATE_PATH -Name 'state.json'
$targetBackup = Join-Path $transactionDir 'target-backup'
$mirrorBackup = $null
$targetMoved = $false
$catalogMutationAttempted = $false
$stateMutationAttempted = $false

try {
    $mirrorBackup = Move-ExtensionMirrorToTransaction -Paths $paths -TransactionDir $transactionDir

    if (Test-Path -LiteralPath $targetDir) {
        [void](Resolve-ExistingPathInsideRoot -Root $paths.EXTENSIONS_ROOT -Candidate $targetDir -MessagePrefix 'Extension target escapes extensions root through a reparse point')
        Move-Item -LiteralPath $targetDir -Destination $targetBackup -ErrorAction Stop
        $targetMoved = $true
    }

    $catalogMutationAttempted = $true
    Write-JsonFile -Path $paths.EXTENSIONS_CATALOG_PATH -Data $catalog -Depth 12
    if ($stateChanged) {
        $stateMutationAttempted = $true
        Write-JsonFile -Path $paths.EXTENSIONS_STATE_PATH -Data $state -Depth 10
    }

    $validation = Invoke-JsonScript -ScriptPath $paths.EXTENSIONS_VALIDATOR_PATH -Arguments @('-Json')
    if (-not $validation.VALID) {
        throw "Extension registry rejected removal: $($validation.ERRORS -join '; ')"
    }

    Remove-Item -LiteralPath $transactionDir -Recurse -Force -ErrorAction Stop
} catch {
    $failure = $_
    $rollbackErrors = @()
    if ($catalogMutationAttempted) {
        try {
            Restore-ExtensionTransactionFileBaseline -Baseline $catalogBaseline
        } catch {
            $rollbackErrors += "catalog rollback failed: $($_.Exception.Message)"
        }
    }
    if ($stateMutationAttempted) {
        try {
            Restore-ExtensionTransactionFileBaseline -Baseline $stateBaseline
        } catch {
            $rollbackErrors += "state rollback failed: $($_.Exception.Message)"
        }
    }
    if ($targetMoved -and (Test-Path -LiteralPath $targetBackup)) {
        try {
            Move-Item -LiteralPath $targetBackup -Destination $targetDir -ErrorAction Stop
        } catch {
            $rollbackErrors += "target rollback failed: $($_.Exception.Message)"
        }
    }
    try {
        Restore-ExtensionMirrorFromTransaction -Paths $paths -BackupPath $mirrorBackup
    } catch {
        $rollbackErrors += "mirror rollback failed: $($_.Exception.Message)"
    }
    if ($rollbackErrors.Count -eq 0 -and (Test-Path -LiteralPath $transactionDir)) {
        try {
            Remove-Item -LiteralPath $transactionDir -Recurse -Force -ErrorAction Stop
        } catch {
            $rollbackErrors += "transaction cleanup failed: $($_.Exception.Message)"
        }
    }

    $rollbackSuffix = if ($rollbackErrors.Count -gt 0) {
        " Rollback errors: $($rollbackErrors -join '; '). Recovery evidence retained at: $transactionDir"
    } else {
        ' Rollback completed.'
    }
    throw "Extension removal failed: $($failure.Exception.Message).$rollbackSuffix"
}

$result = [ordered]@{
    ID          = $Id
    REMOVED_DIR = $targetDir
    VALID       = $validation.VALID
    ERROR_COUNT = $validation.ERROR_COUNT
    MIRROR_INVALIDATED = ($null -ne $mirrorBackup)
}

if ($Json) {
    [PSCustomObject]$result | ConvertTo-Json -Depth 5
    exit 0
}

Write-Output ("Removed extension: {0}" -f $Id)
Write-Output ("Registry valid: {0}" -f $validation.VALID.ToString().ToLower())
