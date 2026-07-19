#Requires -Version 7.0

[CmdletBinding()]
param(
    [string]$WorkspaceRoot,
    [string]$BaseRef,
    [string]$HeadRef = 'HEAD',
    [string[]]$ChangedPaths,
    [string]$ChangedPathsJson,
    [switch]$RequireReady,
    [ValidateSet('Aggregate', 'Batch')]
    [string]$ReadinessScope,
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
Explicit changed paths for nonblocking structural validation and deterministic
tests. Mutually exclusive with -BaseRef and insufficient for -RequireReady.

.PARAMETER ChangedPathsJson
JSON array form of explicit changed paths for cross-process callers and tests.

.PARAMETER RequireReady
Require a changed Ready or Merged note whose Reconciliation Status is Closed.
Requires -BaseRef so commit-range membership and last-touch coverage are
verifiable.

.PARAMETER ReadinessScope
Aggregate also enforces any configured aggregate-note anchor. Batch validates
only the supplied diff as one coherent batch. All evidence, section,
reconciliation, and changed-path coverage checks still apply. The caller must
set this parameter explicitly whenever -RequireReady is used.

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

function Get-VisibleMarkdownSurface {
    param([Parameter(Mandatory)] [string]$Content)

    $visibleLines = [System.Collections.Generic.List[string]]::new()
    $inHtmlComment = $false
    $fenceCharacter = $null
    $fenceLength = 0
    $rawHtmlEndPattern = $null
    $rawHtmlEndsOnBlank = $false

    foreach ($rawLine in @($Content -split "`r?`n")) {
        $visibleLine = [string]$rawLine

        if ($fenceCharacter) {
            $closingPattern = (
                '^ {0,3}' +
                [regex]::Escape($fenceCharacter) +
                "{$fenceLength,}[ \t]*$"
            )
            if ($visibleLine -match $closingPattern) {
                $fenceCharacter = $null
                $fenceLength = 0
            }
            $visibleLines.Add('')
            continue
        }

        if ($rawHtmlEndPattern -or $rawHtmlEndsOnBlank) {
            $rawHtmlBlockEnded = $false
            if ($rawHtmlEndPattern -and $visibleLine -match $rawHtmlEndPattern) {
                $rawHtmlBlockEnded = $true
            } elseif ($rawHtmlEndsOnBlank -and [string]::IsNullOrWhiteSpace($visibleLine)) {
                $rawHtmlBlockEnded = $true
            }
            if ($rawHtmlBlockEnded) {
                $rawHtmlEndPattern = $null
                $rawHtmlEndsOnBlank = $false
            }
            $visibleLines.Add('')
            continue
        }

        # Four-space and tab-indented code is not visible governance metadata.
        # Check before interpreting comment markers so code cannot change parser
        # state for the following surface.
        if (-not $inHtmlComment -and $visibleLine -match '^(?: {4}| {0,3}\t)') {
            $visibleLines.Add('')
            continue
        }

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

        if ($visibleLine -match '^(?: {4}| {0,3}\t)') {
            $visibleLines.Add('')
            continue
        }
        if ($visibleLine -match '(?i)^ {0,3}<(script|pre|style|textarea)(?:[ \t]|>|$)') {
            $rawTag = [regex]::Escape($Matches[1])
            $closingTagPattern = "(?i)</$rawTag[ \t]*>"
            if ($visibleLine -notmatch $closingTagPattern) {
                $rawHtmlEndPattern = $closingTagPattern
            }
            $visibleLines.Add('')
            continue
        }
        if ($visibleLine -match '^ {0,3}<\?') {
            if ($visibleLine -notmatch '\?>') {
                $rawHtmlEndPattern = '\?>'
            }
            $visibleLines.Add('')
            continue
        }
        if ($visibleLine -match '^ {0,3}<!\[CDATA\[') {
            if ($visibleLine -notmatch '\]\]>') {
                $rawHtmlEndPattern = '\]\]>'
            }
            $visibleLines.Add('')
            continue
        }
        if ($visibleLine -match '^ {0,3}<![A-Z]') {
            if ($visibleLine -notmatch '>') {
                $rawHtmlEndPattern = '>'
            }
            $visibleLines.Add('')
            continue
        }
        if ($visibleLine -match '(?i)^ {0,3}</?[A-Za-z][A-Za-z0-9-]*(?:[ \t]|/?>|$)') {
            # CommonMark block-tag and complete-tag HTML blocks terminate at
            # the next blank line. A conservative generic tag match keeps
            # rendered literal HTML from becoming governance evidence.
            $rawHtmlEndsOnBlank = $true
            $visibleLines.Add('')
            continue
        }
        if ($visibleLine -match '^ {0,3}(`{3,}|~{3,})') {
            $fenceCharacter = $Matches[1].Substring(0, 1)
            $fenceLength = $Matches[1].Length
            $visibleLines.Add('')
            continue
        }

        $visibleLines.Add($visibleLine)
    }

    return [pscustomobject][ordered]@{
        Lines                   = @($visibleLines)
        UnterminatedHiddenBlock = [bool](
            $inHtmlComment -or
            $fenceCharacter -or
            $rawHtmlEndPattern -or
            $rawHtmlEndsOnBlank
        )
    }
}

function Get-MarkdownFieldValues {
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [AllowEmptyCollection()] [string[]]$VisibleLines,
        [Parameter(Mandatory)] [string]$Name
    )

    $pattern = '^ {0,3}\*\*' + [regex]::Escape($Name) + '\*\*:[ \t]*(.+?)[ \t]*$'
    return @(
        $VisibleLines |
            ForEach-Object {
                if ([string]$_ -match $pattern) {
                    $Matches[1].Trim()
                }
            }
    )
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
        $regexBody = [regex]::Escape($matchPattern)
        # A complete-category rule such as "studio/scripts/powershell/**" must
        # cover every descendant, including nested directories. A middle /**
        # segment also permits zero directory levels.
        $regexBody = $regexBody -replace '/\\\*\\\*/', '(?:/.*/)?'
        $regexBody = $regexBody -replace '/\\\*\\\*$', '(?:/.*)?'
        $regexBody = $regexBody.Replace('\*\*', '.*').Replace('\*', '[^/]*')
        return [regex]::IsMatch(
            $normalizedPath,
            "^$regexBody$",
            [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor
                [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )
    }
    if ($matchPattern.EndsWith('/', [System.StringComparison]::Ordinal)) {
        return $normalizedPath.StartsWith($matchPattern, [System.StringComparison]::OrdinalIgnoreCase)
    }
    return $normalizedPath.Equals($matchPattern, [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-VisibleH2SectionCounts {
    param([Parameter(Mandatory)] [AllowEmptyString()] [AllowEmptyCollection()] [string[]]$VisibleLines)

    $counts = @{}
    foreach ($visibleLine in @($VisibleLines)) {
        if ([string]$visibleLine -match '^ {0,3}##[ \t]+(.+?)[ \t]*$') {
            $name = $Matches[1].Trim()
            if (-not $counts.ContainsKey($name)) {
                $counts[$name] = 0
            }
            $counts[$name]++
        }
    }

    return $counts
}

function Get-CommitReferences {
    param([AllowNull()] [string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) { return @() }
    return @(
        [regex]::Matches($Value, '(?i)\b[0-9a-f]{7,40}\b') |
            ForEach-Object { $_.Value.ToLowerInvariant() } |
            Select-Object -Unique
    )
}

function Get-PullRequestReferences {
    param([AllowNull()] [string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) { return @() }
    $pattern = '(?i)https://github\.com/(?<owner>[A-Za-z0-9_.-]+)/(?<repo>[A-Za-z0-9_.-]+?)(?:\.git)?/pull/(?<number>\d+)(?=$|[\s`),.;])'
    return @(
        [regex]::Matches($Value, $pattern) | ForEach-Object {
            [pscustomobject][ordered]@{
                url        = $_.Value
                repository = "$($_.Groups['owner'].Value)/$($_.Groups['repo'].Value)".ToLowerInvariant()
                number     = [int]$_.Groups['number'].Value
            }
        }
    )
}

function Invoke-GitCapture {
    param(
        [Parameter(Mandatory)] [string]$Root,
        [Parameter(Mandatory)] [string[]]$Arguments
    )

    $output = @(& git -C $Root @Arguments 2>&1)
    $exitCode = if ($null -ne $LASTEXITCODE) { [int]$LASTEXITCODE } else { 0 }
    return [pscustomobject][ordered]@{
        ExitCode = $exitCode
        Output   = @($output)
    }
}

function Get-GitRepositorySlug {
    param([Parameter(Mandatory)] [string]$Root)

    $remoteResult = Invoke-GitCapture -Root $Root -Arguments @('remote', 'get-url', 'origin')
    if ($remoteResult.ExitCode -ne 0 -or $remoteResult.Output.Count -eq 0) {
        return $null
    }

    $remote = ([string]$remoteResult.Output[0]).Trim()
    $patterns = @(
        '(?i)^https?://github\.com/(?<owner>[^/\s]+)/(?<repo>[^/\s]+?)(?:\.git)?/?$',
        '(?i)^git@github\.com:(?<owner>[^/\s]+)/(?<repo>[^/\s]+?)(?:\.git)?$',
        '(?i)^ssh://git@github\.com/(?<owner>[^/\s]+)/(?<repo>[^/\s]+?)(?:\.git)?/?$'
    )
    foreach ($pattern in $patterns) {
        if ($remote -match $pattern) {
            return "$($Matches['owner'])/$($Matches['repo'])".ToLowerInvariant()
        }
    }
    return $null
}

function Resolve-GitCommit {
    param(
        [Parameter(Mandatory)] [string]$Root,
        [Parameter(Mandatory)] [string]$Reference
    )

    $result = Invoke-GitCapture -Root $Root -Arguments @('rev-parse', '--verify', "$Reference^{commit}")
    if ($result.ExitCode -ne 0 -or $result.Output.Count -eq 0) {
        return $null
    }
    $resolved = ([string]$result.Output[-1]).Trim().ToLowerInvariant()
    if ($resolved -notmatch '^[0-9a-f]{40}$') {
        return $null
    }
    return $resolved
}

function Get-GitBranchContext {
    param(
        [Parameter(Mandatory)] [string]$Root,
        [Parameter(Mandatory)] [string]$From,
        [Parameter(Mandatory)] [string]$To
    )

    $mergeBaseResult = Invoke-GitCapture -Root $Root -Arguments @('merge-base', $From, $To)
    if ($mergeBaseResult.ExitCode -ne 0 -or $mergeBaseResult.Output.Count -eq 0) {
        Add-ValidationIssue -Severity error -Category 'branch-commits' `
            -Message "Unable to resolve merge base for '$From' and '$To'."
        return $null
    }
    $mergeBase = ([string]$mergeBaseResult.Output[-1]).Trim().ToLowerInvariant()

    $commitResult = Invoke-GitCapture -Root $Root -Arguments @('rev-list', "$mergeBase..$To")
    if ($commitResult.ExitCode -ne 0) {
        Add-ValidationIssue -Severity error -Category 'branch-commits' `
            -Message "Unable to enumerate branch commits for '$mergeBase..$To'."
        return $null
    }

    $commitSet = @{}
    foreach ($line in @($commitResult.Output)) {
        $commit = ([string]$line).Trim().ToLowerInvariant()
        if ($commit -match '^[0-9a-f]{40}$') {
            $commitSet[$commit] = $true
        }
    }

    return [pscustomobject][ordered]@{
        MergeBase = $mergeBase
        Commits   = $commitSet
    }
}

function Get-GitLastTouchCommit {
    param(
        [Parameter(Mandatory)] [string]$Root,
        [Parameter(Mandatory)] [string]$MergeBase,
        [Parameter(Mandatory)] [string]$Head,
        [Parameter(Mandatory)] [string]$Path
    )

    $result = Invoke-GitCapture -Root $Root -Arguments @(
        'log', '-1', '--format=%H', "$MergeBase..$Head", '--', $Path
    )
    if ($result.ExitCode -ne 0 -or $result.Output.Count -eq 0) {
        return $null
    }
    $commit = ([string]$result.Output[-1]).Trim().ToLowerInvariant()
    if ($commit -notmatch '^[0-9a-f]{40}$') {
        return $null
    }
    return $commit
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
    param(
        [Parameter(Mandatory)] [AllowEmptyString()] [AllowEmptyCollection()] [string[]]$VisibleLines,
        [bool]$UnterminatedHiddenBlock
    )

    $rows = [System.Collections.Generic.List[object]]::new()
    $sectionCount = 0
    $inSection = $false
    $sectionMalformed = $false

    foreach ($visibleLine in @($VisibleLines)) {
        if ([string]$visibleLine -match '^ {0,3}##[ \t]+Impact Reconciliation[ \t]*$') {
            $sectionCount++
            $inSection = $true
            continue
        }
        if ($inSection -and [string]$visibleLine -match '^ {0,3}##[ \t]+') {
            $inSection = $false
        }
        if (-not $inSection) { continue }

        if ([string]$visibleLine -notmatch '^ {0,3}\|\s*(.+?)\s*\|\s*`?(must_update|must_review|maybe_review)`?\s*\|\s*`?(updated|reviewed-no-change|deferred-owner-approved|pending)`?\s*\|\s*(.*?)\s*\|\s*$') {
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

    if ($inSection -and $UnterminatedHiddenBlock) {
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
    $surface = Get-VisibleMarkdownSurface -Content $content
    $metadataValues = @{}
    foreach ($fieldName in @('Status', 'Related Commits', 'Related PR', 'Reconciliation Status')) {
        $metadataValues[$fieldName] = @(
            Get-MarkdownFieldValues -VisibleLines $surface.Lines -Name $fieldName
        )
        if ($metadataValues[$fieldName].Count -gt 1) {
            Add-ValidationIssue -Severity error -Category 'note-metadata-count' -Path $RelativePath `
                -Message "Governance metadata field '$fieldName' must appear exactly once on the visible Markdown surface."
        }
    }
    if ($metadataValues.Status.Count -eq 0) {
        Add-ValidationIssue -Severity error -Category 'note-metadata-count' -Path $RelativePath `
            -Message "Governance metadata field 'Status' must appear exactly once on the visible Markdown surface."
    }
    $status = if ($metadataValues.Status.Count -gt 0) { $metadataValues.Status[0] } else { $null }
    $commits = if ($metadataValues.'Related Commits'.Count -gt 0) { $metadataValues.'Related Commits'[0] } else { $null }
    $pullRequest = if ($metadataValues.'Related PR'.Count -gt 0) { $metadataValues.'Related PR'[0] } else { $null }
    $reconciliationStatus = if ($metadataValues.'Reconciliation Status'.Count -gt 0) {
        $metadataValues.'Reconciliation Status'[0]
    } else {
        $null
    }
    $reconciliation = Read-ReconciliationRows -VisibleLines $surface.Lines `
        -UnterminatedHiddenBlock $surface.UnterminatedHiddenBlock
    $sectionCounts = Get-VisibleH2SectionCounts -VisibleLines $surface.Lines
    $requiredSections = @('Scope', 'Impact', 'Validation')
    $missingRequiredSections = @(
        $requiredSections | Where-Object {
            -not $sectionCounts.ContainsKey($_) -or [int]$sectionCounts[$_] -eq 0
        }
    )
    $duplicateRequiredSections = @(
        $requiredSections | Where-Object {
            $sectionCounts.ContainsKey($_) -and [int]$sectionCounts[$_] -gt 1
        }
    )
    $commitReferences = @(Get-CommitReferences -Value $commits)
    $pullRequestReferences = @(Get-PullRequestReferences -Value $pullRequest)
    $hasUnqualifiedPullRequest = (
        -not [string]::IsNullOrWhiteSpace($pullRequest) -and
        $pullRequest -match '(?<![\w/])#\d+\b'
    )

    if ($status -notin @('Draft', 'Ready', 'Merged')) {
        Add-ValidationIssue -Severity error -Category 'note-status' -Path $RelativePath `
            -Message 'Status must be exactly Draft, Ready, or Merged.'
    }

    return [pscustomobject][ordered]@{
        path                 = $RelativePath
        absolutePath         = $AbsolutePath
        content              = $content
        status               = $status
        relatedCommits       = $commits
        relatedPullRequest   = $pullRequest
        commitReferences     = @($commitReferences)
        pullRequestReferences = @($pullRequestReferences)
        hasUnqualifiedPullRequest = [bool]$hasUnqualifiedPullRequest
        validCommitHashes    = @()
        validInRangeCommitHashes = @()
        hasCommitEvidence    = $false
        hasPullRequestEvidence = $false
        hasConcreteEvidence  = $false
        evidenceValid        = $false
        missingRequiredSections = @($missingRequiredSections)
        duplicateRequiredSections = @($duplicateRequiredSections)
        requiredSectionsValid = (
            $missingRequiredSections.Count -eq 0 -and
            $duplicateRequiredSections.Count -eq 0
        )
        metadataFieldCounts    = [ordered]@{
            Status                  = $metadataValues.Status.Count
            'Related Commits'       = $metadataValues.'Related Commits'.Count
            'Related PR'            = $metadataValues.'Related PR'.Count
            'Reconciliation Status' = $metadataValues.'Reconciliation Status'.Count
        }
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
    $result = Invoke-GitCapture -Root $Root -Arguments @(
        'diff', '--name-status', '-z', '--find-renames',
        '--diff-filter=ACDMRTUXB', $revisionRange, '--'
    )
    if ($result.ExitCode -ne 0) {
        Add-ValidationIssue -Severity error -Category 'branch-diff' `
            -Message "Unable to read aggregate branch diff '$revisionRange': $($result.Output -join ' ')"
        return [pscustomobject][ordered]@{ Paths = @(); Records = @() }
    }

    $raw = $result.Output -join "`n"
    $tokens = @($raw.Split([char]0, [System.StringSplitOptions]::RemoveEmptyEntries))
    $paths = [System.Collections.Generic.List[string]]::new()
    $records = [System.Collections.Generic.List[object]]::new()

    for ($index = 0; $index -lt $tokens.Count;) {
        $status = ([string]$tokens[$index]).Trim()
        $index++
        if (-not $status) { continue }

        if ($status -match '^[RC]\d{1,3}$') {
            if (($index + 1) -ge $tokens.Count) {
                Add-ValidationIssue -Severity error -Category 'branch-diff' `
                    -Message "Malformed name-status record '$status' in '$revisionRange'."
                break
            }
            $oldPath = Convert-ToRepositoryPath ([string]$tokens[$index])
            $newPath = Convert-ToRepositoryPath ([string]$tokens[$index + 1])
            $index += 2
            if ($oldPath) { $paths.Add($oldPath) }
            if ($newPath) { $paths.Add($newPath) }
            $records.Add([pscustomobject][ordered]@{
                status  = $status
                oldPath = $oldPath
                newPath = $newPath
            })
            continue
        }

        if ($index -ge $tokens.Count) {
            Add-ValidationIssue -Severity error -Category 'branch-diff' `
                -Message "Malformed name-status record '$status' in '$revisionRange'."
            break
        }
        $path = Convert-ToRepositoryPath ([string]$tokens[$index])
        $index++
        if ($path) { $paths.Add($path) }
        $records.Add([pscustomobject][ordered]@{
            status  = $status
            oldPath = $null
            newPath = $path
        })
    }

    return [pscustomobject][ordered]@{
        Paths   = @($paths | Sort-Object -Unique)
        Records = @($records)
    }
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
$baseRefMode = $false
$changed = @()
$changedPathRecords = @()
$branchContext = $null

if ($RequireReady -and -not $PSBoundParameters.ContainsKey('ReadinessScope')) {
    Add-ValidationIssue -Severity error -Category 'arguments' `
        -Message '-RequireReady requires an explicit -ReadinessScope Aggregate or -ReadinessScope Batch.'
}

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
    $baseRefMode = $true
    $diffResult = Get-GitChangedPaths -Root $WorkspaceRoot -From $BaseRef -To $HeadRef
    $changed = @($diffResult.Paths)
    $changedPathRecords = @($diffResult.Records)
    $branchContext = Get-GitBranchContext -Root $WorkspaceRoot -From $BaseRef -To $HeadRef
}

if ($RequireReady -and -not $baseRefMode) {
    Add-ValidationIssue -Severity error -Category 'arguments' `
        -Message '-RequireReady requires -BaseRef so commit-range membership and last-touch path coverage can be verified.'
}

$requiredTargets = [System.Collections.Generic.List[object]]::new()
$matchedRouteNames = [System.Collections.Generic.List[string]]::new()
$changedNotePaths = if ($branchMode) {
    @($changed | Where-Object {
        $_ -match '^docs/mainline-updates/\d{4}-\d{2}-\d{2}-[^/]+\.md$'
    })
} else {
    @()
}
$changedNotes = @(
    $changedNotePaths |
        Where-Object { $notesByPath.ContainsKey($_) } |
        ForEach-Object { $notesByPath[$_] }
)

$gitProbe = Invoke-GitCapture -Root $WorkspaceRoot -Arguments @('rev-parse', '--is-inside-work-tree')
$gitAvailable = (
    $gitProbe.ExitCode -eq 0 -and
    $gitProbe.Output.Count -gt 0 -and
    ([string]$gitProbe.Output[-1]).Trim() -eq 'true'
)
$originRepositorySlug = if ($gitAvailable) { Get-GitRepositorySlug -Root $WorkspaceRoot } else { $null }
$configuredRepositorySlug = $null
if (Test-Path -LiteralPath $contractPath -PathType Leaf) {
    try {
        $evidenceContract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json -AsHashtable
        if (
            $evidenceContract.ContainsKey('mainlineReadiness') -and
            $evidenceContract.mainlineReadiness -is [System.Collections.IDictionary] -and
            $evidenceContract.mainlineReadiness.ContainsKey('repositorySlug')
        ) {
            $configuredSlugCandidate = ([string]$evidenceContract.mainlineReadiness.repositorySlug).Trim().ToLowerInvariant()
            if ($configuredSlugCandidate -match '^[a-z0-9_.-]+/[a-z0-9_.-]+$') {
                $configuredRepositorySlug = $configuredSlugCandidate
            }
        }
    } catch {
        # Contract parsing is reported by the canonical audit and branch-mode
        # validator. Evidence remains fail-closed when no repository can be resolved.
    }
}
# The contract is the machine-bound repository identity. A mutable local
# origin may help only when no canonical policy is configured; it must never
# redefine which repository owns acceptable pull-request evidence.
$repositorySlug = if ($configuredRepositorySlug) {
    $configuredRepositorySlug
} else {
    $originRepositorySlug
}

foreach ($note in @($notes)) {
    if ($note.status -notin @('Ready', 'Merged')) { continue }

    $noteChanged = $branchMode -and $note.path -in $changedNotePaths
    $evidenceHasErrors = $false
    $validCommitHashes = [System.Collections.Generic.List[string]]::new()
    $validInRangeCommitHashes = [System.Collections.Generic.List[string]]::new()

    if ($RequireReady -and -not $gitAvailable) {
        $evidenceHasErrors = $true
        Add-ValidationIssue -Severity error -Category 'commit-evidence-git-context-required' -Path $note.path `
            -Message 'Blocking readiness cannot verify commit evidence without an available Git worktree and BaseRef.'
    }

    foreach ($reference in @($note.commitReferences)) {
        if (-not $gitAvailable) {
            # Global validation is also used by isolated runtime-audit fixtures
            # that intentionally have no .git directory. Only nonblocking
            # structural validation may use this shape-only fallback.
            if (-not $RequireReady) {
                $validCommitHashes.Add([string]$reference)
            }
            continue
        }

        $resolved = Resolve-GitCommit -Root $WorkspaceRoot -Reference ([string]$reference)
        if (-not $resolved) {
            $evidenceHasErrors = $true
            Add-ValidationIssue -Severity error -Category 'commit-evidence-object-invalid' -Path $note.path `
                -Message "Related commit '$reference' does not resolve to a commit object."
            continue
        }
        $validCommitHashes.Add($resolved)

        if ($baseRefMode -and $noteChanged) {
            if (-not $branchContext -or -not $branchContext.Commits.ContainsKey($resolved)) {
                $evidenceHasErrors = $true
                Add-ValidationIssue -Severity error -Category 'commit-evidence-out-of-range' -Path $note.path `
                    -Message "Related commit '$reference' is outside the merge-base..HeadRef branch range."
                continue
            }
            $validInRangeCommitHashes.Add($resolved)
        }
    }

    $note.validCommitHashes = @($validCommitHashes | Sort-Object -Unique)
    $note.validInRangeCommitHashes = @($validInRangeCommitHashes | Sort-Object -Unique)
    $note.hasCommitEvidence = ($note.validCommitHashes.Count -gt 0)

    $pullRequestFieldIsPlaceholder = (
        [string]::IsNullOrWhiteSpace($note.relatedPullRequest) -or
        $note.relatedPullRequest -match '^(?i:`?N/?A`?|`?TBD`?|-)$'
    )
    $validPullRequestCount = 0
    if ($note.hasUnqualifiedPullRequest) {
        $evidenceHasErrors = $true
        Add-ValidationIssue -Severity error -Category 'pr-evidence-unqualified' -Path $note.path `
            -Message 'An unqualified #N reference does not prove which repository owns the pull request; use a fully qualified GitHub pull-request URL.'
    }
    foreach ($pullRequestReference in @($note.pullRequestReferences)) {
        if (-not $repositorySlug) {
            $evidenceHasErrors = $true
            Add-ValidationIssue -Severity error -Category 'pr-evidence-repository-unresolved' -Path $note.path `
                -Message 'The origin GitHub repository could not be resolved for pull-request evidence.'
            continue
        }
        if ($pullRequestReference.repository -ne $repositorySlug) {
            $evidenceHasErrors = $true
            Add-ValidationIssue -Severity error -Category 'pr-evidence-repository-mismatch' -Path $note.path `
                -Message "Pull-request evidence belongs to '$($pullRequestReference.repository)', not '$repositorySlug'."
            continue
        }
        $validPullRequestCount++
    }
    if (-not $pullRequestFieldIsPlaceholder -and
        $note.pullRequestReferences.Count -eq 0 -and
        -not $note.hasUnqualifiedPullRequest) {
        $evidenceHasErrors = $true
        Add-ValidationIssue -Severity error -Category 'pr-evidence-format' -Path $note.path `
            -Message 'Related PR must be N/A, TBD while Draft, or a fully qualified GitHub pull-request URL.'
    }

    $note.hasPullRequestEvidence = ($validPullRequestCount -gt 0)
    $note.hasConcreteEvidence = ($note.hasCommitEvidence -or $note.hasPullRequestEvidence)

    $evidenceInvalid = (
        ($note.status -eq 'Ready' -and -not $note.hasConcreteEvidence) -or
        ($note.status -eq 'Merged' -and -not $note.hasCommitEvidence)
    )
    if ($evidenceInvalid) {
        $baselineMatches = (
            $legacyBaseline.ContainsKey($note.path) -and
            $legacyBaseline[$note.path] -eq $note.sha256
        )
        if ($baselineMatches) {
            $script:legacyBaselineApplied.Add($note.path)
        } else {
            Add-ValidationIssue -Severity error -Category 'ready-evidence' -Path $note.path `
                -Message 'Ready requires a verified commit hash or repository-bound PR URL; Merged requires a verified final commit hash.'
        }
    }
    $note.evidenceValid = (-not $evidenceHasErrors -and -not $evidenceInvalid)
}

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

    foreach ($note in @($changedNotes)) {
        if ($note.status -in @('Ready', 'Merged')) {
            foreach ($fieldName in @('Status', 'Related Commits', 'Related PR', 'Reconciliation Status')) {
                if ([int]$note.metadataFieldCounts[$fieldName] -eq 0) {
                    Add-ValidationIssue -Severity error -Category 'note-metadata-count' -Path $note.path `
                        -Message "A changed Ready or Merged note requires exactly one visible '$fieldName' metadata field."
                }
            }
            foreach ($section in @($note.missingRequiredSections)) {
                Add-ValidationIssue -Severity error -Category 'required-section-missing' -Path $note.path `
                    -Message "A changed Ready or Merged note requires one visible exact '## $section' section outside comments and fenced blocks."
            }
            foreach ($section in @($note.duplicateRequiredSections)) {
                Add-ValidationIssue -Severity error -Category 'required-section-duplicate' -Path $note.path `
                    -Message "A changed Ready or Merged note contains more than one visible exact '## $section' section."
            }
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

    $closedReadyNotes = @($changedNotes | Where-Object {
        $_.status -in @('Ready', 'Merged') -and
        $_.reconciliationStatus -eq 'Closed' -and
        $_.hasReconciliationSection -and
        -not $_.reconciliationSectionMalformed -and
        $_.requiredSectionsValid -and
        $_.evidenceValid -and
        @($_.reconciliationRows | Where-Object {
            $_.disposition -eq 'pending' -or
            [string]::IsNullOrWhiteSpace($_.evidence) -or
            $_.evidence -match '^(?i:`?TBD`?|N/?A|-)$'
        }).Count -eq 0
    })
    if ($RequireReady -and $nonNoteSharedChanges.Count -gt 0 -and $closedReadyNotes.Count -eq 0) {
        Add-ValidationIssue -Severity error -Category 'branch-note-not-ready' `
            -Message 'A shared-layer branch diff requires a changed Ready or Merged note with verified evidence, required sections, and Reconciliation Status: Closed.'
    }

    $configuredAggregatePaths = @()
    if ($contract -and
        $contract.ContainsKey('mainlineReadiness') -and
        $contract.mainlineReadiness -is [System.Collections.IDictionary] -and
        $contract.mainlineReadiness.ContainsKey('aggregateNotePaths')) {
        $configuredAggregatePaths = @(
            $contract.mainlineReadiness.aggregateNotePaths |
                ForEach-Object { Convert-ToRepositoryPath ([string]$_) } |
                Where-Object { $_ } |
                Sort-Object -Unique
        )
    }
    $changedAggregatePaths = @($configuredAggregatePaths | Where-Object { $_ -in $changed })
    $eligibleAggregateNotes = [System.Collections.Generic.List[object]]::new()
    $aggregateCoverageDeferred = $false

    if ($RequireReady -and $ReadinessScope -eq 'Aggregate') {
        if ($configuredAggregatePaths.Count -eq 0) {
            $aggregateCoverageDeferred = $true
            Add-ValidationIssue -Severity error -Category 'aggregate-note-policy-missing' `
                -Path 'studio/runtime/shared-runtime-contract.json' `
                -Message 'Aggregate readiness requires at least one machine-configured aggregate note path.'
        }
        foreach ($aggregatePath in $configuredAggregatePaths) {
            $aggregateNote = if ($notesByPath.ContainsKey($aggregatePath)) {
                $notesByPath[$aggregatePath]
            } else {
                $null
            }
            $aggregateNoteEligible = (
                $null -ne $aggregateNote -and
                $aggregateNote.status -in @('Ready', 'Merged') -and
                $aggregateNote.reconciliationStatus -eq 'Closed' -and
                $aggregateNote.hasReconciliationSection -and
                -not $aggregateNote.reconciliationSectionMalformed -and
                $aggregateNote.requiredSectionsValid -and
                $aggregateNote.evidenceValid -and
                @($aggregateNote.reconciliationRows | Where-Object {
                    $_.disposition -eq 'pending' -or
                    [string]::IsNullOrWhiteSpace($_.evidence) -or
                    $_.evidence -match '^(?i:`?TBD`?|N/?A|-)$'
                }).Count -eq 0
            )
            if (-not $aggregateNoteEligible) {
                $aggregateCoverageDeferred = $true
                Add-ValidationIssue -Severity error -Category 'aggregate-note-not-ready' -Path $aggregatePath `
                    -Message 'Every configured aggregate note at HeadRef must be Ready or Merged, Closed, structurally complete, and backed by verified evidence.'
                continue
            }
            if ($aggregatePath -in $changedAggregatePaths) {
                $eligibleAggregateNotes.Add($aggregateNote)
            }
        }
    }

    if ($RequireReady -and $baseRefMode -and $branchContext -and $nonNoteSharedChanges.Count -gt 0) {
        $coverageNotes = @($closedReadyNotes)
        if ($ReadinessScope -eq 'Aggregate') {
            if ($aggregateCoverageDeferred) {
                $coverageNotes = @()
            } elseif ($changedAggregatePaths.Count -gt 0) {
                $coverageNotes = @($eligibleAggregateNotes)
            }
        }

        # A Draft aggregate anchor is already a decisive blocker. Defer the
        # path-by-path noise until every configured anchor is eligible.
        if (-not ($ReadinessScope -eq 'Aggregate' -and $aggregateCoverageDeferred)) {
            $coveredCommitSet = @{}
            foreach ($coverageNote in $coverageNotes) {
                foreach ($commit in @($coverageNote.validInRangeCommitHashes)) {
                    $coveredCommitSet[[string]$commit] = $true
                }
            }

            foreach ($sharedPath in $nonNoteSharedChanges) {
                $lastTouch = Get-GitLastTouchCommit -Root $WorkspaceRoot `
                    -MergeBase $branchContext.MergeBase -Head $HeadRef -Path $sharedPath
                if (-not $lastTouch) {
                    Add-ValidationIssue -Severity error -Category 'branch-evidence-coverage-unresolved' -Path $sharedPath `
                        -Message 'Unable to resolve the last branch commit that changed this shared path.'
                    continue
                }
                if (-not $coveredCommitSet.ContainsKey($lastTouch)) {
                    Add-ValidationIssue -Severity error -Category 'branch-evidence-coverage-missing' -Path $sharedPath `
                        -Message "No eligible Ready-note evidence cites this path's last-touch commit '$($lastTouch.Substring(0, 7))'."
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
    BASE_REF_MODE             = $baseRefMode
    READINESS_SCOPE           = if ($PSBoundParameters.ContainsKey('ReadinessScope')) { $ReadinessScope } else { $null }
    MERGE_BASE                = if ($branchContext) { $branchContext.MergeBase } else { $null }
    CHANGED_PATH_COUNT        = $changed.Count
    CHANGED_PATHS             = @($changed)
    CHANGED_PATH_RECORDS      = @($changedPathRecords)
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
