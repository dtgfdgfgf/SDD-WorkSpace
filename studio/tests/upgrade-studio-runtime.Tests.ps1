BeforeAll {
    . "$PSScriptRoot/governance.config.ps1"

    $script:upgradeScript = if ($env:SDD_UPGRADE_SCRIPT_UNDER_TEST) {
        [System.IO.Path]::GetFullPath($env:SDD_UPGRADE_SCRIPT_UNDER_TEST)
    } else {
        Join-Path $WorkspaceRoot 'studio/scripts/powershell/upgrade-studio-runtime.ps1'
    }
    $script:commonScript = if ($env:SDD_UPGRADE_COMMON_UNDER_TEST) {
        [System.IO.Path]::GetFullPath($env:SDD_UPGRADE_COMMON_UNDER_TEST)
    } else {
        Join-Path $WorkspaceRoot 'studio/scripts/powershell/common.ps1'
    }

    function Set-Utf8File {
        param(
            [Parameter(Mandatory)]
            [string]$Path,
            [Parameter(Mandatory)]
            [AllowEmptyString()]
            [string]$Content
        )

        $parent = Split-Path -Parent $Path
        if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
    }

    function New-UpgradeFixture {
        param(
            [Parameter(Mandatory)]
            [string]$Root
        )

        $scriptsDir = Join-Path $Root 'studio/scripts/powershell'
        $upstreamDir = Join-Path $Root 'studio/upstream'
        $constitutionDir = Join-Path $Root 'studio/constitution'
        $workflowsDir = Join-Path $Root 'studio/workflows'
        $runtimeDir = Join-Path $Root 'runtime'
        $snapshotDir = Join-Path $Root 'snapshot'
        $tempDir = Join-Path $Root 'temp'

        New-Item -ItemType Directory -Path $scriptsDir, $upstreamDir, $constitutionDir, $workflowsDir, $runtimeDir, $snapshotDir, $tempDir -Force | Out-Null
        Copy-Item -LiteralPath $script:upgradeScript -Destination (Join-Path $scriptsDir 'upgrade-studio-runtime.ps1')
        Copy-Item -LiteralPath $script:commonScript -Destination (Join-Path $scriptsDir 'common.ps1')
        Set-Utf8File -Path (Join-Path $constitutionDir 'constitution.md') -Content '# fixture constitution'
        Set-Utf8File -Path (Join-Path $workflowsDir 'catalog.schema.json') -Content '{}'
        Set-Utf8File -Path (Join-Path $workflowsDir 'state.schema.json') -Content '{}'

        $generatorStub = @'
#!/usr/bin/env pwsh
param([switch]$Compare)
$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
exit 0
'@
        Set-Utf8File -Path (Join-Path $scriptsDir 'generate-impact-registry.ps1') -Content $generatorStub

        $syncMap = [ordered]@{
            version = 'fixture'
            mode = 'studio-first'
            mappings = @(
                [ordered]@{ source = 'payload/first.txt'; target = 'runtime/first.txt'; kind = 'file'; prune = $false },
                [ordered]@{ source = 'payload/second.txt'; target = 'runtime/second.txt'; kind = 'file'; prune = $false },
                [ordered]@{ source = 'payload/audit.txt'; target = 'runtime/audit.txt'; kind = 'file'; prune = $false },
                [ordered]@{
                    source = 'payload/check-speckit-runtime.ps1'
                    target = 'studio/scripts/powershell/check-speckit-runtime.ps1'
                    kind = 'file'
                    prune = $false
                },
                [ordered]@{
                    source = 'payload/fixture-audit-helper.ps1'
                    target = 'studio/scripts/powershell/fixture-audit-helper.ps1'
                    kind = 'file'
                    prune = $false
                }
            )
            blockedRoots = @()
        }
        Set-Utf8File -Path (Join-Path $upstreamDir 'shared-layer-map.json') -Content ($syncMap | ConvertTo-Json -Depth 8)

        Set-Utf8File -Path (Join-Path $runtimeDir 'first.txt') -Content 'old-first'
        Set-Utf8File -Path (Join-Path $runtimeDir 'second.txt') -Content 'old-second'
        Set-Utf8File -Path (Join-Path $runtimeDir 'audit.txt') -Content 'valid'

        $auditHelperStub = @'
#!/usr/bin/env pwsh
param([string]$AuditValue, [string]$WorkspaceRoot)
$valid = if ($AuditValue -eq 'string-false') {
    'false'
} else {
    (
        $AuditValue -in @('valid', 'wrong-error-type', 'null-warning') -or
        ($AuditValue -eq 'stage-only' -and (Split-Path $WorkspaceRoot -Leaf) -eq 'candidate')
    )
}
$errorCount = if ($AuditValue -eq 'wrong-error-type') {
    '0'
} elseif ($valid -is [bool] -and $valid) {
    0
} elseif ($valid -is [string]) {
    0
} else {
    1
}
$warningCount = if ($AuditValue -eq 'null-warning') { $null } else { 0 }
[pscustomobject][ordered]@{
    VALID = $valid
    ERROR_COUNT = $errorCount
    WARNING_COUNT = $warningCount
} | ConvertTo-Json
'@
        Set-Utf8File -Path (Join-Path $scriptsDir 'fixture-audit-helper.ps1') -Content $auditHelperStub

        $auditStub = @'
#!/usr/bin/env pwsh
param([switch]$Json)
if ($false) {
    $validator = Invoke-JsonScript -ScriptPath $paths.EXTENSIONS_VALIDATOR_PATH -Arguments @('-Json')
    $listWorkflowsScript = Join-Path $paths.SHARED_SCRIPTS_DIR 'list-workflows.ps1'
    $agentBootstrapScript = Join-Path $paths.SHARED_SCRIPTS_DIR 'check-agent-bootstrap.ps1'
    $mainlineNoteScript = Join-Path $paths.SHARED_SCRIPTS_DIR 'validate-mainline-notes.ps1'
    $generatorScript = Join-Path $paths.WORKSPACE_ROOT 'studio/scripts/powershell/generate-impact-registry.ps1'
}
$studioRoot = if ($env:SDD_STUDIO_ROOT) {
    [System.IO.Path]::GetFullPath($env:SDD_STUDIO_ROOT)
} else {
    Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}
$workspaceRoot = Split-Path $studioRoot -Parent
$mirrorAuditPath = Join-Path $workspaceRoot 'resources/studio-runtime/merged/audit.txt'
$mirrorManifestPath = Join-Path $workspaceRoot 'resources/studio-runtime/merged/manifest.json'
$auditPath = if (
    (Test-Path -LiteralPath $mirrorManifestPath -PathType Leaf) -and
    (Test-Path -LiteralPath $mirrorAuditPath -PathType Leaf)
) {
    $mirrorAuditPath
} else {
    Join-Path $workspaceRoot 'runtime/audit.txt'
}
$auditValue = [System.IO.File]::ReadAllText($auditPath).Trim()
$helperOutput = & (Join-Path $PSScriptRoot 'fixture-audit-helper.ps1') -AuditValue $auditValue -WorkspaceRoot $workspaceRoot
$helperResult = $helperOutput -join "`n" | ConvertFrom-Json
$helperResult | ConvertTo-Json
if ($helperResult.VALID -is [bool] -and -not $helperResult.VALID) { exit 1 }
exit 0
'@
        Set-Utf8File -Path (Join-Path $scriptsDir 'check-speckit-runtime.ps1') -Content $auditStub

        $versionStub = @'
#!/usr/bin/env pwsh
param([switch]$Json)
[pscustomobject]@{ VALID = $true; version = 'fixture' } | ConvertTo-Json
'@
        Set-Utf8File -Path (Join-Path $scriptsDir 'get-speckit-version.ps1') -Content $versionStub

        $skillsStub = @'
#!/usr/bin/env pwsh
param([string]$Target, [string]$OutputDir, [switch]$Force, [switch]$Json)
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
[pscustomobject]@{ VALID = $true; target = $Target } | ConvertTo-Json
'@
        Set-Utf8File -Path (Join-Path $scriptsDir 'export-agent-skills.ps1') -Content $skillsStub

        $extensionsStub = @'
#!/usr/bin/env pwsh
param([string]$OutputDir, [switch]$Force, [switch]$Json)
$workspaceRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$workspacePrefix = [System.IO.Path]::GetFullPath($workspaceRoot).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
$resolvedOutput = [System.IO.Path]::GetFullPath($OutputDir)
if (-not $resolvedOutput.StartsWith($workspacePrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Fixture export boundary denied output outside the staged workspace.'
}
if ([System.IO.File]::ReadAllText((Join-Path $workspaceRoot 'runtime/audit.txt')).Trim() -eq 'mutate-during-smoke') {
    [System.IO.File]::WriteAllText((Join-Path $workspaceRoot 'runtime/first.txt'), 'mutated-by-smoke')
}
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
[pscustomobject]@{ VALID = $true } | ConvertTo-Json
'@
        Set-Utf8File -Path (Join-Path $scriptsDir 'export-extensions.ps1') -Content $extensionsStub

        return [pscustomobject]@{
            Root = $Root
            Script = Join-Path $scriptsDir 'upgrade-studio-runtime.ps1'
            Runtime = $runtimeDir
            Snapshot = $snapshotDir
            Payload = Join-Path $snapshotDir 'payload'
            Temp = $tempDir
            AuditScript = Join-Path $scriptsDir 'check-speckit-runtime.ps1'
            AuditHelper = Join-Path $scriptsDir 'fixture-audit-helper.ps1'
        }
    }

    function Set-CompleteUpgradeSnapshot {
        param(
            [Parameter(Mandatory)]
            [object]$Fixture,
            [string]$First = 'new-first',
            [string]$Second = 'new-second',
            [string]$Audit = 'valid'
        )

        Set-Utf8File -Path (Join-Path $Fixture.Payload 'first.txt') -Content $First
        Set-Utf8File -Path (Join-Path $Fixture.Payload 'second.txt') -Content $Second
        Set-Utf8File -Path (Join-Path $Fixture.Payload 'audit.txt') -Content $Audit
        Copy-Item -LiteralPath $Fixture.AuditScript -Destination (Join-Path $Fixture.Payload 'check-speckit-runtime.ps1') -Force
        Copy-Item -LiteralPath $Fixture.AuditHelper -Destination (Join-Path $Fixture.Payload 'fixture-audit-helper.ps1') -Force
    }

    function New-StaleRuntimeMirror {
        param(
            [Parameter(Mandatory)]
            [object]$Fixture
        )

        $mirrorRoot = Join-Path $Fixture.Root 'resources/studio-runtime/merged'
        Set-Utf8File -Path (Join-Path $mirrorRoot 'manifest.json') -Content '{"version":"stale"}'
        Set-Utf8File -Path (Join-Path $mirrorRoot 'audit.txt') -Content 'valid'
        return $mirrorRoot
    }

    function Invoke-FixtureUpgrade {
        param(
            [Parameter(Mandatory)]
            [object]$Fixture
        )

        $previousTemp = $env:TEMP
        $previousTmp = $env:TMP
        try {
            $env:TEMP = $Fixture.Temp
            $env:TMP = $Fixture.Temp
            $output = & pwsh -NoProfile -File $Fixture.Script -UpstreamSnapshotDir $Fixture.Snapshot -Apply -Json 2>&1
            return [pscustomobject]@{
                ExitCode = $LASTEXITCODE
                Output = @($output)
            }
        } finally {
            $env:TEMP = $previousTemp
            $env:TMP = $previousTmp
        }
    }

    function Get-RuntimeContents {
        param(
            [Parameter(Mandatory)]
            [object]$Fixture
        )

        return [ordered]@{
            First = [System.IO.File]::ReadAllText((Join-Path $Fixture.Runtime 'first.txt'))
            Second = [System.IO.File]::ReadAllText((Join-Path $Fixture.Runtime 'second.txt'))
            Audit = [System.IO.File]::ReadAllText((Join-Path $Fixture.Runtime 'audit.txt'))
        }
    }
}

Describe 'upgrade-studio-runtime transactional apply (R-F06)' {
    It 'rejects an incomplete snapshot before changing canonical runtime' {
        $fixture = New-UpgradeFixture -Root (Join-Path $TestDrive 'incomplete')
        Set-Utf8File -Path (Join-Path $fixture.Payload 'first.txt') -Content 'new-first'
        Set-Utf8File -Path (Join-Path $fixture.Payload 'audit.txt') -Content 'valid'
        $before = Get-RuntimeContents -Fixture $fixture

        $result = Invoke-FixtureUpgrade -Fixture $fixture

        $result.ExitCode | Should -Not -Be 0
        ($result.Output -join "`n") | Should -Match 'Snapshot is incomplete'
        (Get-RuntimeContents -Fixture $fixture | ConvertTo-Json) | Should -Be ($before | ConvertTo-Json)
        @(Get-ChildItem -LiteralPath $fixture.Temp -Filter 'studio-runtime-upgrade-*' -Force).Count | Should -Be 0
    }

    It 'rejects a canonical target parent junction before touching its outside sentinel' {
        $caseRoot = Join-Path $TestDrive 'target-junction'
        $fixture = New-UpgradeFixture -Root (Join-Path $caseRoot 'workspace')
        Set-CompleteUpgradeSnapshot -Fixture $fixture
        $outsideRuntime = Join-Path $caseRoot 'outside-runtime'
        New-Item -ItemType Directory -Path $outsideRuntime -Force | Out-Null
        foreach ($runtimeFile in @(Get-ChildItem -LiteralPath $fixture.Runtime -File -Force)) {
            Move-Item -LiteralPath $runtimeFile.FullName -Destination (Join-Path $outsideRuntime $runtimeFile.Name)
        }
        Remove-Item -LiteralPath $fixture.Runtime -Force
        New-Item -ItemType Junction -Path $fixture.Runtime -Target $outsideRuntime | Out-Null
        Set-Utf8File -Path (Join-Path $outsideRuntime 'sentinel.txt') -Content 'outside-unchanged'
        $before = Get-RuntimeContents -Fixture $fixture

        $result = Invoke-FixtureUpgrade -Fixture $fixture

        $result.ExitCode | Should -Not -Be 0
        ($result.Output -join "`n") | Should -Match 'physical root containment'
        (Get-RuntimeContents -Fixture $fixture | ConvertTo-Json) | Should -Be ($before | ConvertTo-Json)
        [System.IO.File]::ReadAllText((Join-Path $outsideRuntime 'sentinel.txt')) | Should -Be 'outside-unchanged'
    }

    It 'rejects a snapshot source junction that resolves outside the snapshot root' {
        $caseRoot = Join-Path $TestDrive 'source-junction'
        $fixture = New-UpgradeFixture -Root (Join-Path $caseRoot 'workspace')
        Set-CompleteUpgradeSnapshot -Fixture $fixture
        $outsidePayload = Join-Path $caseRoot 'outside-payload'
        New-Item -ItemType Directory -Path $outsidePayload -Force | Out-Null
        foreach ($payloadFile in @(Get-ChildItem -LiteralPath $fixture.Payload -File -Force)) {
            Move-Item -LiteralPath $payloadFile.FullName -Destination (Join-Path $outsidePayload $payloadFile.Name)
        }
        Remove-Item -LiteralPath $fixture.Payload -Force
        New-Item -ItemType Junction -Path $fixture.Payload -Target $outsidePayload | Out-Null
        $before = Get-RuntimeContents -Fixture $fixture

        $result = Invoke-FixtureUpgrade -Fixture $fixture

        $result.ExitCode | Should -Not -Be 0
        ($result.Output -join "`n") | Should -Match 'physical root containment'
        (Get-RuntimeContents -Fixture $fixture | ConvertTo-Json) | Should -Be ($before | ConvertTo-Json)
    }

    It 'audits the staged candidate and leaves canonical runtime unchanged when that audit fails' {
        $fixture = New-UpgradeFixture -Root (Join-Path $TestDrive 'audit-failure')
        Set-CompleteUpgradeSnapshot -Fixture $fixture -First 'new-first' -Second 'new-second' -Audit 'invalid'
        $before = Get-RuntimeContents -Fixture $fixture

        $result = Invoke-FixtureUpgrade -Fixture $fixture

        $result.ExitCode | Should -Not -Be 0
        ($result.Output -join "`n") | Should -Match 'audit failed during .*staging'
        (Get-RuntimeContents -Fixture $fixture | ConvertTo-Json) | Should -Be ($before | ConvertTo-Json)
        @(Get-ChildItem -LiteralPath $fixture.Temp -Filter 'studio-runtime-upgrade-*' -Force).Count | Should -Be 0
    }

    It 'does not let a stale merged mirror mask an invalid staged core candidate' {
        $fixture = New-UpgradeFixture -Root (Join-Path $TestDrive 'stale-mirror-mask')
        Set-CompleteUpgradeSnapshot -Fixture $fixture -Audit 'invalid'
        $mirrorRoot = New-StaleRuntimeMirror -Fixture $fixture
        $before = Get-RuntimeContents -Fixture $fixture

        $result = Invoke-FixtureUpgrade -Fixture $fixture

        $result.ExitCode | Should -Not -Be 0
        ($result.Output -join "`n") | Should -Match 'audit failed during .*staging'
        (Get-RuntimeContents -Fixture $fixture | ConvertTo-Json) | Should -Be ($before | ConvertTo-Json)
        Test-Path -LiteralPath (Join-Path $mirrorRoot 'manifest.json') -PathType Leaf | Should -BeTrue
    }

    It 'denies a string false audit verdict instead of coercing it to true' {
        $fixture = New-UpgradeFixture -Root (Join-Path $TestDrive 'string-false')
        Set-CompleteUpgradeSnapshot -Fixture $fixture -Audit 'string-false'
        $before = Get-RuntimeContents -Fixture $fixture

        $result = Invoke-FixtureUpgrade -Fixture $fixture

        $result.ExitCode | Should -Not -Be 0
        ($result.Output -join "`n") | Should -Match 'audit failed during trusted staging'
        (Get-RuntimeContents -Fixture $fixture | ConvertTo-Json) | Should -Be ($before | ConvertTo-Json)
    }

    It 'denies a wrong-type ERROR_COUNT from the trusted audit' {
        $fixture = New-UpgradeFixture -Root (Join-Path $TestDrive 'wrong-error-count-type')
        Set-CompleteUpgradeSnapshot -Fixture $fixture -Audit 'wrong-error-type'
        $before = Get-RuntimeContents -Fixture $fixture

        $result = Invoke-FixtureUpgrade -Fixture $fixture

        $result.ExitCode | Should -Not -Be 0
        ($result.Output -join "`n") | Should -Match 'audit failed during trusted staging'
        (Get-RuntimeContents -Fixture $fixture | ConvertTo-Json) | Should -Be ($before | ConvertTo-Json)
    }

    It 'denies a null WARNING_COUNT from the trusted audit' {
        $fixture = New-UpgradeFixture -Root (Join-Path $TestDrive 'null-warning-count')
        Set-CompleteUpgradeSnapshot -Fixture $fixture -Audit 'null-warning'
        $before = Get-RuntimeContents -Fixture $fixture

        $result = Invoke-FixtureUpgrade -Fixture $fixture

        $result.ExitCode | Should -Not -Be 0
        ($result.Output -join "`n") | Should -Match 'audit failed during trusted staging'
        (Get-RuntimeContents -Fixture $fixture | ConvertTo-Json) | Should -Be ($before | ConvertTo-Json)
    }

    It 'denies a self-approving candidate checker with the frozen trusted checker' {
        $fixture = New-UpgradeFixture -Root (Join-Path $TestDrive 'self-approving-checker')
        Set-CompleteUpgradeSnapshot -Fixture $fixture -Audit 'invalid'
        $selfApprovingChecker = @'
#!/usr/bin/env pwsh
param([switch]$Json)
[pscustomobject]@{ VALID = $true; ERROR_COUNT = 0; WARNING_COUNT = 0 } | ConvertTo-Json
'@
        Set-Utf8File -Path (Join-Path $fixture.Payload 'check-speckit-runtime.ps1') -Content $selfApprovingChecker
        $before = Get-RuntimeContents -Fixture $fixture

        $result = Invoke-FixtureUpgrade -Fixture $fixture

        $result.ExitCode | Should -Not -Be 0
        ($result.Output -join "`n") | Should -Match 'audit failed during trusted staging'
        (Get-RuntimeContents -Fixture $fixture | ConvertTo-Json) | Should -Be ($before | ConvertTo-Json)
    }

    It 'denies a self-approving candidate audit dependency using the frozen dependency closure' {
        $fixture = New-UpgradeFixture -Root (Join-Path $TestDrive 'self-approving-dependency')
        Set-CompleteUpgradeSnapshot -Fixture $fixture -Audit 'invalid'
        $selfApprovingHelper = @'
#!/usr/bin/env pwsh
param([string]$AuditValue, [string]$WorkspaceRoot)
[pscustomobject]@{ VALID = $true; ERROR_COUNT = 0; WARNING_COUNT = 0 } | ConvertTo-Json
'@
        Set-Utf8File -Path (Join-Path $fixture.Payload 'fixture-audit-helper.ps1') -Content $selfApprovingHelper
        $before = Get-RuntimeContents -Fixture $fixture

        $result = Invoke-FixtureUpgrade -Fixture $fixture

        $result.ExitCode | Should -Not -Be 0
        ($result.Output -join "`n") | Should -Match 'audit failed during trusted staging'
        (Get-RuntimeContents -Fixture $fixture | ConvertTo-Json) | Should -Be ($before | ConvertTo-Json)
    }

    It 'never executes a candidate checker that writes an absolute canonical path' {
        $fixture = New-UpgradeFixture -Root (Join-Path $TestDrive 'candidate-absolute-write')
        Set-CompleteUpgradeSnapshot -Fixture $fixture -Audit 'invalid'
        $outsideBaselineSentinel = Join-Path $fixture.Root 'canonical-outside-baseline.txt'
        Set-Utf8File -Path $outsideBaselineSentinel -Content 'canonical-unchanged'
        $absoluteWriter = @'
#!/usr/bin/env pwsh
param([switch]$Json)
[System.IO.File]::WriteAllText($env:SDD_UPGRADE_ATTACK_SENTINEL, 'candidate-executed')
[pscustomobject]@{ VALID = $true; ERROR_COUNT = 0; WARNING_COUNT = 0 } | ConvertTo-Json
exit 0
'@
        Set-Utf8File -Path (Join-Path $fixture.Payload 'check-speckit-runtime.ps1') -Content $absoluteWriter
        $before = Get-RuntimeContents -Fixture $fixture

        $previousSentinel = $env:SDD_UPGRADE_ATTACK_SENTINEL
        try {
            $env:SDD_UPGRADE_ATTACK_SENTINEL = $outsideBaselineSentinel
            $result = Invoke-FixtureUpgrade -Fixture $fixture
        } finally {
            $env:SDD_UPGRADE_ATTACK_SENTINEL = $previousSentinel
        }

        $result.ExitCode | Should -Not -Be 0
        ($result.Output -join "`n") | Should -Match 'audit failed during trusted staging'
        [System.IO.File]::ReadAllText($outsideBaselineSentinel) | Should -Be 'canonical-unchanged'
        (Get-RuntimeContents -Fixture $fixture | ConvertTo-Json) | Should -Be ($before | ConvertTo-Json)
    }

    It 'never lets candidate code tamper with trusted authority or baseline siblings' {
        $fixture = New-UpgradeFixture -Root (Join-Path $TestDrive 'candidate-sibling-tamper')
        Set-CompleteUpgradeSnapshot -Fixture $fixture -Audit 'invalid'
        $attackSentinel = Join-Path $fixture.Root 'transaction-sibling-attack.txt'
        Set-Utf8File -Path $attackSentinel -Content 'not-executed'
        $siblingTamper = @'
#!/usr/bin/env pwsh
param([switch]$Json)
$workspaceRoot = Split-Path $env:SDD_STUDIO_ROOT -Parent
if ((Split-Path $workspaceRoot -Leaf) -eq 'candidate') {
    $transactionRoot = Split-Path $workspaceRoot -Parent
    $trustedChecker = Join-Path $transactionRoot 'trusted-audit/studio/scripts/powershell/check-speckit-runtime.ps1'
    $selfApproval = @(
        '#!/usr/bin/env pwsh',
        'param([switch]$Json)',
        '[pscustomobject]@{ VALID = $true; ERROR_COUNT = 0; WARNING_COUNT = 0 } | ConvertTo-Json',
        'exit 0'
    ) -join [Environment]::NewLine
    [System.IO.File]::WriteAllText($trustedChecker, $selfApproval)
    $backups = @(Get-ChildItem -LiteralPath (Join-Path $transactionRoot 'baseline') -Filter '*.bak' -File)
    foreach ($backup in $backups) {
        [System.IO.File]::WriteAllText($backup.FullName, 'candidate-corrupted-baseline')
    }
    [System.IO.File]::WriteAllText(
        $env:SDD_UPGRADE_ATTACK_SENTINEL,
        "trusted-and-$($backups.Count)-baseline-files-tampered"
    )
}
[pscustomobject]@{ VALID = $true; ERROR_COUNT = 0; WARNING_COUNT = 0 } | ConvertTo-Json
exit 0
'@
        Set-Utf8File -Path (Join-Path $fixture.Payload 'check-speckit-runtime.ps1') -Content $siblingTamper
        $before = Get-RuntimeContents -Fixture $fixture

        $previousSentinel = $env:SDD_UPGRADE_ATTACK_SENTINEL
        try {
            $env:SDD_UPGRADE_ATTACK_SENTINEL = $attackSentinel
            $result = Invoke-FixtureUpgrade -Fixture $fixture
        } finally {
            $env:SDD_UPGRADE_ATTACK_SENTINEL = $previousSentinel
        }

        $result.ExitCode | Should -Not -Be 0
        ($result.Output -join "`n") | Should -Match 'audit failed during trusted staging'
        [System.IO.File]::ReadAllText($attackSentinel) | Should -Be 'not-executed'
        (Get-RuntimeContents -Fixture $fixture | ConvertTo-Json) | Should -Be ($before | ConvertTo-Json)
    }

    It 'never executes candidate version or export smoke scripts' {
        $fixture = New-UpgradeFixture -Root (Join-Path $TestDrive 'candidate-smoke-execution')
        Set-CompleteUpgradeSnapshot -Fixture $fixture
        $versionSentinel = Join-Path $fixture.Root 'version-smoke-sentinel.txt'
        $exportSentinel = Join-Path $fixture.Root 'export-smoke-sentinel.txt'
        Set-Utf8File -Path $versionSentinel -Content 'version-not-executed'
        Set-Utf8File -Path $exportSentinel -Content 'export-not-executed'
        $versionWriter = @'
#!/usr/bin/env pwsh
param([switch]$Json)
[System.IO.File]::WriteAllText($env:SDD_UPGRADE_VERSION_SMOKE_SENTINEL, 'version-executed')
[pscustomobject]@{ VALID = $true; version = 'candidate' } | ConvertTo-Json
exit 0
'@
        $exportWriter = @'
#!/usr/bin/env pwsh
param([string]$OutputDir, [switch]$Force, [switch]$Json)
[System.IO.File]::WriteAllText($env:SDD_UPGRADE_EXPORT_SMOKE_SENTINEL, 'export-executed')
[pscustomobject]@{ VALID = $true } | ConvertTo-Json
exit 0
'@
        Set-Utf8File `
            -Path (Join-Path $fixture.Root 'studio/scripts/powershell/get-speckit-version.ps1') `
            -Content $versionWriter
        Set-Utf8File `
            -Path (Join-Path $fixture.Root 'studio/scripts/powershell/export-extensions.ps1') `
            -Content $exportWriter

        $previousVersionSentinel = $env:SDD_UPGRADE_VERSION_SMOKE_SENTINEL
        $previousExportSentinel = $env:SDD_UPGRADE_EXPORT_SMOKE_SENTINEL
        try {
            $env:SDD_UPGRADE_VERSION_SMOKE_SENTINEL = $versionSentinel
            $env:SDD_UPGRADE_EXPORT_SMOKE_SENTINEL = $exportSentinel
            $result = Invoke-FixtureUpgrade -Fixture $fixture
        } finally {
            $env:SDD_UPGRADE_VERSION_SMOKE_SENTINEL = $previousVersionSentinel
            $env:SDD_UPGRADE_EXPORT_SMOKE_SENTINEL = $previousExportSentinel
        }

        $result.ExitCode | Should -Be 0
        [System.IO.File]::ReadAllText($versionSentinel) | Should -Be 'version-not-executed'
        [System.IO.File]::ReadAllText($exportSentinel) | Should -Be 'export-not-executed'
        $resultJson = $result.Output -join "`n" | ConvertFrom-Json
        @($resultJson.VERIFICATION.PSObject.Properties.Name) | Should -Not -Contain 'version'
        @($resultJson.VERIFICATION.PSObject.Properties.Name) | Should -Not -Contain 'skillsExport'
        @($resultJson.VERIFICATION.PSObject.Properties.Name) | Should -Not -Contain 'extensionExport'
    }

    It 'rolls back the complete promotion when canonical post-promotion audit differs from staging' {
        $fixture = New-UpgradeFixture -Root (Join-Path $TestDrive 'post-promotion-audit-failure')
        Set-CompleteUpgradeSnapshot -Fixture $fixture -First 'new-first' -Second 'new-second' -Audit 'stage-only'
        $before = Get-RuntimeContents -Fixture $fixture

        $result = Invoke-FixtureUpgrade -Fixture $fixture

        $result.ExitCode | Should -Not -Be 0
        ($result.Output -join "`n") | Should -Match 'audit failed during .*post-promotion verification'
        ($result.Output -join "`n") | Should -Match 'rollback completed and was verified'
        (Get-RuntimeContents -Fixture $fixture | ConvertTo-Json) | Should -Be ($before | ConvertTo-Json)
        @(Get-ChildItem -LiteralPath $fixture.Temp -Filter 'studio-runtime-upgrade-*' -Force).Count | Should -Be 0
    }

    It 'completes promotion and report when the frozen trusted checker explicitly exits zero' {
        $fixture = New-UpgradeFixture -Root (Join-Path $TestDrive 'trusted-explicit-exit-zero')
        Set-CompleteUpgradeSnapshot -Fixture $fixture

        $result = Invoke-FixtureUpgrade -Fixture $fixture

        $result.ExitCode | Should -Be 0
        $resultJson = $result.Output -join "`n" | ConvertFrom-Json
        $resultJson.TRANSACTION.stagingAudit | Should -Be 'passed'
        $resultJson.TRANSACTION.promotion | Should -Be 'committed'
        $resultJson.VERIFICATION.runtimeCheckPhase | Should -Be 'trusted-staging'
        @($resultJson.VERIFICATION.PSObject.Properties.Name) | Should -Not -Contain 'candidateRuntimeCheck'
        @($resultJson.VERIFICATION.PSObject.Properties.Name) | Should -Not -Contain 'candidateCanonicalRuntimeCheck'
        Test-Path -LiteralPath ([string]$resultJson.REPORT_PATH) -PathType Leaf | Should -BeTrue
    }

    It 'rolls back an earlier promoted file after a later apply failure and permits a clean retry' {
        $fixture = New-UpgradeFixture -Root (Join-Path $TestDrive 'apply-failure')
        Set-CompleteUpgradeSnapshot -Fixture $fixture
        $mirrorRoot = New-StaleRuntimeMirror -Fixture $fixture
        $before = Get-RuntimeContents -Fixture $fixture
        $lockedTarget = Join-Path $fixture.Runtime 'second.txt'
        $lock = [System.IO.File]::Open(
            $lockedTarget,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::Read
        )
        try {
            $failedResult = Invoke-FixtureUpgrade -Fixture $fixture
        } finally {
            $lock.Dispose()
        }

        $failedResult.ExitCode | Should -Not -Be 0
        ($failedResult.Output -join "`n") | Should -Match 'rollback completed and was verified'
        (Get-RuntimeContents -Fixture $fixture | ConvertTo-Json) | Should -Be ($before | ConvertTo-Json)
        [System.IO.File]::ReadAllText((Join-Path $mirrorRoot 'manifest.json')) | Should -Be '{"version":"stale"}'
        @(Get-ChildItem -LiteralPath $fixture.Temp -Filter 'studio-runtime-upgrade-*' -Force).Count | Should -Be 0

        $retryResult = Invoke-FixtureUpgrade -Fixture $fixture

        $retryResult.ExitCode | Should -Be 0
        [System.IO.File]::ReadAllText((Join-Path $fixture.Runtime 'first.txt')) | Should -Be 'new-first'
        [System.IO.File]::ReadAllText((Join-Path $fixture.Runtime 'second.txt')) | Should -Be 'new-second'
        [System.IO.File]::ReadAllText((Join-Path $fixture.Runtime 'audit.txt')) | Should -Be 'valid'
        Test-Path -LiteralPath (Join-Path $mirrorRoot 'manifest.json') | Should -BeFalse
        $retryJson = $retryResult.Output -join "`n" | ConvertFrom-Json
        $retryJson.TRANSACTION.stagingAudit | Should -Be 'passed'
        $retryJson.TRANSACTION.promotion | Should -Be 'committed'
        $retryJson.TRANSACTION.rollback | Should -Be 'not-required'
        $retryJson.VERIFICATION.runtimeMirror | Should -Be 'invalidated'
        $report = Get-Content -LiteralPath ([string]$retryJson.REPORT_PATH) -Raw | ConvertFrom-Json
        $report.TRANSACTION.promotion | Should -Be 'committed'
        $report.VERIFICATION.runtimeMirror | Should -Be 'invalidated'
        @(Get-ChildItem -LiteralPath $fixture.Temp -Filter 'studio-runtime-upgrade-*' -Force).Count | Should -Be 0
    }

    It 'retains a durable transaction journal when rollback verification fails' {
        $fixture = New-UpgradeFixture -Root (Join-Path $TestDrive 'rollback-evidence')
        Set-CompleteUpgradeSnapshot -Fixture $fixture
        $firstTarget = Join-Path $fixture.Runtime 'first.txt'
        $secondTarget = Join-Path $fixture.Runtime 'second.txt'
        $originalFirstHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $firstTarget).Hash
        $upgradeContent = [System.IO.File]::ReadAllText($fixture.Script)
        $newLine = if ($upgradeContent.Contains("`r`n")) { "`r`n" } else { "`n" }
        $injectionAnchor = @(
            '            -TrustedAuditBundle $trustedAuditBundle',
            '',
            '        foreach ($change in $changes) {'
        ) -join $newLine
        $injectionReplacement = @(
            '            -TrustedAuditBundle $trustedAuditBundle',
            '',
            '        $fixtureRollbackTarget = Join-Path $paths.WORKSPACE_ROOT ''runtime/first.txt''',
            '        $fixtureRollbackRecord = @($baseline | Where-Object { [string]$_.target -eq $fixtureRollbackTarget }) | Select-Object -First 1',
            '        if (-not $fixtureRollbackRecord -or -not $fixtureRollbackRecord.backup) {',
            '            throw ''Fixture rollback baseline record is missing.''',
            '        }',
            '        [System.IO.File]::WriteAllText([string]$fixtureRollbackRecord.backup, ''externally-corrupted-baseline'')',
            '',
            '        foreach ($change in $changes) {'
        ) -join $newLine
        [regex]::Matches($upgradeContent, [regex]::Escape($injectionAnchor)).Count | Should -Be 1
        Set-Utf8File `
            -Path $fixture.Script `
            -Content $upgradeContent.Replace(
                $injectionAnchor,
                $injectionReplacement,
                [System.StringComparison]::Ordinal
            )

        $lock = [System.IO.File]::Open(
            $secondTarget,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::Read
        )
        try {
            $result = Invoke-FixtureUpgrade -Fixture $fixture
        } finally {
            $lock.Dispose()
        }

        $result.ExitCode | Should -Not -Be 0
        ($result.Output -join "`n") | Should -Match 'CRITICAL:'
        ($result.Output -join "`n") | Should -Match 'Recovery evidence retained at:'
        [System.IO.File]::ReadAllText($firstTarget) | Should -Be 'new-first'
        [System.IO.File]::ReadAllText($firstTarget) | Should -Not -Be 'externally-corrupted-baseline'
        $transactions = @(Get-ChildItem -LiteralPath $fixture.Temp -Directory -Filter 'studio-runtime-upgrade-*')
        $transactions.Count | Should -Be 1
        $journalPath = Join-Path $transactions[0].FullName 'transaction-journal.json'
        Test-Path -LiteralPath $journalPath -PathType Leaf | Should -BeTrue
        $journal = Get-Content -LiteralPath $journalPath -Raw | ConvertFrom-Json
        $journal.state | Should -Be 'rollback-failed'
        $journal.failure | Should -Match 'Upgrade temporary file verification failed'
        $firstRecord = @($journal.baseline | Where-Object { [string]$_.target -eq $firstTarget }) |
            Select-Object -First 1
        $firstRecord | Should -Not -BeNullOrEmpty
        $firstRecord.hash | Should -Be $originalFirstHash
        $firstRecord.backup | Should -Not -BeNullOrEmpty
        Test-Path -LiteralPath ([string]$firstRecord.backup) -PathType Leaf | Should -BeTrue
        (Get-FileHash -Algorithm SHA256 -LiteralPath ([string]$firstRecord.backup)).Hash |
            Should -Not -Be $firstRecord.hash
        @($journal.trustedAuthority.files).Count | Should -BeGreaterThan 0
    }
}
