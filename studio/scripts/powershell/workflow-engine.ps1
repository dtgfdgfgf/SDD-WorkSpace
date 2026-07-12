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

    RunState lives at specs/<feature>/.workflow/state.json (atomic write via
    .tmp + Move-Item -Force, plus a 60-second advisory lock at state.json.lock).

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
    $stateDir = Join-Path (Join-Path (Join-Path $ProjectRoot 'specs') $Feature) '.workflow'
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
        $stdout = & pwsh -NoProfile -File $scriptPath @argv 2>&1
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
        $accepted = ($AgentActions.ContainsKey($Step.id) -and $AgentActions[$Step.id] -eq 'accept')

        # First arrival this run: record the pre-agent baseline (scaffold or prior-stage state) and
        # halt. Mere existence of a scaffolded artifact is NOT completion; the agent must change it.
        if (-not $stepVars.ContainsKey('agent_baseline')) {
            $stepVars['agent_baseline'] = $current.hash
            $RunState.vars.steps[$Step.id] = $stepVars
        } else {
            $baseline = [string]$stepVars['agent_baseline']
            $changed = ($current.exists -and -not $current.empty -and ($current.hash -ne $baseline))
            if ($changed -or ($accepted -and $current.exists -and -not $current.empty)) {
                Invoke-ArtifactExtraction -Step $Step -RunState $RunState -ArtifactPath $artifactPath
                $outcome = if ($changed) { 'success' } else { 'success-accepted' }
                Add-RunStateHistory -RunState $RunState -Step $Step -Outcome $outcome -Extras @{ artifact = $artifactPath }
                return @{ Status = 'success' }
            }
        }

        $reason = if ($accepted) { "artifact missing or empty; cannot accept: $artifactPath" } else { "artifact unchanged since prep; run the agent to produce real content" }
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
    $action = if ($GateActions.ContainsKey($gateId)) { $GateActions[$gateId] } else { $null }
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
        return @{ Status = 'success' }
    }
    if ($existing -and $existing.status -in 'confirmed', 'rejected') {
        Add-RunStateHistory -RunState $RunState -Step $Step -Outcome ("gate-" + $existing.status) -Extras @{}
        if ($existing.status -eq 'rejected' -and $Step.Contains('on_reject') -and $Step.on_reject) {
            return Invoke-StepList -Steps $Step.on_reject -RunState $RunState -GateActions $GateActions -AgentActions $AgentActions -ProjectRoot $ProjectRoot -WorkspaceRoot $WorkspaceRoot -DryRun:$DryRun
        }
        return @{ Status = 'success' }
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
        Add-RunStateHistory -RunState $RunState -Step $Step -Outcome 'branched-then'
        return Invoke-StepList -Steps $Step.then -RunState $RunState -GateActions $GateActions -AgentActions $AgentActions -ProjectRoot $ProjectRoot -WorkspaceRoot $WorkspaceRoot -DryRun:$DryRun
    }
    Add-RunStateHistory -RunState $RunState -Step $Step -Outcome 'branched-else'
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
        Add-RunStateHistory -RunState $RunState -Step $Step -Outcome "no-match:$subjectValue"
        return @{ Status = 'success' }
    }
    Add-RunStateHistory -RunState $RunState -Step $Step -Outcome "matched-case:$matched" -Extras @{ subject = $subjectValue }
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
        Add-RunStateHistory -RunState $RunState -Step $Step -Outcome 'skipped-completed'
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

function Invoke-StepList {
    param($Steps, $RunState, [hashtable]$GateActions, [hashtable]$AgentActions = @{}, [Parameter(Mandatory)] [string]$ProjectRoot, [Parameter(Mandatory)] [string]$WorkspaceRoot, [switch]$DryRun)
    foreach ($step in $Steps) {
        $r = Invoke-Step -Step $step -RunState $RunState -GateActions $GateActions -AgentActions $AgentActions -ProjectRoot $ProjectRoot -WorkspaceRoot $WorkspaceRoot -DryRun:$DryRun
        if ($r.Status -in 'awaiting_agent', 'awaiting_gate', 'failed') { return $r }
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
        [switch]$Resume,
        [switch]$DryRun
    )
    $schemaPath = Join-Path $WorkspaceRoot 'studio/workflows/manifest.schema.json'
    $workflow = Read-WorkflowYaml -Path $WorkflowYamlPath
    [void](Test-WorkflowSchema -Document $workflow -SchemaPath $schemaPath)

    $statePath = Get-RunStatePath -ProjectRoot $ProjectRoot -Feature $Feature
    $lock = $null
    try {
        $lock = Lock-RunState -Path $statePath
        $runState = $null
        if ($Resume) {
            $runState = Read-RunState -Path $statePath
            if (-not $runState) { throw "No RunState to resume at $statePath" }
            if ($runState.workflow_id -ne [string]$workflow.workflow.id) {
                throw "Resume mismatch: state workflow_id=$($runState.workflow_id), requested=$($workflow.workflow.id)"
            }
            if ($runState.status -in 'completed', 'failed') {
                throw "Cannot resume a $($runState.status) run."
            }
            $runState.status = 'running'
            $runState.halt_reason = $null
            $runState.halt_dispatch = $null
            if (-not $runState.ContainsKey('completed_steps') -or $null -eq $runState.completed_steps) {
                $runState.completed_steps = @()
            }
        } else {
            $effectiveInputs = @{ feature = $Feature }
            foreach ($k in $Inputs.Keys) { $effectiveInputs[$k] = $Inputs[$k] }
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
