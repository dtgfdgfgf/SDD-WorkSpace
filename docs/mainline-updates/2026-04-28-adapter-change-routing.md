# Mainline Update Note: adapter_change Impact Routing

**Date**: 2026-04-28
**Source Branch**: `main`
**Target Branch**: `main`
**Status**: Merged
**Related Commits**: `8fe73578909a54db9cf4743545226e303213cbb1`
**Related PR**: `N/A`
**Reconciliation Status**: Closed

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

## Impact Reconciliation

Historical reconciliation is closed only for recovering the exact introducing commit and confirming
the scoped `adapter_change` routing addition. Current migration-route reconciliation belongs to
`docs/mainline-updates/2026-07-20-rb-5-agent-authority-process-truthfulness.md`; this historical note
is excluded from current readiness authorization.

## Revalidation (2026-07-20)

Git history identifies `8fe73578909a54db9cf4743545226e303213cbb1` as both the introducing and
last-touch commit for this note before immutable migration base
`de61431ae8f50d66f59157e00e4d239e9b37efdb`. The pre-migration SHA-256 was
`b8918f9b65f4306ce626b0b8970887088c7e2ffd8d904e2e58bd5c1572c8756b`.

The commit did add the `adapter_change` advisory route. The statements that it closed the last
v1.8.0 follow-up and left the governance batch fully closed are withdrawn. Subsequent
`update-constitution` and worktree-parity findings showed that additional obligations remained, and
later R-A19 evidence refuted the broader worktree closure before RB-4 repaired it. Merged status
therefore records the scoped routing change only.

The Validation section below is retained as the contemporaneous report for that historical commit.
Any counts or outcomes in it are historical and were not rerun by RB-5 as current acceptance
evidence. Neither this note nor its historical commit can satisfy current Batch or Aggregate
readiness, path coverage, `must_update` reconciliation, runtime promotion, or the R6 fresh-fixture
gate.

## Validation

- `pwsh ./studio/scripts/powershell/generate-impact-registry.ps1 -Write` reported that the registry
  was written with 4 overrides applied.
- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json` reported VALID, 0 errors,
  0 warnings, and FRESH true.
- Change manifests: none required.

## Merge Notes

- Direct follow-up to commits `1a8078b` (v1.8.0) and `ef71fb3` (D4 invariants).
- The original claim that this closed the last v1.8.0 follow-up is withdrawn by the dated
  Revalidation above.

## Follow-ups

- Later governance and worktree findings remain governed independently; this historical routing
  note does not close them.
