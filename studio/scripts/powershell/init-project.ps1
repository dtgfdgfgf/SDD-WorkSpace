<#
.SYNOPSIS
    Initialize a new Internal or Client project in the projects/ directory.

.DESCRIPTION
    Creates a new project by copying the project-init template to projects/<name>/.
    Supports Internal (studio tools, automation) and Client (paid work) project types.

.PARAMETER Name
    The name of the project (will become the directory name).

.PARAMETER Type
    Project type: Internal or Client.
    - Internal: Studio tools, automation, personal projects
    - Client: Paid client work (future)

.PARAMETER Description
    Optional description for the project README.

.EXAMPLE
    .\init-project.ps1 -Name "studio-automation" -Type Internal
    .\init-project.ps1 -Name "2025-client-c" -Type Client -Description "E-commerce platform for Client C"

.NOTES
    Target Directory: projects/<name>/
    SDD Rigor: Full SDD flow (+ client review gates for Client type)
    Knowledge Capture: retrospective.md required
#>

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidatePattern('^[a-z0-9][a-z0-9-]*[a-z0-9]$|^[a-z0-9]$')]
    [string]$Name,

    [Parameter(Mandatory = $true)]
    [ValidateSet('Internal', 'Client')]
    [string]$Type,

    [Parameter(Mandatory = $false)]
    [string]$Description = ""
)

# Import common functions
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir 'common.ps1')

# Find workspace and studio roots
$workspaceRoot = Find-WorkspaceRoot
$studioRoot = Find-StudioRoot -StartDir $scriptDir

if (-not $workspaceRoot) {
    Write-Error "Cannot find workspace root (directory containing 'studio/' folder)"
    exit 1
}

# Define paths
$templateDir = Join-Path $studioRoot 'templates/project-init'
$targetDir = Join-Path $workspaceRoot "projects/$Name"

# Validate template exists
if (-not (Test-Path $templateDir)) {
    Write-Error "Project template not found at: $templateDir"
    Write-Host "Please ensure studio/templates/project-init/ exists."
    exit 1
}

# Check if target already exists
if (Test-Path $targetDir) {
    Write-Error "Project already exists at: $targetDir"
    Write-Host "Choose a different name or remove the existing directory."
    exit 1
}

# Set description based on type if not provided
if (-not $Description) {
    $Description = switch ($Type) {
        'Internal' { "An Internal project for studio tools and automation." }
        'Client' { "A Client project." }
    }
}

# Create target directory and copy template
Write-Host "Creating $Type project: $Name" -ForegroundColor Cyan
Write-Host "Target: $targetDir" -ForegroundColor Gray

try {
    # Copy template to target
    Copy-Item -Path $templateDir -Destination $targetDir -Recurse -Force

    # Update README.md with project info
    $readmePath = Join-Path $targetDir 'README.md'
    if (Test-Path $readmePath) {
        $readmeContent = Get-Content $readmePath -Raw
        $readmeContent = $readmeContent -replace '\[PROJECT_NAME\]', $Name
        $readmeContent = $readmeContent -replace '\[PROJECT_TYPE\]', $Type
        $readmeContent = $readmeContent -replace '\[PROJECT_DESCRIPTION\]', $Description
        $readmeContent = $readmeContent -replace '\[CREATED_DATE\]', (Get-Date -Format 'yyyy-MM-dd')
        Set-Content -Path $readmePath -Value $readmeContent -NoNewline
    }

    # Create retrospective.md template for Internal/Client projects
    $retroPath = Join-Path $targetDir 'retrospective.md'
    $retroContent = @"
# Retrospective: $Name

**Project Type:** $Type  
**Created:** $(Get-Date -Format 'yyyy-MM-dd')  
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
    Set-Content -Path $retroPath -Value $retroContent -NoNewline

    # Create .code-workspace file for multi-root workspace support
    $workspaceFile = Join-Path $targetDir "$Name.code-workspace"
    $workspaceContent = @{
        folders  = @(
            @{
                name = $Name
                path = "."
            },
            @{
                name = "studio (read-only)"
                path = "../../studio"
            },
            @{
                name = "agents (read-only)"
                path = "../../.github/agents"
            }
        )
        settings = @{
            "files.readonlyInclude" = @{
                "**/studio/**"         = $true
                "**/.github/agents/**" = $true
            }
        }
    } | ConvertTo-Json -Depth 4
    Set-Content -Path $workspaceFile -Value $workspaceContent -Encoding UTF8

    # Create .github/agents Junction for VS Code agent discovery
    $githubDir = Join-Path $targetDir '.github'
    $agentsJunction = Join-Path $githubDir 'agents'
    $agentsSource = Join-Path $workspaceRoot '.github/agents'
    
    if (-not (Test-Path $githubDir)) {
        New-Item -ItemType Directory -Path $githubDir -Force | Out-Null
    }
    
    if (Test-Path $agentsSource) {
        # Create Junction (directory symbolic link) to workspace agents
        New-Item -ItemType Junction -Path $agentsJunction -Target $agentsSource -Force | Out-Null
        Write-Host "Created agents junction: .github/agents -> $agentsSource" -ForegroundColor Gray
    }
    else {
        Write-Warning "Agents source not found at: $agentsSource - skipping junction creation"
    }

    # Remove .gitkeep files if directories have content
    Get-ChildItem -Path $targetDir -Recurse -Filter '.gitkeep' | ForEach-Object {
        $parentDir = $_.DirectoryName
        $siblingCount = (Get-ChildItem -Path $parentDir -Exclude '.gitkeep').Count
        if ($siblingCount -gt 0) {
            Remove-Item $_.FullName -Force
        }
    }

    Write-Host ""
    Write-Host "✓ $Type project created successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Open project with multi-root workspace:"
    Write-Host "     code projects/$Name/$Name.code-workspace" -ForegroundColor White
    Write-Host "  2. Start SDD workflow with: /speckit.specify <your feature description>"
    Write-Host ""
    Write-Host "Project Type: $Type" -ForegroundColor Cyan
    Write-Host "Workspace File: $Name.code-workspace (includes studio & agents as read-only)" -ForegroundColor Cyan
    Write-Host "Knowledge Capture: retrospective.md (required) + learnings.md (if applicable)"
    Write-Host ""

    if ($Type -eq 'Client') {
        Write-Host "⚠ Client Project Reminder:" -ForegroundColor Yellow
        Write-Host "  - Add client review gates at each SDD stage"
        Write-Host "  - Document client-specific requirements in .specify/memory/constitution.md"
        Write-Host ""
    }

}
catch {
    Write-Error "Failed to create project: $_"
    # Cleanup on failure
    if (Test-Path $targetDir) {
        Remove-Item -Path $targetDir -Recurse -Force
    }
    exit 1
}
