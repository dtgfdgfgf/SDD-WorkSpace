# Mainline Update Note: R6-A2 through A5 Direct Repairs and Wave-4 Dispositions

**Date**: 2026-07-23
**Source Branch**: `feature/wave-3-security-and-workflows`
**Target Branch**: `main`
**Status**: Draft
**Related Commits**: `814cc6169e6d1bf9167ce91249dbd58ac548674d`, `be5fb24fd79a47d8f0db9f61be2a747d06b29088`, `32a58e653cc4b541db88b23ad4b90fd7b81007a5`, `a45b7d33a59dd41d7765d29626bf43d2adb02cca`
**Related PR**: https://github.com/dtgfdgfgf/SDD-WorkSpace/pull/3
**Reconciliation Status**: Open
**Validation Scope**: Batch

## Summary

- Preserve the committed R6-A2, R6-A3 and R6-A4 implementation candidates without prematurely
  changing their eleven finding statuses.
- Register Medium R-E13 as `OPEN` before implementing trigger-bearing disposition authority.
- Require every future Wave-4 `DISPOSITIONED` record to carry its exact owner-approved re-entry
  trigger inside the canonical machine record.
- Keep both R6 umbrella notes Draft and keep `sdd-pipeline` experimental, default-disabled and
  execution-denied.

## Why This Update Exists

The A2 through A4 implementation commits now exist, but evidence-backed status accounting and the
35 owner-approved Wave-4 dispositions belong to R6-A5. Preflight found that the current canonical
status-entry schema cannot represent the mandatory re-entry trigger: it accepts only `id` and
`status`. The validator consequently accepts a triggerless `DISPOSITIONED` transition while
rejecting the trigger-bearing form required by the committed owner authorization.

Plan `a45b7d33a59dd41d7765d29626bf43d2adb02cca` classifies that independent future-transition gap
as new Medium R-E13. Revision 7 registers R-E13 as `OPEN` before implementation. This does not
reopen R-E11 because revisions 1 through 6 contain no disposition entry and their ledger, fold,
index and history guarantees remain valid.

## Scope

In scope:

- The eleven R6-A2 through R6-A4 direct-repair candidates.
- R-E13 conditional status-entry shape, exact 35-ID trigger mapping and fail-closed mutations.
- Two later machine revisions that separately record evidence-backed completions and conditional
  Wave-4 dispositions.
- A dedicated Batch note and synchronized status and note indexes.

Out of scope:

- Changes under `projects/` or `learning/`.
- Workflow promotion or execution authorization.
- R6-A6, Aggregate acceptance, R-E09 completion, R-J03 completion, merge or post-merge claims.
- Push, force-push, history rewrite or PR-thread resolution.

## Affected Paths

| Path or group | Change |
|---|---|
| `docs/sdd-workspace-wave-3-remediation-plan-2026-07-14_zhTW.md` | Commit the owner-authorized R-E13 registration and A5 accounting sequence |
| `docs/sdd-workspace-repair-inventory-and-update-plan-2026-07-12_zhTW.md` | Register R-E13 as OPEN in revision 7; later append evidence-backed completion and disposition records |
| `docs/README.md` | Keep the machine finding-status marker synchronized |
| `docs/mainline-updates/README.md` | Keep this note and the broad R6 note state visible |
| `docs/mainline-updates/2026-07-21-r6-conservative-non-promotion-convergence.md` | Preserve the broader R6-A6 and merge-checkpoint boundary while recording R-E13 |
| `studio/runtime/finding-status-record.schema.json` | Future conditional `reentryTrigger` shape; unchanged by registration |
| `studio/scripts/powershell/validate-finding-status-ledger.ps1` | Future exact per-ID trigger validation; unchanged by registration |
| `studio/runtime/shared-runtime-contract.json` and tests | Future revert-sensitive trigger contract; unchanged by registration |
| R6-A2 through R6-A4 implementation paths | Existing implementation candidates whose statuses remain OPEN until final accounting |

## Impact

- Revision 7 contains only R-E13 `OPEN`, producing 132 findings with severity 8 Critical,
  32 High, 53 Medium and 39 Low.
- The current fold is 83 `COMPLETED`, 43 `OPEN`, 5 `DECIDED`, 1 `IN_PROGRESS` and
  0 `DISPOSITIONED`.
- The eleven A2 through A4 candidates and R-E13 remain `OPEN`; no Wave-4 item is dispositioned by
  this registration.
- The permitted post-A5 fold is 95 `COMPLETED`, 1 `OPEN`, 0 `DECIDED`, 1 `IN_PROGRESS` and
  35 `DISPOSITIONED`, only after implementation and exact-tree gates pass.

## Impact Reconciliation

| Target | Impact | Disposition | Evidence |
|---|---|---|---|
| `docs/sdd-workspace-repair-inventory-and-update-plan-2026-07-12_zhTW.md` | `must_update` | `updated` | Revision 7 registers only R-E13 as OPEN and preserves revisions 1 through 6. |
| `docs/sdd-workspace-wave-3-remediation-plan-2026-07-14_zhTW.md` | `must_update` | `updated` | Version 1.25.0 and plan `a45b7d33a59dd41d7765d29626bf43d2adb02cca` define the prospective sequence. |
| `docs/README.md` | `must_update` | `updated` | Marker records revision 7, 132 findings and fold 83/43/5/1/0. |
| `docs/mainline-updates/README.md` | `must_update` | `updated` | This dedicated note is indexed as Draft. |
| `studio/runtime/finding-status-record.schema.json` | `must_update` | `pending` | R-E13 implementation must add the conditional trigger-bearing entry shape. |
| `studio/scripts/powershell/validate-finding-status-ledger.ps1` | `must_update` | `pending` | R-E13 implementation must enforce the exact 35-ID mapping. |
| `studio/runtime/shared-runtime-contract.json` | `must_update` | `pending` | R-E13 implementation must add a revert-sensitive invariant. |

## Validation

Registration gates:

- `git diff --check`
- `pwsh ./studio/scripts/powershell/validate-finding-status-ledger.ps1 -Json`
- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json`
- Mainline-note structural validation without a Ready requirement.

Required before this note may become `Ready`:

- Old implementation rejects a legitimate trigger-bearing entry; repaired implementation accepts
  the exact authorized entry and rejects all missing, type, blank, generic, mismatch, swap and
  unauthorized mutations.
- Complete governance suite reports at least 958 passed and 0 failed.
- Runtime reports `VALID=true`, 0 errors and 0 warnings.
- Finding history has the exact consecutive registration, completion and disposition revisions,
  132 findings, severity 8/32/53/39 and fold 95/1/0/1/35.
- Explicit Batch readiness from `b3e7c15c2e70aebf3bd40b5a73f24285de507476` reports
  `VALID=true`, 0 errors and 0 warnings.
- Aggregate readiness fails only with the canonical umbrella blocker.
- `git diff --check`, workflow denial and clean exact-tree worktree verification pass.

## Merge Notes

- This note remains Draft with reconciliation Open until the trigger implementation, completion
  and disposition accounting commit, and final note-only commit exist.
- The broad R6 convergence note and canonical Wave-3 umbrella remain Draft and non-authorizing.
- PR #3 remains `NOT READY TO MERGE`; this batch does not authorize promotion, push or merge.

## Follow-ups

- Implement R-E13 only after this registration commit exists.
- Append completion and disposition records only after every required negative and exact-tree gate
  passes.
- Continue R6-A6 as a separate checkpoint after this bounded A2-A5 note is truthfully finalized.
