#!/usr/bin/env pwsh

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

Ensure-DirectoryEmpty -Path $resolvedOutputDir -Force:$Force

$scopeTargets = [ordered]@{}
foreach ($scope in Get-ExtensionRuntimeScopes) {
    $scopeDir = Join-Path $resolvedOutputDir $scope
    New-Item -ItemType Directory -Path $scopeDir -Force | Out-Null
    $scopeTargets[$scope] = $scopeDir
}

Get-ChildItem -LiteralPath $paths.SHARED_AGENTS_DIR -File -Filter '*.md' | Copy-Item -Destination $scopeTargets['agents'] -Force
Get-ChildItem -LiteralPath $paths.SHARED_PROMPTS_DIR -File -Filter '*.md' | Copy-Item -Destination $scopeTargets['prompts'] -Force
Copy-DirectoryContents -Source $paths.SHARED_SCRIPTS_DIR -Destination $scopeTargets['scripts']
Copy-DirectoryContents -Source $paths.SHARED_TEMPLATES_DIR -Destination $scopeTargets['templates']

$contributions = @()

foreach ($extension in @($validation.EXTENSIONS | Where-Object { $_.enabled -eq $true })) {
    foreach ($scope in $extension.entryPoints.Keys) {
        $scopeDir = $scopeTargets[$scope]
        foreach ($relativePath in @($extension.entryPoints[$scope])) {
            $sourcePath = Resolve-RelativePathInsideRoot -Root $extension.path -RelativePath $relativePath
            $targetTail = $relativePath.Substring($scope.Length + 1)
            $targetPath = Join-Path $scopeDir $targetTail
            $targetParent = Split-Path -Parent $targetPath

            if (Test-Path -LiteralPath $targetPath) {
                Write-Error "Collision detected while exporting '$($extension.id)': $scope/$targetTail"
                exit 1
            }

            if (-not (Test-Path -LiteralPath $targetParent)) {
                New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
            }

            Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force
            $contributions += [ordered]@{
                id       = $extension.id
                scope    = $scope
                source   = $sourcePath
                target   = $targetPath
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

$manifestPath = Join-Path $resolvedOutputDir 'manifest.json'
Write-JsonFile -Path $manifestPath -Data $manifest -Depth 10

$result = [ordered]@{
    OUTPUT_DIR         = $resolvedOutputDir
    MANIFEST_PATH      = $manifestPath
    ENABLED_EXTENSIONS = $manifest.enabledExtensions
    CONTRIBUTION_COUNT = $contributions.Count
    AGENT_COUNT        = @(Get-ChildItem -LiteralPath $scopeTargets['agents'] -File -Recurse).Count
    PROMPT_COUNT       = @(Get-ChildItem -LiteralPath $scopeTargets['prompts'] -File -Recurse).Count
    SCRIPT_COUNT       = @(Get-ChildItem -LiteralPath $scopeTargets['scripts'] -File -Recurse).Count
    TEMPLATE_COUNT     = @(Get-ChildItem -LiteralPath $scopeTargets['templates'] -File -Recurse).Count
    DOC_COUNT          = @(Get-ChildItem -LiteralPath $scopeTargets['docs'] -File -Recurse).Count
  }

if ($Json) {
    [PSCustomObject]$result | ConvertTo-Json -Depth 8
    exit 0
}

Write-Output ("Exported merged runtime mirror to: {0}" -f $resolvedOutputDir)
Write-Output ("Enabled extensions: {0}" -f (($manifest.enabledExtensions -join ', ')))
Write-Output ("Manifest: {0}" -f $manifestPath)
