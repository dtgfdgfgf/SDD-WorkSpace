# Mainline Update Note: Workflow Engine Completion Integrity

**Date**: 2026-07-12
**Source Branch**: `feature/wave-3-security-and-workflows`
**Target Branch**: `main`
**Status**: Ready
**Related Commits**: `78893e2`
**Related PR**: N/A

## Summary

Fixes the five false-completion / replay defects in the Wave-3 workflow engine (verified external
analysis claims C1-C5) so that `sdd-pipeline` can be a real acceptance signal instead of one that
auto-succeeds off scaffolded files.

- **C1/C2** — agent steps no longer succeed merely because the expected artifact exists. The engine
  records a content fingerprint (`Get-ArtifactFingerprint`, SHA-256) of the artifact on first
  arrival (the scaffold / prior-stage baseline) and only completes the step when the artifact has
  actually changed since that baseline. A new `-AcceptAgent <step-id>` operator override exists for
  the legitimate "artifact already produced" case (it still requires a non-empty artifact).
- **C5** — resume no longer re-runs completed command steps. `RunState.completed_steps` records each
  successful command (script or agent) step; on resume those steps are skipped
  (`skipped-completed`), so a prep script can no longer overwrite agent-authored output on replay.
  `setup-plan.ps1` also gained an idempotent guard (never overwrite an existing `plan.md`), matching
  `setup-readiness` / `setup-tasks` / `setup-analyze`.
- **C3** — switch subjects now resolve. Agent steps may declare an `extract` block that pulls a
  field from the produced artifact into `RunState.vars` (via the shared `Get-MarkdownField` parser).
  `sdd-pipeline` extracts `readiness_primary_status` and `eci_authorization_outcome`, so the
  readiness and ECI switches route by real values instead of always falling to the `NOT_READY`
  default.
- **C4** — the implement step's completion is now driven by the same change detection (implement
  checks tasks off in `tasks.md`); mere pre-existence of `tasks.md` no longer completes the pipeline.

## Why This Update Exists

The verified analysis confirmed the engine's agent dispatch only did `Test-Path` on the expected
artifact, while prep scripts pre-create those artifacts — so `readiness` / `plan` / `tasks` /
`analyze` agent steps were auto-marked success without the agent running, the switches read vars
that were never assigned (dead-routing to `NOT_READY`), and resume replayed from the start and could
overwrite agent output. The owner chose to fix the engine fully now.

## Scope

- Engine, run-workflow CLI surface, workflow schema, `sdd-pipeline` workflow, `setup-plan.ps1`,
  tests, and contract invariants.
- Non-goals: no new step types; the expression/gate/lock subsystems are unchanged.

## Affected Paths

| Path | Change |
|------|--------|
| `studio/scripts/powershell/workflow-engine.ps1` | `Get-ArtifactFingerprint`, agent change-detection + `agent_baseline`, `completed_steps` skip, `Invoke-ArtifactExtraction`, `AgentActions` threading, `-AcceptAgent` |
| `studio/scripts/powershell/run-workflow.ps1` | `-AcceptAgent` flag wired to `AgentActions` |
| `studio/scripts/powershell/setup-plan.ps1` | Idempotent plan.md scaffold (no overwrite) |
| `studio/workflows/manifest.schema.json` | New `extract` array on command steps |
| `studio/workflows/sdd-pipeline/workflow.yml` | `extract` on readiness + eci steps; clarified implement operator message |
| `studio/tests/workflow-engine.Tests.ps1` | 4 new tests: existence≠completion, unchanged-stays-halted + `-AcceptAgent`, resume-skip preserves agent output, extract drives switch |
| `studio/runtime/shared-runtime-contract.json` | New `workflow-engine-completion-integrity` scriptInvariant; `-AcceptAgent` added to run-workflow CLI invariant |

## Impact

- `sdd-pipeline` now requires the operator to actually run each agent stage; a fresh run halts at
  every agent step until real content is produced, and resume is safe (no re-scaffold, no overwrite).
- Backward compatible with older RunState (missing `completed_steps` is initialized on resume).

## Validation

- `Invoke-Pester studio/tests/workflow-engine.Tests.ps1`: 10/10 passed, including the 3 new
  fix-verification tests (2026-07-12).
- `validate-workflow.ps1 -Id sdd-pipeline`: VALID, 0 errors / 0 warnings.
- Full governance suite: 253 passed / 0 failed / 1 skipped.
- `check-speckit-runtime.ps1`: Errors 0 / Warnings 0 with the new invariant active.
- Change manifests: none required.

## Merge Notes

- Final batch of the correctness/safety work derived from the verified external analysis; ready to
  merge with Wave-3.

## Follow-ups

- Consider a full end-to-end `sdd-pipeline` walkthrough test with a real feature fixture in a later
  wave (the current tests cover the engine mechanisms in isolation).
