#!/usr/bin/env pwsh
#Requires -Module Pester

# Discriminating R-B20 coverage: each tamper below reached workflow execution under
# the pre-RB-1 runner because it skipped schemas, coerced booleans, or fell back to
# defaultEnabled. The shared registry validator must now deny both run and listing.

BeforeAll {
    . "$PSScriptRoot/governance.config.ps1"

    $script:runWorkflow = Join-Path $WorkspaceRoot 'studio/scripts/powershell/run-workflow.ps1'
    $script:listWorkflows = Join-Path $WorkspaceRoot 'studio/scripts/powershell/list-workflows.ps1'
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
"@ | Set-Content -LiteralPath (Join-Path $workflowRoot 'workflow.yml') -NoNewline

        Write-FixtureJson -Path (Join-Path $workflowRoot 'manifest.json') -Data ([ordered]@{
            id = $id
            version = '1.0.0'
            title = 'Runner Authorization Test'
            kind = 'workflow'
            status = 'active'
            owner = 'studio'
        })

        $policy = [ordered]@{
            mode = 'studio-first'
            curatedOnly = $true
            autoEnableNewWorkflows = $false
            reviewStatuses = @('draft', 'approved', 'experimental', 'deprecated', 'rejected')
            trustLevels = @('core', 'curated', 'experimental')
            stateSources = @('default', 'manual', 'sync')
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
}

Describe 'run-workflow: shared fail-closed registry authorization (R-B20)' {
    It 'uses the same valid authorization result as list-workflows' {
        $fixture = New-RunnerAuthorizationFixture

        $listing = Invoke-FixtureListing -Fixture $fixture
        $listing.ExitCode | Should -Be 0
        $listing.Result.VALID | Should -BeTrue
        $listing.Result.WORKFLOWS[0].executionAuthorized | Should -BeTrue

        $runner = Invoke-FixtureRunner -Fixture $fixture
        $runner.ExitCode | Should -Be 43
        $runner.Result.STATUS | Should -Be 'awaiting_gate'
    }

    It 'denies <Name> in both runner and listing' -ForEach @(
        @{ Name = 'catalog defaultEnabled string false'; Kind = 'catalog-string-boolean' }
        @{ Name = 'state enabled string false'; Kind = 'state-string-boolean' }
        @{ Name = 'state enabled numeric wrong type'; Kind = 'state-number-boolean' }
        @{ Name = 'catalog defaultEnabled null'; Kind = 'catalog-null-boolean' }
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
