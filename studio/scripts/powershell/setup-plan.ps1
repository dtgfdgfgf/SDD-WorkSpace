#!/usr/bin/env pwsh
# Setup implementation plan for a feature

[CmdletBinding()]
param(
    [switch]$Json,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

# Show help if requested
if ($Help) {
    Write-Output "Usage: ./setup-plan.ps1 [-Json] [-Help]"
    Write-Output "  -Json     Output results in JSON format"
    Write-Output "  -Help     Show this help message"
    exit 0
}

# Load common functions
. "$PSScriptRoot/common.ps1"

function Assert-ReadyForPlan {
    param([Parameter(Mandatory = $true)][object]$Paths)

    if (-not (Test-Path -LiteralPath $Paths.READINESS_ASSESSMENT -PathType Leaf)) {
        throw "readiness-assessment.md is required before planning. Run /speckit.readiness first: $($Paths.READINESS_ASSESSMENT)"
    }

    $readinessContent = Get-Content -LiteralPath $Paths.READINESS_ASSESSMENT -Raw
    $primaryStatus = Get-MarkdownField -Content $readinessContent -Field 'Primary Status'
    if ($primaryStatus -ne 'READY_FOR_PLAN') {
        throw "Planning is blocked because readiness Primary Status is '$primaryStatus'. Complete readiness remediation before running /speckit.plan."
    }

    $ledgerRequirement = Get-MarkdownField -Content $readinessContent -Field 'Intent Ledger Requirement'
    if ($ledgerRequirement -match 'Create\s+`?intent-ledger\.md`?|Update\s+`?intent-ledger\.md`?') {
        if (-not (Test-Path -LiteralPath $Paths.INTENT_LEDGER -PathType Leaf)) {
            throw "Planning is blocked because readiness requires intent-ledger.md, but it does not exist: $($Paths.INTENT_LEDGER)"
        }
    }

    $authorizationRecord = Join-Path $Paths.ECI_DIR 'authorization-record.md'
    if (Test-Path -LiteralPath $authorizationRecord -PathType Leaf) {
        $authorizationContent = Get-Content -LiteralPath $authorizationRecord -Raw
        $authorizationOutcome = Get-MarkdownField -Content $authorizationContent -Field 'Authorization Outcome'
        if ($authorizationOutcome -ne 'READY_FOR_MAINLINE_IMPLEMENTATION') {
            throw "Planning is blocked because ECI Authorization Outcome is '$authorizationOutcome'. Re-run /speckit.readiness after resolving the ECI boundary."
        }
    }
}

# Get all paths and variables from common functions
$paths = Get-FeaturePathsEnv

# Path boundary defense: SPECIFY_FEATURE env var or git branch could be tampered to escape REPO_ROOT.
Assert-PathInsideRoot -Root $paths.REPO_ROOT -Candidate $paths.FEATURE_DIR -MessagePrefix 'FEATURE_DIR escapes REPO_ROOT'
Assert-PathInsideRoot -Root $paths.REPO_ROOT -Candidate $paths.IMPL_PLAN -MessagePrefix 'IMPL_PLAN escapes REPO_ROOT'
Assert-PathInsideRoot -Root $paths.REPO_ROOT -Candidate $paths.INTENT_LEDGER -MessagePrefix 'INTENT_LEDGER escapes REPO_ROOT'
Assert-PathInsideRoot -Root $paths.REPO_ROOT -Candidate $paths.ECI_DIR -MessagePrefix 'ECI_DIR escapes REPO_ROOT'

# Check if we're on a proper feature branch (only for git repos)
if (-not (Test-FeatureBranch -Branch $paths.CURRENT_BRANCH -HasGit $paths.HAS_GIT)) {
    exit 1
}

Assert-ReadyForPlan -Paths $paths

# Ensure the feature directory exists
New-Item -ItemType Directory -Path $paths.FEATURE_DIR -Force | Out-Null

# Copy plan template if it exists, otherwise note it or create empty file
# Try studio-level template first, then project-level
$studioRoot = Find-StudioRoot -StartDir $paths.REPO_ROOT
$template = $null
if ($studioRoot) {
    $studioTemplate = Join-Path $studioRoot 'templates/sdd-docs/plan-template.md'
    if (Test-Path $studioTemplate) {
        $template = $studioTemplate
    }
}
if (-not $template) {
    $template = Join-Path $paths.REPO_ROOT '.specify/templates/plan-template.md'
}

if (Test-Path $template) { 
    Copy-Item $template $paths.IMPL_PLAN -Force
    Write-Output "Copied plan template to $($paths.IMPL_PLAN)"
} else {
    Write-Warning "Plan template not found at $template"
    # Create a basic plan file if template doesn't exist
    New-Item -ItemType File -Path $paths.IMPL_PLAN -Force | Out-Null
}

# Output results
if ($Json) {
    # Include studio paths for constitution loading
    $constitutions = Get-ConstitutionPaths -StudioRoot $studioRoot -ProjectRoot $paths.REPO_ROOT
    $result = [PSCustomObject]@{ 
        FEATURE_SPEC = $paths.FEATURE_SPEC
        IMPL_PLAN = $paths.IMPL_PLAN
        SPECS_DIR = $paths.FEATURE_DIR
        BRANCH = $paths.CURRENT_BRANCH
        HAS_GIT = $paths.HAS_GIT
        STUDIO_ROOT = $studioRoot
        CONSTITUTIONS = $constitutions
    }
    $result | ConvertTo-Json -Compress
} else {
    Write-Output "FEATURE_SPEC: $($paths.FEATURE_SPEC)"
    Write-Output "IMPL_PLAN: $($paths.IMPL_PLAN)"
    Write-Output "SPECS_DIR: $($paths.FEATURE_DIR)"
    Write-Output "BRANCH: $($paths.CURRENT_BRANCH)"
    Write-Output "HAS_GIT: $($paths.HAS_GIT)"
    Write-Output "STUDIO_ROOT: $studioRoot"
}
