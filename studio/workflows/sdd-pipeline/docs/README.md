# sdd-pipeline

The first studio-first workflow runtime artifact. It encodes the SDD seven-stage delivery flow as a single declarative workflow with explicit halt-and-resume semantics.

## What it covers

- All seven mandatory stages: specify, clarify, readiness, plan, tasks, analyze, implement.
- Readiness routing: all 8 primary statuses (`READY_FOR_PLAN`, `ROUTE_TO_ECI`, `ROUTE_TO_REPO_CONTEXT`, `ROUTE_TO_DECISION`, `ROUTE_TO_VALIDATION`, `ROUTE_TO_ACCESS`, `EXPLORATORY_ONLY`, `NOT_READY`).
- ECI re-entry: all 3 authorization outcomes (`READY_FOR_MAINLINE_IMPLEMENTATION`, `READY_FOR_SANDBOX_ONLY`, `READY_FOR_SPIKE_ONLY`).

## Run

```pwsh
pwsh ./studio/scripts/powershell/run-workflow.ps1 -Id sdd-pipeline -Feature 001-foo -Json
```

Each `dispatch: agent` step halts with exit code `42`; the operator runs the slash command in their agent IDE, produces the `expected_artifact`, then resumes:

```pwsh
pwsh ./studio/scripts/powershell/run-workflow.ps1 -Id sdd-pipeline -Feature 001-foo -Resume -Json
```

Each `gate` step halts with exit code `43`; resume with `-ConfirmGate <gate-id>` to advance. A `-RejectGate <gate-id>` runs the gate's `on_reject` branch when it declares one; this pipeline's gates declare none, so a rejection is terminal (status `rejected`, exit code `44`) and the run can only be started over with `-Restart` (which archives the RunState). Reject a gate only when you intend to abandon the current run.

This pipeline is currently `experimental` and default-disabled in `catalog.json` pending the wave-3 promotion gates; `run-workflow.ps1 -Id sdd-pipeline` is denied until it is re-promoted. The `## Run` commands above describe the intended surface once enabled.

## Operator-in-the-loop

This workflow is not transparent automation. The engine drives ordering and gate enforcement; the operator drives every LLM-side stage by running the corresponding slash command. RunState lives at `<project>/.workflow/runs/<feature>/state.json`. It is a local transient artifact ignored by Git: resumes are same-machine only, and starting a run never creates anything under `specs/`.
