# setup-copilot-agents.ps1
# GitHub Copilot Custom Agents Setup Script
# Usage: 
#   First setup: .\setup-copilot-agents.ps1
#   Update:      .\setup-copilot-agents.ps1 -Update

param(
    [switch]$Update
)

# Configuration
$workspacePath = "C:\Users\user\Workspace"
$resourcesPath = "$workspacePath\resources"
$configPath = "$resourcesPath\github-copilot-configs"
$globalAgentsPath = "$env:USERPROFILE\.copilot\agents"
$repoUrl = "https://github.com/doggy8088/github-copilot-configs.git"

# Banner
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  GitHub Copilot Custom Agents Setup" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Clone or Update Repository
Write-Host "[Step 1/3] Repository Management" -ForegroundColor Yellow

if (-not (Test-Path $configPath)) {
    # Repository doesn't exist, clone it
    Write-Host "  Status: Repository not found" -ForegroundColor White
    Write-Host "  Action: Cloning from GitHub..." -ForegroundColor White
    
    # Ensure resources directory exists
    if (-not (Test-Path $resourcesPath)) {
        New-Item -Path $resourcesPath -ItemType Directory -Force | Out-Null
    }
    
    Set-Location $resourcesPath
    git clone $repoUrl
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Result: Clone successful!" -ForegroundColor Green
    } else {
        Write-Host "  Result: Clone failed!" -ForegroundColor Red
        exit 1
    }
} elseif ($Update) {
    # Repository exists and update requested
    Write-Host "  Status: Repository found" -ForegroundColor White
    Write-Host "  Action: Updating from GitHub..." -ForegroundColor White
    
    Set-Location $configPath
    git pull
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Result: Update successful!" -ForegroundColor Green
    } else {
        Write-Host "  Result: Update failed!" -ForegroundColor Red
        exit 1
    }
} else {
    # Repository exists but no update requested
    Write-Host "  Status: Repository found" -ForegroundColor White
    Write-Host "  Action: Skipping update (use -Update flag to update)" -ForegroundColor White
}

Write-Host ""

# Step 2: Prepare Global Agents Directory
Write-Host "[Step 2/3] Preparing Global Agents Directory" -ForegroundColor Yellow

if (-not (Test-Path $globalAgentsPath)) {
    Write-Host "  Action: Creating directory..." -ForegroundColor White
    New-Item -Path $globalAgentsPath -ItemType Directory -Force | Out-Null
    Write-Host "  Result: Directory created" -ForegroundColor Green
} else {
    Write-Host "  Status: Directory already exists" -ForegroundColor White
}

Write-Host ""

# Step 3: Copy Agents to Global Directory
Write-Host "[Step 3/3] Copying Agents" -ForegroundColor Yellow

$sourceAgents = "$configPath\.github\agents\*.md"
if (Test-Path $sourceAgents) {
    Copy-Item -Path $sourceAgents -Destination $globalAgentsPath -Force
    
    $agentCount = (Get-ChildItem $globalAgentsPath -Filter "*.md").Count
    Write-Host "  Result: Successfully copied $agentCount agent(s)" -ForegroundColor Green
} else {
    Write-Host "  Error: No agent files found in source!" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Summary
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Setup Completed Successfully!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "File Locations:" -ForegroundColor Cyan
Write-Host "  Repository : $configPath" -ForegroundColor White
Write-Host "  Agents Dir : $globalAgentsPath" -ForegroundColor White
Write-Host "  VS Code Cfg: $configPath\.vscode\settings.json" -ForegroundColor White
Write-Host ""

Write-Host "Available Agents ($agentCount):" -ForegroundColor Cyan
Get-ChildItem $globalAgentsPath -Filter "*.md" | Sort-Object Name | ForEach-Object {
    Write-Host "  * $($_.BaseName)" -ForegroundColor White
}
Write-Host ""

Write-Host "Usage:" -ForegroundColor Cyan
Write-Host "  First-time setup : .\setup-copilot-agents.ps1" -ForegroundColor White
Write-Host "  Update agents    : .\setup-copilot-agents.ps1 -Update" -ForegroundColor White
Write-Host "  View agents      : dir $globalAgentsPath" -ForegroundColor White
Write-Host ""

Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Install GitHub Copilot CLI if not installed" -ForegroundColor White
Write-Host "  2. Run 'copilot' in your project directory" -ForegroundColor White
Write-Host "  3. Use '/agent' command to invoke custom agents" -ForegroundColor White
Write-Host ""