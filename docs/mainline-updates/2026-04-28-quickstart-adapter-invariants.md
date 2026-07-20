# Mainline Update Note: QUICKSTART / SDD-GUIDE Adapter Invariants

**Date**: 2026-04-28
**Source Branch**: `main`
**Target Branch**: `main`
**Status**: Merged
**Related Commits**: `ef71fb3e4f37128de98841c12066118e25827295`
**Related PR**: `N/A`
**Reconciliation Status**: Closed

## Summary

- Add two `docInvariants` to `shared-runtime-contract.json` so the v1.8.0 five-file
  bootstrap narrative in `studio/QUICKSTART.md` and `studio/SDD-QUICKSTART-GUIDE.md`
  is locked against silent regression.

## Why This Update Exists

v1.8.0 introduced the synchronized adapter model (AGENTS.md / CLAUDE.md /
.github/copilot-instructions.md) and updated the two onboarding documents to describe
it. The contract did not yet pin the new phrasing, so a future edit could quietly
revert those documents to the pre-v1.8.0 description without the shared runtime audit
catching it.

## Scope

- Contract-only change. No document content was modified.
- No agent, template, hook, or script behavior changes.

## Affected Paths

| Path | Change |
|------|--------|
| `studio/runtime/shared-runtime-contract.json` | Add `quickstart-agent-adapters` and `sdd-guide-runtime-adapters` doc invariants. |
| `docs/mainline-updates/README.md` | Add this note to the index. |

## Impact

- Audit now fails if either onboarding document loses the AGENTS.md / CLAUDE.md /
  `.github/copilot-instructions.md` adapter description or the
  `generated governance bootstrap` reference.
- No migration required. Existing documents already satisfy the new invariants.

## Impact Reconciliation

Historical reconciliation is closed only for recovering the exact introducing commit and confirming
the two scoped onboarding-document invariants. Current migration-route reconciliation belongs to
`docs/mainline-updates/2026-07-20-rb-5-agent-authority-process-truthfulness.md`; this historical note
is excluded from current readiness authorization.

## Revalidation (2026-07-20)

Git history identifies `ef71fb3e4f37128de98841c12066118e25827295` as both the introducing and
last-touch commit for this note before immutable migration base
`de61431ae8f50d66f59157e00e4d239e9b37efdb`. The pre-migration SHA-256 was
`ec712892629527eb2689925d92d5d22cd580f9bd4c3ecaefee460f7a8eefbdb3`.

No material correction is required for adding the two literal onboarding-document invariants.
Merged status records that scoped historical contract change only and does not close later adapter
or worktree findings.

The Validation section below is retained as the contemporaneous report for that historical commit.
Any counts or outcomes in it are historical and were not rerun by RB-5 as current acceptance
evidence. Neither this note nor its historical commit can satisfy current Batch or Aggregate
readiness, path coverage, `must_update` reconciliation, runtime promotion, or the R6 fresh-fixture
gate.

## Validation

- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json` reported VALID, 0 errors, and
  0 warnings.
- Both new invariants confirmed with empty `missingRequirements`.
- Change manifests: none required.

## Merge Notes

- Direct follow-up to commit `1a8078b` (v1.8.0 bootstrap governance).
- The historical invariant update landed in the exact commit recorded above.

## Follow-ups

- None for now. `adapter_change` impact routing entry remains optional and is tracked
  separately as a low-priority enhancement.
