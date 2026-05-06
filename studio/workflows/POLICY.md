# Studio Workflow Policy

## Authority

- `studio/workflows/<id>/` is the canonical source for workflow-owned assets (`manifest.json`, `workflow.yml`, docs).
- `studio/workflows/catalog.json` is the workspace governance ledger for review, trust, and rollout.
- `studio/workflows/state.json` is the workspace enable/disable ledger.
- Per-feature `specs/<feature>/.workflow/state.json` holds RunState for an executing workflow. It is generated and operator-controlled; never hand-edited as governance authority.
- `studio/workflows/runs/` is a disposable index pointer for active runs. It is generated only.

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
- Execution: drive the runtime with `run-workflow.ps1 -Id <id> -Feature <feature>`. RunState is persisted at `specs/<feature>/.workflow/state.json` for `-Resume` / `-ConfirmGate` / `-RejectGate`.
- Removal: remove catalog entry, state entry, and workflow directory together.

## Step Types Supported in Wave 3

- `command` with `dispatch: script` or `dispatch: agent`.
- `gate` (operator-confirmed).
- `if` (then / else branches).
- `switch` (case / default branches).
- `prompt`, `shell`, `while`, `do-while`, `fan-out`, `fan-in` MUST emit a `step-type-not-implemented` error if encountered. They are deferred to a later wave.

## Dispatch Boundary

`command` steps cross an operator-in-the-loop boundary:

- `dispatch: script` runs an authorized PowerShell script via `& pwsh -NoProfile -File`. Args are positional; no shell interpolation. Exit code is compared to `expected_exit_code`. Captured stdout JSON, when `capture.json=true`, is parsed and stored under `vars.steps.<id>.json`.
- `dispatch: agent` halts the run with `status=awaiting_agent` and exit code `42`. The operator runs the agent slash command in their IDE, produces the declared `expected_artifact`, and resumes via `run-workflow.ps1 -Resume`. The engine asserts the artifact path inside the workspace before re-checking existence.

## Dependencies

- `powershell-yaml` (PowerShell Gallery module) is REQUIRED to parse `workflow.yml`.
- Detection only: `check-speckit-runtime.ps1 -Json` reports `STUDIO_WORKFLOW_YAML_AVAILABLE`. The module is never auto-installed. The recommended install command is `Install-Module -Name powershell-yaml -Scope CurrentUser`.

## Guardrails

- No remote catalog sync.
- No direct writes into existing `projects/` or `learning/` from workflow execution; the workflow engine routes side effects through standard `dispatch: script` invocations.
- No workflow may override core shared files or another workflow's outputs.
- Any path escaping the workspace root, the project root, or the workflow root is rejected at runtime.
- RunState writes are atomic (`state.json.tmp` + `Move-Item -Force`). An advisory lock at `state.json.lock` is honored for 60 seconds to surface concurrent invocation conflicts.
