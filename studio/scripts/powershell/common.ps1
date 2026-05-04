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
    $current = (Resolve-Path $StartDir).Path
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

function Find-ProjectRoot {
    <#
    .SYNOPSIS
    Find the current project root by looking for project markers
    #>
    param([string]$StartDir = (Get-Location))

    $current = (Resolve-Path $StartDir).Path
    while ($true) {
        if ((Test-Path (Join-Path $current '.specify')) -or (Test-Path (Join-Path $current 'specs'))) {
            return $current
        }
        $parent = Split-Path $current -Parent
        if ([string]::IsNullOrEmpty($parent) -or $parent -eq $current) {
            return $null
        }
        $current = $parent
    }
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
        PROJECT_CONST_TEMPLATE = Join-Path $StudioRoot "templates/sdd-docs/project-constitution-template.md"
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


function Initialize-ProjectConstitution {
    <#
    .SYNOPSIS
    Create a minimal project constitution stub if one does not already exist.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,
        [Parameter(Mandatory = $true)]
        [string]$ProjectName,
        [Parameter(Mandatory = $true)]
        [string]$ProjectType,
        [string]$StudioRoot,
        [string]$CreatedDate = (Get-Date -Format 'yyyy-MM-dd')
    )

    $constitutionPath = Join-Path $ProjectRoot '.specify/memory/constitution.md'
    if (Test-Path $constitutionPath) {
        return $constitutionPath
    }

    $constitutionDir = Split-Path -Parent $constitutionPath
    if (-not (Test-Path $constitutionDir)) {
        New-Item -ItemType Directory -Path $constitutionDir -Force | Out-Null
    }

    $classification = switch ($ProjectType) {
        'Practice' { 'Practice project for learning, experimentation, and skill-building.' }
        'Internal' { 'Internal studio project for tools, automation, or operational delivery.' }
        'Client' { 'Client project with external stakeholder expectations and review gates.' }
        default { 'Project-specific rules for this repository.' }
    }

    $content = @"
# Project Constitution: $ProjectName

**Version:** 1.0.0  
**Project Type:** $ProjectType  
**Created:** $CreatedDate

## Purpose

This constitution defines project-specific rules that add to the Studio Constitution at
`studio/constitution/constitution.md`.

## Project Context

- Classification: $classification
- Shared runtime agents are available through the workspace `.github/agents/` and `.claude/agents/` junctions.
- Agent context files such as `.github/copilot-instructions.md` and `CLAUDE.md` are operational
  context only. They do not replace this constitution.

## Additive Rules

### Delivery Rules

- Follow the mandatory seven-stage workflow: specify, clarify, readiness, plan, tasks, analyze, implement.
- Keep `tasks.md` in checklist-first format using `- [ ] T### [P#] [Risk: X] [Story: ...] Description`.
- Update `spec.md`, readiness artifacts, `plan.md`, and `tasks.md` together when approved scope changes.

### Documentation Rules

- Keep Markdown LLM-friendly: tables, lists, and plain-text descriptions.
- Use `contracts/` for Markdown service contracts or machine-readable schemas when needed.
- Record project-specific terminology, stricter testing rules, and delivery constraints here.

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | $CreatedDate | Initial project constitution stub |
"@

    Set-Content -LiteralPath $constitutionPath -Value $content -Encoding utf8
    return $constitutionPath
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
    if ($env:SDD_PROJECT_ROOT -and (Test-Path $env:SDD_PROJECT_ROOT)) {
        return (Resolve-Path $env:SDD_PROJECT_ROOT).Path
    }

    $projectRoot = Find-ProjectRoot -StartDir (Get-Location)
    if ($projectRoot) {
        return $projectRoot
    }

    try {
        $result = git rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -eq 0) {
            return $result
        }
    } catch {
        # Git command failed
    }
    
    # Fall back to workspace root when no project markers or git metadata exist
    return (Resolve-Path (Join-Path $PSScriptRoot "../../..")).Path
}

function Get-CurrentBranch {
    # First check if SPECIFY_FEATURE environment variable is set
    if ($env:SPECIFY_FEATURE) {
        return $env:SPECIFY_FEATURE
    }

    $projectRoot = Find-ProjectRoot -StartDir (Get-Location)

    # Only trust git branch information when the current project root matches the git root.
    try {
        $gitRoot = git rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -eq 0 -and $gitRoot) {
            $gitBranch = git rev-parse --abbrev-ref HEAD 2>$null
            if ($LASTEXITCODE -eq 0 -and $gitBranch) {
                $resolvedGitRoot = (Resolve-Path $gitRoot).Path
                $resolvedProjectRoot = if ($projectRoot) { (Resolve-Path $projectRoot).Path } else { $null }
                if (-not $resolvedProjectRoot -or $resolvedProjectRoot -eq $resolvedGitRoot) {
                    return $gitBranch
                }
            }
        }
    } catch {
        # Git command failed
    }
    
    # For non-git repos, try to find the latest feature directory
    $repoRoot = if ($projectRoot) { $projectRoot } else { Get-RepoRoot }
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
    $projectRoot = Find-ProjectRoot -StartDir (Get-Location)
    try {
        $gitRoot = git rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $gitRoot) {
            return $false
        }
        if (-not $projectRoot) {
            return $true
        }
        return ((Resolve-Path $gitRoot).Path -eq (Resolve-Path $projectRoot).Path)
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
    $readinessDir = Join-Path $featureDir 'readiness'
    $eciDir = Join-Path $readinessDir 'eci'
    
    [PSCustomObject]@{
        REPO_ROOT            = $repoRoot
        CURRENT_BRANCH       = $currentBranch
        HAS_GIT              = $hasGit
        FEATURE_DIR          = $featureDir
        FEATURE_SPEC         = Join-Path $featureDir 'spec.md'
        INTENT_LEDGER        = Join-Path $featureDir 'intent-ledger.md'
        READINESS_DIR        = $readinessDir
        READINESS_ASSESSMENT = Join-Path $readinessDir 'readiness-assessment.md'
        ECI_DIR              = $eciDir
        IMPL_PLAN            = Join-Path $featureDir 'plan.md'
        TASKS                = Join-Path $featureDir 'tasks.md'
        RESEARCH             = Join-Path $featureDir 'research.md'
        DATA_MODEL           = Join-Path $featureDir 'data-model.md'
        QUICKSTART           = Join-Path $featureDir 'quickstart.md'
        CONTRACTS_DIR        = Join-Path $featureDir 'contracts'
    }
}

function Test-FileExists {
    param([string]$Path, [string]$Description)
    if (Test-Path -Path $Path -PathType Leaf) {
        Write-Output "  [OK]   $Description"
        return $true
    } else {
        Write-Output "  [MISS] $Description"
        return $false
    }
}

function Test-DirHasFiles {
    param([string]$Path, [string]$Description)
    if ((Test-Path -Path $Path -PathType Container) -and (Get-ChildItem -Path $Path -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer } | Select-Object -First 1)) {
        Write-Output "  [OK]   $Description"
        return $true
    } else {
        Write-Output "  [MISS] $Description"
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
    $readinessDir = Join-Path $featureDir 'readiness'
    $eciDir = Join-Path $readinessDir 'eci'
    $studioPaths = Get-StudioPaths -StudioRoot $StudioRoot
    $constitutions = Get-ConstitutionPaths -StudioRoot $StudioRoot -ProjectRoot $ProjectRoot
    
    [PSCustomObject]@{
        # Project paths
        PROJECT_ROOT        = $ProjectRoot
        CURRENT_BRANCH      = $currentBranch
        HAS_GIT             = $hasGit
        FEATURE_DIR         = $featureDir
        FEATURE_SPEC        = Join-Path $featureDir 'spec.md'
        INTENT_LEDGER       = Join-Path $featureDir 'intent-ledger.md'
        READINESS_DIR       = $readinessDir
        READINESS_ASSESSMENT = Join-Path $readinessDir 'readiness-assessment.md'
        ECI_DIR             = $eciDir
        IMPL_PLAN           = Join-Path $featureDir 'plan.md'
        TASKS               = Join-Path $featureDir 'tasks.md'
        RESEARCH            = Join-Path $featureDir 'research.md'
        DATA_MODEL          = Join-Path $featureDir 'data-model.md'
        QUICKSTART          = Join-Path $featureDir 'quickstart.md'
        CONTRACTS_DIR       = Join-Path $featureDir 'contracts'
        # Studio paths
        STUDIO_ROOT         = $StudioRoot
        STUDIO_PATHS        = $studioPaths
        CONSTITUTIONS       = $constitutions
    }
}



function Resolve-AbsolutePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [string]$BaseDir = (Get-Location).Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw 'Path cannot be empty.'
    }

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $BaseDir $Path))
}

function Get-IsoTimestamp {
    return (Get-Date).ToString('o')
}

function Read-JsonFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable
}

function Write-JsonFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [object]$Data,
        [int]$Depth = 10
    )

    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    ([PSCustomObject]$Data | ConvertTo-Json -Depth $Depth) | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Test-DirectoryHasEntries {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }

    return [bool](Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue | Select-Object -First 1)
}

function Ensure-DirectoryEmpty {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [switch]$Force
    )

    if (Test-Path -LiteralPath $Path) {
        if ((Test-DirectoryHasEntries -Path $Path) -and -not $Force) {
            throw "Directory is not empty: $Path. Use -Force to overwrite."
        }

        if ($Force) {
            Get-ChildItem -LiteralPath $Path -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
        }
    } else {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Reset-Directory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Recurse -Force
    }

    New-Item -ItemType Directory -Path $Path -Force | Out-Null
}

function Test-PathInsideRoot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,
        [Parameter(Mandatory = $true)]
        [string]$Candidate
    )

    $resolvedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    $resolvedCandidate = [System.IO.Path]::GetFullPath($Candidate)
    return $resolvedCandidate.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)
}

function Assert-PathInsideRoot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,
        [Parameter(Mandatory = $true)]
        [string]$Candidate,
        [string]$MessagePrefix = 'Resolved path escapes the allowed root'
    )

    if (-not (Test-PathInsideRoot -Root $Root -Candidate $Candidate)) {
        throw "${MessagePrefix}: $Candidate (root: $Root)"
    }
}

function Resolve-RelativePathInsideRoot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,
        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )

    if ([string]::IsNullOrWhiteSpace($RelativePath)) {
        throw 'Relative path cannot be empty.'
    }

    if ([System.IO.Path]::IsPathRooted($RelativePath)) {
        throw "Path must be relative: $RelativePath"
    }

    $candidate = [System.IO.Path]::GetFullPath((Join-Path $Root $RelativePath))
    Assert-PathInsideRoot -Root $Root -Candidate $candidate -MessagePrefix 'Relative path escapes root'
    return $candidate
}

function Copy-DirectoryContents {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,
        [Parameter(Mandatory = $true)]
        [string]$Destination
    )

    if (-not (Test-Path -LiteralPath $Source)) {
        throw "Source directory not found: $Source"
    }

    New-Item -ItemType Directory -Path $Destination -Force | Out-Null

    Get-ChildItem -LiteralPath $Source -Recurse -File | ForEach-Object {
        $relativePath = [System.IO.Path]::GetRelativePath($Source, $_.FullName)
        $targetPath = Join-Path $Destination $relativePath
        $targetParent = Split-Path -Parent $targetPath
        if (-not (Test-Path -LiteralPath $targetParent)) {
            New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
        }
        Copy-Item -LiteralPath $_.FullName -Destination $targetPath -Force
    }
}

function Get-NormalizedLinkTarget {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileSystemInfo]$Item
    )

    if (-not ($Item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
        return $null
    }

    $rawTarget = $Item.Target
    if ($rawTarget -is [System.Array]) {
        $rawTarget = $rawTarget | Select-Object -First 1
    }

    if ([string]::IsNullOrWhiteSpace([string]$rawTarget)) {
        return $null
    }

    return Resolve-AbsolutePath -Path ([string]$rawTarget) -BaseDir (Split-Path -Parent $Item.FullName)
}

function Ensure-DirectoryJunction {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Target,
        [switch]$Force
    )

    $resolvedPath = Resolve-AbsolutePath -Path $Path
    $resolvedTarget = Resolve-AbsolutePath -Path $Target

    if (-not (Test-Path -LiteralPath $resolvedTarget -PathType Container)) {
        return [ordered]@{
            path      = $resolvedPath
            target    = $resolvedTarget
            available = $false
            created   = $false
            status    = 'missing-target'
        }
    }

    $parentDir = Split-Path -Parent $resolvedPath
    if ($parentDir -and -not (Test-Path -LiteralPath $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }

    if (Test-Path -LiteralPath $resolvedPath) {
        $existingItem = Get-Item -LiteralPath $resolvedPath -Force
        $existingTarget = Get-NormalizedLinkTarget -Item $existingItem

        if ($existingItem.LinkType -eq 'Junction' -and $existingTarget -eq $resolvedTarget) {
            return [ordered]@{
                path      = $resolvedPath
                target    = $resolvedTarget
                available = $true
                created   = $false
                status    = 'unchanged'
            }
        }

        if (-not $Force) {
            throw "Path already exists and is not the requested junction: $resolvedPath"
        }

        if ($existingItem.LinkType -eq 'Junction') {
            Remove-Item -LiteralPath $resolvedPath -Force
        } else {
            Remove-Item -LiteralPath $resolvedPath -Recurse -Force
        }
    }

    New-Item -ItemType Junction -Path $resolvedPath -Target $resolvedTarget -Force | Out-Null

    return [ordered]@{
        path      = $resolvedPath
        target    = $resolvedTarget
        available = $true
        created   = $true
        status    = 'created'
    }
}

function Initialize-ProjectSharedAgentJunctions {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,
        [Parameter(Mandatory = $true)]
        [string]$WorkspaceRoot,
        [switch]$Force
    )

    $projectRootPath = Resolve-AbsolutePath -Path $ProjectRoot
    $workspaceRootPath = Resolve-AbsolutePath -Path $WorkspaceRoot
    $junctionRequests = @(
        [ordered]@{
            agentType = 'copilot'
            path      = Join-Path $projectRootPath '.github/agents'
            target    = Join-Path $workspaceRootPath '.github/agents'
        },
        [ordered]@{
            agentType = 'claude'
            path      = Join-Path $projectRootPath '.claude/agents'
            target    = Join-Path $workspaceRootPath '.claude/agents'
        }
    )

    $results = @()
    foreach ($request in $junctionRequests) {
        $junctionResult = Ensure-DirectoryJunction -Path $request.path -Target $request.target -Force:$Force
        $results += [ordered]@{
            agentType = $request.agentType
            path      = $junctionResult.path
            target    = $junctionResult.target
            available = $junctionResult.available
            created   = $junctionResult.created
            status    = $junctionResult.status
        }
    }

    return $results
}

function Initialize-ProjectGitRepository {
    <#
    .SYNOPSIS
    Initialize a consumer project as an independent Git repository and attach workspace hooks.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,
        [Parameter(Mandatory = $true)]
        [string]$WorkspaceRoot,
        [string]$InitialBranch = 'main'
    )

    $projectRootPath = Resolve-AbsolutePath -Path $ProjectRoot
    $workspaceRootPath = Resolve-AbsolutePath -Path $WorkspaceRoot
    $hooksDir = Join-Path $workspaceRootPath '.githooks'

    if (-not (Test-Path -LiteralPath $hooksDir -PathType Container)) {
        throw "Workspace hooks directory not found: $hooksDir"
    }

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw 'Git is required to initialize consumer projects.'
    }

    $gitMetadataPath = Join-Path $projectRootPath '.git'
    $initialized = $false
    if (-not (Test-Path -LiteralPath $gitMetadataPath)) {
        & git init -b $InitialBranch $projectRootPath | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "git init failed for project: $projectRootPath"
        }
        $initialized = $true
    }

    $hooksPath = [System.IO.Path]::GetRelativePath($projectRootPath, $hooksDir) -replace '\\', '/'
    & git -C $projectRootPath config core.hooksPath $hooksPath
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to configure core.hooksPath for project: $projectRootPath"
    }

    return [ordered]@{
        projectRoot = $projectRootPath
        initialized = $initialized
        hooksPath   = $hooksPath
    }
}

# ============================================================================
# Markdown field parsing (unified helper - M4)
# ============================================================================

function Get-MarkdownField {
    <#
    .SYNOPSIS
    Extract a Markdown bold-key field value (`**Field:** value`) from content or a file.

    .DESCRIPTION
    Unified replacement for the previously duplicated Get-MarkdownFieldValue / Get-MarkdownField
    helpers across pre-commit.ps1, setup-plan.ps1, and get-speckit-version.ps1. Supports:
    - Plain text:        `**Field:** value`
    - Backtick wrapped:  `**Field:** ` + "`" + `value` + "`"
    - List item prefix:  `- **Field:** value`
    - Quoted value:      `**Field:** "value"`

    Pass either -Content (raw string) or -Path (read from file). Returns $null when the
    field is absent or the file does not exist.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Content')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Content')]
        [AllowEmptyString()]
        [string]$Content,
        [Parameter(Mandatory = $true, ParameterSetName = 'Path')]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Field
    )

    if ($PSCmdlet.ParameterSetName -eq 'Path') {
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
            return $null
        }
        $Content = Get-Content -LiteralPath $Path -Raw
    }

    if ([string]::IsNullOrWhiteSpace($Content)) {
        return $null
    }

    $escapedField = [regex]::Escape($Field)
    # Support both "**Field:**" (colon inside) used by constitution.md /
    # WORKSPACE_STRUCTURE.md, and "**Field**:" (colon outside) used by
    # readiness-assessment.md and friends.
    $pattern = "(?mi)^\s*(?:-\s*)?\*\*$escapedField(?::\*\*|\*\*:)\s*(.+?)\s*$"
    if ($Content -notmatch $pattern) {
        return $null
    }

    $value = $Matches[1].Trim()

    if ($value -match '^`(.+)`$') {
        $value = $Matches[1]
    } elseif ($value -match '^"(.+)"$') {
        $value = $Matches[1]
    }

    return $value
}

# ============================================================================
# Project init helpers (M3, M3', M20, M21)
# ============================================================================

function New-CodeWorkspaceContent {
    <#
    .SYNOPSIS
    Build the JSON content for a project's <name>.code-workspace multi-root file.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectName,
        [string]$StudioRelativePath = '../../studio',
        [string]$AgentsRelativePath = '../../.github/agents',
        [string]$ClaudeAgentsRelativePath = '../../.claude/agents'
    )

    $workspace = [ordered]@{
        folders  = @(
            [ordered]@{ name = $ProjectName;                path = '.' },
            [ordered]@{ name = 'studio (read-only)';        path = $StudioRelativePath },
            [ordered]@{ name = 'agents (read-only)';        path = $AgentsRelativePath },
            [ordered]@{ name = 'claude agents (read-only)'; path = $ClaudeAgentsRelativePath }
        )
        settings = [ordered]@{
            'files.readonlyInclude' = [ordered]@{
                '**/studio/**'         = $true
                '**/.github/agents/**' = $true
                '**/.claude/agents/**' = $true
            }
        }
    }

    return ($workspace | ConvertTo-Json -Depth 4)
}

function Get-RetrospectiveContent {
    <#
    .SYNOPSIS
    Build the retrospective.md scaffold content for an Internal/Client project.
    Sources from studio/templates/sdd-docs/retrospective-template.md when available;
    falls back to inline scaffold for backward compatibility.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectName,
        [Parameter(Mandatory = $true)]
        [ValidateSet('Internal', 'Client')]
        [string]$ProjectType,
        [string]$StudioRoot,
        [string]$CreatedDate = (Get-Date -Format 'yyyy-MM-dd')
    )

    if ($StudioRoot) {
        $templatePath = Join-Path $StudioRoot 'templates/sdd-docs/retrospective-template.md'
        if (Test-Path -LiteralPath $templatePath) {
            $template = Get-Content -LiteralPath $templatePath -Raw
            $template = $template -replace '\[PROJECT_NAME\]', $ProjectName
            $template = $template -replace '\[PROJECT_TYPE\]', $ProjectType
            $template = $template -replace '\[CREATED_DATE\]', $CreatedDate
            return $template
        }
    }

    return @"
# Retrospective: $ProjectName

**Project Type:** $ProjectType
**Created:** $CreatedDate
**Completed:** [TBD]

## What went well?

-

## What was painful?

-

## What would I do differently?

-

## Time estimate vs actual

| Phase | Estimated | Actual | Notes |
|-------|-----------|--------|-------|
| Specify | | | |
| Clarify | | | |
| Plan | | | |
| Tasks | | | |
| Implement | | | |
| **Total** | | | |

## Key Learnings

> Extract significant learnings to ``studio/knowledge-base/learnings.md``

-
"@
}

function Initialize-ProjectFromTemplate {
    <#
    .SYNOPSIS
    Copy the project-init template into a target directory and apply the standard
    SDD workspace scaffold (README rewrite, project constitution, agent bootstrap,
    code-workspace file, retrospective for Internal/Client, agent junctions, git init).

    .DESCRIPTION
    This is the unified replacement for the ~80 lines of duplicated logic between
    init-project.ps1 (Internal/Client) and init-practice.ps1 (Practice). All file
    operations honor -WhatIf via SupportsShouldProcess, and Copy-Item excludes any
    stray .git metadata from the template directory.

    .PARAMETER Name
    Project name (used in README, code-workspace, retrospective heading).

    .PARAMETER TargetDir
    Absolute path where the new project root will be created.

    .PARAMETER Type
    Project classification: Practice / Internal / Client.

    .PARAMETER TemplateDir
    Source template directory (typically `studio/templates/project-init`).

    .PARAMETER StudioRoot
    Absolute path to the studio/ directory (for bootstrap script discovery and templates).

    .PARAMETER WorkspaceRoot
    Absolute path to the workspace root (for shared agent junction targets and hooks).

    .PARAMETER Description
    Optional README description; defaulted by Type if empty.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$TargetDir,
        [Parameter(Mandatory = $true)]
        [ValidateSet('Practice', 'Internal', 'Client')]
        [string]$Type,
        [Parameter(Mandatory = $true)]
        [string]$TemplateDir,
        [Parameter(Mandatory = $true)]
        [string]$StudioRoot,
        [Parameter(Mandatory = $true)]
        [string]$WorkspaceRoot,
        [string]$Description
    )

    if (-not $Description) {
        $Description = switch ($Type) {
            'Practice' { 'A Practice project for learning and experimentation.' }
            'Internal' { 'An Internal project for studio tools and automation.' }
            'Client'   { 'A Client project.' }
        }
    }

    if (-not (Test-Path -LiteralPath $TemplateDir -PathType Container)) {
        throw "Project template not found at: $TemplateDir"
    }

    if (Test-Path -LiteralPath $TargetDir) {
        throw "Project already exists at: $TargetDir"
    }

    $createdDate = Get-Date -Format 'yyyy-MM-dd'
    $createdAny = $false

    if ($PSCmdlet.ShouldProcess($TargetDir, "Copy project-init template (excluding .git/.gitkeep transients)")) {
        Copy-Item -Path $TemplateDir -Destination $TargetDir -Recurse -Force -Exclude '.git'
        $strayGit = Join-Path $TargetDir '.git'
        if (Test-Path -LiteralPath $strayGit) {
            Remove-Item -LiteralPath $strayGit -Recurse -Force
        }
        $createdAny = $true
    }

    $readmePath = Join-Path $TargetDir 'README.md'
    if ((Test-Path -LiteralPath $readmePath) -and $PSCmdlet.ShouldProcess($readmePath, 'Substitute README placeholders')) {
        $readmeContent = Get-Content -LiteralPath $readmePath -Raw
        $readmeContent = $readmeContent -replace '\[PROJECT_NAME\]', $Name
        $readmeContent = $readmeContent -replace '\[PROJECT_TYPE\]', $Type
        $readmeContent = $readmeContent -replace '\[PROJECT_DESCRIPTION\]', $Description
        $readmeContent = $readmeContent -replace '\[CREATED_DATE\]', $createdDate
        Set-Content -LiteralPath $readmePath -Value $readmeContent -NoNewline
    }

    $projectConstPath = $null
    if ($PSCmdlet.ShouldProcess((Join-Path $TargetDir '.specify/memory/constitution.md'), 'Initialize project constitution')) {
        $projectConstPath = Initialize-ProjectConstitution -ProjectRoot $TargetDir -ProjectName $Name -ProjectType $Type -StudioRoot $StudioRoot -CreatedDate $createdDate
    }

    if ($PSCmdlet.ShouldProcess($TargetDir, 'Generate runtime agent bootstrap (AGENTS.md, CLAUDE.md, copilot-instructions)')) {
        $bootstrapScript = Join-Path $StudioRoot 'scripts/powershell/sync-agent-bootstrap.ps1'
        & $bootstrapScript -ProjectRoot $TargetDir -ProjectName $Name -ProjectType $Type -ProjectDescription $Description -Write | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Agent bootstrap generation failed for $TargetDir"
        }
    }

    if ($Type -in 'Internal', 'Client') {
        $retroPath = Join-Path $TargetDir 'retrospective.md'
        if ($PSCmdlet.ShouldProcess($retroPath, 'Scaffold retrospective.md')) {
            $retroContent = Get-RetrospectiveContent -ProjectName $Name -ProjectType $Type -StudioRoot $StudioRoot -CreatedDate $createdDate
            Set-Content -LiteralPath $retroPath -Value $retroContent -NoNewline
        }
    }

    $workspaceFile = Join-Path $TargetDir "$Name.code-workspace"
    if ($PSCmdlet.ShouldProcess($workspaceFile, 'Write multi-root code-workspace JSON')) {
        $workspaceContent = New-CodeWorkspaceContent -ProjectName $Name
        Set-Content -LiteralPath $workspaceFile -Value $workspaceContent -Encoding UTF8
    }

    $junctionResults = @()
    if ($PSCmdlet.ShouldProcess($TargetDir, 'Create shared agent junctions for Copilot and Claude')) {
        $junctionResults = @(Initialize-ProjectSharedAgentJunctions -ProjectRoot $TargetDir -WorkspaceRoot $WorkspaceRoot)
    }

    $gitInit = $null
    if ($PSCmdlet.ShouldProcess($TargetDir, 'Initialize independent Git repository and configure hooksPath')) {
        $gitInit = Initialize-ProjectGitRepository -ProjectRoot $TargetDir -WorkspaceRoot $WorkspaceRoot
    }

    if ((Test-Path -LiteralPath $TargetDir) -and $PSCmdlet.ShouldProcess($TargetDir, 'Cleanup .gitkeep markers in non-empty directories')) {
        Get-ChildItem -Path $TargetDir -Recurse -Filter '.gitkeep' -ErrorAction SilentlyContinue | ForEach-Object {
            $parentDir = $_.DirectoryName
            $siblingCount = @(Get-ChildItem -Path $parentDir -Exclude '.gitkeep').Count
            if ($siblingCount -gt 0) {
                Remove-Item -LiteralPath $_.FullName -Force
            }
        }
    }

    return [ordered]@{
        targetDir            = $TargetDir
        type                 = $Type
        projectConstitution  = $projectConstPath
        codeWorkspaceFile    = $workspaceFile
        junctions            = $junctionResults
        gitRepository        = $gitInit
        createdDate          = $createdDate
        anyChange            = $createdAny -or $WhatIfPreference -eq $false
    }
}

function Get-StudioSharedLayerPaths {
    param(
        [string]$StartDir = (Get-Location)
    )

    $studioRoot = Find-StudioRoot -StartDir $StartDir
    $workspaceRoot = Find-WorkspaceRoot -StartDir $StartDir

    if (-not $studioRoot -or -not $workspaceRoot) {
        throw 'Unable to resolve studio/workspace roots.'
    }

    $extensionsRoot = Join-Path $studioRoot 'extensions'
    $runtimeRoot = Join-Path $workspaceRoot 'resources/studio-runtime'

    return [ordered]@{
        STUDIO_ROOT                = $studioRoot
        WORKSPACE_ROOT             = $workspaceRoot
        EXTENSIONS_ROOT            = $extensionsRoot
        EXTENSIONS_POLICY_PATH     = Join-Path $extensionsRoot 'POLICY.md'
        EXTENSIONS_CATALOG_PATH    = Join-Path $extensionsRoot 'catalog.json'
        EXTENSIONS_CATALOG_SCHEMA  = Join-Path $extensionsRoot 'catalog.schema.json'
        EXTENSIONS_STATE_PATH      = Join-Path $extensionsRoot 'state.json'
        EXTENSIONS_STATE_SCHEMA    = Join-Path $extensionsRoot 'state.schema.json'
        EXTENSIONS_MANIFEST_SCHEMA = Join-Path $extensionsRoot 'manifest.schema.json'
        EXTENSIONS_VALIDATOR_PATH  = Join-Path $studioRoot 'scripts/powershell/validate-extension-registry.ps1'
        SHARED_AGENTS_DIR          = Join-Path $workspaceRoot '.github/agents'
        SHARED_CLAUDE_AGENTS_DIR   = Join-Path $workspaceRoot '.claude/agents'
        SHARED_PROMPTS_DIR         = Join-Path $workspaceRoot '.github/prompts'
        SHARED_SKILLS_DIR          = Join-Path $workspaceRoot '.github/skills'
        SHARED_SCRIPTS_DIR         = Join-Path $studioRoot 'scripts/powershell'
        SHARED_TEMPLATES_DIR       = Join-Path $studioRoot 'templates'
        SHARED_RUNTIME_CONTRACT    = Join-Path $studioRoot 'runtime/shared-runtime-contract.json'
        RUNTIME_ROOT               = $runtimeRoot
        RUNTIME_MIRROR_ROOT        = Join-Path $runtimeRoot 'merged'
        SKILL_PACKS_ROOT           = Join-Path $workspaceRoot 'resources/agent-skill-packs'
        SYNC_MAP_PATH              = Join-Path $studioRoot 'upstream/shared-layer-map.json'
    }
}

function Get-ExtensionRuntimeScopes {
    return @('agents', 'prompts', 'scripts', 'templates', 'docs')
}

function Get-ExtensionRegistryReviewStatuses {
    return @('draft', 'approved', 'experimental', 'deprecated', 'rejected')
}

function Get-ExtensionRegistryTrustLevels {
    return @('core', 'curated', 'experimental')
}

function Get-ExtensionStateSources {
    return @('default', 'manual', 'sync')
}

function Invoke-JsonScript {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,
        [string[]]$Arguments = @()
    )

    $namedParameters = @{}
    $positionalArguments = @()

    for ($i = 0; $i -lt $Arguments.Count; $i++) {
        $token = [string]$Arguments[$i]
        if ($token.StartsWith('-')) {
            $name = $token -replace '^-{1,2}', ''
            if (($i + 1) -lt $Arguments.Count -and -not ([string]$Arguments[$i + 1]).StartsWith('-')) {
                $namedParameters[$name] = $Arguments[$i + 1]
                $i++
            } else {
                $namedParameters[$name] = $true
            }
        } else {
            $positionalArguments += $token
        }
    }

    $output = if ($positionalArguments.Count -gt 0) {
        & $ScriptPath @namedParameters @positionalArguments
    } else {
        & $ScriptPath @namedParameters
    }
    if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw "Script failed: $ScriptPath"
    }

    if (-not $output) {
        return $null
    }

    return ($output -join [Environment]::NewLine) | ConvertFrom-Json -AsHashtable
}

function Invoke-JsonScriptDetailed {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,
        [string[]]$Arguments = @()
    )

    $namedParameters = @{}
    $positionalArguments = @()

    for ($i = 0; $i -lt $Arguments.Count; $i++) {
        $token = [string]$Arguments[$i]
        if ($token.StartsWith('-')) {
            $name = $token -replace '^-{1,2}', ''
            if (($i + 1) -lt $Arguments.Count -and -not ([string]$Arguments[$i + 1]).StartsWith('-')) {
                $namedParameters[$name] = $Arguments[$i + 1]
                $i++
            } else {
                $namedParameters[$name] = $true
            }
        } else {
            $positionalArguments += $token
        }
    }

    $output = if ($positionalArguments.Count -gt 0) {
        & $ScriptPath @namedParameters @positionalArguments
    } else {
        & $ScriptPath @namedParameters
    }

    $exitCode = if ($null -ne $LASTEXITCODE) { [int]$LASTEXITCODE } else { 0 }
    $rawOutput = if ($output) { $output -join [Environment]::NewLine } else { $null }
    $parsedOutput = $null

    if (-not [string]::IsNullOrWhiteSpace($rawOutput)) {
        try {
            $parsedOutput = $rawOutput | ConvertFrom-Json -AsHashtable
        } catch {
            $parsedOutput = $null
        }
    }

    return [ordered]@{
        EXIT_CODE = $exitCode
        RAW       = $rawOutput
        OUTPUT    = $parsedOutput
    }
}

function Get-ExtensionAwareRuntimeSources {
    param(
        [string]$StartDir = (Get-Location)
    )

    $paths = Get-StudioSharedLayerPaths -StartDir $StartDir
    $mirrorManifest = Join-Path $paths.RUNTIME_MIRROR_ROOT 'manifest.json'

    if (Test-Path -LiteralPath $mirrorManifest) {
        return [ordered]@{
            MODE          = 'merged'
            ROOT          = $paths.RUNTIME_MIRROR_ROOT
            MANIFEST_PATH = $mirrorManifest
            AGENTS_DIR    = Join-Path $paths.RUNTIME_MIRROR_ROOT 'agents'
            PROMPTS_DIR   = Join-Path $paths.RUNTIME_MIRROR_ROOT 'prompts'
            SCRIPTS_DIR   = Join-Path $paths.RUNTIME_MIRROR_ROOT 'scripts'
            TEMPLATES_DIR = Join-Path $paths.RUNTIME_MIRROR_ROOT 'templates'
            DOCS_DIR      = Join-Path $paths.RUNTIME_MIRROR_ROOT 'docs'
        }
    }

    return [ordered]@{
        MODE          = 'core'
        ROOT          = $paths.WORKSPACE_ROOT
        MANIFEST_PATH = $null
        AGENTS_DIR    = $paths.SHARED_AGENTS_DIR
        PROMPTS_DIR   = $paths.SHARED_PROMPTS_DIR
        SCRIPTS_DIR   = $paths.SHARED_SCRIPTS_DIR
        TEMPLATES_DIR = $paths.SHARED_TEMPLATES_DIR
        DOCS_DIR      = $null
    }
}

function Get-SupportedAgentContexts {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return @()
    }

    $match = Select-String -Path $Path -Pattern "\[ValidateSet\((.+)\)\]" | Select-Object -First 1
    if (-not $match) {
        return @()
    }

    return [regex]::Matches($match.Matches[0].Groups[1].Value, "(['""])([^'""]+)\1") |
        ForEach-Object { $_.Groups[2].Value }
}

function Get-SkillInstallTargets {
    return [ordered]@{
        codex = [ordered]@{
            envVar        = 'CODEX_HOME'
            fallbackRoot  = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.codex'
            skillsSubpath = 'skills'
        }
        claude = [ordered]@{
            envVar        = 'CLAUDE_HOME'
            fallbackRoot  = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.claude'
            skillsSubpath = 'skills'
        }
    }
}

function Resolve-SkillInstallRoot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Target,
        [string]$InstallRoot
    )

    $targets = Get-SkillInstallTargets
    if (-not $targets.Contains($Target)) {
        throw "Unsupported skill install target: $Target"
    }

    $targetConfig = $targets[$Target]
    $resolvedRoot = $null
    $resolution = $null

    if ($InstallRoot) {
        $resolvedRoot = Resolve-AbsolutePath -Path $InstallRoot
        $resolution = 'explicit'
    } else {
        $envVar = $targetConfig.envVar
        if ($envVar -and (Get-Item -Path "Env:$envVar" -ErrorAction SilentlyContinue)) {
            $resolvedRoot = Resolve-AbsolutePath -Path (Get-Item -Path "Env:$envVar").Value
            $resolution = "env:$envVar"
        } elseif ($targetConfig.fallbackRoot) {
            $resolvedRoot = Resolve-AbsolutePath -Path $targetConfig.fallbackRoot
            $resolution = 'fallback'
        }
    }

    if (-not $resolvedRoot) {
        throw "Unable to resolve install root for target '$Target'."
    }

    return [ordered]@{
        target      = $Target
        resolution  = $resolution
        installRoot = if ($resolution -eq 'explicit') { $resolvedRoot } else { Join-Path $resolvedRoot $targetConfig.skillsSubpath }
    }
}

function Get-ManagedSkillsNamespace {
    return 'studio-first-speckit'
}

function Get-ManagedSkillsPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SkillsRoot
    )

    return Join-Path $SkillsRoot (Get-ManagedSkillsNamespace)
}
