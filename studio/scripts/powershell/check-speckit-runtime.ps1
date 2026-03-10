#!/usr/bin/env pwsh

[CmdletBinding()]
param(
    [switch]$Json,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    $helpLines = @(
        'Usage: ./check-speckit-runtime.ps1 [-Json] [-Help]',
        '',
        'Checks studio-first runtime readiness: tools, agent support, extension governance, merged runtime, and skills install targets.',
        '',
        'Options:',
        '  -Json    Output structured JSON summary',
        '  -Help    Show this help message'
    )
    Write-Output ($helpLines -join "`n")
    exit 0
}

. "$PSScriptRoot/common.ps1"

function Get-ToolCheck {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $command = Get-Command $Name -ErrorAction SilentlyContinue | Select-Object -First 1
    return [ordered]@{
        name      = $Name
        available = [bool]$command
        path      = if ($command) { $command.Source } else { $null }
    }
}

$paths = Get-StudioSharedLayerPaths -StartDir $PSScriptRoot
$validator = Invoke-JsonScript -ScriptPath $paths.EXTENSIONS_VALIDATOR_PATH -Arguments @('-Json')
$runtimeSources = Get-ExtensionAwareRuntimeSources -StartDir $PSScriptRoot
$updateAgentContextPath = Join-Path $paths.SHARED_SCRIPTS_DIR 'update-agent-context.ps1'
$supportedAgentContexts = Get-SupportedAgentContexts -Path $updateAgentContextPath

$toolChecks = @(
    'git',
    'pwsh',
    'claude',
    'gemini',
    'code',
    'code-insiders',
    'cursor-agent',
    'windsurf',
    'qwen',
    'opencode',
    'codex',
    'kiro-cli',
    'shai',
    'qodercli'
) | ForEach-Object { Get-ToolCheck -Name $_ }

$warnings = @()
$enabledExtensions = @($validator.EXTENSIONS | Where-Object { $_.enabled -eq $true } | ForEach-Object { $_.id })
if ($enabledExtensions.Count -gt 0 -and $runtimeSources.MODE -ne 'merged') {
    $warnings += 'Enabled extensions exist but no merged runtime mirror is currently active.'
}

$skillTargets = @()
foreach ($target in @('codex', 'claude')) {
    try {
        $targetInfo = Resolve-SkillInstallRoot -Target $target
        $managedPath = Get-ManagedSkillsPath -SkillsRoot $targetInfo.installRoot
        $skillTargets += [ordered]@{
            target        = $target
            installRoot   = $targetInfo.installRoot
            resolution    = $targetInfo.resolution
            managedPath   = $managedPath
            packDir       = Join-Path $paths.SKILL_PACKS_ROOT $target
            packReady     = (Test-Path -LiteralPath (Join-Path (Join-Path $paths.SKILL_PACKS_ROOT $target) 'manifest.json'))
            installed     = (Test-Path -LiteralPath $managedPath)
            installedCount = if (Test-Path -LiteralPath $managedPath) { @(Get-ChildItem -LiteralPath $managedPath -Directory).Count } else { 0 }
        }
    } catch {
        $skillTargets += [ordered]@{
            target        = $target
            installRoot   = $null
            resolution    = 'unresolved'
            managedPath   = $null
            packDir       = Join-Path $paths.SKILL_PACKS_ROOT $target
            packReady     = (Test-Path -LiteralPath (Join-Path (Join-Path $paths.SKILL_PACKS_ROOT $target) 'manifest.json'))
            installed     = $false
            installedCount = 0
        }
        $warnings += $_.Exception.Message
    }
}

$result = [ordered]@{
    MODE                       = 'studio-first'
    WORKSPACE_ROOT             = $paths.WORKSPACE_ROOT
    STUDIO_ROOT                = $paths.STUDIO_ROOT
    TOOL_CHECKS                = $toolChecks
    SUPPORTED_AGENT_CONTEXTS   = $supportedAgentContexts
    RUNTIME_SOURCE_MODE        = $runtimeSources.MODE
    RUNTIME_SOURCE_ROOT        = $runtimeSources.ROOT
    RUNTIME_MANIFEST_PATH      = $runtimeSources.MANIFEST_PATH
    RUNTIME_AGENT_COUNT        = if (Test-Path -LiteralPath $runtimeSources.AGENTS_DIR) { @(Get-ChildItem -LiteralPath $runtimeSources.AGENTS_DIR -File -Recurse).Count } else { 0 }
    RUNTIME_PROMPT_COUNT       = if (Test-Path -LiteralPath $runtimeSources.PROMPTS_DIR) { @(Get-ChildItem -LiteralPath $runtimeSources.PROMPTS_DIR -File -Recurse).Count } else { 0 }
    EXTENSION_REGISTRY_VALID   = $validator.VALID
    EXTENSION_COUNT            = $validator.EXTENSION_COUNT
    ENABLED_EXTENSIONS         = $enabledExtensions
    EXTENSION_ERRORS           = $validator.ERROR_COUNT
    EXTENSION_WARNINGS         = $validator.WARNING_COUNT
    CATALOG_POLICY_PRESENT     = (Test-Path -LiteralPath $paths.EXTENSIONS_POLICY_PATH)
    CATALOG_CURATED_ONLY       = if ($validator.EXTENSIONS.Count -ge 0) { (Read-JsonFile -Path $paths.EXTENSIONS_CATALOG_PATH).policy.curatedOnly } else { $null }
    SKILL_TARGETS              = $skillTargets
    WARNINGS                   = $warnings
}

if ($Json) {
    [PSCustomObject]$result | ConvertTo-Json -Depth 10
    exit 0
}

Write-Output ("Runtime source mode: {0}" -f $result.RUNTIME_SOURCE_MODE)
Write-Output ("Runtime agents: {0}" -f $result.RUNTIME_AGENT_COUNT)
Write-Output ("Runtime prompts: {0}" -f $result.RUNTIME_PROMPT_COUNT)
Write-Output ("Extension registry valid: {0}" -f $result.EXTENSION_REGISTRY_VALID.ToString().ToLower())
Write-Output ("Supported agent contexts: {0}" -f ($result.SUPPORTED_AGENT_CONTEXTS -join ', '))

if ($warnings.Count -gt 0) {
    Write-Output ''
    Write-Output 'Warnings:'
    $warnings | ForEach-Object { Write-Output "- $_" }
}
