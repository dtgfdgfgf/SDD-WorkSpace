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
. "$PSScriptRoot/extension-registry-common.ps1"

$paths = Get-StudioSharedLayerPaths -StartDir $PSScriptRoot
$resolvedSourceDir = Resolve-AbsolutePath -Path $SourceDir -BaseDir (Get-Location).Path
Assert-PathInsideRoot -Root $paths.WORKSPACE_ROOT -Candidate $resolvedSourceDir -MessagePrefix 'Extension source must stay inside the workspace'

if (-not (Test-Path -LiteralPath $resolvedSourceDir -PathType Container)) {
    Write-Error "Source directory not found: $resolvedSourceDir"
    exit 1
}

[void](Resolve-ExistingPathInsideRoot -Root $paths.WORKSPACE_ROOT -Candidate $resolvedSourceDir -MessagePrefix 'Extension source escapes the workspace through a reparse point')
Assert-ExtensionTreeHasNoReparsePoints -Root $resolvedSourceDir

$sourceManifestPath = Join-Path $resolvedSourceDir 'manifest.json'
if (-not (Test-Path -LiteralPath $sourceManifestPath)) {
    Write-Error "manifest.json not found in source directory: $resolvedSourceDir"
    exit 1
}

try {
    $identityPreflight = Get-Content -LiteralPath $sourceManifestPath -Raw -ErrorAction Stop | ConvertFrom-Json -AsHashtable -ErrorAction Stop
} catch {
    Write-Error "Unable to parse manifest: $sourceManifestPath. $($_.Exception.Message)"
    exit 1
}
if (
    $identityPreflight -isnot [System.Collections.IDictionary] -or
    [string]$identityPreflight.id -notmatch '^[a-z0-9][a-z0-9-]{1,63}$'
) {
    Write-Error "Invalid extension id '$($identityPreflight.id)'. Expected lowercase letters, digits, and hyphens matching ^[a-z0-9][a-z0-9-]{1,63}$."
    exit 1
}

$manifestDocument = Test-ExtensionJsonDocument -Path $sourceManifestPath -SchemaPath $paths.EXTENSIONS_MANIFEST_SCHEMA -Label 'extension source manifest'
if (-not $manifestDocument.VALID) {
    Write-Error ("Extension source manifest is invalid before mutation: {0}" -f ($manifestDocument.ERRORS -join '; '))
    exit 1
}
$manifest = $manifestDocument.DATA

if ($manifest.ContainsKey('entryPoints')) {
    foreach ($scope in @($manifest.entryPoints.Keys)) {
        foreach ($relativePath in @($manifest.entryPoints[$scope])) {
            try {
                [void](Resolve-ExtensionEntryPoint -ExtensionRoot $resolvedSourceDir -Scope ([string]$scope) -RelativePath ([string]$relativePath))
            } catch {
                Write-Error "Extension source manifest is invalid before mutation: $($_.Exception.Message)"
                exit 1
            }
        }
    }
}

if ([string]$manifest.id -notmatch '^[a-z0-9][a-z0-9-]{1,63}$') {
    Write-Error "Invalid extension id '$($manifest.id)'. Expected lowercase letters, digits, and hyphens matching ^[a-z0-9][a-z0-9-]{1,63}$."
    exit 1
}

$targetDir = Join-Path $paths.EXTENSIONS_ROOT $manifest.id
Assert-PathInsideRoot -Root $paths.EXTENSIONS_ROOT -Candidate $targetDir -MessagePrefix 'Extension target escapes extensions root'
$sourceIsTarget = ([System.IO.Path]::GetFullPath($resolvedSourceDir) -eq [System.IO.Path]::GetFullPath($targetDir))

if ((Test-Path -LiteralPath $targetDir) -and -not $Force -and -not $sourceIsTarget) {
    Write-Error "Extension already exists: $($manifest.id). Use -Force to replace."
    exit 1
}

$catalogDocument = Test-ExtensionJsonDocument -Path $paths.EXTENSIONS_CATALOG_PATH -SchemaPath $paths.EXTENSIONS_CATALOG_SCHEMA -Label 'extension catalog'
$stateDocument = Test-ExtensionJsonDocument -Path $paths.EXTENSIONS_STATE_PATH -SchemaPath $paths.EXTENSIONS_STATE_SCHEMA -Label 'extension state'
if (-not $catalogDocument.VALID -or -not $stateDocument.VALID) {
    $preflightErrors = @($catalogDocument.ERRORS) + @($stateDocument.ERRORS)
    Write-Error ("Extension registry is invalid before mutation: {0}" -f ($preflightErrors -join '; '))
    exit 1
}

$catalog = $catalogDocument.DATA
$stateData = $stateDocument.DATA
$existingEntry = @($catalog.extensions | Where-Object { $_.id -eq $manifest.id }) | Select-Object -First 1
$contentSha256 = Get-ExtensionContentSha256 -ExtensionRoot $resolvedSourceDir
$runtimeScopes = [object[]]@($manifest.runtimeScopes)
$capabilities = [object[]]@($manifest.capabilities)
$newEntry = [ordered]@{
    id             = $manifest.id
    version        = $manifest.version
    title          = $manifest.title
    sourcePath     = "extensions/$($manifest.id)"
    reviewStatus   = 'draft'
    trustLevel     = 'experimental'
    defaultEnabled = $false
    owner          = if ($manifest.owner) { $manifest.owner } elseif ($existingEntry -and $existingEntry.owner) { $existingEntry.owner } else { 'studio' }
    approvedBy     = $null
    approvedAt     = $null
    contentSha256  = $contentSha256
    approvedContentSha256 = $null
    runtimeScopes  = $runtimeScopes
    capabilities   = $capabilities
    notes          = if ($manifest.notes) { $manifest.notes } elseif ($existingEntry) { $existingEntry.notes } else { 'Added via add-extension.ps1' }
}

$catalog.extensions = @($catalog.extensions | Where-Object { $_.id -ne $manifest.id }) + @($newEntry)
$catalog.updated = Get-IsoTimestamp

$stateChanged = $stateData.states.ContainsKey([string]$manifest.id)
if ($stateChanged) {
    $stateData.states.Remove([string]$manifest.id)
    $stateData.updated = Get-IsoTimestamp
}

$prospectiveCatalog = Test-ExtensionJsonValue -Data $catalog -SchemaPath $paths.EXTENSIONS_CATALOG_SCHEMA -Label 'prospective extension catalog'
$prospectiveState = Test-ExtensionJsonValue -Data $stateData -SchemaPath $paths.EXTENSIONS_STATE_SCHEMA -Label 'prospective extension state'
if (-not $prospectiveCatalog.VALID -or -not $prospectiveState.VALID) {
    $prospectiveErrors = @($prospectiveCatalog.ERRORS) + @($prospectiveState.ERRORS)
    Write-Error ("Extension replacement is invalid before mutation: {0}" -f ($prospectiveErrors -join '; '))
    exit 1
}

$transactionDir = New-ExtensionTransactionDirectory -Paths $paths -Operation 'add-or-replace'
$catalogBaseline = Save-ExtensionTransactionFileBaseline -TransactionDir $transactionDir -SourcePath $paths.EXTENSIONS_CATALOG_PATH -Name 'catalog.json'
$stateBaseline = Save-ExtensionTransactionFileBaseline -TransactionDir $transactionDir -SourcePath $paths.EXTENSIONS_STATE_PATH -Name 'state.json'
$stagedTarget = Join-Path $transactionDir 'incoming'
$targetBackup = Join-Path $transactionDir 'target-backup'
$mirrorBackup = $null
$targetMoved = $false
$targetInstalled = $false
$catalogMutationAttempted = $false
$stateMutationAttempted = $false

try {
    Copy-Item -LiteralPath $resolvedSourceDir -Destination $stagedTarget -Recurse -ErrorAction Stop
    Assert-ExtensionTreeHasNoReparsePoints -Root $stagedTarget
    $stagedManifest = Test-ExtensionJsonDocument -Path (Join-Path $stagedTarget 'manifest.json') -SchemaPath $paths.EXTENSIONS_MANIFEST_SCHEMA -Label 'staged extension manifest'
    if (-not $stagedManifest.VALID) {
        throw "Staged extension failed validation: $($stagedManifest.ERRORS -join '; ')"
    }
    $stagedHash = Get-ExtensionContentSha256 -ExtensionRoot $stagedTarget
    if ($stagedHash -cne $contentSha256) {
        throw "Extension source changed while staging; expected contentSha256 $contentSha256 but copied $stagedHash"
    }

    $mirrorBackup = Move-ExtensionMirrorToTransaction -Paths $paths -TransactionDir $transactionDir

    if (Test-Path -LiteralPath $targetDir) {
        [void](Resolve-ExistingPathInsideRoot -Root $paths.EXTENSIONS_ROOT -Candidate $targetDir -MessagePrefix 'Extension target escapes extensions root through a reparse point')
        Move-Item -LiteralPath $targetDir -Destination $targetBackup -ErrorAction Stop
        $targetMoved = $true
    }

    Move-Item -LiteralPath $stagedTarget -Destination $targetDir -ErrorAction Stop
    $targetInstalled = $true

    $catalogMutationAttempted = $true
    Write-JsonFile -Path $paths.EXTENSIONS_CATALOG_PATH -Data $catalog -Depth 12
    if ($stateChanged) {
        $stateMutationAttempted = $true
        Write-JsonFile -Path $paths.EXTENSIONS_STATE_PATH -Data $stateData -Depth 10
    }

    $validation = Invoke-JsonScript -ScriptPath $paths.EXTENSIONS_VALIDATOR_PATH -Arguments @('-Json', '-Id', $manifest.id)
    if (-not $validation.VALID) {
        throw "Extension registry rejected the installed candidate: $($validation.ERRORS -join '; ')"
    }

    Remove-Item -LiteralPath $transactionDir -Recurse -Force -ErrorAction Stop
} catch {
    $failure = $_
    $rollbackErrors = @()

    try {
        if ($targetInstalled -and (Test-Path -LiteralPath $targetDir)) {
            Remove-Item -LiteralPath $targetDir -Recurse -Force -ErrorAction Stop
        }
        if ($targetMoved -and (Test-Path -LiteralPath $targetBackup)) {
            Move-Item -LiteralPath $targetBackup -Destination $targetDir -ErrorAction Stop
        }
    } catch {
        $rollbackErrors += "target rollback failed: $($_.Exception.Message)"
    }

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
    throw "Extension add/replace failed: $($failure.Exception.Message).$rollbackSuffix"
}

$result = [ordered]@{
    ID              = $manifest.id
    SOURCE_DIR      = $resolvedSourceDir
    TARGET_DIR      = $targetDir
    SOURCE_IS_TARGET = $sourceIsTarget
    REVIEW_STATUS   = $newEntry.reviewStatus
    TRUST_LEVEL     = $newEntry.trustLevel
    DEFAULT_ENABLED = $newEntry.defaultEnabled
    CONTENT_SHA256  = $contentSha256
    APPROVAL_RESET  = [bool]$existingEntry
    STATE_RESET     = $stateChanged
    MIRROR_INVALIDATED = ($null -ne $mirrorBackup)
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
