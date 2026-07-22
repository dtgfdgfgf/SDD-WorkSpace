#!/usr/bin/env pwsh

#Requires -Version 7.0

BeforeAll {
    . (Join-Path $PSScriptRoot 'governance.config.ps1')

    function script:Write-TestJson {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Path,
            [Parameter(Mandatory = $true)]
            [object]$Data
        )

        $parent = Split-Path -Parent $Path
        if (-not (Test-Path -LiteralPath $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        [PSCustomObject]$Data | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $Path -Encoding utf8NoBOM
    }

    function script:New-ExtensionFixture {
        $root = Join-Path $TestDrive ('extension-workspace-' + [guid]::NewGuid().ToString('N'))
        $scriptDir = Join-Path $root 'studio/scripts/powershell'
        $extensionRoot = Join-Path $root 'studio/extensions'
        New-Item -ItemType Directory -Path (Join-Path $root 'studio/constitution') -Force | Out-Null
        New-Item -ItemType Directory -Path $scriptDir -Force | Out-Null
        New-Item -ItemType Directory -Path $extensionRoot -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $root '.github/agents') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $root '.github/prompts') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $root 'studio/templates') -Force | Out-Null

        foreach ($name in @(
            'common.ps1',
            'extension-registry-common.ps1',
            'validate-extension-registry.ps1',
            'add-extension.ps1',
            'export-extensions.ps1',
            'set-extension-state.ps1',
            'remove-extension.ps1'
        )) {
            Copy-Item -LiteralPath (Join-Path $WorkspaceRoot "studio/scripts/powershell/$name") -Destination (Join-Path $scriptDir $name)
        }
        foreach ($name in @('catalog.schema.json', 'state.schema.json', 'manifest.schema.json', 'POLICY.md')) {
            Copy-Item -LiteralPath (Join-Path $WorkspaceRoot "studio/extensions/$name") -Destination (Join-Path $extensionRoot $name)
        }

        Set-Content -LiteralPath (Join-Path $root '.github/agents/core.agent.md') -Value '# core agent' -Encoding utf8NoBOM
        Set-Content -LiteralPath (Join-Path $root '.github/prompts/core.prompt.md') -Value '# core prompt' -Encoding utf8NoBOM
        Set-Content -LiteralPath (Join-Path $root 'studio/templates/core.md') -Value '# core template' -Encoding utf8NoBOM

        $catalog = [ordered]@{
            version = '1.2.0'
            updated = (Get-Date).ToString('o')
            policy = [ordered]@{
                mode = 'studio-first'
                curatedOnly = $true
                autoEnableNewExtensions = $false
                reviewStatuses = @('draft', 'approved', 'experimental', 'deprecated', 'rejected')
                trustLevels = @('core', 'curated', 'experimental')
                stateSources = @('default', 'manual')
            }
            extensions = @()
        }
        $state = [ordered]@{
            version = '1.1.0'
            updated = (Get-Date).ToString('o')
            states = @{}
        }
        Write-TestJson -Path (Join-Path $extensionRoot 'catalog.json') -Data $catalog
        Write-TestJson -Path (Join-Path $extensionRoot 'state.json') -Data $state

        return [PSCustomObject]@{
            Root = $root
            ScriptDir = $scriptDir
            ExtensionRoot = $extensionRoot
            CatalogPath = Join-Path $extensionRoot 'catalog.json'
            StatePath = Join-Path $extensionRoot 'state.json'
            MirrorRoot = Join-Path $root 'resources/studio-runtime/merged'
            TransactionRoot = Join-Path $root 'resources/studio-runtime/.extension-transactions'
        }
    }

    function script:New-TestExtensionSource {
        param(
            [Parameter(Mandatory = $true)]
            $Fixture,
            [string]$Id = 'fixture-extension',
            [string]$Version = '1.0.0',
            [string]$Kind = 'tooling',
            [string]$Status = 'active',
            [hashtable]$EntryPoints,
            [string]$ScriptContent = "'fixture-v1'"
        )

        $source = Join-Path $Fixture.Root ("incoming/{0}-{1}" -f $Id, [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $source 'scripts') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $source 'scripts/invoke.ps1') -Value $ScriptContent -Encoding utf8NoBOM
        if (-not $EntryPoints) {
            $EntryPoints = @{ scripts = @('scripts/invoke.ps1') }
        }
        $manifest = [ordered]@{
            id = $Id
            version = $Version
            title = "Fixture $Id"
            description = 'Isolated extension lifecycle fixture.'
            kind = $Kind
            status = $Status
            owner = 'tests'
            capabilities = @('fixture')
            runtimeScopes = @($EntryPoints.Keys)
            compatibility = @{ mode = 'studio-first' }
            entryPoints = $EntryPoints
            notes = 'fixture'
        }
        Write-TestJson -Path (Join-Path $source 'manifest.json') -Data $manifest
        return $source
    }

    function script:Invoke-ExtensionScript {
        param(
            [Parameter(Mandatory = $true)]
            $Fixture,
            [Parameter(Mandatory = $true)]
            [string]$Name,
            [string[]]$Arguments = @()
        )

        $output = & pwsh -NoProfile -File (Join-Path $Fixture.ScriptDir $Name) @Arguments 2>&1
        return [PSCustomObject]@{
            ExitCode = $LASTEXITCODE
            Raw = ($output | ForEach-Object { $_.ToString() }) -join "`n"
            Output = $output
        }
    }

    function script:Approve-TestExtension {
        param(
            [Parameter(Mandatory = $true)]
            $Fixture,
            [Parameter(Mandatory = $true)]
            [string]$Id
        )

        $catalog = Get-Content -LiteralPath $Fixture.CatalogPath -Raw | ConvertFrom-Json -AsHashtable
        $entry = @($catalog.extensions | Where-Object { $_.id -eq $Id }) | Select-Object -First 1
        $entry.reviewStatus = 'approved'
        $entry.trustLevel = 'curated'
        $entry.approvedBy = 'fixture-reviewer'
        $entry.approvedAt = (Get-Date).ToString('o')
        $entry.approvedContentSha256 = $entry.contentSha256
        $catalog.updated = (Get-Date).ToString('o')
        Write-TestJson -Path $Fixture.CatalogPath -Data $catalog
    }

    function script:Deprecate-TestExtension {
        param(
            [Parameter(Mandatory = $true)]
            $Fixture,
            [Parameter(Mandatory = $true)]
            [string]$Id
        )

        $catalog = Get-Content -LiteralPath $Fixture.CatalogPath -Raw | ConvertFrom-Json -AsHashtable
        $entry = @($catalog.extensions | Where-Object { $_.id -eq $Id }) | Select-Object -First 1
        $entry.reviewStatus = 'deprecated'
        $entry.defaultEnabled = $false
        $entry.approvedBy = $null
        $entry.approvedAt = $null
        $entry.approvedContentSha256 = $null
        $catalog.updated = (Get-Date).ToString('o')
        Write-TestJson -Path $Fixture.CatalogPath -Data $catalog
    }

    function script:Get-TestExtensionHash {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Root
        )

        $records = [System.Collections.Generic.List[string]]::new()
        foreach ($file in @(
            Get-ChildItem -LiteralPath $Root -File -Force -Recurse |
                Sort-Object { [System.IO.Path]::GetRelativePath($Root, $_.FullName) }
        )) {
            $relativePath = [System.IO.Path]::GetRelativePath($Root, $file.FullName).Replace('\', '/')
            $pathToken = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($relativePath))
            $fileHash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            $records.Add(('{0}:{1}:{2}' -f $pathToken, $file.Length, $fileHash))
        }
        $payload = [System.Text.Encoding]::UTF8.GetBytes(($records -join "`n"))
        return [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($payload)).ToLowerInvariant()
    }

    function script:New-TestCatalogEntry {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Id,
            [Parameter(Mandatory = $true)]
            [string]$ContentSha256
        )

        return [ordered]@{
            id = $Id
            version = '1.0.0'
            title = "Fixture $Id"
            sourcePath = "extensions/$Id"
            reviewStatus = 'draft'
            trustLevel = 'experimental'
            defaultEnabled = $false
            owner = 'tests'
            approvedBy = $null
            approvedAt = $null
            contentSha256 = $ContentSha256
            approvedContentSha256 = $null
            runtimeScopes = @('scripts')
            capabilities = @('fixture')
            notes = 'fixture'
        }
    }
}

Describe 'R6-A3 extension lifecycle truthfulness' {
    It 'rejects reintroduction of either retired compatibility version field' {
        $schema = Get-Content -LiteralPath (Join-Path $WorkspaceRoot 'studio/extensions/manifest.schema.json') -Raw | ConvertFrom-Json -AsHashtable
        $schema.properties.compatibility.additionalProperties | Should -BeFalse
        $schema.properties.compatibility.properties.ContainsKey('minStudioConstitutionVersion') | Should -BeFalse
        $schema.properties.compatibility.properties.ContainsKey('minWorkspaceStructureVersion') | Should -BeFalse

        $canonicalManifest = Get-Content -LiteralPath (Join-Path $WorkspaceRoot 'studio/extensions/extension-smoke/manifest.json') -Raw | ConvertFrom-Json -AsHashtable
        $canonicalManifest.compatibility.ContainsKey('minStudioConstitutionVersion') | Should -BeFalse
        $canonicalManifest.compatibility.ContainsKey('minWorkspaceStructureVersion') | Should -BeFalse

        foreach ($field in @('minStudioConstitutionVersion', 'minWorkspaceStructureVersion')) {
            $fixture = New-ExtensionFixture
            $source = New-TestExtensionSource -Fixture $fixture
            $manifestPath = Join-Path $source 'manifest.json'
            $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -AsHashtable
            $manifest.compatibility[$field] = '9.9.9'
            Write-TestJson -Path $manifestPath -Data $manifest
            $beforeCatalog = Get-Content -LiteralPath $fixture.CatalogPath -Raw

            $result = Invoke-ExtensionScript -Fixture $fixture -Name 'add-extension.ps1' -Arguments @('-SourceDir', $source, '-Json')

            $result.ExitCode | Should -Not -Be 0 -Because $field
            $result.Raw | Should -Match 'schema validation failed|does not conform to schema' -Because $field
            (Get-Content -LiteralPath $fixture.CatalogPath -Raw) | Should -BeExactly $beforeCatalog -Because $field
            (Test-Path -LiteralPath (Join-Path $fixture.ExtensionRoot 'fixture-extension')) | Should -BeFalse -Because $field
        }
    }

    It 'rejects sync in both catalog policy and state sources' {
        $catalogFixture = New-ExtensionFixture
        $catalog = Get-Content -LiteralPath $catalogFixture.CatalogPath -Raw | ConvertFrom-Json -AsHashtable
        $catalog.policy.stateSources = @('default', 'manual', 'sync')
        Write-TestJson -Path $catalogFixture.CatalogPath -Data $catalog

        $catalogValidation = Invoke-ExtensionScript -Fixture $catalogFixture -Name 'validate-extension-registry.ps1' -Arguments @('-Json')
        $catalogParsed = $catalogValidation.Raw | ConvertFrom-Json
        $catalogParsed.VALID | Should -BeFalse
        ($catalogParsed.ERRORS -join "`n") | Should -Match 'schema validation failed|does not conform to schema'

        $stateFixture = New-ExtensionFixture
        $source = New-TestExtensionSource -Fixture $stateFixture
        (Invoke-ExtensionScript -Fixture $stateFixture -Name 'add-extension.ps1' -Arguments @('-SourceDir', $source, '-Json')).ExitCode | Should -Be 0
        $state = Get-Content -LiteralPath $stateFixture.StatePath -Raw | ConvertFrom-Json -AsHashtable
        $state.states['fixture-extension'] = [ordered]@{
            enabled = $false
            pinnedVersion = '1.0.0'
            changedAt = (Get-Date).ToString('o')
            source = 'sync'
        }
        Write-TestJson -Path $stateFixture.StatePath -Data $state

        $stateValidation = Invoke-ExtensionScript -Fixture $stateFixture -Name 'validate-extension-registry.ps1' -Arguments @('-Json')
        $stateParsed = $stateValidation.Raw | ConvertFrom-Json
        $stateParsed.VALID | Should -BeFalse
        ($stateParsed.ERRORS -join "`n") | Should -Match 'schema validation failed|does not conform to schema|Unsupported state source'
    }

    It 'denies deprecated enablement from <Name>' -ForEach @(
        @{ Name = 'a missing state entry'; Kind = 'missing'; RegistryValid = $true }
        @{ Name = 'a disabled state'; Kind = 'disabled'; RegistryValid = $true }
        @{ Name = 'a null pin'; Kind = 'null-pin'; RegistryValid = $false }
        @{ Name = 'a stale pin'; Kind = 'stale-pin'; RegistryValid = $false }
        @{ Name = 'a wrong-type enabled value'; Kind = 'wrong-type'; RegistryValid = $false }
        @{ Name = 'a sync source'; Kind = 'sync'; RegistryValid = $false }
        @{ Name = 'a null provenance source'; Kind = 'source-null'; RegistryValid = $false }
        @{ Name = 'a wrong-type provenance source'; Kind = 'source-wrong-type'; RegistryValid = $false }
    ) {
        $fixture = New-ExtensionFixture
        $source = New-TestExtensionSource -Fixture $fixture
        (Invoke-ExtensionScript -Fixture $fixture -Name 'add-extension.ps1' -Arguments @('-SourceDir', $source, '-Json')).ExitCode | Should -Be 0
        Deprecate-TestExtension -Fixture $fixture -Id 'fixture-extension'

        if ($Kind -ne 'missing') {
            $state = Get-Content -LiteralPath $fixture.StatePath -Raw | ConvertFrom-Json -AsHashtable
            $state.states['fixture-extension'] = [ordered]@{
                enabled = if ($Kind -eq 'disabled') { $false } elseif ($Kind -eq 'wrong-type') { 'true' } else { $true }
                pinnedVersion = if ($Kind -eq 'null-pin') { $null } elseif ($Kind -eq 'stale-pin') { '0.9.0' } else { '1.0.0' }
                changedAt = (Get-Date).ToString('o')
                source = if ($Kind -eq 'sync') {
                    'sync'
                } elseif ($Kind -eq 'source-null') {
                    $null
                } elseif ($Kind -eq 'source-wrong-type') {
                    42
                } else {
                    'manual'
                }
            }
            Write-TestJson -Path $fixture.StatePath -Data $state
        }

        $beforeState = Get-Content -LiteralPath $fixture.StatePath -Raw
        $validation = Invoke-ExtensionScript -Fixture $fixture -Name 'validate-extension-registry.ps1' -Arguments @('-Json')
        $parsedValidation = $validation.Raw | ConvertFrom-Json
        $parsedValidation.VALID | Should -Be $RegistryValid
        if ($Kind -in @('null-pin', 'stale-pin')) {
            ($parsedValidation.ERRORS -join "`n") | Should -Match 'Deprecated extension.*exact pinnedVersion'
        }

        $result = Invoke-ExtensionScript -Fixture $fixture -Name 'set-extension-state.ps1' -Arguments @('-Id', 'fixture-extension', '-State', 'enabled', '-Json')

        $result.ExitCode | Should -Not -Be 0
        (Get-Content -LiteralPath $fixture.StatePath -Raw) | Should -BeExactly $beforeState
    }

    It 'treats an already-enabled same-pin deprecated request as a byte-preserving no-op' {
        $fixture = New-ExtensionFixture
        $source = New-TestExtensionSource -Fixture $fixture
        (Invoke-ExtensionScript -Fixture $fixture -Name 'add-extension.ps1' -Arguments @('-SourceDir', $source, '-Json')).ExitCode | Should -Be 0
        Approve-TestExtension -Fixture $fixture -Id 'fixture-extension'
        (Invoke-ExtensionScript -Fixture $fixture -Name 'set-extension-state.ps1' -Arguments @('-Id', 'fixture-extension', '-State', 'enabled', '-Json')).ExitCode | Should -Be 0
        Deprecate-TestExtension -Fixture $fixture -Id 'fixture-extension'
        New-Item -ItemType Directory -Path $fixture.MirrorRoot -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $fixture.MirrorRoot 'sentinel.txt') -Value 'preserve-deprecated-no-op' -Encoding utf8NoBOM
        $beforeState = Get-Content -LiteralPath $fixture.StatePath -Raw

        $beforeValidation = Invoke-ExtensionScript -Fixture $fixture -Name 'validate-extension-registry.ps1' -Arguments @('-Json')
        ($beforeValidation.Raw | ConvertFrom-Json).VALID | Should -BeTrue
        $result = Invoke-ExtensionScript -Fixture $fixture -Name 'set-extension-state.ps1' -Arguments @('-Id', 'fixture-extension', '-State', 'enabled', '-Json')
        $parsed = $result.Raw | ConvertFrom-Json

        $result.ExitCode | Should -Be 0
        $parsed.NO_OP | Should -BeTrue
        $parsed.MIRROR_INVALIDATED | Should -BeFalse
        (Get-Content -LiteralPath $fixture.StatePath -Raw) | Should -BeExactly $beforeState
        (Get-Content -LiteralPath (Join-Path $fixture.MirrorRoot 'sentinel.txt') -Raw).Trim() | Should -BeExactly 'preserve-deprecated-no-op'
        @(Get-ChildItem -LiteralPath $fixture.TransactionRoot -Directory -ErrorAction SilentlyContinue).Count | Should -Be 0
    }
}

Describe 'RB-4 extension registry integrity' {
    It 'applies all three JSON schemas before accepting registry or manifest data' {
        $fixture = New-ExtensionFixture
        $catalog = Get-Content -LiteralPath $fixture.CatalogPath -Raw | ConvertFrom-Json -AsHashtable
        $catalog.policy.curatedOnly = 'true'
        Write-TestJson -Path $fixture.CatalogPath -Data $catalog

        $validation = Invoke-ExtensionScript -Fixture $fixture -Name 'validate-extension-registry.ps1' -Arguments @('-Json')
        $parsed = $validation.Raw | ConvertFrom-Json
        $parsed.VALID | Should -BeFalse
        ($parsed.ERRORS -join "`n") | Should -Match 'schema validation failed|does not conform to schema'

        $fixture2 = New-ExtensionFixture
        $source = New-TestExtensionSource -Fixture $fixture2 -Kind 'commands'
        $beforeCatalog = Get-Content -LiteralPath $fixture2.CatalogPath -Raw
        $add = Invoke-ExtensionScript -Fixture $fixture2 -Name 'add-extension.ps1' -Arguments @('-SourceDir', $source, '-Force', '-Json')
        $add.ExitCode | Should -Not -Be 0
        $add.Raw | Should -Match 'invalid before mutation'
        (Get-Content -LiteralPath $fixture2.CatalogPath -Raw) | Should -BeExactly $beforeCatalog
        (Test-Path -LiteralPath (Join-Path $fixture2.ExtensionRoot 'fixture-extension')) | Should -BeFalse
    }

    It 'rejects normalized cross-scope entry points before any mutation' {
        $fixture = New-ExtensionFixture
        $source = New-TestExtensionSource -Fixture $fixture -EntryPoints @{ scripts = @('scripts/../docs/readme.md') }
        New-Item -ItemType Directory -Path (Join-Path $source 'docs') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $source 'docs/readme.md') -Value 'cross-scope' -Encoding utf8NoBOM
        $beforeCatalog = Get-Content -LiteralPath $fixture.CatalogPath -Raw

        $result = Invoke-ExtensionScript -Fixture $fixture -Name 'add-extension.ps1' -Arguments @('-SourceDir', $source, '-Force', '-Json')

        $result.ExitCode | Should -Not -Be 0
        $result.Raw | Should -Match 'escapes declared scope'
        (Get-Content -LiteralPath $fixture.CatalogPath -Raw) | Should -BeExactly $beforeCatalog
        (Test-Path -LiteralPath (Join-Path $fixture.ExtensionRoot 'fixture-extension')) | Should -BeFalse
    }

    It 'rejects extension content containing a reparse point before mutation' -Skip:(-not $IsWindows) {
        $fixture = New-ExtensionFixture
        $source = New-TestExtensionSource -Fixture $fixture -EntryPoints @{ scripts = @('scripts/link/payload.ps1') }
        $external = Join-Path $fixture.Root 'incoming/reparse-target'
        New-Item -ItemType Directory -Path $external -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $external 'payload.ps1') -Value "'outside'" -Encoding utf8NoBOM
        New-Item -ItemType Junction -Path (Join-Path $source 'scripts/link') -Target $external | Out-Null

        $result = Invoke-ExtensionScript -Fixture $fixture -Name 'add-extension.ps1' -Arguments @('-SourceDir', $source, '-Force', '-Json')

        $result.ExitCode | Should -Not -Be 0
        $result.Raw | Should -Match 'cannot contain reparse points'
        (Test-Path -LiteralPath (Join-Path $fixture.ExtensionRoot 'fixture-extension')) | Should -BeFalse
    }

    It 'rejects an extension root directory that is a junction to external authority' -Skip:(-not $IsWindows) {
        $fixture = New-ExtensionFixture
        $source = New-TestExtensionSource -Fixture $fixture -Id 'junction-extension'
        $contentHash = Get-TestExtensionHash -Root $source
        New-Item -ItemType Junction -Path (Join-Path $fixture.ExtensionRoot 'junction-extension') -Target $source | Out-Null
        $catalog = Get-Content -LiteralPath $fixture.CatalogPath -Raw | ConvertFrom-Json -AsHashtable
        $catalog.extensions = @(
            New-TestCatalogEntry -Id 'junction-extension' -ContentSha256 $contentHash
        )
        Write-TestJson -Path $fixture.CatalogPath -Data $catalog

        $validation = Invoke-ExtensionScript -Fixture $fixture -Name 'validate-extension-registry.ps1' -Arguments @('-Json')
        $parsed = $validation.Raw | ConvertFrom-Json

        $parsed.VALID | Should -BeFalse
        ($parsed.ERRORS -join "`n") | Should -Match 'Extension directory escapes extensions root through a reparse point'
    }

    It 'keeps the existing target catalog and mirror when post-mutation validation fails' {
        $fixture = New-ExtensionFixture
        $orphan = New-TestExtensionSource -Fixture $fixture -Id 'orphan-extension'
        Copy-Item -LiteralPath $orphan -Destination (Join-Path $fixture.ExtensionRoot 'orphan-extension') -Recurse
        New-Item -ItemType Directory -Path $fixture.MirrorRoot -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $fixture.MirrorRoot 'sentinel.txt') -Value 'original-mirror' -Encoding utf8NoBOM
        $source = New-TestExtensionSource -Fixture $fixture
        $beforeCatalog = Get-Content -LiteralPath $fixture.CatalogPath -Raw

        $result = Invoke-ExtensionScript -Fixture $fixture -Name 'add-extension.ps1' -Arguments @('-SourceDir', $source, '-Force', '-Json')

        $result.ExitCode | Should -Not -Be 0
        $result.Raw | Should -Match 'Rollback completed'
        (Get-Content -LiteralPath $fixture.CatalogPath -Raw) | Should -BeExactly $beforeCatalog
        (Test-Path -LiteralPath (Join-Path $fixture.ExtensionRoot 'fixture-extension')) | Should -BeFalse
        (Get-Content -LiteralPath (Join-Path $fixture.MirrorRoot 'sentinel.txt') -Raw).Trim() | Should -Be 'original-mirror'
        @(Get-ChildItem -LiteralPath $fixture.TransactionRoot -Directory -ErrorAction SilentlyContinue).Count | Should -Be 0
    }

    It 'invalidates content-bound approval trust state and mirror on force replacement' {
        $fixture = New-ExtensionFixture
        $source = New-TestExtensionSource -Fixture $fixture
        (Invoke-ExtensionScript -Fixture $fixture -Name 'add-extension.ps1' -Arguments @('-SourceDir', $source, '-Json')).ExitCode | Should -Be 0
        Approve-TestExtension -Fixture $fixture -Id 'fixture-extension'
        (Invoke-ExtensionScript -Fixture $fixture -Name 'set-extension-state.ps1' -Arguments @('-Id', 'fixture-extension', '-State', 'enabled', '-Json')).ExitCode | Should -Be 0
        (Invoke-ExtensionScript -Fixture $fixture -Name 'export-extensions.ps1' -Arguments @('-Force', '-Json')).ExitCode | Should -Be 0

        $replacement = New-TestExtensionSource -Fixture $fixture -Version '1.0.1' -ScriptContent "'fixture-v2'"
        $replace = Invoke-ExtensionScript -Fixture $fixture -Name 'add-extension.ps1' -Arguments @('-SourceDir', $replacement, '-Force', '-Json')

        $replace.ExitCode | Should -Be 0
        $catalog = Get-Content -LiteralPath $fixture.CatalogPath -Raw | ConvertFrom-Json -AsHashtable
        $entry = @($catalog.extensions | Where-Object id -eq 'fixture-extension') | Select-Object -First 1
        $entry.reviewStatus | Should -Be 'draft'
        $entry.trustLevel | Should -Be 'experimental'
        $entry.defaultEnabled | Should -BeFalse
        $entry.approvedBy | Should -BeNullOrEmpty
        $entry.approvedAt | Should -BeNullOrEmpty
        $entry.approvedContentSha256 | Should -BeNullOrEmpty
        $entry.contentSha256 | Should -Match '^[a-f0-9]{64}$'
        $state = Get-Content -LiteralPath $fixture.StatePath -Raw | ConvertFrom-Json -AsHashtable
        $state.states.ContainsKey('fixture-extension') | Should -BeFalse
        (Test-Path -LiteralPath $fixture.MirrorRoot) | Should -BeFalse
    }

    It 'rolls back catalog target and state when the second replacement write fails' -Skip:(-not $IsWindows) {
        $fixture = New-ExtensionFixture
        $source = New-TestExtensionSource -Fixture $fixture -ScriptContent "'original'"
        (Invoke-ExtensionScript -Fixture $fixture -Name 'add-extension.ps1' -Arguments @('-SourceDir', $source, '-Json')).ExitCode | Should -Be 0
        Approve-TestExtension -Fixture $fixture -Id 'fixture-extension'
        (Invoke-ExtensionScript -Fixture $fixture -Name 'set-extension-state.ps1' -Arguments @('-Id', 'fixture-extension', '-State', 'enabled', '-Json')).ExitCode | Should -Be 0
        $beforeCatalog = Get-Content -LiteralPath $fixture.CatalogPath -Raw
        $beforeState = Get-Content -LiteralPath $fixture.StatePath -Raw
        $beforeTarget = Get-Content -LiteralPath (Join-Path $fixture.ExtensionRoot 'fixture-extension/scripts/invoke.ps1') -Raw
        $replacement = New-TestExtensionSource -Fixture $fixture -Version '1.0.1' -ScriptContent "'replacement'"

        $lock = [System.IO.File]::Open(
            $fixture.StatePath,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::Read
        )
        try {
            $result = Invoke-ExtensionScript -Fixture $fixture -Name 'add-extension.ps1' -Arguments @('-SourceDir', $replacement, '-Force', '-Json')
        } finally {
            $lock.Dispose()
        }

        $result.ExitCode | Should -Not -Be 0
        $result.Raw | Should -Match 'state rollback failed'
        (Get-Content -LiteralPath $fixture.CatalogPath -Raw) | Should -BeExactly $beforeCatalog
        (Get-Content -LiteralPath $fixture.StatePath -Raw) | Should -BeExactly $beforeState
        (Get-Content -LiteralPath (Join-Path $fixture.ExtensionRoot 'fixture-extension/scripts/invoke.ps1') -Raw) | Should -BeExactly $beforeTarget
    }

    It 'rolls back catalog target and state when the second removal write fails' -Skip:(-not $IsWindows) {
        $fixture = New-ExtensionFixture
        $source = New-TestExtensionSource -Fixture $fixture
        (Invoke-ExtensionScript -Fixture $fixture -Name 'add-extension.ps1' -Arguments @('-SourceDir', $source, '-Json')).ExitCode | Should -Be 0
        Approve-TestExtension -Fixture $fixture -Id 'fixture-extension'
        (Invoke-ExtensionScript -Fixture $fixture -Name 'set-extension-state.ps1' -Arguments @('-Id', 'fixture-extension', '-State', 'enabled', '-Json')).ExitCode | Should -Be 0
        $beforeCatalog = Get-Content -LiteralPath $fixture.CatalogPath -Raw
        $beforeState = Get-Content -LiteralPath $fixture.StatePath -Raw

        $lock = [System.IO.File]::Open(
            $fixture.StatePath,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::Read
        )
        try {
            $result = Invoke-ExtensionScript -Fixture $fixture -Name 'remove-extension.ps1' -Arguments @('-Id', 'fixture-extension', '-Json')
        } finally {
            $lock.Dispose()
        }

        $result.ExitCode | Should -Not -Be 0
        $result.Raw | Should -Match 'state rollback failed'
        (Get-Content -LiteralPath $fixture.CatalogPath -Raw) | Should -BeExactly $beforeCatalog
        (Get-Content -LiteralPath $fixture.StatePath -Raw) | Should -BeExactly $beforeState
        (Test-Path -LiteralPath (Join-Path $fixture.ExtensionRoot 'fixture-extension/manifest.json')) | Should -BeTrue
    }

    It 'restores the mirror when the state write itself fails' -Skip:(-not $IsWindows) {
        $fixture = New-ExtensionFixture
        $source = New-TestExtensionSource -Fixture $fixture
        (Invoke-ExtensionScript -Fixture $fixture -Name 'add-extension.ps1' -Arguments @('-SourceDir', $source, '-Json')).ExitCode | Should -Be 0
        Approve-TestExtension -Fixture $fixture -Id 'fixture-extension'
        New-Item -ItemType Directory -Path $fixture.MirrorRoot -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $fixture.MirrorRoot 'sentinel.txt') -Value 'active-before-write' -Encoding utf8NoBOM
        $beforeState = Get-Content -LiteralPath $fixture.StatePath -Raw

        $lock = [System.IO.File]::Open(
            $fixture.StatePath,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::Read
        )
        try {
            $result = Invoke-ExtensionScript -Fixture $fixture -Name 'set-extension-state.ps1' -Arguments @('-Id', 'fixture-extension', '-State', 'enabled', '-Json')
        } finally {
            $lock.Dispose()
        }

        $result.ExitCode | Should -Not -Be 0
        (Get-Content -LiteralPath $fixture.StatePath -Raw) | Should -BeExactly $beforeState
        (Get-Content -LiteralPath (Join-Path $fixture.MirrorRoot 'sentinel.txt') -Raw).Trim() | Should -Be 'active-before-write'

        $production = Get-Content -LiteralPath (Join-Path $WorkspaceRoot 'studio/scripts/powershell/set-extension-state.ps1') -Raw
        $attemptFlag = $production.IndexOf('$stateMutationAttempted = $true')
        $stateWrite = $production.IndexOf('Write-JsonFile -Path $paths.EXTENSIONS_STATE_PATH', $attemptFlag)
        $rollbackGuard = $production.IndexOf('if ($stateMutationAttempted)', $stateWrite)
        $attemptFlag | Should -BeGreaterThan -1
        $stateWrite | Should -BeGreaterThan $attemptFlag
        $rollbackGuard | Should -BeGreaterThan $stateWrite
    }

    It 'retains hash-bound recovery evidence when state rollback cannot write its baseline' -Skip:(-not $IsWindows) {
        $fixture = New-ExtensionFixture
        $source = New-TestExtensionSource -Fixture $fixture
        (Invoke-ExtensionScript -Fixture $fixture -Name 'add-extension.ps1' -Arguments @('-SourceDir', $source, '-Json')).ExitCode | Should -Be 0
        Approve-TestExtension -Fixture $fixture -Id 'fixture-extension'
        $beforeState = Get-Content -LiteralPath $fixture.StatePath -Raw

        $lock = [System.IO.File]::Open(
            $fixture.StatePath,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::Read
        )
        try {
            $result = Invoke-ExtensionScript -Fixture $fixture -Name 'set-extension-state.ps1' -Arguments @('-Id', 'fixture-extension', '-State', 'enabled', '-Json')
        } finally {
            $lock.Dispose()
        }

        $result.ExitCode | Should -Not -Be 0
        $result.Raw | Should -Match 'state rollback failed'
        $result.Raw | Should -Match 'Recovery evidence retained at:'
        (Get-Content -LiteralPath $fixture.StatePath -Raw) | Should -BeExactly $beforeState

        $transactions = @(Get-ChildItem -LiteralPath $fixture.TransactionRoot -Directory -ErrorAction Stop)
        $transactions.Count | Should -Be 1
        $transactionDir = $transactions[0].FullName
        $result.Raw | Should -Match ([regex]::Escape($transactionDir))

        $journalPath = Join-Path $transactionDir 'recovery.json'
        $backupPath = Join-Path $transactionDir 'baseline/state.json'
        $hashPath = "$backupPath.sha256"
        (Test-Path -LiteralPath $journalPath -PathType Leaf) | Should -BeTrue
        (Test-Path -LiteralPath $backupPath -PathType Leaf) | Should -BeTrue
        (Test-Path -LiteralPath $hashPath -PathType Leaf) | Should -BeTrue
        (Get-Content -LiteralPath $backupPath -Raw) | Should -BeExactly $beforeState

        $expectedSha256 = (Get-Content -LiteralPath $hashPath -Raw).Trim()
        $actualSha256 = (Get-FileHash -LiteralPath $backupPath -Algorithm SHA256).Hash.ToLowerInvariant()
        $expectedSha256 | Should -Match '^[a-f0-9]{64}$'
        $actualSha256 | Should -BeExactly $expectedSha256

        $journal = Get-Content -LiteralPath $journalPath -Raw | ConvertFrom-Json -AsHashtable
        $journal.operation | Should -BeExactly 'set-state'
        @($journal.baselineFiles).Count | Should -Be 1
        $journal.baselineFiles[0].backupPath | Should -BeExactly 'baseline/state.json'
        $journal.baselineFiles[0].sha256 | Should -BeExactly $expectedSha256
    }

    It 'keeps retained transaction evidence out of root git status and git add' {
        $repositoryRoot = Join-Path $TestDrive ('extension-recovery-git-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $repositoryRoot -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $WorkspaceRoot '.gitignore') -Destination (Join-Path $repositoryRoot '.gitignore')
        Set-Content -LiteralPath (Join-Path $repositoryRoot 'README.md') -Value '# fixture' -Encoding utf8NoBOM

        $transactionRelativePath = 'resources/studio-runtime/.extension-transactions/fixture-transaction'
        $transactionDir = Join-Path $repositoryRoot $transactionRelativePath
        New-Item -ItemType Directory -Path (Join-Path $transactionDir 'baseline') -Force | Out-Null
        Write-TestJson -Path (Join-Path $transactionDir 'recovery.json') -Data ([ordered]@{
            version = 1
            sourcePath = 'C:\local\authority\studio\extensions\state.json'
        })
        Set-Content -LiteralPath (Join-Path $transactionDir 'baseline/state.json') -Value '{"states":{}}' -Encoding utf8NoBOM

        & git -C $repositoryRoot init --quiet
        $LASTEXITCODE | Should -Be 0
        $ignoreEvidence = @(& git -C $repositoryRoot check-ignore -v -- "$transactionRelativePath/recovery.json")
        $LASTEXITCODE | Should -Be 0
        ($ignoreEvidence -join "`n") | Should -Match '/resources/studio-runtime/\.extension-transactions/'

        & git -C $repositoryRoot add .
        $LASTEXITCODE | Should -Be 0
        $status = @(& git -C $repositoryRoot status --short)
        ($status -join "`n") | Should -Not -Match '\.extension-transactions'
        @(& git -C $repositoryRoot ls-files) | Should -Not -Contain "$transactionRelativePath/recovery.json"
        @(& git -C $repositoryRoot ls-files) | Should -Not -Contain "$transactionRelativePath/baseline/state.json"
    }

    It 'restores a transaction baseline through verified same-directory atomic replacement' {
        $helperPath = Join-Path $WorkspaceRoot 'studio/scripts/powershell/extension-registry-common.ps1'
        $production = Get-Content -LiteralPath $helperPath -Raw
        $temporaryHashIndex = $production.IndexOf('$temporarySha256 = (Get-FileHash -LiteralPath $temporaryPath')
        $atomicMoveIndex = $production.IndexOf('[System.IO.File]::Move($temporaryPath, $sourcePath, $true)')

        $production | Should -Match '\$temporaryPath\s*=\s*Join-Path \$sourceDirectory'
        $production | Should -Not -Match '\[System\.IO\.File\]::WriteAllBytes\(\$sourcePath'
        $temporaryHashIndex | Should -BeGreaterThan -1
        $atomicMoveIndex | Should -BeGreaterThan $temporaryHashIndex

        . (Get-ScriptFunctionsBlock -ScriptPath $helperPath)
        $fixtureRoot = Join-Path $TestDrive ('atomic-extension-restore-' + [guid]::NewGuid().ToString('N'))
        $sourceDir = Join-Path $fixtureRoot 'canonical'
        $baselineDir = Join-Path $fixtureRoot 'transaction/baseline'
        New-Item -ItemType Directory -Path $sourceDir, $baselineDir -Force | Out-Null
        $sourcePath = Join-Path $sourceDir 'state.json'
        $backupPath = Join-Path $baselineDir 'state.json'
        $hashPath = "$backupPath.sha256"
        [System.IO.File]::WriteAllText($sourcePath, '{"authority":"candidate"}', [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText($backupPath, '{"authority":"baseline"}', [System.Text.UTF8Encoding]::new($false))
        $expectedSha256 = (Get-FileHash -LiteralPath $backupPath -Algorithm SHA256).Hash.ToLowerInvariant()
        [System.IO.File]::WriteAllText($hashPath, $expectedSha256, [System.Text.UTF8Encoding]::new($false))
        $baseline = [PSCustomObject][ordered]@{
            SOURCE_PATH = $sourcePath
            BACKUP_PATH = $backupPath
            HASH_PATH   = $hashPath
            SHA256      = $expectedSha256
        }

        Restore-ExtensionTransactionFileBaseline -Baseline $baseline

        [System.IO.File]::ReadAllText($sourcePath) | Should -BeExactly '{"authority":"baseline"}'
        (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash.ToLowerInvariant() | Should -BeExactly $expectedSha256
        @(Get-ChildItem -LiteralPath $sourceDir -Filter '.*.extension-restore-*.tmp' -File -Force).Count | Should -Be 0
        (Test-Path -LiteralPath $backupPath -PathType Leaf) | Should -BeTrue
        (Test-Path -LiteralPath $hashPath -PathType Leaf) | Should -BeTrue
    }

    It 'detects byte replacement after approval even when manifest identity is unchanged' {
        $fixture = New-ExtensionFixture
        $source = New-TestExtensionSource -Fixture $fixture
        (Invoke-ExtensionScript -Fixture $fixture -Name 'add-extension.ps1' -Arguments @('-SourceDir', $source, '-Json')).ExitCode | Should -Be 0
        Approve-TestExtension -Fixture $fixture -Id 'fixture-extension'
        Set-Content -LiteralPath (Join-Path $fixture.ExtensionRoot 'fixture-extension/scripts/invoke.ps1') -Value "'tampered'" -Encoding utf8NoBOM

        $validation = Invoke-ExtensionScript -Fixture $fixture -Name 'validate-extension-registry.ps1' -Arguments @('-Json')
        $parsed = $validation.Raw | ConvertFrom-Json

        $parsed.VALID | Should -BeFalse
        ($parsed.ERRORS -join "`n") | Should -Match 'contentSha256 does not match actual extension bytes'
        ($parsed.ERRORS -join "`n") | Should -Match 'Content-bound approval is stale'
    }

    It 'denies a force export outside the fixture workspace without touching the target' {
        $fixture = New-ExtensionFixture
        $outside = Join-Path $TestDrive 'outside-export'
        New-Item -ItemType Directory -Path $outside -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $outside 'sentinel.txt') -Value 'do-not-touch' -Encoding utf8NoBOM

        $result = Invoke-ExtensionScript -Fixture $fixture -Name 'export-extensions.ps1' -Arguments @('-OutputDir', $outside, '-Force', '-Json')

        $result.ExitCode | Should -Not -Be 0
        $result.Raw | Should -Match 'must stay inside the workspace'
        (Get-Content -LiteralPath (Join-Path $outside 'sentinel.txt') -Raw).Trim() | Should -Be 'do-not-touch'
    }

    It 'denies force export over an output tree containing a reparse point' -Skip:(-not $IsWindows) {
        $fixture = New-ExtensionFixture
        $external = Join-Path $TestDrive ('external-export-content-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $external -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $external 'sentinel.txt') -Value 'external-authority' -Encoding utf8NoBOM
        New-Item -ItemType Directory -Path $fixture.MirrorRoot -Force | Out-Null
        New-Item -ItemType Junction -Path (Join-Path $fixture.MirrorRoot 'linked-content') -Target $external | Out-Null

        $result = Invoke-ExtensionScript -Fixture $fixture -Name 'export-extensions.ps1' -Arguments @('-Force', '-Json')

        $result.ExitCode | Should -Not -Be 0
        $result.Raw | Should -Match 'output trees cannot contain reparse points'
        (Get-Content -LiteralPath (Join-Path $external 'sentinel.txt') -Raw).Trim() | Should -Be 'external-authority'
    }

    It 'denies a workspace alias whose physical output overlaps the extension authority root' -Skip:(-not $IsWindows) {
        $fixture = New-ExtensionFixture
        $alias = Join-Path $fixture.Root 'extension-authority-alias'
        New-Item -ItemType Junction -Path $alias -Target $fixture.ExtensionRoot | Out-Null
        $output = Join-Path $alias 'generated-output'
        $beforeCatalog = Get-Content -LiteralPath $fixture.CatalogPath -Raw

        $result = Invoke-ExtensionScript -Fixture $fixture -Name 'export-extensions.ps1' -Arguments @('-OutputDir', $output, '-Force', '-Json')

        $result.ExitCode | Should -Not -Be 0
        $result.Raw | Should -Match 'overlaps a protected authority path'
        (Test-Path -LiteralPath (Join-Path $fixture.ExtensionRoot 'generated-output')) | Should -BeFalse
        (Get-Content -LiteralPath $fixture.CatalogPath -Raw) | Should -BeExactly $beforeCatalog
    }

    It 'preserves an existing mirror when a staged export encounters a collision' {
        $fixture = New-ExtensionFixture
        $source = New-TestExtensionSource -Fixture $fixture -EntryPoints @{ scripts = @('scripts/common.ps1') }
        Set-Content -LiteralPath (Join-Path $source 'scripts/common.ps1') -Value "'collision'" -Encoding utf8NoBOM
        (Invoke-ExtensionScript -Fixture $fixture -Name 'add-extension.ps1' -Arguments @('-SourceDir', $source, '-Json')).ExitCode | Should -Be 0
        Approve-TestExtension -Fixture $fixture -Id 'fixture-extension'
        (Invoke-ExtensionScript -Fixture $fixture -Name 'set-extension-state.ps1' -Arguments @('-Id', 'fixture-extension', '-State', 'enabled', '-Json')).ExitCode | Should -Be 0
        New-Item -ItemType Directory -Path $fixture.MirrorRoot -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $fixture.MirrorRoot 'sentinel.txt') -Value 'last-known-good' -Encoding utf8NoBOM

        $result = Invoke-ExtensionScript -Fixture $fixture -Name 'export-extensions.ps1' -Arguments @('-Force', '-Json')

        $result.ExitCode | Should -Not -Be 0
        $result.Raw | Should -Match 'Collision detected'
        (Get-Content -LiteralPath (Join-Path $fixture.MirrorRoot 'sentinel.txt') -Raw).Trim() | Should -Be 'last-known-good'
        @(Get-ChildItem -LiteralPath (Split-Path -Parent $fixture.MirrorRoot) -Directory -Filter '.*.staging-*').Count | Should -Be 0
    }

    It 'keeps obsolete backup cleanup outside the export promotion rollback region' {
        $content = Get-Content -LiteralPath (Join-Path $WorkspaceRoot 'studio/scripts/powershell/export-extensions.ps1') -Raw
        $rollbackThrow = $content.IndexOf('throw "Extension export failed:')
        $cleanupGuard = $content.IndexOf('if ($outputBackedUp -and (Test-Path -LiteralPath $backupDir))', $rollbackThrow)
        $cleanupRemoval = $content.IndexOf('Remove-Item -LiteralPath $backupDir -Recurse -Force -ErrorAction Stop', $cleanupGuard)
        $resultConstruction = $content.IndexOf('$result = [ordered]@{', $cleanupRemoval)

        $rollbackThrow | Should -BeGreaterThan -1
        $cleanupGuard | Should -BeGreaterThan $rollbackThrow
        $cleanupRemoval | Should -BeGreaterThan $cleanupGuard
        $resultConstruction | Should -BeGreaterThan $cleanupRemoval
        $content | Should -Match 'CLEANUP_WARNING\s*=\s*\$cleanupWarning'
    }

    It 'exercises add approve enable export disable re-enable export and remove lifecycle' {
        $fixture = New-ExtensionFixture
        $source = New-TestExtensionSource -Fixture $fixture

        (Invoke-ExtensionScript -Fixture $fixture -Name 'add-extension.ps1' -Arguments @('-SourceDir', $source, '-Json')).ExitCode | Should -Be 0
        Approve-TestExtension -Fixture $fixture -Id 'fixture-extension'
        (Invoke-ExtensionScript -Fixture $fixture -Name 'set-extension-state.ps1' -Arguments @('-Id', 'fixture-extension', '-State', 'enabled', '-Json')).ExitCode | Should -Be 0
        (Invoke-ExtensionScript -Fixture $fixture -Name 'export-extensions.ps1' -Arguments @('-Force', '-Json')).ExitCode | Should -Be 0
        (Test-Path -LiteralPath (Join-Path $fixture.MirrorRoot 'scripts/invoke.ps1')) | Should -BeTrue

        (Invoke-ExtensionScript -Fixture $fixture -Name 'set-extension-state.ps1' -Arguments @('-Id', 'fixture-extension', '-State', 'disabled', '-Json')).ExitCode | Should -Be 0
        (Test-Path -LiteralPath $fixture.MirrorRoot) | Should -BeFalse

        (Invoke-ExtensionScript -Fixture $fixture -Name 'set-extension-state.ps1' -Arguments @('-Id', 'fixture-extension', '-State', 'enabled', '-Json')).ExitCode | Should -Be 0
        (Invoke-ExtensionScript -Fixture $fixture -Name 'export-extensions.ps1' -Arguments @('-Force', '-Json')).ExitCode | Should -Be 0
        (Invoke-ExtensionScript -Fixture $fixture -Name 'remove-extension.ps1' -Arguments @('-Id', 'fixture-extension', '-Json')).ExitCode | Should -Be 0

        (Test-Path -LiteralPath $fixture.MirrorRoot) | Should -BeFalse
        (Test-Path -LiteralPath (Join-Path $fixture.ExtensionRoot 'fixture-extension')) | Should -BeFalse
        $catalog = Get-Content -LiteralPath $fixture.CatalogPath -Raw | ConvertFrom-Json -AsHashtable
        @($catalog.extensions | Where-Object id -eq 'fixture-extension').Count | Should -Be 0
        $state = Get-Content -LiteralPath $fixture.StatePath -Raw | ConvertFrom-Json -AsHashtable
        $state.states.ContainsKey('fixture-extension') | Should -BeFalse
        $validation = Invoke-ExtensionScript -Fixture $fixture -Name 'validate-extension-registry.ps1' -Arguments @('-Json')
        ($validation.Raw | ConvertFrom-Json).VALID | Should -BeTrue
    }

    It 'accepts valid in-workspace intake and an isolated export as compatibility controls' {
        $fixture = New-ExtensionFixture
        $source = New-TestExtensionSource -Fixture $fixture -Id 'control-extension'
        $output = Join-Path $fixture.Root 'resources/studio-runtime/control-export'

        $add = Invoke-ExtensionScript -Fixture $fixture -Name 'add-extension.ps1' -Arguments @('-SourceDir', $source, '-Json')
        $validate = Invoke-ExtensionScript -Fixture $fixture -Name 'validate-extension-registry.ps1' -Arguments @('-Json')
        $export = Invoke-ExtensionScript -Fixture $fixture -Name 'export-extensions.ps1' -Arguments @('-OutputDir', $output, '-Force', '-Json')

        $add.ExitCode | Should -Be 0
        ($validate.Raw | ConvertFrom-Json).VALID | Should -BeTrue
        $export.ExitCode | Should -Be 0
        (Test-Path -LiteralPath (Join-Path $fixture.ExtensionRoot 'control-extension/manifest.json')) | Should -BeTrue
        (Test-Path -LiteralPath (Join-Path $output 'manifest.json')) | Should -BeTrue
    }

    It 'anchors normalized source and target scope checks in the production exporter' {
        $content = Get-Content -LiteralPath (Join-Path $WorkspaceRoot 'studio/scripts/powershell/export-extensions.ps1') -Raw
        $content | Should -Match 'Resolve-ExtensionEntryPoint'
        $content | Should -Match 'Extension export target escapes declared scope'
        $content | Should -Match 'Extension export target escapes final declared scope'
        $content | Should -Match 'Assert-ExtensionOutputInsideWorkspace'
    }
}
