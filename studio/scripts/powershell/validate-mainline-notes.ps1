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
$script:historicalEvidenceApplied = [System.Collections.Generic.List[string]]::new()

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

function Get-ExactCommitReferenceList {
    param([AllowNull()] [string]$Value)

    $references = [System.Collections.Generic.List[string]]::new()
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return [pscustomobject][ordered]@{ Valid = $false; References = @() }
    }

    foreach ($rawToken in @($Value -split '[,;]')) {
        $token = ([string]$rawToken).Trim()
        if ($token -cmatch '^([0-9a-f]{40})$') {
            $references.Add([string]$Matches[1])
            continue
        }
        if ($token -cmatch '^`([0-9a-f]{40})`$') {
            $references.Add([string]$Matches[1])
            continue
        }
        return [pscustomobject][ordered]@{ Valid = $false; References = @() }
    }
    $unique = @($references | Sort-Object -Unique -CaseSensitive)
    return [pscustomobject][ordered]@{
        Valid      = ($references.Count -gt 0 -and $unique.Count -eq $references.Count)
        References = @($references)
    }
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

function Test-GitAncestor {
    param(
        [Parameter(Mandatory)] [string]$Root,
        [Parameter(Mandatory)] [string]$Ancestor,
        [Parameter(Mandatory)] [string]$Descendant
    )

    $result = Invoke-GitCapture -Root $Root -Arguments @(
        'merge-base', '--is-ancestor', $Ancestor, $Descendant
    )
    return ($result.ExitCode -eq 0)
}

function Get-GitBlobSha256 {
    param(
        [Parameter(Mandatory)] [string]$Root,
        [Parameter(Mandatory)] [string]$Commit,
        [Parameter(Mandatory)] [string]$Path
    )

    $normalizedPath = Convert-ToRepositoryPath $Path
    $objectResult = Invoke-GitCapture -Root $Root -Arguments @(
        'rev-parse', '--verify', "$Commit`:$normalizedPath"
    )
    if ($objectResult.ExitCode -ne 0 -or $objectResult.Output.Count -eq 0) {
        return $null
    }
    $objectId = ([string]$objectResult.Output[-1]).Trim().ToLowerInvariant()
    if ($objectId -notmatch '^[0-9a-f]{40,64}$') {
        return $null
    }

    $typeResult = Invoke-GitCapture -Root $Root -Arguments @('cat-file', '-t', $objectId)
    if (
        $typeResult.ExitCode -ne 0 -or
        $typeResult.Output.Count -eq 0 -or
        ([string]$typeResult.Output[-1]).Trim() -ne 'blob'
    ) {
        return $null
    }

    $process = $null
    $buffer = $null
    try {
        $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = 'git'
        $startInfo.UseShellExecute = $false
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        foreach ($argument in @('-C', $Root, 'cat-file', 'blob', $objectId)) {
            $startInfo.ArgumentList.Add([string]$argument)
        }

        $process = [System.Diagnostics.Process]::new()
        $process.StartInfo = $startInfo
        if (-not $process.Start()) {
            return $null
        }
        $errorTask = $process.StandardError.ReadToEndAsync()
        $buffer = [System.IO.MemoryStream]::new()
        $process.StandardOutput.BaseStream.CopyTo($buffer)
        $process.WaitForExit()
        $null = $errorTask.GetAwaiter().GetResult()
        if ($process.ExitCode -ne 0) {
            return $null
        }

        $digest = [System.Security.Cryptography.SHA256]::HashData($buffer.ToArray())
        return [System.Convert]::ToHexString($digest).ToLowerInvariant()
    } catch {
        return $null
    } finally {
        if ($buffer) { $buffer.Dispose() }
        if ($process) { $process.Dispose() }
    }
}

function Get-GitNoteHistoryAnchors {
    param(
        [Parameter(Mandatory)] [string]$Root,
        [Parameter(Mandatory)] [string]$AtCommit,
        [Parameter(Mandatory)] [string]$Path
    )

    $anchors = @{}
    $lastTouchResult = Invoke-GitCapture -Root $Root -Arguments @(
        'log', '-1', '--format=%H', $AtCommit, '--', $Path
    )
    foreach ($line in @($lastTouchResult.Output)) {
        $commit = ([string]$line).Trim().ToLowerInvariant()
        if ($commit -match '^[0-9a-f]{40}$') {
            $anchors[$commit] = $true
        }
    }

    $addResult = Invoke-GitCapture -Root $Root -Arguments @(
        'log', '--diff-filter=A', '--format=%H', $AtCommit, '--', $Path
    )
    foreach ($line in @($addResult.Output)) {
        $commit = ([string]$line).Trim().ToLowerInvariant()
        if ($commit -match '^[0-9a-f]{40}$') {
            $anchors[$commit] = $true
        }
    }
    return $anchors
}

function Get-GitCommitChangedPathSet {
    param(
        [Parameter(Mandatory)] [string]$Root,
        [Parameter(Mandatory)] [string]$Commit
    )

    $result = Invoke-GitCapture -Root $Root -Arguments @(
        'diff-tree', '--root', '--no-commit-id', '--name-only', '-r', $Commit, '--'
    )
    if ($result.ExitCode -ne 0) {
        return $null
    }
    $paths = @{}
    foreach ($line in @($result.Output)) {
        $path = Convert-ToRepositoryPath ([string]$line)
        if ($path) {
            $paths[$path] = $true
        }
    }
    return $paths
}

function Read-GitJsonAtCommit {
    param(
        [Parameter(Mandatory)] [string]$Root,
        [Parameter(Mandatory)] [string]$Commit,
        [Parameter(Mandatory)] [string]$Path
    )

    $result = Invoke-GitCapture -Root $Root -Arguments @(
        'show', "$Commit`:$Path"
    )
    if ($result.ExitCode -ne 0 -or $result.Output.Count -eq 0) {
        return $null
    }
    try {
        return (($result.Output -join "`n") | ConvertFrom-Json -AsHashtable)
    } catch {
        return $null
    }
}

function Get-HistoricalEvidencePolicyDocument {
    param([AllowNull()] [object]$Contract)

    if (
        $Contract -isnot [System.Collections.IDictionary] -or
        -not $Contract.ContainsKey('mainlineReadiness') -or
        $Contract.mainlineReadiness -isnot [System.Collections.IDictionary] -or
        -not $Contract.mainlineReadiness.ContainsKey('historicalEvidenceMigration') -or
        $Contract.mainlineReadiness.historicalEvidenceMigration -isnot [System.Collections.IDictionary]
    ) {
        return $null
    }
    return $Contract.mainlineReadiness.historicalEvidenceMigration
}

function Test-HistoricalEvidencePolicySnapshot {
    param(
        [AllowNull()] [object]$Policy,
        [Parameter(Mandatory)] [ValidateSet('pending', 'sealed')] [string]$State,
        [Parameter(Mandatory)] [string]$BatchBase,
        [Parameter(Mandatory)] [int]$ExpectedRecordCount,
        [AllowNull()] [object]$MigrationCommit,
        [AllowNull()] [object]$EvidenceSha256
    )

    $requiredFields = @(
        'state',
        'batchBase',
        'expectedRecordCount',
        'migrationCommit',
        'evidenceSha256',
        'evidencePath',
        'schemaPath',
        'legacyBaselinePath'
    )
    if (
        $Policy -isnot [System.Collections.IDictionary] -or
        $Policy.Count -ne $requiredFields.Count -or
        @($requiredFields | Where-Object { -not $Policy.ContainsKey($_) }).Count -gt 0
    ) {
        return $false
    }

    $recordCountIsInteger = (
        $Policy.expectedRecordCount -is [byte] -or
        $Policy.expectedRecordCount -is [int16] -or
        $Policy.expectedRecordCount -is [int32] -or
        $Policy.expectedRecordCount -is [int64]
    )
    $nullFieldsMatch = if ($State -eq 'pending') {
        $null -eq $Policy.migrationCommit -and
        $null -eq $Policy.evidenceSha256 -and
        $null -eq $MigrationCommit -and
        $null -eq $EvidenceSha256
    } else {
        $Policy.migrationCommit -is [string] -and
        [string]$Policy.migrationCommit -ceq [string]$MigrationCommit -and
        $Policy.evidenceSha256 -is [string] -and
        [string]$Policy.evidenceSha256 -ceq [string]$EvidenceSha256
    }

    return (
        [string]$Policy.state -ceq $State -and
        [string]$Policy.batchBase -ceq $BatchBase -and
        $recordCountIsInteger -and
        [int64]$Policy.expectedRecordCount -eq $ExpectedRecordCount -and
        $nullFieldsMatch -and
        [string]$Policy.evidencePath -ceq 'studio/runtime/mainline-note-historical-evidence.json' -and
        [string]$Policy.schemaPath -ceq 'studio/runtime/mainline-note-historical-evidence.schema.json' -and
        [string]$Policy.legacyBaselinePath -ceq 'studio/runtime/mainline-note-validation-baseline.json'
    )
}

function Test-HistoricalEvidenceDocumentSnapshot {
    param(
        [AllowNull()] [object]$Document,
        [Parameter(Mandatory)] [ValidateSet('pending', 'sealed')] [string]$State,
        [Parameter(Mandatory)] [int]$ExpectedRecordCount,
        [AllowNull()] [object]$MigrationCommit
    )

    $schemaVersionIsInteger = (
        $Document -is [System.Collections.IDictionary] -and
        (
            $Document.schemaVersion -is [byte] -or
            $Document.schemaVersion -is [int16] -or
            $Document.schemaVersion -is [int32] -or
            $Document.schemaVersion -is [int64]
        )
    )
    if (
        $Document -isnot [System.Collections.IDictionary] -or
        $Document.Count -ne 3 -or
        -not $Document.ContainsKey('schemaVersion') -or
        -not $Document.ContainsKey('migrationCommit') -or
        -not $Document.ContainsKey('records') -or
        -not $schemaVersionIsInteger -or
        [int64]$Document.schemaVersion -ne 1 -or
        $Document.records -isnot [System.Collections.IList]
    ) {
        return $false
    }

    if ($State -eq 'pending') {
        return (
            $null -eq $Document.migrationCommit -and
            @($Document.records).Count -eq 0
        )
    }
    return (
        $Document.migrationCommit -is [string] -and
        [string]$Document.migrationCommit -ceq [string]$MigrationCommit -and
        @($Document.records).Count -eq $ExpectedRecordCount
    )
}

function Get-GitCommitParents {
    param(
        [Parameter(Mandatory)] [string]$Root,
        [Parameter(Mandatory)] [string]$Commit
    )

    $result = Invoke-GitCapture -Root $Root -Arguments @(
        'rev-list', '--parents', '-n', '1', $Commit
    )
    if ($result.ExitCode -ne 0 -or $result.Output.Count -eq 0) {
        return @()
    }
    $parts = @(([string]$result.Output[-1]).Trim() -split '\s+')
    if ($parts.Count -lt 2) {
        return @()
    }
    return @(
        $parts[1..($parts.Count - 1)] |
            Where-Object { [string]$_ -match '^[0-9a-f]{40}$' }
    )
}

function Get-GitPathAdditionCommits {
    param(
        [Parameter(Mandatory)] [string]$Root,
        [Parameter(Mandatory)] [string]$HeadCommit,
        [Parameter(Mandatory)] [string]$Path
    )

    $result = Invoke-GitCapture -Root $Root -Arguments @(
        'log',
        '--full-history',
        '--reverse',
        '--format=%H',
        '--diff-filter=A',
        $HeadCommit,
        '--',
        $Path
    )
    if ($result.ExitCode -ne 0) {
        return @()
    }
    return @(
        $result.Output |
            ForEach-Object { ([string]$_).Trim().ToLowerInvariant() } |
            Where-Object { $_ -match '^[0-9a-f]{40}$' }
    )
}

function Read-ExactLegacyBaselineAtCommit {
    param(
        [Parameter(Mandatory)] [string]$Root,
        [Parameter(Mandatory)] [string]$Commit
    )

    $path = 'studio/runtime/mainline-note-validation-baseline.json'
    $document = Read-GitJsonAtCommit -Root $Root -Commit $Commit -Path $path
    $schemaVersionIsInteger = (
        $document -is [System.Collections.IDictionary] -and
        (
            $document.schemaVersion -is [byte] -or
            $document.schemaVersion -is [int16] -or
            $document.schemaVersion -is [int32] -or
            $document.schemaVersion -is [int64]
        )
    )
    if (
        $document -isnot [System.Collections.IDictionary] -or
        $document.Count -ne 2 -or
        -not $document.ContainsKey('schemaVersion') -or
        -not $document.ContainsKey('entries') -or
        -not $schemaVersionIsInteger -or
        [int64]$document.schemaVersion -ne 1 -or
        $document.entries -isnot [System.Collections.IList] -or
        @($document.entries).Count -eq 0
    ) {
        return $null
    }

    $entries = [System.Collections.Generic.Dictionary[string,string]]::new(
        [System.StringComparer]::Ordinal
    )
    $aliases = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    foreach ($entry in @($document.entries)) {
        if (
            $entry -isnot [System.Collections.IDictionary] -or
            $entry.Count -ne 2 -or
            -not $entry.ContainsKey('path') -or
            -not $entry.ContainsKey('sha256')
        ) {
            return $null
        }
        $rawPath = [string]$entry.path
        $entryPath = Convert-ToRepositoryPath $rawPath
        $sha256 = [string]$entry.sha256
        if (
            -not $entryPath -or
            $rawPath -cne $entryPath -or
            $sha256 -cnotmatch '^[0-9a-f]{64}$' -or
            -not $aliases.Add($entryPath)
        ) {
            return $null
        }
        $blobSha = Get-GitBlobSha256 -Root $Root -Commit $Commit -Path $entryPath
        if (-not $blobSha -or $blobSha -cne $sha256) {
            return $null
        }
        $entries.Add($entryPath, $sha256)
    }
    return ,$entries
}

function Get-HistoricalEvidenceFrameworkOrigin {
    param(
        [Parameter(Mandatory)] [string]$Root,
        [Parameter(Mandatory)] [string]$HeadCommit
    )

    $contractPath = 'studio/runtime/shared-runtime-contract.json'
    $evidencePath = 'studio/runtime/mainline-note-historical-evidence.json'
    $schemaPath = 'studio/runtime/mainline-note-historical-evidence.schema.json'
    $baselinePath = 'studio/runtime/mainline-note-validation-baseline.json'
    $evidenceAdds = @(
        Get-GitPathAdditionCommits -Root $Root -HeadCommit $HeadCommit -Path $evidencePath
    )
    $schemaAdds = @(
        Get-GitPathAdditionCommits -Root $Root -HeadCommit $HeadCommit -Path $schemaPath
    )
    if (
        $evidenceAdds.Count -eq 0 -or
        $schemaAdds.Count -eq 0 -or
        $evidenceAdds[0] -cne $schemaAdds[0]
    ) {
        Add-ValidationIssue -Severity error `
            -Category 'historical-evidence-sealed-snapshot-mismatch' `
            -Path $evidencePath `
            -Message (
                'Evidence JSON and schema must share one immutable first-add framework commit ' +
                'in the selected Head ancestry.'
            )
        return $null
    }

    $migrationCommit = [string]$evidenceAdds[0]
    $parentCandidates = [System.Collections.Generic.List[object]]::new()
    foreach ($parent in @(Get-GitCommitParents -Root $Root -Commit $migrationCommit)) {
        $baseline = Read-ExactLegacyBaselineAtCommit -Root $Root -Commit $parent
        $parentEvidenceSha = Get-GitBlobSha256 -Root $Root -Commit $parent -Path $evidencePath
        $parentSchemaSha = Get-GitBlobSha256 -Root $Root -Commit $parent -Path $schemaPath
        if ($baseline -and -not $parentEvidenceSha -and -not $parentSchemaSha) {
            $parentCandidates.Add([pscustomobject][ordered]@{
                Commit   = $parent
                Baseline = $baseline
            })
        }
    }
    if ($parentCandidates.Count -ne 1) {
        Add-ValidationIssue -Severity error `
            -Category 'historical-evidence-sealed-snapshot-mismatch' `
            -Path $baselinePath `
            -Message (
                'The immutable framework commit must have one direct parent with an exact ' +
                'nonempty legacy baseline and no historical evidence framework.'
            )
        return $null
    }

    $batchBase = [string]$parentCandidates[0].Commit
    $baseline = $parentCandidates[0].Baseline
    $expectedRecordCount = [int]$baseline.Count
    $frameworkPaths = @(
        'studio/scripts/powershell/validate-mainline-notes.ps1',
        $schemaPath,
        $evidencePath,
        $contractPath
    )
    $changedPaths = Get-GitCommitChangedPathSet -Root $Root -Commit $migrationCommit
    $pendingEvidence = Read-GitJsonAtCommit -Root $Root -Commit $migrationCommit `
        -Path $evidencePath
    $pendingSchema = Read-GitJsonAtCommit -Root $Root -Commit $migrationCommit `
        -Path $schemaPath
    $pendingSchemaSha = Get-GitBlobSha256 -Root $Root -Commit $migrationCommit `
        -Path $schemaPath
    $pendingContract = Read-GitJsonAtCommit -Root $Root -Commit $migrationCommit `
        -Path $contractPath
    $pendingPolicy = Get-HistoricalEvidencePolicyDocument -Contract $pendingContract
    $parentBaselineSha = Get-GitBlobSha256 -Root $Root -Commit $batchBase `
        -Path $baselinePath
    $migrationBaselineSha = Get-GitBlobSha256 -Root $Root -Commit $migrationCommit `
        -Path $baselinePath
    $originValid = (
        $null -ne $changedPaths -and
        @($frameworkPaths | Where-Object { -not $changedPaths.Contains($_) }).Count -eq 0 -and
        (Test-HistoricalEvidenceDocumentSnapshot -Document $pendingEvidence `
            -State pending -ExpectedRecordCount $expectedRecordCount `
            -MigrationCommit $null) -and
        $pendingSchema -and
        $pendingSchemaSha -and
        [string]$pendingSchema.properties.records.items.properties.batchBase.const -ceq $batchBase -and
        $parentBaselineSha -and
        $migrationBaselineSha -ceq $parentBaselineSha -and
        (Test-HistoricalEvidencePolicySnapshot -Policy $pendingPolicy `
            -State pending -BatchBase $batchBase `
            -ExpectedRecordCount $expectedRecordCount `
            -MigrationCommit $null -EvidenceSha256 $null)
    )
    if (-not $originValid) {
        Add-ValidationIssue -Severity error `
            -Category 'historical-evidence-sealed-snapshot-mismatch' `
            -Path $contractPath `
            -Message (
                'The immutable first-add commit must establish the exact pending framework ' +
                'against its derived baseline parent.'
            )
        return $null
    }

    return [pscustomobject][ordered]@{
        MigrationCommit    = $migrationCommit
        BatchBase          = $batchBase
        ExpectedRecordCount = $expectedRecordCount
        Baseline           = $baseline
        SchemaSha          = $pendingSchemaSha
    }
}

function Get-FirstHistoricalEvidenceSealSnapshot {
    param(
        [Parameter(Mandatory)] [string]$Root,
        [Parameter(Mandatory)] [string]$HeadCommit,
        [Parameter(Mandatory)] [string]$ExpectedBatchBase,
        [Parameter(Mandatory)] [string]$ExpectedMigrationCommit,
        [Parameter(Mandatory)] [int]$ExpectedRecordCount
    )

    $contractPath = 'studio/runtime/shared-runtime-contract.json'
    $evidencePath = 'studio/runtime/mainline-note-historical-evidence.json'
    $schemaPath = 'studio/runtime/mainline-note-historical-evidence.schema.json'
    $baselinePath = 'studio/runtime/mainline-note-validation-baseline.json'
    $historyResult = Invoke-GitCapture -Root $Root -Arguments @(
        'rev-list',
        '--reverse',
        '--topo-order',
        '--ancestry-path',
        "$ExpectedBatchBase..$HeadCommit",
        '--',
        $contractPath
    )
    if ($historyResult.ExitCode -ne 0) {
        Add-ValidationIssue -Severity error `
            -Category 'historical-evidence-sealed-snapshot-mismatch' `
            -Path $contractPath `
            -Message 'Unable to enumerate the pending-to-sealed policy history.'
        return $null
    }

    $transitionCandidates = [System.Collections.Generic.List[object]]::new()
    foreach ($line in @($historyResult.Output)) {
        $commit = ([string]$line).Trim().ToLowerInvariant()
        if ($commit -notmatch '^[0-9a-f]{40}$') { continue }
        $candidateContract = Read-GitJsonAtCommit -Root $Root -Commit $commit `
            -Path $contractPath
        $candidatePolicy = Get-HistoricalEvidencePolicyDocument -Contract $candidateContract
        if (-not $candidatePolicy -or [string]$candidatePolicy.state -cne 'sealed') {
            continue
        }

        $pendingParents = [System.Collections.Generic.List[string]]::new()
        foreach ($parent in @(Get-GitCommitParents -Root $Root -Commit $commit)) {
            if (-not (Test-GitAncestor -Root $Root -Ancestor $ExpectedBatchBase -Descendant $parent)) {
                continue
            }
            $parentContract = Read-GitJsonAtCommit -Root $Root -Commit $parent `
                -Path $contractPath
            $parentPolicy = Get-HistoricalEvidencePolicyDocument -Contract $parentContract
            if ($parentPolicy -and [string]$parentPolicy.state -ceq 'pending') {
                $pendingParents.Add($parent)
            }
        }
        if ($pendingParents.Count -gt 0) {
            $transitionCandidates.Add([pscustomobject][ordered]@{
                Commit        = $commit
                Policy        = $candidatePolicy
                PendingParents = @($pendingParents)
            })
        }
    }

    $batchBaselineSha = Get-GitBlobSha256 -Root $Root -Commit $ExpectedBatchBase `
        -Path $baselinePath
    $validCandidates = [System.Collections.Generic.List[object]]::new()
    foreach ($candidate in @($transitionCandidates)) {
        $candidateMigrationCommit = if (
            $candidate.Policy.migrationCommit -is [string] -and
            [string]$candidate.Policy.migrationCommit -cmatch '^[0-9a-f]{40}$'
        ) {
            [string]$candidate.Policy.migrationCommit
        } else {
            $null
        }
        $resolvedCandidateMigration = if ($candidateMigrationCommit) {
            Resolve-GitCommit -Root $Root -Reference $candidateMigrationCommit
        } else {
            $null
        }
        $candidateEvidence = Read-GitJsonAtCommit -Root $Root -Commit $candidate.Commit `
            -Path $evidencePath
        $candidateEvidenceSha = Get-GitBlobSha256 -Root $Root -Commit $candidate.Commit `
            -Path $evidencePath
        $candidateSchema = Read-GitJsonAtCommit -Root $Root -Commit $candidate.Commit `
            -Path $schemaPath
        $candidateSchemaSha = Get-GitBlobSha256 -Root $Root -Commit $candidate.Commit `
            -Path $schemaPath
        $candidateBaselineSha = Get-GitBlobSha256 -Root $Root -Commit $candidate.Commit `
            -Path $baselinePath
        $candidateValid = (
            $candidateMigrationCommit -and
            $candidateMigrationCommit -ceq $ExpectedMigrationCommit -and
            $resolvedCandidateMigration -ceq $candidateMigrationCommit -and
            $candidateMigrationCommit -cne $ExpectedBatchBase -and
            $candidateMigrationCommit -cne $candidate.Commit -and
            (Test-GitAncestor -Root $Root -Ancestor $ExpectedBatchBase `
                -Descendant $candidateMigrationCommit) -and
            (Test-GitAncestor -Root $Root -Ancestor $candidateMigrationCommit `
                -Descendant $candidate.Commit) -and
            $candidateEvidenceSha -and
            $candidateEvidenceSha -cmatch '^[0-9a-f]{64}$' -and
            (Test-HistoricalEvidencePolicySnapshot -Policy $candidate.Policy `
                -State sealed -BatchBase $ExpectedBatchBase `
                -ExpectedRecordCount $ExpectedRecordCount `
                -MigrationCommit $candidateMigrationCommit `
                -EvidenceSha256 $candidateEvidenceSha) -and
            (Test-HistoricalEvidenceDocumentSnapshot -Document $candidateEvidence `
                -State sealed -ExpectedRecordCount $ExpectedRecordCount `
                -MigrationCommit $candidateMigrationCommit) -and
            $candidateSchema -and
            $candidateSchemaSha -and
            [string]$candidateSchema.properties.records.items.properties.batchBase.const -ceq $ExpectedBatchBase -and
            -not $candidateBaselineSha
        )

        $exactPendingParent = $null
        $exactPendingSchemaSha = $null
        foreach ($parent in @($candidate.PendingParents)) {
            $parentContract = Read-GitJsonAtCommit -Root $Root -Commit $parent `
                -Path $contractPath
            $parentPolicy = Get-HistoricalEvidencePolicyDocument -Contract $parentContract
            $parentEvidence = Read-GitJsonAtCommit -Root $Root -Commit $parent `
                -Path $evidencePath
            $parentSchema = Read-GitJsonAtCommit -Root $Root -Commit $parent `
                -Path $schemaPath
            $parentSchemaSha = Get-GitBlobSha256 -Root $Root -Commit $parent `
                -Path $schemaPath
            $parentBaselineSha = Get-GitBlobSha256 -Root $Root -Commit $parent `
                -Path $baselinePath
            if (
                (Test-HistoricalEvidencePolicySnapshot -Policy $parentPolicy `
                    -State pending -BatchBase $ExpectedBatchBase `
                    -ExpectedRecordCount $ExpectedRecordCount `
                    -MigrationCommit $null -EvidenceSha256 $null) -and
                (Test-HistoricalEvidenceDocumentSnapshot -Document $parentEvidence `
                    -State pending -ExpectedRecordCount $ExpectedRecordCount `
                    -MigrationCommit $null) -and
                $parentSchema -and
                $parentSchemaSha -and
                [string]$parentSchema.properties.records.items.properties.batchBase.const -ceq $ExpectedBatchBase -and
                $batchBaselineSha -and
                $parentBaselineSha -ceq $batchBaselineSha -and
                $candidateMigrationCommit -and
                (Test-GitAncestor -Root $Root -Ancestor $candidateMigrationCommit `
                    -Descendant $parent)
            ) {
                $exactPendingParent = $parent
                $exactPendingSchemaSha = $parentSchemaSha
                break
            }
        }
        if (
            $candidateValid -and
            $exactPendingParent -and
            $candidateSchemaSha -ceq $exactPendingSchemaSha
        ) {
            $validCandidates.Add([pscustomobject][ordered]@{
                Commit          = $candidate.Commit
                PendingParent   = $exactPendingParent
                MigrationCommit = $candidateMigrationCommit
                Policy          = $candidate.Policy
                EvidenceSha     = $candidateEvidenceSha
                SchemaSha       = $candidateSchemaSha
            })
        }
    }

    $firstCandidates = [System.Collections.Generic.List[object]]::new()
    foreach ($candidate in @($validCandidates)) {
        $hasEarlierCandidate = $false
        foreach ($other in @($validCandidates)) {
            if (
                $other.Commit -cne $candidate.Commit -and
                (Test-GitAncestor -Root $Root -Ancestor $other.Commit `
                    -Descendant $candidate.Commit)
            ) {
                $hasEarlierCandidate = $true
                break
            }
        }
        if (-not $hasEarlierCandidate) {
            $firstCandidates.Add($candidate)
        }
    }
    if ($firstCandidates.Count -ne 1) {
        Add-ValidationIssue -Severity error `
            -Category 'historical-evidence-sealed-snapshot-mismatch' `
            -Path $contractPath `
            -Message (
                'The immutable batchBase..Head history must contain one absolute first valid ' +
                'pending-to-sealed transition.'
            )
        return $null
    }
    return $firstCandidates[0]
}

function Test-CurrentHistoricalEvidenceSealSnapshot {
    param(
        [Parameter(Mandatory)] [string]$Root,
        [Parameter(Mandatory)] [string]$HeadCommit,
        [Parameter(Mandatory)] [object]$SealSnapshot
    )

    $contractPath = 'studio/runtime/shared-runtime-contract.json'
    $evidencePath = 'studio/runtime/mainline-note-historical-evidence.json'
    $schemaPath = 'studio/runtime/mainline-note-historical-evidence.schema.json'
    $headContract = Read-GitJsonAtCommit -Root $Root -Commit $HeadCommit `
        -Path $contractPath
    $headPolicy = Get-HistoricalEvidencePolicyDocument -Contract $headContract
    $policyFields = @(
        'state',
        'batchBase',
        'expectedRecordCount',
        'migrationCommit',
        'evidenceSha256',
        'evidencePath',
        'schemaPath',
        'legacyBaselinePath'
    )
    $policyMatches = (
        $headPolicy -is [System.Collections.IDictionary] -and
        $headPolicy.Count -eq $policyFields.Count -and
        $SealSnapshot.Policy -is [System.Collections.IDictionary] -and
        $SealSnapshot.Policy.Count -eq $policyFields.Count
    )
    if ($policyMatches) {
        foreach ($field in $policyFields) {
            if (
                -not $headPolicy.ContainsKey($field) -or
                -not $SealSnapshot.Policy.ContainsKey($field)
            ) {
                $policyMatches = $false
                break
            }
            $headValue = $headPolicy[$field]
            $sealValue = $SealSnapshot.Policy[$field]
            if ($null -eq $headValue -or $null -eq $sealValue) {
                if (-not ($null -eq $headValue -and $null -eq $sealValue)) {
                    $policyMatches = $false
                    break
                }
            } elseif (
                $field -eq 'expectedRecordCount' -and
                [int64]$headValue -ne [int64]$sealValue
            ) {
                $policyMatches = $false
                break
            } elseif (
                $field -ne 'expectedRecordCount' -and
                [string]$headValue -cne [string]$sealValue
            ) {
                $policyMatches = $false
                break
            }
        }
    }

    $headEvidenceSha = Get-GitBlobSha256 -Root $Root -Commit $HeadCommit `
        -Path $evidencePath
    $headSchemaSha = Get-GitBlobSha256 -Root $Root -Commit $HeadCommit `
        -Path $schemaPath
    $valid = (
        $policyMatches -and
        $headEvidenceSha -and
        $headEvidenceSha -ceq $SealSnapshot.EvidenceSha -and
        $headSchemaSha -and
        $headSchemaSha -ceq $SealSnapshot.SchemaSha
    )
    if (-not $valid) {
        Add-ValidationIssue -Severity error `
            -Category 'historical-evidence-sealed-snapshot-mismatch' `
            -Path $evidencePath `
            -Message (
                'Current historical migration policy, evidence records, and schema must equal ' +
                "their first sealed snapshot at commit '$($SealSnapshot.Commit)'."
            )
    }
    return $valid
}

function Get-HistoricalEvidenceMigrationRole {
    param(
        [Parameter(Mandatory)] [string]$Root,
        [Parameter(Mandatory)] [string]$CommitReference,
        [Parameter(Mandatory)] [string]$BatchBase,
        [Parameter(Mandatory)] [string]$UpperBound,
        [Parameter(Mandatory)] [int]$ExpectedRecordCount,
        [Parameter(Mandatory)] [string]$ExpectedSchemaSha
    )

    $commit = Resolve-GitCommit -Root $Root -Reference $CommitReference
    $rangeValid = (
        $commit -and
        $commit -ceq $CommitReference -and
        $commit -cne $BatchBase -and
        $commit -cne $UpperBound -and
        (Test-GitAncestor -Root $Root -Ancestor $BatchBase -Descendant $commit) -and
        (Test-GitAncestor -Root $Root -Ancestor $commit -Descendant $UpperBound)
    )
    $scopeValid = $false
    if ($rangeValid) {
        $frameworkPaths = @(
            'studio/scripts/powershell/validate-mainline-notes.ps1',
            'studio/runtime/mainline-note-historical-evidence.schema.json',
            'studio/runtime/mainline-note-historical-evidence.json',
            'studio/runtime/shared-runtime-contract.json'
        )
        $changedPaths = Get-GitCommitChangedPathSet -Root $Root -Commit $commit
        $pendingEvidence = Read-GitJsonAtCommit -Root $Root -Commit $commit `
            -Path 'studio/runtime/mainline-note-historical-evidence.json'
        $pendingSchema = Read-GitJsonAtCommit -Root $Root -Commit $commit `
            -Path 'studio/runtime/mainline-note-historical-evidence.schema.json'
        $pendingSchemaSha = Get-GitBlobSha256 -Root $Root -Commit $commit `
            -Path 'studio/runtime/mainline-note-historical-evidence.schema.json'
        $pendingContract = Read-GitJsonAtCommit -Root $Root -Commit $commit `
            -Path 'studio/runtime/shared-runtime-contract.json'
        $pendingPolicy = Get-HistoricalEvidencePolicyDocument -Contract $pendingContract
        $migrationBaselineSha = Get-GitBlobSha256 -Root $Root -Commit $commit `
            -Path 'studio/runtime/mainline-note-validation-baseline.json'
        $batchBaselineSha = Get-GitBlobSha256 -Root $Root -Commit $BatchBase `
            -Path 'studio/runtime/mainline-note-validation-baseline.json'
        $scopeValid = (
            $null -ne $changedPaths -and
            @($frameworkPaths | Where-Object { -not $changedPaths.Contains($_) }).Count -eq 0 -and
            (Test-HistoricalEvidenceDocumentSnapshot -Document $pendingEvidence `
                -State pending -ExpectedRecordCount $ExpectedRecordCount `
                -MigrationCommit $null) -and
            $pendingSchema -and
            $pendingSchemaSha -ceq $ExpectedSchemaSha -and
            [string]$pendingSchema.properties.records.items.properties.batchBase.const -ceq $BatchBase -and
            $batchBaselineSha -and
            $migrationBaselineSha -ceq $batchBaselineSha -and
            (Test-HistoricalEvidencePolicySnapshot -Policy $pendingPolicy `
                -State pending -BatchBase $BatchBase `
                -ExpectedRecordCount $ExpectedRecordCount `
                -MigrationCommit $null -EvidenceSha256 $null)
        )
    }

    return [pscustomobject][ordered]@{
        Commit     = $commit
        RangeValid = $rangeValid
        ScopeValid = $scopeValid
    }
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
        [Parameter(Mandatory)] [string]$BaselinePath,
        [switch]$AllowMissing
    )

    $entries = @{}
    if (-not (Test-Path -LiteralPath $BaselinePath -PathType Leaf)) {
        if (-not $AllowMissing) {
            Add-ValidationIssue -Severity error -Category 'legacy-baseline' -Path (Convert-ToRepositoryPath ($BaselinePath.Substring($Root.Length).TrimStart('\', '/'))) `
                -Message 'The hash-bound legacy note migration baseline is missing while migration state is pending.'
        }
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

function Read-HistoricalEvidenceRecords {
    param(
        [Parameter(Mandatory)] [string]$Root,
        [Parameter(Mandatory)] [string]$EvidencePath,
        [Parameter(Mandatory)] [string]$SchemaPath
    )

    $relativeEvidencePath = Convert-ToRepositoryPath (
        $EvidencePath.Substring($Root.Length).TrimStart('\', '/')
    )
    $relativeSchemaPath = Convert-ToRepositoryPath (
        $SchemaPath.Substring($Root.Length).TrimStart('\', '/')
    )
    if (-not (Test-Path -LiteralPath $SchemaPath -PathType Leaf)) {
        Add-ValidationIssue -Severity error -Category 'historical-evidence-schema' -Path $relativeSchemaPath `
            -Message 'The historical evidence record schema is missing.'
        return [pscustomobject][ordered]@{
            schemaValid     = $false
            migrationCommit = $null
            records         = @()
        }
    }
    if (-not (Test-Path -LiteralPath $EvidencePath -PathType Leaf)) {
        Add-ValidationIssue -Severity error -Category 'historical-evidence-record' -Path $relativeEvidencePath `
            -Message 'The historical evidence migration record is missing.'
        return [pscustomobject][ordered]@{
            schemaValid     = $false
            migrationCommit = $null
            records         = @()
        }
    }

    $raw = $null
    try {
        $raw = Get-Content -LiteralPath $EvidencePath -Raw -ErrorAction Stop
        $schemaDiagnostics = @()
        $schemaValid = Test-Json -Json $raw -SchemaFile $SchemaPath `
            -ErrorAction SilentlyContinue -ErrorVariable +schemaDiagnostics
        if (-not $schemaValid) {
            Add-ValidationIssue -Severity error -Category 'historical-evidence-schema' -Path $relativeEvidencePath `
                -Message 'The historical evidence migration record does not conform to its JSON schema.'
            return [pscustomobject][ordered]@{
                schemaValid     = $false
                migrationCommit = $null
                records         = @()
            }
        }
        $document = $raw | ConvertFrom-Json -AsHashtable
    } catch {
        Add-ValidationIssue -Severity error -Category 'historical-evidence-record' -Path $relativeEvidencePath `
            -Message "Unable to read the historical evidence migration record: $($_.Exception.Message)"
        return [pscustomobject][ordered]@{
            schemaValid     = $false
            migrationCommit = $null
            records         = @()
        }
    }

    $records = @(
        $document.records | ForEach-Object {
            [pscustomobject][ordered]@{
                rawPath              = [string]$_.path
                path                 = Convert-ToRepositoryPath ([string]$_.path)
                preMigrationSha256   = ([string]$_.preMigrationSha256).ToLowerInvariant()
                batchBase            = ([string]$_.batchBase).ToLowerInvariant()
                migratedSha256       = ([string]$_.migratedSha256).ToLowerInvariant()
                historicalCommits    = @(
                    $_.historicalCommits | ForEach-Object {
                        ([string]$_).ToLowerInvariant()
                    }
                )
                expectedStatus       = [string]$_.expectedStatus
            }
        }
    )
    return [pscustomobject][ordered]@{
        schemaValid     = $true
        migrationCommit = if ($null -eq $document.migrationCommit) {
            $null
        } else {
            ([string]$document.migrationCommit).ToLowerInvariant()
        }
        records         = @($records)
    }
}

function Read-HistoricalEvidencePolicy {
    param(
        [Parameter(Mandatory)] [string]$ContractPath,
        [Parameter(Mandatory)] [string]$SchemaPath
    )

    $contractRelativePath = 'studio/runtime/shared-runtime-contract.json'
    try {
        $contract = Get-Content -LiteralPath $ContractPath -Raw -ErrorAction Stop |
            ConvertFrom-Json -AsHashtable
    } catch {
        Add-ValidationIssue -Severity error -Category 'historical-evidence-policy' `
            -Path $contractRelativePath `
            -Message "Unable to read historical evidence migration policy: $($_.Exception.Message)"
        return $null
    }

    if (
        -not $contract.ContainsKey('mainlineReadiness') -or
        $contract.mainlineReadiness -isnot [System.Collections.IDictionary] -or
        -not $contract.mainlineReadiness.ContainsKey('historicalEvidenceMigration') -or
        $contract.mainlineReadiness.historicalEvidenceMigration -isnot [System.Collections.IDictionary]
    ) {
        Add-ValidationIssue -Severity error -Category 'historical-evidence-policy' `
            -Path $contractRelativePath `
            -Message 'mainlineReadiness.historicalEvidenceMigration policy is required.'
        return $null
    }

    $policy = $contract.mainlineReadiness.historicalEvidenceMigration
    $requiredFields = @(
        'state',
        'batchBase',
        'expectedRecordCount',
        'migrationCommit',
        'evidenceSha256',
        'evidencePath',
        'schemaPath',
        'legacyBaselinePath'
    )
    if (@($requiredFields | Where-Object { -not $policy.ContainsKey($_) }).Count -gt 0) {
        Add-ValidationIssue -Severity error -Category 'historical-evidence-policy' `
            -Path $contractRelativePath `
            -Message 'Historical evidence migration policy is missing required fields.'
        return $null
    }

    $state = [string]$policy.state
    $batchBase = [string]$policy.batchBase
    $recordCountIsInteger = (
        $policy.expectedRecordCount -is [byte] -or
        $policy.expectedRecordCount -is [int16] -or
        $policy.expectedRecordCount -is [int32] -or
        $policy.expectedRecordCount -is [int64]
    )
    $pathsMatch = (
        [string]$policy.evidencePath -ceq 'studio/runtime/mainline-note-historical-evidence.json' -and
        [string]$policy.schemaPath -ceq 'studio/runtime/mainline-note-historical-evidence.schema.json' -and
        [string]$policy.legacyBaselinePath -ceq 'studio/runtime/mainline-note-validation-baseline.json'
    )
    $migrationCommitValid = if ($state -eq 'pending') {
        $null -eq $policy.migrationCommit
    } else {
        $policy.migrationCommit -is [string] -and
        [string]$policy.migrationCommit -cmatch '^[0-9a-f]{40}$'
    }
    $evidenceShaValid = if ($state -eq 'pending') {
        $null -eq $policy.evidenceSha256
    } else {
        $policy.evidenceSha256 -is [string] -and
        [string]$policy.evidenceSha256 -cmatch '^[0-9a-f]{64}$'
    }
    if (
        $state -notin @('pending', 'sealed') -or
        $batchBase -cnotmatch '^[0-9a-f]{40}$' -or
        -not $recordCountIsInteger -or
        [int64]$policy.expectedRecordCount -lt 0 -or
        -not $migrationCommitValid -or
        -not $evidenceShaValid -or
        -not $pathsMatch
    ) {
        Add-ValidationIssue -Severity error -Category 'historical-evidence-policy' `
            -Path $contractRelativePath `
            -Message 'Historical evidence migration policy has invalid state, batchBase, count, migrationCommit, evidenceSha256, or authority paths.'
        return $null
    }

    try {
        $schema = Get-Content -LiteralPath $SchemaPath -Raw -ErrorAction Stop |
            ConvertFrom-Json -AsHashtable
        $schemaBatchBase = [string]$schema.properties.records.items.properties.batchBase.const
    } catch {
        Add-ValidationIssue -Severity error -Category 'historical-evidence-policy' `
            -Path 'studio/runtime/mainline-note-historical-evidence.schema.json' `
            -Message "Unable to inspect the schema batchBase binding: $($_.Exception.Message)"
        return $null
    }
    if ($schemaBatchBase -cne $batchBase) {
        Add-ValidationIssue -Severity error -Category 'historical-evidence-policy' `
            -Path 'studio/runtime/mainline-note-historical-evidence.schema.json' `
            -Message 'The schema batchBase const must exactly match the contract migration policy.'
        return $null
    }

    return [pscustomobject][ordered]@{
        state               = $state
        batchBase           = $batchBase
        expectedRecordCount = [int]$policy.expectedRecordCount
        migrationCommit     = if ($null -eq $policy.migrationCommit) {
            $null
        } else {
            [string]$policy.migrationCommit
        }
        evidenceSha256      = if ($null -eq $policy.evidenceSha256) {
            $null
        } else {
            [string]$policy.evidenceSha256
        }
        evidencePath        = [string]$policy.evidencePath
        schemaPath          = [string]$policy.schemaPath
        legacyBaselinePath  = [string]$policy.legacyBaselinePath
    }
}

function Test-HistoricalEvidenceTransition {
    param(
        [Parameter(Mandatory)] [object]$Policy,
        [Parameter(Mandatory)] [int]$RecordCount,
        [Parameter(Mandatory)] [int]$BaselineCount,
        [Parameter(Mandatory)] [bool]$BaselineExists,
        [AllowNull()] [object]$EvidenceMigrationCommit
    )

    $valid = if ($Policy.state -eq 'pending') {
        $RecordCount -eq 0 -and
        $BaselineExists -and
        $BaselineCount -eq $Policy.expectedRecordCount -and
        $null -eq $EvidenceMigrationCommit -and
        $null -eq $Policy.migrationCommit
    } else {
        $RecordCount -eq $Policy.expectedRecordCount -and
        -not $BaselineExists -and
        $BaselineCount -eq 0 -and
        $EvidenceMigrationCommit -ceq $Policy.migrationCommit
    }
    if (-not $valid) {
        Add-ValidationIssue -Severity error -Category 'historical-evidence-transition' `
            -Path 'studio/runtime/mainline-note-historical-evidence.json' `
            -Message (
                "Migration state '$($Policy.state)' requires its exact atomic record/baseline counts; " +
                "found records=$RecordCount, baseline=$BaselineCount, baselineExists=$BaselineExists."
            )
    }
    return $valid
}

function Test-HeadBoundAuthoritySurface {
    param(
        [Parameter(Mandatory)] [string]$Root,
        [Parameter(Mandatory)] [string]$HeadCommit,
        [Parameter(Mandatory)] [string[]]$Paths,
        [string[]]$AllowAbsentPaths = @()
    )

    $valid = $true
    foreach ($path in @($Paths)) {
        $absolutePath = Join-Path $Root ($path.Replace('/', [System.IO.Path]::DirectorySeparatorChar))
        $worktreeSha = if (Test-Path -LiteralPath $absolutePath -PathType Leaf) {
            Get-RepositoryFileHash -Path $absolutePath
        } else {
            $null
        }
        $headSha = Get-GitBlobSha256 -Root $Root -Commit $HeadCommit -Path $path
        $bothAbsentAndAllowed = (
            $path -in $AllowAbsentPaths -and
            -not $worktreeSha -and
            -not $headSha
        )
        if (
            -not $bothAbsentAndAllowed -and
            (-not $worktreeSha -or -not $headSha -or $worktreeSha -ne $headSha)
        ) {
            $valid = $false
            Add-ValidationIssue -Severity error -Category 'historical-evidence-authority-surface-dirty' `
                -Path $path `
                -Message 'Historical migration authority bytes must exactly match the selected HeadRef.'
        }
    }
    return $valid
}

function Read-LegacyBaselineAtCommit {
    param(
        [Parameter(Mandatory)] [string]$Root,
        [Parameter(Mandatory)] [string]$Commit
    )

    $result = Invoke-GitCapture -Root $Root -Arguments @(
        'show', "$Commit`:studio/runtime/mainline-note-validation-baseline.json"
    )
    if ($result.ExitCode -ne 0 -or $result.Output.Count -eq 0) {
        return $null
    }

    try {
        $document = ($result.Output -join "`n") | ConvertFrom-Json -AsHashtable
        $entries = @{}
        foreach ($entry in @($document.entries)) {
            $path = Convert-ToRepositoryPath ([string]$entry.path)
            if (-not $path -or -not $entry.sha256 -or $entries.ContainsKey($path)) {
                return $null
            }
            $entries[$path] = ([string]$entry.sha256).ToLowerInvariant()
        }
        return $entries
    } catch {
        return $null
    }
}

function Test-HistoricalEvidenceRecords {
    param(
        [Parameter(Mandatory)] [string]$Root,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]]$Records,
        [Parameter(Mandatory)] [System.Collections.IDictionary]$CurrentBaseline,
        [Parameter(Mandatory)] [System.Collections.IDictionary]$NotesByPath,
        [Parameter(Mandatory)] [string]$HeadReference,
        [Parameter(Mandatory)] [string]$ExpectedBatchBase,
        [Parameter(Mandatory)] [string]$ExpectedMigrationCommit,
        [Parameter(Mandatory)] [int]$ExpectedRecordCount,
        [Parameter(Mandatory)] [bool]$AuthoritySurfaceClean
    )

    $validated = @{}
    $resolvedHead = Resolve-GitCommit -Root $Root -Reference $HeadReference
    if (-not $resolvedHead) {
        Add-ValidationIssue -Severity error -Category 'historical-evidence-git-context' `
            -Message "Unable to resolve historical evidence validation head '$HeadReference'."
        return $validated
    }

    $frameworkOrigin = Get-HistoricalEvidenceFrameworkOrigin -Root $Root `
        -HeadCommit $resolvedHead
    if (-not $frameworkOrigin) {
        return $validated
    }
    $batchBase = [string]$frameworkOrigin.BatchBase
    $canonicalMigrationCommit = [string]$frameworkOrigin.MigrationCommit
    $canonicalRecordCount = [int]$frameworkOrigin.ExpectedRecordCount
    $canonicalBatchBaseline = $frameworkOrigin.Baseline
    $headSchema = Read-GitJsonAtCommit -Root $Root -Commit $resolvedHead `
        -Path 'studio/runtime/mainline-note-historical-evidence.schema.json'
    $headSchemaBatchBase = if ($headSchema) {
        [string]$headSchema.properties.records.items.properties.batchBase.const
    } else {
        $null
    }
    $currentOriginFactsMatch = (
        $ExpectedBatchBase -ceq $batchBase -and
        $ExpectedMigrationCommit -ceq $canonicalMigrationCommit -and
        $ExpectedRecordCount -eq $canonicalRecordCount -and
        $headSchemaBatchBase -ceq $batchBase
    )
    if (-not $currentOriginFactsMatch) {
        Add-ValidationIssue -Severity error `
            -Category 'historical-evidence-sealed-snapshot-mismatch' `
            -Path 'studio/runtime/shared-runtime-contract.json' `
            -Message (
                'Current policy and operative schema must equal the canonical migration commit, ' +
                'batch base, and record count derived from the immutable framework first-add history.'
            )
    }

    $sealSnapshot = Get-FirstHistoricalEvidenceSealSnapshot -Root $Root `
        -HeadCommit $resolvedHead -ExpectedBatchBase $batchBase `
        -ExpectedMigrationCommit $canonicalMigrationCommit `
        -ExpectedRecordCount $canonicalRecordCount
    $sealedSnapshotValid = $false
    if ($sealSnapshot) {
        $headMatchesSeal = Test-CurrentHistoricalEvidenceSealSnapshot `
            -Root $Root -HeadCommit $resolvedHead -SealSnapshot $sealSnapshot
        $currentPointerMatchesSeal = (
            $ExpectedMigrationCommit -ceq $sealSnapshot.MigrationCommit
        )
        if ($headMatchesSeal -and -not $currentPointerMatchesSeal) {
            Add-ValidationIssue -Severity error `
                -Category 'historical-evidence-sealed-snapshot-mismatch' `
                -Path 'studio/runtime/shared-runtime-contract.json' `
                -Message 'Current migrationCommit must equal the commit bound by the first sealed snapshot.'
        }
        $sealedSnapshotValid = (
            $headMatchesSeal -and
            $currentPointerMatchesSeal -and
            $currentOriginFactsMatch
        )
    }

    $sealedMigrationCommit = if ($sealSnapshot) {
        [string]$sealSnapshot.MigrationCommit
    } else {
        $null
    }
    $sealedMigrationRole = if ($sealedMigrationCommit) {
        Get-HistoricalEvidenceMigrationRole -Root $Root `
            -CommitReference $sealedMigrationCommit -BatchBase $batchBase `
            -UpperBound $sealSnapshot.Commit `
            -ExpectedRecordCount $canonicalRecordCount `
            -ExpectedSchemaSha $sealSnapshot.SchemaSha
    } else {
        $null
    }
    $migrationCommit = if ($sealedMigrationRole) {
        $sealedMigrationRole.Commit
    } else {
        $null
    }
    $migrationCommitValid = (
        $sealedMigrationRole -and
        $sealedMigrationRole.RangeValid -and
        $sealedMigrationRole.ScopeValid
    )
    if (-not $sealedMigrationRole -or -not $sealedMigrationRole.RangeValid) {
        Add-ValidationIssue -Severity error -Category 'historical-evidence-migration-out-of-range' `
            -Message (
                'The first sealed snapshot must bind a prior framework commit strictly inside ' +
                'batchBase..first-seal..validation-head.'
            )
    } elseif (-not $sealedMigrationRole.ScopeValid) {
        Add-ValidationIssue -Severity error -Category 'historical-evidence-migration-scope' `
            -Message (
                'The migration commit derived from the first seal must establish the fixed ' +
                'framework plus exact pending evidence, baseline, schema, and policy.'
            )
    }

    if ($sealSnapshot -and $ExpectedMigrationCommit -cne $sealedMigrationCommit) {
        $currentMigrationRole = Get-HistoricalEvidenceMigrationRole -Root $Root `
            -CommitReference $ExpectedMigrationCommit -BatchBase $batchBase `
            -UpperBound $resolvedHead -ExpectedRecordCount $canonicalRecordCount `
            -ExpectedSchemaSha $sealSnapshot.SchemaSha
        if (-not $currentMigrationRole.RangeValid) {
            Add-ValidationIssue -Severity error `
                -Category 'historical-evidence-migration-out-of-range' `
                -Message 'Current migrationCommit is outside the fixed batchBase..validation-head range.'
        } elseif (-not $currentMigrationRole.ScopeValid) {
            Add-ValidationIssue -Severity error `
                -Category 'historical-evidence-migration-scope' `
                -Message 'Current migrationCommit does not establish the exact pending framework role.'
        }
    }

    $recordPathSet = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::Ordinal
    )
    foreach ($record in @($Records)) {
        $null = $recordPathSet.Add([string]$record.path)
    }
    $batchPathSet = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::Ordinal
    )
    foreach ($path in @($canonicalBatchBaseline.Keys)) {
        $null = $batchPathSet.Add([string]$path)
    }
    $recordSetComplete = (
        $recordPathSet.Count -eq $batchPathSet.Count -and
        @($recordPathSet | Where-Object { -not $batchPathSet.Contains($_) }).Count -eq 0 -and
        @($batchPathSet | Where-Object { -not $recordPathSet.Contains($_) }).Count -eq 0
    )
    if (-not $recordSetComplete) {
        Add-ValidationIssue -Severity error -Category 'historical-evidence-record-set-mismatch' `
            -Path 'studio/runtime/mainline-note-historical-evidence.json' `
            -Message 'Sealed record paths must exactly equal every legacy baseline path at batchBase.'
    }

    $seenPaths = @{}
    foreach ($record in @($Records)) {
        $path = [string]$record.path
        $recordErrorCount = $script:validationErrors.Count

        if ([string]$record.rawPath -cne $path) {
            Add-ValidationIssue -Severity error -Category 'historical-evidence-path-noncanonical' -Path $path `
                -Message 'Historical evidence paths must already be canonical repository paths.'
        }
        if ($seenPaths.ContainsKey($path)) {
            Add-ValidationIssue -Severity error -Category 'historical-evidence-duplicate' -Path $path `
                -Message 'Historical evidence records must use unique note paths.'
            continue
        }
        $seenPaths[$path] = $true

        if ($CurrentBaseline.Contains($path)) {
            Add-ValidationIssue -Severity error -Category 'historical-evidence-baseline-overlap' -Path $path `
                -Message 'A note path cannot remain in the legacy baseline after receiving a historical evidence record.'
        }
        if (-not $canonicalBatchBaseline.ContainsKey($path)) {
            Add-ValidationIssue -Severity error -Category 'historical-evidence-not-baselined' -Path $path `
                -Message 'The exact note path was not present in the legacy baseline at batchBase.'
        } elseif (
            [string]$canonicalBatchBaseline[$path] -cne
            [string]$record.preMigrationSha256
        ) {
            Add-ValidationIssue -Severity error -Category 'historical-evidence-pre-sha-mismatch' -Path $path `
                -Message 'preMigrationSha256 does not match the exact legacy baseline entry at batchBase.'
        }
        if (-not $NotesByPath.Contains($path)) {
            Add-ValidationIssue -Severity error -Category 'historical-evidence-note-missing' -Path $path `
                -Message 'Historical evidence record points to a missing current note.'
            continue
        }
        $note = $NotesByPath[$path]

        if ([string]$record.batchBase -cne $batchBase) {
            Add-ValidationIssue -Severity error -Category 'historical-evidence-batch-base-mismatch' -Path $path `
                -Message 'Record batchBase must exactly match the contract and schema binding.'
            continue
        }
        $preMigrationBlobSha = Get-GitBlobSha256 -Root $Root -Commit $batchBase -Path $path
        if (
            -not $preMigrationBlobSha -or
            $preMigrationBlobSha -ne [string]$record.preMigrationSha256
        ) {
            Add-ValidationIssue -Severity error -Category 'historical-evidence-pre-sha-mismatch' -Path $path `
                -Message 'preMigrationSha256 does not match the note bytes at batchBase.'
        }

        $historyAnchors = Get-GitNoteHistoryAnchors -Root $Root -AtCommit $batchBase -Path $path
        $historicalCommitSet = @{}
        foreach ($historicalReference in @($record.historicalCommits)) {
            $historicalCommit = Resolve-GitCommit -Root $Root -Reference ([string]$historicalReference)
            if (-not $historicalCommit -or $historicalCommit -ne [string]$historicalReference) {
                Add-ValidationIssue -Severity error -Category 'historical-evidence-commit-invalid' -Path $path `
                    -Message 'Every historical commit must identify one exact commit object.'
                continue
            }
            $historicalCommitSet[$historicalCommit] = $true
            if (-not (Test-GitAncestor -Root $Root -Ancestor $historicalCommit -Descendant $batchBase)) {
                Add-ValidationIssue -Severity error -Category 'historical-evidence-historical-nonancestor' -Path $path `
                    -Message "Historical commit '$historicalCommit' is not an ancestor of batchBase."
                continue
            }
            if (-not $historyAnchors.Contains($historicalCommit)) {
                Add-ValidationIssue -Severity error -Category 'historical-evidence-history-anchor-mismatch' -Path $path `
                    -Message "Historical commit '$historicalCommit' is neither the add nor last-touch commit for the note at batchBase."
            }
        }

        if ($migrationCommit -and $historicalCommitSet.Contains($migrationCommit)) {
            Add-ValidationIssue -Severity error -Category 'historical-evidence-commit-role-overlap' -Path $path `
                -Message 'migrationCommit cannot also be declared as a historical commit.'
        }

        $headNoteSha = Get-GitBlobSha256 -Root $Root -Commit $resolvedHead -Path $path
        if (-not $headNoteSha -or $note.sha256 -cne $headNoteSha) {
            Add-ValidationIssue -Severity error -Category 'historical-evidence-note-surface-dirty' -Path $path `
                -Message 'A record-path note must exactly match its selected HeadRef bytes during Git validation.'
        }
        $sealedSnapshotExists = (
            $sealSnapshot -and
            (Get-GitBlobSha256 -Root $Root -Commit $sealSnapshot.Commit -Path $path) -ceq
                [string]$record.migratedSha256
        )
        if (-not $sealedSnapshotExists) {
            Add-ValidationIssue -Severity error -Category 'historical-evidence-snapshot-missing' -Path $path `
                -Message 'migratedSha256 must equal the note bytes in the first sealed snapshot.'
        }

        $currentMatchesSealedSnapshot = (
            $headNoteSha -and
            $headNoteSha -ceq [string]$record.migratedSha256
        )
        if ($currentMatchesSealedSnapshot) {
            if ($note.status -ne [string]$record.expectedStatus) {
                Add-ValidationIssue -Severity error -Category 'historical-evidence-status-mismatch' -Path $path `
                    -Message "Sealed note status '$($note.status)' does not match expectedStatus '$($record.expectedStatus)'."
            }

            $exactRelatedCommits = Get-ExactCommitReferenceList -Value $note.relatedCommits
            $expectedCommitSet = @{}
            foreach ($commit in @($record.historicalCommits)) {
                $expectedCommitSet[[string]$commit] = $true
            }
            $currentCommitSet = @{}
            foreach ($reference in @($exactRelatedCommits.References)) {
                $currentCommitSet[[string]$reference] = $true
            }
            $relatedCommitsMatch = (
                $exactRelatedCommits.Valid -and
                $currentCommitSet.Count -eq $expectedCommitSet.Count -and
                @($currentCommitSet.Keys | Where-Object { -not $expectedCommitSet.Contains($_) }).Count -eq 0
            )
            if (-not $relatedCommitsMatch) {
                Add-ValidationIssue -Severity error -Category 'historical-evidence-related-commits-mismatch' -Path $path `
                    -Message 'Related Commits must resolve to exactly historicalCommits; migrationCommit is not note or current-path authorization evidence.'
            }
        }

        if (
            $currentMatchesSealedSnapshot -and
            $AuthoritySurfaceClean -and
            $migrationCommitValid -and
            $sealedSnapshotValid -and
            $recordSetComplete -and
            $script:validationErrors.Count -eq $recordErrorCount
        ) {
            $validated[$path] = [pscustomobject][ordered]@{
                path                = $path
                historicalCommits   = @($record.historicalCommits)
                historicalCommitSet = $historicalCommitSet
            }
        }
    }
    return $validated
}

function Test-HistoricalEvidenceStructuralRecords {
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]]$Records,
        [Parameter(Mandatory)] [System.Collections.IDictionary]$NotesByPath
    )

    $seenPaths = @{}
    foreach ($record in @($Records)) {
        $path = [string]$record.path
        if ([string]$record.rawPath -cne $path) {
            Add-ValidationIssue -Severity error -Category 'historical-evidence-path-noncanonical' -Path $path `
                -Message 'Historical evidence paths must already be canonical repository paths.'
        }
        if ($seenPaths.ContainsKey($path)) {
            Add-ValidationIssue -Severity error -Category 'historical-evidence-duplicate' -Path $path `
                -Message 'Historical evidence records must use unique note paths.'
            continue
        }
        $seenPaths[$path] = $true

        if (-not $NotesByPath.Contains($path)) {
            Add-ValidationIssue -Severity error -Category 'historical-evidence-note-missing' -Path $path `
                -Message 'Historical evidence record points to a missing current note.'
            continue
        }
        $note = $NotesByPath[$path]
        if ($note.sha256 -ceq [string]$record.migratedSha256) {
            if ($note.status -ne [string]$record.expectedStatus) {
                Add-ValidationIssue -Severity error -Category 'historical-evidence-status-mismatch' -Path $path `
                    -Message "Sealed note status '$($note.status)' does not match expectedStatus '$($record.expectedStatus)'."
            }

            $exactRelatedCommits = Get-ExactCommitReferenceList -Value $note.relatedCommits
            $expectedCommitSet = @{}
            foreach ($commit in @($record.historicalCommits)) {
                $expectedCommitSet[[string]$commit] = $true
            }
            $currentCommitSet = @{}
            foreach ($reference in @($exactRelatedCommits.References)) {
                $currentCommitSet[[string]$reference] = $true
            }
            if (
                -not $exactRelatedCommits.Valid -or
                $currentCommitSet.Count -ne $expectedCommitSet.Count -or
                @($currentCommitSet.Keys | Where-Object { -not $expectedCommitSet.Contains($_) }).Count -gt 0
            ) {
                Add-ValidationIssue -Severity error -Category 'historical-evidence-related-commits-mismatch' -Path $path `
                    -Message 'Related Commits must resolve to exactly historicalCommits; migrationCommit is not note or current-path authorization evidence.'
            }
        }
    }
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
$historicalEvidencePath = Join-Path $WorkspaceRoot 'studio/runtime/mainline-note-historical-evidence.json'
$historicalEvidenceSchemaPath = Join-Path $WorkspaceRoot 'studio/runtime/mainline-note-historical-evidence.schema.json'
$contractPath = Join-Path $WorkspaceRoot 'studio/runtime/shared-runtime-contract.json'
$registryPath = Join-Path $WorkspaceRoot 'studio/runtime/impact-registry.json'

$historicalEvidencePolicy = Read-HistoricalEvidencePolicy -ContractPath $contractPath `
    -SchemaPath $historicalEvidenceSchemaPath
$historicalEvidenceDocument = Read-HistoricalEvidenceRecords -Root $WorkspaceRoot `
    -EvidencePath $historicalEvidencePath -SchemaPath $historicalEvidenceSchemaPath
$historicalEvidenceRecords = @($historicalEvidenceDocument.records)
$baselineExists = Test-Path -LiteralPath $baselinePath -PathType Leaf
$allowMissingBaseline = (
    $historicalEvidencePolicy -and
    $historicalEvidencePolicy.state -eq 'sealed'
)
$legacyBaseline = Read-LegacyBaseline -Root $WorkspaceRoot -BaselinePath $baselinePath `
    -AllowMissing:$allowMissingBaseline
$historicalEvidenceSealValid = $true
if ($historicalEvidencePolicy) {
    $null = Test-HistoricalEvidenceTransition -Policy $historicalEvidencePolicy `
        -RecordCount $historicalEvidenceRecords.Count -BaselineCount $legacyBaseline.Count `
        -BaselineExists $baselineExists `
        -EvidenceMigrationCommit $historicalEvidenceDocument.migrationCommit
    if ($historicalEvidencePolicy.state -eq 'sealed') {
        $currentEvidenceSha = if (
            Test-Path -LiteralPath $historicalEvidencePath -PathType Leaf
        ) {
            Get-RepositoryFileHash -Path $historicalEvidencePath
        } else {
            $null
        }
        if (
            -not $currentEvidenceSha -or
            $currentEvidenceSha -cne $historicalEvidencePolicy.evidenceSha256
        ) {
            $historicalEvidenceSealValid = $false
            Add-ValidationIssue -Severity error -Category 'historical-evidence-seal-mismatch' `
                -Path 'studio/runtime/mainline-note-historical-evidence.json' `
                -Message 'Sealed historical evidence bytes must match contract evidenceSha256.'
        }
    }
}
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

$historicalEvidenceByPath = @{}
$historicalBatchBaseline = @{}
$historicalHeadCommit = if ($gitAvailable) {
    Resolve-GitCommit -Root $WorkspaceRoot -Reference $HeadRef
} else {
    $null
}
if (
    $historicalEvidencePolicy -and
    $gitAvailable -and
    $historicalEvidencePolicy.expectedRecordCount -gt 0
) {
    $resolvedPolicyBase = Resolve-GitCommit -Root $WorkspaceRoot `
        -Reference $historicalEvidencePolicy.batchBase
    if (
        -not $resolvedPolicyBase -or
        $resolvedPolicyBase -cne $historicalEvidencePolicy.batchBase
    ) {
        Add-ValidationIssue -Severity error -Category 'historical-evidence-batch-base-invalid' `
            -Path 'studio/runtime/shared-runtime-contract.json' `
            -Message 'The contract historical batchBase does not resolve to its exact commit.'
    } else {
        $baselineAtPolicyBase = Read-LegacyBaselineAtCommit -Root $WorkspaceRoot `
            -Commit $resolvedPolicyBase
        if ($null -eq $baselineAtPolicyBase) {
            Add-ValidationIssue -Severity error -Category 'historical-evidence-batch-baseline-invalid' `
                -Path 'studio/runtime/mainline-note-validation-baseline.json' `
                -Message 'Unable to read the legacy baseline blob at the fixed batchBase.'
        } else {
            $historicalBatchBaseline = $baselineAtPolicyBase
            if ($historicalBatchBaseline.Count -ne $historicalEvidencePolicy.expectedRecordCount) {
                Add-ValidationIssue -Severity error -Category 'historical-evidence-batch-baseline-invalid' `
                    -Path 'studio/runtime/mainline-note-validation-baseline.json' `
                    -Message 'The fixed batchBase baseline count does not match expectedRecordCount.'
            }
            if ($historicalEvidencePolicy.state -eq 'pending') {
                $currentBaselineSha = if ($baselineExists) {
                    Get-RepositoryFileHash -Path $baselinePath
                } else {
                    $null
                }
                $batchBaselineSha = Get-GitBlobSha256 -Root $WorkspaceRoot `
                    -Commit $resolvedPolicyBase `
                    -Path 'studio/runtime/mainline-note-validation-baseline.json'
                if (
                    -not $currentBaselineSha -or
                    -not $batchBaselineSha -or
                    $currentBaselineSha -ne $batchBaselineSha
                ) {
                    Add-ValidationIssue -Severity error -Category 'historical-evidence-pending-baseline-mismatch' `
                        -Path 'studio/runtime/mainline-note-validation-baseline.json' `
                        -Message 'Pending migration requires the exact legacy baseline bytes from batchBase.'
                }
            }
        }
    }
}

if (
    $historicalEvidenceRecords.Count -gt 0 -or
    ($historicalEvidencePolicy -and $historicalEvidencePolicy.state -eq 'sealed')
) {
    if (-not $historicalEvidencePolicy) {
        Add-ValidationIssue -Severity error -Category 'historical-evidence-policy' `
            -Path 'studio/runtime/shared-runtime-contract.json' `
            -Message 'Historical evidence records cannot be validated without migration policy.'
    } elseif (-not $gitAvailable -or -not $historicalHeadCommit) {
        Test-HistoricalEvidenceStructuralRecords -Records $historicalEvidenceRecords `
            -NotesByPath $notesByPath
        if ($RequireReady -or $baseRefMode) {
            Add-ValidationIssue -Severity error -Category 'historical-evidence-git-context' `
                -Path 'studio/runtime/mainline-note-historical-evidence.json' `
                -Message 'Blocking or BaseRef validation of historical evidence requires an available Git worktree.'
        }
    } else {
        $authorityPaths = @(
            $historicalEvidencePolicy.evidencePath,
            $historicalEvidencePolicy.schemaPath,
            'studio/runtime/shared-runtime-contract.json',
            $historicalEvidencePolicy.legacyBaselinePath,
            'docs/mainline-updates/README.md'
        )
        $authoritySurfaceClean = Test-HeadBoundAuthoritySurface -Root $WorkspaceRoot `
            -HeadCommit $historicalHeadCommit -Paths $authorityPaths `
            -AllowAbsentPaths @($historicalEvidencePolicy.legacyBaselinePath)
        $authoritySurfaceClean = (
            $authoritySurfaceClean -and
            $historicalEvidenceSealValid
        )
        $historicalEvidenceByPath = Test-HistoricalEvidenceRecords -Root $WorkspaceRoot `
            -Records $historicalEvidenceRecords -CurrentBaseline $legacyBaseline `
            -NotesByPath $notesByPath `
            -HeadReference $HeadRef -ExpectedBatchBase $historicalEvidencePolicy.batchBase `
            -ExpectedMigrationCommit $historicalEvidencePolicy.migrationCommit `
            -ExpectedRecordCount $historicalEvidencePolicy.expectedRecordCount `
            -AuthoritySurfaceClean $authoritySurfaceClean
    }
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
                $historicalRecord = if ($historicalEvidenceByPath.ContainsKey($note.path)) {
                    $historicalEvidenceByPath[$note.path]
                } else {
                    $null
                }
                $isBoundHistoricalReference = (
                    $historicalRecord -and
                    $historicalRecord.historicalCommitSet.Contains($resolved)
                )
                if ($isBoundHistoricalReference) {
                    $script:historicalEvidenceApplied.Add("$($note.path)@$resolved")
                    continue
                }
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
        -not $historicalEvidenceByPath.ContainsKey($_.path) -and
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
                -not $historicalEvidenceByPath.ContainsKey($aggregatePath) -and
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
    LEGACY_BASELINE_EXISTS    = [bool]$baselineExists
    LEGACY_BASELINE_APPLIED   = @($script:legacyBaselineApplied)
    HISTORICAL_EVIDENCE_COUNT = $historicalEvidenceRecords.Count
    HISTORICAL_EVIDENCE_VALID = $historicalEvidenceByPath.Count
    HISTORICAL_EVIDENCE_APPLIED = @($script:historicalEvidenceApplied)
    HISTORICAL_EVIDENCE_MIGRATION_STATE = if ($historicalEvidencePolicy) {
        $historicalEvidencePolicy.state
    } else {
        $null
    }
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
