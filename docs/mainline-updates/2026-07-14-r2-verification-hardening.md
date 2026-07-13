# Mainline Update Note: R2 Verification Hardening

**Date**: 2026-07-14
**Source Branch**: `feature/wave-3-security-and-workflows`
**Target Branch**: `main`
**Status**: Draft
**Related Commits**: TBD
**Related PR**: https://github.com/dtgfdgfgf/SDD-WorkSpace/pull/3
**Reconciliation Status**: Closed

## Summary

- Force UTF-8 decoding of git output in the pre-commit hook so the personal-data path gate
  cannot silently fail open on non-UTF-8 consoles (ledger R-A15).
- Emit UTF-8 from `check-speckit-runtime.ps1` when output is redirected, keeping the hook's
  staged-snapshot audit pipe encoding-symmetric.
- Reject operator inputs or saved RunState values that rebind a workflow run to a second
  feature, on fresh runs and resumes (ledger R-B17).
- Replace the loose stage-plan-prep contract tokens with one anchored multi-line block and
  lock the new hook and engine behaviors with contract invariants (ledger R-A16).

## Why This Update Exists

An independent read-only verification of the R2 partial repair (`e4fa153..ccb7738`) on
2026-07-13 confirmed both PR #3 review-thread fixes, but discovered three adjacent defects:

1. The R0 personal-data gate silently passed staged `履歷/` paths on the owner's zh-TW
   machine: git emits raw UTF-8 path bytes, the hook decoded them through the inherited
   console codepage (CP950), the protected-directory regex never matched, and the gate
   reported success. Hosted CI stayed green only because the runner console is UTF-8, so
   the full governance suite read 328 passed on CI while the owner's machine read
   326 passed, 2 failed.
2. `run-workflow.ps1 -Inputs "feature=<other>"` silently overrode the validated `-Feature`,
   anchoring RunState at one feature while every templated step targeted another. The same
   rebind was reachable on resume through a tampered or pre-guard `state.json`.
3. The `sdd-pipeline-plan-feature-context` invariant could not detect a revert of the exact
   stage-plan-prep `args` line: its token appeared six times in `workflow.yml`, five of
   which predate the R-B06 fix.

## Scope

- Repair the three verification findings; record them in the repair ledger as R-A15,
  R-B17, and R-A16 with R-B18 (sibling `-FeatureDir` boundary tiers and non-plan agent
  handoffs) recorded as open follow-up work.
- No workflow schema, constitution rule, agent surface, or workspace layout changes.
- R-B06 remains `IN_PROGRESS` (RunState relocation and canonical feature-ID allocation are
  untouched by this batch); R-B16 remains `DECIDED`.

## Affected Paths

| Path | Change |
|------|--------|
| `.githooks/pre-commit.ps1` | Force UTF-8 decoding of native git output before any staged-path evaluation; fail closed if the encoding cannot be set. |
| `studio/scripts/powershell/check-speckit-runtime.ps1` | Emit UTF-8 when output is redirected so parent processes decode audit messages losslessly. |
| `studio/scripts/powershell/workflow-engine.ps1` | Reject operator `feature` input overrides before run-state handling; reject resuming a RunState whose saved `inputs.feature` differs from the anchored run feature; backfill legacy states. |
| `studio/runtime/shared-runtime-contract.json` | Add hook-encoding token, `workflow-engine-feature-input-guard` invariant, and the anchored multi-line stage-plan-prep token. |
| `studio/tests/pre-commit.Tests.ps1` | Add a CP437-console regression test for the personal-data gate. |
| `studio/tests/workflow-engine.Tests.ps1` | Add fresh-run override, redundant-equal input, resume-tamper, and resume-override regression tests. |

## Impact

- The personal-data gate now rejects protected staged paths independent of the console
  codepage; the previously environment-dependent test pair passes on the CP950 machine.
- A workflow run keeps exactly one feature context across fresh runs and resumes; the
  override and tamper paths fail closed with explicit errors.
- Reverting the stage-plan-prep feature binding now turns the shared runtime audit red
  even when the powershell-yaml-gated Pester assertions are skipped.
- Known residuals recorded in the ledger, not silently absorbed: audit child output on a
  non-UTF-8 console garbles non-ASCII failure text only when not redirected (fail-closed
  either way); R-B18 boundary-tier convergence for sibling `setup-*` scripts and non-plan
  operator handoffs remains open for the R2/R3 batches.

## Impact Reconciliation

| Target | Impact | Disposition | Evidence |
|--------|--------|-------------|----------|
| `studio/runtime/shared-runtime-contract.json` | `must_review` | `updated` | Added one invariant and two token hardenings for the new behaviors. |
| `.githooks/pre-commit.ps1` | `must_review` | `updated` | UTF-8 decoding is forced before staged-path evaluation with a fail-closed catch. |
| `studio/scripts/powershell/check-speckit-runtime.ps1` | `must_review` | `updated` | Redirected-output UTF-8 emission keeps the staged-snapshot audit pipe symmetric. |
| `studio/scripts/powershell/workflow-engine.ps1` | `must_review` | `updated` | Feature-rebind guards on the fresh and resume paths. |
| `studio/tests/pre-commit.Tests.ps1` | `must_review` | `updated` | Codepage regression coverage added. |
| `studio/tests/workflow-engine.Tests.ps1` | `must_review` | `updated` | Override and resume-tamper regression coverage added. |
| `.claude/agents/*.md` | `must_update` | `reviewed-no-change` | No agent source changed in this batch; mirrors remain in sync. |
| `studio/constitution/constitution.md` | `maybe_review` | `reviewed-no-change` | Fixes implement existing gate and boundary rules; no governance policy added. |
| `WORKSPACE_STRUCTURE.md` | `maybe_review` | `reviewed-no-change` | No path or component added, removed, or relocated. |
| `studio/QUICKSTART.md` | `maybe_review` | `reviewed-no-change` | No user-facing command surface or prerequisite changed. |

## Validation

- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json`: `VALID=true`,
  0 errors, 0 warnings.
- Full governance Pester suite on the owner's CP950 machine: 333 passed, 0 failed,
  0 skipped (baseline before this batch on the same machine: 326 passed, 2 failed).
- Simulated revert of the stage-plan-prep `args` line no longer satisfies the anchored
  contract token.
- Adversarial patch review (two independent reviewers) found one defect (resume-path
  feature rebind), which was fixed and regression-tested inside this batch.

## Merge Notes

- This batch does not promote the experimental workflow runtime.
- Backfill Related Commits and flip Status to Ready in the follow-up accounting commit,
  after hosted validation of the pushed SHA.

## Follow-ups

- R-B18: converge the three `-FeatureDir` boundary tiers (strong plan/prerequisites,
  shape-only readiness/tasks/analyze/implement, none clarify) and decide whether non-plan
  operator handoffs should carry the explicit feature option.
- Consider forcing UTF-8 output in remaining interactive audit paths if non-ASCII
  diagnostics become load-bearing.
- Complete the R-B06 remainder (RunState relocation, canonical feature-ID allocation).
