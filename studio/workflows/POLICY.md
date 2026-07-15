# Studio Workflow Policy

## Authority

- `studio/workflows/<id>/` is the canonical source for workflow-owned assets (`manifest.json`, `workflow.yml`, docs).
- `studio/workflows/catalog.json` is the workspace governance ledger for review, trust, and rollout.
- `studio/workflows/state.json` is the workspace enable/disable ledger.
- Per-project `.workflow/runs/<feature>/state.json` (under the executing project root, outside `specs/`) holds RunState for an executing workflow. Terminal task baselines are separately preserved in engine-owned, write-once `.workflow/runs/<feature>/baselines/<run-id>/<step-id>.json` sidecars; RunState keeps only a checked cache. These are local transient artifacts: generated, operator-controlled, never hand-edited as governance authority, and never intended for Git. The workspace repo and the `project-init` template ignore `.workflow/`; a pre-existing standalone consumer repo must add the same ignore before running a workflow inside it. Cross-machine resume is out of scope; if it is ever needed it will be an explicit checkpoint export/import capability, not Git tracking.

## Review Status

- `draft`: local intake only; cannot be default-enabled.
- `approved`: curated and allowed to participate in managed rollout.
- `experimental`: locally testable but never default-enabled.
- `deprecated`: still cataloged for compatibility, but should not be newly enabled.
- `rejected`: retained only for audit history; not installable.

## Trust Levels

- `core`: maintained as first-party shared-layer capability.
- `curated`: accepted into the workspace curated catalog after review.
- `experimental`: local-only evaluation status.

## Default Enable Rules

- `defaultEnabled=true` is allowed only when `reviewStatus=approved` and `trustLevel` is `core` or `curated`.
- Uncataloged, `draft`, `experimental`, `deprecated`, and `rejected` workflows are never default-enabled.
- `autoEnableNewWorkflows` remains `false`; enablement is always explicit or policy-driven.

## Lifecycle

- Intake: add a local source directory with a valid `manifest.json` and `workflow.yml`.
- Validation: `validate-workflow.ps1 -Id <id>` parses the YAML and asserts the schema.
- Governance: register the workflow in `catalog.json` with `reviewStatus=draft` or stricter.
- Activation: write `state.json` via `set-workflow-state.ps1`.
- Execution: drive the runtime with `run-workflow.ps1 -Id <id> -Feature <feature>`. The runner authorizes the workflow against `catalog.json`, `state.json`, and `manifest.json` (fail-closed) before dispatch: an uncataloged, rejected, not-enabled, policy-violating, or identity-mismatched workflow is denied even if its directory exists. RunState is persisted at `<project>/.workflow/runs/<feature>/state.json` for `-Resume` / `-ConfirmGate` / `-RejectGate` / `-Restart`; starting a run never creates anything under `specs/`.
- Removal: remove catalog entry, state entry, and workflow directory together.

## Run Outcomes and Exit Codes

- `0` completed; `1` failed or authorization denied.
- `42` awaiting_agent: run the agent slash command, then `-Resume`.
- `43` awaiting_gate: `-ConfirmGate <id>` to advance, or `-RejectGate <id>`.
- `44` rejected: a gate was rejected and declares no `on_reject` branch, so the run is terminal. Start over with `-Restart`, which archives the prior RunState next to the live path.
- A terminal step (e.g. the implement stage) completes only when its declared `postcondition` holds; `-AcceptAgent` cannot substitute for a terminal step's completion. A missing, malformed, identity-mismatched, or cache-mismatched terminal baseline sidecar fails closed and requires `-Restart`.

## Step Types Supported in Wave 3

- `command` with `dispatch: script` or `dispatch: agent`.
- `gate` (operator-confirmed).
- `if` (then / else branches).
- `switch` (case / default branches).
- `prompt`, `shell`, `while`, `do-while`, `fan-out`, `fan-in` MUST emit a `step-type-not-implemented` error if encountered. They are deferred to a later wave.

## Dispatch Boundary

`command` steps cross an operator-in-the-loop boundary:

- `dispatch: script` runs an authorized PowerShell script via `& pwsh -NoProfile -File`. "Authorized" means the script resolves inside the workspace root (the runner anchors the workspace root to the runner's own location, so `SDD_STUDIO_ROOT` may redirect the governed workflows tree but never the dispatchable script surface). Args are positional; no shell interpolation. The child process working directory is the configured project root. Exit code is compared to `expected_exit_code`. Captured stdout JSON, when `capture.json=true`, is parsed and stored under `vars.steps.<id>.json`.
- `dispatch: agent` halts the run with `status=awaiting_agent` and exit code `42`. The operator runs the agent slash command in their IDE, produces the declared `expected_artifact`, and resumes via `run-workflow.ps1 -Resume`. The engine asserts the artifact path inside the workspace before re-checking existence.

## Dependencies

- `powershell-yaml` (PowerShell Gallery module) is REQUIRED to parse `workflow.yml`.
- Detection only: `check-speckit-runtime.ps1 -Json` reports `STUDIO_WORKFLOW_YAML_AVAILABLE`. The module is never auto-installed. The recommended install command is `Install-Module -Name powershell-yaml -Scope CurrentUser`.

## Guardrails

- No remote catalog sync.
- No direct writes into existing `projects/` or `learning/` from workflow execution; the workflow engine routes side effects through standard `dispatch: script` invocations.
- No workflow may override core shared files or another workflow's outputs.
- Any path escaping the workspace root, the project root, or the workflow root is rejected at runtime.
- RunState writes are atomic (`state.json.tmp` + `Move-Item -Force`). Terminal baseline sidecars use an atomic no-overwrite move and are write-once for a run and step identity. An advisory lock at `state.json.lock` is honored for 60 seconds to surface concurrent invocation conflicts.
