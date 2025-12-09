#!/usr/bin/env pwsh
# Common PowerShell functions for SDD workflow
# Modified for multi-project workspace structure (Studio-level)

# ============================================================================
# STUDIO-LEVEL PATH FUNCTIONS
# ============================================================================

function Find-StudioRoot {
    <#
    .SYNOPSIS
    Find the Studio root directory by looking for studio/constitution/ marker
    #>
    param(
        [string]$StartDir = (Get-Location),
        [string]$StudioRootOverride = $env:SDD_STUDIO_ROOT
    )
    
    # If environment variable is set, use it
    if ($StudioRootOverride -and (Test-Path $StudioRootOverride)) {
        return $StudioRootOverride
    }
    
    # Search upward for studio/ directory with constitution/
    $current = Resolve-Path $StartDir
    while ($true) {
        $studioPath = Join-Path $current "studio"
        $constitutionPath = Join-Path $studioPath "constitution"
        if (Test-Path $constitutionPath) {
            return $studioPath
        }
        $parent = Split-Path $current -Parent
        if ([string]::IsNullOrEmpty($parent) -or $parent -eq $current) { 
            return $null 
        }
        $current = $parent
    }
}

function Find-WorkspaceRoot {
    <#
    .SYNOPSIS
    Find the Workspace root directory (parent of studio/)
    #>
    param([string]$StartDir = (Get-Location))
    
    $studioRoot = Find-StudioRoot -StartDir $StartDir
    if ($studioRoot) {
        return Split-Path $studioRoot -Parent
    }
    return $null
}

function Get-StudioPaths {
    <#
    .SYNOPSIS
    Get all studio-level paths (templates, scripts, constitution)
    #>
    param([string]$StudioRoot)
    
    if (-not $StudioRoot) {
        $StudioRoot = Find-StudioRoot
    }
    
    if (-not $StudioRoot) {
        Write-Error "Studio root not found. Please set SDD_STUDIO_ROOT environment variable or run from within workspace."
        return $null
    }
    
    [PSCustomObject]@{
        STUDIO_ROOT           = $StudioRoot
        CONSTITUTION          = Join-Path $StudioRoot "constitution/constitution.md"
        TEMPLATES_DIR         = Join-Path $StudioRoot "templates/sdd-docs"
        SPEC_TEMPLATE         = Join-Path $StudioRoot "templates/sdd-docs/spec-template.md"
        PLAN_TEMPLATE         = Join-Path $StudioRoot "templates/sdd-docs/plan-template.md"
        TASKS_TEMPLATE        = Join-Path $StudioRoot "templates/sdd-docs/tasks-template.md"
        CHECKLIST_TEMPLATE    = Join-Path $StudioRoot "templates/sdd-docs/checklist-template.md"
        AGENT_FILE_TEMPLATE   = Join-Path $StudioRoot "templates/sdd-docs/agent-file-template.md"
        PROJECT_INIT_DIR      = Join-Path $StudioRoot "templates/project-init"
        PROJECT_CONST_TEMPLATE = Join-Path $StudioRoot "templates/project-constitution-template.md"
        SCRIPTS_DIR           = Join-Path $StudioRoot "scripts/powershell"
    }
}

function Get-ConstitutionPaths {
    <#
    .SYNOPSIS
    Get dual-layer constitution paths (Studio + Project)
    #>
    param(
        [string]$StudioRoot,
        [string]$ProjectRoot
    )
    
    if (-not $StudioRoot) {
        $StudioRoot = Find-StudioRoot
    }
    
    $result = @()
    
    # Studio constitution (REQUIRED - highest authority)
    $studioConst = Join-Path $StudioRoot "constitution/constitution.md"
    if (Test-Path $studioConst) {
        $result += [PSCustomObject]@{ 
            Type = "Studio"
            Path = $studioConst
            Priority = 1
            Required = $true
        }
    } else {
        Write-Warning "Studio constitution not found: $studioConst"
    }
    
    # Project constitution (OPTIONAL - additive rules)
    if ($ProjectRoot) {
        $projectConst = Join-Path $ProjectRoot ".specify/memory/constitution.md"
        if (Test-Path $projectConst) {
            $result += [PSCustomObject]@{ 
                Type = "Project"
                Path = $projectConst
                Priority = 2
                Required = $false
            }
        }
    }
    
    return $result
}

function Get-TemplatesPath {
    <#
    .SYNOPSIS
    Get the path to SDD templates directory
    #>
    param([string]$StudioRoot)
    
    if (-not $StudioRoot) {
        $StudioRoot = Find-StudioRoot
    }
    
    return Join-Path $StudioRoot "templates/sdd-docs"
}

# ============================================================================
# PROJECT-LEVEL PATH FUNCTIONS
# ============================================================================

function Get-RepoRoot {
    try {
        $result = git rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -eq 0) {
            return $result
        }
    } catch {
        # Git command failed
    }
    
    # Fall back to script location for non-git repos
    return (Resolve-Path (Join-Path $PSScriptRoot "../../..")).Path
}

function Get-CurrentBranch {
    # First check if SPECIFY_FEATURE environment variable is set
    if ($env:SPECIFY_FEATURE) {
        return $env:SPECIFY_FEATURE
    }
    
    # Then check git if available
    try {
        $result = git rev-parse --abbrev-ref HEAD 2>$null
        if ($LASTEXITCODE -eq 0) {
            return $result
        }
    } catch {
        # Git command failed
    }
    
    # For non-git repos, try to find the latest feature directory
    $repoRoot = Get-RepoRoot
    $specsDir = Join-Path $repoRoot "specs"
    
    if (Test-Path $specsDir) {
        $latestFeature = ""
        $highest = 0
        
        Get-ChildItem -Path $specsDir -Directory | ForEach-Object {
            if ($_.Name -match '^(\d{3})-') {
                $num = [int]$matches[1]
                if ($num -gt $highest) {
                    $highest = $num
                    $latestFeature = $_.Name
                }
            }
        }
        
        if ($latestFeature) {
            return $latestFeature
        }
    }
    
    # Final fallback
    return "main"
}

function Test-HasGit {
    try {
        git rev-parse --show-toplevel 2>$null | Out-Null
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

function Test-FeatureBranch {
    param(
        [string]$Branch,
        [bool]$HasGit = $true
    )
    
    # For non-git repos, we can't enforce branch naming but still provide output
    if (-not $HasGit) {
        Write-Warning "[specify] Warning: Git repository not detected; skipped branch validation"
        return $true
    }
    
    if ($Branch -notmatch '^[0-9]{3}-') {
        Write-Output "ERROR: Not on a feature branch. Current branch: $Branch"
        Write-Output "Feature branches should be named like: 001-feature-name"
        return $false
    }
    return $true
}

function Get-FeatureDir {
    param([string]$RepoRoot, [string]$Branch)
    Join-Path $RepoRoot "specs/$Branch"
}

function Get-FeaturePathsEnv {
    $repoRoot = Get-RepoRoot
    $currentBranch = Get-CurrentBranch
    $hasGit = Test-HasGit
    $featureDir = Get-FeatureDir -RepoRoot $repoRoot -Branch $currentBranch
    
    [PSCustomObject]@{
        REPO_ROOT     = $repoRoot
        CURRENT_BRANCH = $currentBranch
        HAS_GIT       = $hasGit
        FEATURE_DIR   = $featureDir
        FEATURE_SPEC  = Join-Path $featureDir 'spec.md'
        IMPL_PLAN     = Join-Path $featureDir 'plan.md'
        TASKS         = Join-Path $featureDir 'tasks.md'
        RESEARCH      = Join-Path $featureDir 'research.md'
        DATA_MODEL    = Join-Path $featureDir 'data-model.md'
        QUICKSTART    = Join-Path $featureDir 'quickstart.md'
        CONTRACTS_DIR = Join-Path $featureDir 'contracts'
    }
}

function Test-FileExists {
    param([string]$Path, [string]$Description)
    if (Test-Path -Path $Path -PathType Leaf) {
        Write-Output "  ✓ $Description"
        return $true
    } else {
        Write-Output "  ✗ $Description"
        return $false
    }
}

function Test-DirHasFiles {
    param([string]$Path, [string]$Description)
    if ((Test-Path -Path $Path -PathType Container) -and (Get-ChildItem -Path $Path -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer } | Select-Object -First 1)) {
        Write-Output "  ✓ $Description"
        return $true
    } else {
        Write-Output "  ✗ $Description"
        return $false
    }
}

# ============================================================================
# EXTENDED PATH FUNCTIONS FOR WORKSPACE
# ============================================================================

function Get-FeaturePathsEnvExtended {
    <#
    .SYNOPSIS
    Extended version that includes both project and studio paths
    #>
    param(
        [string]$ProjectRoot,
        [string]$StudioRoot
    )
    
    if (-not $ProjectRoot) {
        $ProjectRoot = Get-RepoRoot
    }
    if (-not $StudioRoot) {
        $StudioRoot = Find-StudioRoot -StartDir $ProjectRoot
    }
    
    $currentBranch = Get-CurrentBranch
    $hasGit = Test-HasGit
    $featureDir = Get-FeatureDir -RepoRoot $ProjectRoot -Branch $currentBranch
    $studioPaths = Get-StudioPaths -StudioRoot $StudioRoot
    $constitutions = Get-ConstitutionPaths -StudioRoot $StudioRoot -ProjectRoot $ProjectRoot
    
    [PSCustomObject]@{
        # Project paths
        PROJECT_ROOT   = $ProjectRoot
        CURRENT_BRANCH = $currentBranch
        HAS_GIT        = $hasGit
        FEATURE_DIR    = $featureDir
        FEATURE_SPEC   = Join-Path $featureDir 'spec.md'
        IMPL_PLAN      = Join-Path $featureDir 'plan.md'
        TASKS          = Join-Path $featureDir 'tasks.md'
        RESEARCH       = Join-Path $featureDir 'research.md'
        DATA_MODEL     = Join-Path $featureDir 'data-model.md'
        QUICKSTART     = Join-Path $featureDir 'quickstart.md'
        CONTRACTS_DIR  = Join-Path $featureDir 'contracts'
        # Studio paths
        STUDIO_ROOT    = $StudioRoot
        STUDIO_PATHS   = $studioPaths
        CONSTITUTIONS  = $constitutions
    }
}

