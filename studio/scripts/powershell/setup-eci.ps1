#!/usr/bin/env pwsh

#Requires -Version 7.0
<#
.SYNOPSIS
    Non-bypassable stage entry gate for /speckit.eci.

.DESCRIPTION
    Validates the exact initial ECI readiness route and atomically records an
    engine/operator-local ECI requirement marker. The marker latches only that
    ECI was required; it does not authenticate readiness or dossier evidence.

.PARAMETER FeatureDir
    Optional feature directory override. The target must be a direct child of
    <project>/specs/.

.PARAMETER Json
    Emit one structured JSON object.

.NOTES
    Exit code: 0 only when the exact ROUTE_TO_ECI/PENDING intake is valid and
    the strict ECI requirement marker exists. There is no Force bypass.
#>

[CmdletBinding()]
param(
    [string]$FeatureDir,
    [switch]$Json,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Output 'Usage: ./setup-eci.ps1 [-FeatureDir <path>] [-Json] [-Help]'
    Write-Output '  -FeatureDir  Override feature directory (must be <project>/specs/<feature>).'
    Write-Output '  -Json        Output one machine-readable JSON object.'
    Write-Output '  -Help        Show this help message.'
    exit 0
}

. "$PSScriptRoot/common.ps1"

function Invoke-EciIntakeValidation {
    param([Parameter(Mandatory = $true)][string]$ResolvedFeatureDir)

    $validatorPath = Join-Path $PSScriptRoot 'validate-feature-structure.ps1'
    if (-not (Test-Path -LiteralPath $validatorPath -PathType Leaf)) {
        throw "validate-feature-structure.ps1 is required before ECI: $validatorPath"
    }

    $output = & pwsh -NoProfile -File $validatorPath `
        -FeatureDir $ResolvedFeatureDir `
        -DeferEciDossier `
        -Json 2>&1
    $exitCode = $LASTEXITCODE
    if (-not $output) {
        throw 'validate-feature-structure.ps1 returned no machine-readable result.'
    }

    try {
        $result = ($output -join "`n") | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "validate-feature-structure.ps1 returned invalid JSON: $($_.Exception.Message)"
    }

    return [PSCustomObject][ordered]@{
        EXIT_CODE = $exitCode
        RESULT    = $result
    }
}

$paths = Resolve-FeatureContext -FeatureDir $FeatureDir
Assert-PathInsideRoot `
    -Root $paths.PROJECT_ROOT `
    -Candidate $paths.FEATURE_DIR `
    -MessagePrefix 'FEATURE_DIR escapes project root'
Assert-PathInsideRoot `
    -Root $paths.PROJECT_ROOT `
    -Candidate $paths.READINESS_DIR `
    -MessagePrefix 'READINESS_DIR escapes project root'
Assert-PathInsideRoot `
    -Root $paths.PROJECT_ROOT `
    -Candidate $paths.ECI_TRIGGER `
    -MessagePrefix 'ECI_TRIGGER escapes project root'
Assert-PathInsideRoot `
    -Root $paths.PROJECT_ROOT `
    -Candidate $paths.ECI_DIR `
    -MessagePrefix 'ECI_DIR escapes project root'
Assert-PathInsideRoot `
    -Root $paths.PROJECT_ROOT `
    -Candidate $paths.ECI_REQUIREMENT_PATH `
    -MessagePrefix 'ECI_REQUIREMENT_PATH escapes project root'

$validationInvocation = Invoke-EciIntakeValidation -ResolvedFeatureDir $paths.FEATURE_DIR
$validation = $validationInvocation.RESULT
$blockers = [System.Collections.Generic.List[string]]::new()

if ($validation.VALID -isnot [bool]) {
    $blockers.Add('validate-feature-structure.ps1 result is missing Boolean VALID.') | Out-Null
} elseif ($validationInvocation.EXIT_CODE -ne 0 -or -not $validation.VALID) {
    foreach ($finding in @($validation.ERRORS)) {
        $blockers.Add("[$($finding.id)] $($finding.message)") | Out-Null
    }
    if ($blockers.Count -eq 0) {
        $blockers.Add("validate-feature-structure.ps1 exited with code $($validationInvocation.EXIT_CODE).") | Out-Null
    }
}

if (
    $validation.READINESS_PRIMARY_STATUS -isnot [string] -or
    -not [string]::Equals(
        [string]$validation.READINESS_PRIMARY_STATUS,
        'ROUTE_TO_ECI',
        [System.StringComparison]::Ordinal
    )
) {
    $blockers.Add(
        "ECI entry requires exactly READINESS_PRIMARY_STATUS=ROUTE_TO_ECI; received '$($validation.READINESS_PRIMARY_STATUS)'."
    ) | Out-Null
}
if (
    $validation.ECI_REENTRY_STATUS -isnot [string] -or
    -not [string]::Equals(
        [string]$validation.ECI_REENTRY_STATUS,
        'PENDING',
        [System.StringComparison]::Ordinal
    )
) {
    $blockers.Add(
        "ECI entry requires exactly ECI_REENTRY_STATUS=PENDING; received '$($validation.ECI_REENTRY_STATUS)'."
    ) | Out-Null
}
if ($validation.ECI_REQUIRED -isnot [bool] -or $validation.ECI_REQUIRED -ne $true) {
    $blockers.Add('ECI entry requires the validator Boolean ECI_REQUIRED=true.') | Out-Null
}

$marker = $null
if ($blockers.Count -eq 0) {
    try {
        $marker = Initialize-EciRequirementMarker `
            -FeatureDir $paths.FEATURE_DIR `
            -ProjectRoot $paths.PROJECT_ROOT
    } catch {
        $blockers.Add($_.Exception.Message) | Out-Null
    }
}

$studioRoot = Find-StudioRoot -StartDir $paths.PROJECT_ROOT
$constitutions = if ($studioRoot) {
    @(Get-ConstitutionPaths -StudioRoot $studioRoot -ProjectRoot $paths.PROJECT_ROOT)
} else {
    @()
}
$ready = $blockers.Count -eq 0 -and $null -ne $marker -and $marker.VALID -and $marker.LATCHED
$result = [ordered]@{
    STAGE                   = 'eci'
    READY                   = [bool]$ready
    FEATURE                 = $paths.FEATURE
    FEATURE_DIR             = $paths.FEATURE_DIR
    FEATURE_SPEC            = $paths.FEATURE_SPEC
    READINESS_DIR           = $paths.READINESS_DIR
    READINESS_ASSESSMENT    = $paths.READINESS_ASSESSMENT
    ECI_TRIGGER             = $paths.ECI_TRIGGER
    ECI_DIR                 = $paths.ECI_DIR
    ECI_REQUIREMENT_PATH    = $paths.ECI_REQUIREMENT_PATH
    ECI_REQUIREMENT_LATCHED = [bool]($marker -and $marker.LATCHED)
    ECI_REQUIREMENT_CREATED = [bool]($marker -and $marker.CREATED)
    READINESS_PRIMARY_STATUS = $validation.READINESS_PRIMARY_STATUS
    ECI_REENTRY_STATUS      = $validation.ECI_REENTRY_STATUS
    ECI_REQUIRED            = $validation.ECI_REQUIRED
    STUDIO_ROOT             = $studioRoot
    CONSTITUTIONS           = @($constitutions)
    BLOCKERS                = @($blockers)
}

if ($Json) {
    [PSCustomObject]$result | ConvertTo-Json -Depth 6 -Compress
} else {
    Write-Output ("STAGE: {0}" -f $result.STAGE)
    Write-Output ("READY: {0}" -f $result.READY)
    Write-Output ("FEATURE_DIR: {0}" -f $result.FEATURE_DIR)
    Write-Output ("READINESS_ASSESSMENT: {0}" -f $result.READINESS_ASSESSMENT)
    Write-Output ("ECI_TRIGGER: {0}" -f $result.ECI_TRIGGER)
    Write-Output ("ECI_DIR: {0}" -f $result.ECI_DIR)
    Write-Output ("ECI_REQUIREMENT_PATH: {0}" -f $result.ECI_REQUIREMENT_PATH)
    Write-Output ("ECI_REQUIREMENT_LATCHED: {0}" -f $result.ECI_REQUIREMENT_LATCHED)
    foreach ($blocker in $blockers) {
        Write-Output "[BLOCKER] $blocker"
    }
}

if (-not $ready) {
    exit 1
}
exit 0
