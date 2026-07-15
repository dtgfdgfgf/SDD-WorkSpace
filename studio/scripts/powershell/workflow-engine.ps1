#!/usr/bin/env pwsh

#Requires -Version 7.0
<#
.SYNOPSIS
    Studio workflow engine: YAML parser, schema gate, expression evaluator,
    state machine, and step dispatcher.

.DESCRIPTION
    Dot-source this file from run-workflow.ps1. The engine implements the
    Wave-3 step set (command/gate/if/switch). prompt/shell/while/do-while/
    fan-out/fan-in are surfaced as step-type-not-implemented errors.

    Expression subset:
      - {{ ref }} interpolation (dotted lookup against inputs/vars/steps).
      - Comparisons:  ==, !=
      - Boolean:      and, or, not (with parentheses, short-circuit)
      - Filter:       {{ ref | default('VALUE') }}

    RunState lives at <project>/.workflow/runs/<feature>/state.json (local transient,
    ignored by Git; atomic write via .tmp + Move-Item -Force, plus a 60-second
    advisory lock at state.json.lock).

    The engine never auto-installs powershell-yaml; the operator must install
    it explicitly. Detection-only via Assert-YamlModuleAvailable.

.NOTES
    Wave 3 baseline. Step types extend in later waves.
    Step type implementations: Invoke-CommandStep, Invoke-GateStep,
    Invoke-IfStep, Invoke-SwitchStep. Engine entry: Invoke-Workflow.
    Schema reference: studio/workflows/manifest.schema.json. RunState format:
    documented inline below.
#>

. "$PSScriptRoot/common.ps1"

# ============================================================================
# YAML and schema
# ============================================================================

function Assert-YamlModuleAvailable {
    $module = Get-Module -ListAvailable -Name 'powershell-yaml' | Select-Object -First 1
    if (-not $module) {
        throw 'powershell-yaml module is required. Install: Install-Module -Name powershell-yaml -Scope CurrentUser'
    }
    if (-not (Get-Module -Name 'powershell-yaml')) {
        Import-Module -Name 'powershell-yaml' -ErrorAction Stop
    }
}

function Read-WorkflowYaml {
    param([Parameter(Mandatory)] [string]$Path)
    Assert-YamlModuleAvailable
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "workflow.yml not found: $Path"
    }
    $raw = Get-Content -LiteralPath $Path -Raw
    return (ConvertFrom-Yaml -Yaml $raw -Ordered)
}

function Test-WorkflowSchema {
    param(
        [Parameter(Mandatory)] $Document,
        [Parameter(Mandatory)] [string]$SchemaPath
    )
    if (-not (Test-Path -LiteralPath $SchemaPath -PathType Leaf)) {
        throw "Workflow schema not found: $SchemaPath"
    }
    $schema = Get-Content -LiteralPath $SchemaPath -Raw
    $jsonString = ($Document | ConvertTo-Json -Depth 30 -Compress)
    return [bool](Test-Json -Json $jsonString -Schema $schema -ErrorAction Stop)
}

# ============================================================================
# Expression evaluator (minimal subset; sandboxed, no .NET reflection)
# ============================================================================

function Resolve-DottedReference {
    param(
        [Parameter(Mandatory)] $Context,
        [Parameter(Mandatory)] [string]$Reference
    )
    $segments = $Reference.Split('.')
    $current = $Context
    foreach ($seg in $segments) {
        if ($null -eq $current) { return $null }
        if ($current -is [hashtable] -or $current -is [System.Collections.Specialized.OrderedDictionary]) {
            if ($current.Contains($seg)) { $current = $current[$seg] } else { return $null }
        } elseif ($current.PSObject -and ($current.PSObject.Properties.Match($seg).Count -gt 0)) {
            $current = $current.$seg
        } else {
            return $null
        }
    }
    return $current
}

function ConvertFrom-WorkflowLiteral {
    param([Parameter(Mandatory)] [string]$Token)
    $t = $Token.Trim()
    if ($t -match "^'([^']*)'$") { return $matches[1] }
    if ($t -match '^"([^"]*)"$') { return $matches[1] }
    if ($t -eq 'true') { return $true }
    if ($t -eq 'false') { return $false }
    if ($t -eq 'null') { return $null }
    if ($t -match '^-?\d+(\.\d+)?$') { return [double]$t }
    return $null
}

function Test-WorkflowLiteral {
    param([Parameter(Mandatory)] [string]$Token)
    $t = $Token.Trim()
    if ($t -match "^'[^']*'$") { return $true }
    if ($t -match '^"[^"]*"$') { return $true }
    if ($t -in 'true', 'false', 'null') { return $true }
    if ($t -match '^-?\d+(\.\d+)?$') { return $true }
    return $false
}

function Resolve-Interpolation {
    param(
        [Parameter(Mandatory)] [string]$Template,
        [Parameter(Mandatory)] $Context
    )
    $regex = [regex]'\{\{\s*([^{}]+?)\s*\}\}'
    return $regex.Replace($Template, {
        param($m)
        $expr = $m.Groups[1].Value.Trim()
        $value = Resolve-ExpressionToken -Token $expr -Context $Context
        if ($null -eq $value) { return '' }
        if ($value -is [bool]) { return $value.ToString().ToLower() }
        return [string]$value
    })
}

function Resolve-ExpressionToken {
    param(
        [Parameter(Mandatory)] [string]$Token,
        [Parameter(Mandatory)] $Context
    )
    $t = $Token.Trim()
    # filter form: ref | default('value')
    if ($t -match '^(.+?)\s*\|\s*default\(\s*(.+?)\s*\)\s*$') {
        $left = $matches[1].Trim()
        $fallback = ConvertFrom-WorkflowLiteral -Token $matches[2]
        $value = Resolve-ExpressionToken -Token $left -Context $Context
        if ($null -eq $value -or $value -eq '') { return $fallback }
        return $value
    }
    if (Test-WorkflowLiteral -Token $t) {
        return ConvertFrom-WorkflowLiteral -Token $t
    }
    return Resolve-DottedReference -Context $Context -Reference $t
}

function Test-WorkflowCondition {
    <#
    .SYNOPSIS
        Boolean evaluator for if-condition / switch-subject. Supports
        ==, !=, and, or, not, parentheses, plus dotted references and literals.
        Tokens that are not in the supported grammar raise an explicit error.
    #>
    param(
        [Parameter(Mandatory)] [string]$Expression,
        [Parameter(Mandatory)] $Context
    )
    $expr = (Resolve-Interpolation -Template $Expression -Context $Context).Trim()
    return [bool](Invoke-WorkflowBooleanExpression -Expression $expr -Context $Context)
}

function Invoke-WorkflowBooleanExpression {
    param(
        [Parameter(Mandatory)] [string]$Expression,
        [Parameter(Mandatory)] $Context
    )
    $tokens = ConvertTo-WorkflowTokens -Expression $Expression
    $script:_wfTokens = $tokens
    $script:_wfPos = 0
    $value = Invoke-WorkflowParseOr -Context $Context
    if ($script:_wfPos -lt $tokens.Count) {
        throw "Unexpected trailing tokens in expression: $Expression"
    }
    return $value
}

function ConvertTo-WorkflowTokens {
    param([Parameter(Mandatory)] [string]$Expression)
    # Tokens: words, parens, ==, !=, quoted strings, numbers
    $regex = [regex]"(==|!=|\(|\)|'[^']*'|""[^""]*""|[A-Za-z_][A-Za-z0-9_.\-]*|-?\d+(?:\.\d+)?)"
    $rxMatches = $regex.Matches($Expression)
    return @($rxMatches | ForEach-Object { $_.Value })
}

function Get-WorkflowToken { if ($script:_wfPos -lt $script:_wfTokens.Count) { return $script:_wfTokens[$script:_wfPos] } return $null }
function Step-WorkflowToken { $script:_wfPos++ }

function Invoke-WorkflowParseOr {
    param($Context)
    $left = Invoke-WorkflowParseAnd -Context $Context
    while ((Get-WorkflowToken) -eq 'or') {
        Step-WorkflowToken
        $right = Invoke-WorkflowParseAnd -Context $Context
        $left = [bool]($left -or $right)
    }
    return $left
}

function Invoke-WorkflowParseAnd {
    param($Context)
    $left = Invoke-WorkflowParseNot -Context $Context
    while ((Get-WorkflowToken) -eq 'and') {
        Step-WorkflowToken
        $right = Invoke-WorkflowParseNot -Context $Context
        $left = [bool]($left -and $right)
    }
    return $left
}

function Invoke-WorkflowParseNot {
    param($Context)
    if ((Get-WorkflowToken) -eq 'not') {
        Step-WorkflowToken
        $val = Invoke-WorkflowParseNot -Context $Context
        return -not $val
    }
    return Invoke-WorkflowParseComparison -Context $Context
}

function Invoke-WorkflowParseComparison {
    param($Context)
    $left = Invoke-WorkflowParseAtom -Context $Context
    $op = Get-WorkflowToken
    if ($op -in '==', '!=') {
        Step-WorkflowToken
        $right = Invoke-WorkflowParseAtom -Context $Context
        if ($op -eq '==') { return ($left -eq $right) }
        return ($left -ne $right)
    }
    return [bool]$left
}

function Invoke-WorkflowParseAtom {
    param($Context)
    $t = Get-WorkflowToken
    if ($null -eq $t) { throw 'Unexpected end of expression' }
    if ($t -eq '(') {
        Step-WorkflowToken
        $val = Invoke-WorkflowParseOr -Context $Context
        if ((Get-WorkflowToken) -ne ')') { throw 'Missing closing parenthesis' }
        Step-WorkflowToken
        return $val
    }
    Step-WorkflowToken
    if (Test-WorkflowLiteral -Token $t) {
        return ConvertFrom-WorkflowLiteral -Token $t
    }
    if ($t -in 'and', 'or', 'not') { throw "Unexpected operator: $t" }
    return Resolve-DottedReference -Context $Context -Reference $t
}

# ============================================================================
# RunState I/O (atomic, with advisory lock)
# ============================================================================

function Get-RunStatePath {
    param(
        [Parameter(Mandatory)] [string]$ProjectRoot,
        [Parameter(Mandatory)] [string]$Feature
    )
    if ($Feature -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]*$') {
        throw "Invalid feature name (must match ^[A-Za-z0-9][A-Za-z0-9_.-]*`$): $Feature"
    }
    # RunState is a local transient artifact. It lives outside specs/ so that starting a
    # run can never pre-create (and thereby allocate) a canonical specs/<feature> ID.
    $stateDir = Join-Path (Join-Path (Join-Path $ProjectRoot '.workflow') 'runs') $Feature
    Assert-PathInsideRoot -Root $ProjectRoot -Candidate $stateDir -MessagePrefix 'RunState directory escapes project root'
    if (-not (Test-Path -LiteralPath $stateDir)) {
        New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
    }
    return (Join-Path $stateDir 'state.json')
}

function Save-RunState {
    param(
        [Parameter(Mandatory)] $RunState,
        [Parameter(Mandatory)] [string]$Path
    )
    $RunState.updated_at = Get-IsoTimestamp
    $tmp = "$Path.tmp"
    $RunState | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $tmp -NoNewline -Encoding utf8
    Move-Item -LiteralPath $tmp -Destination $Path -Force
}

function Read-RunState {
    param([Parameter(Mandatory)] [string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    $raw = Get-Content -LiteralPath $Path -Raw
    return ($raw | ConvertFrom-Json -AsHashtable)
}

function Lock-RunState {
    param([Parameter(Mandatory)] [string]$Path)
    $lock = "$Path.lock"
    if (Test-Path -LiteralPath $lock) {
        $age = (Get-Date) - (Get-Item -LiteralPath $lock).LastWriteTime
        if ($age.TotalSeconds -lt 60) {
            throw "Concurrent run-workflow invocation suspected (advisory lock $lock < 60s old). Refusing to start."
        }
    }
    New-Item -ItemType File -Path $lock -Force | Out-Null
    return $lock
}

function Unlock-RunState {
    param([string]$LockPath)
    if ($LockPath -and (Test-Path -LiteralPath $LockPath)) { Remove-Item -LiteralPath $LockPath -Force }
}

function Initialize-RunState {
    param(
        [Parameter(Mandatory)] $Workflow,
        [Parameter(Mandatory)] [string]$Feature,
        [Parameter(Mandatory)] [hashtable]$Inputs
    )
    return [ordered]@{
        schema_version    = '1.0.0'
        run_id            = "{0:yyyyMMddHHmmss}-{1}" -f (Get-Date), [guid]::NewGuid().ToString('N').Substring(0, 6)
        workflow_id       = $Workflow.workflow.id
        workflow_version  = $Workflow.workflow.version
        feature           = $Feature
        status            = 'running'
        started_at        = Get-IsoTimestamp
        updated_at        = Get-IsoTimestamp
        current_step_id   = $null
        halt_reason       = $null
        halt_dispatch     = $null
        inputs            = $Inputs
        vars              = @{ steps = @{} }
        history           = @()
        gates             = @{}
        completed_steps   = @()
    }
}

function Get-ArtifactFingerprint {
    <#
    .SYNOPSIS
        Returns a content fingerprint used to prove an agent step actually produced work,
        rather than merely finding a file that a prep step scaffolded. Missing or empty
        artifacts return an empty hash so "scaffold -> agent edit" is always a detectable change.
    #>
    param([Parameter(Mandatory)] [string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [ordered]@{ exists = $false; empty = $true; hash = '' }
    }
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($bytes.Length -eq 0) {
        return [ordered]@{ exists = $true; empty = $true; hash = '' }
    }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = [System.BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '')
    } finally {
        $sha.Dispose()
    }
    return [ordered]@{ exists = $true; empty = $false; hash = $hash }
}

function Get-CanonicalTaskInventory {
    <#
    .SYNOPSIS
        Returns task IDs and checkbox state only for constitution-canonical task lines.

    .DESCRIPTION
        The exact accepted shape is:
        - [ ] T### [P#] [Risk: X] [Story: ...] Description

        Checked tasks may use x or X. Lines with a changed ID width, missing metadata,
        indentation, alternate bullet, or missing description are deliberately excluded so
        they cannot satisfy a persisted baseline inventory after Implement begins.
    #>
    param([Parameter(Mandatory)] [string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return }

    $content = [string](Get-Content -LiteralPath $Path -Raw)
    $pattern = [regex]'(?m)^- \[(?<checkbox>[ xX])\] (?<id>T\d{3}) \[P[1-3]\] \[Risk: (?:Low|Medium|High)\] \[Story: [^\]\r\n]+\] \S[^\r\n]*[ \t]*\r?$'
    foreach ($match in $pattern.Matches($content)) {
        [ordered]@{
            id      = $match.Groups['id'].Value
            checked = ($match.Groups['checkbox'].Value -in 'x', 'X')
        }
    }
}

function Resolve-StepPostconditionFilePath {
    param($Step, $RunState, [Parameter(Mandatory)] [string]$ProjectRoot)
    $fileRel = Resolve-Interpolation -Template ([string]$Step.postcondition.file) -Context $RunState
    $filePath = if ([System.IO.Path]::IsPathRooted($fileRel)) { $fileRel } else { Join-Path $ProjectRoot $fileRel }
    Assert-PathInsideRoot -Root $ProjectRoot -Candidate $filePath -MessagePrefix 'postcondition file escapes project root'
    return $filePath
}

function Initialize-StepPostconditionBaseline {
    <#
    .SYNOPSIS
        Persists evidence that a terminal postcondition must preserve across agent execution.
    #>
    param($Step, $RunState, [Parameter(Mandatory)] [string]$ProjectRoot)
    if (-not $Step.Contains('postcondition') -or -not $Step.postcondition) { return }
    if ([string]$Step.postcondition.type -ne 'no-pending-tasks') { return }

    $stepVars = $RunState.vars.steps[$Step.id]
    if ($stepVars.ContainsKey('baseline_task_ids')) { return }

    $filePath = Resolve-StepPostconditionFilePath -Step $Step -RunState $RunState -ProjectRoot $ProjectRoot
    $inventory = @(Get-CanonicalTaskInventory -Path $filePath)
    $stepVars['baseline_task_ids'] = @($inventory | ForEach-Object { [string]$_.id } | Sort-Object -Unique)
    $RunState.vars.steps[$Step.id] = $stepVars
}

function Test-StepPostcondition {
    <#
    .SYNOPSIS
        Evaluates a declarative step postcondition. Returns $null when satisfied, otherwise a
        human-readable failure reason. Artifact change detection proves the agent did work;
        the postcondition proves the work is actually finished (e.g. a terminal implement
        step is complete only when every baseline canonical task ID remains canonical and
        checked).
    #>
    param($Step, $RunState, [Parameter(Mandatory)] [string]$ProjectRoot)
    if (-not $Step.Contains('postcondition') -or -not $Step.postcondition) { return $null }
    $pc = $Step.postcondition
    $pcType = [string]$pc.type
    $filePath = Resolve-StepPostconditionFilePath -Step $Step -RunState $RunState -ProjectRoot $ProjectRoot
    switch ($pcType) {
        'no-pending-tasks' {
            if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
                return "postcondition no-pending-tasks: file not found: $filePath"
            }

            $stepVars = $null
            if ($RunState.vars -and $RunState.vars.steps -and $RunState.vars.steps.ContainsKey($Step.id)) {
                $stepVars = $RunState.vars.steps[$Step.id]
            }
            if (-not $stepVars -or -not $stepVars.ContainsKey('baseline_task_ids')) {
                return 'postcondition no-pending-tasks: baseline canonical task inventory is missing from RunState; restart the run'
            }

            $baselineIds = @($stepVars['baseline_task_ids'] | ForEach-Object { [string]$_ })
            if ($baselineIds.Count -eq 0) {
                return 'postcondition no-pending-tasks: baseline canonical task inventory is empty; restart with a valid tasks.md'
            }
            if (@($baselineIds | Where-Object { $_ -notmatch '^T\d{3}$' }).Count -gt 0 -or
                @($baselineIds | Sort-Object -Unique).Count -ne $baselineIds.Count) {
                return 'postcondition no-pending-tasks: baseline canonical task inventory in RunState is invalid; restart the run'
            }

            $currentInventory = @(Get-CanonicalTaskInventory -Path $filePath)
            $missingIds = @()
            $duplicateIds = @()
            $uncheckedIds = @()
            foreach ($taskId in $baselineIds) {
                $matchesForId = @($currentInventory | Where-Object { [string]$_.id -eq $taskId })
                if ($matchesForId.Count -eq 0) {
                    $missingIds += $taskId
                } elseif ($matchesForId.Count -gt 1) {
                    $duplicateIds += $taskId
                } elseif (-not [bool]$matchesForId[0].checked) {
                    $uncheckedIds += $taskId
                }
            }
            if ($missingIds.Count -gt 0) {
                return "postcondition no-pending-tasks: baseline task ID(s) missing or non-canonical: $($missingIds -join ', ')"
            }
            if ($duplicateIds.Count -gt 0) {
                return "postcondition no-pending-tasks: baseline task ID(s) appear more than once: $($duplicateIds -join ', ')"
            }
            if ($uncheckedIds.Count -gt 0) {
                return "postcondition no-pending-tasks: baseline task ID(s) remain unchecked: $($uncheckedIds -join ', ')"
            }

            $otherUncheckedIds = @($currentInventory | Where-Object { -not [bool]$_.checked } | ForEach-Object { [string]$_.id } | Sort-Object -Unique)
            if ($otherUncheckedIds.Count -gt 0) {
                return "postcondition no-pending-tasks: canonical task ID(s) added after baseline remain unchecked: $($otherUncheckedIds -join ', ')"
            }

            return $null
        }
        default { return "unknown postcondition type: $pcType" }
    }
}

function Invoke-ArtifactExtraction {
    <#
    .SYNOPSIS
        Populates RunState.vars.<name> from fields in a completed agent step's artifact so
        downstream switch subjects (e.g. readiness_primary_status) can route. Reuses the shared
        Get-MarkdownField parser and only accepts a single resolved enum token; an unfilled
        template placeholder (e.g. "A | B | C") fails validation and leaves the var unset, so the
        switch safely falls back to its default.
    #>
    param($Step, $RunState, [Parameter(Mandatory)] [string]$ArtifactPath)
    if (-not $Step.Contains('extract')) { return }
    if (-not (Test-Path -LiteralPath $ArtifactPath -PathType Leaf)) { return }
    $content = Get-Content -LiteralPath $ArtifactPath -Raw
    foreach ($rule in $Step.extract) {
        $var = [string]$rule.var
        $field = [string]$rule.field
        if (-not $var -or -not $field) { continue }
        $value = Get-MarkdownField -Content $content -Field $field
        if ($null -eq $value) { continue }
        $value = ([string]$value).Trim()
        if ($value -match '^[A-Z][A-Z0-9_]*$') {
            $RunState.vars[$var] = $value
        }
    }
}

# ============================================================================
# Step dispatch (command/gate/if/switch) and engine loop
# ============================================================================

function Add-RunStateHistory {
    param($RunState, $Step, [string]$Outcome, [hashtable]$Extras = @{})
    $entry = [ordered]@{
        step_id    = $Step.id
        step_type  = $Step.type
        completed_at = Get-IsoTimestamp
        outcome    = $Outcome
    }
    foreach ($k in $Extras.Keys) { $entry[$k] = $Extras[$k] }
    $RunState.history += $entry
}

function Add-RunStateHistoryOnce {
    <#
    .SYNOPSIS
        Replay-safe history append: resume replays revisit already-decided steps on every
        invocation, so replay outcomes are recorded at most once per (step, outcome) to keep
        history from growing quadratically with the number of resumes.
    #>
    param($RunState, $Step, [string]$Outcome, [hashtable]$Extras = @{})
    $sid = [string]$Step.id
    foreach ($entry in @($RunState.history)) {
        if ([string]$entry.step_id -eq $sid -and [string]$entry.outcome -eq $Outcome) { return }
    }
    Add-RunStateHistory -RunState $RunState -Step $Step -Outcome $Outcome -Extras $Extras
}

function Test-TerminalCompletionValidation {
    <#
    .SYNOPSIS
        Re-runs a terminal agent step's explicitly configured entry gate before completion.

    .DESCRIPTION
        Returns $null only when the child process exits zero and emits one JSON object whose
        READY member is the Boolean true. Missing scripts, non-zero exits, empty output,
        malformed JSON, and non-Boolean READY values all fail closed. Terminal steps without
        an explicit completion_validation block retain their existing behavior.
    #>
    param(
        $Step,
        $RunState,
        [Parameter(Mandatory)] [string]$ProjectRoot,
        [Parameter(Mandatory)] [string]$WorkspaceRoot
    )

    if (-not $Step.Contains('completion_validation') -or -not $Step.completion_validation) {
        return $null
    }
    if (-not ($Step.Contains('terminal') -and [bool]$Step.terminal) -or [string]$Step.dispatch -ne 'agent') {
        return 'completion_validation is permitted only on a terminal agent command step'
    }

    $configuration = $Step.completion_validation
    $scriptRel = [string]$configuration.script
    $scriptPath = if ([System.IO.Path]::IsPathRooted($scriptRel)) { $scriptRel } else { Join-Path $WorkspaceRoot $scriptRel }
    Assert-PathInsideRoot -Root $WorkspaceRoot -Candidate $scriptPath -MessagePrefix 'completion validation script path escapes workspace root'
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        return "completion validation script not found: $scriptPath"
    }

    $argv = @()
    if ($configuration.Contains('args')) {
        $argv = @($configuration.args | ForEach-Object { Resolve-Interpolation -Template ([string]$_) -Context $RunState })
    }
    $stdout = @(& pwsh -NoProfile -WorkingDirectory $ProjectRoot -File $scriptPath @argv 2>&1)
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        return "terminal completion validation failed: script exited with code $exitCode"
    }

    $json = $stdout -join [Environment]::NewLine
    if ([string]::IsNullOrWhiteSpace($json)) {
        return 'terminal completion validation failed: script returned no machine-readable result'
    }

    try {
        $result = $json | ConvertFrom-Json -AsHashtable -ErrorAction Stop
    } catch {
        return "terminal completion validation failed: script returned invalid JSON: $($_.Exception.Message)"
    }
    if ($result -isnot [System.Collections.IDictionary] -or
        -not $result.Contains('READY') -or
        $result['READY'] -isnot [bool]) {
        return 'terminal completion validation failed: result is missing Boolean READY'
    }
    if (-not [bool]$result['READY']) {
        $details = @($result['BLOCKERS'] | ForEach-Object { [string]$_ } | Where-Object { $_ }) -join '; '
        if ($details) { return "terminal completion validation failed: $details" }
        return 'terminal completion validation failed: READY is false'
    }

    return $null
}

function Invoke-CommandStep {
    param(
        $Step,
        $RunState,
        [hashtable]$AgentActions = @{},
        [Parameter(Mandatory)] [string]$ProjectRoot,
        [Parameter(Mandatory)] [string]$WorkspaceRoot,
        [switch]$DryRun
    )
    $dispatch = [string]$Step.dispatch
    if ($dispatch -eq 'script') {
        $scriptRel = [string]$Step.script
        $scriptPath = if ([System.IO.Path]::IsPathRooted($scriptRel)) { $scriptRel } else { Join-Path $WorkspaceRoot $scriptRel }
        Assert-PathInsideRoot -Root $WorkspaceRoot -Candidate $scriptPath -MessagePrefix 'Step script path escapes workspace root'
        $argv = @()
        if ($Step.Contains('args')) { $argv = @($Step.args | ForEach-Object { Resolve-Interpolation -Template ([string]$_) -Context $RunState }) }
        if ($DryRun) {
            Add-RunStateHistory -RunState $RunState -Step $Step -Outcome 'dry-run-skipped' -Extras @{ script = $scriptPath; args = $argv }
            return @{ Status = 'success' }
        }
        $stdout = & pwsh -NoProfile -WorkingDirectory $ProjectRoot -File $scriptPath @argv 2>&1
        $exitCode = $LASTEXITCODE
        $expectedExit = if ($Step.Contains('expected_exit_code')) { [int]$Step.expected_exit_code } else { 0 }
        $captureJson = $false
        if ($Step.Contains('capture') -and $Step.capture -and $Step.capture.Contains('json')) { $captureJson = [bool]$Step.capture.json }
        $captured = $null
        if ($captureJson -and $stdout) {
            try { $captured = ($stdout -join "`n") | ConvertFrom-Json -AsHashtable } catch { $captured = $null }
        }
        if ($null -ne $captured) {
            if (-not $RunState.vars.steps.ContainsKey($Step.id)) { $RunState.vars.steps[$Step.id] = @{} }
            $RunState.vars.steps[$Step.id].json = $captured
        }
        $outcome = if ($exitCode -eq $expectedExit) { 'success' } else { 'failed' }
        Add-RunStateHistory -RunState $RunState -Step $Step -Outcome $outcome -Extras @{ exit_code = $exitCode; expected_exit_code = $expectedExit }
        if ($outcome -ne 'success') {
            return @{ Status = 'failed'; ExitCode = $exitCode; Stdout = ($stdout -join "`n") }
        }
        return @{ Status = 'success' }
    }
    elseif ($dispatch -eq 'agent') {
        $agentCommand = [string]$Step.agent_command
        $expected = Resolve-Interpolation -Template ([string]$Step.expected_artifact) -Context $RunState
        $artifactPath = if ([System.IO.Path]::IsPathRooted($expected)) { $expected } else { Join-Path $ProjectRoot $expected }
        Assert-PathInsideRoot -Root $ProjectRoot -Candidate $artifactPath -MessagePrefix 'expected_artifact escapes project root'

        if ($DryRun) {
            Add-RunStateHistory -RunState $RunState -Step $Step -Outcome 'dry-run-skipped' -Extras @{ artifact = $artifactPath }
            return @{ Status = 'success' }
        }

        if (-not $RunState.vars.steps.ContainsKey($Step.id)) { $RunState.vars.steps[$Step.id] = @{} }
        $stepVars = $RunState.vars.steps[$Step.id]
        $current = Get-ArtifactFingerprint -Path $artifactPath
        $terminal = ($Step.Contains('terminal') -and [bool]$Step.terminal)
        $acceptRequested = ($AgentActions.ContainsKey($Step.id) -and $AgentActions[$Step.id] -eq 'accept')
        # A terminal step's completion must come from real artifact state, never from the
        # generic operator override.
        $accepted = ($acceptRequested -and -not $terminal)
        $postconditionFailure = $null
        $completionValidationFailure = $null

        # First arrival this run: record the pre-agent baseline (scaffold or prior-stage state) and
        # halt. Mere existence of a scaffolded artifact is NOT completion; the agent must change it.
        if (-not $stepVars.ContainsKey('agent_baseline')) {
            if ($terminal) {
                Initialize-StepPostconditionBaseline -Step $Step -RunState $RunState -ProjectRoot $ProjectRoot
            }
            $stepVars['agent_baseline'] = $current.hash
            $RunState.vars.steps[$Step.id] = $stepVars
        } else {
            $baseline = [string]$stepVars['agent_baseline']
            $changed = ($current.exists -and -not $current.empty -and ($current.hash -ne $baseline))
            # A terminal step with a declared postcondition may also complete WITHOUT an
            # artifact change: the postcondition itself is the completion proof (e.g. all
            # tasks were already checked off before the run reached this step). Without
            # this, an already-satisfied terminal step would be permanently locked out.
            $hasPostcondition = ($Step.Contains('postcondition') -and $Step.postcondition)
            $completionCandidate = $changed -or
                ($accepted -and $current.exists -and -not $current.empty) -or
                ($terminal -and $hasPostcondition -and $current.exists -and -not $current.empty)
            if ($completionCandidate) {
                $postconditionFailure = Test-StepPostcondition -Step $Step -RunState $RunState -ProjectRoot $ProjectRoot
                if ($null -eq $postconditionFailure) {
                    $completionValidationFailure = Test-TerminalCompletionValidation -Step $Step -RunState $RunState -ProjectRoot $ProjectRoot -WorkspaceRoot $WorkspaceRoot
                    if ($null -eq $completionValidationFailure) {
                        Invoke-ArtifactExtraction -Step $Step -RunState $RunState -ArtifactPath $artifactPath
                        $outcome = if ($changed) { 'success' } elseif ($accepted) { 'success-accepted' } else { 'success-postcondition' }
                        Add-RunStateHistory -RunState $RunState -Step $Step -Outcome $outcome -Extras @{ artifact = $artifactPath }
                        return @{ Status = 'success' }
                    }
                }
            }
        }

        $reason = if ($acceptRequested -and $terminal) {
            $suffix = if ($postconditionFailure) { "; $postconditionFailure" } else { '' }
            "-AcceptAgent is disabled for terminal step $($Step.id); completion requires the real artifact postcondition$suffix"
        } elseif ($postconditionFailure) {
            $postconditionFailure
        } elseif ($completionValidationFailure) {
            $completionValidationFailure
        } elseif ($accepted) {
            "artifact missing or empty; cannot accept: $artifactPath"
        } else {
            "artifact unchanged since prep; run the agent to produce real content"
        }
        $msg = if ($Step.Contains('operator_message')) { Resolve-Interpolation -Template ([string]$Step.operator_message) -Context $RunState } else { "Run $agentCommand in your agent IDE, then re-run with -Resume." }
        $RunState.status = 'awaiting_agent'
        $RunState.current_step_id = $Step.id
        $RunState.halt_reason = "Awaiting agent step: $($Step.id) ($reason)"
        $RunState.halt_dispatch = [ordered]@{
            type = 'agent'
            agent_command = $agentCommand
            expected_artifact = $artifactPath
            operator_instructions = $msg
        }
        return @{ Status = 'awaiting_agent' }
    }
    else {
        throw "Unsupported dispatch: $dispatch (step $($Step.id))"
    }
}

function Invoke-GateStep {
    param($Step, $RunState, [hashtable]$GateActions, [hashtable]$AgentActions = @{}, [Parameter(Mandatory)] [string]$ProjectRoot, [Parameter(Mandatory)] [string]$WorkspaceRoot, [switch]$DryRun)
    $gateId = [string]$Step.id
    $existing = $null
    if ($RunState.gates.ContainsKey($gateId)) { $existing = $RunState.gates[$gateId] }

    # Replay of an already-decided gate short-circuits before any new decision is consumed.
    if ($existing -and $existing.status -in 'confirmed', 'rejected') {
        Add-RunStateHistoryOnce -RunState $RunState -Step $Step -Outcome ("gate-" + $existing.status) -Extras @{}
        if ($existing.status -eq 'rejected' -and $Step.Contains('on_reject') -and $Step.on_reject) {
            return Invoke-StepList -Steps $Step.on_reject -RunState $RunState -GateActions $GateActions -AgentActions $AgentActions -ProjectRoot $ProjectRoot -WorkspaceRoot $WorkspaceRoot -DryRun:$DryRun
        }
        return @{ Status = 'success' }
    }

    # Fail-closed decision scope: an operator decision applies only to a gate this run has
    # actually halted on (status=pending). A decision pre-supplied for a gate that has not
    # halted yet is ignored, and the gate halts as usual.
    $action = $null
    if ($GateActions.ContainsKey($gateId) -and $existing -and $existing.status -eq 'pending') {
        $action = $GateActions[$gateId]
    }
    if ($action -eq 'confirm') {
        $RunState.gates[$gateId] = [ordered]@{ status = 'confirmed'; decided_at = Get-IsoTimestamp; decided_by = 'operator' }
        Add-RunStateHistory -RunState $RunState -Step $Step -Outcome 'gate-confirmed'
        return @{ Status = 'success' }
    }
    elseif ($action -eq 'reject') {
        $RunState.gates[$gateId] = [ordered]@{ status = 'rejected'; decided_at = Get-IsoTimestamp; decided_by = 'operator' }
        Add-RunStateHistory -RunState $RunState -Step $Step -Outcome 'gate-rejected'
        if ($Step.Contains('on_reject') -and $Step.on_reject) {
            return Invoke-StepList -Steps $Step.on_reject -RunState $RunState -GateActions $GateActions -AgentActions $AgentActions -ProjectRoot $ProjectRoot -WorkspaceRoot $WorkspaceRoot -DryRun:$DryRun
        }
        # No on_reject branch: an operator rejection is a terminal outcome for this run,
        # never a silent pass-through to the remaining steps.
        $RunState.status = 'rejected'
        $RunState.current_step_id = $gateId
        $RunState.halt_reason = "Gate rejected with no on_reject branch: $gateId"
        $RunState.halt_dispatch = $null
        return @{ Status = 'rejected' }
    }
    $RunState.gates[$gateId] = [ordered]@{ status = 'pending'; decided_at = $null; decided_by = $null }
    $prompt = if ($Step.Contains('prompt')) { Resolve-Interpolation -Template ([string]$Step.prompt) -Context $RunState } else { 'Approve?' }
    $RunState.status = 'awaiting_gate'
    $RunState.current_step_id = $gateId
    $RunState.halt_reason = "Awaiting gate: $gateId"
    $RunState.halt_dispatch = [ordered]@{ type = 'gate'; gate_id = $gateId; prompt = $prompt; operator_instructions = "Resume with -ConfirmGate $gateId or -RejectGate $gateId" }
    return @{ Status = 'awaiting_gate' }
}

function Invoke-IfStep {
    param($Step, $RunState, [hashtable]$GateActions, [hashtable]$AgentActions = @{}, [Parameter(Mandatory)] [string]$ProjectRoot, [Parameter(Mandatory)] [string]$WorkspaceRoot, [switch]$DryRun)
    $cond = Test-WorkflowCondition -Expression ([string]$Step.condition) -Context $RunState
    if ($cond) {
        Add-RunStateHistoryOnce -RunState $RunState -Step $Step -Outcome 'branched-then'
        return Invoke-StepList -Steps $Step.then -RunState $RunState -GateActions $GateActions -AgentActions $AgentActions -ProjectRoot $ProjectRoot -WorkspaceRoot $WorkspaceRoot -DryRun:$DryRun
    }
    Add-RunStateHistoryOnce -RunState $RunState -Step $Step -Outcome 'branched-else'
    if ($Step.Contains('else') -and $Step.else) {
        return Invoke-StepList -Steps $Step.else -RunState $RunState -GateActions $GateActions -AgentActions $AgentActions -ProjectRoot $ProjectRoot -WorkspaceRoot $WorkspaceRoot -DryRun:$DryRun
    }
    return @{ Status = 'success' }
}

function Invoke-SwitchStep {
    param($Step, $RunState, [hashtable]$GateActions, [hashtable]$AgentActions = @{}, [Parameter(Mandatory)] [string]$ProjectRoot, [Parameter(Mandatory)] [string]$WorkspaceRoot, [switch]$DryRun)
    $subjectValue = (Resolve-Interpolation -Template ([string]$Step.subject) -Context $RunState).Trim()
    $subList = $null
    $matched = $null
    foreach ($caseKey in $Step.cases.Keys) {
        if ([string]$caseKey -eq $subjectValue) {
            $matched = [string]$caseKey
            $subList = $Step.cases[$caseKey]
            break
        }
    }
    if (-not $subList -and $Step.Contains('default') -and $Step.default) {
        $matched = '<default>'
        $subList = $Step.default
    }
    if (-not $subList) {
        Add-RunStateHistoryOnce -RunState $RunState -Step $Step -Outcome "no-match:$subjectValue"
        return @{ Status = 'success' }
    }
    Add-RunStateHistoryOnce -RunState $RunState -Step $Step -Outcome "matched-case:$matched" -Extras @{ subject = $subjectValue }
    return Invoke-StepList -Steps $subList -RunState $RunState -GateActions $GateActions -AgentActions $AgentActions -ProjectRoot $ProjectRoot -WorkspaceRoot $WorkspaceRoot -DryRun:$DryRun
}

function Invoke-NotImplementedStep {
    param($Step, $RunState)
    Add-RunStateHistory -RunState $RunState -Step $Step -Outcome 'step-type-not-implemented'
    throw "Step type '$($Step.type)' is not implemented in Wave 3 (step $($Step.id))"
}

function Invoke-Step {
    param($Step, $RunState, [hashtable]$GateActions, [hashtable]$AgentActions = @{}, [Parameter(Mandatory)] [string]$ProjectRoot, [Parameter(Mandatory)] [string]$WorkspaceRoot, [switch]$DryRun)
    $sid = [string]$Step.id
    # Resume idempotency: a command step (script or agent) that already succeeded is not re-run.
    # This prevents a resume from re-scaffolding / overwriting agent-authored artifacts and defeats
    # the "prep re-creates the expected artifact" false-completion path. if/switch re-route and
    # gates are idempotent on their own, so only command steps are skipped here.
    if (($sid) -and ([string]$Step.type -eq 'command') -and (@($RunState.completed_steps) -contains $sid)) {
        Add-RunStateHistoryOnce -RunState $RunState -Step $Step -Outcome 'skipped-completed'
        return @{ Status = 'success' }
    }
    $RunState.current_step_id = $sid
    switch ([string]$Step.type) {
        'command' {
            $r = Invoke-CommandStep -Step $Step -RunState $RunState -AgentActions $AgentActions -ProjectRoot $ProjectRoot -WorkspaceRoot $WorkspaceRoot -DryRun:$DryRun
            if ($r.Status -eq 'success' -and (@($RunState.completed_steps) -notcontains $sid)) { $RunState.completed_steps += $sid }
            return $r
        }
        'gate'    { return Invoke-GateStep    -Step $Step -RunState $RunState -GateActions $GateActions -AgentActions $AgentActions -ProjectRoot $ProjectRoot -WorkspaceRoot $WorkspaceRoot -DryRun:$DryRun }
        'if'      { return Invoke-IfStep      -Step $Step -RunState $RunState -GateActions $GateActions -AgentActions $AgentActions -ProjectRoot $ProjectRoot -WorkspaceRoot $WorkspaceRoot -DryRun:$DryRun }
        'switch'  { return Invoke-SwitchStep  -Step $Step -RunState $RunState -GateActions $GateActions -AgentActions $AgentActions -ProjectRoot $ProjectRoot -WorkspaceRoot $WorkspaceRoot -DryRun:$DryRun }
        default   { return Invoke-NotImplementedStep -Step $Step -RunState $RunState }
    }
}

function Get-WorkflowStepIds {
    param($Steps)
    $ids = @()
    foreach ($step in @($Steps)) {
        if ($null -eq $step) { continue }
        if ($step.Contains('id') -and $step.id) { $ids += [string]$step.id }
        foreach ($branchKey in 'then', 'else', 'on_reject', 'default') {
            if ($step.Contains($branchKey) -and $step[$branchKey]) {
                $ids += @(Get-WorkflowStepIds -Steps $step[$branchKey])
            }
        }
        if ($step.Contains('cases') -and $step.cases) {
            foreach ($caseKey in $step.cases.Keys) {
                $ids += @(Get-WorkflowStepIds -Steps $step.cases[$caseKey])
            }
        }
    }
    return $ids
}

function Invoke-StepList {
    param($Steps, $RunState, [hashtable]$GateActions, [hashtable]$AgentActions = @{}, [Parameter(Mandatory)] [string]$ProjectRoot, [Parameter(Mandatory)] [string]$WorkspaceRoot, [switch]$DryRun)
    foreach ($step in $Steps) {
        $r = Invoke-Step -Step $step -RunState $RunState -GateActions $GateActions -AgentActions $AgentActions -ProjectRoot $ProjectRoot -WorkspaceRoot $WorkspaceRoot -DryRun:$DryRun
        if ($r.Status -in 'awaiting_agent', 'awaiting_gate', 'rejected', 'failed') { return $r }
    }
    return @{ Status = 'success' }
}

function Invoke-Workflow {
    <#
    .SYNOPSIS
        Engine entry point. Parses workflow, validates, initializes or
        resumes RunState, runs the state machine, persists state on exit.
    #>
    param(
        [Parameter(Mandatory)] [string]$WorkflowYamlPath,
        [Parameter(Mandatory)] [string]$Feature,
        [Parameter(Mandatory)] [string]$ProjectRoot,
        [Parameter(Mandatory)] [string]$WorkspaceRoot,
        [hashtable]$Inputs = @{},
        [hashtable]$GateActions = @{},
        [hashtable]$AgentActions = @{},
        [string]$ExpectedWorkflowId,
        [string]$ExpectedWorkflowVersion,
        [switch]$Resume,
        [switch]$Restart,
        [switch]$DryRun
    )
    if ($Resume -and $Restart) { throw 'Use either -Resume or -Restart, not both.' }
    $schemaPath = Join-Path $WorkspaceRoot 'studio/workflows/manifest.schema.json'
    $workflow = Read-WorkflowYaml -Path $WorkflowYamlPath
    [void](Test-WorkflowSchema -Document $workflow -SchemaPath $schemaPath)

    # Bind the EXECUTED document to the authorized identity: catalog/state/manifest checks
    # in the runner authorize an id and version, and the workflow.yml actually run must
    # declare that same identity, or a swapped file executes ungoverned content.
    if ($ExpectedWorkflowId -and [string]$workflow.workflow.id -ne $ExpectedWorkflowId) {
        throw "Workflow identity mismatch: workflow.yml declares id '$($workflow.workflow.id)' but the authorized id is '$ExpectedWorkflowId'."
    }
    if ($ExpectedWorkflowVersion -and [string]$workflow.workflow.version -ne $ExpectedWorkflowVersion) {
        throw "Workflow identity mismatch: workflow.yml declares version '$($workflow.workflow.version)' but the catalog authorizes version '$ExpectedWorkflowVersion'."
    }

    $statePath = Get-RunStatePath -ProjectRoot $ProjectRoot -Feature $Feature
    # DryRun must never pollute the real RunState: it may read the persisted state for a
    # -Resume preview, but it saves to a sidecar file that a real resume never consumes.
    $resumeReadPath = $statePath
    if ($DryRun) { $statePath = $statePath -replace 'state\.json$', 'state.dryrun.json' }

    $duplicateStepIds = @(Get-WorkflowStepIds -Steps $workflow.steps | Group-Object | Where-Object { $_.Count -gt 1 })
    if ($duplicateStepIds.Count -gt 0) {
        throw "Duplicate step id(s) in workflow: $(@($duplicateStepIds | ForEach-Object { $_.Name }) -join ', ')"
    }

    # The run feature is validated and anchors the RunState path; an operator input must
    # not rebind it to a second feature context, on fresh runs or resumes.
    if ($Inputs.ContainsKey('feature') -and [string]$Inputs['feature'] -ne [string]$Feature) {
        throw "Operator inputs may not override 'feature' (run feature: $Feature, input: $($Inputs['feature']))."
    }

    $lock = $null
    try {
        $lock = Lock-RunState -Path $statePath
        $runState = $null
        if ($Resume) {
            $runState = Read-RunState -Path $resumeReadPath
            if (-not $runState) { throw "No RunState to resume at $resumeReadPath" }
            if ($runState.workflow_id -ne [string]$workflow.workflow.id) {
                throw "Resume mismatch: state workflow_id=$($runState.workflow_id), requested=$($workflow.workflow.id)"
            }
            if ($runState.status -in 'completed', 'failed', 'rejected') {
                throw "Cannot resume a $($runState.status) run. Use -Restart to archive the RunState and start over."
            }
            # Persisted inputs feed step templating; a saved state must not rebind the
            # resumed run to a feature other than the one anchoring this RunState path.
            $stateFeature = if ($runState.ContainsKey('inputs') -and $runState.inputs -and $runState.inputs.ContainsKey('feature')) { [string]$runState.inputs.feature } else { $null }
            if ($stateFeature -and $stateFeature -ne [string]$Feature) {
                throw "Resume mismatch: state inputs.feature=$stateFeature, requested=$Feature"
            }
            if (-not $stateFeature) {
                if (-not $runState.ContainsKey('inputs') -or -not $runState.inputs) { $runState.inputs = @{} }
                $runState.inputs.feature = $Feature
            }
            $runState.status = 'running'
            $runState.halt_reason = $null
            $runState.halt_dispatch = $null
            if (-not $runState.ContainsKey('completed_steps') -or $null -eq $runState.completed_steps) {
                $runState.completed_steps = @()
            }
        } else {
            # A leftover RunState (completed, failed, rejected, or in-flight) is never
            # silently overwritten: continuing requires -Resume, starting over requires
            # -Restart, which archives the previous state next to the live path.
            if (-not $DryRun -and (Test-Path -LiteralPath $resumeReadPath -PathType Leaf)) {
                if ($Restart) {
                    $archiveStamp = (Get-Date).ToString('yyyyMMddHHmmss')
                    Move-Item -LiteralPath $resumeReadPath -Destination "$resumeReadPath.$archiveStamp.restarted.json" -Force
                } else {
                    throw "RunState already exists for feature '$Feature' at $resumeReadPath. Use -Resume to continue or -Restart to archive it and start over."
                }
            }
            $effectiveInputs = @{ feature = $Feature }
            foreach ($k in $Inputs.Keys) {
                if ($k -eq 'feature') { continue }
                $effectiveInputs[$k] = $Inputs[$k]
            }
            $runState = Initialize-RunState -Workflow $workflow -Feature $Feature -Inputs $effectiveInputs
        }

        $r = Invoke-StepList -Steps $workflow.steps -RunState $runState -GateActions $GateActions -AgentActions $AgentActions -ProjectRoot $ProjectRoot -WorkspaceRoot $WorkspaceRoot -DryRun:$DryRun
        if ($r.Status -eq 'awaiting_agent') {
            Save-RunState -RunState $runState -Path $statePath
            return [ordered]@{ Status = 'awaiting_agent'; ExitCode = 42; RunStatePath = $statePath; HaltDispatch = $runState.halt_dispatch }
        }
        if ($r.Status -eq 'awaiting_gate') {
            Save-RunState -RunState $runState -Path $statePath
            return [ordered]@{ Status = 'awaiting_gate'; ExitCode = 43; RunStatePath = $statePath; HaltDispatch = $runState.halt_dispatch }
        }
        if ($r.Status -eq 'rejected') {
            Save-RunState -RunState $runState -Path $statePath
            return [ordered]@{ Status = 'rejected'; ExitCode = 44; RunStatePath = $statePath }
        }
        if ($r.Status -eq 'failed') {
            $runState.status = 'failed'
            Save-RunState -RunState $runState -Path $statePath
            return [ordered]@{ Status = 'failed'; ExitCode = 1; RunStatePath = $statePath; Error = $r }
        }
        $runState.status = 'completed'
        $runState.current_step_id = $null
        Save-RunState -RunState $runState -Path $statePath
        return [ordered]@{ Status = 'completed'; ExitCode = 0; RunStatePath = $statePath }
    } finally {
        Unlock-RunState -LockPath $lock
    }
}
