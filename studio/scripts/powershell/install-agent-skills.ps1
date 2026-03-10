#!/usr/bin/env pwsh

[CmdletBinding()]
param(
    [ValidateSet('codex', 'claude')]
    [string]$Target = 'codex',
    [ValidateSet('install', 'status', 'uninstall')]
    [string]$Mode = 'status',
    [string]$SourceDir,
    [string]$InstallRoot,
    [switch]$Refresh,
    [switch]$Force,
    [switch]$Json,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    $helpLines = @(
        'Usage: ./install-agent-skills.ps1 [-Target codex|claude] [-Mode install|status|uninstall] [-SourceDir <path>] [-InstallRoot <skills-dir>] [-Refresh] [-Force] [-Json] [-Help]',
        '',
        'Installs or removes generated studio-first skill packs into an agent-specific skills directory.',
        '',
        'Options:',
        '  -Target      Export/install target family. Supported: codex, claude',
        '  -Mode        install, status, or uninstall',
        '  -SourceDir   Skill pack directory. Defaults to resources/agent-skill-packs/<target>',
        '  -InstallRoot Agent skills directory. If omitted, resolves from target config or env var',
        '  -Refresh     Rebuild the skill pack before install/status',
        '  -Force       Allow export refresh to overwrite an existing pack',
        '  -Json        Output structured JSON summary',
        '  -Help        Show this help message'
    )
    Write-Output ($helpLines -join "`n")
    exit 0
}

. "$PSScriptRoot/common.ps1"

$paths = Get-StudioSharedLayerPaths -StartDir $PSScriptRoot
$resolvedSourceDir = if ([string]::IsNullOrWhiteSpace($SourceDir)) {
    Join-Path $paths.SKILL_PACKS_ROOT $Target
} else {
    Resolve-AbsolutePath -Path $SourceDir -BaseDir (Get-Location).Path
}

if ($Refresh) {
    $exportScript = Join-Path $PSScriptRoot 'export-agent-skills.ps1'
    $exportArgs = @('-Target', $Target, '-OutputDir', $resolvedSourceDir, '-Force', '-Json')
    $null = Invoke-JsonScript -ScriptPath $exportScript -Arguments $exportArgs
}

$targetInfo = Resolve-SkillInstallRoot -Target $Target -InstallRoot $InstallRoot
$skillsRoot = $targetInfo.installRoot
$managedPath = Get-ManagedSkillsPath -SkillsRoot $skillsRoot
$sourceSkillsDir = Join-Path $resolvedSourceDir 'skills'
$sourceManifestPath = Join-Path $resolvedSourceDir 'manifest.json'

$sourceReady = (Test-Path -LiteralPath $sourceSkillsDir) -and (Test-Path -LiteralPath $sourceManifestPath)
$sourceManifest = if ($sourceReady) { Read-JsonFile -Path $sourceManifestPath } else { $null }
$installedSkillDirs = if (Test-Path -LiteralPath $managedPath) { @(Get-ChildItem -LiteralPath $managedPath -Directory | Select-Object -ExpandProperty Name) } else { @() }

switch ($Mode) {
    'install' {
        if (-not $sourceReady) {
            Write-Error "Skill pack not found or incomplete: $resolvedSourceDir"
            exit 1
        }

        if (-not (Test-Path -LiteralPath $skillsRoot)) {
            New-Item -ItemType Directory -Path $skillsRoot -Force | Out-Null
        }

        Reset-Directory -Path $managedPath
        Copy-DirectoryContents -Source $sourceSkillsDir -Destination $managedPath

        foreach ($artifact in @('manifest.json', 'README.md')) {
            $artifactPath = Join-Path $resolvedSourceDir $artifact
            if (Test-Path -LiteralPath $artifactPath) {
                Copy-Item -LiteralPath $artifactPath -Destination (Join-Path $managedPath $artifact) -Force
            }
        }

        $installedSkillDirs = @(Get-ChildItem -LiteralPath $managedPath -Directory | Select-Object -ExpandProperty Name)
    }
    'uninstall' {
        if (Test-Path -LiteralPath $managedPath) {
            Remove-Item -LiteralPath $managedPath -Recurse -Force
        }

        $installedSkillDirs = @()
    }
    default {
        # status is read-only
    }
}

$result = [ordered]@{
    TARGET              = $Target
    MODE                = $Mode
    SOURCE_DIR          = $resolvedSourceDir
    SOURCE_READY        = $sourceReady
    INSTALL_ROOT        = $skillsRoot
    RESOLUTION          = $targetInfo.resolution
    MANAGED_NAMESPACE   = Get-ManagedSkillsNamespace
    MANAGED_PATH        = $managedPath
    PACK_NAME           = if ($sourceManifest) { $sourceManifest.name } else { $null }
    PACK_GENERATED_AT   = if ($sourceManifest) { $sourceManifest.generatedAt } else { $null }
    INSTALLED           = (Test-Path -LiteralPath $managedPath)
    SKILL_COUNT         = $installedSkillDirs.Count
    SKILLS              = @($installedSkillDirs)
}

if ($Json) {
    [PSCustomObject]$result | ConvertTo-Json -Depth 8
    exit 0
}

Write-Output ("Target: {0}" -f $Target)
Write-Output ("Mode: {0}" -f $Mode)
Write-Output ("Install root: {0}" -f $skillsRoot)
Write-Output ("Managed path: {0}" -f $managedPath)
Write-Output ("Installed: {0}" -f $result.INSTALLED.ToString().ToLower())
Write-Output ("Skill count: {0}" -f $result.SKILL_COUNT)
