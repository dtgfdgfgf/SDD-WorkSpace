#!/usr/bin/env pwsh
#Requires -Module Pester

# Discriminating R-B20/R-B25/R-B26 coverage: authorization tampering must be
# denied by the same shared decision used by the runner, listing, and state setter.

BeforeAll {
    . "$PSScriptRoot/governance.config.ps1"

    $script:runWorkflow = Join-Path $WorkspaceRoot 'studio/scripts/powershell/run-workflow.ps1'
    $script:listWorkflows = Join-Path $WorkspaceRoot 'studio/scripts/powershell/list-workflows.ps1'
    $script:setWorkflowState = Join-Path $WorkspaceRoot 'studio/scripts/powershell/set-workflow-state.ps1'
    $script:workflowSchemas = Join-Path $WorkspaceRoot 'studio/workflows'

    function script:Write-FixtureJson {
        param(
            [Parameter(Mandatory)] [string]$Path,
            [Parameter(Mandatory)] $Data
        )

        $Data | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $Path -Encoding utf8
    }

    function script:New-RunnerAuthorizationFixture {
        $id = 'runner-auth-test'
        $projectRoot = Join-Path $TestDrive ("runner-auth-project-{0}" -f ([guid]::NewGuid().ToString('N')))
        $feature = '999-runner-auth'
        New-Item -ItemType Directory -Path (Join-Path $projectRoot '.specify/memory') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $projectRoot "specs/$feature") -Force | Out-Null
        '# fixture' | Set-Content -LiteralPath (Join-Path $projectRoot '.specify/memory/constitution.md')
        '# fixture spec' | Set-Content -LiteralPath (Join-Path $projectRoot "specs/$feature/spec.md")

        $studioRoot = Join-Path $TestDrive ("runner-auth-studio-{0}" -f ([guid]::NewGuid().ToString('N')))
        $workflowsRoot = Join-Path $studioRoot 'workflows'
        $workflowRoot = Join-Path $workflowsRoot $id
        New-Item -ItemType Directory -Path $workflowRoot -Force | Out-Null

        foreach ($schemaName in @('catalog.schema.json', 'state.schema.json')) {
            Copy-Item `
                -LiteralPath (Join-Path $script:workflowSchemas $schemaName) `
                -Destination (Join-Path $workflowsRoot $schemaName) `
                -Force
        }

        $workflowPath = Join-Path $workflowRoot 'workflow.yml'
        @"
schema_version: "1.0.0"
workflow:
  id: $id
  name: Runner Authorization Test
  version: "1.0.0"
  integration: studio-first
steps:
  - id: review
    type: gate
    prompt: "Approve?"
"@ | Set-Content -LiteralPath $workflowPath -NoNewline
        $workflowSha256 = (Get-FileHash -LiteralPath $workflowPath -Algorithm SHA256).Hash.ToLowerInvariant()

        Write-FixtureJson -Path (Join-Path $workflowRoot 'manifest.json') -Data ([ordered]@{
            id = $id
            version = '1.0.0'
            title = 'Runner Authorization Test'
            kind = 'workflow'
            status = 'active'
            owner = 'studio'
            compatibility = [ordered]@{
                mode = 'studio-first'
            }
        })

        $policy = [ordered]@{
            mode = 'studio-first'
            curatedOnly = $true
            autoEnableNewWorkflows = $false
            reviewStatuses = @('draft', 'approved', 'experimental', 'deprecated', 'rejected')
            trustLevels = @('core', 'curated', 'experimental')
            stateSources = @('default', 'manual')
        }
        $catalogEntry = [ordered]@{
            id = $id
            version = '1.0.0'
            title = 'Runner Authorization Test'
            sourcePath = "workflows/$id"
            reviewStatus = 'approved'
            trustLevel = 'curated'
            defaultEnabled = $true
            owner = 'studio'
            approvedBy = 'governance-test'
            approvedAt = '2026-07-15T00:00:00+08:00'
            workflowSha256 = $workflowSha256
            stepTypesUsed = @('gate')
            notes = 'R-B20 isolated authorization fixture.'
        }
        Write-FixtureJson -Path (Join-Path $workflowsRoot 'catalog.json') -Data ([ordered]@{
            version = '1.0.0'
            updated = '2026-07-15T00:00:00+08:00'
            policy = $policy
            workflows = @($catalogEntry)
        })
        Write-FixtureJson -Path (Join-Path $workflowsRoot 'state.json') -Data ([ordered]@{
            version = '1.0.0'
            updated = '2026-07-15T00:00:00+08:00'
            states = [ordered]@{}
        })

        return [PSCustomObject]@{
            Id = $id
            Feature = $feature
            ProjectRoot = $projectRoot
            StudioRoot = $studioRoot
            WorkflowsRoot = $workflowsRoot
            WorkflowRoot = $workflowRoot
            WorkflowPath = $workflowPath
            ManifestPath = Join-Path $workflowRoot 'manifest.json'
            CatalogPath = Join-Path $workflowsRoot 'catalog.json'
            StatePath = Join-Path $workflowsRoot 'state.json'
        }
    }

    function script:Set-RunnerAuthorizationTamper {
        param(
            [Parameter(Mandatory)] $Fixture,
            [Parameter(Mandatory)] [string]$Kind
        )

        $catalog = Get-Content -LiteralPath $Fixture.CatalogPath -Raw | ConvertFrom-Json -AsHashtable
        $state = Get-Content -LiteralPath $Fixture.StatePath -Raw | ConvertFrom-Json -AsHashtable
        $stateEntry = [ordered]@{
            enabled = $true
            pinnedVersion = '1.0.0'
            changedAt = '2026-07-15T00:00:00+08:00'
            source = 'manual'
        }

        switch ($Kind) {
            'catalog-string-boolean' {
                $catalog.workflows[0].defaultEnabled = 'false'
                Write-FixtureJson -Path $Fixture.CatalogPath -Data $catalog
            }
            'state-string-boolean' {
                $catalog.workflows[0].defaultEnabled = $false
                $stateEntry.enabled = 'false'
                $state.states[$Fixture.Id] = $stateEntry
                Write-FixtureJson -Path $Fixture.CatalogPath -Data $catalog
                Write-FixtureJson -Path $Fixture.StatePath -Data $state
            }
            'state-number-boolean' {
                $catalog.workflows[0].defaultEnabled = $false
                $stateEntry.enabled = 1
                $state.states[$Fixture.Id] = $stateEntry
                Write-FixtureJson -Path $Fixture.CatalogPath -Data $catalog
                Write-FixtureJson -Path $Fixture.StatePath -Data $state
            }
            'catalog-null-boolean' {
                $catalog.workflows[0].defaultEnabled = $null
                $state.states[$Fixture.Id] = $stateEntry
                Write-FixtureJson -Path $Fixture.CatalogPath -Data $catalog
                Write-FixtureJson -Path $Fixture.StatePath -Data $state
            }
            'catalog-missing-workflow-digest' {
                [void]$catalog.workflows[0].Remove('workflowSha256')
                Write-FixtureJson -Path $Fixture.CatalogPath -Data $catalog
            }
            'catalog-null-workflow-digest' {
                $catalog.workflows[0].workflowSha256 = $null
                Write-FixtureJson -Path $Fixture.CatalogPath -Data $catalog
            }
            'catalog-number-workflow-digest' {
                $catalog.workflows[0].workflowSha256 = 42
                Write-FixtureJson -Path $Fixture.CatalogPath -Data $catalog
            }
            'catalog-malformed-workflow-digest' {
                $catalog.workflows[0].workflowSha256 = 'not-a-sha256'
                Write-FixtureJson -Path $Fixture.CatalogPath -Data $catalog
            }
            'catalog-uppercase-workflow-digest' {
                $catalog.workflows[0].workflowSha256 = ([string]$catalog.workflows[0].workflowSha256).ToUpperInvariant()
                Write-FixtureJson -Path $Fixture.CatalogPath -Data $catalog
            }
            'workflow-content-mismatch' {
                (Get-Content -LiteralPath $Fixture.WorkflowPath -Raw).Replace(
                    'prompt: "Approve?"',
                    'prompt: "Mutated after approval?"'
                ) | Set-Content -LiteralPath $Fixture.WorkflowPath -NoNewline
            }
            'source-path-inside-alias' {
                $aliasName = 'catalog-selected-source'
                $aliasRoot = Join-Path $Fixture.WorkflowsRoot $aliasName
                Move-Item -LiteralPath $Fixture.WorkflowRoot -Destination $aliasRoot
                $catalog.workflows[0].sourcePath = "workflows/$aliasName"
                Write-FixtureJson -Path $Fixture.CatalogPath -Data $catalog
                $Fixture.WorkflowRoot = $aliasRoot
                $Fixture.WorkflowPath = Join-Path $aliasRoot 'workflow.yml'
                $Fixture.ManifestPath = Join-Path $aliasRoot 'manifest.json'
            }
            'source-path-inside-junction' {
                $aliasName = 'catalog-selected-inside-junction'
                $aliasRoot = Join-Path $Fixture.WorkflowsRoot $aliasName
                $linkType = if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }
                New-Item `
                    -ItemType $linkType `
                    -Path $aliasRoot `
                    -Target $Fixture.WorkflowRoot `
                    -ErrorAction Stop |
                    Out-Null
                $catalog.workflows[0].sourcePath = "workflows/$aliasName"
                Write-FixtureJson -Path $Fixture.CatalogPath -Data $catalog
            }
            'source-path-outside-root' {
                $outsideRoot = Join-Path $Fixture.StudioRoot 'outside-approved-graph'
                Copy-Item -LiteralPath $Fixture.WorkflowRoot -Destination $outsideRoot -Recurse
                $catalog.workflows[0].sourcePath = 'workflows/../outside-approved-graph'
                Write-FixtureJson -Path $Fixture.CatalogPath -Data $catalog
            }
            'source-path-junction-outside-root' {
                $outsideRoot = Join-Path $Fixture.StudioRoot 'outside-junction-parent'
                New-Item -ItemType Directory -Path $outsideRoot -Force | Out-Null
                $outsideGraph = Join-Path $outsideRoot 'approved-graph'
                Copy-Item -LiteralPath $Fixture.WorkflowRoot -Destination $outsideGraph -Recurse
                $aliasName = 'catalog-selected-outside-junction'
                $aliasRoot = Join-Path $Fixture.WorkflowsRoot $aliasName
                $linkType = if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }
                New-Item `
                    -ItemType $linkType `
                    -Path $aliasRoot `
                    -Target $outsideRoot `
                    -ErrorAction Stop |
                    Out-Null
                $catalog.workflows[0].sourcePath = "workflows/$aliasName/approved-graph"
                Write-FixtureJson -Path $Fixture.CatalogPath -Data $catalog
            }
            'manifest-version-mismatch' {
                $manifest = Get-Content -LiteralPath $Fixture.ManifestPath -Raw | ConvertFrom-Json -AsHashtable
                $manifest['version'] = '9.9.9'
                Write-FixtureJson -Path $Fixture.ManifestPath -Data $manifest
            }
            'manifest-id-mismatch' {
                $manifest = Get-Content -LiteralPath $Fixture.ManifestPath -Raw | ConvertFrom-Json -AsHashtable
                $manifest['id'] = 'other-workflow'
                Write-FixtureJson -Path $Fixture.ManifestPath -Data $manifest
            }
            'manifest-retired-compatibility-field' {
                $manifest = Get-Content -LiteralPath $Fixture.ManifestPath -Raw | ConvertFrom-Json -AsHashtable
                $manifest['compatibility']['minStudioConstitutionVersion'] = '1.10.0'
                Write-FixtureJson -Path $Fixture.ManifestPath -Data $manifest
            }
            'manifest-case-variant-retired-compatibility-field' {
                $manifest = Get-Content -LiteralPath $Fixture.ManifestPath -Raw | ConvertFrom-Json -AsHashtable
                $manifest['compatibility']['MinStudioConstitutionVersion'] = '1.10.0'
                Write-FixtureJson -Path $Fixture.ManifestPath -Data $manifest
            }
            'manifest-unknown-compatibility-field' {
                $manifest = Get-Content -LiteralPath $Fixture.ManifestPath -Raw | ConvertFrom-Json -AsHashtable
                $manifest['compatibility']['futureCompatibilityClaim'] = 'unenforced'
                Write-FixtureJson -Path $Fixture.ManifestPath -Data $manifest
            }
            'catalog-sync-source-policy' {
                $catalog.policy.stateSources = @('default', 'manual', 'sync')
                Write-FixtureJson -Path $Fixture.CatalogPath -Data $catalog
            }
            'state-sync-source' {
                $catalog.workflows[0].defaultEnabled = $false
                $stateEntry.source = 'sync'
                $state.states[$Fixture.Id] = $stateEntry
                Write-FixtureJson -Path $Fixture.CatalogPath -Data $catalog
                Write-FixtureJson -Path $Fixture.StatePath -Data $state
            }
            'state-null-source' {
                $catalog.workflows[0].defaultEnabled = $false
                $stateEntry.source = $null
                $state.states[$Fixture.Id] = $stateEntry
                Write-FixtureJson -Path $Fixture.CatalogPath -Data $catalog
                Write-FixtureJson -Path $Fixture.StatePath -Data $state
            }
            'state-number-source' {
                $catalog.workflows[0].defaultEnabled = $false
                $stateEntry.source = 42
                $state.states[$Fixture.Id] = $stateEntry
                Write-FixtureJson -Path $Fixture.CatalogPath -Data $catalog
                Write-FixtureJson -Path $Fixture.StatePath -Data $state
            }
            'deprecated-missing-state' {
                $catalog.workflows[0].reviewStatus = 'deprecated'
                $catalog.workflows[0].defaultEnabled = $false
                Write-FixtureJson -Path $Fixture.CatalogPath -Data $catalog
            }
            'deprecated-disabled-state' {
                $catalog.workflows[0].reviewStatus = 'deprecated'
                $catalog.workflows[0].defaultEnabled = $false
                $stateEntry.enabled = $false
                $state.states[$Fixture.Id] = $stateEntry
                Write-FixtureJson -Path $Fixture.CatalogPath -Data $catalog
                Write-FixtureJson -Path $Fixture.StatePath -Data $state
            }
            'deprecated-null-pin-state' {
                $catalog.workflows[0].reviewStatus = 'deprecated'
                $catalog.workflows[0].defaultEnabled = $false
                $stateEntry.pinnedVersion = $null
                $state.states[$Fixture.Id] = $stateEntry
                Write-FixtureJson -Path $Fixture.CatalogPath -Data $catalog
                Write-FixtureJson -Path $Fixture.StatePath -Data $state
            }
            'deprecated-stale-pin-state' {
                $catalog.workflows[0].reviewStatus = 'deprecated'
                $catalog.workflows[0].defaultEnabled = $false
                $stateEntry.pinnedVersion = '9.9.9'
                $state.states[$Fixture.Id] = $stateEntry
                Write-FixtureJson -Path $Fixture.CatalogPath -Data $catalog
                Write-FixtureJson -Path $Fixture.StatePath -Data $state
            }
            'deprecated-string-enabled-state' {
                $catalog.workflows[0].reviewStatus = 'deprecated'
                $catalog.workflows[0].defaultEnabled = $false
                $stateEntry.enabled = 'true'
                $state.states[$Fixture.Id] = $stateEntry
                Write-FixtureJson -Path $Fixture.CatalogPath -Data $catalog
                Write-FixtureJson -Path $Fixture.StatePath -Data $state
            }
            'deprecated-enabled-same-pin' {
                $catalog.workflows[0].reviewStatus = 'deprecated'
                $catalog.workflows[0].defaultEnabled = $false
                $state.states[$Fixture.Id] = $stateEntry
                Write-FixtureJson -Path $Fixture.CatalogPath -Data $catalog
                Write-FixtureJson -Path $Fixture.StatePath -Data $state
            }
            'missing-manifest' {
                Remove-Item -LiteralPath $Fixture.ManifestPath -Force
            }
            'malformed-manifest' {
                [System.IO.File]::WriteAllText(
                    $Fixture.ManifestPath,
                    "{not-json`n",
                    [System.Text.UTF8Encoding]::new($false)
                )
            }
            'null-manifest' {
                [System.IO.File]::WriteAllText(
                    $Fixture.ManifestPath,
                    "null`n",
                    [System.Text.UTF8Encoding]::new($false)
                )
            }
            'scalar-manifest' {
                [System.IO.File]::WriteAllText(
                    $Fixture.ManifestPath,
                    "42`n",
                    [System.Text.UTF8Encoding]::new($false)
                )
            }
            'missing-state' {
                Remove-Item -LiteralPath $Fixture.StatePath -Force
            }
            'states-array' {
                $state.states = @()
                Write-FixtureJson -Path $Fixture.StatePath -Data $state
            }
            'states-null' {
                $state.states = $null
                Write-FixtureJson -Path $Fixture.StatePath -Data $state
            }
            'state-root-null' {
                [System.IO.File]::WriteAllText($Fixture.StatePath, "null`n", [System.Text.UTF8Encoding]::new($false))
            }
            'state-root-scalar' {
                [System.IO.File]::WriteAllText($Fixture.StatePath, "42`n", [System.Text.UTF8Encoding]::new($false))
            }
            'missing-catalog-schema' {
                Remove-Item -LiteralPath (Join-Path $Fixture.WorkflowsRoot 'catalog.schema.json') -Force
            }
            'missing-state-schema' {
                Remove-Item -LiteralPath (Join-Path $Fixture.WorkflowsRoot 'state.schema.json') -Force
            }
            'permissive-catalog-schema' {
                [System.IO.File]::WriteAllText(
                    (Join-Path $Fixture.WorkflowsRoot 'catalog.schema.json'),
                    "true`n",
                    [System.Text.UTF8Encoding]::new($false)
                )
            }
            'shaped-permissive-catalog-schema' {
                $catalog.workflows[0]['unexpectedAuthorizationField'] = 'bypass'
                Write-FixtureJson -Path $Fixture.CatalogPath -Data $catalog
                Write-FixtureJson `
                    -Path (Join-Path $Fixture.WorkflowsRoot 'catalog.schema.json') `
                    -Data ([ordered]@{
                        '$schema' = 'https://json-schema.org/draft/2020-12/schema'
                        '$id' = 'https://workspace.local/studio/workflows/catalog.schema.json'
                        type = 'object'
                        additionalProperties = $false
                        required = @('version', 'updated', 'policy', 'workflows')
                        properties = [ordered]@{
                            version = [ordered]@{ type = 'string' }
                            updated = [ordered]@{ type = 'string' }
                            policy = [ordered]@{ type = 'object' }
                            workflows = [ordered]@{ type = 'array'; items = [ordered]@{} }
                        }
                    })
            }
            'shaped-permissive-state-schema' {
                $catalog.workflows[0].defaultEnabled = $false
                $stateEntry['unexpectedAuthorizationField'] = 'bypass'
                $state.states[$Fixture.Id] = $stateEntry
                Write-FixtureJson -Path $Fixture.CatalogPath -Data $catalog
                Write-FixtureJson -Path $Fixture.StatePath -Data $state
                Write-FixtureJson `
                    -Path (Join-Path $Fixture.WorkflowsRoot 'state.schema.json') `
                    -Data ([ordered]@{
                        '$schema' = 'https://json-schema.org/draft/2020-12/schema'
                        '$id' = 'https://workspace.local/studio/workflows/state.schema.json'
                        type = 'object'
                        additionalProperties = $false
                        required = @('version', 'updated', 'states')
                        properties = [ordered]@{
                            version = [ordered]@{ type = 'string' }
                            updated = [ordered]@{ type = 'string' }
                            states = [ordered]@{
                                type = 'object'
                                additionalProperties = [ordered]@{ type = 'object' }
                            }
                        }
                    })
            }
            default { throw "Unknown authorization tamper: $Kind" }
        }
    }

    function script:Invoke-FixtureRunner {
        param([Parameter(Mandatory)] $Fixture)

        $output = & pwsh -NoProfile -Command '& { param($scriptPath, $studioRoot, $projectRoot, $id, $feature) $env:SDD_STUDIO_ROOT = $studioRoot; $env:SDD_PROJECT_ROOT = $projectRoot; & $scriptPath -Id $id -Feature $feature -Json; exit $LASTEXITCODE }' `
            $script:runWorkflow $Fixture.StudioRoot $Fixture.ProjectRoot $Fixture.Id $Fixture.Feature 2>&1
        $exitCode = $LASTEXITCODE
        $raw = $output -join [Environment]::NewLine
        return [PSCustomObject]@{
            ExitCode = $exitCode
            Result = $raw | ConvertFrom-Json
            Raw = $raw
        }
    }

    function script:Invoke-FixtureListing {
        param([Parameter(Mandatory)] $Fixture)

        $output = & pwsh -NoProfile -Command '& { param($scriptPath, $studioRoot, $id) $env:SDD_STUDIO_ROOT = $studioRoot; & $scriptPath -Id $id -Json; exit $LASTEXITCODE }' `
            $script:listWorkflows $Fixture.StudioRoot $Fixture.Id 2>&1
        $exitCode = $LASTEXITCODE
        $raw = $output -join [Environment]::NewLine
        return [PSCustomObject]@{
            ExitCode = $exitCode
            Result = $raw | ConvertFrom-Json
            Raw = $raw
        }
    }

    function script:Invoke-FixtureStateSetter {
        param([Parameter(Mandatory)] $Fixture)

        $output = & pwsh -NoProfile -Command '& { param($scriptPath, $studioRoot, $id) $env:SDD_STUDIO_ROOT = $studioRoot; & $scriptPath -Id $id -State enabled -Json; exit $LASTEXITCODE }' `
            $script:setWorkflowState $Fixture.StudioRoot $Fixture.Id 2>&1
        $exitCode = $LASTEXITCODE
        $raw = $output -join [Environment]::NewLine
        $result = $null
        if ($exitCode -eq 0) {
            $result = $raw | ConvertFrom-Json
        }
        return [PSCustomObject]@{
            ExitCode = $exitCode
            Result = $result
            Raw = $raw
        }
    }
}

Describe 'run-workflow: shared fail-closed registry authorization (R-B20)' {
    It 'uses the same valid authorization result as list-workflows' {
        $fixture = New-RunnerAuthorizationFixture

        $listing = Invoke-FixtureListing -Fixture $fixture
        $listing.ExitCode | Should -Be 0
        $listing.Result.VALID | Should -BeTrue
        $listing.Result.WORKFLOWS[0].executionAuthorized | Should -BeTrue
        $listing.Result.WORKFLOWS[0].workflowSha256 | Should -BeExactly $listing.Result.WORKFLOWS[0].actualWorkflowSha256
        $listing.Result.WORKFLOWS[0].workflowDigestMatches | Should -BeTrue

        $runner = Invoke-FixtureRunner -Fixture $fixture
        $runner.ExitCode | Should -Be 43
        $runner.Result.STATUS | Should -Be 'awaiting_gate'
    }

    It 'denies manifest version mismatch in both listing and runner instead of the old listing false-authorization' {
        $fixture = New-RunnerAuthorizationFixture
        Set-RunnerAuthorizationTamper -Fixture $fixture -Kind 'manifest-version-mismatch'

        $listing = Invoke-FixtureListing -Fixture $fixture
        $listing.ExitCode | Should -Be 1
        $listing.Result.VALID | Should -BeFalse
        $listing.Result.WORKFLOWS[0].executionAuthorized | Should -BeFalse
        ($listing.Result.ERRORS -join "`n") | Should -Match 'Workflow identity mismatch'

        $runner = Invoke-FixtureRunner -Fixture $fixture
        $runner.ExitCode | Should -Be 1
        $runner.Result.STATUS | Should -Be 'denied'
        $runner.Result.ERROR | Should -Match 'registry authorization denied.*Workflow identity mismatch'
    }

    It 'runs the exact authorized sourcePath graph when its directory differs from the workflow id' {
        $fixture = New-RunnerAuthorizationFixture
        Set-RunnerAuthorizationTamper -Fixture $fixture -Kind 'source-path-inside-alias'

        $listing = Invoke-FixtureListing -Fixture $fixture
        $listing.ExitCode | Should -Be 0
        $listing.Result.VALID | Should -BeTrue
        $listing.Result.WORKFLOWS[0].executionAuthorized | Should -BeTrue
        $listing.Result.WORKFLOWS[0].sourcePath | Should -BeExactly 'workflows/catalog-selected-source'
        $listing.Result.WORKFLOWS[0].workflowPath | Should -BeExactly $fixture.WorkflowPath

        $runner = Invoke-FixtureRunner -Fixture $fixture
        $runner.ExitCode | Should -Be 43
        $runner.Result.STATUS | Should -Be 'awaiting_gate'
    }

    It 'allows a catalog junction alias only when its physical target remains inside workflows root' {
        $fixture = New-RunnerAuthorizationFixture
        Set-RunnerAuthorizationTamper -Fixture $fixture -Kind 'source-path-inside-junction'

        $listing = Invoke-FixtureListing -Fixture $fixture
        $listing.ExitCode | Should -Be 0
        $listing.Result.VALID | Should -BeTrue
        $listing.Result.WORKFLOWS[0].executionAuthorized | Should -BeTrue
        $listing.Result.WORKFLOWS[0].sourcePath | Should -BeExactly 'workflows/catalog-selected-inside-junction'
        $listing.Result.WORKFLOWS[0].workflowPath | Should -BeExactly $fixture.WorkflowPath

        $runner = Invoke-FixtureRunner -Fixture $fixture
        $runner.ExitCode | Should -Be 43
        $runner.Result.STATUS | Should -Be 'awaiting_gate'
    }

    It 'denies <Name> in both runner and listing' -ForEach @(
        @{ Name = 'catalog defaultEnabled string false'; Kind = 'catalog-string-boolean' }
        @{ Name = 'state enabled string false'; Kind = 'state-string-boolean' }
        @{ Name = 'state enabled numeric wrong type'; Kind = 'state-number-boolean' }
        @{ Name = 'catalog defaultEnabled null'; Kind = 'catalog-null-boolean' }
        @{ Name = 'approved catalog missing workflow digest'; Kind = 'catalog-missing-workflow-digest' }
        @{ Name = 'approved catalog null workflow digest'; Kind = 'catalog-null-workflow-digest' }
        @{ Name = 'approved catalog numeric workflow digest'; Kind = 'catalog-number-workflow-digest' }
        @{ Name = 'approved catalog malformed workflow digest'; Kind = 'catalog-malformed-workflow-digest' }
        @{ Name = 'approved catalog uppercase workflow digest'; Kind = 'catalog-uppercase-workflow-digest' }
        @{ Name = 'same-id/version workflow content mismatch'; Kind = 'workflow-content-mismatch'; ErrorPattern = 'approval digest mismatch' }
        @{ Name = 'catalog sourcePath outside workflows root'; Kind = 'source-path-outside-root'; ErrorPattern = 'escapes workflows root' }
        @{ Name = 'catalog sourcePath junction target outside workflows root'; Kind = 'source-path-junction-outside-root'; ErrorPattern = 'reparse point outside workflows root.*outside physical root' }
        @{ Name = 'manifest id mismatch'; Kind = 'manifest-id-mismatch'; ErrorPattern = 'Workflow identity mismatch' }
        @{ Name = 'retired workflow compatibility field reintroduction'; Kind = 'manifest-retired-compatibility-field'; ErrorPattern = 'retired compatibility field' }
        @{ Name = 'case-variant retired workflow compatibility field reintroduction'; Kind = 'manifest-case-variant-retired-compatibility-field'; ErrorPattern = 'retired compatibility field' }
        @{ Name = 'unknown workflow compatibility field'; Kind = 'manifest-unknown-compatibility-field'; ErrorPattern = 'unsupported compatibility field' }
        @{ Name = 'catalog policy reintroduces sync provenance'; Kind = 'catalog-sync-source-policy' }
        @{ Name = 'state uses sync provenance'; Kind = 'state-sync-source' }
        @{ Name = 'state uses null provenance'; Kind = 'state-null-source' }
        @{ Name = 'state uses wrong-type provenance'; Kind = 'state-number-source' }
        @{ Name = 'missing manifest'; Kind = 'missing-manifest'; ErrorPattern = 'manifest missing' }
        @{ Name = 'malformed manifest JSON'; Kind = 'malformed-manifest'; ErrorPattern = 'Invalid workflow manifest JSON' }
        @{ Name = 'manifest JSON null'; Kind = 'null-manifest'; ErrorPattern = 'must be a JSON object' }
        @{ Name = 'manifest JSON scalar wrong shape'; Kind = 'scalar-manifest'; ErrorPattern = 'must be a JSON object' }
        @{ Name = 'missing state.json'; Kind = 'missing-state' }
        @{ Name = 'states array wrong type'; Kind = 'states-array' }
        @{ Name = 'states null'; Kind = 'states-null' }
        @{ Name = 'state root null'; Kind = 'state-root-null' }
        @{ Name = 'state root scalar'; Kind = 'state-root-scalar' }
        @{ Name = 'missing catalog schema'; Kind = 'missing-catalog-schema' }
        @{ Name = 'missing state schema'; Kind = 'missing-state-schema' }
        @{ Name = 'permissive catalog schema'; Kind = 'permissive-catalog-schema' }
        @{ Name = 'shaped permissive catalog schema'; Kind = 'shaped-permissive-catalog-schema'; ErrorPattern = 'schema identity mismatch' }
        @{ Name = 'shaped permissive state schema'; Kind = 'shaped-permissive-state-schema'; ErrorPattern = 'schema identity mismatch' }
    ) {
        $fixture = New-RunnerAuthorizationFixture
        Set-RunnerAuthorizationTamper -Fixture $fixture -Kind $Kind

        $runner = Invoke-FixtureRunner -Fixture $fixture
        $runner.ExitCode | Should -Be 1
        $runner.Result.STATUS | Should -Be 'denied'
        $runner.Result.ERROR | Should -Match 'registry authorization denied'

        $listing = Invoke-FixtureListing -Fixture $fixture
        $listing.ExitCode | Should -Be 1
        $listing.Result.VALID | Should -BeFalse
        $listing.Result.ERROR_COUNT | Should -BeGreaterThan 0
        if ($ErrorPattern) {
            $runner.Result.ERROR | Should -Match $ErrorPattern
            ($listing.Result.ERRORS -join "`n") | Should -Match $ErrorPattern
        }
    }
}

Describe 'workflow deprecated lifecycle and provenance hardening (R-B25/R-B26)' {
    It 'denies a deprecated enable request with <Name> state in the mutator' -ForEach @(
        @{ Name = 'missing'; Kind = 'deprecated-missing-state' }
        @{ Name = 'disabled'; Kind = 'deprecated-disabled-state' }
        @{ Name = 'null pin'; Kind = 'deprecated-null-pin-state' }
        @{ Name = 'stale pin'; Kind = 'deprecated-stale-pin-state' }
        @{ Name = 'wrong-type enabled'; Kind = 'deprecated-string-enabled-state' }
        @{ Name = 'sync provenance'; Kind = 'state-sync-source' }
        @{ Name = 'null provenance'; Kind = 'state-null-source' }
        @{ Name = 'wrong-type provenance'; Kind = 'state-number-source' }
    ) {
        $fixture = New-RunnerAuthorizationFixture
        Set-RunnerAuthorizationTamper -Fixture $fixture -Kind $Kind

        if ($Kind -like 'state-*') {
            $catalog = Get-Content -LiteralPath $fixture.CatalogPath -Raw | ConvertFrom-Json -AsHashtable
            $catalog.workflows[0].reviewStatus = 'deprecated'
            Write-FixtureJson -Path $fixture.CatalogPath -Data $catalog
        }

        $setter = Invoke-FixtureStateSetter -Fixture $fixture
        $setter.ExitCode | Should -Be 1
        $setter.Raw | Should -Match 'invalid|Deprecated workflow cannot be newly enabled'
    }

    It 'keeps missing or disabled deprecated state valid for listing but execution-denied' -ForEach @(
        @{ Kind = 'deprecated-missing-state'; ErrorPattern = 'no existing state entry' }
        @{ Kind = 'deprecated-disabled-state'; ErrorPattern = 'enabled=true' }
    ) {
        $fixture = New-RunnerAuthorizationFixture
        Set-RunnerAuthorizationTamper -Fixture $fixture -Kind $Kind

        $listing = Invoke-FixtureListing -Fixture $fixture
        $listing.ExitCode | Should -Be 0
        $listing.Result.VALID | Should -BeTrue
        $listing.Result.WORKFLOWS[0].executionAuthorized | Should -BeFalse
        ($listing.Result.WORKFLOWS[0].authorizationErrors -join "`n") | Should -Match $ErrorPattern

        $runner = Invoke-FixtureRunner -Fixture $fixture
        $runner.ExitCode | Should -Be 1
        $runner.Result.STATUS | Should -Be 'denied'
        $runner.Result.ERROR | Should -Match $ErrorPattern
    }

    It 'denies an enabled deprecated workflow with a null or stale pin in listing and runner' -ForEach @(
        @{ Kind = 'deprecated-null-pin-state'; ErrorPattern = 'pinnedVersion' }
        @{ Kind = 'deprecated-stale-pin-state'; ErrorPattern = 'pinnedVersion' }
    ) {
        $fixture = New-RunnerAuthorizationFixture
        Set-RunnerAuthorizationTamper -Fixture $fixture -Kind $Kind

        $listing = Invoke-FixtureListing -Fixture $fixture
        $listing.ExitCode | Should -Be 1
        $listing.Result.VALID | Should -BeFalse
        $listing.Result.WORKFLOWS[0].executionAuthorized | Should -BeFalse
        ($listing.Result.ERRORS -join "`n") | Should -Match $ErrorPattern

        $runner = Invoke-FixtureRunner -Fixture $fixture
        $runner.ExitCode | Should -Be 1
        $runner.Result.STATUS | Should -Be 'denied'
        $runner.Result.ERROR | Should -Match $ErrorPattern
    }

    It 'permits only an already-enabled same-pin deprecated no-op and preserves state bytes' {
        $fixture = New-RunnerAuthorizationFixture
        Set-RunnerAuthorizationTamper -Fixture $fixture -Kind 'deprecated-enabled-same-pin'
        $before = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($fixture.StatePath))

        $listing = Invoke-FixtureListing -Fixture $fixture
        $listing.ExitCode | Should -Be 0
        $listing.Result.VALID | Should -BeTrue
        $listing.Result.WORKFLOWS[0].executionAuthorized | Should -BeTrue

        $runner = Invoke-FixtureRunner -Fixture $fixture
        $runner.ExitCode | Should -Be 43
        $runner.Result.STATUS | Should -Be 'awaiting_gate'

        $setter = Invoke-FixtureStateSetter -Fixture $fixture
        $setter.ExitCode | Should -Be 0
        $setter.Result.CHANGED | Should -BeFalse
        $setter.Result.NO_OP | Should -BeTrue
        $after = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($fixture.StatePath))
        $after | Should -BeExactly $before
    }
}

Describe 'shared workflow authorization leaf reparse boundary (R-B20)' {
    BeforeAll {
        . (Join-Path $WorkspaceRoot 'studio/scripts/powershell/common.ps1')
    }

    It 'physically resolves workflow.yml and manifest.json before either leaf is trusted' {
        $commonContent = Get-Content `
            -LiteralPath (Join-Path $WorkspaceRoot 'studio/scripts/powershell/common.ps1') `
            -Raw

        $commonContent | Should -Match '(?s)\$workflowPath\s*=\s*Resolve-ExistingPathInsideRoot.*?-Candidate\s+\$workflowPath'
        $commonContent | Should -Match '(?s)\$manifestPath\s*=\s*Resolve-ExistingPathInsideRoot.*?-Candidate\s+\$manifestPath'
    }

    It 'denies a workflow leaf whose simulated reparse target is outside workflows root' {
        # Windows file-symlink creation requires a privilege unavailable in the
        # governance test environment. Mock only Get-Item at the leaf boundary;
        # the resolver still traverses the real root and outside target paths.
        $root = Join-Path $TestDrive 'leaf-reparse-root'
        $outsideRoot = Join-Path $TestDrive 'leaf-reparse-outside'
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        New-Item -ItemType Directory -Path $outsideRoot -Force | Out-Null
        $leafPath = Join-Path $root 'workflow.yml'
        $outsideLeafPath = Join-Path $outsideRoot 'workflow.yml'
        'inside-placeholder' | Set-Content -LiteralPath $leafPath -NoNewline
        'outside-target' | Set-Content -LiteralPath $outsideLeafPath -NoNewline

        $fakeLeaf = [PSCustomObject]@{
            Attributes = [System.IO.FileAttributes]::ReparsePoint
            FullName = [System.IO.Path]::GetFullPath($leafPath)
            TargetPath = [System.IO.Path]::GetFullPath($outsideLeafPath)
        }
        $fakeLeaf | Add-Member -MemberType ScriptMethod -Name ResolveLinkTarget -Value {
            param([bool]$ReturnFinalTarget)
            return [System.IO.FileInfo]::new([string]$this.TargetPath)
        }

        Mock Get-Item {
            if (
                [System.IO.Path]::GetFullPath([string]$LiteralPath) -eq
                [System.IO.Path]::GetFullPath($leafPath)
            ) {
                return $fakeLeaf
            }
            if ([System.IO.Directory]::Exists([string]$LiteralPath)) {
                return [System.IO.DirectoryInfo]::new([string]$LiteralPath)
            }
            if ([System.IO.File]::Exists([string]$LiteralPath)) {
                return [System.IO.FileInfo]::new([string]$LiteralPath)
            }

            throw [System.IO.FileNotFoundException]::new(
                "Mocked filesystem item does not exist: $LiteralPath"
            )
        }

        {
            Resolve-ExistingPathInsideRoot `
                -Root $root `
                -Candidate $leafPath `
                -MessagePrefix 'workflow.yml leaf escapes workflows root' |
                Out-Null
        } | Should -Throw '*workflow.yml leaf escapes workflows root*outside physical root*'
    }
}
