#!/usr/bin/env pwsh
#Requires -Module Pester

# ============================================================
# Patch 7: validate-feature-structure.ps1 (M5)
# Per-feature SDD §11 structural validator. Output is structured
# advisory; consumer projects can run it as warnings via
# check-speckit-runtime.ps1.
# ============================================================

BeforeAll {
    . "$PSScriptRoot/governance.config.ps1"
    $script:validatorScript = Join-Path $WorkspaceRoot 'studio/scripts/powershell/validate-feature-structure.ps1'

    function script:Write-FeatureFixture {
        param(
            [string]$FeatureDir,
            [string]$SpecBody = "# Specification: Test`n`n**Version:** 1.0.0`n",
            [string]$ReadinessBody = "# Readiness`n`n**Primary Status**: READY_FOR_PLAN`n**ECI Re-entry Status**: NOT_REQUIRED`n**ECI Evidence SHA-256**: N/A`n**Intent Ledger Requirement**: Not Required`n",
            [hashtable]$Optional = @{}
        )
        New-Item -ItemType Directory -Path $FeatureDir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $FeatureDir 'spec.md') -Value $SpecBody -NoNewline -Encoding utf8

        if ($ReadinessBody) {
            $rdir = Join-Path $FeatureDir 'readiness'
            New-Item -ItemType Directory -Path $rdir -Force | Out-Null
            New-Item -ItemType Directory -Path (Join-Path $rdir 'eci') -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $rdir 'readiness-assessment.md') -Value $ReadinessBody -NoNewline -Encoding utf8
        }

        foreach ($k in $Optional.Keys) {
            Set-Content -LiteralPath (Join-Path $FeatureDir $k) -Value $Optional[$k] -NoNewline -Encoding utf8
        }
    }

    function script:Write-EciDossier {
        param(
            [Parameter(Mandatory = $true)][string]$FeatureDir,
            [string]$AuthorizationOutcome = 'READY_FOR_MAINLINE_IMPLEMENTATION',
            [string]$AuthorizationSuffix = '',
            [switch]$CompleteReadiness
        )

        $readinessDir = Join-Path $FeatureDir 'readiness'
        $eciDir = Join-Path $readinessDir 'eci'
        New-Item -ItemType Directory -Path $eciDir -Force | Out-Null
        "# ECI Trigger`n`n**Provider**: provider-a`n**Scope**: read-only`n" |
            Set-Content -LiteralPath (Join-Path $readinessDir 'eci-trigger.md') -NoNewline
        @"
# ECI Assessment

**ECI Level**: ``STANDARD_ECI``
"@ | Set-Content -LiteralPath (Join-Path $eciDir 'eci-assessment.md') -NoNewline
        "# ECI Source Manifest`n`nCanonical source evidence.`n" |
            Set-Content -LiteralPath (Join-Path $eciDir 'source-manifest.md') -NoNewline
        "# ECI Adoption Record`n`nGoverned adoption boundary.`n" |
            Set-Content -LiteralPath (Join-Path $eciDir 'adoption-record.md') -NoNewline
        @"
# ECI Authorization Record

**Authorization Outcome**: ``$AuthorizationOutcome``
$AuthorizationSuffix
"@ | Set-Content -LiteralPath (Join-Path $eciDir 'authorization-record.md') -NoNewline

        if ($CompleteReadiness) {
            Set-EciReadinessComplete -FeatureDir $FeatureDir
        }

        Write-EciRequirementMarker -FeatureDir $FeatureDir
    }

    function script:Write-EciRequirementMarker {
        param([Parameter(Mandatory = $true)][string]$FeatureDir)

        $feature = Split-Path -Leaf $FeatureDir
        $specsRoot = Split-Path -Parent $FeatureDir
        $projectRoot = Split-Path -Parent $specsRoot
        $markerDir = Join-Path $projectRoot ".workflow/runs/$feature"
        New-Item -ItemType Directory -Path $markerDir -Force | Out-Null
        [ordered]@{
            schema_version = '1.0.0'
            feature = $feature
            feature_path = "specs/$feature"
            eci_required = $true
            recorded_at = '2026-07-18T00:00:00.0000000+00:00'
        } | ConvertTo-Json -Compress |
            Set-Content -LiteralPath (Join-Path $markerDir 'eci-requirement.json') -NoNewline -Encoding utf8
    }

    function script:Get-EciEvidenceDigest {
        param([Parameter(Mandatory = $true)][string]$FeatureDir)

        $readinessDir = Join-Path $FeatureDir 'readiness'
        $relativePaths = @(
            'eci-trigger.md',
            'eci/eci-assessment.md',
            'eci/source-manifest.md',
            'eci/adoption-record.md',
            'eci/authorization-record.md'
        )
        $hasher = [System.Security.Cryptography.IncrementalHash]::CreateHash(
            [System.Security.Cryptography.HashAlgorithmName]::SHA256
        )
        try {
            foreach ($relativePath in $relativePaths) {
                $pathBytes = [System.Text.Encoding]::UTF8.GetBytes($relativePath)
                $pathLengthBytes = [System.BitConverter]::GetBytes([uint32]$pathBytes.Length)
                if ([System.BitConverter]::IsLittleEndian) {
                    [System.Array]::Reverse($pathLengthBytes)
                }

                $contentBytes = [System.IO.File]::ReadAllBytes(
                    (Join-Path $readinessDir $relativePath)
                )
                $contentLengthBytes = [System.BitConverter]::GetBytes([uint64]$contentBytes.LongLength)
                if ([System.BitConverter]::IsLittleEndian) {
                    [System.Array]::Reverse($contentLengthBytes)
                }

                $hasher.AppendData($pathLengthBytes)
                $hasher.AppendData($pathBytes)
                $hasher.AppendData($contentLengthBytes)
                $hasher.AppendData($contentBytes)
            }
            return [System.Convert]::ToHexString($hasher.GetHashAndReset()).ToLowerInvariant()
        } finally {
            $hasher.Dispose()
        }
    }

    function script:Set-EciReadinessComplete {
        param([Parameter(Mandatory = $true)][string]$FeatureDir)

        $assessmentPath = Join-Path $FeatureDir 'readiness/readiness-assessment.md'
        $digest = Get-EciEvidenceDigest -FeatureDir $FeatureDir
        $content = Get-Content -LiteralPath $assessmentPath -Raw
        $content = $content -replace '(?m)^\*\*ECI Re-entry Status\*\*:\s*.+$', '**ECI Re-entry Status**: COMPLETE'
        $content = $content -replace '(?m)^\*\*ECI Evidence SHA-256\*\*:\s*.+$', "**ECI Evidence SHA-256**: $digest"
        $content | Set-Content -LiteralPath $assessmentPath -NoNewline
    }
}

Describe 'validate-feature-structure (M5)' {
    BeforeEach {
        $projectRoot = Join-Path $TestDrive ("project-{0}" -f ([System.Guid]::NewGuid().ToString('N')))
        $script:featureDir = Join-Path $projectRoot ("specs/feat-{0}" -f ([System.Guid]::NewGuid().ToString('N')))
    }

    It 'reports VALID for a minimal governed feature with readiness and the ECI container' {
        Write-FeatureFixture -FeatureDir $script:featureDir
        $output = pwsh -NoProfile -File $script:validatorScript -FeatureDir $script:featureDir -Json
        $LASTEXITCODE | Should -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        $result.VALID | Should -BeTrue
        $result.ERROR_COUNT | Should -Be 0
    }

    It 'accepts COMPLETE only when Readiness is bound to the canonical framed five-file evidence digest' {
        Write-FeatureFixture -FeatureDir $script:featureDir
        Write-EciDossier -FeatureDir $script:featureDir -CompleteReadiness
        $expectedDigest = Get-EciEvidenceDigest -FeatureDir $script:featureDir

        $output = pwsh -NoProfile -File $script:validatorScript -FeatureDir $script:featureDir -Json
        $LASTEXITCODE | Should -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        $result.ECI_REENTRY_STATUS | Should -Be 'COMPLETE'
        $result.ECI_EVIDENCE_SHA256 | Should -Be $expectedDigest
        $result.ECI_ACTUAL_EVIDENCE_SHA256 | Should -Be $expectedDigest
        $result.PSObject.Properties.Name | Should -Not -Contain 'ECI_DOSSIER_SHA256'
        $result.PSObject.Properties.Name | Should -Not -Contain 'ECI_ACTUAL_DOSSIER_SHA256'
        $result.ECI_REQUIRED | Should -BeTrue
        $result.ECI_REQUIREMENT_LATCHED | Should -BeTrue
        $result.ECI_REQUIREMENT_PATH | Should -Match '[\\/]\.workflow[\\/]runs[\\/]'
    }

    It 'fails closed when a complete ECI dossier was never latched by setup-eci' {
        Write-FeatureFixture -FeatureDir $script:featureDir
        Write-EciDossier -FeatureDir $script:featureDir -CompleteReadiness
        $markerPath = Join-Path (
            Split-Path -Parent (Split-Path -Parent $script:featureDir)
        ) ".workflow/runs/$(Split-Path -Leaf $script:featureDir)/eci-requirement.json"
        Remove-Item -LiteralPath $markerPath -Force

        $output = pwsh -NoProfile -File $script:validatorScript -FeatureDir $script:featureDir -Json
        $LASTEXITCODE | Should -Not -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        $result.VALID | Should -BeFalse
        $result.ERRORS.id | Should -Contain 'eci-requirement-marker-missing'
        $result.ECI_REQUIREMENT_LATCHED | Should -BeFalse
    }

    It 'retains ECI_REQUIRED and denies combined canonical artifact deletion plus NOT_REQUIRED rewrite while the marker remains' {
        Write-FeatureFixture -FeatureDir $script:featureDir
        Write-EciDossier -FeatureDir $script:featureDir -CompleteReadiness
        Remove-Item -LiteralPath (Join-Path $script:featureDir 'readiness/eci-trigger.md') -Force
        Get-ChildItem -LiteralPath (Join-Path $script:featureDir 'readiness/eci') -File |
            Remove-Item -Force
        @"
# Readiness

**Primary Status**: READY_FOR_PLAN
**ECI Re-entry Status**: NOT_REQUIRED
**ECI Evidence SHA-256**: N/A
**Intent Ledger Requirement**: Not Required
"@ | Set-Content -LiteralPath (Join-Path $script:featureDir 'readiness/readiness-assessment.md') -NoNewline

        $output = pwsh -NoProfile -File $script:validatorScript -FeatureDir $script:featureDir -Json
        $LASTEXITCODE | Should -Not -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        $result.ECI_REQUIRED | Should -BeTrue
        $result.ECI_REQUIREMENT_LATCHED | Should -BeTrue
        $result.ERRORS.id | Should -Contain 'eci-requirement-latched-not-required'
        $result.ERRORS.id | Should -Contain 'eci-requirement-latched-digest-na'
        $result.ERRORS.id | Should -Contain 'eci-trigger-missing'
    }

    It 'fails closed when ECI Re-entry Status is missing from Readiness' {
        Write-FeatureFixture -FeatureDir $script:featureDir -ReadinessBody @"
# Readiness

**Primary Status**: READY_FOR_PLAN
**ECI Evidence SHA-256**: N/A
**Intent Ledger Requirement**: Not Required
"@

        $output = pwsh -NoProfile -File $script:validatorScript -FeatureDir $script:featureDir -Json
        $LASTEXITCODE | Should -Not -Be 0
        (($output -join "`n") | ConvertFrom-Json).ERRORS.id |
            Should -Contain 'readiness-eci-reentry-status-invalid'
    }

    It 'fails closed when ECI Evidence SHA-256 is missing from Readiness' {
        Write-FeatureFixture -FeatureDir $script:featureDir -ReadinessBody @"
# Readiness

**Primary Status**: READY_FOR_PLAN
**ECI Re-entry Status**: NOT_REQUIRED
**Intent Ledger Requirement**: Not Required
"@

        $output = pwsh -NoProfile -File $script:validatorScript -FeatureDir $script:featureDir -Json
        $LASTEXITCODE | Should -Not -Be 0
        (($output -join "`n") | ConvertFrom-Json).ERRORS.id |
            Should -Contain 'readiness-eci-evidence-sha256-invalid'
    }

    It 'fails closed on duplicate ECI re-entry evidence field <Field>' -ForEach @(
        @{ Field = 'ECI Re-entry Status'; ExtraValue = 'COMPLETE'; ExpectedId = 'readiness-eci-reentry-status-invalid' }
        @{ Field = 'ECI Evidence SHA-256'; ExtraValue = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'; ExpectedId = 'readiness-eci-evidence-sha256-invalid' }
    ) {
        Write-FeatureFixture -FeatureDir $script:featureDir
        Add-Content -LiteralPath (Join-Path $script:featureDir 'readiness/readiness-assessment.md') `
            -Value "`n**$Field**: $ExtraValue"

        $output = pwsh -NoProfile -File $script:validatorScript -FeatureDir $script:featureDir -Json
        $LASTEXITCODE | Should -Not -Be 0
        (($output -join "`n") | ConvertFrom-Json).ERRORS.id | Should -Contain $ExpectedId
    }

    It 'fails closed on malformed ECI Evidence SHA-256 <Kind>' -ForEach @(
        @{ Kind = 'short'; Digest = 'abc123' }
        @{ Kind = 'uppercase'; Digest = ('A' * 64) }
        @{ Kind = 'placeholder'; Digest = '<digest>' }
    ) {
        Write-FeatureFixture -FeatureDir $script:featureDir -ReadinessBody @"
# Readiness

**Primary Status**: READY_FOR_PLAN
**ECI Re-entry Status**: COMPLETE
**ECI Evidence SHA-256**: $Digest
**Intent Ledger Requirement**: Not Required
"@

        $output = pwsh -NoProfile -File $script:validatorScript -FeatureDir $script:featureDir -Json
        $LASTEXITCODE | Should -Not -Be 0
        (($output -join "`n") | ConvertFrom-Json).ERRORS.id |
            Should -Contain 'readiness-eci-evidence-sha256-invalid'
    }

    It 'rejects a stale COMPLETE digest after any ECI evidence raw byte changes' {
        Write-FeatureFixture -FeatureDir $script:featureDir
        Write-EciDossier -FeatureDir $script:featureDir -CompleteReadiness
        Add-Content -LiteralPath (Join-Path $script:featureDir 'readiness/eci/source-manifest.md') `
            -Value 'Tampered after Readiness.'

        $output = pwsh -NoProfile -File $script:validatorScript -FeatureDir $script:featureDir -Json
        $LASTEXITCODE | Should -Not -Be 0
        (($output -join "`n") | ConvertFrom-Json).ERRORS.id |
            Should -Contain 'eci-evidence-sha256-mismatch'
    }

    It 'rejects a stale COMPLETE digest after only the trigger provider and scope are changed' {
        Write-FeatureFixture -FeatureDir $script:featureDir
        Write-EciDossier -FeatureDir $script:featureDir -CompleteReadiness
        @"
# ECI Trigger

**Provider**: provider-b
**Scope**: write-enabled
"@ | Set-Content -LiteralPath (Join-Path $script:featureDir 'readiness/eci-trigger.md') -NoNewline

        $output = pwsh -NoProfile -File $script:validatorScript -FeatureDir $script:featureDir -Json
        $LASTEXITCODE | Should -Not -Be 0
        (($output -join "`n") | ConvertFrom-Json).ERRORS.id |
            Should -Contain 'eci-evidence-sha256-mismatch'
    }

    It 'rejects a boundary shift even when the unframed concatenation of evidence bytes is unchanged' {
        Write-FeatureFixture -FeatureDir $script:featureDir
        Write-EciDossier -FeatureDir $script:featureDir -CompleteReadiness
        $eciDir = Join-Path $script:featureDir 'readiness/eci'
        $firstPath = Join-Path $eciDir 'eci-assessment.md'
        $secondPath = Join-Path $eciDir 'source-manifest.md'
        $firstBytes = [System.IO.File]::ReadAllBytes($firstPath)
        $secondBytes = [System.IO.File]::ReadAllBytes($secondPath)
        $unframedPairBefore = [System.Convert]::ToBase64String(
            [byte[]]($firstBytes + $secondBytes)
        )
        $movedByte = $firstBytes[$firstBytes.Length - 1]
        [System.IO.File]::WriteAllBytes(
            $firstPath,
            [byte[]]$firstBytes[0..($firstBytes.Length - 2)]
        )
        [System.IO.File]::WriteAllBytes(
            $secondPath,
            [byte[]](@($movedByte) + $secondBytes)
        )
        $unframedPairAfter = [System.Convert]::ToBase64String(
            [byte[]](
                [System.IO.File]::ReadAllBytes($firstPath) +
                [System.IO.File]::ReadAllBytes($secondPath)
            )
        )
        $unframedPairAfter | Should -Be $unframedPairBefore

        $output = pwsh -NoProfile -File $script:validatorScript -FeatureDir $script:featureDir -Json
        $LASTEXITCODE | Should -Not -Be 0
        (($output -join "`n") | ConvertFrom-Json).ERRORS.id |
            Should -Contain 'eci-evidence-sha256-mismatch'
    }

    It 'rejects READY plus a dossier when Readiness still declares ECI NOT_REQUIRED' {
        Write-FeatureFixture -FeatureDir $script:featureDir
        Write-EciDossier -FeatureDir $script:featureDir

        $output = pwsh -NoProfile -File $script:validatorScript -FeatureDir $script:featureDir -Json
        $LASTEXITCODE | Should -Not -Be 0
        (($output -join "`n") | ConvertFrom-Json).ERRORS.id |
            Should -Contain 'eci-reentry-not-required-artifacts-present'
    }

    It 'rejects COMPLETE after the trigger and all four dossier files are deleted' {
        Write-FeatureFixture -FeatureDir $script:featureDir
        Write-EciDossier -FeatureDir $script:featureDir -CompleteReadiness
        Remove-Item -LiteralPath (Join-Path $script:featureDir 'readiness/eci-trigger.md') -Force
        Get-ChildItem -LiteralPath (Join-Path $script:featureDir 'readiness/eci') -File |
            Remove-Item -Force

        $output = pwsh -NoProfile -File $script:validatorScript -FeatureDir $script:featureDir -Json
        $LASTEXITCODE | Should -Not -Be 0
        $errors = (($output -join "`n") | ConvertFrom-Json).ERRORS.id
        $errors | Should -Contain 'eci-trigger-missing'
        $errors | Should -Contain 'eci-missing-eci-assessment'
    }

    It 'fails closed when readiness/ is missing entirely' {
        Write-FeatureFixture -FeatureDir $script:featureDir -ReadinessBody $null
        $output = pwsh -NoProfile -File $script:validatorScript -FeatureDir $script:featureDir -Json
        $LASTEXITCODE | Should -Not -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        ($result.ERRORS | Where-Object { $_.id -eq 'readiness-dir-missing' }) | Should -Not -BeNullOrEmpty
    }

    It 'fails closed when readiness/eci/ is missing' {
        Write-FeatureFixture -FeatureDir $script:featureDir
        Remove-Item -LiteralPath (Join-Path $script:featureDir 'readiness/eci') -Recurse -Force
        $output = pwsh -NoProfile -File $script:validatorScript -FeatureDir $script:featureDir -Json
        $LASTEXITCODE | Should -Not -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        ($result.ERRORS | Where-Object { $_.id -eq 'eci-dir-missing' }) | Should -Not -BeNullOrEmpty
    }

    It 'fails when spec.md is missing' {
        New-Item -ItemType Directory -Path $script:featureDir -Force | Out-Null
        $output = pwsh -NoProfile -File $script:validatorScript -FeatureDir $script:featureDir -Json
        $LASTEXITCODE | Should -Not -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        $result.VALID | Should -BeFalse
        ($result.ERRORS | Where-Object { $_.id -eq 'spec-missing' }) | Should -Not -BeNullOrEmpty
    }

    It 'fails when feature directory does not exist' {
        $missing = Join-Path $TestDrive 'never-created'
        $output = pwsh -NoProfile -File $script:validatorScript -FeatureDir $missing -Json
        $LASTEXITCODE | Should -Not -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        $result.VALID | Should -BeFalse
        ($result.ERRORS | Where-Object { $_.id -eq 'feature-dir-missing' }) | Should -Not -BeNullOrEmpty
    }

    It 'warns when spec.md has no Version field' {
        Write-FeatureFixture -FeatureDir $script:featureDir -SpecBody "# Specification: Test`n"
        $output = pwsh -NoProfile -File $script:validatorScript -FeatureDir $script:featureDir -Json
        $result = ($output -join "`n") | ConvertFrom-Json
        ($result.WARNINGS | Where-Object { $_.id -eq 'spec-version-missing' }) | Should -Not -BeNullOrEmpty
    }

    It 'fails when readiness/ exists but readiness-assessment.md is missing' {
        Write-FeatureFixture -FeatureDir $script:featureDir -ReadinessBody $null
        New-Item -ItemType Directory -Path (Join-Path $script:featureDir 'readiness') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:featureDir 'readiness/eci') -Force | Out-Null
        $output = pwsh -NoProfile -File $script:validatorScript -FeatureDir $script:featureDir -Json
        $LASTEXITCODE | Should -Not -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        ($result.ERRORS | Where-Object { $_.id -eq 'readiness-assessment-missing' }) | Should -Not -BeNullOrEmpty
    }

    It 'fails when ROUTE_TO_ECI is set but ECI dossier is missing' {
        Write-FeatureFixture -FeatureDir $script:featureDir -ReadinessBody @"
# Readiness

**Primary Status**: ROUTE_TO_ECI
**ECI Re-entry Status**: PENDING
**ECI Evidence SHA-256**: N/A
**Intent Ledger Requirement**: Not Required
"@
        $output = pwsh -NoProfile -File $script:validatorScript -FeatureDir $script:featureDir -Json
        $LASTEXITCODE | Should -Not -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        $eciErrors = @($result.ERRORS | Where-Object { $_.id -like 'eci-missing-*' })
        $eciErrors.Count | Should -BeGreaterOrEqual 4
    }

    It 'accepts each exactly-one Readiness primary status with its required evidence' -ForEach @(
        @{ Status = 'READY_FOR_PLAN' }
        @{ Status = 'ROUTE_TO_ECI' }
        @{ Status = 'ROUTE_TO_REPO_CONTEXT' }
        @{ Status = 'ROUTE_TO_DECISION' }
        @{ Status = 'ROUTE_TO_VALIDATION' }
        @{ Status = 'ROUTE_TO_ACCESS' }
        @{ Status = 'EXPLORATORY_ONLY' }
        @{ Status = 'NOT_READY' }
    ) {
        Write-FeatureFixture -FeatureDir $script:featureDir -ReadinessBody @"
# Readiness

**Primary Status**: $Status
**ECI Re-entry Status**: $(if ($Status -eq 'ROUTE_TO_ECI') { 'PENDING' } else { 'NOT_REQUIRED' })
**ECI Evidence SHA-256**: N/A
**Intent Ledger Requirement**: Not Required
"@
        if ($Status -eq 'ROUTE_TO_ECI') {
            Write-EciDossier -FeatureDir $script:featureDir
        }

        $output = pwsh -NoProfile -File $script:validatorScript -FeatureDir $script:featureDir -Json
        $LASTEXITCODE | Should -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        $result.READINESS_PRIMARY_STATUS | Should -Be $Status
    }

    It 'fails closed on duplicate <Kind> Readiness Primary Status fields' -ForEach @(
        @{ Kind = 'identical'; SecondStatus = 'READY_FOR_PLAN' }
        @{ Kind = 'contradictory'; SecondStatus = 'ROUTE_TO_DECISION' }
    ) {
        Write-FeatureFixture -FeatureDir $script:featureDir -ReadinessBody @"
# Readiness

**Primary Status**: READY_FOR_PLAN
**Primary Status**: $SecondStatus
**ECI Re-entry Status**: NOT_REQUIRED
**ECI Evidence SHA-256**: N/A
**Intent Ledger Requirement**: Not Required
"@

        $output = pwsh -NoProfile -File $script:validatorScript -FeatureDir $script:featureDir -Json
        $LASTEXITCODE | Should -Not -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        ($result.ERRORS | Where-Object id -eq 'readiness-primary-status-invalid').message |
            Should -Match "exactly one 'Primary Status' field, found 2"
    }

    It 'fails closed on an unknown Readiness Primary Status' {
        Write-FeatureFixture -FeatureDir $script:featureDir -ReadinessBody @"
# Readiness

**Primary Status**: READY_SOMEDAY
**ECI Re-entry Status**: NOT_REQUIRED
**ECI Evidence SHA-256**: N/A
**Intent Ledger Requirement**: Not Required
"@

        $output = pwsh -NoProfile -File $script:validatorScript -FeatureDir $script:featureDir -Json
        $LASTEXITCODE | Should -Not -Be 0
        (($output -join "`n") | ConvertFrom-Json).READINESS_PRIMARY_STATUS | Should -BeNullOrEmpty
    }

    It 'allows one initial ROUTE_TO_ECI status to await its dossier while still requiring the trigger' {
        Write-FeatureFixture -FeatureDir $script:featureDir -ReadinessBody @"
# Readiness

**Primary Status**: ROUTE_TO_ECI
**ECI Re-entry Status**: PENDING
**ECI Evidence SHA-256**: N/A
**Intent Ledger Requirement**: Not Required
"@
        "# ECI Trigger`n" |
            Set-Content -LiteralPath (Join-Path $script:featureDir 'readiness/eci-trigger.md') -NoNewline

        $output = pwsh -NoProfile -File $script:validatorScript `
            -FeatureDir $script:featureDir `
            -DeferEciDossier `
            -Json
        $LASTEXITCODE | Should -Be 0
        (($output -join "`n") | ConvertFrom-Json).READINESS_PRIMARY_STATUS | Should -Be 'ROUTE_TO_ECI'
    }

    It 'does not defer a PENDING dossier when the ECI container already holds an artifact' {
        Write-FeatureFixture -FeatureDir $script:featureDir -ReadinessBody @"
# Readiness

**Primary Status**: ROUTE_TO_ECI
**ECI Re-entry Status**: PENDING
**ECI Evidence SHA-256**: N/A
**Intent Ledger Requirement**: Not Required
"@
        '# ECI Trigger' |
            Set-Content -LiteralPath (Join-Path $script:featureDir 'readiness/eci-trigger.md') -NoNewline
        'renamed dossier evidence' |
            Set-Content -LiteralPath (Join-Path $script:featureDir 'readiness/eci/unknown.md') -NoNewline

        $output = pwsh -NoProfile -File $script:validatorScript `
            -FeatureDir $script:featureDir `
            -DeferEciDossier `
            -Json
        $LASTEXITCODE | Should -Not -Be 0
        (($output -join "`n") | ConvertFrom-Json).ERRORS.id |
            Should -Contain 'eci-missing-eci-assessment'
    }

    It 'denies duplicate initial Readiness status before ECI branching even while dossier creation is deferred' {
        Write-FeatureFixture -FeatureDir $script:featureDir -ReadinessBody @"
# Readiness

**Primary Status**: ROUTE_TO_ECI
**Primary Status**: READY_FOR_PLAN
**ECI Re-entry Status**: PENDING
**ECI Evidence SHA-256**: N/A
**Intent Ledger Requirement**: Not Required
"@
        "# ECI Trigger`n" |
            Set-Content -LiteralPath (Join-Path $script:featureDir 'readiness/eci-trigger.md') -NoNewline

        $output = pwsh -NoProfile -File $script:validatorScript `
            -FeatureDir $script:featureDir `
            -DeferEciDossier `
            -Json
        $LASTEXITCODE | Should -Not -Be 0
        (($output -join "`n") | ConvertFrom-Json).ERRORS.id |
            Should -Contain 'readiness-primary-status-invalid'
    }

    It 'denies duplicate post-ECI Readiness status before latest-status routing' {
        Write-FeatureFixture -FeatureDir $script:featureDir
        Write-EciDossier -FeatureDir $script:featureDir -CompleteReadiness
        Add-Content -LiteralPath (Join-Path $script:featureDir 'readiness/readiness-assessment.md') `
            -Value "`n**Primary Status**: ROUTE_TO_VALIDATION"

        $output = pwsh -NoProfile -File $script:validatorScript `
            -FeatureDir $script:featureDir `
            -RequireEciDossier `
            -Json
        $LASTEXITCODE | Should -Not -Be 0
        (($output -join "`n") | ConvertFrom-Json).ERRORS.id |
            Should -Contain 'readiness-primary-status-invalid'
    }

    It 'requires all four dossier files after ECI even when Primary Status was hand-edited to READY_FOR_PLAN' -ForEach @(
        @{ MissingFile = 'eci-assessment.md' }
        @{ MissingFile = 'source-manifest.md' }
        @{ MissingFile = 'adoption-record.md' }
        @{ MissingFile = 'authorization-record.md' }
    ) {
        Write-FeatureFixture -FeatureDir $script:featureDir
        Write-EciDossier -FeatureDir $script:featureDir -CompleteReadiness
        Remove-Item -LiteralPath (Join-Path $script:featureDir "readiness/eci/$MissingFile") -Force

        $output = pwsh -NoProfile -File $script:validatorScript -FeatureDir $script:featureDir -Json
        $LASTEXITCODE | Should -Not -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        ($result.ERRORS | Where-Object id -eq "eci-missing-$($MissingFile -replace '\.md$','')") |
            Should -Not -BeNullOrEmpty
    }

    It 'accepts exactly-one ECI outcome <Outcome> as a structurally coherent dossier' -ForEach @(
        @{ Outcome = 'READY_FOR_MAINLINE_IMPLEMENTATION' }
        @{ Outcome = 'READY_FOR_SPIKE_ONLY' }
        @{ Outcome = 'READY_FOR_SANDBOX_ONLY' }
        @{ Outcome = 'NOT_READY' }
    ) {
        Write-FeatureFixture -FeatureDir $script:featureDir
        Write-EciDossier -FeatureDir $script:featureDir -AuthorizationOutcome $Outcome -CompleteReadiness

        $output = pwsh -NoProfile -File $script:validatorScript `
            -FeatureDir $script:featureDir `
            -RequireEciDossier `
            -Json
        $LASTEXITCODE | Should -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        $result.ECI_AUTHORIZATION_OUTCOME | Should -Be $Outcome
        $result.ECI_REENTRY_STATUS | Should -Be 'COMPLETE'
        $result.ECI_EVIDENCE_SHA256 |
            Should -Be (Get-EciEvidenceDigest -FeatureDir $script:featureDir)
        $result.ECI_ACTUAL_EVIDENCE_SHA256 |
            Should -Be (Get-EciEvidenceDigest -FeatureDir $script:featureDir)
    }

    It 'allows bounded ECI outcome <Outcome> to enter a second Readiness assessment' -ForEach @(
        @{ Outcome = 'READY_FOR_MAINLINE_IMPLEMENTATION' }
        @{ Outcome = 'READY_FOR_SPIKE_ONLY' }
        @{ Outcome = 'READY_FOR_SANDBOX_ONLY' }
    ) {
        Write-FeatureFixture -FeatureDir $script:featureDir -ReadinessBody @"
# Readiness

**Primary Status**: ROUTE_TO_ECI
**ECI Re-entry Status**: PENDING
**ECI Evidence SHA-256**: N/A
**Intent Ledger Requirement**: Not Required
"@
        Write-EciDossier -FeatureDir $script:featureDir -AuthorizationOutcome $Outcome

        $output = pwsh -NoProfile -File $script:validatorScript `
            -FeatureDir $script:featureDir `
            -RequireEciReentry `
            -Json
        $LASTEXITCODE | Should -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        $result.ECI_AUTHORIZATION_OUTCOME | Should -Be $Outcome
        $result.ECI_REENTRY_STATUS | Should -Be 'PENDING'
        $result.ECI_EVIDENCE_SHA256 | Should -Be 'N/A'
        $result.ECI_ACTUAL_EVIDENCE_SHA256 |
            Should -Be (Get-EciEvidenceDigest -FeatureDir $script:featureDir)
    }

    It 'denies ECI NOT_READY from entering the second Readiness assessment' {
        Write-FeatureFixture -FeatureDir $script:featureDir -ReadinessBody @"
# Readiness

**Primary Status**: ROUTE_TO_ECI
**ECI Re-entry Status**: PENDING
**ECI Evidence SHA-256**: N/A
**Intent Ledger Requirement**: Not Required
"@
        Write-EciDossier -FeatureDir $script:featureDir -AuthorizationOutcome 'NOT_READY'

        $output = pwsh -NoProfile -File $script:validatorScript `
            -FeatureDir $script:featureDir `
            -RequireEciReentry `
            -Json
        $LASTEXITCODE | Should -Not -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        ($result.ERRORS | Where-Object id -eq 'eci-reentry-not-authorized') |
            Should -Not -BeNullOrEmpty
    }

    It 'denies duplicate contradictory ECI Authorization Outcome fields' {
        Write-FeatureFixture -FeatureDir $script:featureDir
        Write-EciDossier `
            -FeatureDir $script:featureDir `
            -AuthorizationSuffix '**Authorization Outcome**: `READY_FOR_SANDBOX_ONLY`' `
            -CompleteReadiness

        $output = pwsh -NoProfile -File $script:validatorScript `
            -FeatureDir $script:featureDir `
            -RequireEciDossier `
            -Json
        $LASTEXITCODE | Should -Not -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        ($result.ERRORS | Where-Object id -eq 'eci-authorization-outcome-invalid').message |
            Should -Match "exactly one 'Authorization Outcome' field, found 2"
    }

    It 'fails when readiness mandates intent-ledger but it is missing' {
        Write-FeatureFixture -FeatureDir $script:featureDir -ReadinessBody @"
# Readiness

**Primary Status**: READY_FOR_PLAN
**ECI Re-entry Status**: NOT_REQUIRED
**ECI Evidence SHA-256**: N/A
**Intent Ledger Requirement**: Create ``intent-ledger.md``
"@
        $output = pwsh -NoProfile -File $script:validatorScript -FeatureDir $script:featureDir -Json
        $LASTEXITCODE | Should -Not -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        ($result.ERRORS | Where-Object { $_.id -eq 'intent-ledger-missing' }) | Should -Not -BeNullOrEmpty
    }

    It 'warns when intent-ledger.md exists but readiness has not been initiated' {
        Write-FeatureFixture -FeatureDir $script:featureDir -ReadinessBody $null -Optional @{ 'intent-ledger.md' = "# Intent Ledger`n`nstub`n" }
        $output = pwsh -NoProfile -File $script:validatorScript -FeatureDir $script:featureDir -Json
        $LASTEXITCODE | Should -Not -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        ($result.ERRORS | Where-Object { $_.id -eq 'readiness-dir-missing' }) | Should -Not -BeNullOrEmpty
        ($result.WARNINGS | Where-Object { $_.id -eq 'intent-ledger-without-readiness' }) | Should -Not -BeNullOrEmpty
    }

    It 'warns when tasks.md has no canonical "- [ ] T###" lines' {
        $tasksBody = "# Tasks`n`nNo canonical lines yet`n"
        Write-FeatureFixture -FeatureDir $script:featureDir -Optional @{ 'tasks.md' = $tasksBody }
        $output = pwsh -NoProfile -File $script:validatorScript -FeatureDir $script:featureDir -Json
        $result = ($output -join "`n") | ConvertFrom-Json
        ($result.WARNINGS | Where-Object { $_.id -eq 'tasks-no-canonical-line' }) | Should -Not -BeNullOrEmpty
    }

    It 'accepts canonical tasks.md format' {
        $tasksBody = "# Tasks`n`n- [ ] T001 [P1] [Risk: Low] [Story: A] First task`n"
        Write-FeatureFixture -FeatureDir $script:featureDir -Optional @{ 'tasks.md' = $tasksBody }
        $output = pwsh -NoProfile -File $script:validatorScript -FeatureDir $script:featureDir -Json
        $result = ($output -join "`n") | ConvertFrom-Json
        ($result.WARNINGS | Where-Object { $_.id -eq 'tasks-no-canonical-line' }) | Should -BeNullOrEmpty
    }

    It 'promotes warnings to errors with -WarningsAsErrors' {
        Write-FeatureFixture -FeatureDir $script:featureDir -SpecBody "# Specification: Test`n"  # no Version => warning
        $output = pwsh -NoProfile -File $script:validatorScript -FeatureDir $script:featureDir -Json -WarningsAsErrors
        $LASTEXITCODE | Should -Not -Be 0
        $result = ($output -join "`n") | ConvertFrom-Json
        $result.VALID | Should -BeFalse
        ($result.ERRORS | Where-Object { $_.id -eq 'spec-version-missing' }) | Should -Not -BeNullOrEmpty
    }

    It 'emits human-readable text without -Json' {
        Write-FeatureFixture -FeatureDir $script:featureDir
        $output = pwsh -NoProfile -File $script:validatorScript -FeatureDir $script:featureDir
        $LASTEXITCODE | Should -Be 0
        ($output -join "`n") | Should -Match 'VALID:\s+True'
    }
}

Describe 'Readiness ECI re-entry authoring surfaces' {
    BeforeAll {
        $script:readinessAgentSource = Join-Path $WorkspaceRoot '.github/agents/speckit.readiness.agent.md'
        $script:readinessAgentMirror = Join-Path $WorkspaceRoot '.claude/agents/speckit-readiness.md'
        $script:readinessTemplate = Join-Path $WorkspaceRoot 'studio/templates/sdd-docs/readiness-assessment-template.md'
    }

    It 'requires both exactly-one evidence fields on the canonical agent, mirror, and template' {
        foreach ($path in $script:readinessAgentSource, $script:readinessAgentMirror, $script:readinessTemplate) {
            $content = Get-Content -LiteralPath $path -Raw
            $content | Should -Match 'ECI Re-entry Status'
            $content | Should -Match 'ECI Evidence SHA-256'
            $content | Should -Not -Match 'ECI Dossier SHA-256'
            $content | Should -Match 'NOT_REQUIRED'
            $content | Should -Match 'PENDING'
            $content | Should -Match 'COMPLETE'
        }
    }

    It 'directs each authoring surface to the validator-computed framed digest' {
        foreach ($path in $script:readinessAgentSource, $script:readinessAgentMirror, $script:readinessTemplate) {
            $content = Get-Content -LiteralPath $path -Raw
            $content | Should -Match 'ECI_ACTUAL_EVIDENCE_SHA256'
            $content | Should -Not -Match 'ECI_ACTUAL_DOSSIER_SHA256'
            $content | Should -Match '4-byte big-endian'
            $content | Should -Match '8-byte\s+big-endian'
            $content | Should -Match '(?s)eci-trigger\.md.*eci/eci-assessment\.md.*eci/source-manifest\.md.*eci/adoption-record\.md.*eci/authorization-record\.md'
            $content | Should -Match '(?i)all five'
        }
    }
}

Describe 'new-project-worktree parameter validation (L9-prime)' {
    BeforeAll {
        $script:worktreeScript = Join-Path $WorkspaceRoot 'studio/scripts/powershell/new-project-worktree.ps1'
    }

    It 'rejects branch names containing spaces' {
        $output = pwsh -NoProfile -File $script:worktreeScript -SourceRoot $TestDrive -Path (Join-Path $TestDrive 'wt') -Branch 'has space' 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match 'Invalid git branch name'
    }

    It 'rejects branch names with .. traversal' {
        $output = pwsh -NoProfile -File $script:worktreeScript -SourceRoot $TestDrive -Path (Join-Path $TestDrive 'wt') -Branch 'foo..bar' 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match 'Invalid git branch name'
    }

    It 'rejects branch names ending in .lock' {
        $output = pwsh -NoProfile -File $script:worktreeScript -SourceRoot $TestDrive -Path (Join-Path $TestDrive 'wt') -Branch 'foo.lock' 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match 'Invalid git branch name'
    }

    It 'accepts valid kebab-case branch names at parameter binding' {
        $cmd = Get-Command $script:worktreeScript
        $cmd.Parameters.Branch.Attributes |
            Where-Object { $_ -is [System.Management.Automation.ValidateScriptAttribute] } |
            Should -Not -BeNullOrEmpty
        $cmd.Parameters.Commitish.Attributes |
            Where-Object { $_ -is [System.Management.Automation.ValidateScriptAttribute] } |
            Should -Not -BeNullOrEmpty
    }
}

Describe 'sync-agent-bootstrap -From parameter validation (L9)' {
    BeforeAll {
        $script:bootstrapScript = Join-Path $WorkspaceRoot 'studio/scripts/powershell/sync-agent-bootstrap.ps1'
    }

    It 'has ValidateScript on -From' {
        $cmd = Get-Command $script:bootstrapScript
        $validateScript = $cmd.Parameters.From.Attributes |
            Where-Object { $_ -is [System.Management.Automation.ValidateScriptAttribute] }
        $validateScript | Should -Not -BeNullOrEmpty
    }

    It 'rejects an unknown -From basename at parameter binding' {
        $output = pwsh -NoProfile -File $script:bootstrapScript -ProjectRoot $TestDrive -From 'random.md' 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match 'Invalid -From value'
    }

    It 'accepts canonical adapter names' {
        # We use a non-existent ProjectRoot to ensure the script fails AFTER parameter binding,
        # which proves -From was accepted by ValidateScript.
        $output = pwsh -NoProfile -File $script:bootstrapScript -ProjectRoot (Join-Path $TestDrive 'nope') -From 'AGENTS.md' 2>&1
        ($output -join "`n") | Should -Not -Match 'Invalid -From value'
    }

    It 'accepts an absolute path whose basename matches a canonical adapter' {
        $absPath = Join-Path $TestDrive 'project/CLAUDE.md'
        $output = pwsh -NoProfile -File $script:bootstrapScript -ProjectRoot (Join-Path $TestDrive 'nope') -From $absPath 2>&1
        ($output -join "`n") | Should -Not -Match 'Invalid -From value'
    }
}

Describe 'new-project-worktree hooksPath configuration (M8)' {
    BeforeAll {
        $script:worktreeScript = Join-Path $WorkspaceRoot 'studio/scripts/powershell/new-project-worktree.ps1'
    }

    It 'stores depth-specific hooks paths per worktree without changing source or sibling worktrees' {
        # Build a minimal workspace, source repo, and pre-existing sibling worktree on TestDrive.
        $ws = Join-Path $TestDrive 'ws-m8'
        $studio = Join-Path $ws 'studio'
        $hooks = Join-Path $ws '.githooks'
        $project = Join-Path $ws 'projects/sample'
        $existingWorktree = Join-Path $ws 'projects/existing-peer'

        New-Item -ItemType Directory -Path (Join-Path $studio 'constitution') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $studio 'constitution/constitution.md') -Value '# stub' -Encoding utf8
        New-Item -ItemType Directory -Path $hooks -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $ws '.github/agents') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $ws '.claude/agents') -Force | Out-Null
        New-Item -ItemType Directory -Path $project -Force | Out-Null

        Push-Location $project
        try {
            git init -b main . | Out-Null
            git config user.email 'test@example.com'
            git config user.name 'Test'
            'seed' | Set-Content -LiteralPath 'seed.txt'
            @(
                '/.github/agents/',
                '/.claude/agents/'
            ) | Set-Content -LiteralPath '.gitignore' -Encoding utf8
            git add . | Out-Null
            git commit -m 'feat: seed' | Out-Null
        } finally {
            Pop-Location
        }

        $sourceHooksPath = '../../.githooks'
        git -C $project config core.hooksPath $sourceHooksPath
        $LASTEXITCODE | Should -Be 0
        git -C $project worktree add -b existing-peer $existingWorktree | Out-Null
        $LASTEXITCODE | Should -Be 0

        $shallowWorktree = Join-Path $ws 'shallow-wt'
        $shallowOutput = @(pwsh -NoProfile -File $script:worktreeScript `
            -SourceRoot $project `
            -Path $shallowWorktree `
            -Branch 'feature-shallow' `
            -Json 2>&1)
        $LASTEXITCODE | Should -Be 0 -Because ($shallowOutput -join "`n")

        $expectedShallowHooks = [System.IO.Path]::GetRelativePath($shallowWorktree, $hooks) -replace '\\', '/'
        (git -C $shallowWorktree config --worktree --get core.hooksPath) |
            Should -BeExactly $expectedShallowHooks
        (git -C $shallowWorktree config --show-origin --get core.hooksPath) |
            Should -Match 'config\.worktree'
        (git -C $project config --local --get core.hooksPath) |
            Should -BeExactly $sourceHooksPath
        (git -C $project config --get core.hooksPath) |
            Should -BeExactly $sourceHooksPath
        (git -C $existingWorktree config --get core.hooksPath) |
            Should -BeExactly $sourceHooksPath

        $deepParent = Join-Path $ws 'worktrees/team'
        New-Item -ItemType Directory -Path $deepParent -Force | Out-Null
        $deepWorktree = Join-Path $deepParent 'deep-wt'
        $deepOutput = @(pwsh -NoProfile -File $script:worktreeScript `
            -SourceRoot $project `
            -Path $deepWorktree `
            -Branch 'feature-deep' `
            -Json 2>&1)
        $LASTEXITCODE | Should -Be 0 -Because ($deepOutput -join "`n")

        $expectedDeepHooks = [System.IO.Path]::GetRelativePath($deepWorktree, $hooks) -replace '\\', '/'
        (git -C $deepWorktree config --worktree --get core.hooksPath) |
            Should -BeExactly $expectedDeepHooks
        (git -C $deepWorktree config --show-origin --get core.hooksPath) |
            Should -Match 'config\.worktree'
        (git -C $project config --local --get core.hooksPath) |
            Should -BeExactly $sourceHooksPath
        (git -C $project config --get core.hooksPath) |
            Should -BeExactly $sourceHooksPath
        (git -C $existingWorktree config --get core.hooksPath) |
            Should -BeExactly $sourceHooksPath
        (git -C $shallowWorktree config --get core.hooksPath) |
            Should -BeExactly $expectedShallowHooks
        (git -C $project config --local --bool --get extensions.worktreeConfig) |
            Should -BeExactly 'true'
    }
}

Describe 'upgrade-studio-runtime help clarity (L10)' {
    BeforeAll {
        $script:upgradeScript = Join-Path $WorkspaceRoot 'studio/scripts/powershell/upgrade-studio-runtime.ps1'
    }

    It 'help text states default is dry-run' {
        $output = pwsh -NoProfile -File $script:upgradeScript -UpstreamSnapshotDir $TestDrive -Help
        ($output -join "`n") | Should -Match 'Default behavior: dry-run'
    }

    It 'help text marks -DryRun and -Apply as mutually exclusive' {
        $output = pwsh -NoProfile -File $script:upgradeScript -UpstreamSnapshotDir $TestDrive -Help
        ($output -join "`n") | Should -Match 'mutually exclusive'
    }

    It 'mutual-exclusion error message is clear when both flags supplied' {
        $snap = Join-Path $TestDrive 'snap'
        New-Item -ItemType Directory -Path $snap -Force | Out-Null
        $output = pwsh -NoProfile -File $script:upgradeScript -UpstreamSnapshotDir $snap -DryRun -Apply 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        ($output -join "`n") | Should -Match 'mutually exclusive'
    }
}
