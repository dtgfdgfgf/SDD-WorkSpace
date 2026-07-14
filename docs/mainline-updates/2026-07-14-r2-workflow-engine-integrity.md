# Mainline Update Note: R2 Workflow Engine Execution Integrity

**Date**: 2026-07-14
**Source Branch**: `feature/wave-3-security-and-workflows`
**Target Branch**: `main`
**Status**: Draft
**Related Commits**: TBD
**Related PR**: https://github.com/dtgfdgfgf/SDD-WorkSpace/pull/3
**Reconciliation Status**: Closed

## Summary

- Relocate RunState to `<project>/.workflow/runs/<feature>/state.json` (outside `specs/`) so starting
  a run never allocates a canonical feature ID; ignore `.workflow/` in the workspace and project
  template (R-B06 remainder, R-B16).
- Make DryRun write an ephemeral sidecar that a real resume never consumes (R-B03), reject duplicate
  step ids anywhere in the step tree (R-B04), surface failure detail in the run payload (R-B11), and
  deduplicate replay history for command, gate, if, and switch steps (R-B12).
- Make gate decisions fail-closed: a decision applies only to a gate that has actually halted, and a
  rejection with no `on_reject` branch is terminal (exit 44) rather than a silent pass-through
  (R-B01); add `-Restart` recovery for completed/failed/rejected/in-flight runs (R-B10).
- Give the terminal implement step a real completion postcondition (zero unchecked canonical tasks)
  and disable `-AcceptAgent` as a completion substitute for terminal steps (R-B02).
- Enforce runner authorization from `catalog.json` / `state.json` / `manifest.json` and bind the
  executed `workflow.yml` identity to the authorized id/version before dispatch (R-B05); move test
  fixtures into isolated TestDrive studio roots (R-B13); validate manifest `entryPoints` existence
  and correct the sdd-pipeline manifest (R-B15); remove the unused `runs/` index placeholder and its
  POLICY claim (R-B14).

## Why This Update Exists

The 2026-07-12 wave-3 governance review and the repair ledger recorded thirteen workflow-engine
defects (GOV-01 through GOV-13, ledger R-B01 through R-B16). R0 and R1 closed containment and
verification; R-B06's dispatch/context half closed on 2026-07-13. This batch closes the remaining
engine execution-integrity items so the runtime cannot report false completion, run ungoverned
content, allocate canonical IDs by side effect, or pollute a real run from a preview.

An adversarial pre-commit review (three independent reviewers) found five further defects in the
first draft of this batch — a terminal step that could never complete when its postcondition was
already satisfied, if/switch replay history that still grew per resume, the executed `workflow.yml`
not being bound to the authorized identity, the runner not enforcing the POLICY default-enable
invariant, and stale RunState paths in the runtime script headers and QUICKSTART. All five were
fixed and regression-tested inside this batch before commit.

## Scope

- Close ledger items R-B01 through R-B06 (remainder), R-B10 through R-B16.
- No constitution rule, agent surface, or SDD stage semantics change.
- sdd-pipeline stays `experimental` / default-disabled: the runner authorization now makes it
  deterministically denied until the wave-3 promotion gates close in R6. This is intended and is
  now disclosed in the pipeline README and POLICY.
- R-B07 (ECI full-dossier re-entry), R-B08 (analyze result artifact), and R-B09 (re-promotion) remain
  open for R3/R6.

## Affected Paths

| Path | Change |
|------|--------|
| `studio/scripts/powershell/workflow-engine.ps1` | RunState relocation, DryRun sidecar, duplicate-id guard, gate fail-closed + terminal `rejected` status/exit 44, terminal postcondition, replay history dedup, executed-identity binding, timestamped `-Restart` archive. |
| `studio/scripts/powershell/run-workflow.ps1` | Fail-closed catalog/state/manifest authorization, POLICY default-enable re-check, `-Restart` surface, ERROR payload in both output modes, contradictory-gate guard, workspace-root anchoring, updated help. |
| `studio/scripts/powershell/validate-workflow.ps1` | Manifest `entryPoints` existence validation. |
| `studio/workflows/manifest.schema.json` | `terminal` / `postcondition` step fields, restricted to agent dispatch. |
| `studio/workflows/sdd-pipeline/workflow.yml` | Terminal implement step with `no-pending-tasks` postcondition. |
| `studio/workflows/sdd-pipeline/manifest.json` | Remove the nonexistent `scripts` entry point and `scripts` runtime scope. |
| `studio/workflows/POLICY.md`, `studio/workflows/sdd-pipeline/docs/README.md`, `studio/QUICKSTART.md` | RunState location, transient/no-Git wording, exit-code table (incl. 44), authorization and demotion disclosure. |
| `studio/workflows/runs/.gitkeep` | Removed (unused index placeholder). |
| `.gitignore`, `studio/templates/project-init/.gitignore` | Ignore `.workflow/`. |
| `studio/runtime/shared-runtime-contract.json` | Eight new/extended invariants binding the behaviors above, with call-site tokens that break on a single-line revert. |
| `studio/tests/workflow-engine.Tests.ps1`, `studio/tests/workflow-schema.Tests.ps1`, `studio/tests/workflow-runstate.Tests.ps1` | Regression coverage for every item above. |

## Impact

- A run keeps one feature context, never pre-creates `specs/<feature>`, and cannot be resumed from a
  DryRun preview.
- False completion is closed on the shipped pipeline: the implement stage completes only with zero
  unchecked canonical tasks, and no directory-on-disk or `-AcceptAgent` shortcut substitutes.
- A rejected gate with no remediation branch stops the run instead of silently completing it.
- An uncataloged, rejected, not-enabled, policy-violating, identity-mismatched, or content-swapped
  workflow is denied before any engine side effect.
- Known residuals, recorded not absorbed: `.workflow/` is ignored only in the workspace repo and the
  project template — a pre-existing standalone consumer repo must add the pattern itself (noted in
  POLICY, and consumer-repo drift is out of this shared-layer batch's scope); the DryRun sidecar uses
  its own advisory lock so a concurrent real run could see a preview-only stale read; and the
  `SDD_STUDIO_ROOT` redirect is an operator-surface convenience, not a privilege boundary (documented
  in POLICY and a code comment).

## Impact Reconciliation

| Target | Impact | Disposition | Evidence |
|--------|--------|-------------|----------|
| `studio/runtime/shared-runtime-contract.json` | `must_review` | `updated` | Eight new/extended invariants with revert-sensitive call-site tokens. |
| `studio/scripts/powershell/workflow-engine.ps1` | `must_review` | `updated` | Engine execution-integrity fixes above. |
| `studio/scripts/powershell/run-workflow.ps1` | `must_review` | `updated` | Runner authorization and CLI surface. |
| `studio/scripts/powershell/validate-workflow.ps1` | `must_review` | `updated` | entryPoints existence check. |
| `studio/workflows/manifest.schema.json` | `must_review` | `updated` | terminal/postcondition fields, agent-only. |
| `studio/workflows/POLICY.md` | `must_review` | `updated` | RunState, authorization, exit codes, dispatch boundary. |
| `studio/workflows/sdd-pipeline/**` | `must_review` | `updated` | Terminal implement step, manifest entry-point fix, README disclosure. |
| `studio/scripts/powershell/check-speckit-runtime.ps1` | `must_review` | `reviewed-no-change` | Existing invariant evaluation handles the added records. |
| `.githooks/pre-commit.ps1` | `must_review` | `reviewed-no-change` | Consumes the contract through the unchanged audit entry point. |
| `studio/QUICKSTART.md` | `maybe_review` | `updated` | RunState path and experimental-status disclosure corrected. |
| `WORKSPACE_STRUCTURE.md` | `maybe_review` | `reviewed-no-change` | No workspace component added, removed, or relocated (RunState is a local transient, not a tracked layout path). |
| `.claude/agents/*.md` | `must_update` | `reviewed-no-change` | No agent source changed in this batch. |
| `studio/constitution/constitution.md` | `maybe_review` | `reviewed-no-change` | Fixes implement existing ordered-stage, gate, and surface-truthfulness rules; no new policy. |

## Validation

- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json`: `VALID=true`, 0 errors, 0 warnings.
- Full governance Pester suite: 361 passed, 0 failed, 0 skipped (baseline before this batch on the
  same machine: 333 passed).
- Simulated single-line reverts of each guarded behavior break at least one contract token (verified
  for gate-fail-closed propagation, terminal postcondition call site, and history-dedup call sites,
  which survived the first draft's tokens and were hardened).
- Adversarial three-reviewer patch review: five defects found, all fixed and regression-tested here.

## Merge Notes

- This batch does not promote the experimental workflow runtime; sdd-pipeline remains denied until R6.
- Backfill Related Commits and flip Status to Ready in the follow-up accounting commit after hosted
  validation of the pushed SHA.

## Follow-ups

- R-B07 ECI full-dossier re-entry and R-B08 analyze result artifact (R3).
- R-B09 re-promotion of sdd-pipeline after the wave-3 gates close (R6).
- Optional hardening carried in the ledger: strengthen the DryRun sidecar lock, and consider a
  bootstrap step that adds `.workflow/` ignore to existing consumer repos.
