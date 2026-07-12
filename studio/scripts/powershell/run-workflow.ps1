#!/usr/bin/env pwsh

#Requires -Version 7.0
<#
.SYNOPSIS
    Drive a studio workflow end-to-end: start, halt at gates / agent steps,
    resume after the operator does the LLM-side work.

.DESCRIPTION
    Resolves studio/workflows/<id>/workflow.yml, parses + validates against
    manifest.schema.json, initializes or resumes RunState at
    specs/<feature>/.workflow/state.json, and runs the state machine via the
    workflow-engine.ps1 dispatcher.

    Exit codes:
        0  completed
        1  failed (script step or schema)
        42 awaiting_agent (operator action required)
        43 awaiting_gate (-ConfirmGate / -RejectGate required)

.PARAMETER Id
    Workflow id (resolves to studio/workflows/<id>/workflow.yml).

.PARAMETER Feature
    Feature id (e.g. 001-foo). RunState lives at specs/<Feature>/.workflow/state.json.

.PARAMETER Resume
    Resume an existing run. Reuses workflow_id from RunState (must match -Id).

.PARAMETER ConfirmGate
    Approve a halted gate. The next run advances past it.

.PARAMETER RejectGate
    Decline a halted gate. The next run executes its on_reject branch.

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
    Write-Output 'Usage: ./run-workflow.ps1 -Id <workflow-id> -Feature <feature> [-Resume] [-ConfirmGate <id>] [-RejectGate <id>] [-AcceptAgent <id>] [-Inputs "k=v;k=v"] [-DryRun] [-Json] [-Help]'
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
$workspaceRoot = Find-WorkspaceRoot -StartDir $PSScriptRoot
if (-not $studioRoot -or -not $workspaceRoot) { throw 'Unable to resolve studio / workspace roots.' }
$projectRoot = Get-RepoRoot

$workflowYaml = Join-Path (Join-Path $studioRoot "workflows/$Id") 'workflow.yml'
Assert-PathInsideRoot -Root (Join-Path $studioRoot 'workflows') -Candidate $workflowYaml -MessagePrefix 'workflow.yml escapes workflows root'

$inputHash = @{}
if ($Inputs) {
    foreach ($pair in $Inputs.Split(';')) {
        $kv = $pair.Split('=', 2)
        if ($kv.Count -eq 2) { $inputHash[$kv[0].Trim()] = $kv[1].Trim() }
    }
}
$gateActions = @{}
if ($ConfirmGate) { $gateActions[$ConfirmGate] = 'confirm' }
if ($RejectGate)  { $gateActions[$RejectGate] = 'reject' }
$agentActions = @{}
if ($AcceptAgent) { $agentActions[$AcceptAgent] = 'accept' }

try {
    $result = Invoke-Workflow `
        -WorkflowYamlPath $workflowYaml `
        -Feature $Feature `
        -ProjectRoot $projectRoot `
        -WorkspaceRoot $workspaceRoot `
        -Inputs $inputHash `
        -GateActions $gateActions `
        -AgentActions $agentActions `
        -Resume:$Resume `
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
}
exit $result.ExitCode
