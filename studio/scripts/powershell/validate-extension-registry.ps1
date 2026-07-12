#!/usr/bin/env pwsh

#Requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Id,
    [switch]$Json,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    $helpLines = @(
        'Usage: ./validate-extension-registry.ps1 [-Id <extension-id>] [-Json] [-Help]',
        '',
        'Validates the studio-first extension catalog, state ledger, policy, and manifests.',
        '',
        'Options:',
        '  -Id      Validate and return only one extension id',
        '  -Json    Output structured JSON summary',
        '  -Help    Show this help message'
    )
    Write-Output ($helpLines -join "`n")
    exit 0
}

. "$PSScriptRoot/common.ps1"

function New-Issue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Scope,
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    return "${Scope}: $Message"
}

function Test-StringValue {
    param([object]$Value)
    return (-not [string]::IsNullOrWhiteSpace([string]$Value))
}

function Test-VersionValue {
    param([object]$Value)
    if (-not (Test-StringValue -Value $Value)) {
        return $false
    }

    return [bool]([string]$Value -match '^[0-9]+\.[0-9]+\.[0-9]+$')
}

function Test-DateTimeValue {
    param([object]$Value)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        return $false
    }

    $parsed = [datetime]::MinValue
    return [DateTime]::TryParse([string]$Value, [ref]$parsed)
}

function Validate-ManifestData {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Manifest,
        [Parameter(Mandatory = $true)]
        [string]$ManifestPath,
        [Parameter(Mandatory = $true)]
        [string]$ExtensionRoot
    )

    $errors = @()
    $warnings = @()
    $runtimeScopes = @()
    $entryPoints = @{}
    $allowedScopes = Get-ExtensionRuntimeScopes

    foreach ($field in @('id', 'version', 'title', 'description', 'kind', 'status', 'compatibility')) {
        if (-not $Manifest.ContainsKey($field) -or -not (Test-StringValue -Value $Manifest[$field])) {
            $errors += New-Issue -Scope 'manifest' -Message "Missing required field '$field' in $ManifestPath"
        }
    }

    if ($Manifest.ContainsKey('id') -and -not ([string]$Manifest.id -match '^[a-z0-9][a-z0-9-]{1,63}$')) {
        $errors += New-Issue -Scope 'manifest' -Message "Invalid extension id '$($Manifest.id)'"
    }

    if ($Manifest.ContainsKey('version') -and -not (Test-VersionValue -Value $Manifest.version)) {
        $errors += New-Issue -Scope 'manifest' -Message "Invalid version '$($Manifest.version)'"
    }

    if ($Manifest.ContainsKey('compatibility')) {
        if ($Manifest.compatibility -isnot [hashtable]) {
            $errors += New-Issue -Scope 'manifest' -Message 'compatibility must be an object'
        } elseif (-not $Manifest.compatibility.ContainsKey('mode') -or $Manifest.compatibility.mode -ne 'studio-first') {
            $errors += New-Issue -Scope 'manifest' -Message 'compatibility.mode must equal studio-first'
        }
    }

    if ($Manifest.ContainsKey('runtimeScopes')) {
        if ($Manifest.runtimeScopes -isnot [System.Collections.IEnumerable]) {
            $errors += New-Issue -Scope 'manifest' -Message 'runtimeScopes must be an array'
        } else {
            $runtimeScopes = @($Manifest.runtimeScopes)
            foreach ($scope in $runtimeScopes) {
                if ($scope -notin $allowedScopes) {
                    $errors += New-Issue -Scope 'manifest' -Message "Unsupported runtime scope '$scope'"
                }
            }
        }
    }

    if ($Manifest.ContainsKey('entryPoints')) {
        if ($Manifest.entryPoints -isnot [hashtable]) {
            $errors += New-Issue -Scope 'manifest' -Message 'entryPoints must be an object'
        } else {
            foreach ($scope in $Manifest.entryPoints.Keys) {
                if ($scope -notin $allowedScopes) {
                    $errors += New-Issue -Scope 'manifest' -Message "Unsupported entryPoints scope '$scope'"
                    continue
                }

                $scopeEntries = @($Manifest.entryPoints[$scope])
                $entryPoints[$scope] = $scopeEntries

                foreach ($relativePath in $scopeEntries) {
                    if (-not (Test-StringValue -Value $relativePath)) {
                        $errors += New-Issue -Scope 'manifest' -Message "Empty entryPoints path in scope '$scope'"
                        continue
                    }

                    if (-not ([string]$relativePath).StartsWith("$scope/")) {
                        $errors += New-Issue -Scope 'manifest' -Message "Entry point '$relativePath' must start with '$scope/'"
                        continue
                    }

                    try {
                        $resolvedPath = Resolve-RelativePathInsideRoot -Root $ExtensionRoot -RelativePath $relativePath
                    } catch {
                        $errors += New-Issue -Scope 'manifest' -Message $_.Exception.Message
                        continue
                    }

                    if (-not (Test-Path -LiteralPath $resolvedPath)) {
                        $errors += New-Issue -Scope 'manifest' -Message "Declared entry point not found: $relativePath"
                    }
                }

                if ($runtimeScopes.Count -gt 0 -and $scope -notin $runtimeScopes) {
                    $errors += New-Issue -Scope 'manifest' -Message "runtimeScopes must include '$scope' because it appears in entryPoints"
                }
            }
        }
    } elseif ($runtimeScopes.Count -gt 0) {
        $warnings += New-Issue -Scope 'manifest' -Message 'runtimeScopes declared without entryPoints'
    }

    return [ordered]@{
        valid        = ($errors.Count -eq 0)
        errors       = $errors
        warnings     = $warnings
        runtimeScopes = $runtimeScopes
        entryPoints  = $entryPoints
    }
}

function Validate-CatalogEntryData {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Entry,
        [Parameter(Mandatory = $true)]
        [string]$StudioRoot
    )

    $errors = @()
    $warnings = @()
    $allowedScopes = Get-ExtensionRuntimeScopes
    $reviewStatuses = Get-ExtensionRegistryReviewStatuses
    $trustLevels = Get-ExtensionRegistryTrustLevels

    foreach ($field in @('id', 'version', 'title', 'sourcePath', 'reviewStatus', 'trustLevel', 'defaultEnabled', 'owner', 'runtimeScopes', 'capabilities', 'notes')) {
        if (-not $Entry.ContainsKey($field)) {
            $errors += New-Issue -Scope 'catalog' -Message "Missing required catalog field '$field'"
        }
    }

    if ($Entry.ContainsKey('id') -and -not ([string]$Entry.id -match '^[a-z0-9][a-z0-9-]{1,63}$')) {
        $errors += New-Issue -Scope 'catalog' -Message "Invalid catalog id '$($Entry.id)'"
    }

    if ($Entry.ContainsKey('version') -and -not (Test-VersionValue -Value $Entry.version)) {
        $errors += New-Issue -Scope 'catalog' -Message "Invalid catalog version '$($Entry.version)'"
    }

    if ($Entry.ContainsKey('reviewStatus') -and $Entry.reviewStatus -notin $reviewStatuses) {
        $errors += New-Issue -Scope 'catalog' -Message "Unsupported reviewStatus '$($Entry.reviewStatus)'"
    }

    if ($Entry.ContainsKey('trustLevel') -and $Entry.trustLevel -notin $trustLevels) {
        $errors += New-Issue -Scope 'catalog' -Message "Unsupported trustLevel '$($Entry.trustLevel)'"
    }

    if ($Entry.ContainsKey('defaultEnabled') -and $Entry.defaultEnabled -isnot [bool]) {
        $errors += New-Issue -Scope 'catalog' -Message 'defaultEnabled must be a boolean'
    }

    if ($Entry.ContainsKey('runtimeScopes')) {
        foreach ($scope in @($Entry.runtimeScopes)) {
            if ($scope -notin $allowedScopes) {
                $errors += New-Issue -Scope 'catalog' -Message "Unsupported runtime scope '$scope'"
            }
        }
    }

    if ($Entry.ContainsKey('approvedAt') -and $null -ne $Entry.approvedAt -and -not (Test-DateTimeValue -Value $Entry.approvedAt)) {
        $errors += New-Issue -Scope 'catalog' -Message 'approvedAt must be an ISO date-time string or null'
    }

    if ($Entry.defaultEnabled -eq $true) {
        if ($Entry.reviewStatus -ne 'approved') {
            $errors += New-Issue -Scope 'catalog' -Message 'defaultEnabled=true requires reviewStatus=approved'
        }
        if ($Entry.trustLevel -notin @('core', 'curated')) {
            $errors += New-Issue -Scope 'catalog' -Message 'defaultEnabled=true requires trustLevel core or curated'
        }
    }

    if ($Entry.ContainsKey('sourcePath') -and (Test-StringValue -Value $Entry.sourcePath)) {
        try {
            $resolvedSourcePath = Resolve-RelativePathInsideRoot -Root $StudioRoot -RelativePath $Entry.sourcePath
            if (-not (Test-Path -LiteralPath $resolvedSourcePath)) {
                $errors += New-Issue -Scope 'catalog' -Message "sourcePath does not exist: $($Entry.sourcePath)"
            }
        } catch {
            $errors += New-Issue -Scope 'catalog' -Message $_.Exception.Message
        }
    }

    return [ordered]@{
        valid    = ($errors.Count -eq 0)
        errors   = $errors
        warnings = $warnings
    }
}

function Validate-StateEntryData {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Id,
        [Parameter(Mandatory = $true)]
        [hashtable]$Entry
    )

    $errors = @()
    $allowedSources = Get-ExtensionStateSources

    foreach ($field in @('enabled', 'pinnedVersion', 'changedAt', 'source')) {
        if (-not $Entry.ContainsKey($field)) {
            $errors += New-Issue -Scope 'state' -Message "Missing required state field '$field' for $Id"
        }
    }

    if ($Entry.ContainsKey('enabled') -and $Entry.enabled -isnot [bool]) {
        $errors += New-Issue -Scope 'state' -Message "enabled must be boolean for $Id"
    }

    if ($Entry.ContainsKey('pinnedVersion') -and $null -ne $Entry.pinnedVersion -and -not (Test-VersionValue -Value $Entry.pinnedVersion)) {
        $errors += New-Issue -Scope 'state' -Message "Invalid pinnedVersion '$($Entry.pinnedVersion)' for $Id"
    }

    if ($Entry.ContainsKey('changedAt') -and -not (Test-DateTimeValue -Value $Entry.changedAt)) {
        $errors += New-Issue -Scope 'state' -Message "Invalid changedAt '$($Entry.changedAt)' for $Id"
    }

    if ($Entry.ContainsKey('source') -and $Entry.source -notin $allowedSources) {
        $errors += New-Issue -Scope 'state' -Message "Unsupported state source '$($Entry.source)' for $Id"
    }

    return [ordered]@{
        valid  = ($errors.Count -eq 0)
        errors = $errors
    }
}

$paths = Get-StudioSharedLayerPaths -StartDir $PSScriptRoot

$errors = @()
$warnings = @()

foreach ($requiredPath in @($paths.EXTENSIONS_ROOT, $paths.EXTENSIONS_POLICY_PATH, $paths.EXTENSIONS_CATALOG_PATH, $paths.EXTENSIONS_CATALOG_SCHEMA, $paths.EXTENSIONS_STATE_PATH, $paths.EXTENSIONS_STATE_SCHEMA, $paths.EXTENSIONS_MANIFEST_SCHEMA)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        $errors += New-Issue -Scope 'registry' -Message "Required extension registry path not found: $requiredPath"
    }
}

$catalog = Read-JsonFile -Path $paths.EXTENSIONS_CATALOG_PATH
$state = Read-JsonFile -Path $paths.EXTENSIONS_STATE_PATH

if (-not $catalog) {
    $errors += New-Issue -Scope 'catalog' -Message 'Unable to read catalog.json'
    $catalog = [ordered]@{ policy = @{}; extensions = @() }
}

if (-not $state) {
    $errors += New-Issue -Scope 'state' -Message 'Unable to read state.json'
    $state = [ordered]@{ states = @{} }
}

if (-not $catalog.ContainsKey('policy') -or $catalog.policy -isnot [hashtable]) {
    $errors += New-Issue -Scope 'catalog' -Message 'policy must be an object'
}

if (-not $catalog.ContainsKey('extensions')) {
    $errors += New-Issue -Scope 'catalog' -Message 'extensions must be present'
}

if (-not $state.ContainsKey('states') -or $state.states -isnot [hashtable]) {
    $errors += New-Issue -Scope 'state' -Message 'states must be an object'
    $state.states = @{}
}

$catalogLookup = @{}
foreach ($entry in @($catalog.extensions)) {
    if (-not $entry) {
        continue
    }

    $catalogEntry = if ($entry -is [hashtable]) {
        $entry
    } else {
        $converted = @{}
        $entry.PSObject.Properties | ForEach-Object {
            $converted[$_.Name] = $_.Value
        }
        $converted
    }
    $entryId = [string]$catalogEntry.id
    if ($catalogLookup.ContainsKey($entryId)) {
        $errors += New-Issue -Scope 'catalog' -Message "Duplicate catalog id '$entryId'"
        continue
    }

    $catalogLookup[$entryId] = $catalogEntry
}

$manifestLookup = @{}
Get-ChildItem -LiteralPath $paths.EXTENSIONS_ROOT -Directory | ForEach-Object {
    $manifestPath = Join-Path $_.FullName 'manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath)) {
        return
    }

    $manifest = Read-JsonFile -Path $manifestPath
    if (-not $manifest) {
        $errors += New-Issue -Scope 'manifest' -Message "Unable to parse manifest: $manifestPath"
        return
    }

    $manifestValidation = Validate-ManifestData -Manifest $manifest -ManifestPath $manifestPath -ExtensionRoot $_.FullName
    $manifestId = [string]$manifest.id

    if ($manifestLookup.ContainsKey($manifestId)) {
        $errors += New-Issue -Scope 'manifest' -Message "Duplicate manifest id '$manifestId'"
        return
    }

    $manifestLookup[$manifestId] = [ordered]@{
        manifest       = $manifest
        path           = $manifestPath
        root           = $_.FullName
        validation     = $manifestValidation
    }
}

$allIds = @($catalogLookup.Keys + $manifestLookup.Keys + $state.states.Keys | Sort-Object -Unique)
$extensions = @()

foreach ($extensionId in $allIds) {
    $catalogEntry = if ($catalogLookup.ContainsKey($extensionId)) { $catalogLookup[$extensionId] } else { $null }
    $manifestInfo = if ($manifestLookup.ContainsKey($extensionId)) { $manifestLookup[$extensionId] } else { $null }
    $stateEntry = if ($state.states.ContainsKey($extensionId)) { $state.states[$extensionId] } else { $null }

    $extensionErrors = @()
    $extensionWarnings = @()

    if ($catalogEntry) {
        $catalogValidation = Validate-CatalogEntryData -Entry $catalogEntry -StudioRoot $paths.STUDIO_ROOT
        $extensionErrors += $catalogValidation.errors
        $extensionWarnings += $catalogValidation.warnings
    } else {
        $extensionErrors += New-Issue -Scope 'catalog' -Message "Manifest/state exists without catalog entry for '$extensionId'"
    }

    if ($manifestInfo) {
        $extensionErrors += $manifestInfo.validation.errors
        $extensionWarnings += $manifestInfo.validation.warnings
    } else {
        $extensionErrors += New-Issue -Scope 'manifest' -Message "Catalog/state exists without manifest for '$extensionId'"
    }

    if ($stateEntry) {
        if ($stateEntry -isnot [hashtable]) {
            $extensionErrors += New-Issue -Scope 'state' -Message "State entry for '$extensionId' must be an object"
        } else {
            $stateValidation = Validate-StateEntryData -Id $extensionId -Entry $stateEntry
            $extensionErrors += $stateValidation.errors
        }
    }

    if ($catalogEntry -and $manifestInfo) {
        $expectedSourcePath = "extensions/$extensionId"
        if ($catalogEntry.sourcePath -ne $expectedSourcePath) {
            $extensionErrors += New-Issue -Scope 'catalog' -Message "sourcePath for '$extensionId' must equal '$expectedSourcePath'"
        }

        if ($catalogEntry.version -ne $manifestInfo.manifest.version) {
            $extensionErrors += New-Issue -Scope 'catalog' -Message "Catalog version '$($catalogEntry.version)' does not match manifest version '$($manifestInfo.manifest.version)' for '$extensionId'"
        }

        if ($catalogEntry.title -ne $manifestInfo.manifest.title) {
            $extensionWarnings += New-Issue -Scope 'catalog' -Message "Catalog title differs from manifest title for '$extensionId'"
        }

        foreach ($scope in @($catalogEntry.runtimeScopes)) {
            if ($manifestInfo.validation.runtimeScopes.Count -gt 0 -and $scope -notin $manifestInfo.validation.runtimeScopes) {
                $extensionErrors += New-Issue -Scope 'catalog' -Message "Catalog runtime scope '$scope' not present in manifest runtimeScopes for '$extensionId'"
            }
        }
    }

    if ($stateEntry -and $catalogEntry) {
        if ($catalogEntry.reviewStatus -notin @('approved', 'deprecated') -and $stateEntry.enabled) {
            $extensionErrors += New-Issue -Scope 'state' -Message "State enables '$extensionId' even though reviewStatus is '$($catalogEntry.reviewStatus)'"
        }
    }

    if ($stateEntry -and $manifestInfo -and $stateEntry.pinnedVersion -and $stateEntry.pinnedVersion -ne $manifestInfo.manifest.version) {
        $extensionWarnings += New-Issue -Scope 'state' -Message "Pinned version '$($stateEntry.pinnedVersion)' differs from manifest version '$($manifestInfo.manifest.version)' for '$extensionId'"
    }

    $effectiveEnabled = $false
    if ($stateEntry -and $stateEntry.enabled -ne $null) {
        $effectiveEnabled = [bool]$stateEntry.enabled
    } elseif ($catalogEntry -and $catalogEntry.defaultEnabled -eq $true) {
        $effectiveEnabled = $true
    }

    $extensions += [ordered]@{
        id               = $extensionId
        title            = if ($manifestInfo) { $manifestInfo.manifest.title } elseif ($catalogEntry) { $catalogEntry.title } else { $extensionId }
        version          = if ($manifestInfo) { $manifestInfo.manifest.version } elseif ($catalogEntry) { $catalogEntry.version } else { $null }
        sourcePath       = if ($catalogEntry) { $catalogEntry.sourcePath } else { $null }
        path             = if ($manifestInfo) { $manifestInfo.root } else { $null }
        reviewStatus     = if ($catalogEntry) { $catalogEntry.reviewStatus } else { 'uncataloged' }
        trustLevel       = if ($catalogEntry) { $catalogEntry.trustLevel } else { 'unknown' }
        defaultEnabled   = if ($catalogEntry -and $catalogEntry.defaultEnabled -ne $null) { [bool]$catalogEntry.defaultEnabled } else { $false }
        enabled          = $effectiveEnabled
        stateSource      = if ($stateEntry) { $stateEntry.source } else { $null }
        pinnedVersion    = if ($stateEntry) { $stateEntry.pinnedVersion } else { $null }
        runtimeScopes    = if ($manifestInfo -and $manifestInfo.validation.runtimeScopes.Count -gt 0) { @($manifestInfo.validation.runtimeScopes) } elseif ($catalogEntry) { @($catalogEntry.runtimeScopes) } else { @() }
        capabilities     = if ($manifestInfo -and $manifestInfo.manifest.capabilities) { @($manifestInfo.manifest.capabilities) } elseif ($catalogEntry) { @($catalogEntry.capabilities) } else { @() }
        entryPoints      = if ($manifestInfo) { $manifestInfo.validation.entryPoints } else { @{} }
        cataloged        = [bool]$catalogEntry
        hasManifest      = [bool]$manifestInfo
        issues           = @($extensionErrors)
        warnings         = @($extensionWarnings)
        valid            = ($extensionErrors.Count -eq 0)
    }

    $errors += $extensionErrors
    $warnings += $extensionWarnings
}

if ($Id) {
    $extensions = @($extensions | Where-Object { $_.id -eq $Id })
    if ($extensions.Count -eq 0) {
        Write-Error "Extension not found: $Id"
        exit 1
    }
}

$result = [ordered]@{
    VALID                  = ($errors.Count -eq 0)
    POLICY_PATH            = $paths.EXTENSIONS_POLICY_PATH
    CATALOG_PATH           = $paths.EXTENSIONS_CATALOG_PATH
    CATALOG_SCHEMA_PATH    = $paths.EXTENSIONS_CATALOG_SCHEMA
    STATE_PATH             = $paths.EXTENSIONS_STATE_PATH
    STATE_SCHEMA_PATH      = $paths.EXTENSIONS_STATE_SCHEMA
    MANIFEST_SCHEMA_PATH   = $paths.EXTENSIONS_MANIFEST_SCHEMA
    EXTENSIONS_ROOT        = $paths.EXTENSIONS_ROOT
    EXTENSION_COUNT        = $extensions.Count
    ERROR_COUNT            = $errors.Count
    WARNING_COUNT          = $warnings.Count
    ERRORS                 = $errors
    WARNINGS               = $warnings
    EXTENSIONS             = $extensions
}

if ($Json) {
    [PSCustomObject]$result | ConvertTo-Json -Depth 10
    exit 0
}

Write-Output ("Registry valid: {0}" -f $result.VALID.ToString().ToLower())
Write-Output ("Extensions: {0}" -f $result.EXTENSION_COUNT)
Write-Output ("Errors: {0}" -f $result.ERROR_COUNT)
Write-Output ("Warnings: {0}" -f $result.WARNING_COUNT)

foreach ($extension in $extensions) {
    Write-Output ("- {0} | enabled={1} | review={2} | trust={3} | valid={4}" -f $extension.id, $extension.enabled.ToString().ToLower(), $extension.reviewStatus, $extension.trustLevel, $extension.valid.ToString().ToLower())
}

if ($errors.Count -gt 0) {
    Write-Output ''
    Write-Output 'Errors:'
    $errors | ForEach-Object { Write-Output "- $_" }
}

if ($warnings.Count -gt 0) {
    Write-Output ''
    Write-Output 'Warnings:'
    $warnings | ForEach-Object { Write-Output "- $_" }
}
