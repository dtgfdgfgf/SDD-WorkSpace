#!/usr/bin/env pwsh
#Requires -Module Pester

BeforeAll {
    . "$PSScriptRoot/governance.config.ps1"
    $script:setupEciScript = Join-Path $WorkspaceRoot 'studio/scripts/powershell/setup-eci.ps1'
    $script:commonScript = Join-Path $WorkspaceRoot 'studio/scripts/powershell/common.ps1'

    function script:Write-EciEntryFixture {
        param(
            [string]$PrimaryStatus = 'ROUTE_TO_ECI',
            [string]$EciReentryStatus = 'PENDING',
            [string]$EciEvidenceSha256 = 'N/A',
            [switch]$SkipTrigger,
            [switch]$StartDossier
        )

        New-Item -ItemType Directory -Path $script:featureDir -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:projectRoot '.specify/memory') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:featureDir 'readiness/eci') -Force | Out-Null
        '# Project Constitution' |
            Set-Content -LiteralPath (Join-Path $script:projectRoot '.specify/memory/constitution.md') -NoNewline
        "# Specification`n`n**Version**: 1.0.0`n" |
            Set-Content -LiteralPath (Join-Path $script:featureDir 'spec.md') -NoNewline
        @"
# Readiness

**Primary Status**: $PrimaryStatus
**ECI Re-entry Status**: $EciReentryStatus
**ECI Evidence SHA-256**: $EciEvidenceSha256
**Intent Ledger Requirement**: Not Required
"@ | Set-Content -LiteralPath (Join-Path $script:featureDir 'readiness/readiness-assessment.md') -NoNewline
        if (-not $SkipTrigger) {
            '# ECI Trigger' |
                Set-Content -LiteralPath (Join-Path $script:featureDir 'readiness/eci-trigger.md') -NoNewline
        }
        if ($StartDossier) {
            '# Started ECI Assessment' |
                Set-Content -LiteralPath (Join-Path $script:featureDir 'readiness/eci/eci-assessment.md') -NoNewline
        }
    }

    function script:Invoke-SetupEci {
        param([string[]]$ExtraArgs = @())

        $argv = @('-FeatureDir', $script:featureDir, '-Json') + $ExtraArgs
        $output = pwsh -NoProfile -File $script:setupEciScript @argv 2>&1
        $exitCode = $LASTEXITCODE
        $parsed = $null
        try { $parsed = ($output -join "`n") | ConvertFrom-Json } catch { $parsed = $null }
        return [PSCustomObject]@{
            ExitCode = $exitCode
            Output = $output
            Result = $parsed
        }
    }

    function script:Get-MarkerPath {
        return Join-Path $script:projectRoot ".workflow/runs/$script:featureName/eci-requirement.json"
    }
}

Describe 'setup-eci non-bypassable entry gate' {
    BeforeEach {
        $script:oldProjectRoot = $env:SDD_PROJECT_ROOT
        $script:oldStudioRoot = $env:SDD_STUDIO_ROOT
        $script:oldSpecifyFeature = $env:SPECIFY_FEATURE

        $script:projectRoot = Join-Path $TestDrive ("eci-project-{0}" -f [guid]::NewGuid().ToString('N'))
        $script:featureName = '001-eci-fixture'
        $script:featureDir = Join-Path $script:projectRoot "specs/$script:featureName"
        $env:SDD_PROJECT_ROOT = $script:projectRoot
        $env:SDD_STUDIO_ROOT = Join-Path $WorkspaceRoot 'studio'
        $env:SPECIFY_FEATURE = $script:featureName
    }

    AfterEach {
        $env:SDD_PROJECT_ROOT = $script:oldProjectRoot
        $env:SDD_STUDIO_ROOT = $script:oldStudioRoot
        $env:SPECIFY_FEATURE = $script:oldSpecifyFeature
    }

    It 'latches the exact initial ROUTE_TO_ECI and PENDING intake before ECI reads artifacts' {
        Write-EciEntryFixture

        $run = Invoke-SetupEci

        $run.ExitCode | Should -Be 0 -Because ($run.Output -join "`n")
        $run.Result.READY | Should -BeTrue
        $run.Result.READINESS_PRIMARY_STATUS | Should -BeExactly 'ROUTE_TO_ECI'
        $run.Result.ECI_REENTRY_STATUS | Should -BeExactly 'PENDING'
        $run.Result.ECI_REQUIRED | Should -BeTrue
        $run.Result.ECI_REQUIREMENT_LATCHED | Should -BeTrue
        $run.Result.ECI_REQUIREMENT_CREATED | Should -BeTrue
        $run.Result.ECI_REQUIREMENT_PATH | Should -BeExactly (Get-MarkerPath)

        $marker = Get-Content -LiteralPath (Get-MarkerPath) -Raw | ConvertFrom-Json
        @($marker.PSObject.Properties.Name) | Should -Be @(
            'schema_version',
            'feature',
            'feature_path',
            'eci_required',
            'recorded_at'
        )
        $marker.schema_version | Should -BeExactly '1.0.0'
        $marker.feature | Should -BeExactly $script:featureName
        $marker.feature_path | Should -BeExactly "specs/$script:featureName"
        $marker.eci_required | Should -BeOfType ([bool])
        $marker.eci_required | Should -BeTrue
    }

    It 'is idempotent in the narrow deferred intake state and never overwrites a valid marker' {
        Write-EciEntryFixture
        $first = Invoke-SetupEci
        $first.ExitCode | Should -Be 0
        $before = [System.IO.File]::ReadAllBytes((Get-MarkerPath))

        $second = Invoke-SetupEci

        $second.ExitCode | Should -Be 0 -Because ($second.Output -join "`n")
        $second.Result.ECI_REQUIREMENT_LATCHED | Should -BeTrue
        $second.Result.ECI_REQUIREMENT_CREATED | Should -BeFalse
        [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes((Get-MarkerPath))) |
            Should -BeExactly ([System.Convert]::ToBase64String($before))
    }

    It 'atomically publishes exactly one winner under concurrent marker creation' {
        Write-EciEntryFixture
        $workerPath = Join-Path $TestDrive ("eci-worker-{0}.ps1" -f [guid]::NewGuid().ToString('N'))
        @'
param([string]$Common, [string]$FeatureDir, [string]$ProjectRoot)
$ErrorActionPreference = 'Stop'
. $Common
$result = Initialize-EciRequirementMarker -FeatureDir $FeatureDir -ProjectRoot $ProjectRoot
$result | ConvertTo-Json -Compress
'@ | Set-Content -LiteralPath $workerPath -NoNewline -Encoding utf8

        $processes = @()
        $outputs = @()
        for ($index = 0; $index -lt 3; $index++) {
            $outputPath = Join-Path $TestDrive ("eci-worker-{0}-{1}.json" -f $index, [guid]::NewGuid().ToString('N'))
            $errorPath = Join-Path $TestDrive ("eci-worker-{0}-{1}.err" -f $index, [guid]::NewGuid().ToString('N'))
            $outputs += $outputPath
            $processes += Start-Process `
                -FilePath (Join-Path $PSHOME 'pwsh.exe') `
                -ArgumentList @(
                    '-NoProfile',
                    '-File',
                    $workerPath,
                    '-Common',
                    $script:commonScript,
                    '-FeatureDir',
                    $script:featureDir,
                    '-ProjectRoot',
                    $script:projectRoot
                ) `
                -RedirectStandardOutput $outputPath `
                -RedirectStandardError $errorPath `
                -WindowStyle Hidden `
                -PassThru
        }
        $processes | Wait-Process

        @($processes | Where-Object ExitCode -ne 0).Count | Should -Be 0
        $results = @($outputs | ForEach-Object {
            (Get-Content -LiteralPath $_ -Raw) | ConvertFrom-Json
        })
        @($results | Where-Object CREATED).Count | Should -Be 1
        @($results | Where-Object LATCHED).Count | Should -Be 3
        @(Get-ChildItem -LiteralPath (Split-Path -Parent (Get-MarkerPath)) -Filter '*.tmp').Count |
            Should -Be 0
    }

    It 'denies and preserves an existing invalid marker for <Kind>' -ForEach @(
        @{
            Kind = 'malformed JSON'
            Content = '{bad'
        }
        @{
            Kind = 'wrong feature identity'
            Content = '{"schema_version":"1.0.0","feature":"999-other","feature_path":"specs/001-eci-fixture","eci_required":true,"recorded_at":"2026-07-18T00:00:00.0000000+00:00"}'
        }
        @{
            Kind = 'absolute feature path'
            Content = '{"schema_version":"1.0.0","feature":"001-eci-fixture","feature_path":"C:\\escape\\001-eci-fixture","eci_required":true,"recorded_at":"2026-07-18T00:00:00.0000000+00:00"}'
        }
        @{
            Kind = 'string Boolean'
            Content = '{"schema_version":"1.0.0","feature":"001-eci-fixture","feature_path":"specs/001-eci-fixture","eci_required":"true","recorded_at":"2026-07-18T00:00:00.0000000+00:00"}'
        }
        @{
            Kind = 'false Boolean'
            Content = '{"schema_version":"1.0.0","feature":"001-eci-fixture","feature_path":"specs/001-eci-fixture","eci_required":false,"recorded_at":"2026-07-18T00:00:00.0000000+00:00"}'
        }
        @{
            Kind = 'null Boolean'
            Content = '{"schema_version":"1.0.0","feature":"001-eci-fixture","feature_path":"specs/001-eci-fixture","eci_required":null,"recorded_at":"2026-07-18T00:00:00.0000000+00:00"}'
        }
        @{
            Kind = 'unexpected property'
            Content = '{"schema_version":"1.0.0","feature":"001-eci-fixture","feature_path":"specs/001-eci-fixture","eci_required":true,"recorded_at":"2026-07-18T00:00:00.0000000+00:00","bypass":true}'
        }
    ) {
        Write-EciEntryFixture
        $markerPath = Get-MarkerPath
        New-Item -ItemType Directory -Path (Split-Path -Parent $markerPath) -Force | Out-Null
        $Content | Set-Content -LiteralPath $markerPath -NoNewline -Encoding utf8
        $before = [System.IO.File]::ReadAllBytes($markerPath)

        $run = Invoke-SetupEci

        $run.ExitCode | Should -Not -Be 0
        $run.Result.READY | Should -BeFalse
        ($run.Output -join "`n") | Should -Match 'eci-requirement-marker-invalid'
        [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes($markerPath)) |
            Should -BeExactly ([System.Convert]::ToBase64String($before))
    }

    It 'denies a non-ECI readiness route without creating a marker' {
        Write-EciEntryFixture -PrimaryStatus 'READY_FOR_PLAN' -EciReentryStatus 'NOT_REQUIRED'

        $run = Invoke-SetupEci

        $run.ExitCode | Should -Not -Be 0
        $run.Result.READY | Should -BeFalse
        (Get-MarkerPath) | Should -Not -Exist
    }

    It 'does not let DeferEciDossier bypass a missing marker once dossier work has started' {
        Write-EciEntryFixture -StartDossier

        $run = Invoke-SetupEci

        $run.ExitCode | Should -Not -Be 0
        ($run.Result.BLOCKERS -join "`n") | Should -Match 'eci-requirement-marker-missing'
        (Get-MarkerPath) | Should -Not -Exist
    }

    It 'requires the ECI trigger even in the narrow deferred intake state' {
        Write-EciEntryFixture -SkipTrigger

        $run = Invoke-SetupEci

        $run.ExitCode | Should -Not -Be 0
        ($run.Result.BLOCKERS -join "`n") | Should -Match 'eci-trigger-missing'
        (Get-MarkerPath) | Should -Not -Exist
    }

    It 'rejects an explicit feature path outside the configured project specs root' {
        Write-EciEntryFixture
        $outside = Join-Path $TestDrive 'outside/specs/999-outside'
        New-Item -ItemType Directory -Path $outside -Force | Out-Null

        $output = pwsh -NoProfile -File $script:setupEciScript -FeatureDir $outside -Json 2>&1

        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match 'escapes project root'
    }
}
