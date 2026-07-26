# Studio Workflow Policy

## Authority

- `studio/workflows/<id>/` is the canonical source for workflow-owned assets (`manifest.json`, `workflow.yml`, docs).
- `studio/workflows/catalog.json` is the workspace governance ledger for review, trust, rollout, and the approved raw-byte `workflow.yml` SHA-256 digest.
- `studio/workflows/state.json` is the workspace enable/disable ledger.
- Per-project `.workflow/runs/<feature>/state.json` (under the executing project root, outside `specs/`) holds RunState for an executing workflow, including the workflow id, version, and approved raw-byte SHA-256 used to start that run. Terminal task baselines are separately preserved in engine-created local `.workflow/runs/<feature>/baselines/<run-id>/<step-id>.json` sidecars written with atomic no-overwrite-at-creation semantics; RunState keeps only a consistency-checked cache. These are local transient artifacts: generated, operator-controlled, never hand-edited as governance authority, and never intended for Git. The sidecar/cache comparison detects isolated inconsistency but does not authenticate provenance or resist coordinated replacement by the same local principal; that broader RunState authenticity boundary remains open under R-B23. The workspace repo and the `project-init` template ignore `.workflow/`; a pre-existing standalone consumer repo must add the same ignore before running a workflow inside it. Cross-machine resume is out of scope; if it is ever needed it will be an explicit checkpoint export/import capability, not Git tracking.
- Per-feature `.workflow/runs/<feature>/eci-requirement.json` is a strict identity-bound Boolean latch created by the `/speckit.eci` entry gate with atomic no-overwrite publication. Once present, it prevents an isolated deletion or normalization of canonical ECI evidence from silently removing the ECI obligation. This operator-controlled local sidecar does not authenticate the readiness or dossier contents; coordinated deletion or forgery of the marker and governed evidence remains open under R-B23.

## Review Status

- `draft`: local intake only; cannot be default-enabled.
- `approved`: curated and allowed to participate in managed rollout.
- `experimental`: locally testable but never default-enabled.
- `deprecated`: still cataloged for compatibility; it cannot be newly enabled. An enable request
  is accepted only as a byte-preserving no-op when the existing state entry is already enabled and
  pinned to the current catalog version.
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
- State provenance: registry state accepts only `default` and `manual`. Remote provenance is not a
  supported state source.
- Execution: drive the runtime with `run-workflow.ps1 -Id <id> -Feature <feature>`. The runner authorizes the workflow against `catalog.json`, `state.json`, and `manifest.json` (fail-closed) before dispatch: an uncataloged, rejected, not-enabled, policy-violating, identity-mismatched, or approval-digest-mismatched workflow is denied even if its directory exists. The engine hashes and parses the same exact `workflow.yml` byte snapshot, then binds its SHA-256 to RunState. RunState is persisted at `<project>/.workflow/runs/<feature>/state.json` for `-Resume` / `-ConfirmGate` / `-RejectGate` / `-Restart`; starting a run never creates anything under `specs/`.
- Removal: remove catalog entry, state entry, and workflow directory together.

## Workflow Graph Identity

- `workflowSha256` in `catalog.json` is the approval digest for the exact raw bytes of `workflow.yml`; it is not inferred from id or version.
- `approved` and `deprecated` workflows require a lowercase 64-character `workflowSha256`. Experimental workflows may keep it null and remain execution-denied.
- A content change invalidates the existing approval even when workflow id and version are unchanged. The catalog digest must be updated only through explicit review.
- Resume compares RunState workflow id, version, and SHA-256 with the currently approved graph before replaying any step. Missing, malformed, legacy, or mismatched identity fields fail closed.
- A changed graph may not resume an older run. After explicit re-approval, the operator must use `-Restart`; the old RunState is archived only after the current graph passes approval validation. Each archive uses a collision-resistant UTC-millisecond-and-nonce name and an atomic no-overwrite move, so a later restart cannot replace an earlier archive.

## ECI Requirement Latch

- `/speckit.eci` must run `setup-eci.ps1` as its non-bypassable first action. The gate accepts only the exact initial `ROUTE_TO_ECI` and `PENDING` intake, requires the validator Boolean `ECI_REQUIRED=true`, and creates or strictly revalidates the feature-bound latch before the agent reads governed artifacts.
- Invalid, wrong-type, identity-mismatched, false, or null marker values fail closed. A latched feature cannot be rewritten to `NOT_REQUIRED` or use an `N/A` evidence digest, and direct Plan entry still requires the complete current five-file ECI dossier and its framed SHA-256.
- The workflow branches into ECI only from the immediately preceding validator result `READINESS_PRIMARY_STATUS == 'ROUTE_TO_ECI'`. A fresh or restarted run with a valid, complete, already re-entered dossier therefore proceeds from the current Readiness route instead of repeating ECI.
- The latch detects isolated evidence deletion or normalization but is not an authenticity mechanism. Coordinated marker deletion or forgery together with governed evidence remains the separate open R-B23 boundary.

## Run Outcomes and Exit Codes

- `0` completed; `1` failed or authorization denied.
- `42` awaiting_agent: run the agent slash command, then `-Resume`.
- `43` awaiting_gate: `-ConfirmGate <id>` to advance, or `-RejectGate <id>`.
- `44` rejected: a gate was rejected and declares no `on_reject` branch, so the run is terminal. Start over with `-Restart`, which archives the prior RunState next to the live path.
- A terminal step (e.g. the implement stage) completes only when its declared `postcondition` holds; `-AcceptAgent` cannot substitute for a terminal step's completion. A missing, malformed, identity-mismatched, or cache-mismatched terminal baseline sidecar fails closed and requires `-Restart`.

## Step Types Supported in Wave 3

- `command` with `dispatch: script` or `dispatch: agent`.
- `gate` (operator-confirmed).
- `if` (then / else branches). Comparison and Boolean conditions use the engine grammar directly, for example `vars.steps.validation.json.READINESS_PRIMARY_STATUS == 'ROUTE_TO_ECI'`; `{{ }}` is reserved for value interpolation and must not wrap operators.
- `switch` (case / default branches).
- `prompt`, `shell`, `while`, `do-while`, `fan-out`, `fan-in` MUST emit a `step-type-not-implemented` error if encountered. They are deferred to a later wave.

## Dispatch Boundary

`command` steps cross an operator-in-the-loop boundary:

- `dispatch: script` runs an authorized PowerShell script via `& pwsh -NoProfile -File`. "Authorized" means the script resolves inside the workspace root (the runner anchors the workspace root to the runner's own location, so `SDD_STUDIO_ROOT` may redirect the governed workflows tree but never the dispatchable script surface). Args are positional; no shell interpolation. The child process working directory is the configured project root. Exit code is compared to `expected_exit_code`. Captured stdout JSON, when `capture.json=true`, is parsed and stored under `vars.steps.<id>.json`.
- `dispatch: agent` halts the run with `status=awaiting_agent` and exit code `42`. The operator runs the agent slash command in their IDE, produces the declared `expected_artifact`, and resumes via `run-workflow.ps1 -Resume`. The engine asserts the artifact path inside the workspace before re-checking existence.
- Completed command steps are skipped on resume except for `revalidate_on_resume: true`, which is restricted by both schema and engine to the canonical read-only feature-structure validator with strict JSON capture. Each replay removes the prior capture before dispatch and requires a JSON object with Boolean `VALID=true`, so routing cannot reuse stale evidence after empty, malformed, or failed validation output.

## Dependencies

- `powershell-yaml` (PowerShell Gallery module) is REQUIRED to parse `workflow.yml`.
- Detection only: `check-speckit-runtime.ps1 -Json` reports `STUDIO_WORKFLOW_YAML_AVAILABLE`. The module is never auto-installed. The recommended install command is `Install-Module -Name powershell-yaml -Scope CurrentUser`.

## Guardrails

- Catalog and state changes are local-only; no remote registry producer is supported.
- No direct writes into existing `projects/` or `learning/` from workflow execution; the workflow engine routes side effects through standard `dispatch: script` invocations.
- No workflow may override core shared files or another workflow's outputs.
- Any path escaping the workspace root, the project root, or the workflow root is rejected at runtime. Workflow registry authorization checks both the normalized lexical path and every existing reparse-point target for the selected source directory, `workflow.yml`, and `manifest.json`; an external junction or symbolic-link target is denied by listing and execution through the same shared decision.
- RunState live-state writes are atomic (`state.json.tmp` + `Move-Item -Force`). Restart archives and terminal baseline sidecars use atomic no-overwrite moves; restart archive names include UTC milliseconds plus a GUID nonce, and an exact destination collision fails closed without replacing either state history or the existing archive. Later baseline reads detect mismatch against the RunState cache, but all of these artifacts remain operator-controlled local state and provide no cryptographic provenance guarantee; R-B23 remains open. An advisory lock at `state.json.lock` is honored for 60 seconds to surface concurrent invocation conflicts.
