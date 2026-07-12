#Requires -Version 7.0

[CmdletBinding()]
param(
    [string]$WorkspaceRoot,
    [string]$BaseRef,
    [string]$HeadRef = 'HEAD',
    [string[]]$ChangedPaths,
    [string]$ChangedPathsJson,
    [switch]$RequireReady,
    [switch]$Json,
    [switch]$Help
)

<#
.SYNOPSIS
Validates mainline update-note state and branch-level impact reconciliation.

.DESCRIPTION
Without a branch diff, validates the note state machine, index parity, and the
hash-bound R5 migration baseline for legacy Ready notes whose commit evidence is
still TBD. With -BaseRef or -ChangedPaths, also evaluates the aggregate changed
paths against impact-registry must_update routes. CI uses -RequireReady so a
shared-layer PR must include a Ready or Merged note with closed reconciliation.

.PARAMETER WorkspaceRoot
Workspace root. Defaults to the repository root above this script.

.PARAMETER BaseRef
Git base revision. Changed paths are read from BaseRef...HeadRef.

.PARAMETER HeadRef
Git head revision. Defaults to HEAD.

.PARAMETER ChangedPaths
Explicit changed paths, primarily for deterministic tests. Mutually exclusive
with -BaseRef.

.PARAMETER ChangedPathsJson
JSON array form of explicit changed paths for cross-process callers and tests.

.PARAMETER RequireReady
Require a changed Ready or Merged note whose Reconciliation Status is Closed.

.PARAMETER Json
Emit structured JSON and return a nonzero exit code when invalid.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
    Get-Help $MyInvocation.MyCommand.Path -Detailed
    exit 0
}

$script:validationErrors = [System.Collections.Generic.List[object]]::new()
$script:validationWarnings = [System.Collections.Generic.List[object]]::new()
$script:legacyBaselineApplied = [System.Collections.Generic.List[string]]::new()

function Add-ValidationIssue {
    param(
        [Parameter(Mandatory)] [ValidateSet('error', 'warning')] [string]$Severity,
        [Parameter(Mandatory)] [string]$Category,
        [Parameter(Mandatory)] [string]$Message,
        [string]$Path
    )

    $issue = [pscustomobject][ordered]@{
        category = $Category
        message  = $Message
        path     = $Path
    }
    if ($Severity -eq 'error') {
        $script:validationErrors.Add($issue)
    } else {
        $script:validationWarnings.Add($issue)
    }
}

function Convert-ToRepositoryPath {
    param([AllowNull()] [string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) { return '' }
    $normalized = $Path.Replace('\', '/').Trim()
    while ($normalized.StartsWith('./', [System.StringComparison]::Ordinal)) {
        $normalized = $normalized.Substring(2)
    }
    return $normalized
}

function Get-MarkdownFieldValue {
    param(
        [Parameter(Mandatory)] [string]$Content,
        [Parameter(Mandatory)] [string]$Name
    )

    $pattern = '(?mi)^\*\*' + [regex]::Escape($Name) + '\*\*:\s*(.+?)\s*$'
    $match = [regex]::Match($Content, $pattern)
    if (-not $match.Success) { return $null }
    return $match.Groups[1].Value.Trim()
}

function Get-RepositoryFileHash {
    param([Parameter(Mandatory)] [string]$Path)

    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Test-PathPattern {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$Pattern
    )

    $normalizedPath = Convert-ToRepositoryPath $Path
    $normalizedPattern = Convert-ToRepositoryPath $Pattern
    if (-not $normalizedPattern) { return $false }

    $matchPattern = $normalizedPattern -replace '<feature>', '*'
    if ($matchPattern.Contains('*')) {
        $regexPattern = '^' + [regex]::Escape($matchPattern).Replace('\*', '[^/]*') + '$'
        return $normalizedPath -match $regexPattern
    }
    if ($matchPattern.EndsWith('/', [System.StringComparison]::Ordinal)) {
        return $normalizedPath.StartsWith($matchPattern, [System.StringComparison]::OrdinalIgnoreCase)
    }
    return $normalizedPath.Equals($matchPattern, [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-FeatureNameForTrigger {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$Trigger
    )

    if ($Trigger -notmatch '<feature>') { return $null }
    $placeholder = '___FEATURE___'
    $escaped = [regex]::Escape(($Trigger -replace '<feature>', $placeholder))
    $pattern = '^' + $escaped.Replace($placeholder, '([^/]+)') + '$'
    if ((Convert-ToRepositoryPath $Path) -match $pattern) {
        return $Matches[1]
    }
    return $null
}

function Read-ReconciliationRows {
    param([Parameter(Mandatory)] [string]$Content)

    $rows = [System.Collections.Generic.List[object]]::new()
    $sectionCount = 0
    $inSection = $false
    $inHtmlComment = $false
    $fenceCharacter = $null
    $sectionMalformed = $false

    foreach ($rawLine in @($Content -split "`r?`n")) {
        $visibleLine = [string]$rawLine

        while ($true) {
            if ($inHtmlComment) {
                $commentEnd = $visibleLine.IndexOf('-->', [System.StringComparison]::Ordinal)
                if ($commentEnd -lt 0) {
                    $visibleLine = ''
                    break
                }
                $visibleLine = $visibleLine.Substring($commentEnd + 3)
                $inHtmlComment = $false
                continue
            }

            $commentStart = $visibleLine.IndexOf('<!--', [System.StringComparison]::Ordinal)
            if ($commentStart -lt 0) { break }
            $beforeComment = $visibleLine.Substring(0, $commentStart)
            $afterCommentStart = $visibleLine.Substring($commentStart + 4)
            $sameLineEnd = $afterCommentStart.IndexOf('-->', [System.StringComparison]::Ordinal)
            if ($sameLineEnd -ge 0) {
                $visibleLine = $beforeComment + $afterCommentStart.Substring($sameLineEnd + 3)
                continue
            }
            $visibleLine = $beforeComment
            $inHtmlComment = $true
            break
        }

        $trimmed = $visibleLine.Trim()
        if ($fenceCharacter) {
            $closingPattern = if ($fenceCharacter -eq '`') { '^`{3,}\s*$' } else { '^~{3,}\s*$' }
            if ($trimmed -match $closingPattern) {
                $fenceCharacter = $null
            }
            continue
        }
        if ($trimmed -match '^(`{3,}|~{3,})') {
            $fenceCharacter = $Matches[1].Substring(0, 1)
            continue
        }

        if ($trimmed -match '^##\s+Impact Reconciliation\s*$') {
            $sectionCount++
            $inSection = $true
            continue
        }
        if ($inSection -and $trimmed -match '^##\s+') {
            $inSection = $false
        }
        if (-not $inSection) { continue }

        if ($visibleLine -notmatch '^\|\s*(.+?)\s*\|\s*`?(must_update|must_review|maybe_review)`?\s*\|\s*`?(updated|reviewed-no-change|deferred-owner-approved|pending)`?\s*\|\s*(.*?)\s*\|\s*$') {
            continue
        }
        $target = $Matches[1].Trim().Trim('`')
        $rows.Add([pscustomobject][ordered]@{
            target      = Convert-ToRepositoryPath $target
            impact      = $Matches[2].ToLowerInvariant()
            disposition = $Matches[3].ToLowerInvariant()
            evidence    = $Matches[4].Trim()
        })
    }

    if ($inSection -and ($inHtmlComment -or $fenceCharacter)) {
        $sectionMalformed = $true
    }
    if ($sectionCount -gt 1) {
        $sectionMalformed = $true
    }

    return [pscustomobject][ordered]@{
        SectionPresent = ($sectionCount -eq 1)
        SectionCount   = $sectionCount
        Malformed      = $sectionMalformed
        Rows           = @($rows)
    }
}

function Read-MainlineNote {
    param(
        [Parameter(Mandatory)] [string]$AbsolutePath,
        [Parameter(Mandatory)] [string]$RelativePath
    )

    $content = Get-Content -LiteralPath $AbsolutePath -Raw -ErrorAction Stop
    $status = Get-MarkdownFieldValue -Content $content -Name 'Status'
    $commits = Get-MarkdownFieldValue -Content $content -Name 'Related Commits'
    $pullRequest = Get-MarkdownFieldValue -Content $content -Name 'Related PR'
    $reconciliationStatus = Get-MarkdownFieldValue -Content $content -Name 'Reconciliation Status'
    $reconciliation = Read-ReconciliationRows -Content $content

    if ($status -notin @('Draft', 'Ready', 'Merged')) {
        Add-ValidationIssue -Severity error -Category 'note-status' -Path $RelativePath `
            -Message 'Status must be exactly Draft, Ready, or Merged.'
    }

    $hasCommit = -not [string]::IsNullOrWhiteSpace($commits) -and $commits -match '(?i)\b[0-9a-f]{7,40}\b'
    $hasPullRequest = -not [string]::IsNullOrWhiteSpace($pullRequest) -and (
        $pullRequest -match '(?i)https://github\.com/[^\s/]+/[^\s/]+/pull/\d+' -or
        $pullRequest -match '(?<!\w)#\d+\b'
    )

    return [pscustomobject][ordered]@{
        path                 = $RelativePath
        absolutePath         = $AbsolutePath
        content              = $content
        status               = $status
        relatedCommits       = $commits
        relatedPullRequest   = $pullRequest
        hasCommitEvidence    = $hasCommit
        hasPullRequestEvidence = $hasPullRequest
        hasConcreteEvidence  = ($hasCommit -or $hasPullRequest)
        reconciliationStatus = $reconciliationStatus
        hasReconciliationSection = [bool]$reconciliation.SectionPresent
        reconciliationSectionMalformed = [bool]$reconciliation.Malformed
        reconciliationRows  = @($reconciliation.Rows)
        sha256               = Get-RepositoryFileHash -Path $AbsolutePath
    }
}

function Read-LegacyBaseline {
    param(
        [Parameter(Mandatory)] [string]$Root,
        [Parameter(Mandatory)] [string]$BaselinePath
    )

    $entries = @{}
    if (-not (Test-Path -LiteralPath $BaselinePath -PathType Leaf)) {
        Add-ValidationIssue -Severity error -Category 'legacy-baseline' -Path (Convert-ToRepositoryPath ($BaselinePath.Substring($Root.Length).TrimStart('\', '/'))) `
            -Message 'The hash-bound legacy note migration baseline is missing.'
        return $entries
    }

    try {
        $baseline = Get-Content -LiteralPath $BaselinePath -Raw | ConvertFrom-Json -AsHashtable
        foreach ($entry in @($baseline.entries)) {
            $path = Convert-ToRepositoryPath ([string]$entry.path)
            if (-not $path -or -not $entry.sha256) {
                Add-ValidationIssue -Severity error -Category 'legacy-baseline' -Path $path `
                    -Message 'Each baseline entry requires path and sha256.'
                continue
            }
            if ($entries.ContainsKey($path)) {
                Add-ValidationIssue -Severity error -Category 'legacy-baseline' -Path $path `
                    -Message 'Duplicate legacy baseline path.'
                continue
            }
            $entries[$path] = ([string]$entry.sha256).ToLowerInvariant()
        }
    } catch {
        Add-ValidationIssue -Severity error -Category 'legacy-baseline' -Path (Convert-ToRepositoryPath ($BaselinePath.Substring($Root.Length).TrimStart('\', '/'))) `
            -Message "Invalid legacy baseline JSON: $($_.Exception.Message)"
    }
    return $entries
}

function Read-MainlineIndex {
    param([Parameter(Mandatory)] [string]$IndexPath)

    $entries = @{}
    if (-not (Test-Path -LiteralPath $IndexPath -PathType Leaf)) {
        Add-ValidationIssue -Severity error -Category 'note-index' -Path 'docs/mainline-updates/README.md' `
            -Message 'Mainline update-note index is missing.'
        return $entries
    }

    foreach ($line in @(Get-Content -LiteralPath $IndexPath)) {
        if ($line -notmatch '\]\(\./([^)]+\.md)\)') { continue }
        $fileName = $Matches[1]
        $columns = @($line -split '\|' | ForEach-Object { $_.Trim() })
        if ($columns.Count -lt 6) { continue }
        $status = $columns[4]
        $path = "docs/mainline-updates/$fileName"
        if ($entries.ContainsKey($path)) {
            Add-ValidationIssue -Severity error -Category 'note-index' -Path $path -Message 'Duplicate index entry.'
        } else {
            $entries[$path] = $status
        }
    }
    return $entries
}

function Get-GitChangedPaths {
    param(
        [Parameter(Mandatory)] [string]$Root,
        [Parameter(Mandatory)] [string]$From,
        [Parameter(Mandatory)] [string]$To
    )

    $revisionRange = "$From...$To"
    $output = @(& git -C $Root diff --name-only --diff-filter=ACDMRTUXB $revisionRange -- 2>&1)
    $exitCode = if ($null -ne $LASTEXITCODE) { [int]$LASTEXITCODE } else { 0 }
    if ($exitCode -ne 0) {
        Add-ValidationIssue -Severity error -Category 'branch-diff' `
            -Message "Unable to read aggregate branch diff '$revisionRange': $($output -join ' ')"
        return @()
    }
    return @($output | ForEach-Object { Convert-ToRepositoryPath ([string]$_) } | Where-Object { $_ })
}

if (-not $WorkspaceRoot) {
    $WorkspaceRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
}
$WorkspaceRoot = [System.IO.Path]::GetFullPath($WorkspaceRoot)

$notesRoot = Join-Path $WorkspaceRoot 'docs/mainline-updates'
$indexPath = Join-Path $notesRoot 'README.md'
$baselinePath = Join-Path $WorkspaceRoot 'studio/runtime/mainline-note-validation-baseline.json'
$contractPath = Join-Path $WorkspaceRoot 'studio/runtime/shared-runtime-contract.json'
$registryPath = Join-Path $WorkspaceRoot 'studio/runtime/impact-registry.json'

$legacyBaseline = Read-LegacyBaseline -Root $WorkspaceRoot -BaselinePath $baselinePath
$indexEntries = Read-MainlineIndex -IndexPath $indexPath
$notes = [System.Collections.Generic.List[object]]::new()
$notesByPath = @{}

if (-not (Test-Path -LiteralPath $notesRoot -PathType Container)) {
    Add-ValidationIssue -Severity error -Category 'note-directory' -Path 'docs/mainline-updates' `
        -Message 'Mainline update-note directory is missing.'
} else {
    foreach ($file in @(Get-ChildItem -LiteralPath $notesRoot -File -Filter '*.md' | Where-Object Name -ne 'README.md' | Sort-Object Name)) {
        $relativePath = "docs/mainline-updates/$($file.Name)"
        $note = Read-MainlineNote -AbsolutePath $file.FullName -RelativePath $relativePath
        $notes.Add($note)
        $notesByPath[$relativePath] = $note

        if (-not $indexEntries.ContainsKey($relativePath)) {
            Add-ValidationIssue -Severity error -Category 'note-index' -Path $relativePath `
                -Message 'Note is missing from docs/mainline-updates/README.md.'
        } elseif ($indexEntries[$relativePath] -ne $note.status) {
            Add-ValidationIssue -Severity error -Category 'note-index-status' -Path $relativePath `
                -Message "Index status '$($indexEntries[$relativePath])' does not match note status '$($note.status)'."
        }

        $evidenceInvalid = (
            ($note.status -eq 'Ready' -and -not $note.hasConcreteEvidence) -or
            ($note.status -eq 'Merged' -and -not $note.hasCommitEvidence)
        )
        if ($evidenceInvalid) {
            $baselineMatches = $legacyBaseline.ContainsKey($relativePath) -and $legacyBaseline[$relativePath] -eq $note.sha256
            if ($baselineMatches) {
                $script:legacyBaselineApplied.Add($relativePath)
            } else {
                Add-ValidationIssue -Severity error -Category 'ready-evidence' -Path $relativePath `
                    -Message 'Ready requires a concrete commit hash or PR reference; Merged requires a concrete final commit hash.'
            }
        }
    }
}

foreach ($indexedPath in @($indexEntries.Keys)) {
    if (-not $notesByPath.ContainsKey($indexedPath)) {
        Add-ValidationIssue -Severity error -Category 'note-index' -Path $indexedPath `
            -Message 'Index entry points to a missing note.'
    }
}

foreach ($baselineEntry in @($legacyBaseline.GetEnumerator())) {
    $path = [string]$baselineEntry.Key
    if (-not $notesByPath.ContainsKey($path)) {
        Add-ValidationIssue -Severity error -Category 'legacy-baseline' -Path $path `
            -Message 'Legacy baseline entry points to a missing note.'
        continue
    }
    if ($notesByPath[$path].sha256 -ne [string]$baselineEntry.Value) {
        Add-ValidationIssue -Severity error -Category 'legacy-baseline-stale' -Path $path `
            -Message 'Legacy note changed; remove or refresh its baseline entry through the R5 evidence process.'
    }
}

$branchMode = $false
$changed = @()
if ($PSBoundParameters.ContainsKey('ChangedPaths') -or $PSBoundParameters.ContainsKey('ChangedPathsJson')) {
    if ($BaseRef -or ($PSBoundParameters.ContainsKey('ChangedPaths') -and $PSBoundParameters.ContainsKey('ChangedPathsJson'))) {
        Add-ValidationIssue -Severity error -Category 'arguments' -Message '-ChangedPaths, -ChangedPathsJson, and -BaseRef are mutually exclusive.'
    } else {
        $branchMode = $true
        $explicitPaths = @($ChangedPaths)
        if ($PSBoundParameters.ContainsKey('ChangedPathsJson')) {
            try {
                $explicitPaths = @($ChangedPathsJson | ConvertFrom-Json)
            } catch {
                Add-ValidationIssue -Severity error -Category 'arguments' -Message "ChangedPathsJson is invalid JSON: $($_.Exception.Message)"
                $explicitPaths = @()
            }
        }
        $changed = @($explicitPaths | ForEach-Object { Convert-ToRepositoryPath ([string]$_) } | Where-Object { $_ } | Sort-Object -Unique)
    }
} elseif ($BaseRef) {
    $branchMode = $true
    $changed = @(Get-GitChangedPaths -Root $WorkspaceRoot -From $BaseRef -To $HeadRef | Sort-Object -Unique)
}

$requiredTargets = [System.Collections.Generic.List[object]]::new()
$matchedRouteNames = [System.Collections.Generic.List[string]]::new()
$changedNotePaths = @()

if ($branchMode) {
    $contract = $null
    $registry = $null
    try {
        $contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json -AsHashtable
    } catch {
        Add-ValidationIssue -Severity error -Category 'contract' -Path 'studio/runtime/shared-runtime-contract.json' `
            -Message "Unable to read shared runtime contract: $($_.Exception.Message)"
    }
    try {
        $registry = Get-Content -LiteralPath $registryPath -Raw | ConvertFrom-Json -AsHashtable
    } catch {
        Add-ValidationIssue -Severity error -Category 'impact-registry' -Path 'studio/runtime/impact-registry.json' `
            -Message "Unable to read impact registry: $($_.Exception.Message)"
    }

    $changedNotePaths = @($changed | Where-Object {
        $_ -match '^docs/mainline-updates/\d{4}-\d{2}-\d{2}-[^/]+\.md$'
    })
    $changedNotes = @($changedNotePaths | Where-Object { $notesByPath.ContainsKey($_) } | ForEach-Object { $notesByPath[$_] })

    $nonNoteSharedChanges = @()
    if ($contract -and $contract.ContainsKey('sharedGatePaths')) {
        $nonNoteSharedChanges = @($changed | Where-Object {
            $candidate = $_
            $candidate -notmatch '^docs/mainline-updates/' -and
            @($contract.sharedGatePaths | Where-Object { Test-PathPattern -Path $candidate -Pattern ([string]$_) }).Count -gt 0
        })
    }

    if ($nonNoteSharedChanges.Count -gt 0 -and $changedNotes.Count -eq 0) {
        Add-ValidationIssue -Severity error -Category 'branch-note-missing' `
            -Message 'A shared-layer branch diff requires a changed mainline update note.'
    }

    $closedReadyNotes = @($changedNotes | Where-Object {
        $_.status -in @('Ready', 'Merged') -and
        $_.reconciliationStatus -eq 'Closed' -and
        $_.hasReconciliationSection -and
        -not $_.reconciliationSectionMalformed
    })
    if ($RequireReady -and $nonNoteSharedChanges.Count -gt 0 -and $closedReadyNotes.Count -eq 0) {
        Add-ValidationIssue -Severity error -Category 'branch-note-not-ready' `
            -Message 'A shared-layer branch diff requires a changed Ready or Merged note with Reconciliation Status: Closed.'
    }

    foreach ($note in @($changedNotes)) {
        if ($note.status -in @('Ready', 'Merged')) {
            if ($note.reconciliationStatus -ne 'Closed') {
                Add-ValidationIssue -Severity error -Category 'reconciliation-state' -Path $note.path `
                    -Message 'A changed Ready or Merged note requires Reconciliation Status: Closed.'
            }
            if (-not $note.hasReconciliationSection) {
                Add-ValidationIssue -Severity error -Category 'reconciliation-section-missing' -Path $note.path `
                    -Message 'A changed Ready or Merged note requires an Impact Reconciliation section.'
            }
            if ($note.reconciliationSectionMalformed) {
                Add-ValidationIssue -Severity error -Category 'reconciliation-section-malformed' -Path $note.path `
                    -Message 'Impact Reconciliation must be one visible, well-formed Markdown section outside comments and fenced blocks.'
            }
        }
        if ($note.path -in @($script:legacyBaselineApplied)) {
            Add-ValidationIssue -Severity error -Category 'legacy-baseline-note-changed' -Path $note.path `
                -Message 'A changed note cannot rely on the legacy Ready/TBD baseline; provide evidence or downgrade it to Draft and remove the baseline entry.'
        }
        if ($note.reconciliationStatus -eq 'Closed') {
            foreach ($row in @($note.reconciliationRows)) {
                if ($row.disposition -eq 'pending') {
                    Add-ValidationIssue -Severity error -Category 'reconciliation-pending' -Path $note.path `
                        -Message "Closed reconciliation contains a pending target: $($row.target)"
                }
                if ([string]::IsNullOrWhiteSpace($row.evidence) -or $row.evidence -match '^(?i:`?TBD`?|N/?A|-)$') {
                    Add-ValidationIssue -Severity error -Category 'reconciliation-evidence' -Path $note.path `
                        -Message "Reconciliation target requires concrete evidence: $($row.target)"
                }
            }
        }
    }

    if ($registry -and $registry.ContainsKey('impactRouting')) {
        $seenRouteMatches = @{}
        foreach ($route in @($registry.impactRouting)) {
            foreach ($trigger in @(([string]$route.trigger) -split '\|' | ForEach-Object { $_.Trim() })) {
                foreach ($path in $changed) {
                    if (-not (Test-PathPattern -Path $path -Pattern $trigger)) { continue }
                    $featureName = Get-FeatureNameForTrigger -Path $path -Trigger $trigger
                    $routeKey = "$($route.changeType)|$featureName"
                    if ($seenRouteMatches.ContainsKey($routeKey)) { continue }
                    $seenRouteMatches[$routeKey] = $true
                    $matchedRouteNames.Add($routeKey)

                    foreach ($rule in @($route.rules | Where-Object { $_.impact -eq 'must_update' })) {
                        $target = [string]$rule.target
                        if ($target -match '<feature>') {
                            if (-not $featureName) { continue }
                            $target = $target -replace '<feature>', [string]$featureName
                        }
                        $target = Convert-ToRepositoryPath $target
                        if (@($requiredTargets | Where-Object target -eq $target).Count -eq 0) {
                            $requiredTargets.Add([pscustomobject][ordered]@{
                                target     = $target
                                impact     = 'must_update'
                                changeType = [string]$route.changeType
                                reason     = [string]$rule.reason
                            })
                        }
                    }
                }
            }
        }

        foreach ($required in @($requiredTargets)) {
            $targetChanged = @($changed | Where-Object { Test-PathPattern -Path $_ -Pattern $required.target }).Count -gt 0
            if (-not $targetChanged) {
                Add-ValidationIssue -Severity error -Category 'must-update-target-missing' -Path $required.target `
                    -Message "Impact route '$($required.changeType)' requires this target in the aggregate branch diff."
            }

            $matchingRows = @($closedReadyNotes | ForEach-Object {
                $note = $_
                @($note.reconciliationRows | Where-Object { $_.target -eq $required.target }) | ForEach-Object {
                    [pscustomobject]@{ note = $note; row = $_ }
                }
            })
            if ($matchingRows.Count -eq 0) {
                if ($RequireReady) {
                    Add-ValidationIssue -Severity error -Category 'must-update-reconciliation-missing' -Path $required.target `
                        -Message 'No closed Ready-note reconciliation row covers this must_update target.'
                }
                continue
            }

            $accepted = @($matchingRows | Where-Object {
                $_.row.impact -eq 'must_update' -and $_.row.disposition -eq 'updated' -and
                -not [string]::IsNullOrWhiteSpace($_.row.evidence) -and $_.row.evidence -notmatch '^(?i:`?TBD`?|N/?A|-)$'
            })
            if ($accepted.Count -eq 0) {
                Add-ValidationIssue -Severity error -Category 'must-update-reconciliation-open' -Path $required.target `
                    -Message 'must_update requires disposition updated with concrete evidence; review-only or deferred dispositions do not close it.'
            }
        }
    }
}

$result = [pscustomobject][ordered]@{
    VALID                     = ($script:validationErrors.Count -eq 0)
    ERROR_COUNT               = $script:validationErrors.Count
    ERRORS                    = @($script:validationErrors)
    WARNING_COUNT             = $script:validationWarnings.Count
    WARNINGS                  = @($script:validationWarnings)
    NOTE_COUNT                = $notes.Count
    LEGACY_BASELINE_COUNT     = $legacyBaseline.Count
    LEGACY_BASELINE_APPLIED   = @($script:legacyBaselineApplied)
    BRANCH_MODE               = $branchMode
    CHANGED_PATH_COUNT        = $changed.Count
    CHANGED_NOTE_PATHS        = @($changedNotePaths)
    MATCHED_IMPACT_ROUTES     = @($matchedRouteNames)
    REQUIRED_RECONCILIATIONS  = @($requiredTargets)
}

if ($Json) {
    $result | ConvertTo-Json -Depth 12
} else {
    Write-Host "Mainline notes: $($result.NOTE_COUNT)"
    Write-Host "Errors: $($result.ERROR_COUNT); warnings: $($result.WARNING_COUNT)"
    foreach ($issue in @($result.ERRORS)) {
        $suffix = if ($issue.path) { " [$($issue.path)]" } else { '' }
        Write-Host "[ERROR] $($issue.message)$suffix" -ForegroundColor Red
    }
    foreach ($issue in @($result.WARNINGS)) {
        $suffix = if ($issue.path) { " [$($issue.path)]" } else { '' }
        Write-Host "[WARN] $($issue.message)$suffix" -ForegroundColor Yellow
    }
}

if ($result.VALID) { exit 0 }
exit 1
