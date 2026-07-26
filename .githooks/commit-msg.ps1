#!/usr/bin/env pwsh

#Requires -Version 7.0
<#
.SYNOPSIS
    Commit message hook for Conventional Commits validation.

.DESCRIPTION
    Validates that commit messages follow the Conventional Commits format:
    <type>: <description>

    Where type is one of: feat, fix, docs, refactor, chore, test, style

.NOTES
    To enable: git config core.hooksPath .githooks
    To bypass: git commit --no-verify
#>

param(
    [Parameter(Position = 0)]
    [string]$CommitMsgFile
)

$ErrorActionPreference = "Continue"

function Write-HookError {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-HookSuccess {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-HookInfo {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-HookWarning {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

# Get commit message file path
if (-not $CommitMsgFile) {
    $CommitMsgFile = $args[0]
}

if (-not $CommitMsgFile -or -not (Test-Path $CommitMsgFile)) {
    Write-HookError "Commit message file not found"
    exit 1
}

$commitMsg = Get-Content $CommitMsgFile -Raw -ErrorAction SilentlyContinue
if (-not $commitMsg) {
    Write-HookError "Empty commit message"
    exit 1
}

# Get first non-empty, non-comment line as subject (Conventional Commits subject)
$subject = $null
foreach ($line in ($commitMsg -split "`r?`n")) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    if ($line.StartsWith('#')) { continue }
    $subject = $line.Trim()
    break
}

if ([string]::IsNullOrWhiteSpace($subject)) {
    Write-HookError "Commit message has no subject line"
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Commit Message Validation" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Allow merge / revert canonical commits without further checks
if ($subject -match '^Merge ') {
    Write-HookSuccess "Merge commit accepted"
    exit 0
}
if ($subject -match '^Revert ".*"$') {
    Write-HookSuccess "Revert commit accepted"
    exit 0
}

# ========================================
# Conventional Commits Validation
# ========================================

# Valid types (constitution §10 + common Conventional Commits ecosystem types)
$validTypes = @(
    "feat",      # New feature
    "fix",       # Bug fix
    "docs",      # Documentation changes
    "refactor",  # Code refactoring (no feature change)
    "chore",     # Build, config, tooling changes
    "test",      # Test-related changes
    "style",     # Code style (formatting, no logic change)
    "ci",        # CI configuration changes
    "perf",      # Performance improvements
    "build",     # Build system changes
    "revert"     # Manual revert with explicit type
)

# Pattern: type(scope)?!?: summary
# Trailing "!" before colon marks a breaking change (per Conventional Commits spec)
$typePattern = "^($($validTypes -join '|'))(\([a-z0-9_/.-]+\))?(!)?:\s+.+"

# Check format
if ($subject -notmatch $typePattern) {
    Write-HookError "Commit message does not follow Conventional Commits format"
    Write-Host ""
    Write-Host "Expected format:" -ForegroundColor Yellow
    Write-Host '  <type>: <description>' -ForegroundColor Yellow
    Write-Host '  <type>(<scope>): <description>' -ForegroundColor Yellow
    Write-Host '  <type>!: <description>             # breaking change' -ForegroundColor Yellow
    Write-Host '  <type>(<scope>)!: <description>    # breaking change with scope' -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Valid types:" -ForegroundColor Yellow
    Write-Host "  feat     - New feature" -ForegroundColor Gray
    Write-Host "  fix      - Bug fix" -ForegroundColor Gray
    Write-Host "  docs     - Documentation changes" -ForegroundColor Gray
    Write-Host "  refactor - Code refactoring (no feature change)" -ForegroundColor Gray
    Write-Host "  chore    - Build, config, tooling changes" -ForegroundColor Gray
    Write-Host "  test     - Test-related changes" -ForegroundColor Gray
    Write-Host "  style    - Code style (formatting, no logic change)" -ForegroundColor Gray
    Write-Host "  ci       - CI/CD configuration changes" -ForegroundColor Gray
    Write-Host "  perf     - Performance improvements" -ForegroundColor Gray
    Write-Host "  build    - Build system changes" -ForegroundColor Gray
    Write-Host "  revert   - Explicit revert with type" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host '  feat: 新增使用者登入功能' -ForegroundColor Gray
    Write-Host '  fix(auth): 修正過期 token 處理' -ForegroundColor Gray
    Write-Host '  docs: 更新 README 安裝說明' -ForegroundColor Gray
    Write-Host '  chore(deps): 升級相依套件版本' -ForegroundColor Gray
    Write-Host '  feat!: 重構 API 介面 (BREAKING CHANGE)' -ForegroundColor Gray
    Write-Host ""
    Write-Host "Your message: $subject" -ForegroundColor Red
    Write-Host ""
    Write-Host "Use 'git commit --no-verify' to bypass" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

# Extract type and breaking-change marker
$type = ($subject -replace '^(\w+)(\(.+\))?(!)?:.*', '$1')
$isBreaking = ($subject -match '^\w+(\(.+\))?!:')
if (-not $isBreaking) {
    # Also check footer for BREAKING CHANGE / BREAKING-CHANGE marker
    if ($commitMsg -match '(?m)^BREAKING[ -]CHANGE:') {
        $isBreaking = $true
    }
}

# Check subject length (recommended max 72 characters)
if ($subject.Length -gt 72) {
    Write-HookWarning "Subject line is $($subject.Length) characters (recommended: <=72)"
}

# Check for period at end (should not have)
if ($subject -match '\.$') {
    Write-HookWarning "Subject line should not end with a period"
}

Write-HookSuccess "Commit message format valid"
Write-Host "  Type: $type" -ForegroundColor Gray
if ($isBreaking) {
    Write-Host "  Breaking change: yes" -ForegroundColor Yellow
}
Write-Host "  Subject: $subject" -ForegroundColor Gray
Write-Host ""

exit 0
