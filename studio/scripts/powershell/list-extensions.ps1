#!/usr/bin/env pwsh

[CmdletBinding()]
param(
    [string]$Id,
    [switch]$Json,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    $helpLines = @(
        'Usage: ./list-extensions.ps1 [-Id <extension-id>] [-Json] [-Help]',
        '',
        'Lists the current studio-first extension registry using the validator-backed catalog/state view.',
        '',
        'Options:',
        '  -Id      Show details for one extension id',
        '  -Json    Output structured JSON summary',
        '  -Help    Show this help message'
    )
    Write-Output ($helpLines -join "`n")
    exit 0
}

. "$PSScriptRoot/common.ps1"

$validatorPath = Join-Path $PSScriptRoot 'validate-extension-registry.ps1'
$arguments = @('-Json')
if ($Id) {
    $arguments += @('-Id', $Id)
}

$result = Invoke-JsonScript -ScriptPath $validatorPath -Arguments $arguments

if ($Json) {
    [PSCustomObject]$result | ConvertTo-Json -Depth 10
    exit 0
}

if ($result.EXTENSIONS.Count -eq 0) {
    Write-Output 'No extensions registered in studio/extensions/.'
    exit 0
}

foreach ($extension in @($result.EXTENSIONS)) {
    Write-Output ("- {0} | enabled={1} | review={2} | trust={3} | valid={4}" -f $extension.id, ([bool]$extension.enabled).ToString().ToLower(), $extension.reviewStatus, $extension.trustLevel, ([bool]$extension.valid).ToString().ToLower())
}

if (-not $result.VALID) {
    Write-Output ''
    Write-Output ("Registry errors: {0}" -f $result.ERROR_COUNT)
}
