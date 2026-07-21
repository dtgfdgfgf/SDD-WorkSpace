#Requires -Version 7.0
#Requires -Module Pester

BeforeAll {
    $script:validator = Join-Path $PSScriptRoot '../scripts/powershell/validate-finding-status-ledger.ps1'
    $script:workspaceRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
    $script:ledgerRelativePath = 'docs/sdd-workspace-repair-inventory-and-update-plan-2026-07-12_zhTW.md'
    $script:schemaRelativePath = 'studio/runtime/finding-status-record.schema.json'
    $script:indexRelativePath = 'docs/README.md'
    $script:statusBlockPattern = '(?ms)^```finding-status-record-v1\r?\n(?<payload>\{.*?\})\r?\n```'
    $script:indexMarkerPattern = 'finding-status-index-v1; revision=(?<revision>\d+); ledgerVersion=(?<ledgerVersion>[^;\r\n]+); inventoryCount=(?<inventoryCount>\d+); severityCounts=Critical:(?<critical>\d+),High:(?<high>\d+),Medium:(?<medium>\d+),Low:(?<low>\d+); statusCounts=COMPLETED:(?<completed>\d+),OPEN:(?<open>\d+),DECIDED:(?<decided>\d+),IN_PROGRESS:(?<inProgress>\d+),DISPOSITIONED:(?<dispositioned>\d+)'

    function Write-FixtureText {
        param(
            [Parameter(Mandatory)] [string]$Path,
            [Parameter(Mandatory)] [AllowEmptyString()] [string]$Content
        )

        $directory = Split-Path -Parent $Path
        if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
        }
        [System.IO.File]::WriteAllText(
            $Path,
            ($Content -replace "`r`n?", "`n"),
            [System.Text.UTF8Encoding]::new($false)
        )
    }

    function New-FindingStatusFixture {
        $root = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        foreach ($relativePath in @(
            $script:ledgerRelativePath,
            $script:schemaRelativePath,
            $script:indexRelativePath
        )) {
            $sourcePath = Join-Path $script:workspaceRoot $relativePath
            $targetPath = Join-Path $root $relativePath
            $targetDirectory = Split-Path -Parent $targetPath
            New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
            Copy-Item -LiteralPath $sourcePath -Destination $targetPath
        }
        Reset-FindingStatusFixtureToRevisionOne -Root $root
        return $root
    }

    function Invoke-FindingStatusValidator {
        param(
            [Parameter(Mandatory)] [string]$Root,
            [string]$BaseRef,
            [string]$HeadRef = 'HEAD'
        )

        $arguments = @(
            '-NoLogo',
            '-NoProfile',
            '-File', $script:validator,
            '-WorkspaceRoot', $Root,
            '-Json'
        )
        if (-not [string]::IsNullOrWhiteSpace($BaseRef)) {
            $arguments += @('-BaseRef', $BaseRef, '-HeadRef', $HeadRef)
        }

        $output = @(& pwsh @arguments 2>&1)
        $exitCode = $LASTEXITCODE
        $raw = $output -join "`n"
        try {
            $data = $raw | ConvertFrom-Json -ErrorAction Stop
        } catch {
            throw "Finding-status validator did not return JSON (exit $exitCode):`n$raw"
        }

        return [pscustomobject]@{
            ExitCode = $exitCode
            Raw = $raw
            Data = $data
        }
    }

    function Get-LedgerPath {
        param([Parameter(Mandatory)] [string]$Root)
        return Join-Path $Root $script:ledgerRelativePath
    }

    function Get-IndexPath {
        param([Parameter(Mandatory)] [string]$Root)
        return Join-Path $Root $script:indexRelativePath
    }

    function Get-FindingStatusIndexMarker {
        param([Parameter(Mandatory)] [string]$Root)

        $indexText = Get-Content -LiteralPath (Get-IndexPath -Root $Root) -Raw
        $matches = @([regex]::Matches(
            $indexText,
            $script:indexMarkerPattern,
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        ))
        if ($matches.Count -ne 1) {
            throw "Expected one finding-status index marker; found $($matches.Count)."
        }
        $match = $matches[0]
        return [pscustomobject]@{
            Value = $match.Value
            Revision = [int]$match.Groups['revision'].Value
            LedgerVersion = $match.Groups['ledgerVersion'].Value
            InventoryCount = [int]$match.Groups['inventoryCount'].Value
            Critical = [int]$match.Groups['critical'].Value
            High = [int]$match.Groups['high'].Value
            Medium = [int]$match.Groups['medium'].Value
            Low = [int]$match.Groups['low'].Value
            Completed = [int]$match.Groups['completed'].Value
            Open = [int]$match.Groups['open'].Value
            Decided = [int]$match.Groups['decided'].Value
            InProgress = [int]$match.Groups['inProgress'].Value
            Dispositioned = [int]$match.Groups['dispositioned'].Value
        }
    }

    function ConvertTo-FindingStatusIndexMarker {
        param([Parameter(Mandatory)] [System.Collections.IDictionary]$Record)

        return (
            'finding-status-index-v1; revision={0}; ledgerVersion={1}; inventoryCount={2}; ' +
            'severityCounts=Critical:{3},High:{4},Medium:{5},Low:{6}; ' +
            'statusCounts=COMPLETED:{7},OPEN:{8},DECIDED:{9},IN_PROGRESS:{10},DISPOSITIONED:{11}'
        ) -f @(
            $Record.revision,
            $Record.ledgerVersion,
            $Record.inventoryCount,
            $Record.severityCounts.Critical,
            $Record.severityCounts.High,
            $Record.severityCounts.Medium,
            $Record.severityCounts.Low,
            $Record.statusCounts.COMPLETED,
            $Record.statusCounts.OPEN,
            $Record.statusCounts.DECIDED,
            $Record.statusCounts.IN_PROGRESS,
            $Record.statusCounts.DISPOSITIONED
        )
    }

    function Reset-FindingStatusFixtureToRevisionOne {
        param([Parameter(Mandatory)] [string]$Root)

        $ledgerPath = Get-LedgerPath -Root $Root
        $ledgerText = Get-Content -LiteralPath $ledgerPath -Raw
        $matches = @([regex]::Matches($ledgerText, $script:statusBlockPattern))
        if ($matches.Count -lt 1) {
            throw 'Production ledger does not contain a revision-1 status block.'
        }
        $record = $matches[0].Groups['payload'].Value | ConvertFrom-Json -AsHashtable
        if ($record.revision -ne 1 -or $record.recordType -cne 'snapshot') {
            throw 'First production status record is not the canonical revision-1 snapshot.'
        }

        for ($i = $matches.Count - 1; $i -ge 1; $i--) {
            $ledgerText = $ledgerText.Remove($matches[$i].Index, $matches[$i].Length)
        }
        $versionMatches = @([regex]::Matches($ledgerText, '(?m)^version: "[^"\r\n]+"$'))
        if ($versionMatches.Count -ne 1) {
            throw "Expected one leading ledger version field; found $($versionMatches.Count)."
        }
        $versionLine = 'version: "{0}"' -f $record.ledgerVersion
        $ledgerText = $ledgerText.Remove(
            $versionMatches[0].Index,
            $versionMatches[0].Length
        ).Insert($versionMatches[0].Index, $versionLine)
        Write-FixtureText -Path $ledgerPath -Content $ledgerText

        $indexPath = Get-IndexPath -Root $Root
        $indexText = Get-Content -LiteralPath $indexPath -Raw
        $currentMarker = Get-FindingStatusIndexMarker -Root $Root
        $revisionOneMarker = ConvertTo-FindingStatusIndexMarker -Record $record
        $updatedIndex = $indexText.Replace(
            $currentMarker.Value,
            $revisionOneMarker,
            [System.StringComparison]::Ordinal
        )
        Write-FixtureText -Path $indexPath -Content $updatedIndex
    }

    function Get-SchemaPath {
        param([Parameter(Mandatory)] [string]$Root)
        return Join-Path $Root $script:schemaRelativePath
    }

    function Update-FindingStatusSchema {
        param(
            [Parameter(Mandatory)] [string]$Root,
            [Parameter(Mandatory)] [scriptblock]$Mutation
        )

        $schemaPath = Get-SchemaPath -Root $Root
        $schema = Get-Content -LiteralPath $schemaPath -Raw | ConvertFrom-Json -AsHashtable
        & $Mutation $schema
        Write-FixtureText -Path $schemaPath -Content ($schema | ConvertTo-Json -Depth 20)
    }

    function Get-StatusBlockMatches {
        param([Parameter(Mandatory)] [string]$LedgerText)
        return @([regex]::Matches($LedgerText, $script:statusBlockPattern))
    }

    function Get-CanonicalIndexRow {
        param([Parameter(Mandatory)] [string]$IndexText)

        $rows = @($IndexText -split "`r?`n" | Where-Object {
            $_.Contains(
                '(./sdd-workspace-repair-inventory-and-update-plan-2026-07-12_zhTW.md)',
                [System.StringComparison]::Ordinal
            )
        })
        if ($rows.Count -ne 1) {
            throw "Expected one canonical finding-status index row; found $($rows.Count)."
        }
        return [string]$rows[0]
    }

    function ConvertTo-HiddenMarkdownSurface {
        param(
            [Parameter(Mandatory)] [string]$Surface,
            [Parameter(Mandatory)] [string]$Kind
        )

        switch ($Kind) {
            'html-comment' { return "<!--`n$Surface`n-->" }
            'ordinary-fence' { return ('```text' + "`n$Surface`n" + '```') }
            'tilde-fence' { return ('~~~text' + "`n$Surface`n" + '~~~') }
            'long-fence' { return ('````text' + "`n$Surface`n" + '````') }
            'four-space-indent' {
                return (($Surface -split "`r?`n" | ForEach-Object { "    $_" }) -join "`n")
            }
            'tab-indent' {
                return (($Surface -split "`r?`n" | ForEach-Object { "`t$_" }) -join "`n")
            }
            'script' { return "<script>`n$Surface`n</script>" }
            'pre' { return "<pre>`n$Surface`n</pre>" }
            'style' { return "<style>`n$Surface`n</style>" }
            'textarea' { return "<textarea>`n$Surface`n</textarea>" }
            'generic-html' { return "<div>`n$Surface`n</div>`n" }
            default { throw "Unknown hidden Markdown surface kind '$Kind'." }
        }
    }

    function ConvertTo-StatusBlock {
        param([Parameter(Mandatory)] [System.Collections.IDictionary]$Record)

        $payload = $Record | ConvertTo-Json -Depth 12
        return ('```finding-status-record-v1' + "`n" + ($payload -replace "`r`n?", "`n") + "`n" + '```')
    }

    function Update-RevisionOne {
        param(
            [Parameter(Mandatory)] [string]$Root,
            [Parameter(Mandatory)] [scriptblock]$Mutation
        )

        $ledgerPath = Get-LedgerPath -Root $Root
        $ledgerText = Get-Content -LiteralPath $ledgerPath -Raw
        $match = [regex]::Match($ledgerText, $script:statusBlockPattern)
        if (-not $match.Success) {
            throw 'Fixture does not contain the revision-1 status block.'
        }
        $record = $match.Groups['payload'].Value | ConvertFrom-Json -AsHashtable
        & $Mutation $record
        $replacement = ConvertTo-StatusBlock -Record $record
        $updated = $ledgerText.Remove($match.Index, $match.Length).Insert($match.Index, $replacement)
        Write-FixtureText -Path $ledgerPath -Content $updated
    }

    function Add-RevisionTwo {
        param([Parameter(Mandatory)] [string]$Root)

        $ledgerPath = Get-LedgerPath -Root $Root
        $ledgerText = Get-Content -LiteralPath $ledgerPath -Raw
        $matches = Get-StatusBlockMatches -LedgerText $ledgerText
        if ($matches.Count -ne 1) {
            throw "Expected one status block before appending revision 2; found $($matches.Count)."
        }

        $record = [ordered]@{
            schemaVersion = 1
            revision = 2
            recordType = 'delta'
            recordedDate = '2026-07-22'
            ledgerVersion = '1.29.0'
            statuses = @(
                [ordered]@{ id = 'R-E11'; status = 'OPEN' }
            )
            inventoryCount = 131
            severityCounts = [ordered]@{
                Critical = 8
                High = 32
                Medium = 52
                Low = 39
            }
            statusCounts = [ordered]@{
                COMPLETED = 76
                OPEN = 48
                DECIDED = 6
                IN_PROGRESS = 1
                DISPOSITIONED = 0
            }
        }
        $block = ConvertTo-StatusBlock -Record $record
        $insertAt = $matches[0].Index + $matches[0].Length
        $updatedLedger = $ledgerText.Insert($insertAt, "`n$block")
        Write-FixtureText -Path $ledgerPath -Content $updatedLedger

        $indexPath = Get-IndexPath -Root $Root
        $indexText = Get-Content -LiteralPath $indexPath -Raw
        $updatedIndex = $indexText.Replace(
            'finding-status-index-v1; revision=1;',
            'finding-status-index-v1; revision=2;'
        )
        if ($updatedIndex -ceq $indexText) {
            throw 'Fixture status index did not contain the revision-1 marker.'
        }
        Write-FixtureText -Path $indexPath -Content $updatedIndex
    }

    function Add-NoOpDeltaRecord {
        param(
            [Parameter(Mandatory)] [string]$Root,
            [Parameter(Mandatory)] [int]$Revision,
            [string]$RecordedDate = '2026-07-23'
        )

        $record = [ordered]@{
            schemaVersion = 1
            revision = $Revision
            recordType = 'delta'
            recordedDate = $RecordedDate
            ledgerVersion = '1.29.0'
            statuses = @([ordered]@{ id = 'R-E11'; status = 'OPEN' })
            inventoryCount = 131
            severityCounts = [ordered]@{ Critical = 8; High = 32; Medium = 52; Low = 39 }
            statusCounts = [ordered]@{
                COMPLETED = 76
                OPEN = 48
                DECIDED = 6
                IN_PROGRESS = 1
                DISPOSITIONED = 0
            }
        }
        $ledgerPath = Get-LedgerPath -Root $Root
        $ledgerText = Get-Content -Raw -LiteralPath $ledgerPath
        Write-FixtureText -Path $ledgerPath -Content ($ledgerText + "`n" + (ConvertTo-StatusBlock -Record $record) + "`n")
    }

    function Add-NewFindingRevision {
        param([Parameter(Mandatory)] [string]$Root)

        $ledgerPath = Get-LedgerPath -Root $Root
        $ledgerText = Get-Content -Raw -LiteralPath $ledgerPath
        $ledgerText = $ledgerText.Replace('version: "1.29.0"', 'version: "1.30.0"', [System.StringComparison]::Ordinal)
        $record = [ordered]@{
            schemaVersion = 1
            revision = 2
            recordType = 'delta'
            recordedDate = '2026-07-22'
            ledgerVersion = '1.30.0'
            statuses = @([ordered]@{ id = 'R-K100'; status = 'OPEN' })
            inventoryCount = 132
            severityCounts = [ordered]@{ Critical = 8; High = 32; Medium = 52; Low = 40 }
            statusCounts = [ordered]@{
                COMPLETED = 76
                OPEN = 49
                DECIDED = 6
                IN_PROGRESS = 1
                DISPOSITIONED = 0
            }
        }
        $append = @(
            '',
            '| R-K100 | Low | Future append-only finding fixture | New definition before delta |',
            '',
            (ConvertTo-StatusBlock -Record $record),
            ''
        ) -join "`n"
        Write-FixtureText -Path $ledgerPath -Content ($ledgerText + $append)

        $indexPath = Get-IndexPath -Root $Root
        $indexText = Get-Content -Raw -LiteralPath $indexPath
        $oldMarker = 'finding-status-index-v1; revision=1; ledgerVersion=1.29.0; inventoryCount=131; severityCounts=Critical:8,High:32,Medium:52,Low:39; statusCounts=COMPLETED:76,OPEN:48,DECIDED:6,IN_PROGRESS:1,DISPOSITIONED:0'
        $newMarker = 'finding-status-index-v1; revision=2; ledgerVersion=1.30.0; inventoryCount=132; severityCounts=Critical:8,High:32,Medium:52,Low:40; statusCounts=COMPLETED:76,OPEN:49,DECIDED:6,IN_PROGRESS:1,DISPOSITIONED:0'
        $updatedIndex = $indexText.Replace($oldMarker, $newMarker, [System.StringComparison]::Ordinal)
        $updatedIndex | Should -Not -BeExactly $indexText
        Write-FixtureText -Path $indexPath -Content $updatedIndex
    }

    function Invoke-FixtureGit {
        param(
            [Parameter(Mandatory)] [string]$Root,
            [Parameter(Mandatory)] [string[]]$Arguments
        )

        $output = @(& git -C $Root @Arguments 2>&1)
        if ($LASTEXITCODE -ne 0) {
            throw "Fixture git failed: git $($Arguments -join ' ')`n$($output -join "`n")"
        }
        return @($output)
    }

    function Initialize-FixtureGit {
        param([Parameter(Mandatory)] [string]$Root)

        Invoke-FixtureGit -Root $Root -Arguments @('init', '--quiet') | Out-Null
        Invoke-FixtureGit -Root $Root -Arguments @('config', 'user.name', 'Finding Status Test') | Out-Null
        Invoke-FixtureGit -Root $Root -Arguments @('config', 'user.email', 'finding-status@example.invalid') | Out-Null
        Invoke-FixtureGit -Root $Root -Arguments @('config', 'core.autocrlf', 'false') | Out-Null
        return Complete-FixtureCommit -Root $Root -Message 'base'
    }

    function Complete-FixtureCommit {
        param(
            [Parameter(Mandatory)] [string]$Root,
            [Parameter(Mandatory)] [string]$Message
        )

        Invoke-FixtureGit -Root $Root -Arguments @('add', '-A') | Out-Null
        Invoke-FixtureGit -Root $Root -Arguments @('commit', '--quiet', '-m', $Message) | Out-Null
        $revision = @(Invoke-FixtureGit -Root $Root -Arguments @('rev-parse', 'HEAD'))
        return ([string]$revision[-1]).Trim()
    }

    function Get-ErrorCategories {
        param([Parameter(Mandatory)] [object]$Result)
        return @($Result.Data.ERRORS | ForEach-Object { [string]$_.category })
    }
}

Describe 'validate-finding-status-ledger production snapshot' {
    It 'accepts the canonical production fold and matches the machine index' {
        $expected = Get-FindingStatusIndexMarker -Root $script:workspaceRoot
        $result = Invoke-FindingStatusValidator -Root $script:workspaceRoot

        $result.ExitCode | Should -Be 0
        $result.Data.VALID | Should -BeTrue
        $result.Data.ERROR_COUNT | Should -Be 0
        $result.Data.WARNING_COUNT | Should -Be 0
        $result.Data.RECORD_COUNT | Should -Be $expected.Revision
        $result.Data.LATEST_REVISION | Should -Be $expected.Revision
        $result.Data.FINDING_COUNT | Should -Be $expected.InventoryCount
        $result.Data.SEVERITY_COUNTS.Critical | Should -Be $expected.Critical
        $result.Data.SEVERITY_COUNTS.High | Should -Be $expected.High
        $result.Data.SEVERITY_COUNTS.Medium | Should -Be $expected.Medium
        $result.Data.SEVERITY_COUNTS.Low | Should -Be $expected.Low
        $result.Data.STATUS_COUNTS.COMPLETED | Should -Be $expected.Completed
        $result.Data.STATUS_COUNTS.OPEN | Should -Be $expected.Open
        $result.Data.STATUS_COUNTS.DECIDED | Should -Be $expected.Decided
        $result.Data.STATUS_COUNTS.IN_PROGRESS | Should -Be $expected.InProgress
        $result.Data.STATUS_COUNTS.DISPOSITIONED | Should -Be $expected.Dispositioned
    }
}

Describe 'validate-finding-status-ledger authority and fold tampering' {
    It 'fails closed with structured JSON when a required surface is missing: <Label>' -TestCases @(
        @{ Label = 'ledger'; RelativePath = 'docs/sdd-workspace-repair-inventory-and-update-plan-2026-07-12_zhTW.md' }
        @{ Label = 'schema'; RelativePath = 'studio/runtime/finding-status-record.schema.json' }
        @{ Label = 'index'; RelativePath = 'docs/README.md' }
    ) {
        param($Label, $RelativePath)

        $root = New-FindingStatusFixture
        Remove-Item -LiteralPath (Join-Path $root $RelativePath) -Force

        $result = Invoke-FindingStatusValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Data.VALID | Should -BeFalse
        Get-ErrorCategories -Result $result | Should -Contain 'status-surface-missing'
    }

    It 'requires scope metadata in the true leading frontmatter and rejects a body spoof' {
        $root = New-FindingStatusFixture
        $ledgerPath = Get-LedgerPath -Root $root
        $ledgerText = Get-Content -LiteralPath $ledgerPath -Raw
        $metadataLine = [regex]::new('(?m)^finding_status_authority: "source_of_truth"\r?\n')
        $tampered = $metadataLine.Replace($ledgerText, '', 1)
        $tampered += "`nfinding_status_authority: `"source_of_truth`"`n"
        Write-FixtureText -Path $ledgerPath -Content $tampered

        $result = Invoke-FindingStatusValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Data.VALID | Should -BeFalse
        Get-ErrorCategories -Result $result | Should -Contain 'status-scope-metadata'
    }

    It 'rejects a mixed quoted and unquoted duplicate frontmatter key' {
        $root = New-FindingStatusFixture
        $ledgerPath = Get-LedgerPath -Root $root
        $ledgerText = Get-Content -Raw -LiteralPath $ledgerPath
        $tampered = $ledgerText.Replace(
            'finding_status_authority: "source_of_truth"',
            "finding_status_authority: `"source_of_truth`"`nfinding_status_authority: source_of_truth",
            [System.StringComparison]::Ordinal
        )
        Write-FixtureText -Path $ledgerPath -Content $tampered

        $result = Invoke-FindingStatusValidator -Root $root

        $result.ExitCode | Should -Be 1
        Get-ErrorCategories -Result $result | Should -Contain 'status-scope-metadata'
    }

    It 'rejects a conflicting governed frontmatter key with quoted or alternate spelling: <Label>' -TestCases @(
        @{ Label = 'quoted key'; Declaration = '"authority": "source_of_truth"' }
        @{ Label = 'alternate spelling'; Declaration = 'Finding-Status-Authority: "source_of_truth"' }
    ) {
        param($Label, $Declaration)

        $root = New-FindingStatusFixture
        $ledgerPath = Get-LedgerPath -Root $root
        $ledgerText = Get-Content -Raw -LiteralPath $ledgerPath
        $tampered = $ledgerText.Replace(
            'authority: "informational"',
            "authority: `"informational`"`n$Declaration",
            [System.StringComparison]::Ordinal
        )
        Write-FixtureText -Path $ledgerPath -Content $tampered

        $result = Invoke-FindingStatusValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Data.VALID | Should -BeFalse
        Get-ErrorCategories -Result $result | Should -Contain 'status-scope-metadata'
    }

    It 'rejects removal of required schemaVersion paired with a record that omits schemaVersion' {
        $root = New-FindingStatusFixture
        Update-FindingStatusSchema -Root $root -Mutation {
            param($schema)
            $schema.required = @($schema.required | Where-Object { $_ -cne 'schemaVersion' })
        }
        Update-RevisionOne -Root $root -Mutation {
            param($record)
            $null = $record.Remove('schemaVersion')
        }

        $result = Invoke-FindingStatusValidator -Root $root
        $categories = Get-ErrorCategories -Result $result

        $result.ExitCode | Should -Be 1
        $result.Data.VALID | Should -BeFalse
        $categories | Should -Contain 'status-schema-contract'
        $categories | Should -Contain 'status-record-schema'
    }

    It 'rejects a numeric field widened to string in both schema and record' {
        $root = New-FindingStatusFixture
        Update-FindingStatusSchema -Root $root -Mutation {
            param($schema)
            $schema.properties.revision.type = 'string'
            $null = $schema.properties.revision.Remove('minimum')
        }
        Update-RevisionOne -Root $root -Mutation {
            param($record)
            $record.revision = '1'
        }

        $result = Invoke-FindingStatusValidator -Root $root
        $categories = Get-ErrorCategories -Result $result

        $result.ExitCode | Should -Be 1
        $result.Data.VALID | Should -BeFalse
        $categories | Should -Contain 'status-schema-contract'
        $categories | Should -Contain 'status-record-schema'
    }

    It 'rejects additionalProperties true paired with an unknown record field' {
        $root = New-FindingStatusFixture
        Update-FindingStatusSchema -Root $root -Mutation {
            param($schema)
            $schema.additionalProperties = $true
        }
        Update-RevisionOne -Root $root -Mutation {
            param($record)
            $record.unexpectedAuthority = 'spoof'
        }

        $result = Invoke-FindingStatusValidator -Root $root
        $categories = Get-ErrorCategories -Result $result

        $result.ExitCode | Should -Be 1
        $result.Data.VALID | Should -BeFalse
        $categories | Should -Contain 'status-schema-contract'
        $categories | Should -Contain 'status-record-schema'
    }

    It 'rejects an unexpected root schema keyword instead of accepting a widened schema surface' {
        $root = New-FindingStatusFixture
        Update-FindingStatusSchema -Root $root -Mutation {
            param($schema)
            $schema['description'] = 'Fixture-only widened schema surface'
        }

        $result = Invoke-FindingStatusValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Data.VALID | Should -BeFalse
        Get-ErrorCategories -Result $result | Should -Contain 'status-schema-contract'
    }

    It 'requires revision 1 to be complete even when revision 2 restores the omitted ID' {
        $root = New-FindingStatusFixture
        Update-RevisionOne -Root $root -Mutation {
            param($record)
            $record.statuses = @($record.statuses | Where-Object { $_.id -cne 'R-J03' })
            $record.inventoryCount = 130
            $record.severityCounts['High'] = 31
            $record.statusCounts['OPEN'] = 47
        }
        Add-RevisionTwo -Root $root

        $ledgerPath = Get-LedgerPath -Root $root
        $ledgerText = Get-Content -LiteralPath $ledgerPath -Raw
        $matches = Get-StatusBlockMatches -LedgerText $ledgerText
        $revisionTwo = $matches[1].Groups['payload'].Value | ConvertFrom-Json -AsHashtable
        $revisionTwo.statuses = @([ordered]@{ id = 'R-J03'; status = 'OPEN' })
        $replacement = ConvertTo-StatusBlock -Record $revisionTwo
        $updated = $ledgerText.Remove($matches[1].Index, $matches[1].Length).Insert($matches[1].Index, $replacement)
        Write-FixtureText -Path $ledgerPath -Content $updated

        $result = Invoke-FindingStatusValidator -Root $root

        $result.ExitCode | Should -Be 1
        Get-ErrorCategories -Result $result | Should -Contain 'status-snapshot-incomplete'
        $result.Data.FINDING_COUNT | Should -Be 131
    }

    It 'returns structured date errors for an impossible calendar date' {
        $root = New-FindingStatusFixture
        Update-RevisionOne -Root $root -Mutation {
            param($record)
            $record.recordedDate = '2026-02-30'
        }

        $result = Invoke-FindingStatusValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Data | Should -Not -BeNullOrEmpty
        Get-ErrorCategories -Result $result | Should -Contain 'status-record-date-invalid'
    }

    It 'rejects a first status record that starts at revision 2' {
        $root = New-FindingStatusFixture
        Update-RevisionOne -Root $root -Mutation {
            param($record)
            $record.revision = 2
            $record.recordType = 'delta'
        }

        $result = Invoke-FindingStatusValidator -Root $root

        $result.ExitCode | Should -Be 1
        Get-ErrorCategories -Result $result | Should -Contain 'status-revision-sequence'
    }

    It 'rejects a duplicate revision number' {
        $root = New-FindingStatusFixture
        Add-NoOpDeltaRecord -Root $root -Revision 1

        $result = Invoke-FindingStatusValidator -Root $root

        $result.ExitCode | Should -Be 1
        Get-ErrorCategories -Result $result | Should -Contain 'status-revision-sequence'
    }

    It 'rejects a nonconsecutive revision number' {
        $root = New-FindingStatusFixture
        Add-NoOpDeltaRecord -Root $root -Revision 3

        $result = Invoke-FindingStatusValidator -Root $root

        $result.ExitCode | Should -Be 1
        Get-ErrorCategories -Result $result | Should -Contain 'status-revision-sequence'
    }

    It 'rejects out-of-order revision records' {
        $root = New-FindingStatusFixture
        Add-NoOpDeltaRecord -Root $root -Revision 3 -RecordedDate '2026-07-23'
        Add-NoOpDeltaRecord -Root $root -Revision 2 -RecordedDate '2026-07-24'

        $result = Invoke-FindingStatusValidator -Root $root

        $result.ExitCode | Should -Be 1
        Get-ErrorCategories -Result $result | Should -Contain 'status-revision-sequence'
    }

    It 'requires a new finding definition to precede the delta that first assigns its status' {
        $root = New-FindingStatusFixture
        Add-NewFindingRevision -Root $root
        $ledgerPath = Get-LedgerPath -Root $root
        $ledgerText = Get-Content -Raw -LiteralPath $ledgerPath
        $definitionLine = '| R-K100 | Low | Future append-only finding fixture | New definition before delta |'
        $withoutDefinition = $ledgerText.Replace("$definitionLine`n", '', [System.StringComparison]::Ordinal)
        Write-FixtureText -Path $ledgerPath -Content ($withoutDefinition + "`n$definitionLine`n")

        $result = Invoke-FindingStatusValidator -Root $root

        $result.ExitCode | Should -Be 1
        Get-ErrorCategories -Result $result | Should -Contain 'status-id-unknown'
    }

    It 'rejects duplicate finding IDs within one revision' {
        $root = New-FindingStatusFixture
        Update-RevisionOne -Root $root -Mutation {
            param($record)
            $record.statuses = @($record.statuses) + @([ordered]@{ id = 'R-A01'; status = 'COMPLETED' })
        }

        $result = Invoke-FindingStatusValidator -Root $root

        $result.ExitCode | Should -Be 1
        Get-ErrorCategories -Result $result | Should -Contain 'status-id-duplicate'
    }

    It 'rejects a schema-invalid status value: <Label>' -TestCases @(
        @{ Label = 'wrong type'; Value = 17 }
        @{ Label = 'null'; Value = $null }
        @{ Label = 'unknown enum'; Value = 'READY' }
    ) {
        param($Label, $Value)

        $root = New-FindingStatusFixture
        Update-RevisionOne -Root $root -Mutation {
            param($record)
            $record.statuses[0]['status'] = $Value
        }

        $result = Invoke-FindingStatusValidator -Root $root

        $result.ExitCode | Should -Be 1
        Get-ErrorCategories -Result $result | Should -Contain 'status-record-schema'
    }

    It 'rejects declared inventory, severity, and status count mismatches' {
        $root = New-FindingStatusFixture
        Update-RevisionOne -Root $root -Mutation {
            param($record)
            $record.inventoryCount = 130
            $record.severityCounts['Critical'] = 7
            $record.statusCounts['OPEN'] = 47
        }

        $result = Invoke-FindingStatusValidator -Root $root
        $categories = Get-ErrorCategories -Result $result

        $result.ExitCode | Should -Be 1
        $categories | Should -Contain 'inventory-count-mismatch'
        $categories | Should -Contain 'severity-count-mismatch'
        $categories | Should -Contain 'status-count-mismatch'
    }

    It 'rejects a final fold that omits a canonical finding ID' {
        $root = New-FindingStatusFixture
        Update-RevisionOne -Root $root -Mutation {
            param($record)
            $record.statuses = @($record.statuses | Where-Object { $_.id -cne 'R-J03' })
        }

        $result = Invoke-FindingStatusValidator -Root $root

        $result.ExitCode | Should -Be 1
        Get-ErrorCategories -Result $result | Should -Contain 'inventory-status-set-mismatch'
    }

    It 'rejects a docs index marker that disagrees with the latest fold' {
        $root = New-FindingStatusFixture
        $indexPath = Get-IndexPath -Root $root
        $indexText = Get-Content -LiteralPath $indexPath -Raw
        $tampered = $indexText.Replace('inventoryCount=131;', 'inventoryCount=130;')
        $tampered | Should -Not -BeExactly $indexText
        Write-FixtureText -Path $indexPath -Content $tampered

        $result = Invoke-FindingStatusValidator -Root $root

        $result.ExitCode | Should -Be 1
        Get-ErrorCategories -Result $result | Should -Contain 'status-index-mismatch'
    }
}

Describe 'validate-finding-status-ledger inventory and selector boundaries' {
    It 'rejects a canonical status record hidden from the visible Markdown surface: <Label>' -TestCases @(
        @{ Label = 'HTML comment'; Kind = 'html-comment' }
        @{ Label = 'ordinary fence'; Kind = 'ordinary-fence' }
        @{ Label = 'tilde fence'; Kind = 'tilde-fence' }
        @{ Label = 'long fence'; Kind = 'long-fence' }
        @{ Label = 'four-space indented code'; Kind = 'four-space-indent' }
        @{ Label = 'tab-indented code'; Kind = 'tab-indent' }
        @{ Label = 'script raw HTML'; Kind = 'script' }
        @{ Label = 'pre raw HTML'; Kind = 'pre' }
        @{ Label = 'style raw HTML'; Kind = 'style' }
        @{ Label = 'textarea raw HTML'; Kind = 'textarea' }
        @{ Label = 'generic raw HTML'; Kind = 'generic-html' }
    ) {
        param($Label, $Kind)

        $root = New-FindingStatusFixture
        $ledgerPath = Get-LedgerPath -Root $root
        $ledgerText = Get-Content -LiteralPath $ledgerPath -Raw
        $match = [regex]::Match($ledgerText, $script:statusBlockPattern)
        $match.Success | Should -BeTrue
        $hidden = ConvertTo-HiddenMarkdownSurface -Surface $match.Value -Kind $Kind
        $tampered = $ledgerText.Remove($match.Index, $match.Length).Insert($match.Index, $hidden)
        Write-FixtureText -Path $ledgerPath -Content $tampered

        $result = Invoke-FindingStatusValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Data.VALID | Should -BeFalse
        $result.Data.RECORD_COUNT | Should -Be 0
        Get-ErrorCategories -Result $result | Should -Contain 'status-record-missing'
    }

    It 'rejects a visible exact-selector lookalike envelope: <Label>' -TestCases @(
        @{ Label = 'four backticks'; Marker = '````'; Info = 'finding-status-record-v1' }
        @{ Label = 'tilde'; Marker = '~~~'; Info = 'finding-status-record-v1' }
        @{ Label = 'leading space'; Marker = '```'; Info = ' finding-status-record-v1' }
        @{ Label = 'leading tab'; Marker = '```'; Info = "`tfinding-status-record-v1" }
        @{ Label = 'trailing space'; Marker = '```'; Info = 'finding-status-record-v1 ' }
    ) {
        param($Label, $Marker, $Info)

        $root = New-FindingStatusFixture
        $ledgerPath = Get-LedgerPath -Root $root
        $ledgerText = Get-Content -LiteralPath $ledgerPath -Raw
        $match = [regex]::Match($ledgerText, $script:statusBlockPattern)
        $match.Success | Should -BeTrue
        $lookalike = $Marker + $Info + "`n" +
            $match.Groups['payload'].Value + "`n" + $Marker
        $tampered = $ledgerText.Remove($match.Index, $match.Length).Insert($match.Index, $lookalike)
        Write-FixtureText -Path $ledgerPath -Content $tampered

        $result = Invoke-FindingStatusValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Data.VALID | Should -BeFalse
        $result.Data.RECORD_COUNT | Should -Be 0
        Get-ErrorCategories -Result $result | Should -Contain 'status-record-envelope-invalid'
    }

    It 'accepts a canonical three-backtick opening with a longer closing fence' {
        $root = New-FindingStatusFixture
        $ledgerPath = Get-LedgerPath -Root $root
        $ledgerText = Get-Content -LiteralPath $ledgerPath -Raw
        $match = [regex]::Match($ledgerText, $script:statusBlockPattern)
        $match.Success | Should -BeTrue
        $replacement = $match.Value.Substring(0, $match.Value.Length - 3) + '````'
        $tampered = $ledgerText.Remove($match.Index, $match.Length).Insert($match.Index, $replacement)
        Write-FixtureText -Path $ledgerPath -Content $tampered

        $result = Invoke-FindingStatusValidator -Root $root

        $result.ExitCode | Should -Be 0 -Because $result.Raw
        $result.Data.VALID | Should -BeTrue
        $result.Data.RECORD_COUNT | Should -Be 1
    }

    It 'ignores an exact-selector lookalike envelope inside an HTML comment: <Label>' -TestCases @(
        @{ Label = 'four backticks'; Marker = '````' }
        @{ Label = 'tilde'; Marker = '~~~' }
    ) {
        param($Label, $Marker)

        $root = New-FindingStatusFixture
        $ledgerPath = Get-LedgerPath -Root $root
        $ledgerText = Get-Content -LiteralPath $ledgerPath -Raw
        $lookalike = "<!--`n$Marker" + 'finding-status-record-v1' + "`n{}`n$Marker`n-->"
        Write-FixtureText -Path $ledgerPath -Content ($ledgerText + "`n$lookalike`n")

        $result = Invoke-FindingStatusValidator -Root $root

        $result.ExitCode | Should -Be 0 -Because $result.Raw
        $result.Data.VALID | Should -BeTrue
        $result.Data.RECORD_COUNT | Should -Be 1
        Get-ErrorCategories -Result $result | Should -Not -Contain 'status-record-envelope-invalid'
    }

    It 'rejects a canonical docs index row hidden from the visible Markdown surface: <Label>' -TestCases @(
        @{ Label = 'HTML comment'; Kind = 'html-comment' }
        @{ Label = 'ordinary fence'; Kind = 'ordinary-fence' }
        @{ Label = 'tilde fence'; Kind = 'tilde-fence' }
        @{ Label = 'long fence'; Kind = 'long-fence' }
        @{ Label = 'four-space indented code'; Kind = 'four-space-indent' }
        @{ Label = 'tab-indented code'; Kind = 'tab-indent' }
        @{ Label = 'script raw HTML'; Kind = 'script' }
        @{ Label = 'pre raw HTML'; Kind = 'pre' }
        @{ Label = 'style raw HTML'; Kind = 'style' }
        @{ Label = 'textarea raw HTML'; Kind = 'textarea' }
        @{ Label = 'generic raw HTML'; Kind = 'generic-html' }
    ) {
        param($Label, $Kind)

        $root = New-FindingStatusFixture
        $indexPath = Get-IndexPath -Root $root
        $indexText = Get-Content -LiteralPath $indexPath -Raw
        $canonicalRow = Get-CanonicalIndexRow -IndexText $indexText
        $hidden = ConvertTo-HiddenMarkdownSurface -Surface $canonicalRow -Kind $Kind
        $tampered = $indexText.Replace($canonicalRow, $hidden, [System.StringComparison]::Ordinal)
        $tampered | Should -Not -BeExactly $indexText
        Write-FixtureText -Path $indexPath -Content $tampered

        $result = Invoke-FindingStatusValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Data.VALID | Should -BeFalse
        Get-ErrorCategories -Result $result | Should -Contain 'status-index-mismatch'
    }

    It 'rejects duplicate visible canonical docs index rows' {
        $root = New-FindingStatusFixture
        $indexPath = Get-IndexPath -Root $root
        $indexText = Get-Content -LiteralPath $indexPath -Raw
        $canonicalRow = Get-CanonicalIndexRow -IndexText $indexText
        Write-FixtureText -Path $indexPath -Content ($indexText + "`n$canonicalRow`n")

        $result = Invoke-FindingStatusValidator -Root $root

        $result.ExitCode | Should -Be 1
        $result.Data.VALID | Should -BeFalse
        Get-ErrorCategories -Result $result | Should -Contain 'status-index-mismatch'
    }

    It 'ignores a hidden duplicate canonical docs index row' {
        $root = New-FindingStatusFixture
        $indexPath = Get-IndexPath -Root $root
        $indexText = Get-Content -LiteralPath $indexPath -Raw
        $canonicalRow = Get-CanonicalIndexRow -IndexText $indexText
        $hiddenDuplicate = ConvertTo-HiddenMarkdownSurface -Surface $canonicalRow -Kind 'generic-html'
        Write-FixtureText -Path $indexPath -Content ($indexText + "`n$hiddenDuplicate`n")

        $result = Invoke-FindingStatusValidator -Root $root

        $result.ExitCode | Should -Be 0 -Because $result.Raw
        $result.Data.VALID | Should -BeTrue
        $result.Data.RECORD_COUNT | Should -Be 1
    }

    It 'allows a later visible repeat of the canonical severity' {
        $root = New-FindingStatusFixture
        $ledgerPath = Get-LedgerPath -Root $root
        $ledgerText = Get-Content -LiteralPath $ledgerPath -Raw
        $ledgerText += "`n| R-B10 | Medium | historical repeat | unchanged |`n"
        Write-FixtureText -Path $ledgerPath -Content $ledgerText

        $result = Invoke-FindingStatusValidator -Root $root

        $result.ExitCode | Should -Be 0
        $result.Data.VALID | Should -BeTrue
    }

    It 'rejects a later visible severity that conflicts with the canonical definition' {
        $root = New-FindingStatusFixture
        $ledgerPath = Get-LedgerPath -Root $root
        $ledgerText = Get-Content -LiteralPath $ledgerPath -Raw
        $ledgerText += "`n| R-B10 | High | conflicting repeat | tampered |`n"
        Write-FixtureText -Path $ledgerPath -Content $ledgerText

        $result = Invoke-FindingStatusValidator -Root $root

        $result.ExitCode | Should -Be 1
        Get-ErrorCategories -Result $result | Should -Contain 'inventory-severity-conflict'
    }

    It 'ignores a non-authoritative record surface: <Label>' -TestCases @(
        @{
            Label = 'HTML-commented exact selector'
            Surface = @'
<!--
```finding-status-record-v1
{"schemaVersion":"spoof"}
```
-->
'@
        }
        @{
            Label = 'wrong fence selector'
            Surface = @'
```finding-status-record-v2
{"schemaVersion":"spoof"}
```
'@
        }
        @{
            Label = 'generic raw HTML hides a long exact-selector lookalike'
            Surface = @'
<div>
````finding-status-record-v1
{"schemaVersion":"spoof"}
````
</div>

'@
        }
        @{
            Label = 'ordinary fence hides a tilde exact-selector lookalike'
            Surface = @'
```text
~~~finding-status-record-v1
{"schemaVersion":"spoof"}
~~~
```
'@
        }
    ) {
        param($Label, $Surface)

        $root = New-FindingStatusFixture
        $ledgerPath = Get-LedgerPath -Root $root
        $ledgerText = Get-Content -LiteralPath $ledgerPath -Raw
        Write-FixtureText -Path $ledgerPath -Content ($ledgerText + "`n" + $Surface)

        $result = Invoke-FindingStatusValidator -Root $root

        $result.ExitCode | Should -Be 0
        $result.Data.VALID | Should -BeTrue
        $result.Data.RECORD_COUNT | Should -Be 1
        $result.Data.LATEST_REVISION | Should -Be 1
    }
}

Describe 'validate-finding-status-ledger append-only Git history' {
    It 'accepts a new extensible finding definition followed by revision 2 without rewriting revision 1' {
        $root = New-FindingStatusFixture
        $baseCommit = Initialize-FixtureGit -Root $root
        Add-NewFindingRevision -Root $root
        Complete-FixtureCommit -Root $root -Message 'append new finding and revision 2' | Out-Null

        $result = Invoke-FindingStatusValidator -Root $root -BaseRef $baseCommit

        $result.ExitCode | Should -Be 0 -Because $result.Raw
        $result.Data.VALID | Should -BeTrue
        $result.Data.HISTORY_VALID | Should -BeTrue
        $result.Data.RECORD_COUNT | Should -Be 2
        $result.Data.LATEST_REVISION | Should -Be 2
        $result.Data.FINDING_COUNT | Should -Be 132
        $result.Data.SEVERITY_COUNTS.Low | Should -Be 40
        $result.Data.STATUS_COUNTS.OPEN | Should -Be 49
    }

    It 'accepts an appended valid delta while preserving the BaseRef record prefix' {
        $root = New-FindingStatusFixture
        $baseCommit = Initialize-FixtureGit -Root $root
        Add-RevisionTwo -Root $root
        Complete-FixtureCommit -Root $root -Message 'append revision 2' | Out-Null

        $result = Invoke-FindingStatusValidator -Root $root -BaseRef $baseCommit

        $result.ExitCode | Should -Be 0
        $result.Data.VALID | Should -BeTrue
        $result.Data.HISTORY_CHECKED | Should -BeTrue
        $result.Data.HISTORY_VALID | Should -BeTrue
        $result.Data.RECORD_COUNT | Should -Be 2
        $result.Data.LATEST_REVISION | Should -Be 2
    }

    It 'rejects a byte rewrite of a record present at BaseRef' {
        $root = New-FindingStatusFixture
        $baseCommit = Initialize-FixtureGit -Root $root
        $ledgerPath = Get-LedgerPath -Root $root
        $ledgerText = Get-Content -LiteralPath $ledgerPath -Raw
        $tampered = $ledgerText.Replace('"schemaVersion": 1,', '"schemaVersion" : 1,')
        Write-FixtureText -Path $ledgerPath -Content $tampered
        Complete-FixtureCommit -Root $root -Message 'rewrite revision 1' | Out-Null

        $result = Invoke-FindingStatusValidator -Root $root -BaseRef $baseCommit

        $result.ExitCode | Should -Be 1
        $result.Data.HISTORY_VALID | Should -BeFalse
        Get-ErrorCategories -Result $result | Should -Contain 'status-history-rewritten'
    }

    It 'rejects removal of a record present at BaseRef' {
        $root = New-FindingStatusFixture
        $baseCommit = Initialize-FixtureGit -Root $root
        $ledgerPath = Get-LedgerPath -Root $root
        $ledgerText = Get-Content -LiteralPath $ledgerPath -Raw
        $matches = Get-StatusBlockMatches -LedgerText $ledgerText
        $tampered = $ledgerText.Remove($matches[0].Index, $matches[0].Length)
        Write-FixtureText -Path $ledgerPath -Content $tampered
        Complete-FixtureCommit -Root $root -Message 'remove revision 1' | Out-Null

        $result = Invoke-FindingStatusValidator -Root $root -BaseRef $baseCommit

        $result.ExitCode | Should -Be 1
        $result.Data.HISTORY_VALID | Should -BeFalse
        Get-ErrorCategories -Result $result | Should -Contain 'status-history-removed'
    }

    It 'rejects reordering records that were already present at BaseRef' {
        $root = New-FindingStatusFixture
        Add-RevisionTwo -Root $root
        $baseCommit = Initialize-FixtureGit -Root $root
        $ledgerPath = Get-LedgerPath -Root $root
        $ledgerText = Get-Content -LiteralPath $ledgerPath -Raw
        $matches = Get-StatusBlockMatches -LedgerText $ledgerText
        $betweenStart = $matches[0].Index + $matches[0].Length
        $betweenLength = $matches[1].Index - $betweenStart
        $between = $ledgerText.Substring($betweenStart, $betweenLength)
        $tampered = (
            $ledgerText.Substring(0, $matches[0].Index) +
            $matches[1].Value +
            $between +
            $matches[0].Value +
            $ledgerText.Substring($matches[1].Index + $matches[1].Length)
        )
        Write-FixtureText -Path $ledgerPath -Content $tampered
        Complete-FixtureCommit -Root $root -Message 'reorder status history' | Out-Null

        $result = Invoke-FindingStatusValidator -Root $root -BaseRef $baseCommit

        $result.ExitCode | Should -Be 1
        $result.Data.HISTORY_VALID | Should -BeFalse
        Get-ErrorCategories -Result $result | Should -Contain 'status-history-rewritten'
    }
}
