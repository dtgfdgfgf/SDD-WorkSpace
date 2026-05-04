<#
.SYNOPSIS
    Setup Git hooks for the SDD workspace or a consumer project repository.

.DESCRIPTION
    Configures Git to use the workspace .githooks directory. When -ProjectRoot is
    omitted, the workspace repository is configured. When -ProjectRoot is provided,
    that independent consumer repository is configured with a relative hooksPath
    that points back to the workspace hooks.

.PARAMETER ProjectRoot
    Optional Git repository root to configure. Defaults to the workspace root.

.EXAMPLE
    .\setup-hooks.ps1
    .\setup-hooks.ps1 -ProjectRoot ..\..\projects\my-project
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot
)

$ErrorActionPreference = 'Stop'

. "$PSScriptRoot/common.ps1"

$workspaceRoot = Find-WorkspaceRoot -StartDir $PSScriptRoot
if (-not $workspaceRoot) {
    Write-Host '[ERROR] Unable to resolve workspace root from script location.' -ForegroundColor Red
    exit 1
}

$targetRoot = if ($ProjectRoot) {
    Resolve-AbsolutePath -Path $ProjectRoot
} else {
    $workspaceRoot
}

$hooksDir = Join-Path $workspaceRoot '.githooks'

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host '  SDD Git Hooks Setup' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''

if (-not (Test-Path -LiteralPath $hooksDir -PathType Container)) {
    Write-Host "[ERROR] .githooks directory not found at: $hooksDir" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path -LiteralPath $targetRoot -PathType Container)) {
    Write-Host "[ERROR] Repository root not found: $targetRoot" -ForegroundColor Red
    exit 1
}

$gitRoot = & git -C $targetRoot rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0 -or -not $gitRoot) {
    Write-Host "[ERROR] Not a Git repository: $targetRoot" -ForegroundColor Red
    Write-Host '        Initialize with: git init -b main' -ForegroundColor Yellow
    exit 1
}

$resolvedGitRoot = (Resolve-Path -LiteralPath $gitRoot).Path
if ($resolvedGitRoot -ne (Resolve-Path -LiteralPath $targetRoot).Path) {
    Write-Host "[ERROR] ProjectRoot must be the Git repository root: $targetRoot" -ForegroundColor Red
    Write-Host "        Resolved Git root: $resolvedGitRoot" -ForegroundColor Yellow
    exit 1
}

$hooksPath = [System.IO.Path]::GetRelativePath($resolvedGitRoot, $hooksDir) -replace '\\', '/'

try {
    git -C $resolvedGitRoot config core.hooksPath $hooksPath

    Write-Host "[OK] Git hooks path configured: $hooksPath" -ForegroundColor Green
    Write-Host ''
    Write-Host 'Hooks enabled:' -ForegroundColor Cyan
    Write-Host '  - pre-commit  - Runs shared runtime audit and validates SDD governance docs (spec.md, readiness/**/*.md, plan.md, tasks.md)' -ForegroundColor Gray
    Write-Host '  - commit-msg  - Validates Conventional Commits format' -ForegroundColor Gray
    Write-Host ''
    Write-Host 'To bypass hooks temporarily:' -ForegroundColor Yellow
    Write-Host '  git commit --no-verify' -ForegroundColor Gray
    Write-Host ''
    Write-Host 'To disable hooks:' -ForegroundColor Yellow
    Write-Host '  git config --unset core.hooksPath' -ForegroundColor Gray
    Write-Host ''
} catch {
    Write-Host "[ERROR] Failed to configure git hooks: $_" -ForegroundColor Red
    exit 1
}
