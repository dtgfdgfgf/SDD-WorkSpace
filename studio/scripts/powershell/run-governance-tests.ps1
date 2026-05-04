#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Run all governance tool Pester tests.

.DESCRIPTION
    Entry point for the self-verification layer.
    Executes all tests under studio/tests/ and reports results.

.PARAMETER Output
    Pester output verbosity: Minimal, Normal, Detailed, Diagnostic. Default: Detailed.

.EXAMPLE
    pwsh studio/scripts/powershell/run-governance-tests.ps1
    pwsh studio/scripts/powershell/run-governance-tests.ps1 -Output Minimal
#>

param(
    [ValidateSet('Minimal', 'Normal', 'Detailed', 'Diagnostic')]
    [string]$Output = 'Detailed'
)

$ErrorActionPreference = 'Stop'

# Resolve paths
$testsDir = Join-Path $PSScriptRoot '../../tests'
if (-not (Test-Path -LiteralPath $testsDir)) {
    Write-Error "Tests directory not found: $testsDir"
    exit 1
}

# Ensure Pester 5+ is available
$pester = Get-Module -Name Pester -ListAvailable | Where-Object { $_.Version.Major -ge 5 } | Select-Object -First 1
if (-not $pester) {
    Write-Error "Pester 5+ is required. Install with: Install-Module -Name Pester -Force -Scope CurrentUser"
    exit 1
}

Import-Module Pester -MinimumVersion 5.0 -Force

# Configure and run
$artifactsDir = Join-Path $testsDir '_artifacts'
if (-not (Test-Path -LiteralPath $artifactsDir)) {
    New-Item -ItemType Directory -Path $artifactsDir -Force | Out-Null
}
$resultPath = Join-Path $artifactsDir 'testResults.xml'

$config = New-PesterConfiguration
$config.Run.Path = $testsDir
$config.Run.Exit = $true
$config.Output.Verbosity = $Output
$config.TestResult.Enabled = $true
$config.TestResult.OutputFormat = 'NUnitXml'
$config.TestResult.OutputPath = $resultPath

Write-Host "`n=== Governance Self-Verification ===" -ForegroundColor Cyan
Write-Host "Tests path: $testsDir" -ForegroundColor DarkGray
Write-Host "Result XML: $resultPath" -ForegroundColor DarkGray
Write-Host ''

Invoke-Pester -Configuration $config
