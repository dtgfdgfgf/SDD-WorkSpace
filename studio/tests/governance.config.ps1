#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Shared test helper for governance Pester tests.
    Provides AST-based function extraction and workspace path resolution.
#>

$ErrorActionPreference = 'Stop'

# Resolve workspace root from this file's location: studio/tests/ -> workspace root
$script:WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path

function Get-ScriptFunctionsBlock {
    <#
    .SYNOPSIS
        Extract function definitions from a PowerShell script as a single scriptblock.
        Caller must dot-source the result: . (Get-ScriptFunctionsBlock -ScriptPath ...)
        This ensures functions are created in the caller's scope, not this function's scope.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ScriptPath
    )

    if (-not (Test-Path -LiteralPath $ScriptPath)) {
        throw "Script not found: $ScriptPath"
    }

    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $ScriptPath, [ref]$tokens, [ref]$parseErrors
    )

    if ($parseErrors.Count -gt 0) {
        throw "Parse errors in ${ScriptPath}: $($parseErrors[0].Message)"
    }

    $functions = $ast.FindAll(
        { $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] },
        $false
    )

    $text = ($functions | ForEach-Object { $_.Extent.Text }) -join "`n`n"
    return [scriptblock]::Create($text)
}

function Get-FixturePath {
    param([string]$Name)
    return Join-Path $PSScriptRoot "fixtures/$Name"
}
