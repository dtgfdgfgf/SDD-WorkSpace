#Requires -Version 7.0

<#
.SYNOPSIS
    Initialize a new Internal or Client project in the projects/ directory.

.DESCRIPTION
    Creates a new project by copying the project-init template to projects/<name>/.
    Supports Internal (studio tools, automation) and Client (paid work) project types.

    Delegates the bulk of the scaffold to Initialize-ProjectFromTemplate (in common.ps1)
    so init-project and init-practice share a single implementation.

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
    .\init-project.ps1 -Name "preview" -Type Internal -WhatIf

.NOTES
    Target Directory: projects/<name>/
    SDD Rigor: Full SDD flow (+ client review gates for Client type)
    Knowledge Capture: retrospective.md required
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidatePattern('^[a-z0-9][a-z0-9-]*[a-z0-9]$|^[a-z0-9]$')]
    [string]$Name,

    [Parameter(Mandatory = $true)]
    [ValidateSet('Internal', 'Client')]
    [string]$Type,

    [Parameter(Mandatory = $false)]
    [string]$Description = ''
)

$ErrorActionPreference = 'Stop'

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

if (Test-Path $targetDir) {
    Write-Error "Project already exists at: $targetDir"
    Write-Host "Choose a different name or remove the existing directory."
    exit 1
}

Write-Host "Creating $Type project: $Name" -ForegroundColor Cyan
Write-Host "Target: $targetDir" -ForegroundColor Gray

try {
    $result = Initialize-ProjectFromTemplate `
        -Name $Name `
        -TargetDir $targetDir `
        -Type $Type `
        -TemplateDir $templateDir `
        -StudioRoot $studioRoot `
        -WorkspaceRoot $workspaceRoot `
        -Description $Description `
        -WhatIf:$WhatIfPreference

    if ($WhatIfPreference) {
        Write-Host ""
        Write-Host "[WhatIf] No filesystem changes were applied." -ForegroundColor Yellow
        return
    }

    if ($result.projectConstitution) {
        Write-Host "Project constitution ready: $($result.projectConstitution)" -ForegroundColor Gray
    }
    Write-Host "Generated AGENTS.md, CLAUDE.md, and .github/copilot-instructions.md" -ForegroundColor Gray

    foreach ($junction in $result.junctions) {
        if ($junction.available) {
            $verb = if ($junction.created) { 'Created' } else { 'Verified' }
            $relativePath = [System.IO.Path]::GetRelativePath($targetDir, $junction.path)
            Write-Host "$verb agent junction: $relativePath -> $($junction.target)" -ForegroundColor Gray
        } else {
            Write-Warning "Shared $($junction.agentType) agents source not found at: $($junction.target) - skipping junction creation"
        }
    }

    if ($result.gitRepository) {
        $gitVerb = if ($result.gitRepository.initialized) { 'Initialized' } else { 'Verified' }
        Write-Host "$gitVerb independent Git repository with hooksPath: $($result.gitRepository.hooksPath)" -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host "[OK] $Type project created successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Open project with multi-root workspace:"
    Write-Host "     code projects/$Name/$Name.code-workspace" -ForegroundColor White
    Write-Host "  2. Start SDD workflow with: /speckit.specify <your feature description>"
    Write-Host ""
    Write-Host "Project Type: $Type" -ForegroundColor Cyan
    Write-Host "Workspace File: $Name.code-workspace (includes studio, Copilot agents, and Claude agents as read-only)" -ForegroundColor Cyan
    Write-Host "Knowledge Capture: retrospective.md (required) + learnings.md (if applicable)"
    Write-Host ""

    if ($Type -eq 'Client') {
        Write-Host "[Reminder] Client Project:" -ForegroundColor Yellow
        Write-Host "  - Add client review gates at each SDD stage"
        Write-Host "  - Document client-specific requirements in .specify/memory/constitution.md"
        Write-Host ""
    }
}
catch {
    Write-Error "Failed to create project: $_"
    if ((Test-Path $targetDir) -and -not $WhatIfPreference) {
        Remove-Item -Path $targetDir -Recurse -Force
    }
    exit 1
}
