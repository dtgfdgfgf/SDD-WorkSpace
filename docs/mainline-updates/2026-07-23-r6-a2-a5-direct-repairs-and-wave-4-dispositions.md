# Mainline Update Note: R6-A2 through A5 Direct Repairs and Wave-4 Dispositions

**Date**: 2026-07-23
**Source Branch**: `feature/wave-3-security-and-workflows`
**Target Branch**: `main`
**Status**: Ready
**Related Commits**: plan `a45b7d33a59dd41d7765d29626bf43d2adb02cca`; registration `97f63b15ab97f506403a9a4a55a119f7f9c7c310`; R6-A2 `814cc6169e6d1bf9167ce91249dbd58ac548674d`; R6-A3 `be5fb24fd79a47d8f0db9f61be2a747d06b29088`; R6-A4 `32a58e653cc4b541db88b23ad4b90fd7b81007a5`; trigger implementation `5e99ad9569cc0212212a0191193702c25f6af052`; accounting `05fe6f16ec334263bc1432e18ecb4a648a6dc38b`
**Related PR**: https://github.com/dtgfdgfgf/SDD-WorkSpace/pull/3
**Reconciliation Status**: Closed
**Validation Scope**: Batch

## Summary

- Record the twelve evidence-backed R6-A2 through A5 completions in revision 8 without absorbing
  any unrelated finding.
- Record exactly 35 owner-approved Wave-4 dispositions in revision 9, each with its exact re-entry
  trigger inside the canonical machine record.
- Bind the completion and disposition records to accounting commit
  `05fe6f16ec334263bc1432e18ecb4a648a6dc38b` and close this bounded Batch reconciliation.
- Keep both R6 umbrella notes Draft and keep `sdd-pipeline` experimental, default-disabled and
  execution-denied.

## Why This Update Exists

The A2 through A4 implementation commits existed before accounting, but evidence-backed status
accounting and the 35 owner-approved Wave-4 dispositions belong to R6-A5. Preflight found that the
then-current canonical status-entry schema could not represent the mandatory re-entry trigger: it
accepted only `id` and `status`. The then-current validator consequently accepted a triggerless
`DISPOSITIONED` transition while rejecting the trigger-bearing form required by the committed
owner authorization.

Plan `a45b7d33a59dd41d7765d29626bf43d2adb02cca` classifies that independent future-transition gap
as new Medium R-E13. Revision 7 registers R-E13 as `OPEN` before implementation. This does not
reopen R-E11 because revisions 1 through 6 contain no disposition entry and their ledger, fold,
index and history guarantees remain valid.

Registration `97f63b15ab97f506403a9a4a55a119f7f9c7c310` precedes trigger implementation
`5e99ad9569cc0212212a0191193702c25f6af052`. The latter adds the conditional entry shape, exact
35-ID ordinal mapping, strict trigger comparison and discriminating negative tests without changing
revision 7. The clean implementation tree reports 986 governance tests passed with 0 failed and
canonical runtime `VALID=true` with 0 errors and 0 warnings.

Revision 8 records exactly the eleven A2 through A4 completions plus R-E13. Revision 9 records the
authorized thirty `OPEN` and five `DECIDED` findings as conditionally `DISPOSITIONED`. Accounting
commit `05fe6f16ec334263bc1432e18ecb4a648a6dc38b` contains those exact bytes. Its committed tree
reports canonical runtime `VALID=true` with 0 errors and 0 warnings, plus nine consecutive valid
status records, 132 findings, severity 8/32/53/39 and fold 95/1/0/1/35. This note is Ready/Closed
only for the bounded Batch scope; it does not satisfy Aggregate, R6-A6, merge or post-merge gates.

## Scope

In scope:

- The eleven R6-A2 through R6-A4 direct-repair candidates.
- R-E13 conditional status-entry shape, exact 35-ID trigger mapping and fail-closed mutations.
- Two consecutive machine revisions that separately record evidence-backed completions and
  conditional Wave-4 dispositions.
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
| `docs/sdd-workspace-repair-inventory-and-update-plan-2026-07-12_zhTW.md` | Preserve revision 7, append completion revision 8 and trigger-bearing disposition revision 9 |
| `docs/README.md` | Synchronize the machine finding-status marker to revision 9 |
| `docs/mainline-updates/README.md` | Keep this note and the broad R6 note state visible |
| `docs/mainline-updates/2026-07-21-r6-conservative-non-promotion-convergence.md` | Preserve the broader R6-A6 and merge-checkpoint boundary while recording R-E13 |
| `studio/runtime/finding-status-record.schema.json` | Conditionally require `reentryTrigger` only for a disposition entry |
| `studio/scripts/powershell/validate-finding-status-ledger.ps1` | Enforce the exact 35-ID trigger mapping and strict record shape |
| `studio/runtime/shared-runtime-contract.json` and tests | Bind the schema, mapping, ordinal comparison and rejection contract against revert |
| R6-A2 through R6-A4 implementation paths | Committed implementations backing the eleven direct-repair completions in revision 8 |

## Impact

- Revision 8 completes exactly twelve findings and has interim fold 95 `COMPLETED`, 31 `OPEN`,
  5 `DECIDED`, 1 `IN_PROGRESS` and 0 `DISPOSITIONED`.
- Revision 9 conditionally dispositions exactly 35 findings and has fold 95 `COMPLETED`, 1 `OPEN`,
  0 `DECIDED`, 1 `IN_PROGRESS` and 35 `DISPOSITIONED`.
- Inventory remains 132 with severity 8 Critical, 32 High, 53 Medium and 39 Low.
- R-E09 remains `IN_PROGRESS`; R-J03 remains `OPEN`. Neither terminal item is absorbed here.

## Impact Reconciliation

| Target | Impact | Disposition | Evidence |
|---|---|---|---|
| `docs/sdd-workspace-repair-inventory-and-update-plan-2026-07-12_zhTW.md` | `must_update` | `updated` | Revisions 8 and 9 preserve revisions 1 through 7 and produce the authorized 95/1/0/1/35 fold. |
| `docs/sdd-workspace-wave-3-remediation-plan-2026-07-14_zhTW.md` | `must_update` | `updated` | Version 1.25.0 and plan `a45b7d33a59dd41d7765d29626bf43d2adb02cca` define the prospective sequence. |
| `docs/README.md` | `must_update` | `updated` | Marker records revision 9, 132 findings and fold 95/1/0/1/35. |
| `docs/mainline-updates/README.md` | `must_update` | `updated` | This dedicated note is indexed as Draft. |
| `studio/runtime/finding-status-record.schema.json` | `must_update` | `updated` | Trigger implementation `5e99ad9569cc0212212a0191193702c25f6af052` adds the conditional trigger-bearing entry shape. |
| `studio/scripts/powershell/validate-finding-status-ledger.ps1` | `must_update` | `updated` | Trigger implementation enforces the exact 35-ID ordinal mapping and fail-closed mutations. |
| `studio/runtime/shared-runtime-contract.json` | `must_update` | `updated` | Trigger implementation adds revert-sensitive schema, mapping and rejection anchors. |

## Validation

Registration gates:

- `git diff --check`
- `pwsh ./studio/scripts/powershell/validate-finding-status-ledger.ps1 -Json`
- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json`
- Mainline-note structural validation without a Ready requirement.

Pre-accounting implementation gates:

- Complete governance suite: 986 passed and 0 failed.
- Canonical runtime: `VALID=true`, 0 errors and 0 warnings.
- Revision-7 committed history: valid consecutive history, 132 findings and fold 83/43/5/1/0.

Required for this note to remain `Ready`:

- Old implementation rejects a legitimate trigger-bearing entry; repaired implementation accepts
  the exact authorized entry and rejects all missing, type, blank, generic, mismatch, swap and
  unauthorized mutations.
- Complete governance suite reports at least 958 passed and 0 failed.
- Runtime reports `VALID=true`, 0 errors and 0 warnings.
- Finding history has the exact consecutive registration, completion and disposition revisions,
  132 findings, severity 8/32/53/39 and fold 95/1/0/1/35.
- Accounting commit `05fe6f16ec334263bc1432e18ecb4a648a6dc38b` remains the exact revision-8 and
  revision-9 authority cited by this note-only finalization.
- Explicit Batch readiness from `b3e7c15c2e70aebf3bd40b5a73f24285de507476` reports
  `VALID=true`, 0 errors and 0 warnings.
- Aggregate readiness fails only with the canonical umbrella blocker.
- `git diff --check`, workflow denial and clean exact-tree worktree verification pass.

## Merge Notes

- This note is Ready with reconciliation Closed for the explicit Batch scope. Any failed
  finalization-tree gate requires truthful demotion and append-only per-ID reversal where evidence
  refutes a status.
- The broad R6 convergence note and canonical Wave-3 umbrella remain Draft and non-authorizing.
- PR #3 remains `NOT READY TO MERGE`; this batch does not authorize promotion, push or merge.

## Follow-ups

- Run all exact-tree gates on the committed note-only finalization and preserve this Ready state
  only while every Batch gate remains green.
- Continue R6-A6 as a separate checkpoint after this bounded A2-A5 note is truthfully finalized.
