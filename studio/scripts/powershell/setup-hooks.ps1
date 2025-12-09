<#
.SYNOPSIS
    Setup Git hooks for the SDD workspace.

.DESCRIPTION
    Configures Git to use the .githooks directory for hooks.
    This enables SDD document validation and Conventional Commits checking.

.EXAMPLE
    .\setup-hooks.ps1

.NOTES
    Run this once per workspace clone.
#>

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SDD Git Hooks Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Find workspace root
$workspaceRoot = $PWD.Path
$maxDepth = 5
$depth = 0

while ($depth -lt $maxDepth) {
    if (Test-Path (Join-Path $workspaceRoot "studio")) {
        break
    }
    $parent = Split-Path $workspaceRoot -Parent
    if (-not $parent -or $parent -eq $workspaceRoot) {
        break
    }
    $workspaceRoot = $parent
    $depth++
}

$hooksDir = Join-Path $workspaceRoot ".githooks"

if (-not (Test-Path $hooksDir)) {
    Write-Host "❌ .githooks directory not found at: $hooksDir" -ForegroundColor Red
    exit 1
}

# Check if we're in a git repository
$gitDir = Join-Path $workspaceRoot ".git"
if (-not (Test-Path $gitDir)) {
    Write-Host "❌ Not a Git repository: $workspaceRoot" -ForegroundColor Red
    Write-Host "   Initialize with: git init" -ForegroundColor Yellow
    exit 1
}

# Configure git hooks path
try {
    Push-Location $workspaceRoot
    git config core.hooksPath .githooks
    Pop-Location
    
    Write-Host "✓ Git hooks path configured: .githooks" -ForegroundColor Green
    Write-Host ""
    Write-Host "Hooks enabled:" -ForegroundColor Cyan
    Write-Host "  • pre-commit  - Validates SDD documents (spec.md, plan.md, tasks.md)" -ForegroundColor Gray
    Write-Host "  • commit-msg  - Validates Conventional Commits format" -ForegroundColor Gray
    Write-Host ""
    Write-Host "To bypass hooks temporarily:" -ForegroundColor Yellow
    Write-Host "  git commit --no-verify" -ForegroundColor Gray
    Write-Host ""
    Write-Host "To disable hooks:" -ForegroundColor Yellow
    Write-Host "  git config --unset core.hooksPath" -ForegroundColor Gray
    Write-Host ""
    
} catch {
    Write-Host "❌ Failed to configure git hooks: $_" -ForegroundColor Red
    exit 1
}
