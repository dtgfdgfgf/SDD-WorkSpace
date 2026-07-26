# Mainline Update Note: R6 Residual Ledger Truth Restoration

**Date**: 2026-07-21
**Source Branch**: `feature/wave-3-security-and-workflows`
**Target Branch**: `main`
**Status**: Ready
**Related Commits**: `180abc05b8eaaa6fb32a753e81931f14e10ef726`
**Related PR**: https://github.com/dtgfdgfgf/SDD-WorkSpace/pull/3
**Reconciliation Status**: Closed
**Validation Scope**: Batch

## Summary

- Apply the append-only R-F04 status clarification after owner-authorized entry-plan commit
  `bab1ce93aec28819a0c68a3ed7f6e85d3de53442`.
- Preserve R-F04 as unimplemented while distinguishing `DECIDED` from `COMPLETED` and
  `DISPOSITIONED`.
- Close bounded truth-restoration accounting under the owner-selected explicit-scope contract,
  then resume the read-only residual audit from the reconciled fold.

## Why This Update Exists

The original owner decision records R-F04 and R-H15 as `DECIDED`: the agent-skills export/install
capability is to be retired, but that decision does not mean the retirement has been implemented.
The later RB-4 record calls R-F04 `OPEN` because RB-4 removed only an upgrade caller and retained
the rest of the capability chain. The final ledger summary nevertheless reports counts that require
R-F04 to remain `DECIDED`.

The two readings produce different folds. Treating R-F04 as `DECIDED` yields 76 COMPLETED,
45 OPEN, 6 DECIDED, and 1 IN_PROGRESS. Treating the later `OPEN` row as authoritative yields
76 COMPLETED, 46 OPEN, 5 DECIDED, and 1 IN_PROGRESS. The owner selected the first semantic result
on 2026-07-21. Entry-plan commit `bab1ce93aec28819a0c68a3ed7f6e85d3de53442`
precedes the new authoritative latest-status row that supersedes only the later RB-4 `OPEN` label.
Implementation `180abc05b8eaaa6fb32a753e81931f14e10ef726` now supplies the real identity. A
drift-stop also exposed that the handoff's no-scope command conflicts with R-A20; owner Choice A
preserves explicit Batch and Aggregate scopes. The exact accounting tree supplies the final gates
below without relabeling the failed no-scope diagnostic as green.

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
| `docs/sdd-workspace-repair-inventory-and-update-plan-2026-07-12_zhTW.md` | Append the authoritative R-F04 DECIDED clarification after the committed entry plan |
| `docs/sdd-workspace-wave-3-remediation-plan-2026-07-14_zhTW.md` | Record the post-plan implementation chronology and remaining accounting boundary |
| `docs/README.md` | Keep the ledger index truthful during plan, implementation, and accounting states |
| `docs/mainline-updates/README.md` | Index this dedicated note with matching state |
| `docs/mainline-updates/2026-07-21-r6-residual-ledger-truth-restoration.md` | Preserve the drift chronology and Batch evidence |

## Impact

- The authoritative R-F04 status is unambiguous without rewriting the historical RB-4 record.
- R-F04 and R-H15 remain unimplemented, and all other finding dispositions remain unchanged.
- R6 remains `IN_PROGRESS`; the branch remains `NOT READY TO MERGE`.

## Impact Reconciliation

| Target | Impact | Disposition | Evidence |
|--------|--------|-------------|----------|
| `docs/sdd-workspace-repair-inventory-and-update-plan-2026-07-12_zhTW.md` | `must_update` | `updated` | Version 1.25.0 records implementation identity, owner Choice A, Ready/Closed accounting, exact-tree gates, and retained R-E09 obligations. |
| `docs/sdd-workspace-wave-3-remediation-plan-2026-07-14_zhTW.md` | `must_update` | `updated` | Version 1.17.0 records the scope-aware gate decision and final accounting without changing any finding disposition. |
| `docs/README.md` | `must_update` | `updated` | The index reflects v1.25.0, 76/45/6/1, explicit-scope acceptance, and residual-audit resumption. |
| `docs/mainline-updates/README.md` | `must_update` | `updated` | The index matches this Ready note and its bounded Batch scope. |
| `studio/constitution/constitution.md` | `must_review` | `reviewed-no-change` | Section 2.1 requires this committed owner-authorized plan before implementation. |
| `studio/runtime/shared-runtime-contract.json` | `must_review` | `reviewed-no-change` | No finding closure or runtime invariant changes in this accounting-only truth restoration. |

## Validation

Observed focused evidence:

- The hardened section-bounded fold reports parent `bab1ce9` as `VALID=false`: R-F04 has structured
  status `DECIDED` followed by direct-status records claiming `OPEN`.
- The proposed implementation tree reports `VALID=true` with 0 ambiguities and uniquely records
  R-F04 and R-H15 as `DECIDED`; it folds 128 findings to 76 COMPLETED, 45 OPEN, 6 DECIDED, and
  1 IN_PROGRESS.
- Both trees parse to 128 findings and severity counts 8/31/51/38. Inventory parity and historical
  Section 22 parity are exact, and the implementation deletes 0 finding rows.
- R-F04 and R-H15 remain neither `COMPLETED` nor `DISPOSITIONED`; the other 126 findings retain
  their previous dispositions.

Final exact-tree evidence:

- Runtime reports `VALID=true`, 0 errors, 0 warnings, and 18 of 18 historical records valid.
- The complete governance suite reports 747 passed, 0 failed, 0 skipped, and 0 not run.
- Explicit Batch from `6b749a1f153dc88412714db0ed6d8708170c5936` reports `VALID=true`,
  0 errors, 0 warnings, and 5 changed paths.
- Explicit Aggregate returns exactly one `aggregate-note-not-ready` for the canonical umbrella.
- The no-scope drift diagnostic truthfully remains nonzero with one `arguments` and five
  `branch-evidence-coverage-missing` records. Those coverage paths remain under R-E09/Aggregate.
- `git diff --check` passes; detached candidate and formal branch use the same tree.

## Merge Notes

- This note is `Ready` with reconciliation `Closed` only for the R-F04 status/count truth
  restoration. It does not implement or close R-F04/R-H15, and it does not close R-E09.
- The batch does not authorize R-F04 retirement, workflow promotion, push, or merge.
- `sdd-pipeline` remains experimental, default-disabled, and execution-denied.

## Follow-ups

- Resume the read-only R6 residual disposition audit from the reconciled fold.
- Resolve the five named Aggregate coverage obligations only through the canonical umbrella and
  R-E09 work; do not absorb them into this Batch.
