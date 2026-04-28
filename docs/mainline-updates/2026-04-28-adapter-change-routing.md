# Mainline Update Note: adapter_change Impact Routing

**Date**: 2026-04-28
**Source Branch**: `main`
**Target Branch**: `main`
**Status**: Ready
**Related Commits**: `TBD`
**Related PR**: `N/A`

## Summary

- Add `adapter_change` changeType to the built-in impact routing rules so that
  edits to AGENTS.md / CLAUDE.md / .github/copilot-instructions.md produce a
  precise advisory listing the other two adapters as `must_update`.

## Why This Update Exists

Adapter edits previously fell through to the generic `doc_change` route, which
only flagged the contract for `maybe_review`. The pre-commit hook already
enforces three-adapter synchronization via its dedicated `Test-IsAgentAdapterPath`
logic, so this change is purely additive: it makes the impact routing advisory
output match what the hook actually checks, and helps future tooling reason
about adapter-specific dependencies.

## Scope

- Built-in rules in `generate-impact-registry.ps1` only.
- Generated `impact-registry.json` regenerated via `-Write`.
- No hook, contract, agent, template, or document content changes.

## Affected Paths

| Path | Change |
|------|--------|
| `studio/scripts/powershell/generate-impact-registry.ps1` | Add `adapter_change` entry to `$builtinImpactRouting`. |
| `studio/runtime/impact-registry.json` | Regenerated to include the new changeType. |
| `docs/mainline-updates/README.md` | Add this note to the index. |

## Impact

- Editing any single adapter now triggers an `adapter_change` advisory naming
  the other two as `must_update` and the contract as `maybe_review`.
- Registry freshness check still passes (`generate-impact-registry.ps1 -Compare`
  matches after `-Write`).

## Validation

- `pwsh ./studio/scripts/powershell/generate-impact-registry.ps1 -Write` -> wrote registry, 4 overrides applied
- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json` -> VALID, 0 errors, 0 warnings, FRESH true
- Change manifests: none required.

## Merge Notes

- Direct follow-up to commits `1a8078b` (v1.8.0) and `ef71fb3` (D4 invariants).
- Closes the last v1.8.0 follow-up listed as low-priority in
  `2026-04-27-agent-bootstrap-governance.md`.

## Follow-ups

- None. v1.8.0 governance batch is fully closed.
