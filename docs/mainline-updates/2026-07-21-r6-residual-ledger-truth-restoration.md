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

- Apply the append-only R-F04 status clarification after owner-authorized entry-plan commit
  `bab1ce93aec28819a0c68a3ed7f6e85d3de53442`.
- Preserve R-F04 as unimplemented while distinguishing `DECIDED` from `COMPLETED` and
  `DISPOSITIONED`.
- Keep the R6 residual audit paused until the implementation commit identity and exact-tree
  accounting gates are recorded.

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
This note remains Draft because the implementation commit identity and final accounting gates do
not yet exist.

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
| `docs/sdd-workspace-repair-inventory-and-update-plan-2026-07-12_zhTW.md` | `must_update` | `pending` | The latest-status clarification is applied; implementation identity and final accounting evidence remain pending. |
| `docs/sdd-workspace-wave-3-remediation-plan-2026-07-14_zhTW.md` | `must_update` | `pending` | The post-plan implementation is recorded; final exact-tree validation remains pending. |
| `docs/README.md` | `must_update` | `pending` | The implementation index now reflects v1.24.0 and the 76/45/6/1 fold; final Ready/Closed accounting remains pending. |
| `docs/mainline-updates/README.md` | `must_update` | `pending` | Must match this note when it can truthfully become Ready. |
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

Pending final evidence:

- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json` reports `VALID=true`,
  0 errors, and 0 warnings.
- The complete governance suite passes without reducing the 747-test baseline.
- Batch validation from the immutable pre-plan base passes with 0 errors and 0 warnings.
- Aggregate validation returns only the expected canonical umbrella blocker.
- `git diff --check` and clean-worktree checks pass.

## Merge Notes

- This note remains `Draft`, `TBD`, and reconciliation `Open` until the implementation commit is
  identifiable and a later accounting commit passes the exact-tree gates.
- The batch does not authorize R-F04 retirement, workflow promotion, push, or merge.
- `sdd-pipeline` remains experimental, default-disabled, and execution-denied.

## Follow-ups

- Record the real implementation hash and final gate results in a separate accounting commit.
- Resume the read-only R6 residual disposition audit only after the ledger has one authoritative
  fold and the truth-restoration Batch is fully validated.
