# Mainline Update Note: R6 Residual Ledger Truth Restoration

**Date**: 2026-07-21
**Source Branch**: `feature/wave-3-security-and-workflows`
**Target Branch**: `main`
**Status**: Draft
**Related Commits**: `TBD`
**Related PR**: https://github.com/dtgfdgfgf/SDD-WorkSpace/pull/3
**Reconciliation Status**: Open
**Validation Scope**: Batch

## Summary

- Record the owner-authorized prospective plan for resolving the R-F04 status/count contradiction.
- Preserve R-F04 as unimplemented while distinguishing `DECIDED` from `COMPLETED` and
  `DISPOSITIONED`.
- Keep the R6 residual audit paused until a post-plan implementation and accounting sequence
  restores one authoritative ledger fold.

## Why This Update Exists

The original owner decision records R-F04 and R-H15 as `DECIDED`: the agent-skills export/install
capability is to be retired, but that decision does not mean the retirement has been implemented.
The later RB-4 record calls R-F04 `OPEN` because RB-4 removed only an upgrade caller and retained
the rest of the capability chain. The final ledger summary nevertheless reports counts that require
R-F04 to remain `DECIDED`.

The two readings produce different folds. Treating R-F04 as `DECIDED` yields 76 COMPLETED,
45 OPEN, 6 DECIDED, and 1 IN_PROGRESS. Treating the later `OPEN` row as authoritative yields
76 COMPLETED, 46 OPEN, 5 DECIDED, and 1 IN_PROGRESS. The owner selected the first semantic result
on 2026-07-21. This Draft note records only the plan; it does not claim that the later row has
already been superseded.

## Scope

In scope:

- R-F04 status/count truth restoration only.
- Append-only ledger and remediation-plan clarification after a committed plan.
- Deterministic old/new folding evidence and final governance gates.

Out of scope:

- Implementing the R-F04/R-H15 retirement.
- Closing, deferring, accepting, or otherwise changing any residual finding.
- `projects/`, `learning/`, workflow promotion, Aggregate acceptance, push, merge, or PR-thread
  resolution.

## Affected Paths

| Path | Change |
|------|--------|
| `docs/sdd-workspace-repair-inventory-and-update-plan-2026-07-12_zhTW.md` | Record entry plan, then append the authoritative R-F04 status clarification after the plan commit |
| `docs/sdd-workspace-wave-3-remediation-plan-2026-07-14_zhTW.md` | Record owner decision, required sequence, and validation boundary |
| `docs/README.md` | Keep the ledger index truthful during plan, implementation, and accounting states |
| `docs/mainline-updates/README.md` | Index this dedicated note with matching state |
| `docs/mainline-updates/2026-07-21-r6-residual-ledger-truth-restoration.md` | Preserve the drift chronology and Batch evidence |

## Impact

- The prospective target is one unambiguous R-F04 status without rewriting the historical RB-4
  record.
- R-F04 and R-H15 remain unimplemented, and all other finding dispositions remain unchanged.
- R6 remains `IN_PROGRESS`; the branch remains `NOT READY TO MERGE`.

## Impact Reconciliation

| Target | Impact | Disposition | Evidence |
|--------|--------|-------------|----------|
| `docs/sdd-workspace-repair-inventory-and-update-plan-2026-07-12_zhTW.md` | `must_update` | `pending` | Requires a post-plan implementation commit that appends the R-F04 latest-status clarification. |
| `docs/sdd-workspace-wave-3-remediation-plan-2026-07-14_zhTW.md` | `must_update` | `pending` | Requires the implementation and final validation result after this committed entry plan. |
| `docs/README.md` | `must_update` | `pending` | Requires final ledger version and folded-state summary after implementation. |
| `docs/mainline-updates/README.md` | `must_update` | `pending` | Must match this note when it can truthfully become Ready. |
| `studio/constitution/constitution.md` | `must_review` | `reviewed-no-change` | Section 2.1 requires this committed owner-authorized plan before implementation. |
| `studio/runtime/shared-runtime-contract.json` | `must_review` | `reviewed-no-change` | No finding closure or runtime invariant changes in this accounting-only truth restoration. |

## Validation

Planned evidence:

- A section-bounded parser rejects the pre-implementation tree as ambiguous because the R-F04
  later status and final fold disagree.
- The proposed implementation tree uniquely folds 128 findings to 76 COMPLETED, 45 OPEN,
  6 DECIDED, and 1 IN_PROGRESS.
- R-F04 and R-H15 remain neither `COMPLETED` nor `DISPOSITIONED`; every other finding retains its
  previous disposition.
- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json` reports `VALID=true`,
  0 errors, and 0 warnings.
- The complete governance suite passes without reducing the 747-test baseline.
- Batch validation from the immutable pre-plan base passes with 0 errors and 0 warnings.
- Aggregate validation returns only the expected canonical umbrella blocker.
- `git diff --check` and clean-worktree checks pass.

## Merge Notes

- This note remains `Draft`, `TBD`, and reconciliation `Open` until the post-plan implementation,
  accounting commit, and exact-tree gates exist.
- The batch does not authorize R-F04 retirement, workflow promotion, push, or merge.
- `sdd-pipeline` remains experimental, default-disabled, and execution-denied.

## Follow-ups

- Apply the bounded truth-restoration implementation only after this plan is committed.
- Resume the read-only R6 residual disposition audit only after the ledger has one authoritative
  fold and the truth-restoration Batch is fully validated.
