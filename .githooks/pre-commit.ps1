#!/usr/bin/env pwsh

#Requires -Version 7.0
<#
.SYNOPSIS
    Pre-commit hook for SDD document validation and commit message format checking.

.DESCRIPTION
    This hook validates:
    1. spec.md files contain required sections
    2. readiness and ECI dossier artifacts contain required governance fields
    3. plan.md files contain required sections
    4. tasks.md files follow checklist format
    5. Commit messages follow Conventional Commits format
    6. Impact routing advisory via impact-registry.json (warning only)
    7. Staged paths do not enter a protected personal-data directory

.NOTES
    To enable: git config core.hooksPath .githooks
    To bypass: git commit --no-verify
#>

$ErrorActionPreference = 'Continue'
$script:hasErrors = $false

# Git emits raw UTF-8 bytes on stdout. Force UTF-8 decoding: when the inherited console
# codepage is not UTF-8 (e.g. zh-TW CP950), the default [Console]::OutputEncoding garbles
# non-ASCII staged paths such as 履歷/ into deterministic mojibake, which silently
# fail-opens the personal-data path gate below.
try {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    $OutputEncoding = [System.Text.UTF8Encoding]::new($false)
} catch {
    Write-Host '[ERROR] Unable to force UTF-8 decoding of git output; staged paths cannot be evaluated safely.' -ForegroundColor Red
    exit 1
}

$script:workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$script:repoRoot = (& git rev-parse --show-toplevel 2>$null)
if ($LASTEXITCODE -ne 0 -or -not $script:repoRoot) {
    Write-Host '[ERROR] Unable to resolve Git repository root for pre-commit validation.' -ForegroundColor Red
    exit 1
}
$script:repoRoot = (Resolve-Path -LiteralPath $script:repoRoot).Path
$script:isWorkspaceRepo = ($script:repoRoot -eq $script:workspaceRoot)
$script:sharedRuntimeContractPath = Join-Path $script:workspaceRoot 'studio/runtime/shared-runtime-contract.json'
$script:sharedRuntimeAuditScript = Join-Path $script:workspaceRoot 'studio/scripts/powershell/check-speckit-runtime.ps1'

function Write-HookError {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
    $script:hasErrors = $true
}

function Write-HookWarning {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-HookSuccess {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-HookInfo {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Convert-ToRepoRelativePath {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $Path
    }

    return ($Path -replace '\\', '/') -replace '^\.\/', ''
}

function Get-ProtectedPersonalDataPaths {
    param([string[]]$Paths)

    $matches = foreach ($path in @($Paths)) {
        $normalizedPath = Convert-ToRepoRelativePath -Path $path
        if ($normalizedPath -match '(^|/)履歷(/|$)') {
            $normalizedPath
        }
    }

    return @($matches | Sort-Object -Unique)
}

function Get-SharedGatePaths {
    if (-not (Test-Path -LiteralPath $script:sharedRuntimeContractPath)) {
        return @()
    }

    try {
        $contract = Get-Content -LiteralPath $script:sharedRuntimeContractPath -Raw | ConvertFrom-Json -AsHashtable
        return @($contract.sharedGatePaths | ForEach-Object { Convert-ToRepoRelativePath -Path ([string]$_) })
    } catch {
        Write-HookError "Unable to read shared runtime contract: $($script:sharedRuntimeContractPath)"
        return @()
    }
}

function Test-IsSharedGateHit {
    param(
        [string]$Path,
        [string[]]$GatePaths
    )

    $normalizedPath = Convert-ToRepoRelativePath -Path $Path
    foreach ($gatePath in $GatePaths) {
        if ($gatePath.EndsWith('/**', [System.StringComparison]::Ordinal)) {
            $recursiveGatePrefix = $gatePath.Substring(0, $gatePath.Length - 2)
            if (
                $normalizedPath.Length -gt $recursiveGatePrefix.Length -and
                $normalizedPath.StartsWith($recursiveGatePrefix, [System.StringComparison]::OrdinalIgnoreCase)
            ) {
                return $true
            }
        } elseif ($gatePath.EndsWith('/')) {
            if ($normalizedPath.StartsWith($gatePath, [System.StringComparison]::OrdinalIgnoreCase)) {
                return $true
            }
        } elseif ($normalizedPath.Equals($gatePath, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }

    return $false
}

function Get-NonNoteSharedLayerFiles {
    param(
        [AllowEmptyCollection()]
        [string[]]$SharedLayerFiles
    )

    return @($SharedLayerFiles | Where-Object {
        $normalized = Convert-ToRepoRelativePath -Path $_
        -not ($normalized -like 'docs/mainline-updates/*')
    })
}

function Get-StagedMainlineUpdateNotes {
    param(
        [AllowEmptyCollection()]
        [string[]]$StagedFiles
    )

    return @($StagedFiles | Where-Object {
        $normalized = Convert-ToRepoRelativePath -Path $_
        $normalized -match '^docs/mainline-updates/[^/]+\.md$' -and $normalized -ne 'docs/mainline-updates/README.md'
    })
}

function ConvertFrom-GitNameStatusZ {
    param([string]$Raw)

    if ([string]::IsNullOrEmpty($Raw)) {
        return @()
    }

    $parts = @($Raw -split "`0" | Where-Object { $_ -ne '' })
    $changes = @()
    $i = 0
    while ($i -lt $parts.Count) {
        $status = [string]$parts[$i]
        $i++

        if ($status -match '^[RC]') {
            if ($i + 1 -ge $parts.Count) { break }
            $oldPath = Convert-ToRepoRelativePath -Path $parts[$i]
            $i++
            $path = Convert-ToRepoRelativePath -Path $parts[$i]
            $i++
        } else {
            if ($i -ge $parts.Count) { break }
            $oldPath = $null
            $path = Convert-ToRepoRelativePath -Path $parts[$i]
            $i++
        }

        $changes += [PSCustomObject]@{
            Status  = $status
            Path    = $path
            OldPath = $oldPath
        }
    }

    return $changes
}

function Get-StagedChanges {
    $raw = & git -C $script:repoRoot diff --cached --name-status --find-renames -z --diff-filter=ACDMR 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-HookError 'Unable to read staged changes from Git index.'
        return @()
    }

    return @(ConvertFrom-GitNameStatusZ -Raw ([string]::Join('', @($raw))))
}

function Get-StagedActivePaths {
    param([object[]]$Changes)

    return @($Changes | Where-Object { $_.Status -notmatch '^D' } | ForEach-Object { $_.Path })
}

function Get-StagedTouchedPaths {
    param([object[]]$Changes)

    $paths = @()
    foreach ($change in @($Changes)) {
        if ($change.Path) { $paths += $change.Path }
        if ($change.OldPath) { $paths += $change.OldPath }
    }
    return @($paths | Sort-Object -Unique)
}

function Test-StagedPathDeleted {
    param(
        [string]$Path,
        [object[]]$Changes
    )

    $normalizedPath = Convert-ToRepoRelativePath -Path $Path
    return [bool](@($Changes | Where-Object { $_.Path -eq $normalizedPath -and $_.Status -match '^D' }).Count)
}

function Test-StagedPathExists {
    param([string]$Path)

    $normalizedPath = Convert-ToRepoRelativePath -Path $Path
    & git -C $script:repoRoot cat-file -e ":$normalizedPath" 2>$null
    return ($LASTEXITCODE -eq 0)
}

function Get-StagedFileContent {
    param([string]$Path)

    $normalizedPath = Convert-ToRepoRelativePath -Path $Path
    $content = & git -C $script:repoRoot show ":$normalizedPath" 2>$null
    if ($LASTEXITCODE -ne 0) {
        return $null
    }

    return ($content -join [Environment]::NewLine)
}

function Get-RepoRelativePath {
    param([string]$Path)

    return ([System.IO.Path]::GetRelativePath($script:repoRoot, $Path) -replace '\\', '/')
}

function Invoke-SharedRuntimeAuditOnStagedSnapshot {
    if (-not $script:isWorkspaceRepo) {
        Write-HookInfo 'Shared runtime audit skipped: current repository is a consumer project.'
        return
    }

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sdd-runtime-staged-{0}" -f ([System.Guid]::NewGuid().ToString('N')))
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

    $auditConfirmed = $false
    try {
        $prefix = $tempRoot.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
        & git -C $script:repoRoot checkout-index -a -f --prefix=$prefix 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-HookError 'Unable to materialize staged shared-layer snapshot for audit.'
            return
        }

        $snapshotAuditScript = Join-Path $tempRoot 'studio/scripts/powershell/check-speckit-runtime.ps1'
        if (-not (Test-Path -LiteralPath $snapshotAuditScript)) {
            Write-HookError 'Shared runtime audit script is missing from the staged snapshot.'
            return
        }

        $auditOutput = & pwsh -NoProfile -File $snapshotAuditScript -Json 2>&1
        $auditExitCode = if ($null -ne $LASTEXITCODE) { [int]$LASTEXITCODE } else { 1 }
        $auditJson = if ($auditOutput) { $auditOutput -join [Environment]::NewLine } else { $null }

        if ([string]::IsNullOrWhiteSpace($auditJson)) {
            Write-HookError 'Shared runtime audit did not return JSON output from staged snapshot.'
            return
        }

        try {
            $auditResult = $auditJson | ConvertFrom-Json -AsHashtable
        } catch {
            Write-HookError 'Unable to parse shared runtime audit JSON output from staged snapshot.'
            Write-Host $auditJson -ForegroundColor DarkGray
            return
        }

        if ($auditExitCode -ne 0 -or -not $auditResult.VALID -or [int]$auditResult.ERROR_COUNT -gt 0) {
            Write-HookError 'Shared runtime audit failed against staged snapshot.'
            foreach ($failure in @($auditResult.FAILURES)) {
                $pathSuffix = if ($failure.path) { " [$($failure.path)]" } else { '' }
                Write-Host "    - [$($failure.category)] $($failure.message)$pathSuffix" -ForegroundColor Red
            }
            return
        }

        Write-HookSuccess 'Shared runtime audit passed against staged snapshot'
        $auditConfirmed = $true
    } finally {
        if (-not $auditConfirmed -and -not $script:hasErrors) {
            Write-HookError 'Shared runtime audit terminated without confirming success (no error path covered).'
        }
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force
        }
    }
}

function Invoke-SharedRuntimeAudit {
    if (-not (Test-Path -LiteralPath $script:sharedRuntimeAuditScript)) {
        Write-HookError "Shared runtime audit script not found: $($script:sharedRuntimeAuditScript)"
        return
    }

    # shared runtime audit
    $auditOutput = & $script:sharedRuntimeAuditScript -Json 2>&1
    $auditExitCode = if ($null -ne $LASTEXITCODE) { [int]$LASTEXITCODE } else { 1 }
    $auditJson = if ($auditOutput) { $auditOutput -join [Environment]::NewLine } else { $null }

    if ([string]::IsNullOrWhiteSpace($auditJson)) {
        Write-HookError 'Shared runtime audit did not return JSON output.'
        return
    }

    try {
        $auditResult = $auditJson | ConvertFrom-Json -AsHashtable
    } catch {
        Write-HookError 'Unable to parse shared runtime audit JSON output.'
        Write-Host $auditJson -ForegroundColor DarkGray
        return
    }

    if ($auditExitCode -ne 0 -or -not $auditResult.VALID -or [int]$auditResult.ERROR_COUNT -gt 0) {
        Write-HookError 'Shared runtime audit failed: studio shared layer drift detected.'
        foreach ($failure in @($auditResult.FAILURES)) {
            $pathSuffix = if ($failure.path) { " [$($failure.path)]" } else { '' }
            Write-Host "    - [$($failure.category)] $($failure.message)$pathSuffix" -ForegroundColor Red
        }
        return
    }

    Write-HookSuccess 'Shared runtime audit passed'
}

# ========================================
# Agent bootstrap governance helpers
# ========================================

function Test-IsAgentAdapterPath {
    param([string]$Path)

    $normalizedPath = Convert-ToRepoRelativePath -Path $Path
    return (
        $normalizedPath -eq 'AGENTS.md' -or
        $normalizedPath -eq 'CLAUDE.md' -or
        $normalizedPath -eq '.github/copilot-instructions.md' -or
        $normalizedPath -match '(^|/)(AGENTS\.md|CLAUDE\.md|\.github/copilot-instructions\.md)$'
    )
}

function Test-IsProjectConstitutionPath {
    param([string]$Path)

    $normalizedPath = Convert-ToRepoRelativePath -Path $Path
    return ($normalizedPath -match '(^|/)\.specify/memory/constitution\.md$')
}

function Get-AgentBootstrapProjectRootForPath {
    param([string]$Path)

    $normalizedPath = Convert-ToRepoRelativePath -Path $Path

    if ($normalizedPath -in @('AGENTS.md', 'CLAUDE.md', '.github/copilot-instructions.md', '.specify/memory/constitution.md')) {
        return $script:repoRoot
    }

    if ($normalizedPath -match '^(.*)/(AGENTS\.md|CLAUDE\.md|\.github/copilot-instructions\.md|\.specify/memory/constitution\.md)$') {
        return Join-Path $script:repoRoot $Matches[1]
    }

    return $null
}

function Test-ShouldValidateAgentBootstrapProjectRoot {
    param([string]$ProjectRoot)

    if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
        return $false
    }

    return (Test-Path -LiteralPath $ProjectRoot -PathType Container)
}

function Invoke-AgentBootstrapJsonTool {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    if (-not (Test-Path -LiteralPath $ScriptPath)) {
        return [ordered]@{
            ExitCode = 1
            Output   = $null
            Raw      = "Script not found: $ScriptPath"
        }
    }

    $toolOutput = & $ScriptPath @Arguments 2>&1
    $toolExitCode = if ($null -ne $LASTEXITCODE) { [int]$LASTEXITCODE } else { 0 }
    $rawOutput = if ($toolOutput) { $toolOutput -join [Environment]::NewLine } else { '' }
    $parsedOutput = $null

    if (-not [string]::IsNullOrWhiteSpace($rawOutput)) {
        try {
            $parsedOutput = $rawOutput | ConvertFrom-Json -AsHashtable
        } catch {
            $parsedOutput = $null
        }
    }

    return [ordered]@{
        ExitCode = $toolExitCode
        Output   = $parsedOutput
        Raw      = $rawOutput
    }
}

function Invoke-AgentBootstrapSync {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,
        [string]$From,
        [string]$StudioConstitutionVersion
    )

    $syncScript = Join-Path $script:workspaceRoot 'studio/scripts/powershell/sync-agent-bootstrap.ps1'
    $arguments = @('-ProjectRoot', $ProjectRoot, '-Write', '-Json')
    if ($From) {
        $arguments += @('-From', $From)
    }
    if ($StudioConstitutionVersion) {
        $arguments += @('-StudioConstitutionVersion', $StudioConstitutionVersion)
    }

    $result = Invoke-AgentBootstrapJsonTool -ScriptPath $syncScript -Arguments $arguments
    if ($result.ExitCode -ne 0 -or -not $result.Output) {
        Write-HookError "Agent bootstrap sync failed for $ProjectRoot"
        if ($result.Raw) { Write-Host $result.Raw -ForegroundColor Red }
        return
    }

    if ([int]$result.Output.CHANGED_COUNT -gt 0) {
        Write-HookError 'Agent bootstrap synchronized. Review changed files and re-stage them.'
        foreach ($changedFile in @($result.Output.CHANGED_FILES)) {
            Write-Host "    - $changedFile" -ForegroundColor Yellow
        }
    } else {
        Write-HookSuccess "Agent bootstrap already synchronized: $ProjectRoot"
    }
}

function Invoke-AgentBootstrapCheck {
    param([Parameter(Mandatory = $true)][string]$ProjectRoot)

    $checkScript = Join-Path $script:workspaceRoot 'studio/scripts/powershell/check-agent-bootstrap.ps1'
    $result = Invoke-AgentBootstrapJsonTool -ScriptPath $checkScript -Arguments @('-ProjectRoot', $ProjectRoot, '-Json')
    if ($result.ExitCode -ne 0 -or -not $result.Output -or -not $result.Output.VALID) {
        Write-HookError "Agent bootstrap check failed for $ProjectRoot"
        if ($result.Output -and $result.Output.FAILURES) {
            foreach ($failure in @($result.Output.FAILURES)) {
                Write-Host "    - $($failure.id): $($failure.message)" -ForegroundColor Red
            }
        } elseif ($result.Raw) {
            Write-Host $result.Raw -ForegroundColor Red
        }
    } else {
        Write-HookSuccess "Agent bootstrap check passed: $ProjectRoot"
    }
}

function Get-StudioConstitutionVersionFromFile {
    $constitutionPath = Join-Path $script:workspaceRoot 'studio/constitution/constitution.md'
    if (-not (Test-Path -LiteralPath $constitutionPath)) {
        return $null
    }

    $content = Get-Content -LiteralPath $constitutionPath -Raw
    if ($content -match '(?m)^\*\*Version:\*\*\s*([^\r\n]+)\s*$') {
        return $Matches[1].Trim()
    }

    return $null
}

function Get-MarkdownFieldValue {
    # NOTE: pre-commit hook is intentionally self-contained (does not dot-source
    # common.ps1) so it keeps working even if shared scripts are corrupt during a
    # mid-edit commit. The regex behavior MUST match Get-MarkdownField in
    # studio/scripts/powershell/common.ps1.
    param(
        [string]$Content,
        [string]$FieldName
    )

    if ([string]::IsNullOrWhiteSpace($Content)) {
        return $null
    }

    $escapedField = [regex]::Escape($FieldName)
    # Support both "**Field:**" and "**Field**:" formats found in workspace docs.
    $pattern = "(?mi)^\s*(?:-\s*)?\*\*$escapedField(?::\*\*|\*\*:)\s*(.+?)\s*$"
    if ($Content -notmatch $pattern) {
        return $null
    }

    $value = $Matches[1].Trim()
    if ($value -match '^`(.+)`$') {
        $value = $Matches[1]
    } elseif ($value -match '^"(.+)"$') {
        $value = $Matches[1]
    }
    return $value
}

function Get-GovernanceBootstrapBlock {
    param([string]$Content)

    if ([string]::IsNullOrWhiteSpace($Content)) {
        return $null
    }

    $pattern = '(?s)' + [regex]::Escape('<!-- BEGIN GENERATED GOVERNANCE BOOTSTRAP -->') + '.*?' + [regex]::Escape('<!-- END GENERATED GOVERNANCE BOOTSTRAP -->')
    $match = [regex]::Match($Content, $pattern)
    if (-not $match.Success) {
        return $null
    }

    return $match.Value.Trim()
}

function Convert-ToPortableRelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$FromPath,
        [Parameter(Mandatory = $true)][string]$ToPath
    )

    return ([System.IO.Path]::GetRelativePath($FromPath, $ToPath) -replace '\\', '/')
}

function Get-AdapterRelPathsForProjectRoot {
    param([Parameter(Mandatory = $true)][string]$ProjectRoot)

    $projectRootPath = (Resolve-Path -LiteralPath $ProjectRoot).Path
    $base = if ($projectRootPath -eq $script:repoRoot) {
        ''
    } else {
        (Get-RepoRelativePath -Path $projectRootPath).TrimEnd('/')
    }

    $prefix = if ($base) { "$base/" } else { '' }
    return @(
        "${prefix}AGENTS.md",
        "${prefix}CLAUDE.md",
        "${prefix}.github/copilot-instructions.md"
    )
}

function Get-StagedStudioConstitutionVersion {
    $stagedConstitution = if ($script:isWorkspaceRepo -and (Test-StagedPathExists -Path 'studio/constitution/constitution.md')) {
        Get-StagedFileContent -Path 'studio/constitution/constitution.md'
    } else {
        $null
    }

    if ($stagedConstitution -and $stagedConstitution -match '(?m)^\*\*Version:\*\*\s*([^\r\n]+)\s*$') {
        return $Matches[1].Trim()
    }

    return Get-StudioConstitutionVersionFromFile
}

function Test-StagedAgentBootstrapForProject {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [Parameter(Mandatory = $true)][object[]]$Changes,
        [switch]$RequireAllAdaptersStaged
    )

    $adapterPaths = Get-AdapterRelPathsForProjectRoot -ProjectRoot $ProjectRoot
    $changedActivePaths = Get-StagedActivePaths -Changes $Changes
    $contents = @{}
    $blocks = @()

    foreach ($adapterPath in $adapterPaths) {
        if ($RequireAllAdaptersStaged -and ($changedActivePaths -notcontains $adapterPath)) {
            Write-HookError "Runtime adapter must be staged with its synchronized set: $adapterPath"
            continue
        }

        if (-not (Test-StagedPathExists -Path $adapterPath)) {
            Write-HookError "Required runtime adapter is missing from staged commit: $adapterPath"
            continue
        }

        $content = Get-StagedFileContent -Path $adapterPath
        $contents[$adapterPath] = $content
        $block = Get-GovernanceBootstrapBlock -Content $content
        if (-not $block) {
            Write-HookError "Generated governance bootstrap block is missing in staged adapter: $adapterPath"
            continue
        }

        if ($content -match '(?m)^#\s+Studio Constitution\s*$') {
            Write-HookError "Adapter appears to inline-copy the Studio Constitution instead of referencing it: $adapterPath"
        }

        $blocks += $block
    }

    if ($blocks.Count -gt 1) {
        $firstBlock = $blocks[0]
        foreach ($block in $blocks) {
            if ($block -ne $firstBlock) {
                Write-HookError "Generated governance bootstrap blocks are not synchronized in staged adapters for: $ProjectRoot"
                break
            }
        }
    }

    $projectRootPath = (Resolve-Path -LiteralPath $ProjectRoot).Path
    $studioConstitutionPath = Join-Path $script:workspaceRoot 'studio/constitution/constitution.md'
    $relativeStudioConstitution = Convert-ToPortableRelativePath -FromPath $projectRootPath -ToPath $studioConstitutionPath
    $projectConstitutionRelPath = (Get-RepoRelativePath -Path (Join-Path $projectRootPath '.specify/memory/constitution.md'))
    $hasProjectConstitution = Test-StagedPathExists -Path $projectConstitutionRelPath
    $studioVersion = Get-StagedStudioConstitutionVersion

    foreach ($adapterPath in $adapterPaths) {
        $content = [string]$contents[$adapterPath]
        if ([string]::IsNullOrWhiteSpace($content)) { continue }

        if ($content.IndexOf($relativeStudioConstitution, [System.StringComparison]::Ordinal) -lt 0) {
            Write-HookError "Staged adapter does not reference the resolved Studio Constitution path '$relativeStudioConstitution': $adapterPath"
        }

        if ($studioVersion -and $content.IndexOf("**Studio Constitution Version:** $studioVersion", [System.StringComparison]::Ordinal) -lt 0) {
            Write-HookError "Staged adapter does not reference current Studio Constitution version $studioVersion`: $adapterPath"
        }

        if ($hasProjectConstitution -and $content.IndexOf('.specify/memory/constitution.md', [System.StringComparison]::Ordinal) -lt 0) {
            Write-HookError "Staged adapter does not reference .specify/memory/constitution.md: $adapterPath"
        }
    }

    $claudePath = $adapterPaths[1]
    $claudeContent = [string]$contents[$claudePath]
    if (-not [string]::IsNullOrWhiteSpace($claudeContent)) {
        $studioImportPattern = '(?m)^@' + [regex]::Escape($relativeStudioConstitution) + '\s*$'
        if ($claudeContent -notmatch $studioImportPattern) {
            Write-HookError "CLAUDE.md staged adapter is missing the direct Studio Constitution @path import: $claudePath"
        }

        if ($hasProjectConstitution -and $claudeContent -notmatch '(?m)^@\.specify/memory/constitution\.md\s*$') {
            Write-HookError "CLAUDE.md staged adapter is missing the direct project constitution @path import: $claudePath"
        }
    }
}

function Test-StagedPlanningGate {
    param([Parameter(Mandatory = $true)][string]$ArtifactPath)

    $normalizedPath = Convert-ToRepoRelativePath -Path $ArtifactPath
    if ($normalizedPath -notmatch '^(?<featureDir>(?:.+/)?specs/[^/]+)/(?:plan|tasks)\.md$') {
        return
    }

    $featureDir = $Matches['featureDir']
    $readinessPath = "$featureDir/readiness/readiness-assessment.md"
    $readinessContent = Get-StagedFileContent -Path $readinessPath
    if ([string]::IsNullOrWhiteSpace($readinessContent)) {
        Write-HookError "Planning artifact is staged without readiness-assessment.md in the staged commit: $normalizedPath"
        return
    }

    $primaryStatus = Get-MarkdownFieldValue -Content $readinessContent -FieldName 'Primary Status'
    if ($primaryStatus -ne 'READY_FOR_PLAN') {
        Write-HookError "Planning artifact is staged while readiness Primary Status is '$primaryStatus' instead of READY_FOR_PLAN: $normalizedPath"
    }

    $ledgerRequirement = Get-MarkdownFieldValue -Content $readinessContent -FieldName 'Intent Ledger Requirement'
    if ($ledgerRequirement -match 'Create\s+`?intent-ledger\.md`?|Update\s+`?intent-ledger\.md`?') {
        $ledgerPath = "$featureDir/intent-ledger.md"
        if (-not (Test-StagedPathExists -Path $ledgerPath)) {
            Write-HookError "Planning artifact is staged but readiness requires intent-ledger.md and it is missing from the staged commit: $ledgerPath"
        }
    }

    $authorizationPath = "$featureDir/readiness/eci/authorization-record.md"
    if (Test-StagedPathExists -Path $authorizationPath) {
        $authorizationContent = Get-StagedFileContent -Path $authorizationPath
        $authorizationOutcome = Get-MarkdownFieldValue -Content $authorizationContent -FieldName 'Authorization Outcome'
        if ($authorizationOutcome -ne 'READY_FOR_MAINLINE_IMPLEMENTATION') {
            Write-HookError "Planning artifact is staged but ECI Authorization Outcome is '$authorizationOutcome' instead of READY_FOR_MAINLINE_IMPLEMENTATION: $normalizedPath"
        }
    }
}

function Get-EdgeCaseCount {
    param([string]$Content)

    $count = 0
    $sectionPattern = '(?ms)^#{2,6}\s*(Edge Cases|Boundary Cases|Exception Cases|Error Handling|邊界情況|邊界案例|例外情況|異常情況|錯誤處理)\s*$([\s\S]*?)(?=^#{1,6}\s|\z)'
    $sectionMatches = [regex]::Matches($Content, $sectionPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

    foreach ($match in $sectionMatches) {
        $body = $match.Groups[2].Value
        $count += [regex]::Matches($body, '(?m)^\s*(?:[-*]|\d+\.)\s+').Count
    }

    if ($count -gt 0) {
        return $count
    }

    $fallbackPattern = '(?mi)^\s*(?:[-*]|\d+\.)\s+.*(edge\s*case|boundary|exception|invalid|overflow|timeout|error\s+(case|scenario|handling)|empty\s+(input|state|value|result)|null\s+(value|input|check|case)|邊界|例外|異常|錯誤(處理|情境|案例)|無效|空值|逾時|超時)'
    return [regex]::Matches($Content, $fallbackPattern).Count
}

function Test-RequiredPatterns {
    param(
        [string]$Content,
        [object[]]$Requirements
    )

    $missing = @()
    foreach ($requirement in $Requirements) {
        if ($Content -notmatch $requirement.Pattern) {
            $missing += $requirement.Name
        }
    }

    return $missing
}

function Get-ReadinessValidationErrors {
    param(
        [string]$Path,
        [string]$Content
    )

    $leaf = Split-Path -Path $Path -Leaf
    $requirements = @()

    switch ($leaf) {
        'readiness-assessment.md' {
            $requirements = @(
                @{ Name = 'Title'; Pattern = '(?mi)^#\s+Readiness Assessment:' },
                @{ Name = 'Date field'; Pattern = '(?mi)^\*\*Date\*\*:' },
                @{ Name = 'Primary Status field'; Pattern = '(?mi)^\*\*Primary Status\*\*:' },
                @{ Name = 'Recommended Next Step field'; Pattern = '(?mi)^\*\*Recommended Next Step\*\*:' },
                @{ Name = 'Summary section'; Pattern = '(?mi)^##\s+Summary\s*$' },
                @{ Name = 'Readiness Dimension Scan section'; Pattern = '(?mi)^##\s+Readiness Dimension Scan\s*$' },
                @{ Name = 'Primary Blocker Analysis section'; Pattern = '(?mi)^##\s+Primary Blocker Analysis\s*$' },
                @{ Name = 'Allowed / Not Allowed Next Actions section'; Pattern = '(?mi)^##\s+Allowed\s*/\s*Not Allowed Next Actions\s*$' },
                @{ Name = 'Allowed subsection'; Pattern = '(?mi)^#{2,3}\s+Allowed\s*$' },
                @{ Name = 'Not Allowed subsection'; Pattern = '(?mi)^#{2,3}\s+Not Allowed\s*$' },
                @{ Name = 'Planability vs Intent Obligations section'; Pattern = '(?mi)^##\s+Planability vs Intent Obligations\s*$' }
            )
        }
        'eci-trigger.md' {
            $requirements = @(
                @{ Name = 'Preliminary Recommendation field'; Pattern = '(?mi)^\*\*Preliminary Recommendation\*\*:' },
                @{ Name = 'Why This Blocks Planning section'; Pattern = '(?mi)^##\s+Why This Blocks Planning\s*$' },
                @{ Name = 'Return Condition section'; Pattern = '(?mi)^##\s+Return Condition\s*$' }
            )
        }
        'eci-assessment.md' {
            $requirements = @(
                @{ Name = 'Title'; Pattern = '(?mi)^#\s+ECI Assessment:' },
                @{ Name = 'ECI Level field'; Pattern = '(?mi)^\*\*ECI Level\*\*:' },
                @{ Name = 'Recommended Authorization field'; Pattern = '(?mi)^\*\*Recommended Authorization\*\*:' },
                @{ Name = 'Capability Inventory section'; Pattern = '(?mi)^##\s+Capability Inventory\s*$' },
                @{ Name = 'Governance Determination section'; Pattern = '(?mi)^##\s+Governance Determination\s*$' },
                @{ Name = 'Recommended Authorization Path section'; Pattern = '(?mi)^##\s+Recommended Authorization Path\s*$' },
                @{ Name = 'Return To Readiness section'; Pattern = '(?mi)^##\s+Return To Readiness\s*$' }
            )
        }
        'source-manifest.md' {
            $requirements = @(
                @{ Name = 'Title'; Pattern = '(?mi)^#\s+ECI Source Manifest:' },
                @{ Name = 'Canonical Source Rules section'; Pattern = '(?mi)^##\s+Canonical Source Rules\s*$' },
                @{ Name = 'Source Inventory section'; Pattern = '(?mi)^##\s+Source Inventory\s*$' },
                @{ Name = 'Known Gaps section'; Pattern = '(?mi)^##\s+Known Gaps\s*$' }
            )
        }
        'adoption-record.md' {
            $requirements = @(
                @{ Name = 'Title'; Pattern = '(?mi)^#\s+ECI Adoption Record:' },
                @{ Name = 'Adoption Boundary section'; Pattern = '(?mi)^##\s+Adoption Boundary\s*$' },
                @{ Name = 'ADR-Lite Decision section'; Pattern = '(?mi)^##\s+ADR-Lite Decision\s*$' },
                @{ Name = 'Packaging / Integration Stance section'; Pattern = '(?mi)^##\s+Packaging\s*/\s*Integration Stance\s*$' },
                @{ Name = 'Allowed Modes section'; Pattern = '(?mi)^##\s+Allowed Modes\s*$' },
                @{ Name = 'Prohibited Modes section'; Pattern = '(?mi)^##\s+Prohibited Modes\s*$' },
                @{ Name = 'Re-Intake Triggers section'; Pattern = '(?mi)^##\s+Re-Intake Triggers\s*$' }
            )
        }
        'authorization-record.md' {
            $requirements = @(
                @{ Name = 'Title'; Pattern = '(?mi)^#\s+ECI Authorization Record:' },
                @{ Name = 'Authorization Outcome field'; Pattern = '(?mi)^\*\*Authorization Outcome\*\*:' },
                @{ Name = 'Allowed Implementation Scope section'; Pattern = '(?mi)^##\s+Allowed Implementation Scope\s*$' },
                @{ Name = 'Explicit Prohibitions section'; Pattern = '(?mi)^##\s+Explicit Prohibitions\s*$' },
                @{ Name = 'Prerequisites section'; Pattern = '(?mi)^##\s+Prerequisites\s*$' },
                @{ Name = 'Evidence Required To Upgrade Authorization section'; Pattern = '(?mi)^##\s+Evidence Required To Upgrade Authorization\s*$' },
                @{ Name = 'Return To Readiness section'; Pattern = '(?mi)^##\s+Return To Readiness\s*$' }
            )
        }
        'repo-context-packet.md' {
            $requirements = @(
                @{ Name = 'Canonical Source / Runtime Authority Map section'; Pattern = '(?mi)^##\s+Canonical Source\s*/\s*Runtime Authority Map\s*$' },
                @{ Name = 'Protected or Do-Not-Break Areas section'; Pattern = '(?mi)^##\s+Protected or Do-Not-Break Areas\s*$' },
                @{ Name = 'Return Condition section'; Pattern = '(?mi)^##\s+Return Condition\s*$' }
            )
        }
        'decision-record.md' {
            $requirements = @(
                @{ Name = 'Viable Options section'; Pattern = '(?mi)^##\s+Viable Options\s*$' },
                @{ Name = 'Recommended Owner / Approver section'; Pattern = '(?mi)^##\s+Recommended Owner\s*/\s*Approver\s*$' },
                @{ Name = 'Return Condition section'; Pattern = '(?mi)^##\s+Return Condition\s*$' }
            )
        }
        'validation-contract.md' {
            $requirements = @(
                @{ Name = 'Claims That Require Evidence section'; Pattern = '(?mi)^##\s+Claims That Require Evidence\s*$' },
                @{ Name = 'Evaluation Method section'; Pattern = '(?mi)^##\s+Evaluation Method\s*$' },
                @{ Name = 'Return Condition section'; Pattern = '(?mi)^##\s+Return Condition\s*$' }
            )
        }
        'access-setup-checklist.md' {
            $requirements = @(
                @{ Name = 'Required Access / Runtime Items section'; Pattern = '(?mi)^##\s+Required Access\s*/\s*Runtime Items\s*$' },
                @{ Name = 'Risks of Proceeding Without Setup section'; Pattern = '(?mi)^##\s+Risks of Proceeding Without Setup\s*$' },
                @{ Name = 'Return Condition section'; Pattern = '(?mi)^##\s+Return Condition\s*$' }
            )
        }
        'exploration-boundary.md' {
            $requirements = @(
                @{ Name = 'Why Mainline Commitment Is Premature section'; Pattern = '(?mi)^##\s+Why Mainline Commitment Is Premature\s*$' },
                @{ Name = 'Allowed Exploration section'; Pattern = '(?mi)^##\s+Allowed Exploration\s*$' },
                @{ Name = 'Explicitly Not Allowed section'; Pattern = '(?mi)^##\s+Explicitly Not Allowed\s*$' },
                @{ Name = 'Evidence Needed To Re-Enter Readiness section'; Pattern = '(?mi)^##\s+Evidence Needed To Re-Enter Readiness\s*$' }
            )
        }
        default {
            return @()
        }
    }

    return Test-RequiredPatterns -Content $Content -Requirements $requirements
}

# ========================================
# Drift governance helpers
# ========================================

function Get-ImpactRegistry {
    $registryPath = Join-Path $script:workspaceRoot 'studio/runtime/impact-registry.json'
    if (-not (Test-Path -LiteralPath $registryPath)) {
        return $null
    }

    try {
        return Get-Content -LiteralPath $registryPath -Raw | ConvertFrom-Json -AsHashtable
    } catch {
        Write-HookWarning "Unable to read impact registry: $registryPath"
        return $null
    }
}

function Get-ChangeTypesFromPaths {
    param(
        [string[]]$StagedPaths,
        [hashtable]$Registry
    )

    $normalizedStaged = @($StagedPaths | ForEach-Object { Convert-ToRepoRelativePath -Path $_ })
    $matchedTypes = @{}

    foreach ($route in $Registry.impactRouting) {
        $triggers = @($route.trigger -split '\|' | ForEach-Object { $_.Trim() })

        foreach ($trigger in $triggers) {
            if ($matchedTypes.Contains($route.changeType)) { break }

            # Replace <feature> placeholder with wildcard for matching
            $matchTrigger = $trigger -replace '<feature>', '*'

            foreach ($staged in $normalizedStaged) {
                $match = $false

                if ($matchTrigger.Contains('*')) {
                    $pattern = '^' + [regex]::Escape($matchTrigger).Replace('\*', '[^/]*') + '$'
                    if ($staged -match $pattern) { $match = $true }
                } elseif ($matchTrigger.EndsWith('/')) {
                    if ($staged.StartsWith($matchTrigger, [System.StringComparison]::OrdinalIgnoreCase)) {
                        $match = $true
                    }
                } else {
                    if ($staged -eq $matchTrigger) { $match = $true }
                }

                if ($match) {
                    # For feature-scoped triggers, capture the feature name
                    $featureName = $null
                    if ($trigger -match '<feature>') {
                        $escaped = [regex]::Escape(($trigger -replace '<feature>', '___FEAT___'))
                        $featurePattern = '^' + $escaped.Replace('___FEAT___', '([^/]+)') + '$'
                        if ($staged -match $featurePattern) {
                            $featureName = $Matches[1]
                        }
                    }

                    $matchedTypes[$route.changeType] = @{
                        Route       = $route
                        FeatureName = $featureName
                    }
                    break
                }
            }
        }
    }

    return $matchedTypes
}

# ========================================
# Get staged files
# ========================================
$stagedChanges = @(Get-StagedChanges)
$stagedFiles = Get-StagedActivePaths -Changes $stagedChanges
$stagedTouchedFiles = Get-StagedTouchedPaths -Changes $stagedChanges
if ($script:hasErrors) {
    Write-Host '[ERROR] Unable to evaluate staged paths safely.' -ForegroundColor Red
    exit 1
}
if ($stagedChanges.Count -eq 0) {
    Write-HookInfo 'No staged files to validate'
    exit 0
}

Write-Host ''
Write-Host '========================================' -ForegroundColor Cyan
Write-Host '  SDD Pre-Commit Validation' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ''

$protectedPersonalDataPaths = @(Get-ProtectedPersonalDataPaths -Paths $stagedFiles)
if ($protectedPersonalDataPaths.Count -gt 0) {
    Write-Host "[ERROR] Staged paths under a directory named '履歷' are not allowed. Keep personal data outside Git repositories." -ForegroundColor Red
    Write-Host "  Protected path matches: $($protectedPersonalDataPaths.Count)" -ForegroundColor Red
    Write-Host ''
    exit 1
}

$sharedGatePaths = Get-SharedGatePaths
$sharedLayerFiles = @()
if ($script:isWorkspaceRepo -and $sharedGatePaths.Count -gt 0) {
    $sharedLayerFiles = @($stagedTouchedFiles | Where-Object { Test-IsSharedGateHit -Path $_ -GatePaths $sharedGatePaths })
}

if ($sharedLayerFiles.Count -gt 0) {
    Write-HookInfo 'Shared-layer files detected; running shared runtime audit against staged snapshot...'
    Invoke-SharedRuntimeAuditOnStagedSnapshot
    Write-Host ''
}

# ========================================
# H1: Mainline-update note enforcement (constitution §12)
# Any shared-layer governance change requires a paired docs/mainline-updates/*.md note
# in the same commit. mainline-updates/* edits themselves and the README are exempt
# (otherwise the rule would be self-locking).
# ========================================
$nonNoteSharedFiles = Get-NonNoteSharedLayerFiles -SharedLayerFiles $sharedLayerFiles
$mainlineNotesStaged = Get-StagedMainlineUpdateNotes -StagedFiles $stagedFiles

if ($script:isWorkspaceRepo -and $nonNoteSharedFiles.Count -gt 0 -and $mainlineNotesStaged.Count -eq 0) {
    Write-HookError 'Shared-layer governance changes require a docs/mainline-updates/*.md note in the same commit (constitution Section 12).'
    Write-Host '  Affected shared-layer paths:' -ForegroundColor Yellow
    foreach ($file in @($nonNoteSharedFiles | Select-Object -First 5)) {
        Write-Host "    - $file" -ForegroundColor Red
    }
    if ($nonNoteSharedFiles.Count -gt 5) {
        Write-Host "    ... and $($nonNoteSharedFiles.Count - 5) more" -ForegroundColor Red
    }
    Write-Host '  Author a note from studio/templates/sdd-docs/mainline-update-note-template.md and add it to docs/mainline-updates/README.md.' -ForegroundColor Yellow
    Write-Host ''
}

# ========================================
# H2: Studio Constitution change requires synchronized workspace adapters
# When studio/constitution/constitution.md is staged, AGENTS.md / CLAUDE.md /
# .github/copilot-instructions.md MUST be staged together AND their bootstrap
# blocks MUST reference the current constitution version.
# ========================================
$studioConstitutionChanged = @($stagedTouchedFiles | Where-Object {
    (Convert-ToRepoRelativePath -Path $_) -eq 'studio/constitution/constitution.md'
})

if ($studioConstitutionChanged.Count -gt 0 -and $script:isWorkspaceRepo) {
    Write-HookInfo 'Studio Constitution change detected; root runtime adapters must be synchronized in the staged commit...'
    Test-StagedAgentBootstrapForProject -ProjectRoot $script:repoRoot -Changes $stagedChanges -RequireAllAdaptersStaged
    Write-Host ''
}

$adapterFiles = @($stagedTouchedFiles | Where-Object { Test-IsAgentAdapterPath -Path $_ })
if ($adapterFiles.Count -gt 0) {
    Write-HookInfo 'Agent adapter changes detected; checking staged generated bootstrap blocks...'

    $adapterGroups = @{}
    foreach ($adapterFile in $adapterFiles) {
        $projectRoot = Get-AgentBootstrapProjectRootForPath -Path $adapterFile
        if (-not (Test-ShouldValidateAgentBootstrapProjectRoot -ProjectRoot $projectRoot)) { continue }
        if (-not $adapterGroups.ContainsKey($projectRoot)) {
            $adapterGroups[$projectRoot] = @()
        }
        $adapterGroups[$projectRoot] += $adapterFile
    }

    foreach ($entry in $adapterGroups.GetEnumerator()) {
        $projectRoot = $entry.Key
        Test-StagedAgentBootstrapForProject -ProjectRoot $projectRoot -Changes $stagedChanges -RequireAllAdaptersStaged
    }
    Write-Host ''
}

$projectConstitutionFiles = @($stagedTouchedFiles | Where-Object { Test-IsProjectConstitutionPath -Path $_ })
if ($projectConstitutionFiles.Count -gt 0) {
    Write-HookInfo 'Project Constitution changes detected; checking staged local runtime adapters...'
    $projectRoots = @{}
    foreach ($projectConstitutionFile in $projectConstitutionFiles) {
        $projectRoot = Get-AgentBootstrapProjectRootForPath -Path $projectConstitutionFile
        if (Test-ShouldValidateAgentBootstrapProjectRoot -ProjectRoot $projectRoot) {
            $projectRoots[$projectRoot] = $true
        }
    }

    foreach ($projectRoot in $projectRoots.Keys) {
        Test-StagedAgentBootstrapForProject -ProjectRoot $projectRoot -Changes $stagedChanges -RequireAllAdaptersStaged
    }
    Write-Host ''
}

# ========================================
# Impact routing advisory (advisory)
# ========================================
$impactRegistry = Get-ImpactRegistry

if ($impactRegistry) {
    $changeTypes = Get-ChangeTypesFromPaths -StagedPaths $stagedFiles -Registry $impactRegistry

    if ($changeTypes.Count -gt 0) {
        Write-HookInfo 'Impact routing advisory for detected change types...'

        $normalizedStaged = @($stagedFiles | ForEach-Object { Convert-ToRepoRelativePath -Path $_ })

        foreach ($entry in $changeTypes.GetEnumerator()) {
            $typeName = $entry.Key
            $route = $entry.Value.Route
            $featureName = $entry.Value.FeatureName

            $missingTargets = @()

            foreach ($rule in $route.rules) {
                if ($rule.impact -ne 'must_update') { continue }

                $target = [string]$rule.target

                # Resolve feature-scoped targets
                if ($target -match '<feature>') {
                    if ($featureName) {
                        $target = $target -replace '<feature>', $featureName
                    } else {
                        continue
                    }
                }

                # Check if target (or any file under target pattern) is in staged files
                $found = $false
                foreach ($staged in $normalizedStaged) {
                    if ($target.Contains('*')) {
                        $pattern = '^' + [regex]::Escape($target).Replace('\*', '[^/]*') + '$'
                        if ($staged -match $pattern) { $found = $true; break }
                    } elseif ($target.EndsWith('/')) {
                        if ($staged.StartsWith($target, [System.StringComparison]::OrdinalIgnoreCase)) {
                            $found = $true; break
                        }
                    } else {
                        if ($staged -eq $target) { $found = $true; break }
                    }
                }

                if (-not $found) {
                    $missingTargets += @{ Target = $target; Reason = $rule.reason }
                }
            }

            if ($missingTargets.Count -gt 0) {
                Write-HookWarning "Change type '$typeName': must_update targets not in this commit:"
                foreach ($t in $missingTargets) {
                    Write-Host "    - $($t.Target)" -ForegroundColor Yellow
                    if ($t.Reason) {
                        Write-Host "      $($t.Reason)" -ForegroundColor DarkGray
                    }
                }
            } else {
                $mustUpdateCount = @($route.rules | Where-Object {
                    $_.impact -eq 'must_update' -and $_.target -notmatch '<feature>'
                }).Count
                $featureMustUpdateCount = 0
                if ($featureName) {
                    $featureMustUpdateCount = @($route.rules | Where-Object {
                        $_.impact -eq 'must_update' -and $_.target -match '<feature>'
                    }).Count
                }
                if (($mustUpdateCount + $featureMustUpdateCount) -gt 0) {
                    Write-HookSuccess "Change type '$typeName': all must_update targets in this commit"
                }
            }
        }
        Write-Host ''
    }
}

# ========================================
# 1. Validate spec.md files
# ========================================
$specFiles = $stagedFiles | Where-Object { $_ -match 'spec\.md$' }

if ($specFiles) {
    Write-HookInfo 'Validating spec.md files...'

    $requiredSections = @(
        @{ Name = 'Problem/Goal'; Pattern = 'Problem|Goal|Overview|問題|目標|概述' },
        @{ Name = 'Actors'; Pattern = 'Actor|User|Stakeholder|角色|使用者|利害關係人' },
        @{ Name = 'Scenarios'; Pattern = 'Scenario|User Flow|Use Case|情境|流程|使用案例' },
        @{ Name = 'Functional Requirements'; Pattern = 'Functional Requirement|FR\b|功能需求' },
        @{ Name = 'Non-Functional Requirements'; Pattern = 'Non-Functional Requirement|NFR\b|非功能需求' },
        @{ Name = 'Edge Cases'; Pattern = 'Edge Case|Boundary|Exception|Error Handling|邊界|例外|錯誤處理' },
        @{ Name = 'Success Criteria'; Pattern = 'Success Criteria|Acceptance Criteria|成功標準|驗收標準' },
        @{ Name = 'Out of Scope'; Pattern = 'Out of Scope|Exclusion|Not Included|不在範圍|排除項目' },
        @{ Name = 'Document version'; Pattern = '(?mi)(Version|版本)\s*[:：]\s*\S|(?mi)^[*_]*Version[*_]*\s*[:：]' }
    )

    foreach ($file in $specFiles) {
        $content = Get-StagedFileContent -Path $file
        if (-not $content) { continue }

        $missingSections = @()
        foreach ($section in $requiredSections) {
            if ($content -notmatch $section.Pattern) {
                $missingSections += $section.Name
            }
        }

        $edgeCaseCount = Get-EdgeCaseCount -Content $content
        if ($edgeCaseCount -lt 3) {
            $missingSections += "At least 3 Edge Cases (found: $edgeCaseCount)"
        }

        if ($missingSections.Count -gt 0) {
            Write-HookError "[$file] Missing required sections:"
            foreach ($missing in $missingSections) {
                Write-Host "    - $missing" -ForegroundColor Red
            }
        }
        else {
            Write-HookSuccess "[$file] All required sections present"
        }
    }
    Write-Host ''
}

# ========================================
# 2. Validate readiness artifacts
# ========================================
$readinessFiles = $stagedFiles | Where-Object {
    $_ -match '(^|[\\/])readiness(?:[\\/]eci)?[\\/](readiness-assessment|eci-trigger|repo-context-packet|decision-record|validation-contract|access-setup-checklist|exploration-boundary|eci-assessment|source-manifest|adoption-record|authorization-record)\.md$'
}

if ($readinessFiles) {
    Write-HookInfo 'Validating readiness artifacts...'

    foreach ($file in $readinessFiles) {
        $content = Get-StagedFileContent -Path $file
        if (-not $content) { continue }

        $validationErrors = Get-ReadinessValidationErrors -Path $file -Content $content
        if ($validationErrors.Count -gt 0) {
            Write-HookError "[$file] Readiness validation failed:"
            foreach ($err in $validationErrors) {
                Write-Host "    - Missing $err" -ForegroundColor Red
            }
        }
        else {
            Write-HookSuccess "[$file] Readiness artifact structure valid"
        }
    }
    Write-Host ''
}

# ========================================
# 2b. Validate intent-ledger.md files
# ========================================
$intentLedgerFiles = $stagedFiles | Where-Object { $_ -match 'intent-ledger\.md$' }

if ($intentLedgerFiles) {
    Write-HookInfo 'Validating intent-ledger.md files...'

    foreach ($file in $intentLedgerFiles) {
        $content = Get-StagedFileContent -Path $file
        if (-not $content) { continue }

        $validationErrors = @()

        # Check 9-column table header
        if ($content -notmatch 'source_intent_item\s*\|.*spec_anchor\s*\|.*current_classification\s*\|.*current_representation\s*\|.*defer_or_drop_reason\s*\|.*reentry_trigger\s*\|.*follow_on_feature_hint\s*\|.*surface_disclosure_required\s*\|.*owner_signoff_required') {
            $validationErrors += 'Missing 9-column intent-ledger table header (source_intent_item | spec_anchor | current_classification | current_representation | defer_or_drop_reason | reentry_trigger | follow_on_feature_hint | surface_disclosure_required | owner_signoff_required)'
        }

        # Check valid current_classification values in data rows
        $validClassifications = 'represented_by_substitute|deferred|dropped_with_owner_signoff'
        $dataRowMatches = [regex]::Matches($content, '(?m)^\|\s*([^|]+?)\s*\|\s*[^|]+?\s*\|\s*`?([^|`]+?)`?\s*\|')
        foreach ($row in $dataRowMatches) {
            $firstCol = $row.Groups[1].Value.Trim()
            $classValue = $row.Groups[2].Value.Trim()
            # Skip header row and separator rows
            if ($firstCol -eq 'source_intent_item' -or $firstCol -match '^[-:]+$') { continue }
            if ($classValue -and $classValue -notmatch '^[-:]+$' -and $classValue -ne 'current_classification' -and $classValue -notmatch "^($validClassifications)$") {
                $validationErrors += "Invalid current_classification value: '$classValue' (must be represented_by_substitute, deferred, or dropped_with_owner_signoff)"
            }
        }

        if ($validationErrors.Count -gt 0) {
            Write-HookError "[$file] Intent ledger validation failed:"
            foreach ($err in $validationErrors) {
                Write-Host "    - $err" -ForegroundColor Red
            }
        }
        else {
            Write-HookSuccess "[$file] Intent ledger structure valid"
        }
    }
    Write-Host ''
}

# ========================================
# 3. Validate plan.md files
# ========================================
# Scope: only SDD feature plans live under `specs/<feature>/plan.md`. Agent
# definition files such as `.claude/agents/speckit-plan.md` are not SDD plans.
$planFiles = $stagedFiles | Where-Object { $_ -match '(^|/)specs/[^/]+/plan\.md$' }

if ($planFiles) {
    Write-HookInfo 'Validating plan.md files...'

    $requiredSections = @(
        @{ Name = 'Architecture'; Pattern = 'Architecture|System Design|Overview|架構|系統設計' },
        @{ Name = 'Technology'; Pattern = 'Tech|Technology|Stack|Language|Framework|技術|技術棧|框架' },
        @{ Name = 'Integration'; Pattern = 'Integration|API|Endpoint|整合|介接|端點' },
        @{ Name = 'Data Flow'; Pattern = 'Data Flow|Data Model|Schema|資料流|資料模型|結構' },
        @{ Name = 'Risks'; Pattern = 'Risk|Constraint|Limitation|風險|限制' },
        @{ Name = 'Why Not'; Pattern = 'Why Not|Alternative|Decision|Rejected|替代方案|不採用' },
        @{ Name = 'Estimated timeline'; Pattern = 'Estimated [Tt]imeline|Timeline|時程|預估時間' },
        @{ Name = 'Document version'; Pattern = '(?mi)(Version|版本)\s*[:：]\s*\S|(?mi)^[*_]*Version[*_]*\s*[:：]' }
    )

    foreach ($file in $planFiles) {
        Test-StagedPlanningGate -ArtifactPath $file
        $content = Get-StagedFileContent -Path $file
        if (-not $content) { continue }

        $missingSections = @()
        foreach ($section in $requiredSections) {
            if ($content -notmatch $section.Pattern) {
                $missingSections += $section.Name
            }
        }

        if ($missingSections.Count -gt 0) {
            Write-HookError "[$file] Missing required sections:"
            foreach ($missing in $missingSections) {
                Write-Host "    - $missing" -ForegroundColor Red
            }
        }
        else {
            Write-HookSuccess "[$file] All required sections present"
        }
    }
    Write-Host ''
}

# ========================================
# 4. Validate tasks.md files
# ========================================
# Scope: only SDD feature tasks live under `specs/<feature>/tasks.md`. Agent
# definition files such as `.claude/agents/speckit-tasks.md` are not SDD tasks.
$tasksFiles = $stagedFiles | Where-Object { $_ -match '(^|/)specs/[^/]+/tasks\.md$' }

if ($tasksFiles) {
    Write-HookInfo 'Validating tasks.md files...'

    foreach ($file in $tasksFiles) {
        Test-StagedPlanningGate -ArtifactPath $file
        $content = Get-StagedFileContent -Path $file
        if (-not $content) { continue }

        $validationErrors = @()
        $taskMatches = [regex]::Matches($content, '(?m)^\s*-\s\[[ xX]\]\sT\d{3}\b')
        if ($taskMatches.Count -eq 0) {
            $validationErrors += 'No tasks found with proper checklist ID format (`- [ ] T001 ...`)'
        }

        if ($content -notmatch 'Definition of Done|DoD|Done when|Acceptance|完成條件') {
            $validationErrors += 'Missing Definition of Done section'
        }

        if ($content -notmatch '\[P[123]\]|Priority|優先') {
            $validationErrors += 'Missing priority markers (P1/P2/P3)'
        }

        if ($content -notmatch 'Risk:|Low|Medium|High|風險') {
            Write-HookWarning "[$file] Consider adding Risk Level indicators"
        }

        if ($validationErrors.Count -gt 0) {
            Write-HookError "[$file] Validation failed:"
            foreach ($err in $validationErrors) {
                Write-Host "    - $err" -ForegroundColor Red
            }
        }
        else {
            Write-HookSuccess "[$file] Checklist format valid"
        }
    }
    Write-Host ''
}

# ========================================
# 5. Validate Conventional Commits (if commit message exists)
# ========================================
Write-HookInfo 'Commit message will be validated by commit-msg hook'
Write-Host ''

# ========================================
# Final Result
# ========================================
Write-Host '========================================' -ForegroundColor Cyan

if ($script:hasErrors) {
    Write-Host ''
    Write-Host '[ERROR] Pre-commit validation FAILED' -ForegroundColor Red
    Write-Host ''
    Write-Host "Fix the issues above or use 'git commit --no-verify' to bypass" -ForegroundColor Yellow
    Write-Host ''
    exit 1
}
else {
    Write-Host '[OK] Pre-commit validation PASSED' -ForegroundColor Green
    Write-Host ''
    exit 0
}
