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
. "$PSScriptRoot/extension-registry-common.ps1"

$paths = Get-StudioSharedLayerPaths -StartDir $PSScriptRoot
$validation = Invoke-JsonScript -ScriptPath $paths.EXTENSIONS_VALIDATOR_PATH -Arguments @('-Json')
if (-not $validation.VALID) {
    Write-Error ("Extension registry is invalid; refusing state mutation: {0}" -f ($validation.ERRORS -join '; '))
    exit 1
}
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

$stateDocument = Test-ExtensionJsonDocument -Path $paths.EXTENSIONS_STATE_PATH -SchemaPath $paths.EXTENSIONS_STATE_SCHEMA -Label 'extension state'
if (-not $stateDocument.VALID) {
    Write-Error ("Extension state is invalid; refusing mutation: {0}" -f ($stateDocument.ERRORS -join '; '))
    exit 1
}
$stateData = $stateDocument.DATA

$enabled = ($State -eq 'enabled')
if ($enabled -and $extension.reviewStatus -eq 'deprecated') {
    $hasExistingState = (
        $stateData.states -is [System.Collections.IDictionary] -and
        $stateData.states.ContainsKey($Id)
    )
    $existingState = if ($hasExistingState) { $stateData.states[$Id] } else { $null }
    $hasExactEnabledPin = (
        $existingState -is [System.Collections.IDictionary] -and
        $existingState.ContainsKey('enabled') -and
        $existingState.enabled -is [bool] -and
        $existingState.enabled -eq $true -and
        $existingState.ContainsKey('pinnedVersion') -and
        $existingState.pinnedVersion -is [string] -and
        $existingState.pinnedVersion -ceq [string]$extension.version
    )

    if (-not $hasExactEnabledPin) {
        Write-Error "Deprecated extension '$Id' cannot be newly enabled or repinned; only an existing enabled state at exact pinnedVersion '$($extension.version)' is allowed."
        exit 1
    }

    $result = [ordered]@{
        ID                 = $Id
        STATE              = $State
        ENABLED            = $true
        PINNED_VERSION     = $extension.version
        REVIEW_STATUS      = $extension.reviewStatus
        STATE_PATH         = $paths.EXTENSIONS_STATE_PATH
        NO_OP              = $true
        MIRROR_INVALIDATED = $false
    }

    if ($Json) {
        [PSCustomObject]$result | ConvertTo-Json -Depth 5
        exit 0
    }

    Write-Output ("Extension state unchanged: {0} remains enabled at {1}" -f $Id, $extension.version)
    Write-Output "State file: $($paths.EXTENSIONS_STATE_PATH)"
    exit 0
}

$stateData.states[$Id] = [ordered]@{
    enabled       = $enabled
    pinnedVersion = $extension.version
    changedAt     = Get-IsoTimestamp
    source        = 'manual'
}
$stateData.updated = Get-IsoTimestamp

$prospectiveState = Test-ExtensionJsonValue -Data $stateData -SchemaPath $paths.EXTENSIONS_STATE_SCHEMA -Label 'prospective extension state'
if (-not $prospectiveState.VALID) {
    Write-Error ("Prospective extension state is invalid; refusing mutation: {0}" -f ($prospectiveState.ERRORS -join '; '))
    exit 1
}

$transactionDir = New-ExtensionTransactionDirectory -Paths $paths -Operation 'set-state'
$stateBaseline = Save-ExtensionTransactionFileBaseline -TransactionDir $transactionDir -SourcePath $paths.EXTENSIONS_STATE_PATH -Name 'state.json'
$mirrorBackup = $null
$stateMutationAttempted = $false

try {
    $mirrorBackup = Move-ExtensionMirrorToTransaction -Paths $paths -TransactionDir $transactionDir
    $stateMutationAttempted = $true
    Write-JsonFile -Path $paths.EXTENSIONS_STATE_PATH -Data $stateData -Depth 10

    $postValidation = Invoke-JsonScript -ScriptPath $paths.EXTENSIONS_VALIDATOR_PATH -Arguments @('-Json', '-Id', $Id)
    if (-not $postValidation.VALID) {
        throw "Extension registry rejected the state update: $($postValidation.ERRORS -join '; ')"
    }

    Remove-Item -LiteralPath $transactionDir -Recurse -Force -ErrorAction Stop
} catch {
    $failure = $_
    $rollbackErrors = @()
    if ($stateMutationAttempted) {
        try {
            Restore-ExtensionTransactionFileBaseline -Baseline $stateBaseline
        } catch {
            $rollbackErrors += "state rollback failed: $($_.Exception.Message)"
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
    throw "Extension state update failed: $($failure.Exception.Message).$rollbackSuffix"
}

$result = [ordered]@{
    ID            = $Id
    STATE         = $State
    ENABLED       = $enabled
    PINNED_VERSION = $extension.version
    REVIEW_STATUS = $extension.reviewStatus
    STATE_PATH    = $paths.EXTENSIONS_STATE_PATH
    NO_OP         = $false
    MIRROR_INVALIDATED = ($null -ne $mirrorBackup)
}

if ($Json) {
    [PSCustomObject]$result | ConvertTo-Json -Depth 5
    exit 0
}

Write-Output ("Updated extension state: {0} -> {1}" -f $Id, $State)
Write-Output "State file: $($paths.EXTENSIONS_STATE_PATH)"
