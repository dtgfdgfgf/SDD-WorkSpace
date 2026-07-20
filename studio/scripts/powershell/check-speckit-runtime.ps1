#!/usr/bin/env pwsh

#Requires -Version 7.0

[CmdletBinding()]
param(
    [switch]$Json,
    [switch]$Fix,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

# When a parent process (e.g. the pre-commit hook) captures this script's output, emit
# UTF-8 regardless of the inherited console codepage so non-ASCII text in audit messages
# survives the pipe. Redirected-only: the setter does not touch a shared console here,
# and interactive display keeps the host's own encoding.
if ([Console]::IsOutputRedirected) {
    try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch {
        # Legacy console-decoding behavior remains; audit verdicts are ASCII-only either way.
    }
}

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

$warnings = @()
$failures = @()
$commandChecks = @()
$githubAgentChecks = @()
$promptStubChecks = @()
$claudeAgentChecks = @()
$claudeAgentParityChecks = @()
$templateChecks = @()
$docSemanticChecks = @()
$agentSemanticChecks = @()
$templateSemanticChecks = @()
$scriptSemanticChecks = @()
$workflowSemanticChecks = @()
$hookChecks = @()
$agentBootstrapChecks = @()
$mainlineNoteChecks = @()

$paths = Get-StudioSharedLayerPaths -StartDir $PSScriptRoot
$validator = Invoke-JsonScript -ScriptPath $paths.EXTENSIONS_VALIDATOR_PATH -Arguments @('-Json')
$listWorkflowsScript = Join-Path $paths.SHARED_SCRIPTS_DIR 'list-workflows.ps1'
$workflowListInvocation = if (Test-Path -LiteralPath $listWorkflowsScript -PathType Leaf) {
    Invoke-JsonScriptDetailed -ScriptPath $listWorkflowsScript -Arguments @('-Json')
} else {
    [ordered]@{ EXIT_CODE = 1; RAW = $null; OUTPUT = $null }
}
$workflowList = $workflowListInvocation.OUTPUT
$studioWorkflowEnabled = @()
if ($workflowList) {
    $studioWorkflowEnabled = @($workflowList.WORKFLOWS | Where-Object { $_.enabled -eq $true } | ForEach-Object { $_.id })
}

if (-not (Test-Path -LiteralPath $listWorkflowsScript -PathType Leaf)) {
    $failures += New-AuditFailure -Category 'workflow-registry' -Id 'workflow-list-script-missing' -Message 'Workflow registry list/validation script is missing.' -Path $listWorkflowsScript
} elseif (-not $workflowList) {
    $failures += New-AuditFailure -Category 'workflow-registry' -Id 'workflow-registry-output-invalid' -Message 'Workflow registry validation did not return structured JSON output.' -Path $listWorkflowsScript
} elseif ($workflowListInvocation.EXIT_CODE -ne 0 -or -not [bool]$workflowList.VALID) {
    $workflowErrors = @($workflowList.ERRORS | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    if ($workflowErrors.Count -eq 0) {
        $workflowErrors = @('Workflow registry validation failed without a structured error message.')
    }
    foreach ($workflowError in $workflowErrors) {
        $failures += New-AuditFailure -Category 'workflow-registry' -Id 'workflow-registry-invalid' -Message ([string]$workflowError) -Path (Join-Path $paths.STUDIO_ROOT 'workflows')
    }
}

$workflowYamlAvailable = [bool](Get-Module -ListAvailable -Name 'powershell-yaml' | Select-Object -First 1)
if (-not $workflowYamlAvailable) {
    $failures += New-AuditFailure -Category 'workflow-dependency' -Id 'powershell-yaml-missing' -Message 'powershell-yaml module is not installed; the workflow runtime requires it. Install: Install-Module -Name powershell-yaml -Scope CurrentUser' -Path $null
}
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


if (-not $contract) {
    $failures += New-AuditFailure -Category 'contract' -Id 'missing-contract' -Message 'Shared runtime contract not found or unreadable.' -Path $paths.SHARED_RUNTIME_CONTRACT
} else {
    $requiredCommands = @($contract.requiredCommands | ForEach-Object { [string]$_ })
    $mandatoryStageCommands = @($contract.mandatoryStageCommands | ForEach-Object { [string]$_ })
    $auxiliaryCommands = @($contract.auxiliaryCommands | ForEach-Object { [string]$_ })
    $expectedRequiredCommands = @($mandatoryStageCommands + $auxiliaryCommands | Sort-Object -Unique)
    $normalizedRequiredCommands = @($requiredCommands | Sort-Object -Unique)
    $commandLayerOverlap = @($mandatoryStageCommands | Where-Object { $_ -in $auxiliaryCommands } | Sort-Object -Unique)

    if (($expectedRequiredCommands -join "`n") -ne ($normalizedRequiredCommands -join "`n")) {
        $failures += New-AuditFailure -Category 'contract' -Id 'required-command-layering-mismatch' -Message 'requiredCommands must equal the union of mandatoryStageCommands and auxiliaryCommands.' -Path $paths.SHARED_RUNTIME_CONTRACT
    }
    if ($commandLayerOverlap.Count -gt 0) {
        $failures += New-AuditFailure -Category 'contract' -Id 'command-layering-overlap' -Message ("mandatoryStageCommands and auxiliaryCommands must be disjoint: {0}" -f ($commandLayerOverlap -join ', ')) -Path $paths.SHARED_RUNTIME_CONTRACT
    }

    $requiredSharedGatePaths = @(
        'studio/scripts/powershell/**',
        '.githooks/**',
        'studio/extensions/**'
    )
    $declaredSharedGatePaths = if ($contract.ContainsKey('sharedGatePaths')) {
        @($contract.sharedGatePaths | ForEach-Object { ([string]$_).Replace('\', '/').Trim() })
    } else {
        @()
    }
    $missingRequiredSharedGatePaths = @($requiredSharedGatePaths | Where-Object { $_ -cnotin $declaredSharedGatePaths })
    if ($missingRequiredSharedGatePaths.Count -gt 0) {
        $failures += New-AuditFailure -Category 'contract' -Id 'required-shared-gate-path-missing' -Message ("sharedGatePaths must include the category-complete rules: {0}" -f ($missingRequiredSharedGatePaths -join ', ')) -Path $paths.SHARED_RUNTIME_CONTRACT
    }

    $requiredRepositorySlug = 'dtgfdgfgf/sdd-workspace'
    $requiredAggregateNotePath = 'docs/mainline-updates/2026-05-05-studio-workflows-runtime.md'
    $mainlineReadinessPolicyValid = (
        $contract.ContainsKey('mainlineReadiness') -and
        $contract.mainlineReadiness -is [System.Collections.IDictionary] -and
        $contract.mainlineReadiness.ContainsKey('repositorySlug') -and
        ([string]$contract.mainlineReadiness.repositorySlug).Trim().ToLowerInvariant() -eq $requiredRepositorySlug -and
        $contract.mainlineReadiness.ContainsKey('aggregateNotePaths') -and
        $requiredAggregateNotePath -cin @(
            $contract.mainlineReadiness.aggregateNotePaths |
                ForEach-Object { ([string]$_).Replace('\', '/').Trim() }
        )
    )
    if (-not $mainlineReadinessPolicyValid) {
        $failures += New-AuditFailure -Category 'contract' -Id 'required-mainline-readiness-policy-missing' -Message "mainlineReadiness must bind repository '$requiredRepositorySlug' to aggregate note '$requiredAggregateNotePath' until R6." -Path $paths.SHARED_RUNTIME_CONTRACT
    }

    $actualGitHubAgentFiles = if (Test-Path -LiteralPath $paths.SHARED_AGENTS_DIR -PathType Container) {
        @(Get-ChildItem -LiteralPath $paths.SHARED_AGENTS_DIR -File -Force | Select-Object -ExpandProperty Name)
    } else {
        @()
    }
    $requiredCommandFiles = @($requiredCommands | ForEach-Object { "{0}.agent.md" -f $_ })
    $requiredNonCommandGitHubAgentFiles = @($contract.requiredNonCommandGitHubAgentFiles | ForEach-Object { [string]$_ })
    $requiredGitHubAgentFiles = @($requiredCommandFiles + $requiredNonCommandGitHubAgentFiles | Sort-Object -Unique)

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

    foreach ($requiredAgentFile in $requiredNonCommandGitHubAgentFiles) {
        $agentPath = Join-Path $paths.SHARED_AGENTS_DIR $requiredAgentFile
        $exists = Test-Path -LiteralPath $agentPath -PathType Leaf
        $githubAgentChecks += [ordered]@{
            name     = $requiredAgentFile
            path     = $agentPath
            exists   = $exists
            declared = $true
        }
        if (-not $exists) {
            $failures += New-AuditFailure -Category 'github-agents' -Id ("missing-{0}" -f $requiredAgentFile) -Message "Required non-command GitHub agent file is missing: $requiredAgentFile" -Path $agentPath
        }
    }

    foreach ($unexpectedAgentFile in @($actualGitHubAgentFiles | Where-Object { $_ -notin $requiredGitHubAgentFiles })) {
        $agentPath = Join-Path $paths.SHARED_AGENTS_DIR $unexpectedAgentFile
        $githubAgentChecks += [ordered]@{
            name     = $unexpectedAgentFile
            path     = $agentPath
            exists   = $true
            declared = $false
        }
        $failures += New-AuditFailure -Category 'github-agents' -Id ("unexpected-{0}" -f $unexpectedAgentFile) -Message "Unexpected GitHub agent file is not declared by the closed-directory policy: $unexpectedAgentFile" -Path $agentPath
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
        @(Get-ChildItem -LiteralPath $paths.SHARED_CLAUDE_AGENTS_DIR -File -Force | Select-Object -ExpandProperty Name)
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

    $claudeSeedVerifierPath = Join-Path $PSScriptRoot 'seed-claude-agents.ps1'
    $claudeParityInvocation = if (Test-Path -LiteralPath $claudeSeedVerifierPath -PathType Leaf) {
        Invoke-JsonScriptDetailed `
            -ScriptPath $claudeSeedVerifierPath `
            -Arguments @('-WorkspaceRoot', $paths.WORKSPACE_ROOT, '-Verify', '-Json')
    } else {
        [ordered]@{ EXIT_CODE = 1; RAW = $null; OUTPUT = $null }
    }
    $claudeParityResult = $claudeParityInvocation.OUTPUT
    $claudeParityValidFieldIsBoolean = (
        $null -ne $claudeParityResult -and
        ($claudeParityResult.VALID -is [bool])
    )
    $claudeParityErrorCountIsInteger = (
        $null -ne $claudeParityResult -and
        ($claudeParityResult.ERROR_COUNT -is [long])
    )
    $claudeParityErrorsIsArray = (
        $null -ne $claudeParityResult -and
        ($claudeParityResult.ERRORS -is [array])
    )
    $claudeParityValid = (
        (Test-Path -LiteralPath $claudeSeedVerifierPath -PathType Leaf) -and
        $null -ne $claudeParityResult -and
        $claudeParityInvocation.EXIT_CODE -eq 0 -and
        $claudeParityValidFieldIsBoolean -and
        $claudeParityResult.VALID -eq $true -and
        $claudeParityErrorCountIsInteger -and
        $claudeParityResult.ERROR_COUNT -eq 0 -and
        $claudeParityErrorsIsArray -and
        @($claudeParityResult.ERRORS).Count -eq 0
    )
    $claudeAgentParityChecks += [ordered]@{
        verifierPath = $claudeSeedVerifierPath
        valid        = $claudeParityValid
        validFieldIsBoolean = $claudeParityValidFieldIsBoolean
        errorCountIsInteger = $claudeParityErrorCountIsInteger
        errorsIsArray = $claudeParityErrorsIsArray
        exitCode     = [int]$claudeParityInvocation.EXIT_CODE
        errorCount   = if ($claudeParityErrorCountIsInteger) { [long]$claudeParityResult.ERROR_COUNT } else { $null }
        errors       = if ($claudeParityResult) { @($claudeParityResult.ERRORS) } else { @() }
    }
    if (-not $claudeParityValid) {
        $parityMessages = @()
        if ($claudeParityResult) {
            foreach ($childError in @($claudeParityResult.ERRORS)) {
                $childMessage = if ($childError -is [string]) {
                    [string]$childError
                } else {
                    [string]$childError.message
                }
                if (-not [string]::IsNullOrWhiteSpace($childMessage)) {
                    $parityMessages += $childMessage
                }
            }
        }
        if ($parityMessages.Count -eq 0) {
            $parityMessages = if ($claudeParityResult) {
                @('Claude agent parity verification output was invalid or internally inconsistent.')
            } else {
                @('Claude agent parity verifier did not return structured JSON output.')
            }
        }
        $failures += New-AuditFailure `
            -Category 'claude-agents' `
            -Id 'claude-agent-mirror-parity' `
            -Message ($parityMessages -join '; ') `
            -Path $paths.SHARED_CLAUDE_AGENTS_DIR
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

    $workflowContractResult = Invoke-PathContractChecks -Entries ($contract.workflowInvariants ?? @()) -RootPath $paths.WORKSPACE_ROOT -FailureCategory 'workflow-semantics' -MissingMessage 'Workflow definition required by semantic contract is missing.'
    $workflowSemanticChecks = @($workflowContractResult.Checks)
    $failures += @($workflowContractResult.Failures)
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

$mainlineNoteScript = Join-Path $paths.SHARED_SCRIPTS_DIR 'validate-mainline-notes.ps1'
if (-not (Test-Path -LiteralPath $mainlineNoteScript -PathType Leaf)) {
    $failures += New-AuditFailure -Category 'mainline-notes' -Id 'validator-missing' -Message 'Mainline update-note validator is missing.' -Path $mainlineNoteScript
} else {
    $mainlineNoteResult = Invoke-JsonScriptDetailed -ScriptPath $mainlineNoteScript -Arguments @('-WorkspaceRoot', $paths.WORKSPACE_ROOT, '-Json')
    if ($mainlineNoteResult.OUTPUT) {
        $mainlineNoteChecks = @($mainlineNoteResult.OUTPUT)
    }

    if (-not $mainlineNoteResult.OUTPUT) {
        $failures += New-AuditFailure -Category 'mainline-notes' -Id 'validator-output-invalid' -Message 'Mainline update-note validator did not return structured JSON.' -Path $mainlineNoteScript
    } elseif ($mainlineNoteResult.EXIT_CODE -ne 0 -or -not [bool]$mainlineNoteResult.OUTPUT.VALID) {
        $noteErrors = @($mainlineNoteResult.OUTPUT.ERRORS)
        if ($noteErrors.Count -eq 0) {
            $failures += New-AuditFailure -Category 'mainline-notes' -Id 'validation-failed' -Message 'Mainline update-note validation failed without a structured error.' -Path (Join-Path $paths.WORKSPACE_ROOT 'docs/mainline-updates')
        } else {
            foreach ($noteError in $noteErrors) {
                $notePath = if ($noteError.path) { Join-Path $paths.WORKSPACE_ROOT ([string]$noteError.path) } else { Join-Path $paths.WORKSPACE_ROOT 'docs/mainline-updates' }
                $failures += New-AuditFailure -Category 'mainline-notes' -Id ([string]$noteError.category) -Message ([string]$noteError.message) -Path $notePath
            }
        }
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
    STUDIO_WORKFLOW_REGISTRY_VALID = if ($workflowList) { [bool]$workflowList.VALID } else { $false }
    STUDIO_WORKFLOW_COUNT          = if ($workflowList) { [int]$workflowList.COUNT } else { 0 }
    STUDIO_WORKFLOW_ENABLED        = $studioWorkflowEnabled
    STUDIO_WORKFLOW_ERRORS         = if ($workflowList) { [int]$workflowList.ERROR_COUNT } else { 0 }
    STUDIO_WORKFLOW_WARNINGS       = 0
    STUDIO_WORKFLOW_YAML_AVAILABLE = $workflowYamlAvailable
    COMMAND_CHECKS            = $commandChecks
    GITHUB_AGENT_CHECKS        = $githubAgentChecks
    PROMPT_STUB_CHECKS        = $promptStubChecks
    CLAUDE_AGENT_CHECKS       = $claudeAgentChecks
    CLAUDE_AGENT_PARITY_CHECKS = $claudeAgentParityChecks
    CLAUDE_AGENT_PARITY_VALID = if ($claudeAgentParityChecks.Count -gt 0) { [bool]$claudeAgentParityChecks[0].valid } else { $false }
    TEMPLATE_CHECKS           = $templateChecks
    DOC_SEMANTIC_CHECKS       = $docSemanticChecks
    AGENT_SEMANTIC_CHECKS     = $agentSemanticChecks
    TEMPLATE_SEMANTIC_CHECKS  = $templateSemanticChecks
    SCRIPT_SEMANTIC_CHECKS    = $scriptSemanticChecks
    WORKFLOW_SEMANTIC_CHECKS  = $workflowSemanticChecks
    AGENT_BOOTSTRAP_CHECKS    = $agentBootstrapChecks
    MAINLINE_NOTE_CHECKS      = $mainlineNoteChecks
    MAINLINE_NOTE_VALID       = if ($mainlineNoteChecks.Count -gt 0) { [bool]$mainlineNoteChecks[0].VALID } else { $false }
    MAINLINE_NOTE_ERROR_COUNT = if ($mainlineNoteChecks.Count -gt 0) { [int]$mainlineNoteChecks[0].ERROR_COUNT } else { 0 }
    MAINLINE_NOTE_LEGACY_BASELINE_COUNT = if ($mainlineNoteChecks.Count -gt 0) { [int]$mainlineNoteChecks[0].LEGACY_BASELINE_COUNT } else { 0 }
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
