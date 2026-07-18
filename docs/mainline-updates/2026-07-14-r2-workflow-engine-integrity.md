# Mainline Update Note: R2 Workflow Engine Execution Integrity

**Date**: 2026-07-14
**Source Branch**: `feature/wave-3-security-and-workflows`
**Target Branch**: `main`
**Status**: Draft
**Related Commits**: `6a53f66`
**Related PR**: https://github.com/dtgfdgfgf/SDD-WorkSpace/pull/3
**Reconciliation Status**: Open

## Revalidation

The 2026-07-14 governance re-review
([`sdd-workspace-wave-3-governance-review-2026-07-14_zhTW.md`](../sdd-workspace-wave-3-governance-review-2026-07-14_zhTW.md))
refuted two of this note's material closure claims with reproduced counterexamples, so the note is
demoted from Ready to Draft per the note state machine's Reopened rule:

- **R-B02 (false-completion closure) refuted by RVR-01.** The `no-pending-tasks` postcondition only
  checks that no unchecked `T\d+` marker remains; it does not preserve or compare the baseline task-ID
  inventory. Replacing `tasks.md` with any non-empty non-task text after the Implement step arrives
  still completes the run (locally reproduced). Closure moves to ledger item R-B19.
- **R-B05 (runner fail-closed authorization) refuted by RVR-03.** The runner does not apply the
  `catalog.schema.json` / `state.schema.json` validators and casts `defaultEnabled` / `enabled` with
  `[bool]`, where `[bool]'false'` is `True` (locally reproduced); a missing `state.json` falls back to
  `defaultEnabled` instead of failing closed. Closure moves to ledger item R-B20.

The other items in this batch (R-B01, R-B03, R-B04, R-B06 remainder, R-B10 through R-B16) are not
refuted and stand as implemented. Re-entry condition: this note may return to Ready only after R-B19
and R-B20 land with baseline-inventory and schema/strict-boolean fail-closed negative tests, and the
2026-07-14 remediation plan's RB-1 batch closes. Full mapping in
[`sdd-workspace-wave-3-remediation-plan-2026-07-14_zhTW.md`](../sdd-workspace-wave-3-remediation-plan-2026-07-14_zhTW.md).

### 2026-07-18 Restart Archive Revalidation

This dated evidence supersedes only the preceding sentence's R-B10 archive-retention conclusion.
An RB-2 adversarial test fixed the clock and performed two consecutive `-Restart` operations. The
engine's second-granularity archive name and `Move-Item -Force` left only one archive: the second
restart overwrote the first state, losing its run identity and audit evidence. R-B10 therefore
returns to `IN_PROGRESS`, and the distinct Medium finding R-B24 records the collision and overwrite
failure. The existing explicit restart and terminal/in-flight recovery behavior remains effective.

Re-entry requires collision-resistant archive names, atomic no-overwrite creation, and a
discriminating fixed-time repeated-restart test that preserves both archived states and their
distinct run identities. This note remains Draft and its Reconciliation Status is Open until that
evidence exists.

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
verification; R-B06's dispatch/context half closed on 2026-07-13. This batch targets the remaining
engine execution-integrity items. As recorded in the Revalidation section above, the false-completion
(R-B02) and runner-authorization (R-B05) closures were later refuted and moved to R-B19 / R-B20; the
remaining items (no canonical-ID side effects, no preview pollution, duplicate-id and gate
fail-closed guards) stand.

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
- (REOPENED, R-B02 / RVR-01) This batch added a `no-pending-tasks` postcondition and a terminal
  `-AcceptAgent` lockout, but the re-review showed the postcondition does not preserve the baseline
  task-ID inventory, so false completion is NOT closed. See the Revalidation section; closure moves to
  R-B19.
- A rejected gate with no remediation branch stops the run instead of silently completing it.
- (REOPENED, R-B05 / RVR-03) This batch added catalog/state/manifest existence and identity checks,
  but the re-review showed the runner does not apply the catalog/state schema and mis-parses string
  booleans (missing `state.json` falls back to `defaultEnabled`), so runner authorization is NOT
  fail-closed. See the Revalidation section; closure moves to R-B20.
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
- Implementation commit `6a53f66` exists and all local validation is green; hosted `audit-and-tests`
  validates the pushed SHA on PR #3 before merge.

## Follow-ups

- R-B07 ECI full-dossier re-entry and R-B08 analyze result artifact (R3).
- R-B09 re-promotion of sdd-pipeline after the wave-3 gates close (R6).
- Optional hardening carried in the ledger: strengthen the DryRun sidecar lock, and consider a
  bootstrap step that adds `.workflow/` ignore to existing consumer repos.
