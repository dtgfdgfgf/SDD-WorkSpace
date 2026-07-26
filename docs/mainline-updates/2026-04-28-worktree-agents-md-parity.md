# Mainline Update Note: Worktree AGENTS.md Parity

**Date**: 2026-04-28
**Source Branch**: `main`
**Target Branch**: `main`
**Status**: Merged
**Related Commits**: `580462832150509ecc108cfeea44e25e1a6b077c`
**Related PR**: `N/A`
**Reconciliation Status**: Closed

## Summary

- Extend `new-project-worktree.ps1` to copy `AGENTS.md` alongside `CLAUDE.md`
  and `.github/copilot-instructions.md` so derived worktrees carry all three
  v1.8.0 runtime adapters.
- Add `AGENTS.md` to the Minimum Required Bootstrap Parity table in
  `docs/project-worktree-parity-governance.md` and order the three adapters to
  match the constitution.

## Why This Update Exists

Studio Constitution v1.8.0 (2026-04-27) introduced the five-file Agent
Bootstrap Governance model, in which `AGENTS.md`, `CLAUDE.md`, and
`.github/copilot-instructions.md` together form the synchronized runtime
adapter layer. The worktree machinery, however, was last updated before v1.8.0
and only handled two of the three adapters:

- `new-project-worktree.ps1` line 57 iterated only
  `.github/copilot-instructions.md` and `CLAUDE.md`, so a derived worktree of a
  consumer project would silently drop `AGENTS.md`.
- `docs/project-worktree-parity-governance.md` Minimum Required Bootstrap
  Parity table did not list `AGENTS.md`, making the governance description
  inconsistent with the v1.8.0 five-file model.

The v1.8.0 mainline note for `adapter-change-routing` claimed the v1.8.0
batch was fully closed; this update corrects that statement and closes the
remaining worktree-side gap.

## Scope

- One source-of-truth script change (`new-project-worktree.ps1`).
- One source-of-truth governance doc change
  (`docs/project-worktree-parity-governance.md`).
- No constitution, contract, registry, or hook content changes; the
  pre-commit hook already enforces three-adapter synchronization at the
  workspace and project level.
- No agent, template, or runtime-artifact changes.

## Affected Paths

| Path | Change |
|------|--------|
| `studio/scripts/powershell/new-project-worktree.ps1` | Iterate over `AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md` instead of two adapters. |
| `docs/project-worktree-parity-governance.md` | Add `AGENTS.md` row to the Minimum Required Bootstrap Parity table; order the three adapters to match the constitution. |
| `docs/mainline-updates/README.md` | Add this note to the index. |

## Impact

- New derived worktrees created via `new-project-worktree.ps1` will receive
  all three runtime adapters whenever the source project carries them.
- Operators auditing a derived worktree against the parity governance doc
  will now see `AGENTS.md` listed explicitly, matching what the constitution
  v1.8.0 already requires.
- No behavior change for workspace-root operations; this only affects
  derived worktrees of consumer projects under `projects/` and `learning/`.

## Impact Reconciliation

Historical reconciliation is closed only for recovering the exact introducing commit and confirming
the scoped `AGENTS.md` copy-loop and parity-table additions. Current migration-route reconciliation
belongs to
`docs/mainline-updates/2026-07-20-rb-5-agent-authority-process-truthfulness.md`; this historical note
is excluded from current readiness authorization.

## Revalidation (2026-07-20)

Git history identifies `580462832150509ecc108cfeea44e25e1a6b077c` as both the introducing and
last-touch commit for this note before immutable migration base
`de61431ae8f50d66f59157e00e4d239e9b37efdb`. The pre-migration SHA-256 was
`9c0d1c84bbd46f402769243ba004dec77bb37fbc21833be9d33028d539154865`.

The commit added `AGENTS.md` to the copy loop and the documented parity table. Its statements that
the remaining worktree-side gap was closed and that the complete worktree machinery was aligned
were too broad. R-A19 later demonstrated shared `core.hooksPath` mutation and junction-intake
problems in derived consumer worktrees. RB-4 commit
`9819e301318230ca0413d44a5bdf3d2a3b3e3ca6` repaired those later findings. Merged status here
records only the scoped historical additions, not the broader closure claim.

The Validation section below is retained as the contemporaneous report for that historical commit.
Any counts or outcomes in it are historical and were not rerun by RB-5 as current acceptance
evidence. Neither this note nor its historical commit can satisfy current Batch or Aggregate
readiness, path coverage, `must_update` reconciliation, runtime promotion, or the R6 fresh-fixture
gate.

## Validation

- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json` reported VALID, 0 errors, and
  0 warnings.
- `pwsh ./studio/scripts/powershell/check-agent-bootstrap.ps1 -Json` reported all three workspace
  adapters with `hasBlock: true` (unchanged).
- Manual spot check on the script change: copy loop now treats `AGENTS.md` as
  a peer of the other two adapters and respects the same idempotency guard.

## Merge Notes

- Follow-up to v1.8.0 (`1a8078b`) and the v1.8.0 closing notes
  `ef71fb3` (D4) and the `adapter-change-routing` note dated 2026-04-28.
- It superseded one earlier closure line at the time, but the dated Revalidation above withdraws
  the claim that this was the complete worktree closing fix.

## Follow-ups

- The later R-A19 worktree boundary repair remains independently accounted by RB-4.
