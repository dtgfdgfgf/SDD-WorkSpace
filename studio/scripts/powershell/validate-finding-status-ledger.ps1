#Requires -Version 7.0

[CmdletBinding()]
param(
    [string]$WorkspaceRoot,
    [string]$BaseRef,
    [string]$HeadRef = 'HEAD',
    [switch]$Json,
    [switch]$Help
)

<#
.SYNOPSIS
Validates the machine-authoritative finding-status records embedded in the workspace repair ledger.

.DESCRIPTION
Only visible fenced blocks whose exact selector is finding-status-record-v1 are status authority.
Historical Markdown prose and status tables are deliberately ignored. The first visible
severity-definition occurrence establishes each finding ID; later same-severity historical rows
are allowed, while a conflicting severity fails closed.

When BaseRef is supplied, records present at BaseRef must remain an exact prefix at HeadRef.
This permits append-only revisions and rejects rewritten, removed, reordered, or inserted history.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
    Get-Help $MyInvocation.MyCommand.Path -Detailed
    exit 0
}

$ledgerRelativePath = 'docs/sdd-workspace-repair-inventory-and-update-plan-2026-07-12_zhTW.md'
$schemaRelativePath = 'studio/runtime/finding-status-record.schema.json'
$indexRelativePath = 'docs/README.md'
$selector = 'finding-status-record-v1'
$statusOrder = @('COMPLETED', 'OPEN', 'DECIDED', 'IN_PROGRESS', 'DISPOSITIONED')
$severityOrder = @('Critical', 'High', 'Medium', 'Low')
$authorizedDispositionTriggerGroups = @(
    [pscustomobject][ordered]@{
        ids = @('R-A13')
        trigger = 'Before adding or materially expanding `mustContainAll` literal assertions, or before the next contract-invariant refactor'
    }
    [pscustomobject][ordered]@{
        ids = @('R-B23')
        trigger = 'Before any workflow promotion, execution authorization, or use of RunState/sidecar data as trusted evidence; deferral is valid only while `sdd-pipeline` stays experimental, default-disabled and execution-denied'
    }
    [pscustomobject][ordered]@{
        ids = @('R-F01', 'R-F02', 'R-F03', 'R-F05', 'R-G02')
        trigger = 'Before upstream adoption, Yuanxi pack implementation, or any renewed current-baseline claim; upstream release and CLI facts must be re-verified at that time'
    }
    [pscustomobject][ordered]@{
        ids = @('R-D08', 'R-D09', 'R-D10', 'R-D11')
        trigger = 'Before the next change to agent source, Claude invocation guidance, discovery/version-agent surfaces or their generated mirrors'
    }
    [pscustomobject][ordered]@{
        ids = @('R-E01', 'R-E03', 'R-E04', 'R-E06', 'R-E12')
        trigger = 'Before the corresponding constitution classification, authority taxonomy, bootstrap wording or hook classification is changed again'
    }
    [pscustomobject][ordered]@{
        ids = @('R-G05', 'R-G07', 'R-G08', 'R-G09', 'R-G11', 'R-G12')
        trigger = 'Before the affected document is reused as current guidance, supplied to an LLM for execution, or materially revised'
    }
    [pscustomobject][ordered]@{
        ids = @('R-H07', 'R-H14', 'R-H18')
        trigger = 'Before the affected root asset, reserved directory or language policy is presented as a current supported surface'
    }
    [pscustomobject][ordered]@{
        ids = @('R-I01')
        trigger = 'Before the shared-runtime upgrade scope is expanded or changed'
    }
    [pscustomobject][ordered]@{
        ids = @('R-I02')
        trigger = 'Before adapter templates or the bootstrap generator are changed'
    }
    [pscustomobject][ordered]@{
        ids = @('R-I04', 'R-I05')
        trigger = 'Before a project claims complete prompt or knowledge-capture closure'
    }
    [pscustomobject][ordered]@{
        ids = @('R-I09')
        trigger = 'Before the extension operator surface is documented or used externally'
    }
    [pscustomobject][ordered]@{
        ids = @('R-D06')
        trigger = 'Before agent reseed or a model lifecycle, availability, cost or policy change'
    }
    [pscustomobject][ordered]@{
        ids = @('R-D12')
        trigger = 'Only after a separate owner-authorized consumer exception and a decision between project-local Copilot overlay and Claude-only support; current `projects/` and `learning/` exclusion prevents implementation'
    }
    [pscustomobject][ordered]@{
        ids = @('R-F04', 'R-H15')
        trigger = 'Before agent-skill export/install is reused, advertised or repopulated'
    }
    [pscustomobject][ordered]@{
        ids = @('R-I03')
        trigger = 'Before route-aware auto-scaffold work or workflow promotion'
    }
)
$authorizedDispositionTriggers = [System.Collections.Generic.Dictionary[string,string]]::new(
    [System.StringComparer]::Ordinal
)
$dispositionTriggerPolicyHasDuplicateIds = $false
foreach ($triggerGroup in $authorizedDispositionTriggerGroups) {
    foreach ($findingId in @($triggerGroup.ids)) {
        if (-not $authorizedDispositionTriggers.TryAdd([string]$findingId, [string]$triggerGroup.trigger)) {
            $dispositionTriggerPolicyHasDuplicateIds = $true
        }
    }
}
$authorizedDispositionTriggerSha256 = '6c1e442d4d9b6f5be5360cffb537dbe1fa6ccaa33783f701376409ca5e007262'
$script:errors = [System.Collections.Generic.List[object]]::new()
$script:warnings = [System.Collections.Generic.List[object]]::new()

function Add-FindingStatusIssue {
    param(
        [Parameter(Mandatory)] [ValidateSet('error', 'warning')] [string]$Severity,
        [Parameter(Mandatory)] [string]$Category,
        [Parameter(Mandatory)] [string]$Message,
        [string]$Path
    )

    $issue = [pscustomobject][ordered]@{
        category = $Category
        message = $Message
        path = $Path
    }
    if ($Severity -eq 'error') {
        $script:errors.Add($issue)
    } else {
        $script:warnings.Add($issue)
    }
}

function Get-DispositionTriggerPolicySha256 {
    param(
        [Parameter(Mandatory)]
        [System.Collections.Generic.Dictionary[string,string]]$Map
    )

    $ids = [string[]]@($Map.Keys)
    [System.Array]::Sort($ids, [System.StringComparer]::Ordinal)
    $canonical = @(
        $ids | ForEach-Object { "$_`t$($Map[$_])" }
    ) -join "`n"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($canonical)
    return [System.Convert]::ToHexString(
        [System.Security.Cryptography.SHA256]::HashData($bytes)
    ).ToLowerInvariant()
}

function Get-DuplicateReentryTriggerEntryIndexes {
    param([Parameter(Mandatory)] [string]$Payload)

    $duplicates = [System.Collections.Generic.List[int]]::new()
    $document = [System.Text.Json.JsonDocument]::Parse($Payload)
    try {
        $root = $document.RootElement
        if ($root.ValueKind -ne [System.Text.Json.JsonValueKind]::Object) {
            return @()
        }
        try {
            $statuses = $root.GetProperty('statuses')
        } catch {
            return @()
        }
        if ($statuses.ValueKind -ne [System.Text.Json.JsonValueKind]::Array) {
            return @()
        }

        $entryIndex = 0
        foreach ($entry in $statuses.EnumerateArray()) {
            $entryIndex++
            if ($entry.ValueKind -ne [System.Text.Json.JsonValueKind]::Object) {
                continue
            }
            $triggerPropertyCount = 0
            foreach ($property in $entry.EnumerateObject()) {
                if ([string]::Equals(
                    [string]$property.Name,
                    'reentryTrigger',
                    [System.StringComparison]::Ordinal
                )) {
                    $triggerPropertyCount++
                }
            }
            if ($triggerPropertyCount -gt 1) {
                $duplicates.Add($entryIndex)
            }
        }
    } finally {
        $document.Dispose()
    }
    return @($duplicates)
}

function Test-FindingStatusTriggerContract {
    param(
        [AllowNull()] [object]$Record,
        [Parameter(Mandatory)] [int]$Position,
        [int[]]$DuplicateTriggerEntryIndexes = @()
    )

    if ($Record -isnot [System.Collections.IDictionary]) {
        return $true
    }
    $recordKeys = @($Record.Keys | ForEach-Object { [string]$_ })
    if (
        -not ($recordKeys -ccontains 'statuses') -or
        $Record.statuses -isnot [System.Collections.IList]
    ) {
        return $true
    }

    $valid = $true
    $duplicateIndexSet = [System.Collections.Generic.HashSet[int]]::new()
    foreach ($duplicateIndex in @($DuplicateTriggerEntryIndexes)) {
        $null = $duplicateIndexSet.Add([int]$duplicateIndex)
    }

    $entryIndex = 0
    foreach ($entry in @($Record.statuses)) {
        $entryIndex++
        if ($entry -isnot [System.Collections.IDictionary]) {
            continue
        }
        $entryKeys = @($entry.Keys | ForEach-Object { [string]$_ })
        $hasTrigger = $entryKeys -ccontains 'reentryTrigger'
        $isDispositioned = (
            $entryKeys -ccontains 'status' -and
            $entry.status -is [string] -and
            [string]$entry.status -ceq 'DISPOSITIONED'
        )
        $id = if (
            $entryKeys -ccontains 'id' -and
            $entry.id -is [string]
        ) { [string]$entry.id } else { '<invalid>' }

        if ($duplicateIndexSet.Contains($entryIndex)) {
            Add-FindingStatusIssue -Severity error -Category 'status-disposition-trigger-duplicate' `
                -Path $ledgerRelativePath `
                -Message "Finding-status record at position $Position entry $entryIndex contains duplicate reentryTrigger properties."
            $valid = $false
            continue
        }

        if (-not $isDispositioned) {
            if ($hasTrigger) {
                Add-FindingStatusIssue -Severity error -Category 'status-reentry-trigger-forbidden' `
                    -Path $ledgerRelativePath `
                    -Message "Finding-status record at position $Position entry $entryIndex carries reentryTrigger for non-DISPOSITIONED status."
                $valid = $false
            }
            continue
        }

        if (-not $hasTrigger) {
            Add-FindingStatusIssue -Severity error -Category 'status-disposition-trigger-missing' `
                -Path $ledgerRelativePath `
                -Message "DISPOSITIONED finding '$id' at record position $Position requires reentryTrigger."
            $valid = $false
            continue
        }
        if ($entry.reentryTrigger -isnot [string]) {
            Add-FindingStatusIssue -Severity error -Category 'status-disposition-trigger-type' `
                -Path $ledgerRelativePath `
                -Message "DISPOSITIONED finding '$id' at record position $Position has a non-string reentryTrigger."
            $valid = $false
            continue
        }
        if ([string]::IsNullOrWhiteSpace([string]$entry.reentryTrigger)) {
            Add-FindingStatusIssue -Severity error -Category 'status-disposition-trigger-blank' `
                -Path $ledgerRelativePath `
                -Message "DISPOSITIONED finding '$id' at record position $Position has a blank reentryTrigger."
            $valid = $false
            continue
        }
        if (-not $authorizedDispositionTriggers.ContainsKey($id)) {
            Add-FindingStatusIssue -Severity error -Category 'status-disposition-id-unapproved' `
                -Path $ledgerRelativePath `
                -Message "Finding '$id' is not authorized for a trigger-bearing DISPOSITIONED transition."
            $valid = $false
            continue
        }
        if (-not [string]::Equals(
            [string]$entry.reentryTrigger,
            [string]$authorizedDispositionTriggers[$id],
            [System.StringComparison]::Ordinal
        )) {
            Add-FindingStatusIssue -Severity error -Category 'status-disposition-trigger-mismatch' `
                -Path $ledgerRelativePath `
                -Message "DISPOSITIONED finding '$id' at record position $Position does not carry its exact authorized re-entry trigger."
            $valid = $false
        }
    }
    return $valid
}

function Resolve-ValidationRoot {
    param([string]$RequestedRoot)

    if ([string]::IsNullOrWhiteSpace($RequestedRoot)) {
        return [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
    }
    return [System.IO.Path]::GetFullPath($RequestedRoot)
}

function Get-GitCommit {
    param([string]$Root, [string]$Reference)

    $output = @(& git -C $Root rev-parse --verify "$Reference`^{commit}" 2>$null)
    if ($LASTEXITCODE -ne 0 -or $output.Count -ne 1) { return $null }
    $commit = ([string]$output[0]).Trim().ToLowerInvariant()
    if ($commit -notmatch '^[0-9a-f]{40}$') { return $null }
    return $commit
}

function Get-GitFileText {
    param(
        [string]$Root,
        [string]$Commit,
        [string]$RelativePath,
        [switch]$AllowMissing
    )

    $specification = "${Commit}:$RelativePath"
    $output = @(& git -C $Root show $specification 2>$null)
    if ($LASTEXITCODE -ne 0) {
        if ($AllowMissing) { return $null }
        throw "Unable to read $RelativePath at $Commit"
    }
    return (($output -join "`n") + "`n")
}

function Get-LedgerSurface {
    param(
        [AllowNull()] [string]$Content,
        [switch]$HistorySurface,
        [switch]$PlainMarkdown
    )

    $visible = [System.Collections.Generic.List[string]]::new()
    $visibleEntries = [System.Collections.Generic.List[object]]::new()
    $blocks = [System.Collections.Generic.List[object]]::new()
    $inComment = $false
    $fenceMarker = $null
    $fenceLength = 0
    $statusFence = $false
    $statusLines = [System.Collections.Generic.List[string]]::new()
    $statusRawLines = [System.Collections.Generic.List[string]]::new()
    $statusFenceStartLine = 0
    $rawHtmlEndPattern = $null
    $rawHtmlEndsOnBlank = $false
    $lineNumber = 0

    foreach ($rawLine in @(($Content ?? '') -split "`r?`n")) {
        $lineNumber++
        $line = [string]$rawLine
        $surfaceLine = $line

        if ($fenceMarker) {
            $closingPattern = '^ {0,3}' + [regex]::Escape($fenceMarker) + "{$fenceLength,}[ \t]*$"
            if ($line -match $closingPattern) {
                if ($statusFence) {
                    $statusRawLines.Add($line)
                    $blocks.Add([pscustomobject][ordered]@{
                        payload = ($statusLines -join "`n")
                        raw = ($statusRawLines -join "`n")
                        startLine = $statusFenceStartLine
                        endLine = $lineNumber
                    })
                }
                $fenceMarker = $null
                $fenceLength = 0
                $statusFence = $false
                $statusLines = [System.Collections.Generic.List[string]]::new()
                $statusRawLines = [System.Collections.Generic.List[string]]::new()
            } elseif ($statusFence) {
                $statusLines.Add($line)
                $statusRawLines.Add($line)
            }
            $visible.Add('')
            $visibleEntries.Add([pscustomobject][ordered]@{ line = $lineNumber; text = '' })
            continue
        }

        if ($rawHtmlEndPattern -or $rawHtmlEndsOnBlank) {
            $rawHtmlBlockEnded = $false
            if ($rawHtmlEndPattern -and $surfaceLine -match $rawHtmlEndPattern) {
                $rawHtmlBlockEnded = $true
            } elseif ($rawHtmlEndsOnBlank -and [string]::IsNullOrWhiteSpace($surfaceLine)) {
                $rawHtmlBlockEnded = $true
            }
            if ($rawHtmlBlockEnded) {
                $rawHtmlEndPattern = $null
                $rawHtmlEndsOnBlank = $false
            }
            $visible.Add('')
            $visibleEntries.Add([pscustomobject][ordered]@{ line = $lineNumber; text = '' })
            continue
        }

        # Indented code is never visible governance authority. Check it before
        # comments so literal comment markers cannot change parser state.
        if (-not $inComment -and $surfaceLine -match '^(?: {4}| {0,3}\t)') {
            $visible.Add('')
            $visibleEntries.Add([pscustomobject][ordered]@{ line = $lineNumber; text = '' })
            continue
        }

        while ($true) {
            if ($inComment) {
                $commentEnd = $surfaceLine.IndexOf('-->', [System.StringComparison]::Ordinal)
                if ($commentEnd -lt 0) {
                    $surfaceLine = ''
                    break
                }
                $surfaceLine = $surfaceLine.Substring($commentEnd + 3)
                $inComment = $false
                continue
            }

            $commentStart = $surfaceLine.IndexOf('<!--', [System.StringComparison]::Ordinal)
            if ($commentStart -lt 0) { break }
            $commentEnd = $surfaceLine.IndexOf('-->', $commentStart + 4, [System.StringComparison]::Ordinal)
            if ($commentEnd -ge 0) {
                $surfaceLine = $surfaceLine.Remove($commentStart, ($commentEnd + 3) - $commentStart)
                continue
            }
            $surfaceLine = $surfaceLine.Substring(0, $commentStart)
            $inComment = $true
            break
        }

        if ($surfaceLine -match '^(?: {4}| {0,3}\t)') {
            $visible.Add('')
            $visibleEntries.Add([pscustomobject][ordered]@{ line = $lineNumber; text = '' })
            continue
        }

        if ($surfaceLine -match '(?i)^ {0,3}<(script|pre|style|textarea)(?:[ \t]|>|$)') {
            $rawTag = [regex]::Escape($Matches[1])
            $closingTagPattern = "(?i)</$rawTag[ \t]*>"
            if ($surfaceLine -notmatch $closingTagPattern) {
                $rawHtmlEndPattern = $closingTagPattern
            }
            $visible.Add('')
            $visibleEntries.Add([pscustomobject][ordered]@{ line = $lineNumber; text = '' })
            continue
        }
        if ($surfaceLine -match '^ {0,3}<\?') {
            if ($surfaceLine -notmatch '\?>') {
                $rawHtmlEndPattern = '\?>'
            }
            $visible.Add('')
            $visibleEntries.Add([pscustomobject][ordered]@{ line = $lineNumber; text = '' })
            continue
        }
        if ($surfaceLine -match '^ {0,3}<!\[CDATA\[') {
            if ($surfaceLine -notmatch '\]\]>') {
                $rawHtmlEndPattern = '\]\]>'
            }
            $visible.Add('')
            $visibleEntries.Add([pscustomobject][ordered]@{ line = $lineNumber; text = '' })
            continue
        }
        if ($surfaceLine -match '^ {0,3}<![A-Z]') {
            if ($surfaceLine -notmatch '>') {
                $rawHtmlEndPattern = '>'
            }
            $visible.Add('')
            $visibleEntries.Add([pscustomobject][ordered]@{ line = $lineNumber; text = '' })
            continue
        }
        if ($surfaceLine -match '(?i)^ {0,3}</?[A-Za-z][A-Za-z0-9-]*(?:[ \t]|/?>|$)') {
            $rawHtmlEndsOnBlank = $true
            $visible.Add('')
            $visibleEntries.Add([pscustomobject][ordered]@{ line = $lineNumber; text = '' })
            continue
        }

        if ($surfaceLine -match '^ {0,3}(?<marker>`{3,}|~{3,})(?<info>.*)$') {
            $fenceMarker = $Matches.marker.Substring(0, 1)
            $fenceLength = $Matches.marker.Length
            $rawInfo = [string]$Matches.info
            $hasExactStatusSelector = ($rawInfo -ceq $selector)
            $hasStatusSelectorLookalike = ($rawInfo.Trim() -ceq $selector)
            $statusFence = (-not $PlainMarkdown -and $Matches.marker -ceq '```' -and $hasExactStatusSelector)
            if (-not $PlainMarkdown -and $hasStatusSelectorLookalike -and -not $statusFence) {
                Add-FindingStatusIssue -Severity error -Category 'status-record-envelope-invalid' `
                    -Path $ledgerRelativePath `
                    -Message 'A visible finding-status selector must use the canonical three-backtick opening envelope.'
            }
            if ($statusFence) {
                $statusRawLines.Add($line)
                $statusFenceStartLine = $lineNumber
            }
            $visible.Add('')
            $visibleEntries.Add([pscustomobject][ordered]@{ line = $lineNumber; text = '' })
            continue
        }

        $visible.Add($surfaceLine)
        $visibleEntries.Add([pscustomobject][ordered]@{ line = $lineNumber; text = $surfaceLine })
    }

    if ($fenceMarker -and $statusFence -and -not $HistorySurface -and -not $PlainMarkdown) {
        Add-FindingStatusIssue -Severity error -Category 'status-record-fence-unclosed' `
            -Path $ledgerRelativePath -Message 'The finding-status authority fence is not closed.'
    }

    return [pscustomobject][ordered]@{
        visible = @($visible)
        visibleEntries = @($visibleEntries)
        blocks = @($blocks)
    }
}

function Get-FrontmatterValue {
    param([string]$Frontmatter, [string]$Key)

    $declarations = @([regex]::Matches(
        $Frontmatter,
        ('(?m)^{0}\s*:(?<raw>[^\r\n]*)$' -f [regex]::Escape($Key))
    ))
    if ($declarations.Count -ne 1) {
        Add-FindingStatusIssue -Severity error -Category 'status-scope-metadata' `
            -Path $ledgerRelativePath -Message "Ledger frontmatter requires exactly one unambiguous '$Key' field."
        return $null
    }
    $quotedValue = [regex]::Match(
        $declarations[0].Groups['raw'].Value,
        '^\s*"(?<value>[^\"]+)"\s*$'
    )
    if (-not $quotedValue.Success) {
        Add-FindingStatusIssue -Severity error -Category 'status-scope-metadata' `
            -Path $ledgerRelativePath -Message "Ledger frontmatter '$Key' must have one quoted scalar value."
        return $null
    }
    return $quotedValue.Groups['value'].Value
}

function Test-GovernedFrontmatterKeys {
    param(
        [string]$Frontmatter,
        [string[]]$GovernedKeys
    )

    $canonicalByNormalizedKey = @{}
    $occurrences = @{}
    foreach ($key in $GovernedKeys) {
        $normalizedKey = ($key -replace '[_-]', '').ToLowerInvariant()
        $canonicalByNormalizedKey[$normalizedKey] = $key
        $occurrences[$key] = 0
    }

    foreach ($line in @($Frontmatter -split "`r?`n")) {
        $keyMatch = [regex]::Match(
            [string]$line,
            '^(?<indent>[ \t]*)(?<key>"[^"]+"|''[^'']+''|[A-Za-z_][A-Za-z0-9_-]*)[ \t]*:'
        )
        if (-not $keyMatch.Success) { continue }

        $rawKey = [string]$keyMatch.Groups['key'].Value
        $unquotedKey = $rawKey
        if (
            $rawKey.Length -ge 2 -and
            (($rawKey[0] -eq '"' -and $rawKey[$rawKey.Length - 1] -eq '"') -or
             ($rawKey[0] -eq "'" -and $rawKey[$rawKey.Length - 1] -eq "'"))
        ) {
            $unquotedKey = $rawKey.Substring(1, $rawKey.Length - 2)
        }
        $normalizedKey = (($unquotedKey.Trim()) -replace '[_-]', '').ToLowerInvariant()
        if (-not $canonicalByNormalizedKey.ContainsKey($normalizedKey)) { continue }

        $canonicalKey = [string]$canonicalByNormalizedKey[$normalizedKey]
        $occurrences[$canonicalKey]++
        if (
            $rawKey -cne $canonicalKey -or
            $keyMatch.Groups['indent'].Value.Length -ne 0
        ) {
            Add-FindingStatusIssue -Severity error -Category 'status-scope-metadata' `
                -Path $ledgerRelativePath `
                -Message "Ledger frontmatter governance key '$canonicalKey' must use its exact unquoted top-level spelling."
        }
    }

    foreach ($key in $GovernedKeys) {
        if ([int]$occurrences[$key] -gt 1) {
            Add-FindingStatusIssue -Severity error -Category 'status-scope-metadata' `
                -Path $ledgerRelativePath `
                -Message "Ledger frontmatter governance key '$key' must not have duplicate or alternate declarations."
        }
    }
}

function Test-JsonIntegerValue {
    param([AllowNull()] [object]$Value)

    return (
        $Value -is [byte] -or $Value -is [sbyte] -or
        $Value -is [int16] -or $Value -is [uint16] -or
        $Value -is [int32] -or $Value -is [uint32] -or
        $Value -is [int64] -or $Value -is [uint64]
    )
}

function Test-DeepContractEqual {
    param(
        [AllowNull()] [object]$Actual,
        [AllowNull()] [object]$Expected
    )

    if ($null -eq $Actual -or $null -eq $Expected) {
        return ($null -eq $Actual -and $null -eq $Expected)
    }
    if ($Expected -is [System.Collections.IDictionary]) {
        if ($Actual -isnot [System.Collections.IDictionary]) { return $false }
        $actualKeys = @($Actual.Keys | ForEach-Object { [string]$_ })
        $expectedKeys = @($Expected.Keys | ForEach-Object { [string]$_ })
        if ($actualKeys.Count -ne $expectedKeys.Count) { return $false }
        foreach ($key in $expectedKeys) {
            if (-not ($actualKeys -ccontains $key)) { return $false }
            if (-not (Test-DeepContractEqual -Actual $Actual[$key] -Expected $Expected[$key])) {
                return $false
            }
        }
        return $true
    }
    if ($Expected -is [System.Collections.IList]) {
        if ($Actual -isnot [System.Collections.IList]) { return $false }
        if ($Actual.Count -ne $Expected.Count) { return $false }
        for ($index = 0; $index -lt $Expected.Count; $index++) {
            if (-not (Test-DeepContractEqual -Actual $Actual[$index] -Expected $Expected[$index])) {
                return $false
            }
        }
        return $true
    }
    if ((Test-JsonIntegerValue -Value $Expected) -or (Test-JsonIntegerValue -Value $Actual)) {
        return (
            (Test-JsonIntegerValue -Value $Expected) -and
            (Test-JsonIntegerValue -Value $Actual) -and
            [decimal]$Actual -eq [decimal]$Expected
        )
    }
    if ($Actual.GetType() -ne $Expected.GetType()) { return $false }
    if ($Expected -is [string]) { return ([string]$Actual -ceq [string]$Expected) }
    return $Actual.Equals($Expected)
}

function Test-FindingStatusSchemaContract {
    param([AllowNull()] [object]$Schema)

    if ($Schema -isnot [System.Collections.IDictionary]) { return $false }
    $schemaKeys = @($Schema.Keys | ForEach-Object { [string]$_ })
    $contractKeys = @('$schema', '$id', 'title', 'type', 'additionalProperties', 'required', 'properties')
    if ($schemaKeys.Count -ne $contractKeys.Count) { return $false }
    foreach ($key in $contractKeys) {
        if (-not ($schemaKeys -ccontains $key)) { return $false }
    }

    $expected = [ordered]@{
        '$schema' = 'https://json-schema.org/draft/2020-12/schema'
        '$id' = 'https://github.com/dtgfdgfgf/SDD-WorkSpace/studio/runtime/finding-status-record.schema.json'
        title = 'Finding status ledger record'
        type = 'object'
        additionalProperties = $false
        required = @(
            'schemaVersion', 'revision', 'recordType', 'recordedDate', 'ledgerVersion',
            'statuses', 'inventoryCount', 'severityCounts', 'statusCounts'
        )
        properties = [ordered]@{
            schemaVersion = [ordered]@{ type = 'integer'; const = 1 }
            revision = [ordered]@{ type = 'integer'; minimum = 1 }
            recordType = [ordered]@{ type = 'string'; enum = @('snapshot', 'delta') }
            recordedDate = [ordered]@{ type = 'string'; format = 'date' }
            ledgerVersion = [ordered]@{
                type = 'string'
                pattern = '^[0-9]+\.[0-9]+\.[0-9]+$'
            }
            statuses = [ordered]@{
                type = 'array'
                minItems = 1
                items = [ordered]@{
                    type = 'object'
                    additionalProperties = $false
                    required = @('id', 'status')
                    properties = [ordered]@{
                        id = [ordered]@{ type = 'string'; pattern = '^R-[A-Z][0-9]{2,}$' }
                        status = [ordered]@{ type = 'string'; enum = @($statusOrder) }
                        reentryTrigger = [ordered]@{
                            type = 'string'
                            minLength = 1
                            pattern = '\S'
                        }
                    }
                    allOf = @(
                        [ordered]@{
                            'if' = [ordered]@{
                                properties = [ordered]@{
                                    status = [ordered]@{ const = 'DISPOSITIONED' }
                                }
                                required = @('status')
                            }
                            'then' = [ordered]@{ required = @('reentryTrigger') }
                            'else' = [ordered]@{
                                'not' = [ordered]@{ required = @('reentryTrigger') }
                            }
                        }
                    )
                }
            }
            inventoryCount = [ordered]@{ type = 'integer'; minimum = 1 }
            severityCounts = [ordered]@{
                type = 'object'
                additionalProperties = $false
                required = @($severityOrder)
                properties = [ordered]@{
                    Critical = [ordered]@{ type = 'integer'; minimum = 0 }
                    High = [ordered]@{ type = 'integer'; minimum = 0 }
                    Medium = [ordered]@{ type = 'integer'; minimum = 0 }
                    Low = [ordered]@{ type = 'integer'; minimum = 0 }
                }
            }
            statusCounts = [ordered]@{
                type = 'object'
                additionalProperties = $false
                required = @($statusOrder)
                properties = [ordered]@{
                    COMPLETED = [ordered]@{ type = 'integer'; minimum = 0 }
                    OPEN = [ordered]@{ type = 'integer'; minimum = 0 }
                    DECIDED = [ordered]@{ type = 'integer'; minimum = 0 }
                    IN_PROGRESS = [ordered]@{ type = 'integer'; minimum = 0 }
                    DISPOSITIONED = [ordered]@{ type = 'integer'; minimum = 0 }
                }
            }
        }
    }
    $actual = [ordered]@{}
    foreach ($key in $contractKeys) { $actual[$key] = $Schema[$key] }
    return (Test-DeepContractEqual -Actual $actual -Expected $expected)
}

function Test-ExactRecordMap {
    param(
        [AllowNull()] [object]$Map,
        [string[]]$Keys,
        [int]$Minimum
    )

    if ($Map -isnot [System.Collections.IDictionary]) { return $false }
    $actualKeys = @($Map.Keys | ForEach-Object { [string]$_ })
    if ($actualKeys.Count -ne $Keys.Count) { return $false }
    foreach ($key in $Keys) {
        if (-not ($actualKeys -ccontains $key)) { return $false }
        if (-not (Test-JsonIntegerValue -Value $Map[$key]) -or [long]$Map[$key] -lt $Minimum) {
            return $false
        }
    }
    return $true
}

function Test-FindingStatusRecordContract {
    param([AllowNull()] [object]$Record)

    $requiredKeys = @(
        'schemaVersion', 'revision', 'recordType', 'recordedDate', 'ledgerVersion',
        'statuses', 'inventoryCount', 'severityCounts', 'statusCounts'
    )
    if ($Record -isnot [System.Collections.IDictionary]) { return $false }
    $actualKeys = @($Record.Keys | ForEach-Object { [string]$_ })
    if ($actualKeys.Count -ne $requiredKeys.Count) { return $false }
    foreach ($key in $requiredKeys) {
        if (-not ($actualKeys -ccontains $key)) { return $false }
    }
    if (
        -not (Test-JsonIntegerValue -Value $Record.schemaVersion) -or
        [long]$Record.schemaVersion -ne 1 -or
        -not (Test-JsonIntegerValue -Value $Record.revision) -or
        [long]$Record.revision -lt 1 -or
        $Record.recordType -isnot [string] -or
        -not (@('snapshot', 'delta') -ccontains [string]$Record.recordType) -or
        $Record.recordedDate -isnot [string] -or
        [string]$Record.recordedDate -notmatch '^\d{4}-\d{2}-\d{2}$' -or
        $Record.ledgerVersion -isnot [string] -or
        [string]$Record.ledgerVersion -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$' -or
        -not (Test-JsonIntegerValue -Value $Record.inventoryCount) -or
        [long]$Record.inventoryCount -lt 1
    ) {
        return $false
    }
    if ($Record.statuses -isnot [System.Collections.IList] -or $Record.statuses.Count -lt 1) {
        return $false
    }
    foreach ($entry in $Record.statuses) {
        if ($entry -isnot [System.Collections.IDictionary]) { return $false }
        $entryKeys = @($entry.Keys | ForEach-Object { [string]$_ })
        if (-not ($entryKeys -ccontains 'id') -or -not ($entryKeys -ccontains 'status')) {
            return $false
        }
        if (
            $entry.id -isnot [string] -or [string]$entry.id -notmatch '^R-[A-Z][0-9]{2,}$' -or
            $entry.status -isnot [string] -or -not ($statusOrder -ccontains [string]$entry.status)
        ) {
            return $false
        }
        if ([string]$entry.status -ceq 'DISPOSITIONED') {
            if (
                $entryKeys.Count -ne 3 -or
                -not ($entryKeys -ccontains 'reentryTrigger') -or
                $entry.reentryTrigger -isnot [string] -or
                [string]::IsNullOrWhiteSpace([string]$entry.reentryTrigger)
            ) {
                return $false
            }
        } elseif ($entryKeys.Count -ne 2) {
            return $false
        }
    }
    return (
        (Test-ExactRecordMap -Map $Record.severityCounts -Keys $severityOrder -Minimum 0) -and
        (Test-ExactRecordMap -Map $Record.statusCounts -Keys $statusOrder -Minimum 0)
    )
}

function Get-InventoryDefinitionEvents {
    param([object[]]$VisibleEntries)

    $definitions = [System.Collections.Generic.Dictionary[string,string]]::new(
        [System.StringComparer]::Ordinal
    )
    $events = [System.Collections.Generic.List[object]]::new()
    foreach ($entry in $VisibleEntries) {
        $line = [string]$entry.text
        if ($line -notmatch '^\|\s*(R-[A-Z][0-9]{2,})\s*\|\s*(Critical|High|Medium|Low)\s*\|') {
            continue
        }
        $id = [string]$Matches[1]
        $severity = [string]$Matches[2]
        if (-not $definitions.ContainsKey($id)) {
            $definitions.Add($id, $severity)
            $events.Add([pscustomobject][ordered]@{
                line = [int]$entry.line
                id = $id
                severity = $severity
            })
        } elseif ($definitions[$id] -cne $severity) {
            Add-FindingStatusIssue -Severity error -Category 'inventory-severity-conflict' `
                -Path $ledgerRelativePath `
                -Message "Finding '$id' has conflicting severity definitions '$($definitions[$id])' and '$severity'."
        }
    }
    return [pscustomobject][ordered]@{
        definitions = $definitions
        events = @($events)
    }
}

function New-ZeroCountMap {
    param([string[]]$Keys)

    $result = [ordered]@{}
    foreach ($key in $Keys) { $result[$key] = 0 }
    return $result
}

function Test-CountMap {
    param(
        [System.Collections.IDictionary]$Declared,
        [System.Collections.IDictionary]$Actual,
        [string[]]$Keys,
        [string]$Category,
        [int]$Revision
    )

    foreach ($key in $Keys) {
        if (-not $Declared.Contains($key) -or [long]$Declared[$key] -ne [long]$Actual[$key]) {
            Add-FindingStatusIssue -Severity error -Category $Category -Path $ledgerRelativePath `
                -Message "Revision $Revision declares an incorrect '$key' count."
        }
    }
}

function Get-CanonicalIndexMarker {
    param(
        [string]$LedgerVersion,
        [int]$Revision,
        [int]$InventoryCount,
        [System.Collections.IDictionary]$SeverityCounts,
        [System.Collections.IDictionary]$StatusCounts
    )

    return (
        "finding-status-index-v1; revision=$Revision; ledgerVersion=$LedgerVersion; " +
        "inventoryCount=$InventoryCount; severityCounts=" +
        "Critical:$($SeverityCounts.Critical),High:$($SeverityCounts.High)," +
        "Medium:$($SeverityCounts.Medium),Low:$($SeverityCounts.Low); statusCounts=" +
        "COMPLETED:$($StatusCounts.COMPLETED),OPEN:$($StatusCounts.OPEN)," +
        "DECIDED:$($StatusCounts.DECIDED),IN_PROGRESS:$($StatusCounts.IN_PROGRESS)," +
        "DISPOSITIONED:$($StatusCounts.DISPOSITIONED)"
    )
}

$WorkspaceRoot = Resolve-ValidationRoot -RequestedRoot $WorkspaceRoot
$ledgerPath = Join-Path $WorkspaceRoot $ledgerRelativePath
$schemaPath = Join-Path $WorkspaceRoot $schemaRelativePath
$indexPath = Join-Path $WorkspaceRoot $indexRelativePath
$historyChecked = -not [string]::IsNullOrWhiteSpace($BaseRef)
$historyValid = $true
$baseCommit = $null
$headCommit = $null
$ledgerContent = $null
$schemaContent = $null
$indexContent = $null
$baseLedgerContent = $null

if ($historyChecked) {
    $baseCommit = Get-GitCommit -Root $WorkspaceRoot -Reference $BaseRef
    $headCommit = Get-GitCommit -Root $WorkspaceRoot -Reference $HeadRef
    if (-not $baseCommit -or -not $headCommit) {
        $historyValid = $false
        Add-FindingStatusIssue -Severity error -Category 'history-ref-invalid' -Path $ledgerRelativePath `
            -Message 'BaseRef and HeadRef must both resolve to Git commits.'
    } else {
        & git -C $WorkspaceRoot merge-base --is-ancestor $baseCommit $headCommit 2>$null
        if ($LASTEXITCODE -ne 0) {
            $historyValid = $false
            Add-FindingStatusIssue -Severity error -Category 'history-range-invalid' -Path $ledgerRelativePath `
                -Message 'BaseRef must be an ancestor of HeadRef.'
        }
        try {
            $ledgerContent = Get-GitFileText -Root $WorkspaceRoot -Commit $headCommit -RelativePath $ledgerRelativePath
            $schemaContent = Get-GitFileText -Root $WorkspaceRoot -Commit $headCommit -RelativePath $schemaRelativePath
            $indexContent = Get-GitFileText -Root $WorkspaceRoot -Commit $headCommit -RelativePath $indexRelativePath
            $baseLedgerContent = Get-GitFileText -Root $WorkspaceRoot -Commit $baseCommit `
                -RelativePath $ledgerRelativePath -AllowMissing
        } catch {
            $historyValid = $false
            Add-FindingStatusIssue -Severity error -Category 'history-surface-missing' -Path $ledgerRelativePath `
                -Message $_.Exception.Message
        }
    }
} else {
    foreach ($requiredPath in @($ledgerPath, $schemaPath, $indexPath)) {
        if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
            Add-FindingStatusIssue -Severity error -Category 'status-surface-missing' -Path $requiredPath `
                -Message 'A required finding-status authority surface is missing.'
        }
    }
    if (Test-Path -LiteralPath $ledgerPath -PathType Leaf) {
        $ledgerContent = Get-Content -LiteralPath $ledgerPath -Raw
    }
    if (Test-Path -LiteralPath $schemaPath -PathType Leaf) {
        $schemaContent = Get-Content -LiteralPath $schemaPath -Raw
    }
    if (Test-Path -LiteralPath $indexPath -PathType Leaf) {
        $indexContent = Get-Content -LiteralPath $indexPath -Raw
    }
}

$records = @()
$definitionEvents = @()
$definitions = [System.Collections.Generic.Dictionary[string,string]]::new(
    [System.StringComparer]::Ordinal
)
$fold = [System.Collections.Generic.Dictionary[string,string]]::new(
    [System.StringComparer]::Ordinal
)
$latestRevision = 0
$latestLedgerVersion = $null
$latestSeverityCounts = New-ZeroCountMap -Keys $severityOrder
$latestStatusCounts = New-ZeroCountMap -Keys $statusOrder

if (
    $authorizedDispositionTriggerGroups.Count -ne 15 -or
    $authorizedDispositionTriggers.Count -ne 35 -or
    $dispositionTriggerPolicyHasDuplicateIds -or
    (Get-DispositionTriggerPolicySha256 -Map $authorizedDispositionTriggers) -cne
        $authorizedDispositionTriggerSha256
) {
    Add-FindingStatusIssue -Severity error -Category 'status-disposition-policy-invalid' `
        -Path 'studio/scripts/powershell/validate-finding-status-ledger.ps1' `
        -Message 'Disposition policy must expand fifteen owner-authorized groups into exactly 35 unique finding IDs.'
}

if ($ledgerContent -and $schemaContent) {
    $frontmatterMatch = [regex]::Match($ledgerContent, '\A---\r?\n(?<body>.*?)\r?\n---\r?\n', 'Singleline')
    $frontmatter = if ($frontmatterMatch.Success) { $frontmatterMatch.Groups['body'].Value } else { '' }
    if (-not $frontmatterMatch.Success) {
        Add-FindingStatusIssue -Severity error -Category 'status-scope-metadata' `
            -Path $ledgerRelativePath -Message 'Ledger must begin with one closed YAML frontmatter block.'
    }
    Test-GovernedFrontmatterKeys -Frontmatter $frontmatter -GovernedKeys @(
        'authority',
        'finding_status_authority',
        'finding_status_selector',
        'finding_status_schema',
        'finding_status_validator',
        'finding_status_index',
        'version'
    )
    $ledgerAuthority = Get-FrontmatterValue -Frontmatter $frontmatter -Key 'authority'
    $scopeAuthority = Get-FrontmatterValue -Frontmatter $frontmatter -Key 'finding_status_authority'
    $scopeSelector = Get-FrontmatterValue -Frontmatter $frontmatter -Key 'finding_status_selector'
    $scopeSchema = Get-FrontmatterValue -Frontmatter $frontmatter -Key 'finding_status_schema'
    $scopeValidator = Get-FrontmatterValue -Frontmatter $frontmatter -Key 'finding_status_validator'
    $scopeIndex = Get-FrontmatterValue -Frontmatter $frontmatter -Key 'finding_status_index'
    $frontmatterVersion = Get-FrontmatterValue -Frontmatter $frontmatter -Key 'version'

    if ($ledgerAuthority -cne 'informational' -or $scopeAuthority -cne 'source_of_truth' -or
        $scopeSelector -cne $selector -or $scopeSchema -cne $schemaRelativePath -or
        $scopeValidator -cne 'studio/scripts/powershell/validate-finding-status-ledger.ps1' -or
        $scopeIndex -cne $indexRelativePath) {
        Add-FindingStatusIssue -Severity error -Category 'status-scope-metadata' `
            -Path $ledgerRelativePath -Message 'Ledger finding_status scope metadata is missing or inconsistent.'
    }

    $schemaObject = $null
    try {
        $schemaObject = $schemaContent | ConvertFrom-Json -AsHashtable -ErrorAction Stop
        if ($schemaObject -isnot [System.Collections.IDictionary]) {
            throw 'Schema root is not an object.'
        }
    } catch {
        Add-FindingStatusIssue -Severity error -Category 'status-schema-invalid' -Path $schemaRelativePath `
            -Message "Finding-status schema is invalid JSON: $($_.Exception.Message)"
    }
    if ($schemaObject -is [System.Collections.IDictionary] -and
        -not (Test-FindingStatusSchemaContract -Schema $schemaObject)) {
        Add-FindingStatusIssue -Severity error -Category 'status-schema-contract' -Path $schemaRelativePath `
            -Message 'Finding-status schema must retain the exact closed record, field, enum, pattern, and count-map contract.'
    }

    $surface = Get-LedgerSurface -Content $ledgerContent
    $inventoryDefinitionSurface = Get-InventoryDefinitionEvents -VisibleEntries $surface.visibleEntries
    $definitions = $inventoryDefinitionSurface.definitions
    $definitionEvents = @($inventoryDefinitionSurface.events)
    if ($definitions.Count -eq 0) {
        Add-FindingStatusIssue -Severity error -Category 'inventory-empty' -Path $ledgerRelativePath `
            -Message 'No canonical finding severity definitions were found.'
    }
    if ($surface.blocks.Count -eq 0) {
        Add-FindingStatusIssue -Severity error -Category 'status-record-missing' -Path $ledgerRelativePath `
            -Message 'At least one visible finding-status-record-v1 block is required.'
    }

    $position = 0
    foreach ($block in @($surface.blocks)) {
        $position++
        try {
            $record = $block.payload | ConvertFrom-Json -AsHashtable -ErrorAction Stop
        } catch {
            Add-FindingStatusIssue -Severity error -Category 'status-record-json' -Path $ledgerRelativePath `
                -Message "Finding-status record at position $position is invalid JSON."
            continue
        }
        $duplicateTriggerInspectionValid = $true
        $duplicateTriggerEntryIndexes = @()
        try {
            $duplicateTriggerEntryIndexes = @(
                Get-DuplicateReentryTriggerEntryIndexes -Payload $block.payload
            )
        } catch {
            $duplicateTriggerInspectionValid = $false
            Add-FindingStatusIssue -Severity error -Category 'status-disposition-trigger-inspection' `
                -Path $ledgerRelativePath `
                -Message "Finding-status record at position $position could not be inspected for duplicate reentryTrigger properties."
        }
        $triggerContractValid = $false
        if ($duplicateTriggerInspectionValid) {
            $triggerContractValid = Test-FindingStatusTriggerContract -Record $record `
                -Position $position -DuplicateTriggerEntryIndexes $duplicateTriggerEntryIndexes
        }
        $recordContractValid = Test-FindingStatusRecordContract -Record $record
        $schemaDiagnostics = @()
        try {
            $schemaValid = Test-Json -Json $block.payload -Schema $schemaContent `
                -ErrorAction SilentlyContinue -ErrorVariable +schemaDiagnostics
        } catch {
            $schemaValid = $false
        }
        if (-not $schemaValid -or -not $recordContractValid) {
            Add-FindingStatusIssue -Severity error -Category 'status-record-schema' -Path $ledgerRelativePath `
                -Message "Finding-status record at position $position does not conform to its schema."
            if (
                $record -is [System.Collections.IDictionary] -and
                @($record.Keys | ForEach-Object { [string]$_ }) -ccontains 'recordedDate' -and
                $record.recordedDate -is [string]
            ) {
                try {
                    $null = [datetime]::ParseExact(
                        [string]$record.recordedDate,
                        'yyyy-MM-dd',
                        [System.Globalization.CultureInfo]::InvariantCulture
                    )
                } catch {
                    Add-FindingStatusIssue -Severity error -Category 'status-record-date-invalid' `
                        -Path $ledgerRelativePath `
                        -Message "Finding-status record at position $position has an impossible recordedDate."
                }
            }
            continue
        }
        if (-not $triggerContractValid) {
            continue
        }
        $records += [pscustomobject][ordered]@{
            document = $record
            raw = $block.raw
            startLine = [int]$block.startLine
        }
    }

    $expectedRevision = 1
    $previousDate = $null
    $definitionEventIndex = 0
    $definitionsAtRecord = [System.Collections.Generic.Dictionary[string,string]]::new(
        [System.StringComparer]::Ordinal
    )
    foreach ($wrappedRecord in $records) {
        $record = $wrappedRecord.document
        $revision = [int]$record.revision
        while (
            $definitionEventIndex -lt $definitionEvents.Count -and
            [int]$definitionEvents[$definitionEventIndex].line -lt [int]$wrappedRecord.startLine
        ) {
            $definitionEvent = $definitionEvents[$definitionEventIndex]
            $definitionsAtRecord[[string]$definitionEvent.id] = [string]$definitionEvent.severity
            $definitionEventIndex++
        }
        if ($revision -ne $expectedRevision) {
            Add-FindingStatusIssue -Severity error -Category 'status-revision-sequence' -Path $ledgerRelativePath `
                -Message "Expected revision $expectedRevision but found revision $revision."
        }
        if ($revision -eq 1 -and [string]$record.recordType -cne 'snapshot') {
            Add-FindingStatusIssue -Severity error -Category 'status-record-type' -Path $ledgerRelativePath `
                -Message 'Revision 1 must be a full snapshot.'
        }
        if ($revision -gt 1 -and [string]$record.recordType -cne 'delta') {
            Add-FindingStatusIssue -Severity error -Category 'status-record-type' -Path $ledgerRelativePath `
                -Message 'Revisions after revision 1 must be deltas.'
        }
        $recordDate = $null
        try {
            $recordDate = [datetime]::ParseExact(
                [string]$record.recordedDate,
                'yyyy-MM-dd',
                [System.Globalization.CultureInfo]::InvariantCulture
            )
        } catch {
            Add-FindingStatusIssue -Severity error -Category 'status-record-date-invalid' `
                -Path $ledgerRelativePath `
                -Message "Revision $revision recordedDate is not a real yyyy-MM-dd calendar date."
        }
        if ($recordDate) {
            if ($previousDate -and $recordDate -lt $previousDate) {
                Add-FindingStatusIssue -Severity error -Category 'status-record-date-order' -Path $ledgerRelativePath `
                    -Message "Revision $revision predates the preceding record."
            }
            $previousDate = $recordDate
        }

        $seenIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        foreach ($statusEntry in @($record.statuses)) {
            $id = [string]$statusEntry.id
            $status = [string]$statusEntry.status
            if (-not $seenIds.Add($id)) {
                Add-FindingStatusIssue -Severity error -Category 'status-id-duplicate' -Path $ledgerRelativePath `
                    -Message "Revision $revision contains duplicate status entries for '$id'."
                continue
            }
            if (-not $definitionsAtRecord.ContainsKey($id)) {
                Add-FindingStatusIssue -Severity error -Category 'status-id-unknown' -Path $ledgerRelativePath `
                    -Message "Revision $revision references finding '$id' before its canonical severity definition."
                continue
            }
            $fold[$id] = $status
        }

        if ($revision -eq 1) {
            $missingSnapshotIds = @($definitionsAtRecord.Keys | Where-Object { -not $seenIds.Contains($_) })
            if ($missingSnapshotIds.Count -gt 0 -or $seenIds.Count -ne $definitionsAtRecord.Count) {
                Add-FindingStatusIssue -Severity error -Category 'status-snapshot-incomplete' `
                    -Path $ledgerRelativePath `
                    -Message "Revision 1 must contain every canonical inventory ID defined before revision 1 exactly once; missing=$($missingSnapshotIds.Count)."
            }
        }

        $missingRevisionIds = @($definitionsAtRecord.Keys | Where-Object { -not $fold.ContainsKey($_) })
        $extraRevisionIds = @($fold.Keys | Where-Object { -not $definitionsAtRecord.ContainsKey($_) })
        if ($missingRevisionIds.Count -gt 0 -or $extraRevisionIds.Count -gt 0) {
            Add-FindingStatusIssue -Severity error -Category 'inventory-status-set-mismatch' `
                -Path $ledgerRelativePath `
                -Message "Revision $revision folded status set must equal definitions visible before that record; missing=$($missingRevisionIds.Count), extra=$($extraRevisionIds.Count)."
        }

        $actualSeverityCounts = New-ZeroCountMap -Keys $severityOrder
        $actualStatusCounts = New-ZeroCountMap -Keys $statusOrder
        foreach ($id in $fold.Keys) {
            if (-not $definitionsAtRecord.ContainsKey($id)) { continue }
            $actualSeverityCounts[$definitionsAtRecord[$id]]++
            $actualStatusCounts[$fold[$id]]++
        }
        if ([int]$record.inventoryCount -ne $definitionsAtRecord.Count -or $fold.Count -ne $definitionsAtRecord.Count) {
            Add-FindingStatusIssue -Severity error -Category 'inventory-count-mismatch' -Path $ledgerRelativePath `
                -Message "Revision $revision inventoryCount and folded ID count must match the definitions visible before that record."
        }
        Test-CountMap -Declared $record.severityCounts -Actual $actualSeverityCounts `
            -Keys $severityOrder -Category 'severity-count-mismatch' -Revision $revision
        Test-CountMap -Declared $record.statusCounts -Actual $actualStatusCounts `
            -Keys $statusOrder -Category 'status-count-mismatch' -Revision $revision

        $latestRevision = $revision
        $latestLedgerVersion = [string]$record.ledgerVersion
        $latestSeverityCounts = $actualSeverityCounts
        $latestStatusCounts = $actualStatusCounts
        $expectedRevision++
    }

    $missingStatusIds = @($definitions.Keys | Where-Object { -not $fold.ContainsKey($_) } | Sort-Object)
    $extraStatusIds = @($fold.Keys | Where-Object { -not $definitions.ContainsKey($_) } | Sort-Object)
    if ($missingStatusIds.Count -gt 0 -or $extraStatusIds.Count -gt 0) {
        Add-FindingStatusIssue -Severity error -Category 'inventory-status-set-mismatch' `
            -Path $ledgerRelativePath `
            -Message "Final status fold must equal the canonical inventory ID set; missing=$($missingStatusIds.Count), extra=$($extraStatusIds.Count)."
    }
    if ($records.Count -gt 0 -and $latestLedgerVersion -cne $frontmatterVersion) {
        Add-FindingStatusIssue -Severity error -Category 'ledger-version-mismatch' -Path $ledgerRelativePath `
            -Message 'Latest status record ledgerVersion must equal the ledger frontmatter version.'
    }

    if ($indexContent -and $records.Count -gt 0) {
        $expectedIndexMarker = Get-CanonicalIndexMarker -LedgerVersion $latestLedgerVersion `
            -Revision $latestRevision -InventoryCount $fold.Count `
            -SeverityCounts $latestSeverityCounts -StatusCounts $latestStatusCounts
        $indexSurface = Get-LedgerSurface -Content $indexContent -PlainMarkdown
        $visibleIndexContent = $indexSurface.visible -join "`n"
        $selectorMatches = @([regex]::Matches(
            $visibleIndexContent,
            [regex]::Escape('finding-status-index-v1')
        ))
        $ledgerRows = @($indexSurface.visible | Where-Object {
            $_.Contains('(./sdd-workspace-repair-inventory-and-update-plan-2026-07-12_zhTW.md)', [System.StringComparison]::Ordinal)
        })
        if ($selectorMatches.Count -ne 1 -or $ledgerRows.Count -ne 1 -or
            -not $ledgerRows[0].Contains($expectedIndexMarker, [System.StringComparison]::Ordinal)) {
            Add-FindingStatusIssue -Severity error -Category 'status-index-mismatch' -Path $indexRelativePath `
                -Message 'docs/README.md must contain one canonical finding-status index marker matching the latest fold.'
        }
    }

    if ($historyChecked -and $baseCommit -and $headCommit -and $baseLedgerContent) {
        $baseSurface = Get-LedgerSurface -Content $baseLedgerContent -HistorySurface
        if ($surface.blocks.Count -lt $baseSurface.blocks.Count) {
            $historyValid = $false
            Add-FindingStatusIssue -Severity error -Category 'status-history-removed' -Path $ledgerRelativePath `
                -Message 'HeadRef removes finding-status records that existed at BaseRef.'
        } else {
            for ($i = 0; $i -lt $baseSurface.blocks.Count; $i++) {
                if ([string]$baseSurface.blocks[$i].raw -cne [string]$surface.blocks[$i].raw) {
                    $historyValid = $false
                    Add-FindingStatusIssue -Severity error -Category 'status-history-rewritten' `
                        -Path $ledgerRelativePath `
                        -Message "Finding-status record $($i + 1) differs from its BaseRef bytes."
                }
            }
        }
    }
}

if ($historyChecked -and $script:errors.Count -gt 0) {
    $historyValid = $false
}

$result = [pscustomobject][ordered]@{
    VALID = ($script:errors.Count -eq 0)
    ERROR_COUNT = $script:errors.Count
    ERRORS = @($script:errors)
    WARNING_COUNT = $script:warnings.Count
    WARNINGS = @($script:warnings)
    LEDGER_PATH = $ledgerRelativePath
    SCHEMA_PATH = $schemaRelativePath
    INDEX_PATH = $indexRelativePath
    SELECTOR = $selector
    RECORD_COUNT = $records.Count
    LATEST_REVISION = $latestRevision
    FINDING_COUNT = $fold.Count
    SEVERITY_COUNTS = $latestSeverityCounts
    STATUS_COUNTS = $latestStatusCounts
    HISTORY_CHECKED = $historyChecked
    HISTORY_VALID = $historyValid
    BASE_COMMIT = $baseCommit
    HEAD_COMMIT = $headCommit
}

if ($Json) {
    $result | ConvertTo-Json -Depth 12
} else {
    Write-Output "Finding status ledger valid: $($result.VALID.ToString().ToLowerInvariant())"
    Write-Output "Findings: $($result.FINDING_COUNT); revisions: $($result.RECORD_COUNT)"
    Write-Output "Errors: $($result.ERROR_COUNT); warnings: $($result.WARNING_COUNT)"
    foreach ($issue in @($result.ERRORS)) {
        Write-Output "[ERROR] $($issue.category): $($issue.message)"
    }
}

if ($result.VALID) { exit 0 }
exit 1
