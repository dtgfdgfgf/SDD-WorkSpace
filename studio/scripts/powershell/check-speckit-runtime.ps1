#!/usr/bin/env pwsh

[CmdletBinding()]
param(
    [switch]$Json,
    [switch]$Fix,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    $helpLines = @(
        'Usage: ./check-speckit-runtime.ps1 [-Json] [-Fix] [-Help]',
        '',
        'Checks studio-first runtime readiness, including Copilot and Claude shared runtime authorities, templates, hooks, extension governance, and skills install targets.',
        '',
        'Options:',
        '  -Json    Output structured JSON summary',
        '  -Fix     Reserved for future auto-fix capabilities',
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

function New-AuditFailure {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Category,
        [Parameter(Mandatory = $true)]
        [string]$Id,
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [string]$Path
    )

    return [ordered]@{
        category = $Category
        id       = $Id
        message  = $Message
        path     = $Path
    }
}

function Test-ContentContract {
    param(
        [string]$Content,
        [object[]]$MustContainAll = @(),
        [object[]]$MustMatchAll = @(),
        [object[]]$MustContainAnchors = @()
    )

    $missing = @()

    foreach ($requiredText in @($MustContainAll)) {
        $requiredTextString = [string]$requiredText
        if (
            -not [string]::IsNullOrWhiteSpace($requiredTextString) -and
            $Content.IndexOf($requiredTextString, [System.StringComparison]::Ordinal) -lt 0
        ) {
            $missing += "missing text: $requiredText"
        }
    }

    foreach ($requiredPattern in @($MustMatchAll)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$requiredPattern) -and ($Content -notmatch [string]$requiredPattern)) {
            $missing += "missing pattern: $requiredPattern"
        }
    }

    foreach ($requiredAnchor in @($MustContainAnchors)) {
        $anchorId = [string]$requiredAnchor
        if ([string]::IsNullOrWhiteSpace($anchorId)) { continue }
        $anchorMarker = "<!-- governance-anchor: $anchorId -->"
        if ($Content.IndexOf($anchorMarker, [System.StringComparison]::Ordinal) -lt 0) {
            $missing += "missing anchor: $anchorId"
        }
    }

    return @($missing)
}

function Invoke-PathContractChecks {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Entries,
        [Parameter(Mandatory = $true)]
        [string]$RootPath,
        [Parameter(Mandatory = $true)]
        [string]$FailureCategory,
        [Parameter(Mandatory = $true)]
        [string]$MissingMessage
    )

    $checks = @()
    $entryFailures = @()

    foreach ($entry in @($Entries)) {
        $targetPath = Join-Path $RootPath ([string]$entry.path)
        $exists = Test-Path -LiteralPath $targetPath
        $missingRequirements = @()

        if ($exists) {
            $content = Get-Content -LiteralPath $targetPath -Raw
            $missingRequirements = @(Test-ContentContract -Content $content -MustContainAll @($entry.mustContainAll) -MustMatchAll @($entry.mustMatchAll) -MustContainAnchors @($entry.mustContainAnchors))
        }

        $checks += [ordered]@{
            id                  = [string]$entry.id
            path                = $targetPath
            exists              = $exists
            missingRequirements = $missingRequirements
        }

        if (-not $exists) {
            $entryFailures += New-AuditFailure -Category $FailureCategory -Id ([string]$entry.id) -Message $MissingMessage -Path $targetPath
        } elseif ($missingRequirements.Count -gt 0) {
            $entryFailures += New-AuditFailure -Category $FailureCategory -Id ([string]$entry.id) -Message ("Contract invariant failed: {0}" -f ($missingRequirements -join '; ')) -Path $targetPath
        }
    }

    return [ordered]@{
        Checks   = $checks
        Failures = $entryFailures
    }
}

$paths = Get-StudioSharedLayerPaths -StartDir $PSScriptRoot
$validator = Invoke-JsonScript -ScriptPath $paths.EXTENSIONS_VALIDATOR_PATH -Arguments @('-Json')
$runtimeSources = Get-ExtensionAwareRuntimeSources -StartDir $PSScriptRoot
$updateAgentContextPath = Join-Path $paths.SHARED_SCRIPTS_DIR 'update-agent-context.ps1'
$supportedAgentContexts = Get-SupportedAgentContexts -Path $updateAgentContextPath
$contract = Read-JsonFile -Path $paths.SHARED_RUNTIME_CONTRACT

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
$failures = @()

$enabledExtensions = @($validator.EXTENSIONS | Where-Object { $_.enabled -eq $true } | ForEach-Object { $_.id })
if ($enabledExtensions.Count -gt 0 -and $runtimeSources.MODE -ne 'merged') {
    $warnings += 'Enabled extensions exist but no merged runtime mirror is currently active.'
}

if (-not $validator.VALID) {
    foreach ($extensionError in @($validator.ERRORS)) {
        $failures += New-AuditFailure -Category 'extension-registry' -Id 'extension-registry-invalid' -Message ([string]$extensionError) -Path $paths.EXTENSIONS_ROOT
    }
}
foreach ($extensionWarning in @($validator.WARNINGS)) {
    $warnings += [string]$extensionWarning
}

$commandChecks = @()
$promptStubChecks = @()
$claudeAgentChecks = @()
$templateChecks = @()
$docSemanticChecks = @()
$agentSemanticChecks = @()
$templateSemanticChecks = @()
$scriptSemanticChecks = @()
$hookChecks = @()
$agentBootstrapChecks = @()

if (-not $contract) {
    $failures += New-AuditFailure -Category 'contract' -Id 'missing-contract' -Message 'Shared runtime contract not found or unreadable.' -Path $paths.SHARED_RUNTIME_CONTRACT
} else {
    $actualCommandFiles = @(Get-ChildItem -LiteralPath $paths.SHARED_AGENTS_DIR -File -Filter 'speckit.*.agent.md' | Select-Object -ExpandProperty Name)
    $actualCommands = @($actualCommandFiles | ForEach-Object { $_ -replace '\.agent\.md$', '' } | Sort-Object -Unique)
    $requiredCommands = @($contract.requiredCommands | ForEach-Object { [string]$_ })

    foreach ($requiredCommand in $requiredCommands) {
        $agentPath = Join-Path $paths.SHARED_AGENTS_DIR ("{0}.agent.md" -f $requiredCommand)
        $exists = Test-Path -LiteralPath $agentPath
        $commandChecks += [ordered]@{
            name      = $requiredCommand
            path      = $agentPath
            exists    = $exists
            inContract = $true
        }
        if (-not $exists) {
            $failures += New-AuditFailure -Category 'commands' -Id $requiredCommand -Message "Missing required shared runtime command: $requiredCommand" -Path $agentPath
        }
    }

    foreach ($unexpectedCommand in @($actualCommands | Where-Object { $_ -notin $requiredCommands })) {
        $agentPath = Join-Path $paths.SHARED_AGENTS_DIR ("{0}.agent.md" -f $unexpectedCommand)
        $commandChecks += [ordered]@{
            name       = $unexpectedCommand
            path       = $agentPath
            exists     = $true
            inContract = $false
        }
        $failures += New-AuditFailure -Category 'commands' -Id ("unexpected-{0}" -f $unexpectedCommand) -Message "Unexpected shared runtime command not declared in contract: $unexpectedCommand" -Path $agentPath
    }

    $actualPromptFiles = @(Get-ChildItem -LiteralPath $paths.SHARED_PROMPTS_DIR -File -Filter 'speckit.*.prompt.md' | Select-Object -ExpandProperty Name)
    $requiredPromptFiles = @($contract.requiredPromptStubs | ForEach-Object { [string]$_ })

    foreach ($requiredPromptFile in $requiredPromptFiles) {
        $promptPath = Join-Path $paths.SHARED_PROMPTS_DIR $requiredPromptFile
        $exists = Test-Path -LiteralPath $promptPath
        $promptStubChecks += [ordered]@{
            name       = $requiredPromptFile
            path       = $promptPath
            exists     = $exists
            inContract = $true
        }
        if (-not $exists) {
            $failures += New-AuditFailure -Category 'prompts' -Id $requiredPromptFile -Message "Missing required prompt stub: $requiredPromptFile" -Path $promptPath
        }
    }

    foreach ($unexpectedPromptFile in @($actualPromptFiles | Where-Object { $_ -notin $requiredPromptFiles })) {
        $promptPath = Join-Path $paths.SHARED_PROMPTS_DIR $unexpectedPromptFile
        $promptStubChecks += [ordered]@{
            name       = $unexpectedPromptFile
            path       = $promptPath
            exists     = $true
            inContract = $false
        }
        $failures += New-AuditFailure -Category 'prompts' -Id ("unexpected-{0}" -f $unexpectedPromptFile) -Message "Unexpected prompt stub not declared in contract: $unexpectedPromptFile" -Path $promptPath
    }

    $actualClaudeAgentFiles = if (Test-Path -LiteralPath $paths.SHARED_CLAUDE_AGENTS_DIR) {
        @(Get-ChildItem -LiteralPath $paths.SHARED_CLAUDE_AGENTS_DIR -File -Filter '*.md' | Select-Object -ExpandProperty Name)
    } else {
        @()
    }
    $requiredClaudeAgentFiles = @($contract.requiredClaudeAgents | ForEach-Object { [string]$_ })

    foreach ($requiredClaudeAgentFile in $requiredClaudeAgentFiles) {
        $claudeAgentPath = Join-Path $paths.SHARED_CLAUDE_AGENTS_DIR $requiredClaudeAgentFile
        $exists = Test-Path -LiteralPath $claudeAgentPath
        $claudeAgentChecks += [ordered]@{
            name       = $requiredClaudeAgentFile
            path       = $claudeAgentPath
            exists     = $exists
            inContract = $true
        }
        if (-not $exists) {
            $failures += New-AuditFailure -Category 'claude-agents' -Id $requiredClaudeAgentFile -Message "Missing required Claude shared agent: $requiredClaudeAgentFile" -Path $claudeAgentPath
        }
    }

    foreach ($unexpectedClaudeAgentFile in @($actualClaudeAgentFiles | Where-Object { $_ -notin $requiredClaudeAgentFiles })) {
        $claudeAgentPath = Join-Path $paths.SHARED_CLAUDE_AGENTS_DIR $unexpectedClaudeAgentFile
        $claudeAgentChecks += [ordered]@{
            name       = $unexpectedClaudeAgentFile
            path       = $claudeAgentPath
            exists     = $true
            inContract = $false
        }
        $failures += New-AuditFailure -Category 'claude-agents' -Id ("unexpected-{0}" -f $unexpectedClaudeAgentFile) -Message "Unexpected Claude shared agent not declared in contract: $unexpectedClaudeAgentFile" -Path $claudeAgentPath
    }

    $templatesDir = Join-Path $paths.STUDIO_ROOT 'templates/sdd-docs'
    foreach ($templateName in @($contract.requiredDocTemplates | ForEach-Object { [string]$_ })) {
        $templatePath = Join-Path $templatesDir $templateName
        $exists = Test-Path -LiteralPath $templatePath
        $templateChecks += [ordered]@{
            name   = $templateName
            path   = $templatePath
            exists = $exists
        }
        if (-not $exists) {
            $failures += New-AuditFailure -Category 'templates' -Id $templateName -Message "Missing required studio document template: $templateName" -Path $templatePath
        }
    }

    foreach ($hookContract in ($contract.requiredHooks ?? @())) {
        $hookPath = Join-Path $paths.WORKSPACE_ROOT ([string]$hookContract.path)
        $exists = Test-Path -LiteralPath $hookPath
        $missingRequirements = @()
        if ($exists) {
            $content = Get-Content -LiteralPath $hookPath -Raw
            $missingRequirements = @(Test-ContentContract -Content $content -MustContainAll @($hookContract.mustContainAll) -MustMatchAll @($hookContract.mustMatchAll))
        }

        $hookChecks += [ordered]@{
            id                  = [string]$hookContract.id
            path                = $hookPath
            exists              = $exists
            missingRequirements = $missingRequirements
        }

        if (-not $exists) {
            $failures += New-AuditFailure -Category 'hooks' -Id ([string]$hookContract.id) -Message 'Required hook file is missing.' -Path $hookPath
        } elseif ($missingRequirements.Count -gt 0) {
            $failures += New-AuditFailure -Category 'hooks' -Id ([string]$hookContract.id) -Message ("Hook file does not satisfy contract requirements: {0}" -f ($missingRequirements -join '; ')) -Path $hookPath
        }
    }

    $docContractResult = Invoke-PathContractChecks -Entries ($contract.docInvariants ?? @()) -RootPath $paths.WORKSPACE_ROOT -FailureCategory 'docs' -MissingMessage 'Canonical document required by contract is missing.'
    $docSemanticChecks = @($docContractResult.Checks)
    $failures += @($docContractResult.Failures)

    $agentContractResult = Invoke-PathContractChecks -Entries ($contract.agentInvariants ?? @()) -RootPath $paths.WORKSPACE_ROOT -FailureCategory 'agent-semantics' -MissingMessage 'Runtime agent required by semantic contract is missing.'
    $agentSemanticChecks = @($agentContractResult.Checks)
    $failures += @($agentContractResult.Failures)

    $templateContractResult = Invoke-PathContractChecks -Entries ($contract.templateInvariants ?? @()) -RootPath $paths.WORKSPACE_ROOT -FailureCategory 'template-semantics' -MissingMessage 'Template required by semantic contract is missing.'
    $templateSemanticChecks = @($templateContractResult.Checks)
    $failures += @($templateContractResult.Failures)

    $scriptContractResult = Invoke-PathContractChecks -Entries ($contract.scriptInvariants ?? @()) -RootPath $paths.WORKSPACE_ROOT -FailureCategory 'script-semantics' -MissingMessage 'Shared script required by semantic contract is missing.'
    $scriptSemanticChecks = @($scriptContractResult.Checks)
    $failures += @($scriptContractResult.Failures)
}

$agentBootstrapScript = Join-Path $paths.SHARED_SCRIPTS_DIR 'check-agent-bootstrap.ps1'
if (-not (Test-Path -LiteralPath $agentBootstrapScript)) {
    $failures += New-AuditFailure -Category 'agent-bootstrap' -Id 'missing-check-script' -Message 'Agent bootstrap check script is missing.' -Path $agentBootstrapScript
} else {
    $agentBootstrapResult = Invoke-JsonScriptDetailed -ScriptPath $agentBootstrapScript -Arguments @('-ProjectRoot', $paths.WORKSPACE_ROOT, '-Json')
    if ($agentBootstrapResult.OUTPUT) {
        $agentBootstrapChecks = @($agentBootstrapResult.OUTPUT)
    }

    if ($agentBootstrapResult.EXIT_CODE -ne 0 -or -not $agentBootstrapResult.OUTPUT -or -not $agentBootstrapResult.OUTPUT.VALID) {
        $failures += New-AuditFailure -Category 'agent-bootstrap' -Id 'workspace-bootstrap-invalid' -Message 'Workspace root AGENTS.md, CLAUDE.md, and .github/copilot-instructions.md are not synchronized.' -Path $paths.WORKSPACE_ROOT
    }
}

$skillTargets = @()
foreach ($target in @('codex', 'claude')) {
    try {
        $targetInfo = Resolve-SkillInstallRoot -Target $target
        $managedPath = Get-ManagedSkillsPath -SkillsRoot $targetInfo.installRoot
        $skillTargets += [ordered]@{
            target         = $target
            installRoot    = $targetInfo.installRoot
            resolution     = $targetInfo.resolution
            managedPath    = $managedPath
            packDir        = Join-Path $paths.SKILL_PACKS_ROOT $target
            packReady      = (Test-Path -LiteralPath (Join-Path (Join-Path $paths.SKILL_PACKS_ROOT $target) 'manifest.json'))
            installed      = (Test-Path -LiteralPath $managedPath)
            installedCount = if (Test-Path -LiteralPath $managedPath) { @(Get-ChildItem -LiteralPath $managedPath -Directory).Count } else { 0 }
        }
    } catch {
        $skillTargets += [ordered]@{
            target         = $target
            installRoot    = $null
            resolution     = 'unresolved'
            managedPath    = $null
            packDir        = Join-Path $paths.SKILL_PACKS_ROOT $target
            packReady      = (Test-Path -LiteralPath (Join-Path (Join-Path $paths.SKILL_PACKS_ROOT $target) 'manifest.json'))
            installed      = $false
            installedCount = 0
        }
        $warnings += $_.Exception.Message
    }
}

# ========================================
# Impact registry freshness check
# ========================================
$registryFreshnessCheck = [ordered]@{
    id     = 'impact-registry-freshness'
    fresh  = $false
    reason = $null
}

$generatorScript = Join-Path $paths.WORKSPACE_ROOT 'studio/scripts/powershell/generate-impact-registry.ps1'
$registryFile = Join-Path $paths.WORKSPACE_ROOT 'studio/runtime/impact-registry.json'

if (-not (Test-Path -LiteralPath $generatorScript)) {
    $registryFreshnessCheck.reason = 'Generator script not found'
    $warnings += 'Impact registry freshness: generator script not found'
} elseif (-not (Test-Path -LiteralPath $registryFile)) {
    $registryFreshnessCheck.reason = 'Registry file not found'
    $failures += (New-AuditFailure -Category 'registry-freshness' -Id 'impact-registry-missing' -Message 'impact-registry.json does not exist' -Path $registryFile)
} else {
    try {
        $compareOutput = & pwsh -NoProfile -File $generatorScript -Compare 2>&1
        $compareExit = if ($null -ne $LASTEXITCODE) { [int]$LASTEXITCODE } else { 0 }
        if ($compareExit -eq 0) {
            $registryFreshnessCheck.fresh = $true
        } else {
            $registryFreshnessCheck.reason = 'Generated output differs from current file'
            $failures += (New-AuditFailure -Category 'registry-freshness' -Id 'impact-registry-stale' -Message 'Impact registry is stale: run generate-impact-registry.ps1 -Write to refresh' -Path $registryFile)
        }
    } catch {
        $registryFreshnessCheck.reason = "Generator error: $($_.Exception.Message)"
        $failures += (New-AuditFailure -Category 'registry-freshness' -Id 'impact-registry-error' -Message "Impact registry freshness check error: $($_.Exception.Message)" -Path $registryFile)
    }
}

$result = [ordered]@{
    VALID                     = ($failures.Count -eq 0)
    ERROR_COUNT               = $failures.Count
    WARNING_COUNT             = $warnings.Count
    MODE                      = 'studio-first'
    WORKSPACE_ROOT            = $paths.WORKSPACE_ROOT
    STUDIO_ROOT               = $paths.STUDIO_ROOT
    CONTRACT_PATH             = $paths.SHARED_RUNTIME_CONTRACT
    RUNTIME_SOURCE_MODE       = $runtimeSources.MODE
    RUNTIME_SOURCE_ROOT       = $runtimeSources.ROOT
    RUNTIME_MANIFEST_PATH     = $runtimeSources.MANIFEST_PATH
    RUNTIME_AGENT_COUNT       = if (Test-Path -LiteralPath $runtimeSources.AGENTS_DIR) { @(Get-ChildItem -LiteralPath $runtimeSources.AGENTS_DIR -File -Recurse).Count } else { 0 }
    RUNTIME_PROMPT_COUNT      = if (Test-Path -LiteralPath $runtimeSources.PROMPTS_DIR) { @(Get-ChildItem -LiteralPath $runtimeSources.PROMPTS_DIR -File -Recurse).Count } else { 0 }
    CLAUDE_RUNTIME_AGENT_COUNT = if (Test-Path -LiteralPath $paths.SHARED_CLAUDE_AGENTS_DIR) { @(Get-ChildItem -LiteralPath $paths.SHARED_CLAUDE_AGENTS_DIR -File -Recurse).Count } else { 0 }
    TOOL_CHECKS               = $toolChecks
    SUPPORTED_AGENT_CONTEXTS  = $supportedAgentContexts
    EXTENSION_REGISTRY_VALID  = $validator.VALID
    EXTENSION_COUNT           = $validator.EXTENSION_COUNT
    ENABLED_EXTENSIONS        = $enabledExtensions
    EXTENSION_ERRORS          = $validator.ERROR_COUNT
    EXTENSION_WARNINGS        = $validator.WARNING_COUNT
    COMMAND_CHECKS            = $commandChecks
    PROMPT_STUB_CHECKS        = $promptStubChecks
    CLAUDE_AGENT_CHECKS       = $claudeAgentChecks
    TEMPLATE_CHECKS           = $templateChecks
    DOC_SEMANTIC_CHECKS       = $docSemanticChecks
    AGENT_SEMANTIC_CHECKS     = $agentSemanticChecks
    TEMPLATE_SEMANTIC_CHECKS  = $templateSemanticChecks
    SCRIPT_SEMANTIC_CHECKS    = $scriptSemanticChecks
    AGENT_BOOTSTRAP_CHECKS    = $agentBootstrapChecks
    HOOK_CHECKS               = $hookChecks
    SKILL_TARGETS             = $skillTargets
    REGISTRY_FRESHNESS        = $registryFreshnessCheck
    WARNINGS                  = $warnings
    FAILURES                  = $failures
}

$exitCode = if ($result.VALID) { 0 } else { 1 }

if ($Json) {
    [PSCustomObject]$result | ConvertTo-Json -Depth 10
    exit $exitCode
}

Write-Output ("Shared runtime contract valid: {0}" -f $result.VALID.ToString().ToLower())
Write-Output ("Contract path: {0}" -f $result.CONTRACT_PATH)
Write-Output ("Errors: {0}" -f $result.ERROR_COUNT)
Write-Output ("Warnings: {0}" -f $result.WARNING_COUNT)
Write-Output ("Runtime source mode: {0}" -f $result.RUNTIME_SOURCE_MODE)
Write-Output ("Runtime agents: {0}" -f $result.RUNTIME_AGENT_COUNT)
Write-Output ("Runtime prompts: {0}" -f $result.RUNTIME_PROMPT_COUNT)
Write-Output ("Claude shared agents: {0}" -f $result.CLAUDE_RUNTIME_AGENT_COUNT)
Write-Output ("Extension registry valid: {0}" -f $result.EXTENSION_REGISTRY_VALID.ToString().ToLower())
Write-Output ("Supported agent contexts: {0}" -f ($result.SUPPORTED_AGENT_CONTEXTS -join ', '))

if ($result.FAILURES.Count -gt 0) {
    Write-Output ''
    Write-Output 'Failures:'
    $result.FAILURES | ForEach-Object {
        $pathSuffix = if ($_.path) { " [$($_.path)]" } else { '' }
        Write-Output ("- {0}/{1}: {2}{3}" -f $_.category, $_.id, $_.message, $pathSuffix)
    }
}

if ($warnings.Count -gt 0) {
    Write-Output ''
    Write-Output 'Warnings:'
    $warnings | ForEach-Object { Write-Output "- $_" }
}

exit $exitCode
