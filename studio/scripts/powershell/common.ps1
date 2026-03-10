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
- Runtime agents come from the workspace `.github/agents/` junction.
- Agent context files such as `.github/copilot-instructions.md` and `CLAUDE.md` are operational
  context only. They do not replace this constitution.

## Additive Rules

### Delivery Rules

- Follow the mandatory six-stage workflow: specify, clarify, plan, tasks, analyze, implement.
- Keep `tasks.md` in checklist-first format using `- [ ] T### [P#] [Risk: X] [Story: ...] Description`.
- Update `spec.md`, `plan.md`, and `tasks.md` together when approved scope changes.

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
        SHARED_PROMPTS_DIR         = Join-Path $workspaceRoot '.github/prompts'
        SHARED_SKILLS_DIR          = Join-Path $workspaceRoot '.github/skills'
        SHARED_SCRIPTS_DIR         = Join-Path $studioRoot 'scripts/powershell'
        SHARED_TEMPLATES_DIR       = Join-Path $studioRoot 'templates'
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
            $name = $token.TrimStart('-')
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
    if ($LASTEXITCODE -ne 0) {
        throw "Script failed: $ScriptPath"
    }

    if (-not $output) {
        return $null
    }

    return ($output -join [Environment]::NewLine) | ConvertFrom-Json -AsHashtable
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

    return [regex]::Matches($match.Matches[0].Groups[1].Value, "'([^']+)'") |
        ForEach-Object { $_.Groups[1].Value }
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
