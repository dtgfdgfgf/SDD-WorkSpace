#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Validate a studio workflow definition (workflow.yml) against the workflow schema.

.DESCRIPTION
    Parses workflow.yml using the powershell-yaml module, converts to JSON, and
    validates the resulting structure against studio/workflows/manifest.schema.json
    via the built-in Test-Json -SchemaFile cmdlet.

    The script is read-only. It never modifies catalog.json, state.json, or any
    workflow content. Wave-3 step types (command/gate/if/switch) are accepted by
    the schema; other step types fail schema validation by design and the engine
    rejects them at run time as "step-type-not-implemented".

.PARAMETER Id
    The workflow id (e.g. sdd-pipeline). Resolves to studio/workflows/<id>/workflow.yml.

.PARAMETER Path
    Direct path to a workflow.yml file. Mutually exclusive with -Id.

.PARAMETER Json
    Emit a structured JSON report instead of human-readable text.

.PARAMETER Help
    Show this help message.

.NOTES
    Requires the powershell-yaml module. The script reports a clear install hint
    if the module is missing instead of attempting auto-install.
#>

[CmdletBinding()]
param(
    [string]$Id,
    [string]$Path,
    [switch]$Json,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Output 'Usage: ./validate-workflow.ps1 -Id <workflow-id> [-Json] [-Help]'
    Write-Output '       ./validate-workflow.ps1 -Path <yaml-path> [-Json] [-Help]'
    Write-Output ''
    Write-Output 'Validates a workflow.yml file against studio/workflows/manifest.schema.json'
    Write-Output 'using the powershell-yaml module to parse YAML.'
    Write-Output ''
    Write-Output 'Options:'
    Write-Output '  -Id      Resolve workflow.yml from studio/workflows/<id>/workflow.yml'
    Write-Output '  -Path    Direct path to a workflow.yml file (mutually exclusive with -Id)'
    Write-Output '  -Json    Output structured JSON summary'
    Write-Output '  -Help    Show this help message'
    exit 0
}

. "$PSScriptRoot/common.ps1"

if (-not $Id -and -not $Path) {
    Write-Error 'Either -Id or -Path is required. See -Help.'
    exit 1
}
if ($Id -and $Path) {
    Write-Error '-Id and -Path are mutually exclusive.'
    exit 1
}

$studioRoot = Find-StudioRoot -StartDir $PSScriptRoot
if (-not $studioRoot) { throw 'Unable to resolve studio root.' }
$workflowsRoot = Join-Path $studioRoot 'workflows'
$schemaPath = Join-Path $workflowsRoot 'manifest.schema.json'

if (-not (Test-Path -LiteralPath $schemaPath)) {
    throw "Workflow manifest.schema.json not found: $schemaPath"
}

if ($Id) {
    if ($Id -notmatch '^[a-z0-9][a-z0-9-]{1,63}$') {
        Write-Error "Invalid workflow id: '$Id' (must match ^[a-z0-9][a-z0-9-]{1,63}`$)"
        exit 1
    }
    $candidate = Join-Path (Join-Path $workflowsRoot $Id) 'workflow.yml'
    Assert-PathInsideRoot -Root $workflowsRoot -Candidate $candidate -MessagePrefix 'workflow.yml escapes workflows root'
    $resolvedPath = $candidate
} else {
    $resolvedPath = Resolve-AbsolutePath -Path $Path
}

$errors = @()
$warnings = @()

if (-not (Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
    $errors += "workflow.yml not found: $resolvedPath"
}

# powershell-yaml dependency check (detection only, never auto-install)
$yamlModule = Get-Module -ListAvailable -Name 'powershell-yaml' | Sort-Object Version -Descending | Select-Object -First 1
$yamlAvailable = [bool]$yamlModule

if (-not $yamlAvailable) {
    $errors += 'powershell-yaml module is not installed. Run: Install-Module -Name powershell-yaml -Scope CurrentUser'
}

$parsed = $null
$jsonString = $null
$schemaValid = $null

if ($yamlAvailable -and (Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
    try {
        Import-Module -Name 'powershell-yaml' -ErrorAction Stop
        $rawYaml = Get-Content -LiteralPath $resolvedPath -Raw
        $parsed = ConvertFrom-Yaml -Yaml $rawYaml -Ordered
    } catch {
        $errors += "YAML parse error: $($_.Exception.Message)"
    }
}

if ($parsed) {
    try {
        $jsonString = ($parsed | ConvertTo-Json -Depth 30 -Compress)
    } catch {
        $errors += "Failed to convert parsed YAML to JSON: $($_.Exception.Message)"
    }
}

if ($jsonString) {
    try {
        $schemaContent = Get-Content -LiteralPath $schemaPath -Raw
        $schemaValid = Test-Json -Json $jsonString -Schema $schemaContent -ErrorAction Stop
    } catch {
        $schemaValid = $false
        $errors += "Schema validation error: $($_.Exception.Message)"
    }
}

$workflowMeta = [ordered]@{}
if ($parsed -and $parsed.workflow) {
    foreach ($field in 'id', 'name', 'version', 'integration') {
        if ($parsed.workflow.Contains($field)) {
            $workflowMeta[$field] = $parsed.workflow[$field]
        }
    }
}

$result = [ordered]@{
    VALID                  = (($errors.Count -eq 0) -and ($schemaValid -eq $true))
    SCHEMA_PATH            = $schemaPath
    WORKFLOW_PATH          = $resolvedPath
    YAML_AVAILABLE         = $yamlAvailable
    YAML_MODULE_VERSION    = if ($yamlModule) { $yamlModule.Version.ToString() } else { $null }
    SCHEMA_VALID           = $schemaValid
    WORKFLOW_META          = $workflowMeta
    ERROR_COUNT            = $errors.Count
    WARNING_COUNT          = $warnings.Count
    ERRORS                 = @($errors)
    WARNINGS               = @($warnings)
}

if ($Json) {
    [PSCustomObject]$result | ConvertTo-Json -Depth 10
    if (-not $result.VALID) { exit 1 } else { exit 0 }
}

Write-Output ("Workflow: {0}" -f $resolvedPath)
Write-Output ("Schema:   {0}" -f $schemaPath)
Write-Output ("Yaml available:  {0}" -f $yamlAvailable.ToString().ToLower())
Write-Output ("Schema valid:    {0}" -f ($schemaValid | Out-String).Trim())
Write-Output ("Errors:   {0}" -f $errors.Count)
foreach ($e in $errors) { Write-Output "- $e" }
if (-not $result.VALID) { exit 1 } else { exit 0 }
