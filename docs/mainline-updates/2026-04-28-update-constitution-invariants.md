# Mainline Update Note: update-constitution.ps1 Invariants Strengthening

**Date**: 2026-04-28
**Source Branch**: `main`
**Target Branch**: `main`
**Status**: Ready
**Related Commits**: `TBD`
**Related PR**: `N/A`

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

## Validation

- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json` -> VALID, 0 errors, 0 warnings
- `update-constitution-script` semantic check: `missingRequirements` empty.
- Change manifests: none required.

## Merge Notes

- Final follow-up to the v1.8.0 governance batch (`1a8078b`, `ef71fb3`, `8fe7357`).
- Supersedes the "fully closed" claim in
  `2026-04-28-adapter-change-routing.md`; the batch is now actually closed.

## Follow-ups

- None.
