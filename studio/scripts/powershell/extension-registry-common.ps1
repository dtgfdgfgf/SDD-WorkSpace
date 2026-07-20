#!/usr/bin/env pwsh

#Requires -Version 7.0

function Test-ExtensionJsonDocument {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$SchemaPath,
        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    $errors = @()
    $data = $null
    $raw = $null
    $schemaValid = $false

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        $errors += "Required $Label file missing: $Path"
    } else {
        try {
            $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
            $data = $raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop
        } catch {
            $errors += "Invalid $Label JSON: $($_.Exception.Message)"
        }
    }

    if (-not (Test-Path -LiteralPath $SchemaPath -PathType Leaf)) {
        $errors += "Required $Label schema missing: $SchemaPath"
    } elseif ($null -ne $raw) {
        try {
            $schema = Get-Content -LiteralPath $SchemaPath -Raw -ErrorAction Stop
            $schemaValid = Test-Json -Json $raw -Schema $schema -ErrorAction Stop
            if (-not $schemaValid) {
                $errors += "$Label does not conform to schema: $SchemaPath"
            }
        } catch {
            $errors += "$Label schema validation failed: $($_.Exception.Message)"
        }
    }

    return [PSCustomObject][ordered]@{
        VALID        = ($errors.Count -eq 0 -and $schemaValid)
        DATA         = $data
        RAW          = $raw
        SCHEMA_VALID = $schemaValid
        ERRORS       = @($errors)
    }
}

function Test-ExtensionJsonValue {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Data,
        [Parameter(Mandatory = $true)]
        [string]$SchemaPath,
        [Parameter(Mandatory = $true)]
        [string]$Label,
        [int]$Depth = 20
    )

    $errors = @()
    $schemaValid = $false
    try {
        $raw = [PSCustomObject]$Data | ConvertTo-Json -Depth $Depth
        $schema = Get-Content -LiteralPath $SchemaPath -Raw -ErrorAction Stop
        $schemaValid = Test-Json -Json $raw -Schema $schema -ErrorAction Stop
        if (-not $schemaValid) {
            $errors += "$Label does not conform to schema: $SchemaPath"
        }
    } catch {
        $errors += "$Label schema validation failed: $($_.Exception.Message)"
    }

    return [PSCustomObject][ordered]@{
        VALID        = ($errors.Count -eq 0 -and $schemaValid)
        SCHEMA_VALID = $schemaValid
        ERRORS       = @($errors)
    }
}

function Assert-ExtensionTreeHasNoReparsePoints {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,
        [string]$TreeLabel = 'Extension trees'
    )

    if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
        throw "Extension tree root does not exist: $Root"
    }

    $rootItem = Get-Item -LiteralPath $Root -Force -ErrorAction Stop
    $items = @($rootItem) + @(Get-ChildItem -LiteralPath $Root -Force -Recurse -ErrorAction Stop)
    foreach ($item in $items) {
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            $target = $null
            try {
                $target = $item.ResolveLinkTarget($true)
            } catch {
                throw "Cannot resolve extension reparse point '$($item.FullName)': $($_.Exception.Message)"
            }

            $targetText = if ($target) { $target.FullName } else { '<unresolved>' }
            throw "$TreeLabel cannot contain reparse points: $($item.FullName) -> $targetText"
        }
    }
}

function Resolve-ExtensionEntryPoint {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExtensionRoot,
        [Parameter(Mandatory = $true)]
        [string]$Scope,
        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )

    if ([string]::IsNullOrWhiteSpace($RelativePath)) {
        throw "Entry point in scope '$Scope' cannot be empty."
    }
    if ([System.IO.Path]::IsPathRooted($RelativePath)) {
        throw "Entry point must be relative: $RelativePath"
    }

    $scopeRoot = [System.IO.Path]::GetFullPath((Join-Path $ExtensionRoot $Scope))
    $candidate = [System.IO.Path]::GetFullPath((Join-Path $ExtensionRoot $RelativePath))
    Assert-PathInsideRoot -Root $ExtensionRoot -Candidate $candidate -MessagePrefix 'Entry point escapes extension root'
    Assert-PathInsideRoot -Root $scopeRoot -Candidate $candidate -MessagePrefix "Entry point escapes declared scope '$Scope'"

    if (-not (Test-Path -LiteralPath $candidate)) {
        throw "Declared entry point not found: $RelativePath"
    }

    [void](Resolve-ExistingPathInsideRoot -Root $ExtensionRoot -Candidate $candidate -MessagePrefix 'Entry point escapes extension root through a reparse point')
    [void](Resolve-ExistingPathInsideRoot -Root $scopeRoot -Candidate $candidate -MessagePrefix "Entry point escapes declared scope '$Scope' through a reparse point")
    return $candidate
}

function Get-ExtensionContentSha256 {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExtensionRoot
    )

    Assert-ExtensionTreeHasNoReparsePoints -Root $ExtensionRoot

    $records = [System.Collections.Generic.List[string]]::new()
    foreach ($file in @(
        Get-ChildItem -LiteralPath $ExtensionRoot -File -Force -Recurse |
            Sort-Object { [System.IO.Path]::GetRelativePath($ExtensionRoot, $_.FullName) }
    )) {
        $relativePath = [System.IO.Path]::GetRelativePath($ExtensionRoot, $file.FullName).Replace('\', '/')
        $pathToken = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($relativePath))
        $fileHash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
        $records.Add(('{0}:{1}:{2}' -f $pathToken, $file.Length, $fileHash))
    }

    $payload = [System.Text.Encoding]::UTF8.GetBytes(($records -join "`n"))
    return [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($payload)).ToLowerInvariant()
}

function Assert-ExtensionOutputInsideWorkspace {
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkspaceRoot,
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        [string[]]$ProtectedRoots = @()
    )

    $resolvedWorkspace = [System.IO.Path]::GetFullPath($WorkspaceRoot)
    $resolvedOutput = [System.IO.Path]::GetFullPath($OutputPath)
    Assert-PathInsideRoot -Root $resolvedWorkspace -Candidate $resolvedOutput -MessagePrefix 'Extension export output must stay inside the workspace'

    $existingAncestor = $resolvedOutput
    while (-not (Test-Path -LiteralPath $existingAncestor)) {
        $nextAncestor = Split-Path -Parent $existingAncestor
        if ([string]::IsNullOrWhiteSpace($nextAncestor) -or $nextAncestor -eq $existingAncestor) {
            throw "Cannot resolve an existing ancestor for extension export output: $resolvedOutput"
        }
        $existingAncestor = $nextAncestor
    }

    $physicalWorkspace = Resolve-ExistingPathThroughReparsePoints -Path $resolvedWorkspace
    $physicalAncestor = Resolve-ExistingPathThroughReparsePoints -Path $existingAncestor
    if (-not (Test-PathInsideOrEqualRoot -Root $physicalWorkspace -Candidate $physicalAncestor)) {
        throw "Extension export output escapes the workspace through a reparse point: $existingAncestor -> $physicalAncestor"
    }

    $remainingTail = [System.IO.Path]::GetRelativePath($existingAncestor, $resolvedOutput)
    $physicalOutput = if ($remainingTail -eq '.') {
        $physicalAncestor
    } else {
        [System.IO.Path]::GetFullPath((Join-Path $physicalAncestor $remainingTail))
    }

    foreach ($protectedRoot in @($ProtectedRoots)) {
        if ([string]::IsNullOrWhiteSpace($protectedRoot)) {
            continue
        }

        $resolvedProtected = [System.IO.Path]::GetFullPath($protectedRoot)
        $physicalProtected = if (Test-Path -LiteralPath $resolvedProtected) {
            Resolve-ExistingPathThroughReparsePoints -Path $resolvedProtected
        } else {
            $resolvedProtected
        }
        if (
            (Test-PathInsideOrEqualRoot -Root $resolvedProtected -Candidate $resolvedOutput) -or
            (Test-PathInsideOrEqualRoot -Root $resolvedOutput -Candidate $resolvedProtected) -or
            (Test-PathInsideOrEqualRoot -Root $physicalProtected -Candidate $physicalOutput) -or
            (Test-PathInsideOrEqualRoot -Root $physicalOutput -Candidate $physicalProtected)
        ) {
            throw "Extension export output overlaps a protected authority path: lexical '$resolvedOutput', physical '$physicalOutput', protected '$resolvedProtected'"
        }
    }

    return $resolvedOutput
}

function Write-ExtensionTransactionRecoveryJournal {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TransactionDir,
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Data
    )

    if (-not (Test-Path -LiteralPath $TransactionDir -PathType Container)) {
        throw "Extension transaction directory is missing: $TransactionDir"
    }

    $journalPath = Join-Path $TransactionDir 'recovery.json'
    $temporaryPath = Join-Path $TransactionDir ('.recovery.json.{0}.tmp' -f [guid]::NewGuid().ToString('N'))
    try {
        $json = [PSCustomObject]$Data | ConvertTo-Json -Depth 8 -ErrorAction Stop
        $roundTrip = $json | ConvertFrom-Json -AsHashtable -ErrorAction Stop
        if ($roundTrip -isnot [System.Collections.IDictionary]) {
            throw 'Extension transaction recovery journal did not round-trip as a JSON object.'
        }

        [System.IO.File]::WriteAllText(
            $temporaryPath,
            "$json$([Environment]::NewLine)",
            [System.Text.UTF8Encoding]::new($false)
        )
        $writtenRoundTrip = [System.IO.File]::ReadAllText($temporaryPath) |
            ConvertFrom-Json -AsHashtable -ErrorAction Stop
        if ($writtenRoundTrip -isnot [System.Collections.IDictionary]) {
            throw "Extension transaction recovery journal temporary file is invalid: $temporaryPath"
        }

        [System.IO.File]::Move($temporaryPath, $journalPath, $true)
    } finally {
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function New-ExtensionTransactionDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Paths,
        [Parameter(Mandatory = $true)]
        [string]$Operation
    )

    $transactionRoot = Join-Path $Paths.RUNTIME_ROOT '.extension-transactions'
    [void](Assert-ExtensionOutputInsideWorkspace -WorkspaceRoot $Paths.WORKSPACE_ROOT -OutputPath $transactionRoot)
    $transactionDir = Join-Path $transactionRoot ([guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $transactionDir -Force -ErrorAction Stop | Out-Null
    Write-ExtensionTransactionRecoveryJournal -TransactionDir $transactionDir -Data ([ordered]@{
        version       = 1
        operation     = $Operation
        transactionId = Split-Path -Leaf $transactionDir
        createdAt     = Get-IsoTimestamp
        baselineFiles = @()
    })
    return $transactionDir
}

function Save-ExtensionTransactionFileBaseline {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TransactionDir,
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[a-z0-9][a-z0-9.-]*$')]
        [string]$Name
    )

    if (-not (Test-Path -LiteralPath $TransactionDir -PathType Container)) {
        throw "Extension transaction directory is missing: $TransactionDir"
    }
    if (-not (Test-Path -LiteralPath $SourcePath -PathType Leaf)) {
        throw "Extension transaction baseline source is missing: $SourcePath"
    }

    $baselineDir = Join-Path $TransactionDir 'baseline'
    New-Item -ItemType Directory -Path $baselineDir -Force -ErrorAction Stop | Out-Null
    $backupPath = Join-Path $baselineDir $Name
    $hashPath = "$backupPath.sha256"
    $bytes = [System.IO.File]::ReadAllBytes($SourcePath)
    $sha256 = [Convert]::ToHexString(
        [System.Security.Cryptography.SHA256]::HashData($bytes)
    ).ToLowerInvariant()

    [System.IO.File]::WriteAllBytes($backupPath, $bytes)
    $backupSha256 = (Get-FileHash -LiteralPath $backupPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
    if ($backupSha256 -cne $sha256) {
        throw "Extension transaction baseline verification failed for '$Name': expected $sha256 but copied $backupSha256"
    }
    [System.IO.File]::WriteAllText(
        $hashPath,
        "$sha256$([Environment]::NewLine)",
        [System.Text.UTF8Encoding]::new($false)
    )

    $journalPath = Join-Path $TransactionDir 'recovery.json'
    $journal = Read-JsonFile -Path $journalPath
    if ($journal -isnot [System.Collections.IDictionary]) {
        throw "Extension transaction recovery journal is invalid: $journalPath"
    }
    $journal.baselineFiles = @($journal.baselineFiles) + @([ordered]@{
        name       = $Name
        sourcePath = [System.IO.Path]::GetFullPath($SourcePath)
        backupPath = [System.IO.Path]::GetRelativePath($TransactionDir, $backupPath).Replace('\', '/')
        sha256     = $sha256
        length     = $bytes.Length
    })
    Write-ExtensionTransactionRecoveryJournal -TransactionDir $TransactionDir -Data $journal

    return [PSCustomObject][ordered]@{
        SOURCE_PATH = [System.IO.Path]::GetFullPath($SourcePath)
        BACKUP_PATH = $backupPath
        HASH_PATH   = $hashPath
        SHA256      = $sha256
        LENGTH      = $bytes.Length
    }
}

function Restore-ExtensionTransactionFileBaseline {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Baseline
    )

    $sourcePath = [string]$Baseline.SOURCE_PATH
    $backupPath = [string]$Baseline.BACKUP_PATH
    $hashPath = [string]$Baseline.HASH_PATH
    if (-not (Test-Path -LiteralPath $backupPath -PathType Leaf)) {
        throw "Extension transaction baseline backup is missing: $backupPath"
    }
    if (-not (Test-Path -LiteralPath $hashPath -PathType Leaf)) {
        throw "Extension transaction baseline hash is missing: $hashPath"
    }

    $expectedSha256 = [System.IO.File]::ReadAllText($hashPath).Trim().ToLowerInvariant()
    if ($expectedSha256 -notmatch '^[a-f0-9]{64}$' -or $expectedSha256 -cne [string]$Baseline.SHA256) {
        throw "Extension transaction baseline hash record is invalid: $hashPath"
    }
    $backupSha256 = (Get-FileHash -LiteralPath $backupPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
    if ($backupSha256 -cne $expectedSha256) {
        throw "Extension transaction baseline backup hash mismatch for '$backupPath': expected $expectedSha256 but found $backupSha256"
    }

    $sourceDirectory = Split-Path -Parent $sourcePath
    if (-not (Test-Path -LiteralPath $sourceDirectory -PathType Container)) {
        throw "Extension transaction restore parent is missing: $sourceDirectory"
    }
    $sourceName = Split-Path -Leaf $sourcePath
    $temporaryPath = Join-Path $sourceDirectory (
        '.{0}.extension-restore-{1}.tmp' -f $sourceName, [guid]::NewGuid().ToString('N')
    )
    try {
        [System.IO.File]::Copy($backupPath, $temporaryPath, $false)
        $temporarySha256 = (Get-FileHash -LiteralPath $temporaryPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
        if ($temporarySha256 -cne $expectedSha256) {
            throw "Extension transaction restore temporary hash mismatch for '$sourcePath': expected $expectedSha256 but found $temporarySha256"
        }

        [System.IO.File]::Move($temporaryPath, $sourcePath, $true)
        $restoredSha256 = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
        if ($restoredSha256 -cne $expectedSha256) {
            throw "Extension transaction restore verification failed for '$sourcePath': expected $expectedSha256 but found $restoredSha256"
        }
    } finally {
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Move-ExtensionMirrorToTransaction {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Paths,
        [Parameter(Mandatory = $true)]
        [string]$TransactionDir
    )

    if (-not (Test-Path -LiteralPath $Paths.RUNTIME_MIRROR_ROOT)) {
        return $null
    }

    [void](Assert-ExtensionOutputInsideWorkspace -WorkspaceRoot $Paths.WORKSPACE_ROOT -OutputPath $Paths.RUNTIME_MIRROR_ROOT)
    Assert-ExtensionTreeHasNoReparsePoints -Root $Paths.RUNTIME_MIRROR_ROOT -TreeLabel 'Generated extension mirrors'
    $backupPath = Join-Path $TransactionDir 'merged-backup'
    Move-Item -LiteralPath $Paths.RUNTIME_MIRROR_ROOT -Destination $backupPath -ErrorAction Stop
    return $backupPath
}

function Restore-ExtensionMirrorFromTransaction {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Paths,
        [AllowNull()]
        [string]$BackupPath
    )

    if ([string]::IsNullOrWhiteSpace($BackupPath) -or -not (Test-Path -LiteralPath $BackupPath)) {
        return
    }

    if (Test-Path -LiteralPath $Paths.RUNTIME_MIRROR_ROOT) {
        Remove-Item -LiteralPath $Paths.RUNTIME_MIRROR_ROOT -Recurse -Force -ErrorAction Stop
    }
    Move-Item -LiteralPath $BackupPath -Destination $Paths.RUNTIME_MIRROR_ROOT -ErrorAction Stop
}
