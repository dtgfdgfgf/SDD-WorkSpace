#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Generates studio/runtime/impact-registry.json from built-in rules and local drift-governance metadata.

.DESCRIPTION
    This script produces the impact registry deterministically from two sources:

    1. Built-in path-pattern rules (cover most governed documents)
    2. drift-governance comment blocks embedded in individual files (overrides)

    The generated output replaces manual maintenance of impact-registry.json.
    The registry is a derived artifact; this script and the embedded metadata are the sources of truth.

    drift-governance metadata format (HTML comment in .md files):

        <!-- drift-governance
        authority: source_of_truth
        domain: governance
        impact_on_change:
          - target: README.md
            level: must_update
            reason: Must reflect current governance state
        -->

    drift-governance metadata format (block comment in .ps1 files):

        # Use opening: less-than hash drift-governance
        # Use closing: hash greater-than
        # Example:
        #   authority: source_of_truth
        #   domain: hooks

.PARAMETER Write
    Write the generated registry to studio/runtime/impact-registry.json.
    Without this flag, the script runs in dry-run mode and outputs to stdout.

.PARAMETER Compare
    Compare the generated registry with the current file and report differences.

.PARAMETER Help
    Show this help message.

.EXAMPLE
    ./generate-impact-registry.ps1                  # Dry-run: print to stdout
    ./generate-impact-registry.ps1 -Compare         # Show diff vs current file
    ./generate-impact-registry.ps1 -Write           # Overwrite the registry file
#>

[CmdletBinding()]
param(
    [switch]$Write,
    [switch]$Compare,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    Get-Help $PSCommandPath -Detailed
    exit 0
}

$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$registryPath = Join-Path $workspaceRoot 'studio/runtime/impact-registry.json'

# ============================================================
# Built-in document authority rules
# ============================================================
# These cover all governed documents. Individual files may override
# via drift-governance comment blocks.

$builtinDocumentAuthority = @(
    @{ path = 'studio/constitution/constitution.md';       authority = 'source_of_truth'; domain = 'governance';           description = 'Highest governance authority for all projects and workflows' }
    @{ path = 'studio/runtime/shared-runtime-contract.json'; authority = 'source_of_truth'; domain = 'runtime_verification'; description = 'Machine-verifiable invariants for all governance requirements' }
    @{ path = 'studio/runtime/impact-registry.json';       authority = 'source_of_truth'; domain = 'routing';              description = 'Change-to-document conditional impact routing rules' }
    @{ path = '.github/agents/*.agent.md';                 authority = 'source_of_truth'; domain = 'agent_runtime';        description = 'Copilot agent definitions, canonical source for agent behavior' }
    @{ path = 'studio/templates/sdd-docs/*.md';            authority = 'source_of_truth'; domain = 'templates';            description = 'Canonical document templates for SDD workflow' }
    @{ path = '.githooks/pre-commit.ps1';                  authority = 'source_of_truth'; domain = 'hooks';                description = 'Commit-time validation logic' }
    @{ path = 'studio/scripts/powershell/*.ps1';           authority = 'source_of_truth'; domain = 'scripts';              description = 'Studio automation and runtime verification' }
    @{ path = 'specs/<feature>/spec.md';                   authority = 'source_of_truth'; domain = 'feature';              description = 'Feature requirements, per-feature source of truth' }
    @{ path = 'specs/<feature>/readiness/**/*.md';         authority = 'source_of_truth'; domain = 'feature';              description = 'Readiness and ECI governance artifacts, per-feature' }
    @{ path = 'docs/project-worktree-parity-governance.md'; authority = 'source_of_truth'; domain = 'governance';          description = 'Worktree parity obligations for derived worktrees' }
    @{ path = '.claude/agents/*.md';                       authority = 'dependent';       domain = 'agent_runtime';        description = 'Claude agent definitions, seeded from .github/agents/' }
    @{ path = 'AGENTS.md';                                  authority = 'dependent';       domain = 'agent_context';        description = 'Codex and Copilot CLI runtime adapter, reflects constitution rules' }
    @{ path = 'CLAUDE.md';                                  authority = 'dependent';       domain = 'agent_context';        description = 'Claude Code runtime adapter, reflects constitution rules' }
    @{ path = '.github/copilot-instructions.md';           authority = 'dependent';       domain = 'agent_context';        description = 'Copilot project context, reflects constitution rules' }
    @{ path = 'specs/<feature>/plan.md';                   authority = 'dependent';       domain = 'feature';              description = 'Technical plan, depends on spec, readiness, intent-ledger' }
    @{ path = 'specs/<feature>/tasks.md';                  authority = 'dependent';       domain = 'feature';              description = 'Task decomposition, depends on plan' }
    @{ path = 'specs/<feature>/intent-ledger.md';          authority = 'dependent';       domain = 'feature';              description = 'Scope compression tracker, depends on spec and readiness' }
    @{ path = 'README.md';                                 authority = 'informational';   domain = 'overview';             description = 'Workspace overview, must reflect current governance state' }
    @{ path = 'WORKSPACE_STRUCTURE.md';                    authority = 'informational';   domain = 'structure';            description = 'Architecture documentation, must reflect current directory layout' }
    @{ path = 'studio/QUICKSTART.md';                      authority = 'informational';   domain = 'onboarding';           description = 'Chinese-language quickstart onboarding guide' }
    @{ path = 'studio/SDD-QUICKSTART-GUIDE.md';            authority = 'informational';   domain = 'onboarding';           description = 'Comprehensive SDD methodology guide' }
    @{ path = 'docs/mainline-updates/*.md';                authority = 'informational';   domain = 'change_tracking';      description = 'Merge explanation notes and index' }
)

# ============================================================
# Built-in impact routing rules
# ============================================================
# These define the default routing for each change type.
# Individual files may add additional rules via drift-governance
# impact_on_change blocks.

$builtinImpactRouting = @(
    @{
        changeType  = 'constitution_change'
        trigger     = 'studio/constitution/constitution.md'
        description = 'Any change to the studio constitution'
        rules       = @(
            @{ target = 'studio/runtime/shared-runtime-contract.json'; impact = 'must_review'; reason = 'Constitution invariants may need new or updated mustContainAll entries' }
            @{ target = 'studio/runtime/impact-registry.json';        impact = 'maybe_review'; reason = 'Authority classification or routing rules may need adjustment' }
            @{ target = '.github/agents/*.agent.md';                  impact = 'must_review'; reason = 'Agent behavior semantics may be affected by new governance rules' }
            @{ target = '.claude/agents/*.md';                        impact = 'must_review'; reason = 'Claude agents mirror Copilot agents and must reflect updated semantics' }
            @{ target = 'studio/templates/sdd-docs/*.md';             impact = 'must_review'; reason = 'Templates may need new sections or updated guidance' }
            @{ target = 'README.md';                                  impact = 'must_update'; reason = 'Must reflect current governance state and workflow sequence' }
            @{ target = 'WORKSPACE_STRUCTURE.md';                     impact = 'maybe_review'; reason = 'Structure doc may need updates if paths or conventions changed' }
            @{ target = 'studio/QUICKSTART.md';                       impact = 'must_update'; reason = 'Must reflect constitution rules in quickstart form' }
            @{ target = 'studio/SDD-QUICKSTART-GUIDE.md';             impact = 'must_update'; reason = 'Must reflect updated methodology rules' }
            @{ target = 'AGENTS.md';                                  impact = 'must_review'; reason = 'Codex and Copilot CLI adapter may need updated governance bootstrap metadata' }
            @{ target = 'CLAUDE.md';                                  impact = 'must_review'; reason = 'Claude Code adapter may need updated governance bootstrap metadata' }
            @{ target = '.github/copilot-instructions.md';            impact = 'must_review'; reason = 'Copilot context may need updated governance references' }
            @{ target = '.githooks/pre-commit.ps1';                   impact = 'maybe_review'; reason = 'Validation logic may need updates for new governance rules' }
        )
    }
    @{
        changeType  = 'contract_change'
        trigger     = 'studio/runtime/shared-runtime-contract.json'
        description = 'Any change to the shared runtime contract'
        rules       = @(
            @{ target = '.githooks/pre-commit.ps1';                              impact = 'must_review'; reason = 'Hook consumes contract for sharedGatePaths and audit invocation' }
            @{ target = 'studio/scripts/powershell/check-speckit-runtime.ps1';   impact = 'must_review'; reason = 'Audit script validates contract invariants' }
            @{ target = 'studio/constitution/constitution.md';                   impact = 'maybe_review'; reason = 'Contract changes may reflect constitution-level decisions' }
        )
    }
    @{
        changeType  = 'agent_change'
        trigger     = '.github/agents/*.agent.md'
        description = 'Any change to Copilot runtime agent definitions'
        rules       = @(
            @{ target = 'studio/runtime/shared-runtime-contract.json'; impact = 'must_review'; reason = 'Agent invariants may need updated mustContainAll entries' }
            @{ target = '.claude/agents/*.md';                         impact = 'must_update'; reason = 'Claude mirrors must stay in sync with Copilot source' }
            @{ target = 'studio/constitution/constitution.md';         impact = 'reference' }
            @{ target = 'README.md';                                   impact = 'reference' }
        )
    }
    @{
        changeType  = 'template_change'
        trigger     = 'studio/templates/sdd-docs/*.md'
        description = 'Any change to SDD document templates'
        rules       = @(
            @{ target = 'studio/runtime/shared-runtime-contract.json'; impact = 'must_review'; reason = 'Template invariants may need updated mustContainAll entries' }
            @{ target = '.github/agents/*.agent.md';                   impact = 'maybe_review'; reason = 'Agents may reference template structure or field names' }
            @{ target = 'studio/constitution/constitution.md';         impact = 'maybe_review'; reason = 'Template changes may warrant constitution-level documentation' }
            @{ target = 'README.md';                                   impact = 'reference' }
        )
    }
    @{
        changeType  = 'hook_change'
        trigger     = '.githooks/'
        description = 'Any change to git hook validation logic'
        rules       = @(
            @{ target = 'studio/runtime/shared-runtime-contract.json'; impact = 'must_review'; reason = 'Hook invariants may need updated entries' }
            @{ target = 'studio/constitution/constitution.md';         impact = 'maybe_review'; reason = 'Hook behavior changes may need governance documentation' }
            @{ target = 'studio/QUICKSTART.md';                        impact = 'maybe_review'; reason = 'Quickstart may reference hook behavior' }
        )
    }
    @{
        changeType  = 'script_change'
        trigger     = 'studio/scripts/powershell/*.ps1'
        description = 'Any change to studio PowerShell automation scripts'
        rules       = @(
            @{ target = 'studio/runtime/shared-runtime-contract.json'; impact = 'must_review'; reason = 'Script invariants may need updated entries' }
            @{ target = '.githooks/pre-commit.ps1';                    impact = 'maybe_review'; reason = 'Pre-commit invokes check-speckit-runtime.ps1' }
        )
    }
    @{
        changeType  = 'spec_change'
        trigger     = 'specs/<feature>/spec.md'
        description = 'Any change to feature spec that affects requirements referenced in downstream artifacts'
        rules       = @(
            @{ target = 'specs/<feature>/readiness/readiness-assessment.md'; impact = 'must_review'; reason = 'Readiness classification may change if requirements changed' }
            @{ target = 'specs/<feature>/intent-ledger.md';                 impact = 'must_review'; reason = 'Scope compression tracking may need new or updated rows' }
            @{ target = 'specs/<feature>/plan.md';                          impact = 'must_update'; reason = 'Plan must reflect current spec requirements' }
            @{ target = 'specs/<feature>/tasks.md';                         impact = 'must_update'; reason = 'Tasks must reflect current plan derived from spec' }
            @{ target = 'README.md';                                        impact = 'maybe_review'; reason = 'Surface truthfulness (constitution Section 12): umbrella feature names with shrunken coverage MUST be disclosed to readers' }
            @{ target = 'studio/QUICKSTART.md';                             impact = 'maybe_review'; reason = 'Surface truthfulness: outward-facing quickstart MUST not over-claim against compressed core scope' }
        )
    }
    @{
        changeType  = 'readiness_change'
        trigger     = 'specs/<feature>/readiness/readiness-assessment.md'
        description = 'Any change to a feature readiness assessment; downstream planning artifacts must be revalidated'
        rules       = @(
            @{ target = 'specs/<feature>/intent-ledger.md';                       impact = 'must_review'; reason = 'Readiness classification changes may surface new represented/deferred/dropped core items' }
            @{ target = 'specs/<feature>/plan.md';                                impact = 'must_update'; reason = 'Plan must reflect the latest readiness primary status and Intent Recovery Obligations' }
            @{ target = 'specs/<feature>/tasks.md';                               impact = 'must_update'; reason = 'Tasks may need restructuring when readiness gates change' }
            @{ target = 'specs/<feature>/readiness/eci/eci-assessment.md';        impact = 'maybe_review'; reason = 'ECI dossier may be referenced as governed input on readiness re-entry' }
        )
    }
    @{
        changeType  = 'worktree_parity_change'
        trigger     = 'docs/project-worktree-parity-governance.md'
        description = 'Changes to consumer-project derived worktree parity governance; ripple to bootstrap and init scripts'
        rules       = @(
            @{ target = 'studio/scripts/powershell/new-project-worktree.ps1'; impact = 'must_update'; reason = 'Worktree bootstrap script must implement the parity rules' }
            @{ target = 'studio/scripts/powershell/init-project.ps1';         impact = 'must_review'; reason = 'Project init must produce baseline parity that derived worktrees inherit' }
            @{ target = 'studio/scripts/powershell/init-practice.ps1';        impact = 'must_review'; reason = 'Practice init must produce baseline parity that derived worktrees inherit' }
            @{ target = 'studio/runtime/shared-runtime-contract.json';        impact = 'maybe_review'; reason = 'Contract sharedGatePaths and runtime invariants may need updates' }
            @{ target = 'studio/QUICKSTART.md';                               impact = 'maybe_review'; reason = 'Quickstart may reference worktree behavior' }
            @{ target = 'studio/SDD-QUICKSTART-GUIDE.md';                     impact = 'maybe_review'; reason = 'SDD guide may reference worktree behavior' }
            @{ target = 'WORKSPACE_STRUCTURE.md';                             impact = 'maybe_review'; reason = 'Workspace structure overview may need updated parity description' }
        )
    }
    @{
        changeType  = 'doc_change'
        trigger     = 'README.md|WORKSPACE_STRUCTURE.md|studio/QUICKSTART.md|studio/SDD-QUICKSTART-GUIDE.md'
        description = 'Changes to informational docs that may contain invariant text'
        rules       = @(
            @{ target = 'studio/runtime/shared-runtime-contract.json'; impact = 'maybe_review'; reason = 'Informational docs have docInvariant entries; changing invariant text breaks the contract' }
        )
    }
    @{
        changeType  = 'adapter_change'
        trigger     = 'AGENTS.md|CLAUDE.md|.github/copilot-instructions.md'
        description = 'Runtime adapter changes; all three must stay synchronized via the generated bootstrap block'
        rules       = @(
            @{ target = 'AGENTS.md';                                              impact = 'must_update'; reason = 'All three adapters share the same generated governance bootstrap block' }
            @{ target = 'CLAUDE.md';                                              impact = 'must_update'; reason = 'All three adapters share the same generated governance bootstrap block' }
            @{ target = '.github/copilot-instructions.md';                        impact = 'must_update'; reason = 'All three adapters share the same generated governance bootstrap block' }
            @{ target = 'studio/runtime/shared-runtime-contract.json';            impact = 'maybe_review'; reason = 'Adapter edits may affect bootstrap-related invariants' }
            @{ target = 'studio/scripts/powershell/sync-agent-bootstrap.ps1';     impact = 'reference' }
            @{ target = 'studio/scripts/powershell/check-agent-bootstrap.ps1';    impact = 'reference' }
        )
    }
    @{
        changeType  = 'registry_change'
        trigger     = 'studio/runtime/impact-registry.json'
        description = 'Any change to the impact registry itself'
        rules       = @(
            @{ target = 'studio/constitution/constitution.md';         impact = 'maybe_review'; reason = 'Authority classification in constitution should stay aligned with registry' }
            @{ target = 'studio/runtime/shared-runtime-contract.json'; impact = 'maybe_review'; reason = 'Contract sharedGatePaths may need alignment' }
        )
    }
)

# ============================================================
# Frontmatter reader
# ============================================================

function Read-DriftGovernanceBlock {
    # Reads a drift-governance metadata block from a file.
    # Supports HTML comment format in .md and PS block comment format in .ps1.
    # Returns hashtable with parsed fields, or $null if no block found.
    param([string]$FilePath)

    if (-not (Test-Path -LiteralPath $FilePath)) { return $null }

    $content = Get-Content -LiteralPath $FilePath -Raw -ErrorAction SilentlyContinue
    if (-not $content) { return $null }

    $block = $null

    # Try HTML comment format
    if ($content -match '(?s)<!--\s*drift-governance\s*\r?\n(.*?)-->') {
        $block = $Matches[1]
    }
    # Try PowerShell block comment format
    elseif ($content -match '(?s)<#\s*drift-governance\s*\r?\n(.*?)#>') {
        $block = $Matches[1]
    }

    if (-not $block) { return $null }

    # Simple YAML-like parser for our limited schema
    $result = @{}
    $currentKey = $null
    $currentList = $null
    $currentItem = $null

    foreach ($line in ($block -split '\r?\n')) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
        $isIndented = $line -match '^\s'

        # Top-level key: value (not indented, not inside a list item)
        if (-not $isIndented -and $trimmed -match '^(\w+):\s*(.+)$' -and -not $trimmed.StartsWith('-')) {
            if ($null -ne $currentList -and $currentItem) {
                [void]$currentList.Add($currentItem)
                $currentItem = $null
            }
            $result[$Matches[1]] = $Matches[2].Trim()
            $currentKey = $Matches[1]
            $currentList = $null
        }
        # Top-level key with list value (key:) — not indented
        elseif (-not $isIndented -and $trimmed -match '^(\w+):\s*$') {
            if ($null -ne $currentList -and $currentItem) {
                [void]$currentList.Add($currentItem)
                $currentItem = $null
            }
            $currentKey = $Matches[1]
            $currentList = [System.Collections.ArrayList]::new()
            $result[$currentKey] = $currentList
        }
        # List item start
        elseif ($trimmed -match '^-\s+(\w+):\s*(.+)$') {
            if ($null -ne $currentList -and $currentItem) {
                [void]$currentList.Add($currentItem)
            }
            $currentItem = @{ $Matches[1] = $Matches[2].Trim() }
        }
        # Continuation of list item (indented key: value while building item)
        elseif ($isIndented -and $trimmed -match '^(\w+):\s*(.+)$' -and $currentItem) {
            $currentItem[$Matches[1]] = $Matches[2].Trim()
        }
    }

    if ($null -ne $currentList -and $currentItem) {
        [void]$currentList.Add($currentItem)
    }

    return $result
}

# ============================================================
# Scan workspace for drift-governance overrides
# ============================================================

function Get-FrontmatterOverrides {
    $overrides = @{}

    # Scan .md files with drift-governance blocks
    $mdFiles = @(Get-ChildItem -Path $workspaceRoot -Filter '*.md' -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/](node_modules|\.git|projects|learning|resources|merged)[\\/]|[\\/]studio[\\/]upstream[\\/]' })

    foreach ($file in $mdFiles) {
        $meta = Read-DriftGovernanceBlock -FilePath $file.FullName
        if ($meta) {
            $relPath = $file.FullName.Substring($workspaceRoot.Length + 1) -replace '\\', '/'
            $overrides[$relPath] = $meta
        }
    }

    # Scan .ps1 files
    $ps1Files = @(Get-ChildItem -Path $workspaceRoot -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/](node_modules|\.git|projects|learning|resources|merged)[\\/]|[\\/]studio[\\/]upstream[\\/]' })

    foreach ($file in $ps1Files) {
        $meta = Read-DriftGovernanceBlock -FilePath $file.FullName
        if ($meta) {
            $relPath = $file.FullName.Substring($workspaceRoot.Length + 1) -replace '\\', '/'
            $overrides[$relPath] = $meta
        }
    }

    return $overrides
}

# ============================================================
# Build registry
# ============================================================

function Build-Registry {
    param([hashtable]$Overrides)

    # Build documentAuthority: start with builtins, apply overrides
    $docAuthority = @()
    foreach ($entry in $builtinDocumentAuthority) {
        $item = [ordered]@{
            path        = $entry.path
            authority   = $entry.authority
            domain      = $entry.domain
            description = $entry.description
        }

        # Check if any override matches this path exactly
        if ($Overrides.Contains($entry.path)) {
            $meta = $Overrides[$entry.path]
            if ($meta.authority)   { $item.authority   = $meta.authority }
            if ($meta.domain)      { $item.domain      = $meta.domain }
            if ($meta.description) { $item.description = $meta.description }
        }

        $docAuthority += $item
    }

    # Build impactRouting: start with builtins, merge override impact_on_change
    $impactRouting = @()
    foreach ($route in $builtinImpactRouting) {
        $routeItem = [ordered]@{
            changeType  = $route.changeType
            trigger     = $route.trigger
            description = $route.description
            rules       = @()
        }

        foreach ($rule in $route.rules) {
            $ruleItem = [ordered]@{ target = $rule.target; impact = $rule.impact }
            if ($rule.reason) { $ruleItem.reason = $rule.reason }
            $routeItem.rules += $ruleItem
        }

        # Check if the trigger file has impact_on_change overrides
        $triggerPaths = @($route.trigger -split '\|' | ForEach-Object { $_.Trim() })
        foreach ($tp in $triggerPaths) {
            if ($Overrides.Contains($tp) -and $Overrides[$tp].impact_on_change) {
                foreach ($override in $Overrides[$tp].impact_on_change) {
                    # Check if this target already exists in rules
                    $existing = $routeItem.rules | Where-Object { $_.target -eq $override.target }
                    if ($existing) {
                        # Override the existing rule
                        $existing.impact = $override.level
                        if ($override.reason) { $existing.reason = $override.reason }
                    } else {
                        # Add new rule
                        $newRule = [ordered]@{ target = $override.target; impact = $override.level }
                        if ($override.reason) { $newRule.reason = $override.reason }
                        $routeItem.rules += $newRule
                    }
                }
            }
        }

        $impactRouting += $routeItem
    }

    return [ordered]@{
        documentAuthority = $docAuthority
        impactRouting     = $impactRouting
    }
}

# ============================================================
# JSON serialization
# ============================================================

function ConvertTo-RegistryJson {
    param([object]$Registry)

    # Use ConvertTo-Json with sufficient depth
    return $Registry | ConvertTo-Json -Depth 10
}

# ============================================================
# Normalize JSON for comparison
# ============================================================

function Get-NormalizedJson {
    param([string]$JsonString)

    # Parse and re-serialize to normalize formatting.
    # Use ConvertFrom-Json WITHOUT -AsHashtable to preserve key order (PSObject),
    # because hashtable key ordering is non-deterministic and causes false diffs.
    try {
        $obj = $JsonString | ConvertFrom-Json
        return $obj | ConvertTo-Json -Depth 10 -Compress
    } catch {
        return $JsonString.Trim()
    }
}

# ============================================================
# Main
# ============================================================

$overrides = Get-FrontmatterOverrides
$registry = Build-Registry -Overrides $overrides
$generatedJson = ConvertTo-RegistryJson -Registry $registry

if ($Compare) {
    if (-not (Test-Path -LiteralPath $registryPath)) {
        Write-Host 'Current registry file does not exist. Generated output would be new.' -ForegroundColor Yellow
        Write-Output $generatedJson
        exit 1
    }

    $currentJson = Get-Content -LiteralPath $registryPath -Raw
    $normalizedCurrent   = Get-NormalizedJson -JsonString $currentJson
    $normalizedGenerated = Get-NormalizedJson -JsonString $generatedJson

    if ($normalizedCurrent -eq $normalizedGenerated) {
        Write-Host 'Registry is fresh: generated output matches current file.' -ForegroundColor Green
        exit 0
    } else {
        Write-Host 'Registry is stale: generated output differs from current file.' -ForegroundColor Yellow
        Write-Host ''
        Write-Host '--- Overrides found ---' -ForegroundColor Cyan
        if ($overrides.Count -eq 0) {
            Write-Host '  (none)'
        } else {
            foreach ($key in $overrides.Keys) {
                Write-Host "  $key"
            }
        }
        Write-Host ''
        Write-Host 'Run with -Write to update the registry file.' -ForegroundColor Yellow
        exit 1
    }
}

if ($Write) {
    $generatedJson | Set-Content -LiteralPath $registryPath -Encoding utf8NoBOM -NoNewline
    # Append a final newline for POSIX compliance
    [System.IO.File]::AppendAllText($registryPath, "`n")
    Write-Host "Registry written to: $registryPath" -ForegroundColor Green

    if ($overrides.Count -gt 0) {
        Write-Host "Overrides applied from:" -ForegroundColor Cyan
        foreach ($key in $overrides.Keys) {
            Write-Host "  $key"
        }
    }
    exit 0
}

# Default: dry-run, output to stdout
Write-Output $generatedJson
