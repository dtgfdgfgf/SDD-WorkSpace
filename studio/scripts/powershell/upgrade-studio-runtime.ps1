#!/usr/bin/env pwsh

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

$paths = Get-StudioSharedLayerPaths -StartDir $PSScriptRoot
$snapshotRoot = Resolve-AbsolutePath -Path $UpstreamSnapshotDir -BaseDir (Get-Location).Path

if (-not (Test-Path -LiteralPath $snapshotRoot -PathType Container)) {
    Write-Error "Snapshot directory not found: $snapshotRoot"
    exit 1
}

if ($DryRun -and $Apply) {
    Write-Error '-DryRun and -Apply are mutually exclusive. Default behavior is dry-run; specify -Apply only when you actually want to write changes.'
    exit 1
}

$mode = if ($Apply) { 'apply' } else { 'dry-run' }
$syncMap = Read-JsonFile -Path $paths.SYNC_MAP_PATH
if (-not $syncMap) {
    Write-Error "Unable to read sync map: $($paths.SYNC_MAP_PATH)"
    exit 1
}

$blockedFindings = @()
foreach ($blockedPath in @($syncMap.blockedRoots)) {
    $candidate = Join-Path $snapshotRoot $blockedPath
    if (Test-Path -LiteralPath $candidate) {
        $blockedFindings += $candidate
    }
}

if ($blockedFindings.Count -gt 0) {
    Write-Error ("Snapshot contains blocked paths: {0}" -f ($blockedFindings -join ', '))
    exit 1
}

$changes = @()

foreach ($mapping in @($syncMap.mappings)) {
    $sourcePath = Join-Path $snapshotRoot $mapping.source
    $targetPath = Join-Path $paths.WORKSPACE_ROOT $mapping.target

    if ($mapping.kind -eq 'directory') {
        $sourceFiles = Get-RelativeFileMap -Path $sourcePath
        foreach ($relativePath in $sourceFiles.Keys) {
            $sourceFile = $sourceFiles[$relativePath]
            $targetFile = Join-Path $targetPath $relativePath
            $changeType = Get-FileChangeType -SourcePath $sourceFile -TargetPath $targetFile
            if ($changeType -ne 'unchanged') {
                $changes += [ordered]@{
                    mapping    = $mapping.target
                    kind       = 'directory'
                    relative   = $relativePath
                    source     = $sourceFile
                    target     = $targetFile
                    changeType = $changeType
                }
            }

            if ($Apply -and $changeType -in @('add', 'update')) {
                $targetParent = Split-Path -Parent $targetFile
                if (-not (Test-Path -LiteralPath $targetParent)) {
                    New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
                }
                Copy-Item -LiteralPath $sourceFile -Destination $targetFile -Force
            }
        }
    } else {
        $changeType = Get-FileChangeType -SourcePath $sourcePath -TargetPath $targetPath
        if ($changeType -ne 'unchanged') {
            $changes += [ordered]@{
                mapping    = $mapping.target
                kind       = 'file'
                relative   = $null
                source     = $sourcePath
                target     = $targetPath
                changeType = $changeType
            }
        }

        if ($Apply -and $changeType -in @('add', 'update')) {
            $targetParent = Split-Path -Parent $targetPath
            if (-not (Test-Path -LiteralPath $targetParent)) {
                New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
            }
            Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force
        }
    }
}

$verification = $null
$reportPath = Join-Path $paths.RUNTIME_ROOT 'upgrade-report.json'

if ($Apply) {
    if (-not (Test-Path -LiteralPath $paths.RUNTIME_ROOT)) {
        New-Item -ItemType Directory -Path $paths.RUNTIME_ROOT -Force | Out-Null
    }

    $tempSkillsOut = Join-Path $env:TEMP ('studio-runtime-skill-smoke-' + [guid]::NewGuid().ToString('N'))
    $tempMirrorOut = Join-Path $env:TEMP ('studio-runtime-extension-smoke-' + [guid]::NewGuid().ToString('N'))
    $runtimeCheckDetailed = Invoke-JsonScriptDetailed -ScriptPath (Join-Path $paths.SHARED_SCRIPTS_DIR 'check-speckit-runtime.ps1') -Arguments @('-Json')
    $runtimeAuditFailed = ($runtimeCheckDetailed.EXIT_CODE -ne 0 -or -not $runtimeCheckDetailed.OUTPUT -or -not $runtimeCheckDetailed.OUTPUT.VALID)

    $verification = [ordered]@{
        version        = Invoke-JsonScript -ScriptPath (Join-Path $paths.SHARED_SCRIPTS_DIR 'get-speckit-version.ps1') -Arguments @('-Json')
        runtimeCheckExitCode = $runtimeCheckDetailed.EXIT_CODE
        runtimeCheck   = $runtimeCheckDetailed.OUTPUT
        runtimeCheckRaw = $runtimeCheckDetailed.RAW
        skillsExport   = $null
        extensionExport = $null
    }

    if (-not $runtimeAuditFailed) {
        $verification.skillsExport = Invoke-JsonScript -ScriptPath (Join-Path $paths.SHARED_SCRIPTS_DIR 'export-agent-skills.ps1') -Arguments @('-Target', 'codex', '-OutputDir', $tempSkillsOut, '-Force', '-Json')
        $verification.extensionExport = Invoke-JsonScript -ScriptPath (Join-Path $paths.SHARED_SCRIPTS_DIR 'export-extensions.ps1') -Arguments @('-OutputDir', $tempMirrorOut, '-Force', '-Json')
    } else {
        $verification.runtimeAuditStatus = 'failed'
        $verification.runtimeAuditFailure = 'Shared runtime contract audit failed after apply; smoke exports were skipped.'
    }
}

$result = [ordered]@{
    MODE              = $mode
    SNAPSHOT_DIR      = $snapshotRoot
    SYNC_MAP_PATH     = $paths.SYNC_MAP_PATH
    BLOCKED_FINDINGS  = $blockedFindings
    CHANGE_COUNT      = $changes.Count
    CHANGES           = $changes
    VERIFICATION      = $verification
    REPORT_PATH       = if ($Apply) { $reportPath } else { $null }
}

if ($Apply) {
    Write-JsonFile -Path $reportPath -Data $result -Depth 10

    if (
        $verification -and (
            $verification.runtimeCheckExitCode -ne 0 -or
            -not $verification.runtimeCheck -or
            -not $verification.runtimeCheck.VALID
        )
    ) {
        Write-Error ("Shared runtime contract audit failed after apply. Review report: {0}" -f $reportPath)
        exit 1
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
