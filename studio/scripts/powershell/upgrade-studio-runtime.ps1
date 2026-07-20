#!/usr/bin/env pwsh

#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$UpstreamSnapshotDir,
    [switch]$DryRun,
    [switch]$Apply,
    [switch]$Json,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    $helpLines = @(
        'Usage: ./upgrade-studio-runtime.ps1 -UpstreamSnapshotDir <path> [-DryRun] [-Apply] [-Json] [-Help]',
        '',
        'Syncs the studio-first shared layer from a local snapshot that already matches the workspace shared-layer shape.',
        '',
        'Default behavior: dry-run.',
        '',
        'Options:',
        '  -UpstreamSnapshotDir Local snapshot directory used as the comparison/apply source',
        '  -DryRun             Report changes only (this is the DEFAULT; -DryRun and -Apply are mutually exclusive)',
        '  -Apply              Actually apply the allowlisted shared-layer changes (REQUIRED to write anything)',
        '  -Json               Output structured JSON summary',
        '  -Help               Show this help message',
        '',
        'Examples:',
        '  pwsh ./upgrade-studio-runtime.ps1 -UpstreamSnapshotDir ../snapshot          # preview changes',
        '  pwsh ./upgrade-studio-runtime.ps1 -UpstreamSnapshotDir ../snapshot -Apply   # actually copy them'
    )
    Write-Output ($helpLines -join "`n")
    exit 0
}

. "$PSScriptRoot/common.ps1"

function Get-RelativeFileMap {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $map = @{}
    if (-not (Test-Path -LiteralPath $Path)) {
        return $map
    }

    Get-ChildItem -LiteralPath $Path -Recurse -File | ForEach-Object {
        $map[[System.IO.Path]::GetRelativePath($Path, $_.FullName)] = $_.FullName
    }

    return $map
}

function Get-FileChangeType {
    param(
        [string]$SourcePath,
        [string]$TargetPath
    )

    if (-not (Test-Path -LiteralPath $SourcePath)) {
        return 'missing-source'
    }

    if (-not (Test-Path -LiteralPath $TargetPath)) {
        return 'add'
    }

    $sourceHash = (Get-FileHash -LiteralPath $SourcePath -Algorithm SHA256).Hash
    $targetHash = (Get-FileHash -LiteralPath $TargetPath -Algorithm SHA256).Hash
    if ($sourceHash -eq $targetHash) {
        return 'unchanged'
    }

    return 'update'
}

function Get-FileSha256 {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Assert-UpgradePathPhysicalContainment {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,
        [Parameter(Mandatory = $true)]
        [string]$Candidate,
        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    $resolvedRoot = [System.IO.Path]::GetFullPath($Root)
    $resolvedCandidate = [System.IO.Path]::GetFullPath($Candidate)
    if (-not (Test-PathInsideOrEqualRoot -Root $resolvedRoot -Candidate $resolvedCandidate)) {
        throw "$Label escapes the lexical root boundary: $resolvedCandidate (root: $resolvedRoot)"
    }

    $existingPath = $resolvedCandidate
    while (-not (Test-Path -LiteralPath $existingPath)) {
        $parentPath = Split-Path -Parent $existingPath
        if ([string]::IsNullOrWhiteSpace($parentPath) -or $parentPath -eq $existingPath) {
            throw "Unable to find an existing ancestor for ${Label}: $resolvedCandidate"
        }
        $existingPath = $parentPath
    }

    if ($existingPath.Equals($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        return
    }

    try {
        Resolve-ExistingPathInsideRoot `
            -Root $resolvedRoot `
            -Candidate $existingPath `
            -MessagePrefix "$Label escapes the physical root boundary through a reparse point" |
            Out-Null
    } catch {
        throw "$Label failed physical root containment: $($_.Exception.Message)"
    }
}

function Assert-UpgradeSnapshotComplete {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$SyncMap,
        [Parameter(Mandatory = $true)]
        [string]$SnapshotRoot,
        [Parameter(Mandatory = $true)]
        [string]$WorkspaceRoot
    )

    foreach ($mapping in @($SyncMap.mappings)) {
        $mappingKind = [string]$mapping.kind
        if ($mappingKind -notin @('directory', 'file')) {
            throw "Unsupported sync mapping kind '$mappingKind' for target '$($mapping.target)'."
        }

        $sourcePath = Resolve-RelativePathInsideRoot -Root $SnapshotRoot -RelativePath ([string]$mapping.source)
        $targetPath = Resolve-RelativePathInsideRoot -Root $WorkspaceRoot -RelativePath ([string]$mapping.target)
        Assert-UpgradePathPhysicalContainment -Root $WorkspaceRoot -Candidate $targetPath -Label "Upgrade target '$($mapping.target)'"

        if ($mappingKind -eq 'directory') {
            if (-not (Test-Path -LiteralPath $sourcePath -PathType Container)) {
                throw "Snapshot is incomplete: mapped source directory is missing: $($mapping.source)"
            }
            Assert-UpgradePathPhysicalContainment -Root $SnapshotRoot -Candidate $sourcePath -Label "Snapshot source '$($mapping.source)'"

            $sourceFiles = Get-RelativeFileMap -Path $sourcePath
            $targetFiles = Get-RelativeFileMap -Path $targetPath
            $missingRelativePaths = @(
                $targetFiles.Keys |
                    Where-Object { -not $sourceFiles.ContainsKey($_) } |
                    Sort-Object
            )
            if ($missingRelativePaths.Count -gt 0) {
                throw (
                    "Snapshot is incomplete for mapping '{0}': missing current canonical files: {1}" -f
                    $mapping.target,
                    ($missingRelativePaths -join ', ')
                )
            }

            foreach ($relativePath in @($sourceFiles.Keys)) {
                Assert-UpgradePathPhysicalContainment `
                    -Root $SnapshotRoot `
                    -Candidate ([string]$sourceFiles[$relativePath]) `
                    -Label "Snapshot source '$($mapping.source)/$relativePath'"
                Assert-UpgradePathPhysicalContainment `
                    -Root $WorkspaceRoot `
                    -Candidate (Join-Path $targetPath $relativePath) `
                    -Label "Upgrade target '$($mapping.target)/$relativePath'"
            }
        } elseif (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
            throw "Snapshot is incomplete: mapped source file is missing: $($mapping.source)"
        } else {
            Assert-UpgradePathPhysicalContainment -Root $SnapshotRoot -Candidate $sourcePath -Label "Snapshot source '$($mapping.source)'"
        }
    }
}

function Get-UpgradeChanges {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$SyncMap,
        [Parameter(Mandatory = $true)]
        [string]$SnapshotRoot,
        [Parameter(Mandatory = $true)]
        [string]$WorkspaceRoot
    )

    $detectedChanges = @()
    foreach ($mapping in @($SyncMap.mappings)) {
        $sourcePath = Resolve-RelativePathInsideRoot -Root $SnapshotRoot -RelativePath ([string]$mapping.source)
        $targetPath = Resolve-RelativePathInsideRoot -Root $WorkspaceRoot -RelativePath ([string]$mapping.target)

        if ([string]$mapping.kind -eq 'directory') {
            $sourceFiles = Get-RelativeFileMap -Path $sourcePath
            foreach ($relativePath in @($sourceFiles.Keys | Sort-Object)) {
                $sourceFile = $sourceFiles[$relativePath]
                $targetFile = Join-Path $targetPath $relativePath
                $changeType = Get-FileChangeType -SourcePath $sourceFile -TargetPath $targetFile
                if ($changeType -ne 'unchanged') {
                    $detectedChanges += [ordered]@{
                        mapping    = [string]$mapping.target
                        kind       = 'directory'
                        relative   = $relativePath
                        source     = $sourceFile
                        target     = $targetFile
                        changeType = $changeType
                    }
                }
            }
        } else {
            $changeType = Get-FileChangeType -SourcePath $sourcePath -TargetPath $targetPath
            if ($changeType -ne 'unchanged') {
                $detectedChanges += [ordered]@{
                    mapping    = [string]$mapping.target
                    kind       = 'file'
                    relative   = $null
                    source     = $sourcePath
                    target     = $targetPath
                    changeType = $changeType
                }
            }
        }
    }

    return @($detectedChanges)
}

function Copy-FilePreservingRelativePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceRoot,
        [Parameter(Mandatory = $true)]
        [string]$DestinationRoot,
        [Parameter(Mandatory = $true)]
        [string]$SourceFile
    )

    $relativePath = [System.IO.Path]::GetRelativePath($SourceRoot, $SourceFile)
    $destinationFile = Join-Path $DestinationRoot $relativePath
    $destinationParent = Split-Path -Parent $destinationFile
    if (-not (Test-Path -LiteralPath $destinationParent -PathType Container)) {
        New-Item -ItemType Directory -Path $destinationParent -Force | Out-Null
    }
    Copy-Item -LiteralPath $SourceFile -Destination $destinationFile -Force
}

function Copy-UpgradeWorkspaceSeed {
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkspaceRoot,
        [Parameter(Mandatory = $true)]
        [string]$StagingRoot
    )

    New-Item -ItemType Directory -Path $StagingRoot -Force | Out-Null

    $auditSeedFiles = @(
        '.editorconfig',
        '.gitattributes',
        '.gitignore',
        'AGENTS.md',
        'CLAUDE.md',
        'LICENSE',
        'README.md',
        'THIRD_PARTY_NOTICES.md',
        'WORKSPACE_STRUCTURE.md'
    )
    foreach ($relativeFile in $auditSeedFiles) {
        $rootFile = Join-Path $WorkspaceRoot $relativeFile
        if (Test-Path -LiteralPath $rootFile -PathType Leaf) {
            Copy-FilePreservingRelativePath -SourceRoot $WorkspaceRoot -DestinationRoot $StagingRoot -SourceFile $rootFile
        }
    }

    $auditSeedDirectories = @(
        '.claude',
        '.githooks',
        '.github',
        'docs',
        'resources',
        'studio'
    )
    foreach ($relativeDirectory in $auditSeedDirectories) {
        $sourceDirectory = Join-Path $WorkspaceRoot $relativeDirectory
        if (-not (Test-Path -LiteralPath $sourceDirectory -PathType Container)) {
            continue
        }

        foreach ($sourceFile in @(Get-ChildItem -LiteralPath $sourceDirectory -Recurse -File -Force)) {
            Copy-FilePreservingRelativePath -SourceRoot $WorkspaceRoot -DestinationRoot $StagingRoot -SourceFile $sourceFile.FullName
        }
    }
}

function Disable-StagedRuntimeMirror {
    param(
        [Parameter(Mandatory = $true)]
        [string]$StagingRoot,
        [Parameter(Mandatory = $true)]
        [string]$TransactionRoot
    )

    $stagedMirrorRoot = Join-Path $StagingRoot 'resources/studio-runtime/merged'
    if (-not (Test-Path -LiteralPath $stagedMirrorRoot)) {
        return
    }

    $quarantineRoot = Join-Path $TransactionRoot 'inactive-staged-mirror'
    if (Test-Path -LiteralPath $quarantineRoot) {
        throw "Staged mirror quarantine path already exists: $quarantineRoot"
    }
    Move-Item -LiteralPath $stagedMirrorRoot -Destination $quarantineRoot
}

function Apply-SnapshotToStaging {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$SyncMap,
        [Parameter(Mandatory = $true)]
        [string]$SnapshotRoot,
        [Parameter(Mandatory = $true)]
        [string]$StagingRoot
    )

    foreach ($mapping in @($SyncMap.mappings)) {
        $sourcePath = Resolve-RelativePathInsideRoot -Root $SnapshotRoot -RelativePath ([string]$mapping.source)
        $stagedTargetPath = Resolve-RelativePathInsideRoot -Root $StagingRoot -RelativePath ([string]$mapping.target)

        if ([string]$mapping.kind -eq 'directory') {
            foreach ($sourceFile in @((Get-RelativeFileMap -Path $sourcePath).Values)) {
                $relativePath = [System.IO.Path]::GetRelativePath($sourcePath, $sourceFile)
                $stagedTargetFile = Join-Path $stagedTargetPath $relativePath
                $targetParent = Split-Path -Parent $stagedTargetFile
                if (-not (Test-Path -LiteralPath $targetParent -PathType Container)) {
                    New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
                }
                Copy-Item -LiteralPath $sourceFile -Destination $stagedTargetFile -Force
            }
        } else {
            $targetParent = Split-Path -Parent $stagedTargetPath
            if (-not (Test-Path -LiteralPath $targetParent -PathType Container)) {
                New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
            }
            Copy-Item -LiteralPath $sourcePath -Destination $stagedTargetPath -Force
        }
    }
}

function Get-UpgradeCandidateHashManifest {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$SyncMap,
        [Parameter(Mandatory = $true)]
        [string]$StagingRoot,
        [Parameter(Mandatory = $true)]
        [string]$WorkspaceRoot
    )

    $manifest = @{}
    foreach ($mapping in @($SyncMap.mappings)) {
        $stagedTargetPath = Resolve-RelativePathInsideRoot -Root $StagingRoot -RelativePath ([string]$mapping.target)
        $canonicalTargetPath = Resolve-RelativePathInsideRoot -Root $WorkspaceRoot -RelativePath ([string]$mapping.target)
        if ([string]$mapping.kind -eq 'directory') {
            $stagedFiles = Get-RelativeFileMap -Path $stagedTargetPath
            foreach ($relativePath in @($stagedFiles.Keys)) {
                $canonicalFile = Join-Path $canonicalTargetPath $relativePath
                $manifest[$canonicalFile] = Get-FileSha256 -Path ([string]$stagedFiles[$relativePath])
            }
        } elseif (Test-Path -LiteralPath $stagedTargetPath -PathType Leaf) {
            $manifest[$canonicalTargetPath] = Get-FileSha256 -Path $stagedTargetPath
        } else {
            throw "Mapped candidate file is missing from staging: $($mapping.target)"
        }
    }

    return ,$manifest
}

function Assert-UpgradeCandidateManifestUnchanged {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Before,
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$After
    )

    $manifestErrors = @()
    foreach ($path in @($Before.Keys)) {
        if (-not $After.ContainsKey($path)) {
            $manifestErrors += "candidate file disappeared: $path"
        } elseif ([string]$Before[$path] -ne [string]$After[$path]) {
            $manifestErrors += "candidate file changed after staging: $path"
        }
    }
    foreach ($path in @($After.Keys)) {
        if (-not $Before.ContainsKey($path)) {
            $manifestErrors += "candidate file appeared after staging: $path"
        }
    }

    if ($manifestErrors.Count -gt 0) {
        throw "Candidate verification mutated governed upgrade files: $($manifestErrors -join '; ')"
    }
}

function Get-TrustedUpgradeAuthorityManifest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AuthorityRoot
    )

    if (-not (Test-Path -LiteralPath $AuthorityRoot -PathType Container)) {
        throw "Trusted upgrade audit authority root is missing: $AuthorityRoot"
    }

    $manifest = @{}
    foreach ($file in @(Get-ChildItem -LiteralPath $AuthorityRoot -Recurse -File -Force | Sort-Object FullName)) {
        $relativePath = [System.IO.Path]::GetRelativePath($AuthorityRoot, $file.FullName)
        $manifest[$relativePath] = Get-FileSha256 -Path $file.FullName
    }
    if ($manifest.Count -eq 0) {
        throw "Trusted upgrade audit authority is empty: $AuthorityRoot"
    }

    return $manifest
}

function Assert-TrustedUpgradeAuthorityUnchanged {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$TrustedAuditBundle
    )

    $expected = $TrustedAuditBundle.manifest
    $actual = Get-TrustedUpgradeAuthorityManifest -AuthorityRoot ([string]$TrustedAuditBundle.root)
    $authorityErrors = @()
    foreach ($path in @($expected.Keys)) {
        if (-not $actual.ContainsKey($path)) {
            $authorityErrors += "trusted authority file disappeared: $path"
        } elseif ([string]$expected[$path] -ne [string]$actual[$path]) {
            $authorityErrors += "trusted authority file hash changed: $path"
        }
    }
    foreach ($path in @($actual.Keys)) {
        if (-not $expected.ContainsKey($path)) {
            $authorityErrors += "trusted authority file appeared: $path"
        }
    }

    if ($authorityErrors.Count -gt 0) {
        throw "Frozen trusted upgrade audit authority changed during transaction: $($authorityErrors -join '; ')"
    }
}

function New-TrustedUpgradeAuditBundle {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CanonicalScriptsDir,
        [Parameter(Mandatory = $true)]
        [string]$TransactionRoot
    )

    $trustedScriptsDir = Join-Path $TransactionRoot 'trusted-audit/studio/scripts/powershell'
    New-Item -ItemType Directory -Path $trustedScriptsDir -Force | Out-Null
    foreach ($canonicalScript in @(Get-ChildItem -LiteralPath $CanonicalScriptsDir -File -Force)) {
        [System.IO.File]::Copy($canonicalScript.FullName, (Join-Path $trustedScriptsDir $canonicalScript.Name), $false)
    }

    $trustedAuditScript = Join-Path $trustedScriptsDir 'check-speckit-runtime.ps1'
    $trustedCommonScript = Join-Path $trustedScriptsDir 'common.ps1'
    if (
        -not (Test-Path -LiteralPath $trustedAuditScript -PathType Leaf) -or
        -not (Test-Path -LiteralPath $trustedCommonScript -PathType Leaf)
    ) {
        throw "Trusted upgrade audit authority is incomplete under: $trustedScriptsDir"
    }

    $canonicalStudioRoot = [System.IO.Path]::GetFullPath((Join-Path $CanonicalScriptsDir '../..'))
    $trustedWorkflowsRoot = Join-Path $TransactionRoot 'trusted-audit/studio/workflows'
    New-Item -ItemType Directory -Path $trustedWorkflowsRoot -Force | Out-Null
    foreach ($schemaName in @('catalog.schema.json', 'state.schema.json')) {
        $canonicalSchema = Join-Path $canonicalStudioRoot "workflows/$schemaName"
        if (-not (Test-Path -LiteralPath $canonicalSchema -PathType Leaf)) {
            throw "Trusted workflow registry schema is missing: $canonicalSchema"
        }
        [System.IO.File]::Copy($canonicalSchema, (Join-Path $trustedWorkflowsRoot $schemaName), $false)
    }

    $trustedGeneratorScript = Join-Path $trustedScriptsDir 'generate-impact-registry.ps1'
    $generatorContent = [System.IO.File]::ReadAllText($trustedGeneratorScript)
    $generatorWorkspaceAnchor = '$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot ''../../..'')).Path'
    $generatorWorkspaceReplacement = '$workspaceRoot = if ($env:SDD_AUDIT_WORKSPACE_ROOT) { [System.IO.Path]::GetFullPath($env:SDD_AUDIT_WORKSPACE_ROOT) } else { (Resolve-Path (Join-Path $PSScriptRoot ''../../..'')).Path }'
    if (-not $generatorContent.Contains($generatorWorkspaceAnchor, [System.StringComparison]::Ordinal)) {
        throw 'Trusted impact-registry generator workspace anchor is missing.'
    }
    $generatorContent = $generatorContent.Replace(
        $generatorWorkspaceAnchor,
        $generatorWorkspaceReplacement,
        [System.StringComparison]::Ordinal
    )
    [System.IO.File]::WriteAllText($trustedGeneratorScript, $generatorContent, [System.Text.UTF8Encoding]::new($false))

    $checkerContent = [System.IO.File]::ReadAllText($trustedAuditScript)
    $dependencyRedirects = [ordered]@{
        '$validator = Invoke-JsonScript -ScriptPath $paths.EXTENSIONS_VALIDATOR_PATH -Arguments @(''-Json'')' =
            '$validator = Invoke-JsonScript -ScriptPath (Join-Path $PSScriptRoot ''validate-extension-registry.ps1'') -Arguments @(''-Json'')'
        '$listWorkflowsScript = Join-Path $paths.SHARED_SCRIPTS_DIR ''list-workflows.ps1''' =
            '$listWorkflowsScript = Join-Path $PSScriptRoot ''list-workflows.ps1'''
        '$agentBootstrapScript = Join-Path $paths.SHARED_SCRIPTS_DIR ''check-agent-bootstrap.ps1''' =
            '$agentBootstrapScript = Join-Path $PSScriptRoot ''check-agent-bootstrap.ps1'''
        '$mainlineNoteScript = Join-Path $paths.SHARED_SCRIPTS_DIR ''validate-mainline-notes.ps1''' =
            '$mainlineNoteScript = Join-Path $PSScriptRoot ''validate-mainline-notes.ps1'''
        '$generatorScript = Join-Path $paths.WORKSPACE_ROOT ''studio/scripts/powershell/generate-impact-registry.ps1''' =
            '$generatorScript = Join-Path $PSScriptRoot ''generate-impact-registry.ps1'''
    }
    $redirectedDependencyCount = 0
    foreach ($redirect in $dependencyRedirects.GetEnumerator()) {
        if ($checkerContent.Contains([string]$redirect.Key, [System.StringComparison]::Ordinal)) {
            $checkerContent = $checkerContent.Replace([string]$redirect.Key, [string]$redirect.Value, [System.StringComparison]::Ordinal)
            $redirectedDependencyCount++
        }
    }
    if ($redirectedDependencyCount -ne $dependencyRedirects.Count) {
        throw "Trusted runtime checker dependency redirection is incomplete: $redirectedDependencyCount of $($dependencyRedirects.Count)"
    }
    [System.IO.File]::WriteAllText($trustedAuditScript, $checkerContent, [System.Text.UTF8Encoding]::new($false))

    $trustedAuthorityRoot = Join-Path $TransactionRoot 'trusted-audit'
    return [ordered]@{
        root = $trustedAuthorityRoot
        script = $trustedAuditScript
        manifest = Get-TrustedUpgradeAuthorityManifest -AuthorityRoot $trustedAuthorityRoot
    }
}

function Invoke-UpgradeJsonProcessDetailed {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,
        [Parameter(Mandatory = $true)]
        [string]$WorkspaceRoot,
        [string[]]$Arguments = @()
    )

    $previousStudioRoot = $env:SDD_STUDIO_ROOT
    $previousProjectRoot = $env:SDD_PROJECT_ROOT
    $previousAuditWorkspaceRoot = $env:SDD_AUDIT_WORKSPACE_ROOT
    Push-Location -LiteralPath $WorkspaceRoot
    try {
        $env:SDD_STUDIO_ROOT = Join-Path $WorkspaceRoot 'studio'
        $env:SDD_PROJECT_ROOT = $WorkspaceRoot
        $env:SDD_AUDIT_WORKSPACE_ROOT = $WorkspaceRoot
        $output = & pwsh -NoProfile -File $ScriptPath @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    } finally {
        $env:SDD_STUDIO_ROOT = $previousStudioRoot
        $env:SDD_PROJECT_ROOT = $previousProjectRoot
        $env:SDD_AUDIT_WORKSPACE_ROOT = $previousAuditWorkspaceRoot
        Pop-Location
    }
    $rawOutput = if ($output) { $output -join [Environment]::NewLine } else { $null }
    $parsedOutput = $null
    if (-not [string]::IsNullOrWhiteSpace($rawOutput)) {
        try {
            $parsedOutput = $rawOutput | ConvertFrom-Json -AsHashtable
        } catch {
            $parsedOutput = $null
        }
    }

    return [ordered]@{
        EXIT_CODE = $exitCode
        RAW = $rawOutput
        OUTPUT = $parsedOutput
    }
}

function Invoke-UpgradeRuntimeAudit {
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkspaceRoot,
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$TrustedAuditBundle
    )

    $trustedAuditScript = [string]$TrustedAuditBundle.script
    if (-not (Test-Path -LiteralPath $trustedAuditScript -PathType Leaf)) {
        throw "Frozen trusted runtime audit script is missing: $trustedAuditScript"
    }

    Assert-TrustedUpgradeAuthorityUnchanged -TrustedAuditBundle $TrustedAuditBundle
    try {
        return Invoke-UpgradeJsonProcessDetailed `
            -ScriptPath $trustedAuditScript `
            -WorkspaceRoot $WorkspaceRoot `
            -Arguments @('-Json')
    } finally {
        Assert-TrustedUpgradeAuthorityUnchanged -TrustedAuditBundle $TrustedAuditBundle
    }
}

function Assert-UpgradeRuntimeAuditPassed {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$AuditResult,
        [Parameter(Mandatory = $true)]
        [string]$Phase
    )

    $outputShapeValid = (
        $AuditResult.OUTPUT -is [System.Collections.IDictionary] -and
        $AuditResult.OUTPUT.ContainsKey('VALID') -and
        $AuditResult.OUTPUT.VALID -is [bool] -and
        $AuditResult.OUTPUT.VALID -eq $true -and
        $AuditResult.OUTPUT.ContainsKey('ERROR_COUNT') -and
        $AuditResult.OUTPUT.ERROR_COUNT -is [long] -and
        $AuditResult.OUTPUT.ERROR_COUNT -eq 0 -and
        $AuditResult.OUTPUT.ContainsKey('WARNING_COUNT') -and
        $AuditResult.OUTPUT.WARNING_COUNT -is [long] -and
        $AuditResult.OUTPUT.WARNING_COUNT -eq 0
    )
    if ($AuditResult.EXIT_CODE -ne 0 -or -not $outputShapeValid) {
        throw "Shared runtime contract audit failed during $Phase; canonical runtime was not authorized for update."
    }
}

function Invoke-UpgradeTrustedCandidateVerification {
    param(
        [Parameter(Mandatory = $true)]
        [string]$StagingRoot,
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$TrustedAuditBundle,
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$SyncMap,
        [Parameter(Mandatory = $true)]
        [string]$WorkspaceRoot
    )

    $manifestBeforeVerification = Get-UpgradeCandidateHashManifest -SyncMap $SyncMap -StagingRoot $StagingRoot -WorkspaceRoot $WorkspaceRoot
    $trustedRuntimeCheck = Invoke-UpgradeRuntimeAudit -WorkspaceRoot $StagingRoot -TrustedAuditBundle $TrustedAuditBundle
    Assert-UpgradeRuntimeAuditPassed -AuditResult $trustedRuntimeCheck -Phase 'trusted staging'
    $manifestAfterVerification = Get-UpgradeCandidateHashManifest -SyncMap $SyncMap -StagingRoot $StagingRoot -WorkspaceRoot $WorkspaceRoot
    Assert-UpgradeCandidateManifestUnchanged -Before $manifestBeforeVerification -After $manifestAfterVerification

    return [ordered]@{
        verification = [ordered]@{
            runtimeCheckPhase = 'trusted-staging'
            runtimeCheckExitCode = $trustedRuntimeCheck.EXIT_CODE
            runtimeCheck = $trustedRuntimeCheck.OUTPUT
            runtimeCheckRaw = $trustedRuntimeCheck.RAW
            candidateFileCount = $manifestAfterVerification.Count
        }
        manifest = $manifestAfterVerification
    }
}

function New-UpgradeBaseline {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Changes,
        [Parameter(Mandatory = $true)]
        [string]$WorkspaceRoot,
        [Parameter(Mandatory = $true)]
        [string]$BackupRoot
    )

    New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
    $records = @()
    $index = 0
    foreach ($targetPath in @($Changes | ForEach-Object { [string]$_.target } | Select-Object -Unique)) {
        Assert-UpgradePathPhysicalContainment -Root $WorkspaceRoot -Candidate $targetPath -Label 'Upgrade transaction target'
        if ((Test-Path -LiteralPath $targetPath) -and -not (Test-Path -LiteralPath $targetPath -PathType Leaf)) {
            throw "Upgrade target is not a file: $targetPath"
        }

        $existed = Test-Path -LiteralPath $targetPath -PathType Leaf
        $backupPath = if ($existed) { Join-Path $BackupRoot ("{0:D6}.bak" -f $index) } else { $null }
        $baselineHash = if ($existed) { Get-FileSha256 -Path $targetPath } else { $null }
        if ($existed) {
            [System.IO.File]::Copy($targetPath, $backupPath, $false)
            if ((Get-FileSha256 -Path $backupPath) -ne $baselineHash) {
                throw "Unable to verify upgrade baseline backup for: $targetPath"
            }
        }

        $records += [ordered]@{
            target = $targetPath
            existed = $existed
            hash = $baselineHash
            backup = $backupPath
        }
        $index++
    }

    return @($records)
}

function Write-UpgradeTransactionJournal {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$TransactionId,
        [Parameter(Mandatory = $true)]
        [string]$State,
        [Parameter(Mandatory = $true)]
        [string]$WorkspaceRoot,
        [Parameter(Mandatory = $true)]
        [string]$StagingRoot,
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Baseline,
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$TrustedAuditBundle,
        [string]$Failure
    )

    $baselineRecords = @(
        foreach ($record in $Baseline) {
            [ordered]@{
                target = [string]$record.target
                existed = [bool]$record.existed
                hash = if ($record.hash) { [string]$record.hash } else { $null }
                backup = if ($record.backup) { [string]$record.backup } else { $null }
            }
        }
    )
    $authorityRecords = @(
        foreach ($entry in @($TrustedAuditBundle.manifest.GetEnumerator() | Sort-Object Key)) {
            [ordered]@{
                path = [string]$entry.Key
                hash = [string]$entry.Value
            }
        }
    )
    $journal = [ordered]@{
        version = 1
        transactionId = $TransactionId
        state = $State
        workspaceRoot = $WorkspaceRoot
        stagingRoot = $StagingRoot
        trustedAuthority = [ordered]@{
            root = [string]$TrustedAuditBundle.root
            script = [string]$TrustedAuditBundle.script
            files = $authorityRecords
        }
        baseline = $baselineRecords
        failure = if ([string]::IsNullOrWhiteSpace($Failure)) { $null } else { $Failure }
        updatedAt = (Get-Date).ToUniversalTime().ToString('o')
    }

    $json = $journal | ConvertTo-Json -Depth 10
    $temporaryPath = "$Path.write-$TransactionId.tmp"
    try {
        [System.IO.File]::WriteAllText($temporaryPath, $json, [System.Text.UTF8Encoding]::new($false))
        $temporaryHash = Get-FileSha256 -Path $temporaryPath
        try {
            $roundTrip = [System.IO.File]::ReadAllText($temporaryPath) | ConvertFrom-Json -AsHashtable
        } catch {
            throw "Upgrade transaction journal round-trip parsing failed: $($_.Exception.Message)"
        }
        $shapeValid = (
            $roundTrip -is [System.Collections.IDictionary] -and
            $roundTrip.ContainsKey('version') -and
            $roundTrip.version -is [long] -and
            $roundTrip.version -eq 1 -and
            $roundTrip.ContainsKey('transactionId') -and
            [string]$roundTrip.transactionId -eq $TransactionId -and
            $roundTrip.ContainsKey('state') -and
            [string]$roundTrip.state -eq $State -and
            $roundTrip.ContainsKey('trustedAuthority') -and
            $roundTrip.trustedAuthority -is [System.Collections.IDictionary] -and
            $roundTrip.ContainsKey('baseline') -and
            $roundTrip.baseline -is [System.Collections.IList]
        )
        if (-not $shapeValid) {
            throw 'Upgrade transaction journal round-trip shape validation failed.'
        }

        [System.IO.File]::Move($temporaryPath, $Path, $true)
        if (
            -not (Test-Path -LiteralPath $Path -PathType Leaf) -or
            (Get-FileSha256 -Path $Path) -ne $temporaryHash
        ) {
            throw "Upgrade transaction journal atomic replacement verification failed: $Path"
        }
    } finally {
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Assert-UpgradeBaselineIntegrity {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Baseline
    )

    $integrityErrors = @()
    foreach ($record in $Baseline) {
        if (-not [bool]$record.existed) {
            continue
        }
        $backupPath = [string]$record.backup
        if (-not (Test-Path -LiteralPath $backupPath -PathType Leaf)) {
            $integrityErrors += "baseline backup is missing for: $($record.target)"
        } elseif ((Get-FileSha256 -Path $backupPath) -ne [string]$record.hash) {
            $integrityErrors += "baseline backup hash changed for: $($record.target)"
        }
    }
    if ($integrityErrors.Count -gt 0) {
        throw "Upgrade transaction baseline integrity failed: $($integrityErrors -join '; ')"
    }
}

function Add-MissingParentDirectories {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[string]]$CreatedDirectories
    )

    $missingDirectories = @()
    $current = Split-Path -Parent $Path
    while ($current -and -not (Test-Path -LiteralPath $current -PathType Container)) {
        $missingDirectories += $current
        $current = Split-Path -Parent $current
    }

    for ($index = $missingDirectories.Count - 1; $index -ge 0; $index--) {
        $directory = $missingDirectories[$index]
        New-Item -ItemType Directory -Path $directory | Out-Null
        $CreatedDirectories.Add($directory)
    }
}

function Publish-UpgradeFileAtomically {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,
        [Parameter(Mandatory = $true)]
        [string]$Target,
        [Parameter(Mandatory = $true)]
        [string]$TransactionId,
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[string]]$CreatedDirectories,
        [string]$ExpectedSha256
    )

    Add-MissingParentDirectories -Path $Target -CreatedDirectories $CreatedDirectories
    $temporaryTarget = "{0}.upgrade-{1}.tmp" -f $Target, $TransactionId
    try {
        [System.IO.File]::Copy($Source, $temporaryTarget, $false)
        $expectedHash = if ($ExpectedSha256) { $ExpectedSha256 } else { Get-FileSha256 -Path $Source }
        if ((Get-FileSha256 -Path $temporaryTarget) -ne $expectedHash) {
            throw "Upgrade temporary file verification failed for: $Target"
        }
        [System.IO.File]::Move($temporaryTarget, $Target, $true)
    } finally {
        if (Test-Path -LiteralPath $temporaryTarget) {
            Remove-Item -LiteralPath $temporaryTarget -Force -ErrorAction SilentlyContinue
        }
    }
}

function Restore-UpgradeTargets {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Baseline,
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$PromotedTargets,
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[string]]$CreatedDirectories,
        [Parameter(Mandatory = $true)]
        [string]$TransactionId
    )

    $baselineByTarget = @{}
    foreach ($record in $Baseline) {
        $baselineByTarget[[string]$record.target] = $record
    }

    $uniquePromotedTargets = @($PromotedTargets | Select-Object -Unique)
    [array]::Reverse($uniquePromotedTargets)
    foreach ($targetPath in $uniquePromotedTargets) {
        $record = $baselineByTarget[$targetPath]
        if (-not $record) {
            throw "Rollback baseline is missing for promoted target: $targetPath"
        }

        if ([bool]$record.existed) {
            if (
                (Test-Path -LiteralPath $targetPath -PathType Leaf) -and
                ((Get-FileSha256 -Path $targetPath) -eq [string]$record.hash)
            ) {
                continue
            }
            Publish-UpgradeFileAtomically `
                -Source ([string]$record.backup) `
                -Target $targetPath `
                -TransactionId $TransactionId `
                -CreatedDirectories $CreatedDirectories `
                -ExpectedSha256 ([string]$record.hash)
        } else {
            if (-not (Test-Path -LiteralPath $targetPath)) {
                continue
            }
            Remove-Item -LiteralPath $targetPath -Force
        }
    }

    foreach ($directory in @($CreatedDirectories | Sort-Object { $_.Length } -Descending)) {
        if (
            (Test-Path -LiteralPath $directory -PathType Container) -and
            -not (Get-ChildItem -LiteralPath $directory -Force | Select-Object -First 1)
        ) {
            Remove-Item -LiteralPath $directory -Force
        }
    }

    $rollbackErrors = @()
    foreach ($record in $Baseline) {
        $targetPath = [string]$record.target
        if ([bool]$record.existed) {
            if (-not (Test-Path -LiteralPath $targetPath -PathType Leaf)) {
                $rollbackErrors += "missing restored file: $targetPath"
            } elseif ((Get-FileSha256 -Path $targetPath) -ne [string]$record.hash) {
                $rollbackErrors += "restored hash mismatch: $targetPath"
            }
        } elseif (Test-Path -LiteralPath $targetPath) {
            $rollbackErrors += "added target still exists: $targetPath"
        }
    }

    if ($rollbackErrors.Count -gt 0) {
        throw "Upgrade rollback verification failed: $($rollbackErrors -join '; ')"
    }
}

$transactionRoot = $null
$promotionStarted = $false
$promotionCommitted = $false
$preserveTransactionEvidence = $false
$baseline = @()
$transactionJournalPath = $null
$trustedAuditBundle = $null
$stagingRoot = $null
$promotedTargets = [System.Collections.Generic.List[string]]::new()
$createdDirectories = [System.Collections.Generic.List[string]]::new()

try {
    $paths = Get-StudioSharedLayerPaths -StartDir $PSScriptRoot
    $snapshotRoot = Resolve-AbsolutePath -Path $UpstreamSnapshotDir -BaseDir (Get-Location).Path

    if (-not (Test-Path -LiteralPath $snapshotRoot -PathType Container)) {
        throw "Snapshot directory not found: $snapshotRoot"
    }

    if ($DryRun -and $Apply) {
        throw '-DryRun and -Apply are mutually exclusive. Default behavior is dry-run; specify -Apply only when you actually want to write changes.'
    }

    $mode = if ($Apply) { 'apply' } else { 'dry-run' }
    $syncMap = Read-JsonFile -Path $paths.SYNC_MAP_PATH
    if (-not $syncMap) {
        throw "Unable to read sync map: $($paths.SYNC_MAP_PATH)"
    }

    $blockedFindings = @()
    foreach ($blockedPath in @($syncMap.blockedRoots)) {
        $candidate = Join-Path $snapshotRoot ([string]$blockedPath)
        if (Test-Path -LiteralPath $candidate) {
            $blockedFindings += $candidate
        }
    }

    if ($blockedFindings.Count -gt 0) {
        throw "Snapshot contains blocked paths: $($blockedFindings -join ', ')"
    }

    Assert-UpgradeSnapshotComplete -SyncMap $syncMap -SnapshotRoot $snapshotRoot -WorkspaceRoot $paths.WORKSPACE_ROOT
    $changes = @(Get-UpgradeChanges -SyncMap $syncMap -SnapshotRoot $snapshotRoot -WorkspaceRoot $paths.WORKSPACE_ROOT)
    $verification = $null
    $reportPath = Join-Path $paths.RUNTIME_ROOT 'upgrade-report.json'
    Assert-UpgradePathPhysicalContainment -Root $paths.WORKSPACE_ROOT -Candidate $reportPath -Label 'Upgrade report target'

    if ($Apply) {
        $transactionId = [guid]::NewGuid().ToString('N')
        $transactionRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("studio-runtime-upgrade-$transactionId")
        $stagingRoot = Join-Path $transactionRoot 'candidate'
        $backupRoot = Join-Path $transactionRoot 'baseline'
        $transactionJournalPath = Join-Path $transactionRoot 'transaction-journal.json'

        $trustedAuditBundle = New-TrustedUpgradeAuditBundle -CanonicalScriptsDir $paths.SHARED_SCRIPTS_DIR -TransactionRoot $transactionRoot
        Copy-UpgradeWorkspaceSeed -WorkspaceRoot $paths.WORKSPACE_ROOT -StagingRoot $stagingRoot
        Apply-SnapshotToStaging -SyncMap $syncMap -SnapshotRoot $snapshotRoot -StagingRoot $stagingRoot
        Disable-StagedRuntimeMirror -StagingRoot $stagingRoot -TransactionRoot $transactionRoot

        # Freeze every canonical path this transaction may touch before the
        # staged bytes are inspected by the frozen trusted authority.
        $mirrorManifestPath = Join-Path $paths.RUNTIME_MIRROR_ROOT 'manifest.json'
        $invalidateRuntimeMirror = ($changes.Count -gt 0 -and (Test-Path -LiteralPath $mirrorManifestPath -PathType Leaf))
        $baselineChanges = @($changes)
        if ($invalidateRuntimeMirror) {
            $baselineChanges += [ordered]@{
                target = $mirrorManifestPath
            }
        }
        $baselineChanges += [ordered]@{
            target = $reportPath
        }
        $baseline = @(New-UpgradeBaseline -Changes $baselineChanges -WorkspaceRoot $paths.WORKSPACE_ROOT -BackupRoot $backupRoot)
        foreach ($record in $baseline) {
            $promotedTargets.Add([string]$record.target)
        }
        $promotionStarted = $true
        Write-UpgradeTransactionJournal `
            -Path $transactionJournalPath `
            -TransactionId $transactionId `
            -State 'baseline-created' `
            -WorkspaceRoot $paths.WORKSPACE_ROOT `
            -StagingRoot $stagingRoot `
            -Baseline $baseline `
            -TrustedAuditBundle $trustedAuditBundle

        $candidateVerification = Invoke-UpgradeTrustedCandidateVerification `
            -StagingRoot $stagingRoot `
            -TrustedAuditBundle $trustedAuditBundle `
            -SyncMap $syncMap `
            -WorkspaceRoot $paths.WORKSPACE_ROOT
        $verification = $candidateVerification.verification
        $auditedCandidateManifest = $candidateVerification.manifest
        Assert-UpgradeBaselineIntegrity -Baseline $baseline
        Write-UpgradeTransactionJournal `
            -Path $transactionJournalPath `
            -TransactionId $transactionId `
            -State 'trusted-staging-audit-passed' `
            -WorkspaceRoot $paths.WORKSPACE_ROOT `
            -StagingRoot $stagingRoot `
            -Baseline $baseline `
            -TrustedAuditBundle $trustedAuditBundle

        foreach ($change in $changes) {
            Assert-UpgradePathPhysicalContainment -Root $paths.WORKSPACE_ROOT -Candidate ([string]$change.target) -Label 'Upgrade promotion target'
            $stagedSource = Join-Path $stagingRoot ([System.IO.Path]::GetRelativePath($paths.WORKSPACE_ROOT, [string]$change.target))
            if (-not $auditedCandidateManifest.ContainsKey([string]$change.target)) {
                throw "Audited candidate manifest is missing promotion target: $($change.target)"
            }
            $auditedHash = [string]$auditedCandidateManifest[[string]$change.target]
            if ((Get-FileSha256 -Path $stagedSource) -ne $auditedHash) {
                throw "Staged source changed after trusted audit: $($change.target)"
            }
            Publish-UpgradeFileAtomically `
                -Source $stagedSource `
                -Target ([string]$change.target) `
                -TransactionId $transactionId `
                -CreatedDirectories $createdDirectories `
                -ExpectedSha256 $auditedHash
            $promotedTargets.Add([string]$change.target)
            if ((Get-FileSha256 -Path ([string]$change.target)) -ne (Get-FileSha256 -Path $stagedSource)) {
                throw "Promoted runtime file verification failed for: $($change.target)"
            }
        }

        if ($invalidateRuntimeMirror) {
            Assert-UpgradePathPhysicalContainment -Root $paths.WORKSPACE_ROOT -Candidate $mirrorManifestPath -Label 'Runtime mirror invalidation target'
            Remove-Item -LiteralPath $mirrorManifestPath -Force
            $promotedTargets.Add($mirrorManifestPath)
        }

        $canonicalRuntimeCheck = Invoke-UpgradeRuntimeAudit -WorkspaceRoot $paths.WORKSPACE_ROOT -TrustedAuditBundle $trustedAuditBundle
        Assert-UpgradeRuntimeAuditPassed -AuditResult $canonicalRuntimeCheck -Phase 'post-promotion verification'
        $canonicalPromotedManifest = Get-UpgradeCandidateHashManifest `
            -SyncMap $syncMap `
            -StagingRoot $paths.WORKSPACE_ROOT `
            -WorkspaceRoot $paths.WORKSPACE_ROOT
        Assert-UpgradeCandidateManifestUnchanged -Before $auditedCandidateManifest -After $canonicalPromotedManifest
        $verification.canonicalRuntimeCheckExitCode = $canonicalRuntimeCheck.EXIT_CODE
        $verification.canonicalRuntimeCheck = $canonicalRuntimeCheck.OUTPUT
        $verification.canonicalRuntimeCheckRaw = $canonicalRuntimeCheck.RAW
        $verification.runtimeMirror = if ($invalidateRuntimeMirror) { 'invalidated' } else { 'not-active-or-no-change' }
        Write-UpgradeTransactionJournal `
            -Path $transactionJournalPath `
            -TransactionId $transactionId `
            -State 'trusted-post-promotion-audit-passed' `
            -WorkspaceRoot $paths.WORKSPACE_ROOT `
            -StagingRoot $stagingRoot `
            -Baseline $baseline `
            -TrustedAuditBundle $trustedAuditBundle
    }

    $result = [ordered]@{
        MODE = $mode
        SNAPSHOT_DIR = $snapshotRoot
        SYNC_MAP_PATH = $paths.SYNC_MAP_PATH
        BLOCKED_FINDINGS = $blockedFindings
        CHANGE_COUNT = $changes.Count
        CHANGES = $changes
        VERIFICATION = $verification
        TRANSACTION = if ($Apply) {
            [ordered]@{
                stagingAudit = 'passed'
                promotion = 'committed'
                rollback = 'not-required'
            }
        } else {
            $null
        }
        REPORT_PATH = if ($Apply) { $reportPath } else { $null }
    }

    if ($Apply) {
        $reportStagingPath = Join-Path $transactionRoot 'upgrade-report.json'
        Write-JsonFile -Path $reportStagingPath -Data $result -Depth 10
        Assert-UpgradePathPhysicalContainment -Root $paths.WORKSPACE_ROOT -Candidate $reportPath -Label 'Upgrade report promotion target'
        Publish-UpgradeFileAtomically -Source $reportStagingPath -Target $reportPath -TransactionId $transactionId -CreatedDirectories $createdDirectories
        $promotionCommitted = $true
    }
} catch {
    $failureMessage = $_.Exception.Message
    if ($promotionStarted -and -not $promotionCommitted) {
        try {
            Restore-UpgradeTargets -Baseline $baseline -PromotedTargets $promotedTargets.ToArray() -CreatedDirectories $createdDirectories -TransactionId $transactionId
            $failureMessage = "$failureMessage Canonical runtime rollback completed and was verified."
        } catch {
            $preserveTransactionEvidence = $true
            $rollbackFailure = $_.Exception.Message
            try {
                Write-UpgradeTransactionJournal `
                    -Path $transactionJournalPath `
                    -TransactionId $transactionId `
                    -State 'rollback-failed' `
                    -WorkspaceRoot $paths.WORKSPACE_ROOT `
                    -StagingRoot $stagingRoot `
                    -Baseline $baseline `
                    -TrustedAuditBundle $trustedAuditBundle `
                    -Failure $rollbackFailure
            } catch {
                $rollbackFailure = "$rollbackFailure Transaction journal update also failed: $($_.Exception.Message)"
            }
            $failureMessage = "$failureMessage CRITICAL: $rollbackFailure Recovery evidence retained at: $transactionRoot"
        }
    }

    Write-Error -Message $failureMessage -ErrorAction Continue
    exit 1
} finally {
    if (-not $preserveTransactionEvidence -and $transactionRoot -and (Test-Path -LiteralPath $transactionRoot)) {
        Remove-Item -LiteralPath $transactionRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if ($Json) {
    [PSCustomObject]$result | ConvertTo-Json -Depth 10
    exit 0
}

Write-Output ("Mode: {0}" -f $mode)
Write-Output ("Snapshot: {0}" -f $snapshotRoot)
Write-Output ("Changes detected: {0}" -f $changes.Count)

if ($Apply) {
    Write-Output ("Report: {0}" -f $reportPath)
}
