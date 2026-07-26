# Mainline Update Note: update-constitution.ps1 Invariants Strengthening

**Date**: 2026-04-28
**Source Branch**: `main`
**Target Branch**: `main`
**Status**: Merged
**Related Commits**: `a439c64d1dd14b69cefb92e034f0db35703c551d`
**Related PR**: `N/A`
**Reconciliation Status**: Closed

## Summary

- Strengthen the `update-constitution-script` invariant in
  `shared-runtime-contract.json` so the v1.8.0 governance rules embedded in
  `update-constitution.ps1` cannot be silently regressed.

## Why This Update Exists

The `update-constitution-script` invariant existed since v1.8.0 (commit `1a8078b`)
but only locked 6 surface-level phrases (`Scope Studio`, `Project Constitution`,
`sync-agent-bootstrap.ps1`, `check-agent-bootstrap.ps1`, `version`, `changelog`).
It did not lock the three v1.8.0 governance rules implemented inside the script:

1. mandatory mainline-updates note when Studio Constitution changes
2. shared runtime audit invocation after every constitution update
3. enforcement that Project Constitution cannot relax Studio Constitution

Without rule-level invariants, a future edit could remove any of these checks
without the audit catching the regression. This was originally listed as
"already handled" during the v1.8.0 follow-up review, then reclassified as a
governance gap on a closer reading.

## Scope

- Contract-only change. Three additional `mustContainAll` entries.
- No script behavior, document content, or template change.

## Affected Paths

| Path | Change |
|------|--------|
| `studio/runtime/shared-runtime-contract.json` | Add `check-speckit-runtime.ps1`, `mainline-updates`, and `Test-ProjectConstitutionDoesNotRelaxStudio` to the `update-constitution-script` invariant. |
| `docs/mainline-updates/README.md` | Add this note to the index. |

## Impact

- Audit now fails if any of the three core governance rules disappears from
  `update-constitution.ps1`.
- No migration required. Existing script already satisfies all locked phrases.

## Impact Reconciliation

Historical reconciliation is closed only for recovering the exact introducing commit and confirming
the three literal contract tokens added to the existing invariant. Current migration-route
reconciliation belongs to
`docs/mainline-updates/2026-07-20-rb-5-agent-authority-process-truthfulness.md`; this historical note
is excluded from current readiness authorization.

## Revalidation (2026-07-20)

Git history identifies `a439c64d1dd14b69cefb92e034f0db35703c551d` as both the introducing and
last-touch commit for this note before immutable migration base
`de61431ae8f50d66f59157e00e4d239e9b37efdb`. The pre-migration SHA-256 was
`289aff90699e41f9d7318fc7b727bdfb9437769db61fcd57714afaa5ca05ac62`.

The historical commit added three literal `mustContainAll` tokens. That detects removal of those
tokens but does not prove the corresponding behaviors, make the checks semantics-aware, or establish
that the v1.8.0 governance batch was fully closed. The broader silent-regression and final-closure
claims are narrowed to literal-token presence only. R-A13 remains open as the independent finding
for strengthening runtime invariant quality beyond literal presence.

The Validation section below is retained as the contemporaneous report for that historical commit.
Any counts or outcomes in it are historical and were not rerun by RB-5 as current acceptance
evidence. Neither this note nor its historical commit can satisfy current Batch or Aggregate
readiness, path coverage, `must_update` reconciliation, runtime promotion, or the R6 fresh-fixture
gate.

## Validation

- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json` reported VALID, 0 errors, and
  0 warnings.
- `update-constitution-script` semantic check: `missingRequirements` empty.
- Change manifests: none required.

## Merge Notes

- Final follow-up to the v1.8.0 governance batch (`1a8078b`, `ef71fb3`, `8fe7357`).
- It superseded one earlier closure claim at the time, but it did not prove complete behavioral
  closure; the dated Revalidation above governs that boundary.

## Follow-ups

- R-A13 remains open for semantics-aware invariant enforcement.
