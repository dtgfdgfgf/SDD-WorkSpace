#!/usr/bin/env pwsh

#Requires -Version 7.0
<#
.SYNOPSIS
    Non-bypassable stage entry gate for /speckit.implement.

.DESCRIPTION
    Confirms that the canonical pre-implementation artifacts exist, readiness
    authorizes planning, any triggered ECI dossier authorizes mainline work,
    tasks.md contains pending canonical tasks, and /speckit.analyze emitted a
    schema-valid analysis-result.json bound to the current analyzed artifacts.

    analysis-checklist.md remains an optional human review surface. Its former
    `Analysis Status` field is not an authorization source. The machine gate is
    analysis-result.json plus studio/runtime/analysis-result.schema.json.

    The former `-Force` bypass is intentionally not accepted. Implement is the
    terminal delivery stage, so readiness, ECI, Analyze, and intent-obligation
    blockers cannot be converted into READY by an operator switch.

.PARAMETER FeatureDir
    Optional override for the feature directory.

.PARAMETER Task
    Optional task ID filter (e.g. T001) to validate before driving a single
    task implementation pass.

.PARAMETER CompletionValidation
    Re-run the same non-bypassable gate for a terminal completion candidate.
    This permits zero pending tasks; every readiness, ECI, Analyze, intent,
    artifact-binding, and feature-structure check remains mandatory.

.PARAMETER Json
    Emit a single structured JSON object instead of human-readable text.

.PARAMETER Help
    Show this help message.

.NOTES
    Exit code: 0 ready for implement, 1 entry-gate failure.
#>

[CmdletBinding()]
param(
    [string]$FeatureDir,
    [string]$Task,
    [switch]$CompletionValidation,
    [switch]$Json,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Output 'Usage: ./setup-implement.ps1 [-FeatureDir <path>] [-Task T###] [-CompletionValidation] [-Json] [-Help]'
    Write-Output '  -FeatureDir  Override feature directory (defaults to current branch).'
    Write-Output '  -Task        Validate readiness for a specific task ID (e.g. T001).'
    Write-Output '  -CompletionValidation  Permit zero pending tasks while re-running every other gate.'
    Write-Output '  -Json        Output results as JSON.'
    Write-Output '  -Help        Show this help message.'
    Write-Output '  This gate has no -Force bypass.'
    exit 0
}

. "$PSScriptRoot/common.ps1"

function Resolve-FeatureContext {
    param([string]$Override)

    if ($Override) {
        $resolved = Resolve-AbsolutePath -Path $Override
        $readinessDir = Join-Path $resolved 'readiness'
        return [PSCustomObject]@{
            FEATURE_DIR          = $resolved
            FEATURE_SPEC         = Join-Path $resolved 'spec.md'
            READINESS_DIR        = $readinessDir
            READINESS_ASSESSMENT = Join-Path $readinessDir 'readiness-assessment.md'
            ECI_DIR              = Join-Path $readinessDir 'eci'
            ECI_TRIGGER          = Join-Path $readinessDir 'eci-trigger.md'
            IMPL_PLAN            = Join-Path $resolved 'plan.md'
            TASKS                = Join-Path $resolved 'tasks.md'
            INTENT_LEDGER        = Join-Path $resolved 'intent-ledger.md'
            ANALYSIS_RESULT      = Join-Path $resolved 'analysis-result.json'
            ANALYSIS_CHECKLIST   = Join-Path $resolved 'analysis-checklist.md'
        }
    }

    $base = Get-FeaturePathsEnv
    $readinessDir = Join-Path $base.FEATURE_DIR 'readiness'
    return [PSCustomObject]@{
        FEATURE_DIR          = $base.FEATURE_DIR
        FEATURE_SPEC         = $base.FEATURE_SPEC
        READINESS_DIR        = $readinessDir
        READINESS_ASSESSMENT = Join-Path $readinessDir 'readiness-assessment.md'
        ECI_DIR              = Join-Path $readinessDir 'eci'
        ECI_TRIGGER          = Join-Path $readinessDir 'eci-trigger.md'
        IMPL_PLAN            = $base.IMPL_PLAN
        TASKS                = $base.TASKS
        INTENT_LEDGER        = Join-Path $base.FEATURE_DIR 'intent-ledger.md'
        ANALYSIS_RESULT      = Join-Path $base.FEATURE_DIR 'analysis-result.json'
        ANALYSIS_CHECKLIST   = Join-Path $base.FEATURE_DIR 'analysis-checklist.md'
    }
}

function Invoke-FeatureStructureValidation {
    param([string]$FeatureDir)

    $validatorPath = Join-Path $PSScriptRoot 'validate-feature-structure.ps1'
    if (-not (Test-Path -LiteralPath $validatorPath -PathType Leaf)) {
        return [PSCustomObject]@{
            Parsed = $false
            Result = $null
            Error  = "validate-feature-structure.ps1 is missing: $validatorPath"
        }
    }

    try {
        $raw = @(& pwsh -NoProfile -File $validatorPath -FeatureDir $FeatureDir -Json 2>$null)
        $validatorExitCode = $LASTEXITCODE
    } catch {
        return [PSCustomObject]@{
            Parsed = $false
            Result = $null
            Error  = "validate-feature-structure.ps1 failed: $($_.Exception.Message)"
        }
    }

    if ($validatorExitCode -ne 0) {
        $validatorDetails = ''
        $validatorJson = $raw -join [Environment]::NewLine
        if (-not [string]::IsNullOrWhiteSpace($validatorJson)) {
            try {
                $validatorFailure = $validatorJson | ConvertFrom-Json -ErrorAction Stop
                $reportedErrors = @($validatorFailure.ERRORS | ForEach-Object {
                    if ($_.id -and $_.message) { "[$($_.id)] $($_.message)" } else { [string]$_ }
                } | Where-Object { $_ })
                if ($reportedErrors.Count -gt 0) {
                    $validatorDetails = " Reported errors: $($reportedErrors -join '; ')"
                }
            } catch {
                # The non-zero exit remains independently authoritative. Never trust
                # malformed output merely because the child emitted some text.
            }
        }
        return [PSCustomObject]@{
            Parsed = $false
            Result = $null
            Error  = "validate-feature-structure.ps1 exited with code $validatorExitCode.$validatorDetails"
        }
    }

    $json = $raw -join [Environment]::NewLine
    if ([string]::IsNullOrWhiteSpace($json)) {
        return [PSCustomObject]@{
            Parsed = $false
            Result = $null
            Error  = 'validate-feature-structure.ps1 returned no machine-readable result.'
        }
    }

    try {
        $parsed = $json | ConvertFrom-Json -ErrorAction Stop
    } catch {
        return [PSCustomObject]@{
            Parsed = $false
            Result = $null
            Error  = "validate-feature-structure.ps1 returned invalid JSON: $($_.Exception.Message)"
        }
    }

    if ($parsed.PSObject.Properties.Name -notcontains 'VALID' -or $parsed.VALID -isnot [bool]) {
        return [PSCustomObject]@{
            Parsed = $false
            Result = $null
            Error  = 'validate-feature-structure.ps1 result is missing boolean VALID.'
        }
    }

    return [PSCustomObject]@{
        Parsed = $true
        Result = $parsed
        Error  = $null
    }
}

function Get-PendingTasks {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return @() }
    $content = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrEmpty($content)) { return @() }
    $rxMatches = [regex]::Matches($content, '(?m)^- \[\s\]\s+(T\d{3})\b.*$')
    return @($rxMatches | ForEach-Object { @{ Id = $_.Groups[1].Value; Line = $_.Value.Trim() } })
}

function Get-ArtifactBindingHash {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [switch]$NormalizeTaskCheckboxes
    )

    if (-not $NormalizeTaskCheckboxes) {
        return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    }

    $content = [System.IO.File]::ReadAllText($Path, [System.Text.UTF8Encoding]::new($false, $true))
    $normalized = [regex]::Replace(
        $content,
        '(?m)^(- )\[(?: |x|X)\](\s+T\d{3}\b)',
        '$1[ ]$2'
    )
    $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($normalized)
    $digest = [System.Security.Cryptography.SHA256]::HashData($bytes)
    return ([System.Convert]::ToHexString($digest)).ToLowerInvariant()
}

function Get-AnalyzeCompletionState {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$SchemaPath
    )

    $errors = New-Object System.Collections.Generic.List[string]
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        $errors.Add("/speckit.analyze has not run: analysis-result.json is missing: $Path") | Out-Null
        return [PSCustomObject]@{ State = 'missing'; Data = $null; Errors = @($errors) }
    }
    if (-not (Test-Path -LiteralPath $SchemaPath -PathType Leaf)) {
        $errors.Add("Canonical Analyze result schema is missing: $SchemaPath") | Out-Null
        return [PSCustomObject]@{ State = 'invalid'; Data = $null; Errors = @($errors) }
    }

    try {
        $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
        $data = $raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop
    } catch {
        $errors.Add("/speckit.analyze is not complete: analysis-result.json is invalid JSON: $($_.Exception.Message)") | Out-Null
        return [PSCustomObject]@{ State = 'invalid'; Data = $null; Errors = @($errors) }
    }

    try {
        $schema = Get-Content -LiteralPath $SchemaPath -Raw -ErrorAction Stop
        $null = $schema | ConvertFrom-Json -AsHashtable -ErrorAction Stop
        $schemaValid = Test-Json -Json $raw -Schema $schema -ErrorAction Stop
        if (-not $schemaValid) {
            $errors.Add("/speckit.analyze is not complete: analysis-result.json does not conform to $SchemaPath") | Out-Null
        }
    } catch {
        $errors.Add("/speckit.analyze is not complete: Analyze result schema validation failed: $($_.Exception.Message)") | Out-Null
    }

    if ($errors.Count -gt 0) {
        return [PSCustomObject]@{ State = 'invalid'; Data = $data; Errors = @($errors) }
    }

    return [PSCustomObject]@{ State = 'complete'; Data = $data; Errors = @() }
}

function Get-UnresolvedCriticalFindings {
    param([System.Collections.IDictionary]$AnalyzeResult)

    if (-not $AnalyzeResult) { return @() }
    return @($AnalyzeResult['criticalFindings'] | Where-Object {
        [string]$_['status'] -eq 'OPEN'
    })
}

function Test-AnalyzeArtifactBindings {
    param(
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$AnalyzeResult,
        [Parameter(Mandatory = $true)]$Paths
    )

    $bindingErrors = New-Object System.Collections.Generic.List[string]
    $hashes = $AnalyzeResult['artifactHashes']
    $bindings = @(
        @{ Name = 'spec.md'; Path = $Paths.FEATURE_SPEC; NormalizeTasks = $false }
        @{ Name = 'readiness/readiness-assessment.md'; Path = $Paths.READINESS_ASSESSMENT; NormalizeTasks = $false }
        @{ Name = 'plan.md'; Path = $Paths.IMPL_PLAN; NormalizeTasks = $false }
        @{ Name = 'tasks.md'; Path = $Paths.TASKS; NormalizeTasks = $true }
    )
    if ($AnalyzeResult['eciRequired'] -eq $true) {
        $bindings += @(
            @{ Name = 'readiness/eci-trigger.md'; Path = $Paths.ECI_TRIGGER; NormalizeTasks = $false }
            @{ Name = 'readiness/eci/eci-assessment.md'; Path = (Join-Path $Paths.ECI_DIR 'eci-assessment.md'); NormalizeTasks = $false }
            @{ Name = 'readiness/eci/source-manifest.md'; Path = (Join-Path $Paths.ECI_DIR 'source-manifest.md'); NormalizeTasks = $false }
            @{ Name = 'readiness/eci/adoption-record.md'; Path = (Join-Path $Paths.ECI_DIR 'adoption-record.md'); NormalizeTasks = $false }
            @{ Name = 'readiness/eci/authorization-record.md'; Path = (Join-Path $Paths.ECI_DIR 'authorization-record.md'); NormalizeTasks = $false }
        )
    }

    foreach ($binding in $bindings) {
        if (-not (Test-Path -LiteralPath $binding.Path -PathType Leaf)) {
            if ($binding.Name -like 'readiness/eci*') {
                $bindingErrors.Add("analysis-result.json records required ECI evidence, but $($binding.Name) is missing.") | Out-Null
            }
            continue
        }
        $expected = Get-ArtifactBindingHash -Path $binding.Path -NormalizeTaskCheckboxes:$binding.NormalizeTasks
        $actual = [string]$hashes[$binding.Name]
        if (-not [string]::Equals($expected, $actual, [System.StringComparison]::Ordinal)) {
            $bindingErrors.Add("analysis-result.json is stale: hash mismatch for $($binding.Name). Re-run /speckit.analyze.") | Out-Null
        }
    }

    $ledgerExists = Test-Path -LiteralPath $Paths.INTENT_LEDGER -PathType Leaf
    $ledgerHash = $hashes['intent-ledger.md']
    if ($ledgerExists) {
        $expectedLedgerHash = Get-ArtifactBindingHash -Path $Paths.INTENT_LEDGER
        if (-not [string]::Equals($expectedLedgerHash, [string]$ledgerHash, [System.StringComparison]::Ordinal)) {
            $bindingErrors.Add('analysis-result.json is stale: hash mismatch for intent-ledger.md. Re-run /speckit.analyze.') | Out-Null
        }
    } elseif ($null -ne $ledgerHash) {
        $bindingErrors.Add('analysis-result.json declares an intent-ledger.md hash, but the artifact is absent.') | Out-Null
    }

    return @($bindingErrors)
}

function Split-IntentLedgerRow {
    param([Parameter(Mandatory = $true)][string]$Line)

    $body = $Line.Trim()
    if ($body.StartsWith('|')) { $body = $body.Substring(1) }
    if ($body.EndsWith('|')) { $body = $body.Substring(0, $body.Length - 1) }
    return @([regex]::Split($body, '(?<!\\)\|') | ForEach-Object { $_.Trim() })
}

function Get-IntentLedgerEntries {
    param([Parameter(Mandatory = $true)][string]$Path)

    $entries = New-Object System.Collections.Generic.List[object]
    $errors = New-Object System.Collections.Generic.List[string]
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [PSCustomObject]@{ Entries = @(); Errors = @() }
    }

    $canonicalHeaders = @(
        'source_intent_item',
        'spec_anchor',
        'current_classification',
        'current_representation',
        'defer_or_drop_reason',
        'reentry_trigger',
        'follow_on_feature_hint',
        'surface_disclosure_required',
        'owner_signoff_required'
    )
    $lines = Get-Content -LiteralPath $Path
    $headerIndex = -1
    for ($lineIndex = 0; $lineIndex -lt $lines.Count; $lineIndex++) {
        if ($lines[$lineIndex] -notmatch '^\s*\|') { continue }
        $candidate = @(Split-IntentLedgerRow -Line $lines[$lineIndex])
        if ($candidate -contains 'source_intent_item' -or $candidate -contains 'current_classification') {
            $headerIndex = $lineIndex
            if ($candidate.Count -ne $canonicalHeaders.Count -or
                (Compare-Object -ReferenceObject $canonicalHeaders -DifferenceObject $candidate -SyncWindow 0)) {
                $errors.Add("intent-ledger.md header must contain the canonical nine columns in canonical order: $($canonicalHeaders -join ', ').") | Out-Null
            }
            break
        }
    }
    if ($headerIndex -lt 0) {
        $errors.Add('intent-ledger.md is missing its canonical nine-column ledger header.') | Out-Null
        return [PSCustomObject]@{ Entries = @(); Errors = $errors.ToArray() }
    }
    if ($errors.Count -gt 0) {
        return [PSCustomObject]@{ Entries = @(); Errors = $errors.ToArray() }
    }

    $separatorIndex = $headerIndex + 1
    if ($separatorIndex -ge $lines.Count -or $lines[$separatorIndex] -notmatch '^\s*\|') {
        $errors.Add('intent-ledger.md canonical header must be followed by a nine-column Markdown separator row.') | Out-Null
        return [PSCustomObject]@{ Entries = @(); Errors = $errors.ToArray() }
    }
    $separatorCells = @(Split-IntentLedgerRow -Line $lines[$separatorIndex])
    if ($separatorCells.Count -ne $canonicalHeaders.Count -or
        @($separatorCells | Where-Object { $_ -notmatch '^:?-{3,}:?$' }).Count -gt 0) {
        $errors.Add('intent-ledger.md canonical header must be followed by a valid nine-column Markdown separator row.') | Out-Null
        return [PSCustomObject]@{ Entries = @(); Errors = $errors.ToArray() }
    }

    $allowedClassifications = @('represented_by_substitute', 'deferred', 'dropped_with_owner_signoff')
    for ($lineIndex = $separatorIndex + 1; $lineIndex -lt $lines.Count; $lineIndex++) {
        if ($lines[$lineIndex] -notmatch '^\s*\|') { break }

        $cells = @(Split-IntentLedgerRow -Line $lines[$lineIndex])
        $displayLine = $lineIndex + 1
        if ($cells.Count -ne $canonicalHeaders.Count) {
            $errors.Add("intent-ledger.md line $displayLine has $($cells.Count) columns; exactly nine are required.") | Out-Null
            continue
        }
        if (@($cells | Where-Object { $_ -match '^:?-{3,}:?$' }).Count -eq $cells.Count) {
            $errors.Add("intent-ledger.md line $displayLine is an unexpected extra separator row.") | Out-Null
            continue
        }

        $normalizedCells = @($cells | ForEach-Object { ([string]$_ -replace '^`|`$', '').Trim() })
        $invalidCellIndexes = @(for ($cellIndex = 0; $cellIndex -lt $normalizedCells.Count; $cellIndex++) {
            if ([string]::IsNullOrWhiteSpace($normalizedCells[$cellIndex]) -or $normalizedCells[$cellIndex] -match '^\[.*\]$') {
                $cellIndex
            }
        })
        if ($invalidCellIndexes.Count -gt 0) {
            $invalidColumns = @($invalidCellIndexes | ForEach-Object { $canonicalHeaders[$_] })
            $errors.Add("intent-ledger.md line $displayLine has empty or placeholder canonical cell(s): $($invalidColumns -join ', ').") | Out-Null
            continue
        }

        $sourceItem = $normalizedCells[0]
        $classification = $normalizedCells[2]
        if ($allowedClassifications -notcontains $classification) {
            $errors.Add("intent-ledger.md line $displayLine has invalid current_classification '$classification'.") | Out-Null
            continue
        }
        if ($classification -eq 'represented_by_substitute' -and
            $normalizedCells[3] -match '^(?i:n/?a|none|no|tbd|not applicable)$') {
            $errors.Add("intent-ledger.md line $displayLine requires a concrete current_representation for represented_by_substitute.") | Out-Null
            continue
        }
        if ($classification -eq 'deferred' -and
            $normalizedCells[5] -match '^(?i:n/?a|none|tbd|later|v\d+\+?)$') {
            $errors.Add("intent-ledger.md line $displayLine requires a concrete reentry_trigger for deferred intent; N/A and generic version labels are invalid.") | Out-Null
            continue
        }
        if ($classification -eq 'dropped_with_owner_signoff' -and
            $normalizedCells[8] -match '^(?i:no|n/?a|none|tbd|not applicable)$') {
            $errors.Add("intent-ledger.md line $displayLine requires owner signoff evidence for dropped_with_owner_signoff.") | Out-Null
            continue
        }
        $entries.Add([PSCustomObject]@{
            SourceIntentItem = $sourceItem
            Classification   = $classification
        }) | Out-Null
    }
    if ($entries.Count -eq 0) {
        $errors.Add('intent-ledger.md contains no canonical intent obligation rows.') | Out-Null
    }
    return [PSCustomObject]@{ Entries = $entries.ToArray(); Errors = $errors.ToArray() }
}

$paths = Resolve-FeatureContext -Override $FeatureDir

# Path boundary defense: -FeatureDir override or SPECIFY_FEATURE env var could be tampered to escape the project.
$projectRootForBoundary = if ($FeatureDir) {
    $specsParent = Split-Path -Parent $paths.FEATURE_DIR
    if ((Split-Path -Leaf $specsParent) -ne 'specs') {
        throw "FEATURE_DIR escapes project root: $($paths.FEATURE_DIR) must be located at <project>/specs/<feature>"
    }
    Split-Path -Parent $specsParent
} else {
    Get-RepoRoot
}
if (-not $projectRootForBoundary) { throw 'Unable to resolve project root for path boundary check.' }
Assert-PathInsideRoot -Root $projectRootForBoundary -Candidate $paths.FEATURE_DIR -MessagePrefix 'FEATURE_DIR escapes project root'
Assert-PathInsideRoot -Root $projectRootForBoundary -Candidate $paths.TASKS -MessagePrefix 'TASKS escapes project root'
Assert-PathInsideRoot -Root $projectRootForBoundary -Candidate $paths.READINESS_ASSESSMENT -MessagePrefix 'READINESS_ASSESSMENT escapes project root'
Assert-PathInsideRoot -Root $projectRootForBoundary -Candidate $paths.ANALYSIS_RESULT -MessagePrefix 'ANALYSIS_RESULT escapes project root'
Assert-PathInsideRoot -Root $projectRootForBoundary -Candidate $paths.ANALYSIS_CHECKLIST -MessagePrefix 'ANALYSIS_CHECKLIST escapes project root'

$trustedStudioRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$analysisResultSchema = Join-Path $trustedStudioRoot 'runtime/analysis-result.schema.json'
$blockers = New-Object System.Collections.Generic.List[string]
$messages = New-Object System.Collections.Generic.List[string]

$required = @(
    @{ Path = $paths.FEATURE_SPEC;         Name = 'spec.md';                          Stage = '/speckit.specify' }
    @{ Path = $paths.READINESS_ASSESSMENT; Name = 'readiness/readiness-assessment.md'; Stage = '/speckit.readiness' }
    @{ Path = $paths.IMPL_PLAN;            Name = 'plan.md';                          Stage = '/speckit.plan' }
    @{ Path = $paths.TASKS;                Name = 'tasks.md';                         Stage = '/speckit.tasks' }
)
foreach ($req in $required) {
    if (-not (Test-Path -LiteralPath $req.Path -PathType Leaf)) {
        $blockers.Add("$($req.Name) is required before /speckit.implement. Complete $($req.Stage) first: $($req.Path)") | Out-Null
    }
}

$readinessAssessmentExists = Test-Path -LiteralPath $paths.READINESS_ASSESSMENT -PathType Leaf
$primaryStatus = if ($readinessAssessmentExists) {
    Get-MarkdownField -Path $paths.READINESS_ASSESSMENT -Field 'Primary Status'
} else {
    $null
}
if ($readinessAssessmentExists -and -not $primaryStatus) {
    $blockers.Add('readiness-assessment.md has no machine-readable Primary Status.') | Out-Null
} elseif ($primaryStatus -and $primaryStatus -ne 'READY_FOR_PLAN') {
    $blockers.Add("readiness Primary Status is '$primaryStatus'; /speckit.implement requires READY_FOR_PLAN.") | Out-Null
}

$eciArtifactBindings = @(
    @{ Name = 'readiness/eci-trigger.md'; Path = $paths.ECI_TRIGGER }
    @{ Name = 'readiness/eci/eci-assessment.md'; Path = (Join-Path $paths.ECI_DIR 'eci-assessment.md') }
    @{ Name = 'readiness/eci/source-manifest.md'; Path = (Join-Path $paths.ECI_DIR 'source-manifest.md') }
    @{ Name = 'readiness/eci/adoption-record.md'; Path = (Join-Path $paths.ECI_DIR 'adoption-record.md') }
    @{ Name = 'readiness/eci/authorization-record.md'; Path = (Join-Path $paths.ECI_DIR 'authorization-record.md') }
)
$observedEciRequired = (
    $primaryStatus -eq 'ROUTE_TO_ECI' -or
    @($eciArtifactBindings | Where-Object { Test-Path -LiteralPath $_.Path -PathType Leaf }).Count -gt 0
)
$recordedEciRequired = $false
$eciRequired = $observedEciRequired
$authorizationOutcome = $null

$pendingTasks = Get-PendingTasks -Path $paths.TASKS
if (-not $CompletionValidation -and $pendingTasks.Count -eq 0 -and (Test-Path -LiteralPath $paths.TASKS -PathType Leaf)) {
    $blockers.Add('tasks.md has no pending canonical "- [ ] T### ..." lines. Either run /speckit.tasks or mark tasks pending again.') | Out-Null
}

$selectedTask = $null
if ($Task) {
    $selectedTask = $pendingTasks | Where-Object { $_.Id -eq $Task } | Select-Object -First 1
    if (-not $selectedTask) {
        $blockers.Add("Task $Task is not pending in tasks.md. Available pending IDs: $((@($pendingTasks | ForEach-Object { $_.Id }) -join ', '))") | Out-Null
    }
}

$analyzeCompletion = if ($analysisResultSchema) {
    Get-AnalyzeCompletionState -Path $paths.ANALYSIS_RESULT -SchemaPath $analysisResultSchema
} else {
    [PSCustomObject]@{
        State = 'invalid'
        Data = $null
        Errors = @('Unable to resolve the canonical Analyze result schema from the studio root.')
    }
}
foreach ($analyzeError in $analyzeCompletion.Errors) {
    $blockers.Add($analyzeError) | Out-Null
}

$criticalFindings = @()
if ($analyzeCompletion.State -eq 'complete' -and $analyzeCompletion.Data -is [System.Collections.IDictionary]) {
    $recordedEciRequired = $analyzeCompletion.Data['eciRequired'] -eq $true
    $eciRequired = $observedEciRequired -or $recordedEciRequired
    if ($recordedEciRequired -ne $observedEciRequired) {
        $blockers.Add("analysis-result.json ECI requirement ($recordedEciRequired) contradicts current ECI evidence ($observedEciRequired); ECI governance cannot be added or removed without re-running /speckit.analyze.") | Out-Null
    }

    $expectedFeatureId = Split-Path -Leaf $paths.FEATURE_DIR
    if (-not [string]::Equals([string]$analyzeCompletion.Data['featureId'], $expectedFeatureId, [System.StringComparison]::Ordinal)) {
        $blockers.Add("analysis-result.json featureId does not match feature directory '$expectedFeatureId'.") | Out-Null
    }

    foreach ($bindingError in (Test-AnalyzeArtifactBindings -AnalyzeResult $analyzeCompletion.Data -Paths $paths)) {
        $blockers.Add($bindingError) | Out-Null
    }

    if ([string]$analyzeCompletion.Data['outcome'] -ne 'IMPLEMENTATION_READY') {
        $blockers.Add("/speckit.analyze is not complete for implementation: outcome is '$($analyzeCompletion.Data['outcome'])'.") | Out-Null
    }

    $criticalFindings = @(Get-UnresolvedCriticalFindings -AnalyzeResult $analyzeCompletion.Data)
    foreach ($finding in $criticalFindings) {
        $blockers.Add("analysis-result.json has unresolved Critical finding [$($finding['id'])]: $($finding['summary'])") | Out-Null
    }

    $intentDrift = $analyzeCompletion.Data['intentDriftCheck']
    if ([string]$intentDrift['status'] -ne 'PASS') {
        $blockers.Add("Intent Drift Check is '$($intentDrift['status'])': $($intentDrift['summary'])") | Out-Null
    }

    $intentObligations = $analyzeCompletion.Data['intentObligations']
    $obligationItems = @($intentObligations['items'])
    $blockingObligations = @($obligationItems | Where-Object { [string]$_['status'] -eq 'BLOCKING' })
    $intentLedgerExists = Test-Path -LiteralPath $paths.INTENT_LEDGER -PathType Leaf
    if ($intentLedgerExists) {
        $ledgerState = Get-IntentLedgerEntries -Path $paths.INTENT_LEDGER
        $ledgerEntries = @($ledgerState.Entries)
        foreach ($ledgerError in @($ledgerState.Errors)) {
            $blockers.Add($ledgerError) | Out-Null
        }
        if ($ledgerState.Errors.Count -eq 0 -and
            ([string]$intentObligations['status'] -ne 'ACCOUNTED' -or $ledgerEntries.Count -eq 0 -or $obligationItems.Count -ne $ledgerEntries.Count)) {
            $blockers.Add('intent-ledger.md exists, but analysis-result.json does not account for its intent obligations.') | Out-Null
        } elseif ($ledgerState.Errors.Count -eq 0) {
            foreach ($ledgerEntry in $ledgerEntries) {
                $matches = @($obligationItems | Where-Object {
                    [string]$_['sourceIntentItem'] -eq $ledgerEntry.SourceIntentItem -and
                    [string]$_['classification'] -eq $ledgerEntry.Classification
                })
                if ($matches.Count -ne 1) {
                    $blockers.Add("analysis-result.json does not account exactly once for intent obligation '$($ledgerEntry.SourceIntentItem)'.") | Out-Null
                }
            }
        }
    } elseif ([string]$intentObligations['status'] -ne 'NOT_REQUIRED' -or $obligationItems.Count -ne 0) {
        $blockers.Add('analysis-result.json intent obligations contradict the absence of intent-ledger.md.') | Out-Null
    }
    foreach ($obligation in $blockingObligations) {
        $blockers.Add("Intent obligation is blocking [$($obligation['sourceIntentItem'])]: $($obligation['evidence'])") | Out-Null
    }
}

if ($eciRequired) {
    foreach ($binding in $eciArtifactBindings) {
        if (-not (Test-Path -LiteralPath $binding.Path -PathType Leaf)) {
            $blockers.Add("Triggered or Analyze-recorded ECI governance requires $($binding.Name) before /speckit.implement.") | Out-Null
        }
    }

    $authorizationPath = Join-Path $paths.ECI_DIR 'authorization-record.md'
    if (Test-Path -LiteralPath $authorizationPath -PathType Leaf) {
        $authorizationOutcome = Get-MarkdownField -Path $authorizationPath -Field 'Authorization Outcome'
        if (-not $authorizationOutcome) {
            $blockers.Add('ECI authorization-record.md has no machine-readable Authorization Outcome.') | Out-Null
        } elseif ($authorizationOutcome -ne 'READY_FOR_MAINLINE_IMPLEMENTATION') {
            $blockers.Add("ECI Authorization Outcome is '$authorizationOutcome'; mainline implementation is not authorized.") | Out-Null
        }
    }
}

$validationInvocation = Invoke-FeatureStructureValidation -FeatureDir $paths.FEATURE_DIR
$validation = $validationInvocation.Result
if (-not $validationInvocation.Parsed) {
    $blockers.Add($validationInvocation.Error) | Out-Null
} elseif (-not $validation.VALID) {
    foreach ($err in @($validation.ERRORS)) {
        $blockers.Add("validate-feature-structure: [$($err.id)] $($err.message)") | Out-Null
    }
}
if ($validationInvocation.Parsed -and $validation.WARNING_COUNT -gt 0) {
    foreach ($warning in @($validation.WARNINGS)) {
        $messages.Add("validate-feature-structure warning: [$($warning.id)] $($warning.message)") | Out-Null
    }
}

$ready = $blockers.Count -eq 0
$stage = 'implement'
$result = [ordered]@{
    STAGE                 = $stage
    READY                 = $ready
    FORCED                = $false
    COMPLETION_VALIDATION = [bool]$CompletionValidation
    FEATURE_DIR           = $paths.FEATURE_DIR
    READINESS_ASSESSMENT  = $paths.READINESS_ASSESSMENT
    READINESS_STATUS      = $primaryStatus
    ECI_REQUIRED          = $eciRequired
    ECI_AUTHORIZATION     = $authorizationOutcome
    IMPL_PLAN             = $paths.IMPL_PLAN
    TASKS                 = $paths.TASKS
    INTENT_LEDGER         = $paths.INTENT_LEDGER
    ANALYSIS_RESULT       = $paths.ANALYSIS_RESULT
    ANALYSIS_RESULT_SCHEMA = $analysisResultSchema
    ANALYSIS_CHECKLIST    = $paths.ANALYSIS_CHECKLIST
    ANALYZE_STATE         = $analyzeCompletion.State
    PENDING_TASKS         = @($pendingTasks)
    SELECTED_TASK         = $selectedTask
    UNRESOLVED_CRITICAL   = @($criticalFindings)
    STRUCTURE_VALID       = if ($validationInvocation.Parsed) { $validation.VALID } else { $null }
    BLOCKERS              = @($blockers)
    MESSAGES              = @($messages)
}

if ($Json) {
    [PSCustomObject]$result | ConvertTo-Json -Depth 8 -Compress
} else {
    Write-Output ("STAGE: {0}" -f $stage)
    Write-Output ("READY: {0}" -f $ready)
    Write-Output ("FEATURE_DIR: {0}" -f $paths.FEATURE_DIR)
    Write-Output ("READINESS_STATUS: {0}" -f $primaryStatus)
    Write-Output ("ANALYZE_STATE: {0}" -f $analyzeCompletion.State)
    Write-Output ("PENDING_TASKS: {0}" -f $pendingTasks.Count)
    foreach ($pendingTask in $pendingTasks) { Write-Output ("  - {0}: {1}" -f $pendingTask.Id, $pendingTask.Line) }
    if ($selectedTask) { Write-Output ("SELECTED_TASK: {0}" -f $selectedTask.Id) }
    if ($validationInvocation.Parsed) { Write-Output ("STRUCTURE_VALID: {0}" -f $validation.VALID) }
    foreach ($blocker in $blockers) { Write-Output "[BLOCKER] $blocker" }
    foreach ($message in $messages) { Write-Output "[NOTE] $message" }
}

if (-not $ready) { exit 1 } else { exit 0 }
