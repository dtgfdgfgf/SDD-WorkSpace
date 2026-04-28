# Mainline Update Note: QUICKSTART / SDD-GUIDE Adapter Invariants

**Date**: 2026-04-28
**Source Branch**: `main`
**Target Branch**: `main`
**Status**: Ready
**Related Commits**: `TBD`
**Related PR**: `N/A`

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

## Validation

- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json` -> VALID, 0 errors, 0 warnings
- Both new invariants confirmed with empty `missingRequirements`.
- Change manifests: none required.

## Merge Notes

- Direct follow-up to commit `1a8078b` (v1.8.0 bootstrap governance).
- Ready to merge as soon as audit passes in the target branch.

## Follow-ups

- None for now. `adapter_change` impact routing entry remains optional and is tracked
  separately as a low-priority enhancement.
