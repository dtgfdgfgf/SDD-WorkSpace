#!/usr/bin/env pwsh

[CmdletBinding()]
param(
    [switch]$Json,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    $helpLines = @(
        'Usage: ./get-speckit-version.ps1 [-Json] [-Help]',
        '',
        'Outputs the local studio-first Spec Kit version state and upstream alignment summary.',
        '',
        'Options:',
        '  -Json    Output structured JSON',
        '  -Help    Show this help message'
    )
    Write-Output ($helpLines -join "`n")
    exit 0
}

. "$PSScriptRoot/common.ps1"

function Get-UpstreamAnalysisRange {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        return [PSCustomObject]@{ Start = $null; End = $null; Label = $null }
    }

    $match = Select-String -Path $Path -Pattern '^# github/spec-kit 變更研究（(.+?) 至 (.+?)）$' | Select-Object -First 1
    if (-not $match) {
        return [PSCustomObject]@{ Start = $null; End = $null; Label = $null }
    }

    return [PSCustomObject]@{
        Start = $match.Matches[0].Groups[1].Value.Trim()
        End   = $match.Matches[0].Groups[2].Value.Trim()
        Label = "$($match.Matches[0].Groups[1].Value.Trim()) to $($match.Matches[0].Groups[2].Value.Trim())"
    }
}

$paths = Get-StudioSharedLayerPaths -StartDir $PSScriptRoot
$runtimeSources = Get-ExtensionAwareRuntimeSources -StartDir $PSScriptRoot
$validator = Invoke-JsonScript -ScriptPath $paths.EXTENSIONS_VALIDATOR_PATH -Arguments @('-Json')

$constitutionPath = Join-Path $paths.STUDIO_ROOT 'constitution/constitution.md'
$workspaceStructurePath = Join-Path $paths.WORKSPACE_ROOT 'WORKSPACE_STRUCTURE.md'
$upstreamAnalysisPath = Join-Path $paths.WORKSPACE_ROOT 'https-github-com-github-spec-kit-repo-2025-10-01-2.md'
$agentsDir = $runtimeSources.AGENTS_DIR
$promptsDir = $runtimeSources.PROMPTS_DIR
$updateAgentContextPath = Join-Path $paths.SHARED_SCRIPTS_DIR 'update-agent-context.ps1'

$constitutionVersion = Get-MarkdownField -Path $constitutionPath -Field 'Version'
$workspaceStructureVersion = Get-MarkdownField -Path $workspaceStructurePath -Field 'Version'
$upstreamRange = Get-UpstreamAnalysisRange -Path $upstreamAnalysisPath
$supportedAgentContexts = Get-SupportedAgentContexts -Path $updateAgentContextPath

$runtimeAgents = @()
if (Test-Path $agentsDir) {
    $runtimeAgents = Get-ChildItem -LiteralPath $agentsDir -File -Filter '*.md' | Sort-Object Name | Select-Object -ExpandProperty Name
}

$runtimePrompts = @()
if (Test-Path $promptsDir) {
    $runtimePrompts = Get-ChildItem -LiteralPath $promptsDir -File -Filter '*.md' | Sort-Object Name | Select-Object -ExpandProperty Name
}

$extensionManifests = @($validator.EXTENSIONS | Where-Object { $_.hasManifest -eq $true } | ForEach-Object { $_.id })
$extensionCatalog = @($validator.EXTENSIONS | Where-Object { $_.cataloged -eq $true })

$skillInstallTargets = @()
foreach ($target in @('codex', 'claude')) {
    try {
        $resolved = Resolve-SkillInstallRoot -Target $target
        $skillInstallTargets += [ordered]@{
            target      = $target
            installRoot = $resolved.installRoot
            resolution  = $resolved.resolution
        }
    } catch {
        $skillInstallTargets += [ordered]@{
            target      = $target
            installRoot = $null
            resolution  = 'unresolved'
        }
    }
}

$result = [ordered]@{
    MODE                        = 'studio-first'
    STUDIO_ROOT                 = $paths.STUDIO_ROOT
    WORKSPACE_ROOT              = $paths.WORKSPACE_ROOT
    STUDIO_CONSTITUTION_VERSION = $constitutionVersion
    WORKSPACE_STRUCTURE_VERSION = $workspaceStructureVersion
    UPSTREAM_ANALYSIS_RANGE     = $upstreamRange.Label
    UPSTREAM_BASELINE_DATE      = $upstreamRange.End
    RUNTIME_SOURCE_MODE         = $runtimeSources.MODE
    RUNTIME_AGENT_COUNT         = $runtimeAgents.Count
    RUNTIME_PROMPT_COUNT        = $runtimePrompts.Count
    EXTENSION_COUNT             = $extensionManifests.Count
    EXTENSION_CATALOG_COUNT     = $extensionCatalog.Count
    EXTENSION_REGISTRY_VALID    = $validator.VALID
    EXTENSION_ENABLED_COUNT     = @($validator.EXTENSIONS | Where-Object { $_.enabled -eq $true }).Count
    RUNTIME_AGENTS              = $runtimeAgents
    RUNTIME_PROMPTS             = $runtimePrompts
    EXTENSIONS                  = $extensionManifests
    SUPPORTED_AGENT_CONTEXTS    = $supportedAgentContexts
    SKILL_INSTALL_TARGETS       = $skillInstallTargets
    ADOPTED_CAPABILITIES        = @(
        '/speckit.* namespaced commands',
        'clarify / analyze / checklist / taskstoissues in local workflow',
        'multi-agent runtime support',
        'project constitution preservation on init/re-init style flows',
        'local speckit.version adaptation',
        'generic/BYO agent pack export helper',
        'AI skills export packs for codex/claude',
        'shared extension registry foundation',
        'curated catalog governance and validator',
        'extension runtime merged mirror export',
        'AI skills install layer for codex/claude',
        'runtime availability check',
        'workspace shared-layer sync command'
    )
    DEFERRED_CAPABILITIES       = @(
        'community extension adoption'
    )
    NON_GOALS                   = @(
        'repo-local full .specify migration',
        'legacy project batch migration',
        'update-agent-context.ps1 refactor',
        'changing studio-first template precedence'
    )
}

if ($Json) {
    [PSCustomObject]$result | ConvertTo-Json -Depth 6
    exit 0
}

Write-Output "Mode: $($result.MODE)"
Write-Output "Studio Root: $($result.STUDIO_ROOT)"
Write-Output "Workspace Root: $($result.WORKSPACE_ROOT)"
Write-Output "Studio Constitution Version: $($result.STUDIO_CONSTITUTION_VERSION)"
Write-Output "Workspace Structure Version: $($result.WORKSPACE_STRUCTURE_VERSION)"
Write-Output "Upstream Analysis Range: $($result.UPSTREAM_ANALYSIS_RANGE)"
Write-Output "Upstream Baseline Date: $($result.UPSTREAM_BASELINE_DATE)"
Write-Output "Runtime Source Mode: $($result.RUNTIME_SOURCE_MODE)"
Write-Output "Runtime Agents: $($result.RUNTIME_AGENT_COUNT)"
Write-Output "Runtime Prompts: $($result.RUNTIME_PROMPT_COUNT)"
Write-Output "Extensions: $($result.EXTENSION_COUNT)"
Write-Output "Catalog Entries: $($result.EXTENSION_CATALOG_COUNT)"
Write-Output "Extension Registry Valid: $($result.EXTENSION_REGISTRY_VALID)"
Write-Output "Supported Agent Contexts: $($result.SUPPORTED_AGENT_CONTEXTS -join ', ')"
Write-Output ''
Write-Output 'Adopted Capabilities:'
$result.ADOPTED_CAPABILITIES | ForEach-Object { Write-Output "- $_" }
Write-Output ''
Write-Output 'Deferred Capabilities:'
$result.DEFERRED_CAPABILITIES | ForEach-Object { Write-Output "- $_" }
Write-Output ''
Write-Output 'Non-Goals:'
$result.NON_GOALS | ForEach-Object { Write-Output "- $_" }

