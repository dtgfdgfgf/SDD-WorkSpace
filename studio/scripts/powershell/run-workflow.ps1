#!/usr/bin/env pwsh

#Requires -Version 7.0
<#
.SYNOPSIS
    Drive a studio workflow end-to-end: start, halt at gates / agent steps,
    resume after the operator does the LLM-side work.

.DESCRIPTION
    Authorizes the workflow against catalog.json / state.json / manifest.json
    (fail-closed), resolves the catalog sourcePath workflow.yml, parses +
    validates against manifest.schema.json, initializes or resumes RunState at
    <project>/.workflow/runs/<feature>/state.json (local transient, ignored by Git),
    and runs the state machine via the workflow-engine.ps1 dispatcher.

    Exit codes:
        0  completed
        1  failed (script step, schema, or authorization denied)
        42 awaiting_agent (operator action required)
        43 awaiting_gate (-ConfirmGate / -RejectGate required)
        44 rejected (gate rejected with no on_reject branch; recover with -Restart)

.PARAMETER Id
    Workflow id (resolves through the authorized catalog sourcePath).

.PARAMETER Feature
    Feature id (e.g. 001-foo). RunState lives at <project>/.workflow/runs/<Feature>/state.json.

.PARAMETER Resume
    Resume an existing run. Reuses workflow_id from RunState (must match -Id).

.PARAMETER Restart
    Archive an existing RunState (timestamped .restarted.json) and start the run
    over. Required to re-run a completed, failed, or rejected run, and to start
    over an in-flight run.

.PARAMETER ConfirmGate
    Approve a halted gate. The next run advances past it.

.PARAMETER RejectGate
    Decline a halted gate. The next run executes its on_reject branch when the
    gate declares one; otherwise the run terminates as rejected (exit 44).

.PARAMETER Inputs
    Optional hashtable of additional inputs (key=value pairs as a
    semicolon-separated string, e.g. "scope=full;owner=studio").

.PARAMETER DryRun
    Do not invoke any dispatched script and skip side effects.

.PARAMETER Json
    Emit a structured JSON result.

.PARAMETER Help
    Show this help message.
#>

[CmdletBinding()]
param(
    [string]$Id,
    [string]$Feature,
    [switch]$Resume,
    [switch]$Restart,
    [string]$ConfirmGate,
    [string]$RejectGate,
    [string]$AcceptAgent,
    [string]$Inputs,
    [switch]$DryRun,
    [switch]$Json,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'

if ($Help) {
    Write-Output 'Usage: ./run-workflow.ps1 -Id <workflow-id> -Feature <feature> [-Resume] [-Restart] [-ConfirmGate <id>] [-RejectGate <id>] [-AcceptAgent <id>] [-Inputs "k=v;k=v"] [-DryRun] [-Json] [-Help]'
    Write-Output '  -Restart           Archive an existing RunState (state.json.restarted.json) and start the run over. Required to re-run a completed, failed, or rejected run.'
    Write-Output '  -AcceptAgent <id>  Accept the current artifact of a halted agent step as its output (use when the artifact was already produced and change-detection would otherwise loop).'
    exit 0
}

. "$PSScriptRoot/common.ps1"
. "$PSScriptRoot/workflow-engine.ps1"

if (-not $Id -or -not $Feature) {
    Write-Error '-Id and -Feature are required. See -Help.'
    exit 1
}
if ($Id -notmatch '^[a-z0-9][a-z0-9-]{1,63}$') {
    Write-Error "Invalid workflow id: '$Id'"
    exit 1
}

$studioRoot = Find-StudioRoot -StartDir $PSScriptRoot
# WorkspaceRoot anchors the shared runtime surface (workflow schema and dispatchable
# scripts). It is derived from this script's real location on purpose: SDD_STUDIO_ROOT
# may redirect the governed workflows tree (catalog/state/workflow sources), but it must
# never relocate which scripts the engine is allowed to dispatch.
$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
if (-not $studioRoot -or -not $workspaceRoot) { throw 'Unable to resolve studio / workspace roots.' }
$projectRoot = Get-RepoRoot

function Deny-WorkflowRun {
    param([Parameter(Mandatory)] [string]$Message)
    if ($Json) {
        [PSCustomObject]@{ STATUS = 'denied'; EXIT_CODE = 1; ERROR = $Message } | ConvertTo-Json
    } else {
        Write-Error $Message
    }
    exit 1
}

# ---------------------------------------------------------------------------
# Runner authorization (fail-closed): catalog.json is the governance ledger and
# state.json is the enable/disable ledger. A workflow directory existing on disk
# is not, by itself, an authorization to execute it.
# ---------------------------------------------------------------------------
$registry = Get-WorkflowRegistrySnapshot -StudioRoot $studioRoot
# Manifest existence, JSON shape, id, and version are shared registry facts.
# "Workflow identity mismatch" is therefore denied here and by workflow listing alike.
$authorization = Get-WorkflowExecutionAuthorization -Registry $registry -Id $Id
if (-not $authorization.AUTHORIZED) {
    Deny-WorkflowRun -Message ("Workflow registry authorization denied: {0}" -f (@($authorization.ERRORS) -join ' '))
}
$catalogEntry = $authorization.ENTRY.CATALOG_ENTRY
$workflowYaml = [string]$authorization.ENTRY.WORKFLOW_PATH
if ([string]::IsNullOrWhiteSpace($workflowYaml)) {
    Deny-WorkflowRun -Message "Workflow registry authorization did not resolve workflow.yml for '$Id'."
}
try {
    Assert-PathInsideRoot `
        -Root (Join-Path $studioRoot 'workflows') `
        -Candidate $workflowYaml `
        -MessagePrefix 'workflow.yml escapes workflows root'
} catch {
    Deny-WorkflowRun -Message $_.Exception.Message
}

$inputHash = @{}
if ($Inputs) {
    foreach ($pair in $Inputs.Split(';')) {
        $kv = $pair.Split('=', 2)
        if ($kv.Count -eq 2) { $inputHash[$kv[0].Trim()] = $kv[1].Trim() }
    }
}
$gateActions = @{}
if ($ConfirmGate -and $RejectGate -and ($ConfirmGate -eq $RejectGate)) {
    Deny-WorkflowRun -Message "Contradictory gate decision: '$ConfirmGate' was both confirmed and rejected in one invocation."
}
if ($ConfirmGate) { $gateActions[$ConfirmGate] = 'confirm' }
if ($RejectGate)  { $gateActions[$RejectGate] = 'reject' }
$agentActions = @{}
if ($AcceptAgent) { $agentActions[$AcceptAgent] = 'accept' }

try {
    $result = Invoke-Workflow `
        -WorkflowYamlPath $workflowYaml `
        -ExpectedWorkflowId $Id `
        -ExpectedWorkflowVersion ([string]$catalogEntry.version) `
        -ExpectedWorkflowSha256 ([string]$authorization.ENTRY.WORKFLOW_SHA256) `
        -Feature $Feature `
        -ProjectRoot $projectRoot `
        -WorkspaceRoot $workspaceRoot `
        -Inputs $inputHash `
        -GateActions $gateActions `
        -AgentActions $agentActions `
        -Resume:$Resume `
        -Restart:$Restart `
        -DryRun:$DryRun
} catch {
    if ($Json) {
        [PSCustomObject]@{ STATUS = 'error'; EXIT_CODE = 1; ERROR = $_.Exception.Message } | ConvertTo-Json
    } else {
        Write-Error $_.Exception.Message
    }
    exit 1
}

$payload = [ordered]@{
    STATUS         = $result.Status
    EXIT_CODE      = $result.ExitCode
    RUN_STATE_PATH = $result.RunStatePath
    WORKFLOW_ID    = $Id
    FEATURE        = $Feature
}
if ($result.HaltDispatch) { $payload.HALT_DISPATCH = $result.HaltDispatch }
if ($result.Error) { $payload.ERROR = $result.Error }

if ($Json) {
    [PSCustomObject]$payload | ConvertTo-Json -Depth 15
} else {
    Write-Output ("STATUS: {0}" -f $result.Status)
    Write-Output ("EXIT_CODE: {0}" -f $result.ExitCode)
    Write-Output ("RUN_STATE_PATH: {0}" -f $result.RunStatePath)
    if ($result.HaltDispatch) {
        Write-Output 'HALT_DISPATCH:'
        $result.HaltDispatch | ConvertTo-Json | Write-Output
    }
    if ($result.Error) {
        Write-Output 'ERROR:'
        $result.Error | ConvertTo-Json | Write-Output
    }
}
exit $result.ExitCode
