#!/usr/bin/env pwsh

#Requires -Version 7.0
# Setup implementation plan for a feature

<#
.SYNOPSIS
    Stage entry gate for /speckit.plan.

.PARAMETER FeatureDir
    Optional feature directory override, resolved relative to the configured
    project root. The target must be a direct child of <project>/specs/.

.PARAMETER Json
    Emit a single structured JSON object instead of human-readable text.

.PARAMETER Help
    Show this help message.
#>

[CmdletBinding()]
param(
    [string]$FeatureDir,
    [switch]$Json,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

# Show help if requested
if ($Help) {
    Write-Output "Usage: ./setup-plan.ps1 [-FeatureDir <path>] [-Json] [-Help]"
    Write-Output "  -FeatureDir  Override feature directory (defaults to current branch)."
    Write-Output "  -Json        Output results in JSON format"
    Write-Output "  -Help        Show this help message"
    exit 0
}

# Load common functions
. "$PSScriptRoot/common.ps1"

function Invoke-FeatureStructureValidation {
    param([Parameter(Mandatory = $true)][string]$FeatureDir)

    $validatorPath = Join-Path $PSScriptRoot 'validate-feature-structure.ps1'
    if (-not (Test-Path -LiteralPath $validatorPath -PathType Leaf)) {
        throw "validate-feature-structure.ps1 is required before planning: $validatorPath"
    }

    $output = & pwsh -NoProfile -File $validatorPath -FeatureDir $FeatureDir -Json 2>&1
    $exitCode = $LASTEXITCODE
    if (-not $output) {
        throw 'validate-feature-structure.ps1 returned no machine-readable result.'
    }

    try {
        $result = ($output -join "`n") | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "validate-feature-structure.ps1 returned invalid JSON: $($_.Exception.Message)"
    }

    if ($result.VALID -isnot [bool]) {
        throw 'validate-feature-structure.ps1 result is missing boolean VALID.'
    }
    if ($exitCode -ne 0 -or -not $result.VALID) {
        $details = @($result.ERRORS | ForEach-Object { "[$($_.id)] $($_.message)" }) -join '; '
        if (-not $details) {
            $details = "validator exited with code $exitCode"
        }
        throw "Planning is blocked by feature structure validation: $details"
    }

    return $result
}

function Assert-ReadyForPlan {
    param([Parameter(Mandatory = $true)][object]$Paths)

    if (-not (Test-Path -LiteralPath $Paths.READINESS_ASSESSMENT -PathType Leaf)) {
        throw "readiness-assessment.md is required before planning. Run /speckit.readiness first: $($Paths.READINESS_ASSESSMENT)"
    }

    $validation = Invoke-FeatureStructureValidation -FeatureDir $Paths.FEATURE_DIR
    $readinessContent = Get-Content -LiteralPath $Paths.READINESS_ASSESSMENT -Raw
    $primaryStatus = [string]$validation.READINESS_PRIMARY_STATUS
    if ($primaryStatus -ne 'READY_FOR_PLAN') {
        throw "Planning is blocked because readiness Primary Status is '$primaryStatus'. Complete readiness remediation before running /speckit.plan."
    }

    $eciReentryStatus = [string]$validation.ECI_REENTRY_STATUS
    if ($eciReentryStatus -eq 'NOT_REQUIRED') {
        if ($validation.ECI_REQUIRED -eq $true) {
            throw 'Planning is blocked because Readiness declares ECI NOT_REQUIRED while current ECI evidence requires governed re-entry.'
        }
    } elseif ($eciReentryStatus -ne 'COMPLETE') {
        throw "Planning is blocked because ECI Re-entry Status is '$eciReentryStatus'. Run /speckit.readiness after the complete ECI evidence set is available."
    }

    $ledgerRequirement = Get-MarkdownField -Content $readinessContent -Field 'Intent Ledger Requirement'
    if ($ledgerRequirement -match 'Create\s+`?intent-ledger\.md`?|Update\s+`?intent-ledger\.md`?') {
        if (-not (Test-Path -LiteralPath $Paths.INTENT_LEDGER -PathType Leaf)) {
            throw "Planning is blocked because readiness requires intent-ledger.md, but it does not exist: $($Paths.INTENT_LEDGER)"
        }
    }

    if ($validation.ECI_REQUIRED -eq $true) {
        $authorizationOutcome = [string]$validation.ECI_AUTHORIZATION_OUTCOME
        if ($authorizationOutcome -ne 'READY_FOR_MAINLINE_IMPLEMENTATION') {
            throw "Planning is blocked because ECI Authorization Outcome is '$authorizationOutcome'. Re-run /speckit.readiness after resolving the ECI boundary."
        }
    }
}

function Resolve-FeatureContext {
    param([string]$Override)

    $basePaths = Get-FeaturePathsEnv
    if (-not $Override) {
        return $basePaths
    }

    $resolved = Resolve-AbsolutePath -Path $Override -BaseDir $basePaths.REPO_ROOT
    $specsRoot = [System.IO.Path]::GetFullPath((Join-Path $basePaths.REPO_ROOT 'specs'))
    $featureParent = [System.IO.Path]::GetFullPath((Split-Path -Parent $resolved))
    if (-not $featureParent.Equals($specsRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "FEATURE_DIR escapes project root: $resolved must be located at <project>/specs/<feature>"
    }

    $readinessDir = Join-Path $resolved 'readiness'
    return [PSCustomObject]@{
        REPO_ROOT            = $basePaths.REPO_ROOT
        CURRENT_BRANCH       = $basePaths.CURRENT_BRANCH
        HAS_GIT              = $basePaths.HAS_GIT
        FEATURE_DIR          = $resolved
        FEATURE_SPEC         = Join-Path $resolved 'spec.md'
        INTENT_LEDGER        = Join-Path $resolved 'intent-ledger.md'
        READINESS_DIR        = $readinessDir
        READINESS_ASSESSMENT = Join-Path $readinessDir 'readiness-assessment.md'
        ECI_DIR              = Join-Path $readinessDir 'eci'
        IMPL_PLAN            = Join-Path $resolved 'plan.md'
    }
}

# Get all paths and variables from common functions, while allowing a workflow
# to bind plan preparation to its explicit feature input instead of the branch.
$paths = Resolve-FeatureContext -Override $FeatureDir

# Path boundary defense: SPECIFY_FEATURE env var or git branch could be tampered to escape REPO_ROOT.
Assert-PathInsideRoot -Root $paths.REPO_ROOT -Candidate $paths.FEATURE_DIR -MessagePrefix 'FEATURE_DIR escapes REPO_ROOT'
Assert-PathInsideRoot -Root $paths.REPO_ROOT -Candidate $paths.IMPL_PLAN -MessagePrefix 'IMPL_PLAN escapes REPO_ROOT'
Assert-PathInsideRoot -Root $paths.REPO_ROOT -Candidate $paths.INTENT_LEDGER -MessagePrefix 'INTENT_LEDGER escapes REPO_ROOT'
Assert-PathInsideRoot -Root $paths.REPO_ROOT -Candidate $paths.ECI_DIR -MessagePrefix 'ECI_DIR escapes REPO_ROOT'

# Check if we're on a proper feature branch (only for git repos). An explicit
# workflow feature is already validated against <project>/specs/<feature> and
# intentionally may differ from the current branch.
if (-not $FeatureDir -and -not (Test-FeatureBranch -Branch $paths.CURRENT_BRANCH -HasGit $paths.HAS_GIT)) {
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

if (Test-Path -LiteralPath $paths.IMPL_PLAN -PathType Leaf) {
    # Idempotent scaffold: never overwrite an existing plan.md. Matches setup-readiness /
    # setup-tasks / setup-analyze, and prevents a workflow resume from clobbering agent-authored
    # plan content back to the template.
    Write-Output "plan.md already exists; left untouched: $($paths.IMPL_PLAN)"
} elseif (Test-Path $template) {
    Copy-Item $template $paths.IMPL_PLAN
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
