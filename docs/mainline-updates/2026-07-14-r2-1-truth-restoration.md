# Mainline Update Note: R2.1 Truth Restoration

**Date**: 2026-07-14
**Source Branch**: `feature/wave-3-security-and-workflows`
**Target Branch**: `main`
**Status**: Ready
**Related Commits**: `2b7681d`
**Related PR**: https://github.com/dtgfdgfgf/SDD-WorkSpace/pull/3
**Reconciliation Status**: Closed

## Summary

- Reopen ledger items R-B02 and R-B05 from `COMPLETED` to `IN_PROGRESS`: the 2026-07-14 governance
  re-review reproduced counterexamples that refute their closure claims.
- Enter the re-review's twelve RVR findings into the single open-findings ledger as nine new items
  (R-A17, R-A18, R-A19, R-B19, R-B20, R-B21, R-B22, R-C08, R-F06) plus the two reopenings; the ledger
  grows from 114 to 123 findings (machine recount: Critical 8 / High 28 / Medium 49 / Low 38).
- Demote `docs/mainline-updates/2026-07-14-r2-workflow-engine-integrity.md` from Ready to Draft and
  add a Revalidation section, per the note state machine's Reopened rule.
- No runtime, agent, workflow, schema, hook, or test change: this batch only restores accounting
  truth so subsequent remediation batches build on an honest baseline.

## Why This Update Exists

The R2 engine-integrity batch (commit `6a53f66`) claimed `COMPLETED` for R-B02 (false-completion
closure) and R-B05 (runner fail-closed authorization) and shipped a `Ready` mainline note. The
2026-07-14 governance re-review reproduced two counterexamples that refute those claims:

- **RVR-01 / R-B02.** The terminal `no-pending-tasks` postcondition only checks for the absence of an
  unchecked `T\d+` marker. It does not persist the baseline task-ID inventory or require it to survive
  completion. Replacing `tasks.md` with an arbitrary non-empty non-task file after the Implement step
  arrives still resumes to `completed` (reproduced locally).
- **RVR-03 / R-B05.** The runner casts `defaultEnabled` / `enabled` with `[bool]`, and PowerShell
  `[bool]'false'` is `True`; a missing `state.json` falls back to `defaultEnabled` rather than failing
  closed; the runner does not apply `catalog.schema.json` / `state.schema.json` (reproduced locally).

The constitution's Surface Truthfulness rule and the repair ledger's own maintenance rules require a
refuted `COMPLETED` claim to be reopened rather than left standing. Doing this before any further
remediation prevents "fixing on top of a false green".

## Scope

- Accounting only. Ledger status, finding registration, and note status are corrected to match the
  reproduced evidence.
- The remaining R2 engine-integrity items (R-B01, R-B03, R-B04, R-B06 remainder, R-B10 through R-B16)
  are not refuted and remain implemented; only R-B02 and R-B05 reopen.
- The full remediation sequence for the twelve findings is planned in
  `docs/sdd-workspace-wave-3-remediation-plan-2026-07-14_zhTW.md` (batches RB-1 through RB-5 plus R6);
  this note does not implement any of it.

## Affected Paths

| Path | Change |
|------|--------|
| `docs/sdd-workspace-repair-inventory-and-update-plan-2026-07-12_zhTW.md` | Ledger v1.6.0: reopen R-B02/B05, add nine RVR findings, recount, new section 16. |
| `docs/mainline-updates/2026-07-14-r2-workflow-engine-integrity.md` | Ready to Draft with a Revalidation section. |
| `docs/mainline-updates/README.md` | Index the R2.1 note; mark the engine-integrity note reopened. |
| `docs/sdd-workspace-wave-3-remediation-plan-2026-07-14_zhTW.md` | Referenced plan (added in the prior planning step). |
| `docs/README.md` | Index the remediation plan and updated ledger scope. |

## Impact

- The single open-findings ledger again reflects reality: nothing is marked `COMPLETED` that a
  reproduced counterexample refutes.
- No behavior, gate, test, or contract changes; the runtime is byte-identical to `6a53f66` plus the
  earlier verification-hardening commit. The canonical audit and full Pester suite are unchanged.
- Downstream batches (RB-1 onward) have an accurate starting inventory and cannot inherit a false
  green.

## Impact Reconciliation

| Target | Impact | Disposition | Evidence |
|--------|--------|-------------|----------|
| `docs/mainline-updates/*` | `doc_change` | `updated` | Note demotion, Revalidation, and R2.1 index entry recorded. |
| `docs/sdd-workspace-repair-inventory-and-update-plan-2026-07-12_zhTW.md` | `doc_change` | `updated` | Ledger reopenings, nine new findings, machine recount in section 16. |
| `studio/scripts/powershell/**`, `studio/runtime/**`, `studio/workflows/**`, `studio/tests/**` | n/a | `reviewed-no-change` | Accounting-only batch; no runtime/test bytes changed. |

## Validation

- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json`: `VALID=true`, 0 errors, 0 warnings.
- `pwsh ./studio/scripts/powershell/validate-mainline-notes.ps1 -BaseRef origin/main -HeadRef HEAD -RequireReady -Json`: `VALID=true`.
- Ledger section 3 machine recount: 123 rows, no duplicate IDs, Critical 8 / High 28 / Medium 49 / Low 38.
- Full governance Pester suite unchanged from the R2 batch (no test or runtime files touched).

## Merge Notes

- This is a documentation/accounting batch; it does not promote the experimental workflow runtime and
  does not by itself make the branch mergeable. The branch remains NOT READY TO MERGE per the
  2026-07-14 re-review until batches RB-1 through R6 close.
- Implementation commit `2b7681d`; all machine gates green (audit VALID 0/0, notes validator VALID 0/0).

## Follow-ups

- Execute remediation batches RB-1 (RVR-01/02/03), RB-2 (RVR-04/07), RB-3 (RVR-05/06),
  RB-4 (RVR-08/09/11), RB-5 (RVR-10/12), then R6 fresh-fixture end-to-end and merge.
