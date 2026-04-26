<#
.SYNOPSIS
    Initialize a new Practice project in the learning/ directory.

.DESCRIPTION
    Creates a new Practice project by copying the project-init template to learning/<name>/.
    Practice projects are for learning exercises, demos, and skill-building.

.PARAMETER Name
    The name of the project (will become the directory name).

.PARAMETER Description
    Optional description for the project README.

.EXAMPLE
    .\init-practice.ps1 -Name "my-first-sdd"
    .\init-practice.ps1 -Name "chatbot-demo" -Description "A simple chatbot demo using LINE API"

.NOTES
    Project Type: Practice
    Target Directory: learning/<name>/
    SDD Rigor: Full SDD flow
    Knowledge Capture: learnings.md update (lightweight)
#>

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidatePattern('^[a-z0-9][a-z0-9-]*[a-z0-9]$|^[a-z0-9]$')]
    [string]$Name,

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
$targetDir = Join-Path $workspaceRoot "learning/$Name"

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

# Create target directory and copy template
Write-Host "Creating Practice project: $Name" -ForegroundColor Cyan
Write-Host "Target: $targetDir" -ForegroundColor Gray

try {
    # Copy template to target
    Copy-Item -Path $templateDir -Destination $targetDir -Recurse -Force

    # Update README.md with project info
    $readmePath = Join-Path $targetDir 'README.md'
    if (Test-Path $readmePath) {
        $readmeContent = Get-Content $readmePath -Raw
        $readmeContent = $readmeContent -replace '\[PROJECT_NAME\]', $Name
        $readmeContent = $readmeContent -replace '\[PROJECT_TYPE\]', 'Practice'
        $readmeContent = $readmeContent -replace '\[PROJECT_DESCRIPTION\]', $(if ($Description) { $Description } else { "A Practice project for learning and experimentation." })
        $readmeContent = $readmeContent -replace '\[CREATED_DATE\]', (Get-Date -Format 'yyyy-MM-dd')
        Set-Content -Path $readmePath -Value $readmeContent -NoNewline
    }

    # Ensure project constitution exists
    $projectConstPath = Initialize-ProjectConstitution -ProjectRoot $targetDir -ProjectName $Name -ProjectType 'Practice' -StudioRoot $studioRoot
    Write-Host "Project constitution ready: $projectConstPath" -ForegroundColor Gray

    # Generate CLAUDE.md from template
    $claudeTemplatePath = Join-Path $studioRoot 'templates/sdd-docs/claude-md-template.md'
    $claudeTargetPath = Join-Path $targetDir 'CLAUDE.md'
    if ((Test-Path $claudeTemplatePath) -and -not (Test-Path $claudeTargetPath)) {
        $claudeContent = Get-Content $claudeTemplatePath -Raw
        $claudeContent = $claudeContent -replace '\[PROJECT_NAME\]', $Name
        $claudeContent = $claudeContent -replace '\[PROJECT_TYPE\]', 'Practice'
        $claudeContent = $claudeContent -replace '\[CREATED_DATE\]', (Get-Date -Format 'yyyy-MM-dd')
        Set-Content -Path $claudeTargetPath -Value $claudeContent -NoNewline
        Write-Host "Generated CLAUDE.md" -ForegroundColor Gray
    }

    # Generate .github/copilot-instructions.md from template
    $copilotTemplatePath = Join-Path $studioRoot 'templates/sdd-docs/copilot-instructions-template.md'
    $copilotTargetDir = Join-Path $targetDir '.github'
    $copilotTargetPath = Join-Path $copilotTargetDir 'copilot-instructions.md'
    if ((Test-Path $copilotTemplatePath) -and -not (Test-Path $copilotTargetPath)) {
        if (-not (Test-Path $copilotTargetDir)) {
            New-Item -ItemType Directory -Path $copilotTargetDir -Force | Out-Null
        }
        $copilotContent = Get-Content $copilotTemplatePath -Raw
        $copilotContent = $copilotContent -replace '\[PROJECT_NAME\]', $Name
        $copilotContent = $copilotContent -replace '\[PROJECT_TYPE\]', 'Practice'
        $copilotContent = $copilotContent -replace '\[PROJECT_DESCRIPTION\]', $(if ($Description) { $Description } else { "A Practice project for learning and experimentation." })
        $copilotContent = $copilotContent -replace '\[CREATED_DATE\]', (Get-Date -Format 'yyyy-MM-dd')
        Set-Content -Path $copilotTargetPath -Value $copilotContent -NoNewline
        Write-Host "Generated .github/copilot-instructions.md" -ForegroundColor Gray
    }

    # Remove .gitkeep files if directories have content
    Get-ChildItem -Path $targetDir -Recurse -Filter '.gitkeep' | ForEach-Object {
        $parentDir = $_.DirectoryName
        $siblingCount = (Get-ChildItem -Path $parentDir -Exclude '.gitkeep').Count
        if ($siblingCount -gt 0) {
            Remove-Item $_.FullName -Force
        }
    }

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
            },
            @{
                name = "claude agents (read-only)"
                path = "../../.claude/agents"
            }
        )
        settings = @{
            "files.readonlyInclude" = @{
                "**/studio/**"          = $true
                "**/.github/agents/**"  = $true
                "**/.claude/agents/**"  = $true
            }
        }
    } | ConvertTo-Json -Depth 4
    Set-Content -Path $workspaceFile -Value $workspaceContent -Encoding UTF8

    # Create shared agent junctions for Copilot and Claude runtime discovery
    foreach ($junction in @(Initialize-ProjectSharedAgentJunctions -ProjectRoot $targetDir -WorkspaceRoot $workspaceRoot)) {
        if ($junction.available) {
            $verb = if ($junction.created) { 'Created' } else { 'Verified' }
            $relativePath = [System.IO.Path]::GetRelativePath($targetDir, $junction.path)
            Write-Host "$verb agent junction: $relativePath -> $($junction.target)" -ForegroundColor Gray
        } else {
            Write-Warning "Shared $($junction.agentType) agents source not found at: $($junction.target) - skipping junction creation"
        }
    }

    Write-Host ""
    Write-Host "✓ Practice project created successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Open project with multi-root workspace:"
    Write-Host "     code learning/$Name/$Name.code-workspace" -ForegroundColor White
    Write-Host "  2. Start SDD workflow with: /speckit.specify <your feature description>"
    Write-Host ""
    Write-Host "Project Type: Practice" -ForegroundColor Cyan
    Write-Host "Workspace File: $Name.code-workspace (includes studio, Copilot agents, and Claude agents as read-only)" -ForegroundColor Cyan
    Write-Host "Knowledge Capture: Update studio/knowledge-base/learnings.md when complete"
    Write-Host ""

}
catch {
    Write-Error "Failed to create project: $_"
    # Cleanup on failure
    if (Test-Path $targetDir) {
        Remove-Item -Path $targetDir -Recurse -Force
    }
    exit 1
}
