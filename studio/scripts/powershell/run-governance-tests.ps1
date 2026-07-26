#!/usr/bin/env pwsh

#Requires -Version 7.0
<#
.SYNOPSIS
    Run all governance tool Pester tests.

.DESCRIPTION
    Entry point for the self-verification layer.
    Executes all tests under studio/tests/ and reports results.

.PARAMETER Output
    Pester output verbosity: Minimal, Normal, Detailed, Diagnostic. Default: Detailed.

.PARAMETER CodeCoverage
    Collect Cobertura line coverage for studio/scripts/powershell/*.ps1.

.EXAMPLE
    pwsh studio/scripts/powershell/run-governance-tests.ps1
    pwsh studio/scripts/powershell/run-governance-tests.ps1 -Output Minimal
    pwsh studio/scripts/powershell/run-governance-tests.ps1 -Output Normal -CodeCoverage
#>

param(
    [ValidateSet('Minimal', 'Normal', 'Detailed', 'Diagnostic')]
    [string]$Output = 'Detailed',
    [switch]$CodeCoverage
)

$ErrorActionPreference = 'Stop'

# Resolve paths
$testsDir = Join-Path $PSScriptRoot '../../tests'
if (-not (Test-Path -LiteralPath $testsDir)) {
    Write-Error "Tests directory not found: $testsDir"
    exit 1
}

# Keep local and hosted execution on the same measured Pester baseline.
$requiredPesterVersion = [version]'5.7.1'
$pester = Get-Module -Name Pester -ListAvailable | Where-Object { $_.Version -eq $requiredPesterVersion } | Select-Object -First 1
if (-not $pester) {
    Write-Error "Pester 5.7.1 is required. Install with: Install-Module -Name Pester -RequiredVersion 5.7.1 -Force -Scope CurrentUser"
    exit 1
}

Import-Module Pester -RequiredVersion 5.7.1 -Force

# Configure and run
$artifactsDir = Join-Path $testsDir '_artifacts'
if (-not (Test-Path -LiteralPath $artifactsDir)) {
    New-Item -ItemType Directory -Path $artifactsDir -Force | Out-Null
}
$resultPath = Join-Path $artifactsDir 'testResults.xml'
$coveragePath = Join-Path $artifactsDir 'codeCoverage.xml'

$config = New-PesterConfiguration
$config.Run.Path = $testsDir
$config.Run.Exit = $true
$config.Output.Verbosity = $Output
$config.TestResult.Enabled = $true
$config.TestResult.OutputFormat = 'NUnitXml'
$config.TestResult.OutputPath = $resultPath
if ($CodeCoverage) {
    $config.CodeCoverage.Enabled = $true
    $config.CodeCoverage.Path = @($PSScriptRoot)
    $config.CodeCoverage.RecursePaths = $true
    $config.CodeCoverage.ExcludeTests = $true
    $config.CodeCoverage.OutputFormat = 'Cobertura'
    $config.CodeCoverage.OutputPath = $coveragePath
    $config.CodeCoverage.OutputEncoding = 'UTF8'
}

Write-Host "`n=== Governance Self-Verification ===" -ForegroundColor Cyan
Write-Host "Tests path: $testsDir" -ForegroundColor DarkGray
Write-Host "Result XML: $resultPath" -ForegroundColor DarkGray
if ($CodeCoverage) {
    Write-Host "Coverage XML: $coveragePath" -ForegroundColor DarkGray
}
Write-Host ''

Invoke-Pester -Configuration $config
