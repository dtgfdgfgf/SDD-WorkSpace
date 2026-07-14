#!/usr/bin/env pwsh

#Requires -Version 7.0
<#
.SYNOPSIS
    Drive a studio workflow end-to-end: start, halt at gates / agent steps,
    resume after the operator does the LLM-side work.

.DESCRIPTION
    Authorizes the workflow against catalog.json / state.json / manifest.json
    (fail-closed), resolves studio/workflows/<id>/workflow.yml, parses + validates
    against manifest.schema.json, initializes or resumes RunState at
    <project>/.workflow/runs/<feature>/state.json (local transient, ignored by Git),
    and runs the state machine via the workflow-engine.ps1 dispatcher.

    Exit codes:
        0  completed
        1  failed (script step, schema, or authorization denied)
        42 awaiting_agent (operator action required)
        43 awaiting_gate (-ConfirmGate / -RejectGate required)
        44 rejected (gate rejected with no on_reject branch; recover with -Restart)

.PARAMETER Id
    Workflow id (resolves to studio/workflows/<id>/workflow.yml).

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

$workflowYaml = Join-Path (Join-Path $studioRoot "workflows/$Id") 'workflow.yml'
Assert-PathInsideRoot -Root (Join-Path $studioRoot 'workflows') -Candidate $workflowYaml -MessagePrefix 'workflow.yml escapes workflows root'

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
$catalogPath = Join-Path $studioRoot 'workflows/catalog.json'
$stateLedgerPath = Join-Path $studioRoot 'workflows/state.json'
$manifestPath = Join-Path (Join-Path $studioRoot "workflows/$Id") 'manifest.json'

if (-not (Test-Path -LiteralPath $catalogPath -PathType Leaf)) {
    Deny-WorkflowRun -Message "Workflow catalog not found at $catalogPath; refusing to run without governance metadata."
}
try { $catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json -AsHashtable } catch {
    Deny-WorkflowRun -Message "Unable to parse workflow catalog at ${catalogPath}: $($_.Exception.Message)"
}
$catalogEntry = $null
foreach ($wf in @($catalog.workflows)) {
    if ([string]$wf.id -eq $Id) { $catalogEntry = $wf; break }
}
if (-not $catalogEntry) {
    Deny-WorkflowRun -Message "Workflow '$Id' is not cataloged in $catalogPath; refusing to run an ungoverned workflow."
}
if ([string]$catalogEntry.reviewStatus -eq 'rejected') {
    Deny-WorkflowRun -Message "Workflow '$Id' has reviewStatus 'rejected' and is retained for audit history only."
}
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    Deny-WorkflowRun -Message "Workflow manifest not found at $manifestPath."
}
try { $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -AsHashtable } catch {
    Deny-WorkflowRun -Message "Unable to parse workflow manifest at ${manifestPath}: $($_.Exception.Message)"
}
if ([string]$manifest.id -ne $Id -or [string]$manifest.version -ne [string]$catalogEntry.version) {
    Deny-WorkflowRun -Message "Workflow identity mismatch: manifest declares '$($manifest.id)@$($manifest.version)' but the catalog entry is '$Id@$($catalogEntry.version)'."
}
$effectiveEnabled = [bool]$catalogEntry.defaultEnabled
$enableSource = 'defaultEnabled'
if (Test-Path -LiteralPath $stateLedgerPath -PathType Leaf) {
    try { $stateLedger = Get-Content -LiteralPath $stateLedgerPath -Raw | ConvertFrom-Json -AsHashtable } catch {
        Deny-WorkflowRun -Message "Unable to parse workflow state ledger at ${stateLedgerPath}: $($_.Exception.Message)"
    }
    if ($stateLedger.states -and $stateLedger.states.ContainsKey($Id)) {
        $stateEntry = $stateLedger.states[$Id]
        $effectiveEnabled = [bool]$stateEntry.enabled
        $enableSource = 'state'
        if ($stateEntry.pinnedVersion -and [string]$stateEntry.pinnedVersion -ne [string]$catalogEntry.version) {
            Deny-WorkflowRun -Message "Workflow '$Id' state ledger pins version '$($stateEntry.pinnedVersion)' but the catalog lists '$($catalogEntry.version)'. Re-run set-workflow-state.ps1 after review."
        }
    }
}
if (-not $effectiveEnabled) {
    Deny-WorkflowRun -Message "Workflow '$Id' is not enabled (reviewStatus '$($catalogEntry.reviewStatus)', defaultEnabled=$([bool]$catalogEntry.defaultEnabled)). Enable it explicitly with set-workflow-state.ps1 -Id $Id -State enabled."
}
# The runner re-checks the POLICY enable invariants instead of trusting ledger authors:
# defaultEnabled is honored only for approved core/curated workflows, and an explicit
# state-ledger enable is honored only for reviewStatus approved or deprecated (the same
# rule set-workflow-state.ps1 enforces on the write path).
if ($enableSource -eq 'defaultEnabled') {
    if ([string]$catalogEntry.reviewStatus -ne 'approved' -or [string]$catalogEntry.trustLevel -notin @('core', 'curated')) {
        Deny-WorkflowRun -Message "Workflow '$Id' is default-enabled but violates the default-enable policy (requires reviewStatus 'approved' and trustLevel core/curated; found '$($catalogEntry.reviewStatus)'/'$($catalogEntry.trustLevel)')."
    }
} elseif ([string]$catalogEntry.reviewStatus -notin @('approved', 'deprecated')) {
    Deny-WorkflowRun -Message "Workflow '$Id' has reviewStatus '$($catalogEntry.reviewStatus)', which cannot be enabled via the state ledger (allowed: approved, deprecated)."
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
