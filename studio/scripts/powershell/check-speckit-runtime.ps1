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
        'Checks studio-first runtime readiness, including canonical GitHub agent inputs, dependent Claude mirrors, templates, hooks, extension governance, and skills install targets.',
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
        [object[]]$MustContainAnchors = @(),
        [object[]]$MustNotContainAny = @()
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

    foreach ($prohibitedText in @($MustNotContainAny)) {
        $prohibitedTextString = [string]$prohibitedText
        if (
            -not [string]::IsNullOrWhiteSpace($prohibitedTextString) -and
            $Content.IndexOf($prohibitedTextString, [System.StringComparison]::Ordinal) -ge 0
        ) {
            $missing += "prohibited text: $prohibitedText"
        }
    }

    return @($missing)
}

function Test-ExactDictionaryKeys {
    param(
        [object]$Value,
        [Parameter(Mandatory = $true)][string[]]$ExpectedKeys
    )

    if ($Value -isnot [System.Collections.IDictionary]) { return $false }
    if (@($Value.Keys).Count -ne $ExpectedKeys.Count) { return $false }
    foreach ($key in $ExpectedKeys) {
        if (-not $Value.Contains($key)) { return $false }
    }
    return $true
}

function Test-ExactStringArray {
    param(
        [object]$Value,
        [Parameter(Mandatory = $true)][string[]]$ExpectedValues
    )

    if ($Value -isnot [array]) { return $false }
    if (@($Value).Count -ne $ExpectedValues.Count) { return $false }
    for ($index = 0; $index -lt $ExpectedValues.Count; $index++) {
        if ($Value[$index] -isnot [string] -or $Value[$index] -cne $ExpectedValues[$index]) {
            return $false
        }
    }
    return $true
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
            $missingRequirements = @(Test-ContentContract -Content $content -MustContainAll @($entry.mustContainAll) -MustMatchAll @($entry.mustMatchAll) -MustContainAnchors @($entry.mustContainAnchors) -MustNotContainAny @($entry.mustNotContainAny))
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

function Convert-WorkspaceGlobToRegex {
    param([Parameter(Mandatory = $true)][string]$Pattern)

    $normalized = $Pattern.Replace('\', '/').Trim()
    $escaped = [regex]::Escape($normalized)
    $escaped = $escaped.Replace('\*\*/', '(?:.*/)?')
    $escaped = $escaped.Replace('\*\*', '.*')
    $escaped = $escaped.Replace('\*', '[^/]*')
    return '^' + $escaped + '$'
}

function Resolve-WorkspaceGlobFiles {
    param(
        [Parameter(Mandatory = $true)][string]$RootPath,
        [Parameter(Mandatory = $true)][string]$Pattern
    )

    $normalizedPattern = $Pattern.Replace('\', '/').Trim()
    if (
        [string]::IsNullOrWhiteSpace($normalizedPattern) -or
        [System.IO.Path]::IsPathRooted($normalizedPattern) -or
        $normalizedPattern -match '(^|/)\.\.(/|$)'
    ) {
        return @()
    }

    $wildcardIndex = $normalizedPattern.IndexOf('*', [System.StringComparison]::Ordinal)
    if ($wildcardIndex -lt 0) {
        $candidate = Join-Path $RootPath $normalizedPattern
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return @([System.IO.Path]::GetFullPath($candidate))
        }
        return @()
    }

    $prefix = $normalizedPattern.Substring(0, $wildcardIndex)
    $lastSlash = $prefix.LastIndexOf('/', [System.StringComparison]::Ordinal)
    $searchRelative = if ($lastSlash -ge 0) { $prefix.Substring(0, $lastSlash) } else { '' }
    $searchRoot = if ([string]::IsNullOrWhiteSpace($searchRelative)) {
        $RootPath
    } else {
        Join-Path $RootPath $searchRelative
    }
    if (-not (Test-Path -LiteralPath $searchRoot -PathType Container)) { return @() }

    $patternRegex = Convert-WorkspaceGlobToRegex -Pattern $normalizedPattern
    return @(
        Get-ChildItem -LiteralPath $searchRoot -File -Recurse -Force |
            Where-Object {
                $relative = [System.IO.Path]::GetRelativePath($RootPath, $_.FullName).Replace('\', '/')
                $relative -cmatch $patternRegex
            } |
            Select-Object -ExpandProperty FullName
    )
}

function Get-ProhibitedMarkdownCodePointClass {
    param([Parameter(Mandatory = $true)][int]$CodePoint)

    if (
        ($CodePoint -ge 0x2190 -and $CodePoint -le 0x21FF) -or
        ($CodePoint -ge 0x27F0 -and $CodePoint -le 0x27FF) -or
        ($CodePoint -ge 0x2900 -and $CodePoint -le 0x297F) -or
        ($CodePoint -ge 0x2B00 -and $CodePoint -le 0x2BFF)
    ) { return 'unicode-arrow-code-point' }

    if ($CodePoint -ge 0x2500 -and $CodePoint -le 0x257F) {
        return 'tree-or-box-drawing-code-point'
    }

    if (
        ($CodePoint -ge 0x1F000 -and $CodePoint -le 0x1FAFF) -or
        ($CodePoint -ge 0x2300 -and $CodePoint -le 0x23FF) -or
        ($CodePoint -ge 0x2600 -and $CodePoint -le 0x27BF) -or
        $CodePoint -in @(0x00A9, 0x00AE, 0x203C, 0x2049, 0x20E3, 0x2122, 0x2139, 0x3030, 0x303D, 0x3297, 0x3299, 0xFE0F)
    ) { return 'emoji-code-point' }

    return $null
}

function Get-MarkdownSymbolOccurrences {
    param([Parameter(Mandatory = $true)][string]$Path)

    $occurrences = @()
    $lineNumber = 0
    foreach ($line in @(Get-Content -LiteralPath $Path)) {
        $lineNumber++
        for ($index = 0; $index -lt $line.Length; $index++) {
            $current = [char]$line[$index]
            if (
                [char]::IsHighSurrogate($current) -and
                $index + 1 -lt $line.Length -and
                [char]::IsLowSurrogate([char]$line[$index + 1])
            ) {
                $codePoint = [char]::ConvertToUtf32($current, [char]$line[++$index])
            } else {
                $codePoint = [int]$current
            }
            $tokenClass = Get-ProhibitedMarkdownCodePointClass -CodePoint $codePoint
            if ($tokenClass) {
                $occurrences += [ordered]@{
                    tokenClass = $tokenClass
                    line = $lineNumber
                    codePoint = ('U+{0:X}' -f $codePoint)
                }
            }
        }

        if ($line -cmatch '^\s*\+(?:[-=]{2,}\+)+\s*$') {
            $occurrences += [ordered]@{
                tokenClass = 'ascii-box-border-line'
                line = $lineNumber
                codePoint = $null
            }
        }
        if ($line -cmatch '^\s*(?:(?:\|\s{3})*)(?:\+--|\\--|`--|\|--)\s+\S.*$') {
            $occurrences += [ordered]@{
                tokenClass = 'ascii-tree-branch-line'
                line = $lineNumber
                codePoint = $null
            }
        }
        if (
            $line -cmatch '^\s*(?:\[[^\]]+\]|\([^\)]+\)|[A-Za-z0-9_.-]+)\s*(?:--+>|==+>|<--+)\s*(?:\[[^\]]+\]|\([^\)]+\)|[A-Za-z0-9_.-]+)(?:\s*(?:--+>|==+>|<--+)\s*(?:\[[^\]]+\]|\([^\)]+\)|[A-Za-z0-9_.-]+))*\s*$' -or
            $line -cmatch '^\s*\[[^\]]+\](?:\s*[-=+]{2,}\s*\[[^\]]+\])+\s*$'
        ) {
            $occurrences += [ordered]@{
                tokenClass = 'ascii-flow-diagram-line'
                line = $lineNumber
                codePoint = $null
            }
        }
    }

    return @($occurrences)
}

function Get-ArtifactMarkdownViolations {
    param([Parameter(Mandatory = $true)][string]$Path)

    $violations = @()
    $seenClasses = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($occurrence in @(Get-MarkdownSymbolOccurrences -Path $Path)) {
        if ($seenClasses.Add([string]$occurrence.tokenClass)) {
            $violations += $occurrence
        }
    }

    return @($violations)
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
$findingStatusLedgerChecks = @()
$agentAuthorityPartitionValid = $false
$artifactMarkdownChecks = @()
$artifactMarkdownPolicyValid = $false

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
        'studio/extensions/**',
        'studio/runtime/finding-status-record.schema.json',
        'docs/README.md',
        'docs/sdd-workspace-repair-inventory-and-update-plan-2026-07-12_zhTW.md'
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

    $requiredFindingStatusLedgerPolicy = [ordered]@{
        path = 'docs/sdd-workspace-repair-inventory-and-update-plan-2026-07-12_zhTW.md'
        documentAuthority = 'informational'
        scope = 'finding_status'
        scopeAuthority = 'source_of_truth'
        selector = 'finding-status-record-v1'
        fenceMarker = '```'
        schemaPath = 'studio/runtime/finding-status-record.schema.json'
        validatorPath = 'studio/scripts/powershell/validate-finding-status-ledger.ps1'
        indexPath = 'docs/README.md'
    }
    $requiredFindingStatusLedgerKeys = @($requiredFindingStatusLedgerPolicy.Keys) + 'allowedStatuses'
    $findingStatusLedgerPolicyValid = (
        $contract.ContainsKey('findingStatusLedger') -and
        (Test-ExactDictionaryKeys -Value $contract.findingStatusLedger -ExpectedKeys $requiredFindingStatusLedgerKeys)
    )
    if ($findingStatusLedgerPolicyValid) {
        foreach ($policyKey in $requiredFindingStatusLedgerPolicy.Keys) {
            if (-not $contract.findingStatusLedger.ContainsKey($policyKey) -or
                $contract.findingStatusLedger[$policyKey] -isnot [string] -or
                $contract.findingStatusLedger[$policyKey] -cne $requiredFindingStatusLedgerPolicy[$policyKey]) {
                $findingStatusLedgerPolicyValid = $false
                break
            }
        }
        $requiredFindingStatuses = @('COMPLETED', 'OPEN', 'DECIDED', 'IN_PROGRESS', 'DISPOSITIONED')
        if (-not (Test-ExactStringArray -Value $contract.findingStatusLedger.allowedStatuses -ExpectedValues $requiredFindingStatuses)) {
            $findingStatusLedgerPolicyValid = $false
        }
    }
    if (-not $findingStatusLedgerPolicyValid) {
        $failures += New-AuditFailure -Category 'contract' `
            -Id 'required-finding-status-ledger-policy-missing' `
            -Message 'findingStatusLedger must bind the informational ledger to the exact finding_status source-of-truth selector, canonical fence marker, schema, validator, index, and status enum.' `
            -Path $paths.SHARED_RUNTIME_CONTRACT
    }

    $requiredAgentAuthorityPartitionKeys = @(
        'canonicalAgentPattern',
        'expectedPatternInputCount',
        'canonicalAdditionalFiles',
        'dependentExcludedFiles',
        'dependentMirrorPattern',
        'expectedCanonicalInputCount',
        'expectedDependentMirrorCount'
    )
    $agentAuthorityPartitionValid = (
        $contract.ContainsKey('agentAuthorityPartition') -and
        (Test-ExactDictionaryKeys -Value $contract.agentAuthorityPartition -ExpectedKeys $requiredAgentAuthorityPartitionKeys) -and
        $contract.agentAuthorityPartition.canonicalAgentPattern -is [string] -and
        $contract.agentAuthorityPartition.canonicalAgentPattern -ceq '.github/agents/*.agent.md' -and
        $contract.agentAuthorityPartition.expectedPatternInputCount -is [long] -and
        [long]$contract.agentAuthorityPartition.expectedPatternInputCount -eq 14 -and
        (Test-ExactStringArray -Value $contract.agentAuthorityPartition.canonicalAdditionalFiles -ExpectedValues @('.github/agents/async-python-reviewer.md')) -and
        (Test-ExactStringArray -Value $contract.agentAuthorityPartition.dependentExcludedFiles -ExpectedValues @('.github/agents/copilot-instructions.md')) -and
        $contract.agentAuthorityPartition.dependentMirrorPattern -is [string] -and
        $contract.agentAuthorityPartition.dependentMirrorPattern -ceq '.claude/agents/*.md' -and
        $contract.agentAuthorityPartition.expectedCanonicalInputCount -is [long] -and
        [long]$contract.agentAuthorityPartition.expectedCanonicalInputCount -eq 15 -and
        $contract.agentAuthorityPartition.expectedDependentMirrorCount -is [long] -and
        [long]$contract.agentAuthorityPartition.expectedDependentMirrorCount -eq 15
    )
    if (-not $agentAuthorityPartitionValid) {
        $failures += New-AuditFailure -Category 'contract' -Id 'agent-authority-partition-invalid' `
            -Message 'agentAuthorityPartition must bind 14 .agent.md inputs plus async-python-reviewer.md, exclude the dependent copilot-instructions adapter, and require 15 dependent Claude mirrors.' `
            -Path $paths.SHARED_RUNTIME_CONTRACT
    }

    $requiredArtifactMarkdownStrictPatterns = @(
        'studio/constitution/constitution.md',
        'AGENTS.md',
        'CLAUDE.md',
        '.github/copilot-instructions.md',
        '.github/agents/copilot-instructions.md',
        'specs/**/*.md',
        'studio/templates/sdd-docs/**/*.md',
        'docs/README.md',
        'docs/project-governance-status.md',
        'docs/project-worktree-parity-governance.md',
        'docs/yuanxi_sdd_pack_strategy_zhTW.md',
        'docs/sdd-workspace-*.md',
        'docs/mainline-updates/*.md',
        'studio/workflows/POLICY.md',
        'studio/extensions/POLICY.md',
        'WORKSPACE_STRUCTURE.md'
    )
    $requiredArtifactMarkdownTokenClasses = @(
        'emoji-code-point',
        'unicode-arrow-code-point',
        'tree-or-box-drawing-code-point',
        'ascii-box-border-line',
        'ascii-tree-branch-line',
        'ascii-flow-diagram-line'
    )
    $requiredSemanticSymbolAllowlist = @(
        'U+2192|flow',
        'U+26A0|risk',
        'U+2705|accepted',
        'U+2713|pass',
        'U+2717|fail',
        'U+274C|invalid',
        'U+1F6AB|prohibited'
    )
    $requiredLegacySymbolAllowances = @(
        '.github/agents/async-python-reviewer.md|U+1F50D|1',
        '.claude/agents/async-python-reviewer.md|U+1F50D|1'
    )
    $requiredArtifactMarkdownPolicyKeys = @(
        'schemaVersion',
        'defaultClassification',
        'strictPathPatterns',
        'semanticExceptionSources',
        'strictlyExcludedFromException',
        'semanticSymbolAllowlist',
        'legacyNonGrowthAllowances',
        'limits',
        'forbiddenTokenClasses'
    )
    $requiredArtifactMarkdownExceptionSourceKeys = @(
        'agentPartitionRef',
        'promptRoot',
        'promptFilesRef',
        'claudeMirrorPartitionRef',
        'claudeMirrorRoot',
        'claudeMirrorFilesRef'
    )
    $artifactMarkdownPolicyValid = (
        $contract.ContainsKey('artifactMarkdownPolicy') -and
        (Test-ExactDictionaryKeys -Value $contract.artifactMarkdownPolicy -ExpectedKeys $requiredArtifactMarkdownPolicyKeys)
    )
    if ($artifactMarkdownPolicyValid) {
        $declaredExceptionSources = $contract.artifactMarkdownPolicy.semanticExceptionSources
        $declaredAllowlist = @()
        $allowlistShapeValid = $contract.artifactMarkdownPolicy.semanticSymbolAllowlist -is [array]
        foreach ($entry in @($contract.artifactMarkdownPolicy.semanticSymbolAllowlist)) {
            if (
                -not (Test-ExactDictionaryKeys -Value $entry -ExpectedKeys @('codePoint', 'meaning')) -or
                $entry.codePoint -isnot [string] -or
                $entry.meaning -isnot [string]
            ) {
                $allowlistShapeValid = $false
                continue
            }
            $declaredAllowlist += '{0}|{1}' -f $entry.codePoint, $entry.meaning
        }
        $declaredLegacyAllowances = @()
        $legacyAllowanceShapeValid = $contract.artifactMarkdownPolicy.legacyNonGrowthAllowances -is [array]
        foreach ($entry in @($contract.artifactMarkdownPolicy.legacyNonGrowthAllowances)) {
            if (
                -not (Test-ExactDictionaryKeys -Value $entry -ExpectedKeys @('path', 'codePoint', 'maxOccurrences')) -or
                $entry.path -isnot [string] -or
                $entry.codePoint -isnot [string] -or
                $entry.maxOccurrences -isnot [long]
            ) {
                $legacyAllowanceShapeValid = $false
                continue
            }
            $declaredLegacyAllowances += '{0}|{1}|{2}' -f $entry.path, $entry.codePoint, [long]$entry.maxOccurrences
        }
        $declaredLimits = $contract.artifactMarkdownPolicy.limits
        $artifactMarkdownPolicyValid = (
            $contract.artifactMarkdownPolicy.schemaVersion -is [long] -and
            [long]$contract.artifactMarkdownPolicy.schemaVersion -eq 1 -and
            $contract.artifactMarkdownPolicy.defaultClassification -is [string] -and
            $contract.artifactMarkdownPolicy.defaultClassification -ceq 'out_of_scope' -and
            (Test-ExactStringArray -Value $contract.artifactMarkdownPolicy.strictPathPatterns -ExpectedValues $requiredArtifactMarkdownStrictPatterns) -and
            (Test-ExactStringArray -Value $contract.artifactMarkdownPolicy.forbiddenTokenClasses -ExpectedValues $requiredArtifactMarkdownTokenClasses) -and
            (Test-ExactDictionaryKeys -Value $declaredExceptionSources -ExpectedKeys $requiredArtifactMarkdownExceptionSourceKeys) -and
            $declaredExceptionSources.agentPartitionRef -is [string] -and
            $declaredExceptionSources.agentPartitionRef -ceq 'agentAuthorityPartition' -and
            $declaredExceptionSources.promptRoot -is [string] -and
            $declaredExceptionSources.promptRoot -ceq '.github/prompts' -and
            $declaredExceptionSources.promptFilesRef -is [string] -and
            $declaredExceptionSources.promptFilesRef -ceq 'requiredPromptStubs' -and
            $declaredExceptionSources.claudeMirrorPartitionRef -is [string] -and
            $declaredExceptionSources.claudeMirrorPartitionRef -ceq 'agentAuthorityPartition' -and
            $declaredExceptionSources.claudeMirrorRoot -is [string] -and
            $declaredExceptionSources.claudeMirrorRoot -ceq '.claude/agents' -and
            $declaredExceptionSources.claudeMirrorFilesRef -is [string] -and
            $declaredExceptionSources.claudeMirrorFilesRef -ceq 'requiredClaudeAgents' -and
            (Test-ExactStringArray -Value $contract.artifactMarkdownPolicy.strictlyExcludedFromException -ExpectedValues @('.github/agents/copilot-instructions.md')) -and
            $allowlistShapeValid -and
            ($declaredAllowlist -join "`n") -ceq ($requiredSemanticSymbolAllowlist -join "`n") -and
            $legacyAllowanceShapeValid -and
            ($declaredLegacyAllowances -join "`n") -ceq ($requiredLegacySymbolAllowances -join "`n") -and
            (Test-ExactDictionaryKeys -Value $declaredLimits -ExpectedKeys @('maxAllowedSymbolOccurrencesPerFile', 'maxDistinctAllowedSymbolsPerFile')) -and
            $declaredLimits.maxAllowedSymbolOccurrencesPerFile -is [long] -and
            [long]$declaredLimits.maxAllowedSymbolOccurrencesPerFile -eq 27 -and
            $declaredLimits.maxDistinctAllowedSymbolsPerFile -is [long] -and
            [long]$declaredLimits.maxDistinctAllowedSymbolsPerFile -eq 3
        )
    }
    if (-not $artifactMarkdownPolicyValid) {
        $failures += New-AuditFailure -Category 'contract' -Id 'artifact-markdown-policy-invalid' `
            -Message 'artifactMarkdownPolicy must preserve the exact strict path set, forbidden classes, contract-referenced exception set, semantic allowlist, non-growth allowance, limits, and strict instruction-adapter exclusion.' `
            -Path $paths.SHARED_RUNTIME_CONTRACT
    }

    $checkedArtifactMarkdownPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($strictPattern in $requiredArtifactMarkdownStrictPatterns) {
        $matchedPaths = @(Resolve-WorkspaceGlobFiles -RootPath $paths.WORKSPACE_ROOT -Pattern $strictPattern)
        if ($matchedPaths.Count -eq 0 -and $strictPattern.IndexOf('*', [System.StringComparison]::Ordinal) -lt 0) {
            $artifactMarkdownPolicyValid = $false
            $failures += New-AuditFailure -Category 'artifact-markdown' -Id 'artifact-markdown-path-unresolved' `
                -Message "Strict artifact Markdown path pattern did not resolve to a current file: $strictPattern" `
                -Path (Join-Path $paths.WORKSPACE_ROOT $strictPattern)
            continue
        }
        foreach ($artifactPath in @($matchedPaths | Sort-Object)) {
            if (-not $checkedArtifactMarkdownPaths.Add($artifactPath)) { continue }
            $violations = @(Get-ArtifactMarkdownViolations -Path $artifactPath)
            $relativeArtifactPath = [System.IO.Path]::GetRelativePath($paths.WORKSPACE_ROOT, $artifactPath).Replace('\', '/')
            $artifactMarkdownChecks += [ordered]@{
                path = $relativeArtifactPath
                classification = 'strict'
                valid = ($violations.Count -eq 0)
                violations = $violations
            }
            if ($violations.Count -gt 0) {
                $artifactMarkdownPolicyValid = $false
                $summaries = @($violations | ForEach-Object { '{0} at line {1}' -f $_.tokenClass, $_.line })
                $failures += New-AuditFailure -Category 'artifact-markdown' -Id 'artifact-markdown-prohibited-content' `
                    -Message ("Strict governed Markdown contains prohibited content: {0}" -f ($summaries -join '; ')) `
                    -Path $artifactPath
            }
        }
    }

    $actualGitHubAgentFiles = if (Test-Path -LiteralPath $paths.SHARED_AGENTS_DIR -PathType Container) {
        @(Get-ChildItem -LiteralPath $paths.SHARED_AGENTS_DIR -File -Force | Select-Object -ExpandProperty Name)
    } else {
        @()
    }
    $patternCanonicalInputs = @($actualGitHubAgentFiles | Where-Object { $_ -like '*.agent.md' } | Sort-Object)
    $additionalCanonicalInputExists = 'async-python-reviewer.md' -cin $actualGitHubAgentFiles
    $dependentAdapterExists = 'copilot-instructions.md' -cin $actualGitHubAgentFiles
    if ($patternCanonicalInputs.Count -ne 14 -or -not $additionalCanonicalInputExists -or -not $dependentAdapterExists) {
        $agentAuthorityPartitionValid = $false
        $failures += New-AuditFailure -Category 'github-agents' -Id 'agent-authority-source-set-mismatch' `
            -Message 'Canonical agent inputs must be exactly 14 *.agent.md files plus async-python-reviewer.md, with copilot-instructions.md retained only as the dependent excluded adapter.' `
            -Path $paths.SHARED_AGENTS_DIR
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
    if ($requiredClaudeAgentFiles.Count -ne 15 -or $actualClaudeAgentFiles.Count -ne 15) {
        $agentAuthorityPartitionValid = $false
        $failures += New-AuditFailure -Category 'claude-agents' -Id 'dependent-mirror-set-mismatch' `
            -Message 'The exact canonical input partition must produce 15 declared dependent Claude mirrors.' `
            -Path $paths.SHARED_CLAUDE_AGENTS_DIR
    }

    $canonicalAgentExceptionFiles = @(
        $requiredCommandFiles +
        @($requiredNonCommandGitHubAgentFiles | Where-Object { $_ -cne 'copilot-instructions.md' }) |
            Sort-Object -Unique
    )
    $semanticExceptionRelativePaths = @(
        @($canonicalAgentExceptionFiles | ForEach-Object { '.github/agents/{0}' -f $_ })
        @($requiredPromptFiles | ForEach-Object { '.github/prompts/{0}' -f $_ })
        @($requiredClaudeAgentFiles | ForEach-Object { '.claude/agents/{0}' -f $_ })
    )
    if (
        $canonicalAgentExceptionFiles.Count -ne 15 -or
        $requiredPromptFiles.Count -ne 13 -or
        $requiredClaudeAgentFiles.Count -ne 15 -or
        '.github/agents/copilot-instructions.md' -cin $semanticExceptionRelativePaths
    ) {
        $artifactMarkdownPolicyValid = $false
        $failures += New-AuditFailure -Category 'contract' -Id 'artifact-markdown-policy-invalid' `
            -Message 'The semantic exception must resolve to exactly 15 canonical agents, 13 declared prompt stubs, and 15 declared Claude mirrors, excluding the instruction adapter.' `
            -Path $paths.SHARED_RUNTIME_CONTRACT
    }

    $semanticAllowedCodePoints = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($allowedEntry in $requiredSemanticSymbolAllowlist) {
        [void]$semanticAllowedCodePoints.Add(($allowedEntry -split '\|', 2)[0])
    }
    $legacySymbolAllowances = @{
        '.github/agents/async-python-reviewer.md' = @{ codePoint = 'U+1F50D'; maxOccurrences = 1 }
        '.claude/agents/async-python-reviewer.md' = @{ codePoint = 'U+1F50D'; maxOccurrences = 1 }
    }
    foreach ($relativeExceptionPath in @($semanticExceptionRelativePaths | Sort-Object)) {
        $exceptionPath = Join-Path $paths.WORKSPACE_ROOT $relativeExceptionPath
        if (-not (Test-Path -LiteralPath $exceptionPath -PathType Leaf)) {
            $artifactMarkdownPolicyValid = $false
            $artifactMarkdownChecks += [ordered]@{
                path = $relativeExceptionPath
                classification = 'semantic_exception'
                valid = $false
                violations = @([ordered]@{ tokenClass = 'path-unresolved'; line = 0; codePoint = $null })
            }
            $failures += New-AuditFailure -Category 'artifact-markdown' -Id 'artifact-markdown-path-unresolved' `
                -Message "Contract-declared semantic exception file is missing: $relativeExceptionPath" `
                -Path $exceptionPath
            continue
        }

        $occurrences = @(Get-MarkdownSymbolOccurrences -Path $exceptionPath)
        $semanticViolations = @()
        foreach ($occurrence in $occurrences) {
            $codePoint = [string]$occurrence.codePoint
            if ([string]::IsNullOrWhiteSpace($codePoint)) {
                $semanticViolations += $occurrence
                continue
            }
            if ($semanticAllowedCodePoints.Contains($codePoint)) { continue }
            $legacyAllowance = $legacySymbolAllowances[$relativeExceptionPath]
            if ($legacyAllowance -and [string]$legacyAllowance.codePoint -ceq $codePoint) { continue }
            $semanticViolations += $occurrence
        }

        $symbolOccurrences = @($occurrences | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.codePoint) })
        $distinctCodePoints = @($symbolOccurrences | ForEach-Object { [string]$_.codePoint } | Sort-Object -Unique)
        if ($symbolOccurrences.Count -gt 27) {
            $semanticViolations += [ordered]@{
                tokenClass = 'semantic-symbol-occurrence-limit'
                line = 0
                codePoint = $null
            }
        }
        if ($distinctCodePoints.Count -gt 3) {
            $semanticViolations += [ordered]@{
                tokenClass = 'semantic-symbol-distinct-limit'
                line = 0
                codePoint = $null
            }
        }

        $legacyAllowance = $legacySymbolAllowances[$relativeExceptionPath]
        if ($legacyAllowance) {
            $legacyCount = @($symbolOccurrences | Where-Object { [string]$_.codePoint -ceq [string]$legacyAllowance.codePoint }).Count
            if ($legacyCount -gt [int]$legacyAllowance.maxOccurrences) {
                $semanticViolations += [ordered]@{
                    tokenClass = 'legacy-symbol-growth'
                    line = 0
                    codePoint = [string]$legacyAllowance.codePoint
                }
            }
        }

        $semanticExceptionValid = ($semanticViolations.Count -eq 0)
        $artifactMarkdownChecks += [ordered]@{
            path = $relativeExceptionPath
            classification = 'semantic_exception'
            valid = $semanticExceptionValid
            symbolOccurrenceCount = $symbolOccurrences.Count
            distinctSymbolCount = $distinctCodePoints.Count
            violations = $semanticViolations
        }
        if (-not $semanticExceptionValid) {
            $artifactMarkdownPolicyValid = $false
            $summaries = @($semanticViolations | ForEach-Object { '{0} at line {1}' -f $_.tokenClass, $_.line })
            $failures += New-AuditFailure -Category 'artifact-markdown' -Id 'artifact-markdown-prohibited-content' `
                -Message ("Semantic-exception Markdown exceeds its bounded symbol policy: {0}" -f ($summaries -join '; ')) `
                -Path $exceptionPath
        }
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

$findingStatusLedgerScript = Join-Path $paths.SHARED_SCRIPTS_DIR 'validate-finding-status-ledger.ps1'
if (-not (Test-Path -LiteralPath $findingStatusLedgerScript -PathType Leaf)) {
    $failures += New-AuditFailure -Category 'finding-status-ledger' -Id 'validator-missing' `
        -Message 'Finding-status ledger validator is missing.' -Path $findingStatusLedgerScript
} else {
    $findingStatusInvocation = Invoke-JsonScriptDetailed -ScriptPath $findingStatusLedgerScript `
        -Arguments @('-WorkspaceRoot', $paths.WORKSPACE_ROOT, '-Json')
    $findingStatusResult = $findingStatusInvocation.OUTPUT
    $findingStatusResultIsObject = $findingStatusResult -is [System.Collections.IDictionary]
    $validFieldIsBoolean = ($findingStatusResultIsObject -and $findingStatusResult.Contains('VALID') -and $findingStatusResult.VALID -is [bool])
    $errorCountIsInteger = ($findingStatusResultIsObject -and $findingStatusResult.Contains('ERROR_COUNT') -and $findingStatusResult.ERROR_COUNT -is [long])
    $errorsIsArray = ($findingStatusResultIsObject -and $findingStatusResult.Contains('ERRORS') -and $findingStatusResult.ERRORS -is [array])
    $warningCountIsInteger = ($findingStatusResultIsObject -and $findingStatusResult.Contains('WARNING_COUNT') -and $findingStatusResult.WARNING_COUNT -is [long])
    $warningsIsArray = ($findingStatusResultIsObject -and $findingStatusResult.Contains('WARNINGS') -and $findingStatusResult.WARNINGS -is [array])
    $findingCountIsInteger = ($findingStatusResultIsObject -and $findingStatusResult.Contains('FINDING_COUNT') -and $findingStatusResult.FINDING_COUNT -is [long])
    $latestRevisionIsInteger = ($findingStatusResultIsObject -and $findingStatusResult.Contains('LATEST_REVISION') -and $findingStatusResult.LATEST_REVISION -is [long])
    $errorCountMatchesArray = ($errorCountIsInteger -and $errorsIsArray -and [long]$findingStatusResult.ERROR_COUNT -eq @($findingStatusResult.ERRORS).Count)
    $warningCountMatchesArray = ($warningCountIsInteger -and $warningsIsArray -and [long]$findingStatusResult.WARNING_COUNT -eq @($findingStatusResult.WARNINGS).Count)
    $findingStatusValid = (
        $findingStatusInvocation.EXIT_CODE -eq 0 -and
        $validFieldIsBoolean -and $findingStatusResult.VALID -eq $true -and
        $errorCountIsInteger -and $findingStatusResult.ERROR_COUNT -eq 0 -and
        $errorsIsArray -and $errorCountMatchesArray -and @($findingStatusResult.ERRORS).Count -eq 0 -and
        $warningCountIsInteger -and $findingStatusResult.WARNING_COUNT -eq 0 -and
        $warningsIsArray -and $warningCountMatchesArray -and @($findingStatusResult.WARNINGS).Count -eq 0 -and
        $findingCountIsInteger -and $findingStatusResult.FINDING_COUNT -gt 0 -and
        $latestRevisionIsInteger -and $findingStatusResult.LATEST_REVISION -gt 0
    )
    $findingStatusLedgerChecks += [ordered]@{
        validatorPath = $findingStatusLedgerScript
        valid = $findingStatusValid
        validFieldIsBoolean = $validFieldIsBoolean
        errorCountIsInteger = $errorCountIsInteger
        errorsIsArray = $errorsIsArray
        warningCountIsInteger = $warningCountIsInteger
        warningsIsArray = $warningsIsArray
        errorCountMatchesArray = $errorCountMatchesArray
        warningCountMatchesArray = $warningCountMatchesArray
        findingCountIsInteger = $findingCountIsInteger
        latestRevisionIsInteger = $latestRevisionIsInteger
        exitCode = [int]$findingStatusInvocation.EXIT_CODE
        findingCount = if ($findingCountIsInteger) { [long]$findingStatusResult.FINDING_COUNT } else { $null }
        latestRevision = if ($latestRevisionIsInteger) { [long]$findingStatusResult.LATEST_REVISION } else { $null }
        errors = if ($errorsIsArray) { @($findingStatusResult.ERRORS) } else { @() }
    }
    if ($warningsIsArray) {
        foreach ($childWarning in @($findingStatusResult.WARNINGS)) {
            $warningMessage = if ($childWarning -is [string]) { [string]$childWarning } else { [string]$childWarning.message }
            if (-not [string]::IsNullOrWhiteSpace($warningMessage)) { $warnings += $warningMessage }
        }
    }
    if (-not $findingStatusValid) {
        $childErrors = if ($errorsIsArray) { @($findingStatusResult.ERRORS) } else { @() }
        if ($childErrors.Count -eq 0) {
            $failures += New-AuditFailure -Category 'finding-status-ledger' -Id 'validation-failed' `
                -Message 'Finding-status ledger validation output was missing, malformed, or internally inconsistent.' `
                -Path $findingStatusLedgerScript
        } else {
            foreach ($childError in $childErrors) {
                $childCategory = [string]$childError.category
                if ([string]::IsNullOrWhiteSpace($childCategory)) { $childCategory = 'validation-failed' }
                $childPath = if ($childError.path) { Join-Path $paths.WORKSPACE_ROOT ([string]$childError.path) } else { $findingStatusLedgerScript }
                $failures += New-AuditFailure -Category 'finding-status-ledger' -Id $childCategory `
                    -Message ([string]$childError.message) -Path $childPath
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
    AGENT_AUTHORITY_PARTITION_VALID = $agentAuthorityPartitionValid
    ARTIFACT_MARKDOWN_POLICY_VALID = $artifactMarkdownPolicyValid
    ARTIFACT_MARKDOWN_CHECKS = @($artifactMarkdownChecks | Sort-Object path)
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
    FINDING_STATUS_LEDGER_CHECKS = $findingStatusLedgerChecks
    FINDING_STATUS_LEDGER_VALID = if ($findingStatusLedgerChecks.Count -gt 0) { [bool]$findingStatusLedgerChecks[0].valid } else { $false }
    FINDING_STATUS_LEDGER_COUNT = if ($findingStatusLedgerChecks.Count -gt 0 -and $null -ne $findingStatusLedgerChecks[0].findingCount) { [long]$findingStatusLedgerChecks[0].findingCount } else { 0 }
    FINDING_STATUS_LEDGER_REVISION = if ($findingStatusLedgerChecks.Count -gt 0 -and $null -ne $findingStatusLedgerChecks[0].latestRevision) { [long]$findingStatusLedgerChecks[0].latestRevision } else { 0 }
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
