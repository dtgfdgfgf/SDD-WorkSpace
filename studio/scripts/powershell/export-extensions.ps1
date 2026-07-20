#!/usr/bin/env pwsh

#Requires -Version 7.0

[CmdletBinding()]
param(
    [string]$OutputDir,
    [switch]$Force,
    [switch]$Json,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    $helpLines = @(
        'Usage: ./export-extensions.ps1 [-OutputDir <path>] [-Force] [-Json] [-Help]',
        '',
        'Exports the core shared runtime plus enabled studio-first extensions into a generated merged mirror.',
        '',
        'Options:',
        '  -OutputDir Target output directory. Defaults to resources/studio-runtime/merged',
        '  -Force     Overwrite an existing output directory',
        '  -Json      Output structured JSON summary',
        '  -Help      Show this help message'
    )
    Write-Output ($helpLines -join "`n")
    exit 0
}

. "$PSScriptRoot/common.ps1"
. "$PSScriptRoot/extension-registry-common.ps1"

$paths = Get-StudioSharedLayerPaths -StartDir $PSScriptRoot
$validation = Invoke-JsonScript -ScriptPath $paths.EXTENSIONS_VALIDATOR_PATH -Arguments @('-Json')
if (-not $validation.VALID) {
    Write-Error 'Extension registry is invalid. Run validate-extension-registry.ps1 for details.'
    exit 1
}

$resolvedOutputDir = if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $paths.RUNTIME_MIRROR_ROOT
} else {
    Resolve-AbsolutePath -Path $OutputDir -BaseDir (Get-Location).Path
}

$resolvedOutputDir = Assert-ExtensionOutputInsideWorkspace `
    -WorkspaceRoot $paths.WORKSPACE_ROOT `
    -OutputPath $resolvedOutputDir `
    -ProtectedRoots @(
        $paths.EXTENSIONS_ROOT,
        $paths.SHARED_AGENTS_DIR,
        $paths.SHARED_PROMPTS_DIR,
        $paths.SHARED_SCRIPTS_DIR,
        $paths.SHARED_TEMPLATES_DIR
    )

if (Test-Path -LiteralPath $resolvedOutputDir -PathType Leaf) {
    Write-Error "Extension export output is an existing file: $resolvedOutputDir"
    exit 1
}
if (Test-Path -LiteralPath $resolvedOutputDir -PathType Container) {
    Assert-ExtensionTreeHasNoReparsePoints -Root $resolvedOutputDir -TreeLabel 'Extension export output trees'
}
if ((Test-DirectoryHasEntries -Path $resolvedOutputDir) -and -not $Force) {
    Write-Error "Directory is not empty: $resolvedOutputDir. Use -Force to overwrite."
    exit 1
}

$outputParent = Split-Path -Parent $resolvedOutputDir
if (-not (Test-Path -LiteralPath $outputParent)) {
    New-Item -ItemType Directory -Path $outputParent -Force -ErrorAction Stop | Out-Null
}
$outputLeaf = Split-Path -Leaf $resolvedOutputDir
$stagingDir = Join-Path $outputParent ('.{0}.staging-{1}' -f $outputLeaf, [guid]::NewGuid().ToString('N'))
$backupDir = Join-Path $outputParent ('.{0}.backup-{1}' -f $outputLeaf, [guid]::NewGuid().ToString('N'))
[void](Assert-ExtensionOutputInsideWorkspace -WorkspaceRoot $paths.WORKSPACE_ROOT -OutputPath $stagingDir)
[void](Assert-ExtensionOutputInsideWorkspace -WorkspaceRoot $paths.WORKSPACE_ROOT -OutputPath $backupDir)
New-Item -ItemType Directory -Path $stagingDir -Force -ErrorAction Stop | Out-Null

$scopeTargets = [ordered]@{}
foreach ($scope in Get-ExtensionRuntimeScopes) {
    $scopeDir = Join-Path $stagingDir $scope
    New-Item -ItemType Directory -Path $scopeDir -Force | Out-Null
    $scopeTargets[$scope] = $scopeDir
}

$contributions = @()
$outputPromoted = $false
$outputBackedUp = $false
$cleanupWarning = $null

try {
    Get-ChildItem -LiteralPath $paths.SHARED_AGENTS_DIR -File -Filter '*.md' | Copy-Item -Destination $scopeTargets['agents'] -Force
    Get-ChildItem -LiteralPath $paths.SHARED_PROMPTS_DIR -File -Filter '*.md' | Copy-Item -Destination $scopeTargets['prompts'] -Force
    Copy-DirectoryContents -Source $paths.SHARED_SCRIPTS_DIR -Destination $scopeTargets['scripts']
    Copy-DirectoryContents -Source $paths.SHARED_TEMPLATES_DIR -Destination $scopeTargets['templates']

    foreach ($extension in @($validation.EXTENSIONS | Where-Object { $_.enabled -eq $true })) {
        foreach ($scope in $extension.entryPoints.Keys) {
            $scopeDir = $scopeTargets[$scope]
            $sourceScopeDir = Join-Path $extension.path $scope
            foreach ($relativePath in @($extension.entryPoints[$scope])) {
                $sourcePath = Resolve-ExtensionEntryPoint -ExtensionRoot $extension.path -Scope $scope -RelativePath $relativePath
                $targetTail = [System.IO.Path]::GetRelativePath($sourceScopeDir, $sourcePath)
                $targetPath = [System.IO.Path]::GetFullPath((Join-Path $scopeDir $targetTail))
                Assert-PathInsideRoot -Root $scopeDir -Candidate $targetPath -MessagePrefix "Extension export target escapes declared scope '$scope'"
                $targetParent = Split-Path -Parent $targetPath

                if (Test-Path -LiteralPath $targetPath) {
                    throw "Collision detected while exporting '$($extension.id)': $scope/$($targetTail.Replace('\', '/'))"
                }

                if (-not (Test-Path -LiteralPath $targetParent)) {
                    New-Item -ItemType Directory -Path $targetParent -Force -ErrorAction Stop | Out-Null
                }

                $copyArguments = @{
                    LiteralPath = $sourcePath
                    Destination = $targetPath
                    Force       = $true
                    ErrorAction = 'Stop'
                }
                if (Test-Path -LiteralPath $sourcePath -PathType Container) {
                    $copyArguments['Recurse'] = $true
                }
                Copy-Item @copyArguments

                $finalTarget = Join-Path (Join-Path $resolvedOutputDir $scope) $targetTail
                Assert-PathInsideRoot -Root (Join-Path $resolvedOutputDir $scope) -Candidate $finalTarget -MessagePrefix "Extension export target escapes final declared scope '$scope'"
                $contributions += [ordered]@{
                    id       = $extension.id
                    scope    = $scope
                    source   = $sourcePath
                    target   = $finalTarget
                }
            }
        }
    }

    $manifest = [ordered]@{
        generatedAt       = Get-IsoTimestamp
        mode              = 'studio-first'
        outputDir         = $resolvedOutputDir
        coreSources       = [ordered]@{
            agentsDir    = $paths.SHARED_AGENTS_DIR
            promptsDir   = $paths.SHARED_PROMPTS_DIR
            scriptsDir   = $paths.SHARED_SCRIPTS_DIR
            templatesDir = $paths.SHARED_TEMPLATES_DIR
        }
        enabledExtensions = @($validation.EXTENSIONS | Where-Object { $_.enabled -eq $true } | ForEach-Object { $_.id })
        contributions     = $contributions
        nonGoals          = @(
            'No direct writes into root shared runtime sources',
            'No project-tree mutation',
            'No override of core shared files',
            'No override between extensions'
        )
    }

    Write-JsonFile -Path (Join-Path $stagingDir 'manifest.json') -Data $manifest -Depth 10

    $counts = [ordered]@{
        AGENT_COUNT    = @(Get-ChildItem -LiteralPath $scopeTargets['agents'] -File -Recurse).Count
        PROMPT_COUNT   = @(Get-ChildItem -LiteralPath $scopeTargets['prompts'] -File -Recurse).Count
        SCRIPT_COUNT   = @(Get-ChildItem -LiteralPath $scopeTargets['scripts'] -File -Recurse).Count
        TEMPLATE_COUNT = @(Get-ChildItem -LiteralPath $scopeTargets['templates'] -File -Recurse).Count
        DOC_COUNT      = @(Get-ChildItem -LiteralPath $scopeTargets['docs'] -File -Recurse).Count
    }

    if (Test-Path -LiteralPath $resolvedOutputDir) {
        Move-Item -LiteralPath $resolvedOutputDir -Destination $backupDir -ErrorAction Stop
        $outputBackedUp = $true
    }
    Move-Item -LiteralPath $stagingDir -Destination $resolvedOutputDir -ErrorAction Stop
    $outputPromoted = $true
} catch {
    $failure = $_
    $rollbackErrors = @()
    if ($outputPromoted -and (Test-Path -LiteralPath $resolvedOutputDir)) {
        try {
            Remove-Item -LiteralPath $resolvedOutputDir -Recurse -Force -ErrorAction Stop
        } catch {
            $rollbackErrors += "promoted output cleanup failed: $($_.Exception.Message)"
        }
    }
    if ($outputBackedUp -and (Test-Path -LiteralPath $backupDir)) {
        try {
            Move-Item -LiteralPath $backupDir -Destination $resolvedOutputDir -ErrorAction Stop
        } catch {
            $rollbackErrors += "output rollback failed: $($_.Exception.Message)"
        }
    }
    if (Test-Path -LiteralPath $stagingDir) {
        try {
            Remove-Item -LiteralPath $stagingDir -Recurse -Force -ErrorAction Stop
        } catch {
            $rollbackErrors += "staging cleanup failed: $($_.Exception.Message)"
        }
    }

    $rollbackSuffix = if ($rollbackErrors.Count -gt 0) { " Rollback errors: $($rollbackErrors -join '; ')" } else { ' Rollback completed.' }
    throw "Extension export failed: $($failure.Exception.Message).$rollbackSuffix"
}

if ($outputBackedUp -and (Test-Path -LiteralPath $backupDir)) {
    try {
        Remove-Item -LiteralPath $backupDir -Recurse -Force -ErrorAction Stop
    } catch {
        $cleanupWarning = "Export succeeded, but obsolete backup cleanup failed: $($_.Exception.Message)"
    }
}

$manifestPath = Join-Path $resolvedOutputDir 'manifest.json'
$result = [ordered]@{
    OUTPUT_DIR         = $resolvedOutputDir
    MANIFEST_PATH      = $manifestPath
    ENABLED_EXTENSIONS = $manifest.enabledExtensions
    CONTRIBUTION_COUNT = $contributions.Count
    AGENT_COUNT        = $counts.AGENT_COUNT
    PROMPT_COUNT       = $counts.PROMPT_COUNT
    SCRIPT_COUNT       = $counts.SCRIPT_COUNT
    TEMPLATE_COUNT     = $counts.TEMPLATE_COUNT
    DOC_COUNT          = $counts.DOC_COUNT
    CLEANUP_WARNING    = $cleanupWarning
}

if ($Json) {
    [PSCustomObject]$result | ConvertTo-Json -Depth 8
    exit 0
}

Write-Output ("Exported merged runtime mirror to: {0}" -f $resolvedOutputDir)
Write-Output ("Enabled extensions: {0}" -f (($manifest.enabledExtensions -join ', ')))
Write-Output ("Manifest: {0}" -f $manifestPath)
if ($cleanupWarning) {
    Write-Warning $cleanupWarning
}
