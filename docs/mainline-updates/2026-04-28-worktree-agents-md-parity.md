# Mainline Update Note: Worktree AGENTS.md Parity

**Date**: 2026-04-28
**Source Branch**: `main`
**Target Branch**: `main`
**Status**: Ready
**Related Commits**: `TBD`
**Related PR**: `N/A`

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

## Validation

- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json` -> VALID,
  0 errors, 0 warnings.
- `pwsh ./studio/scripts/powershell/check-agent-bootstrap.ps1 -Json` -> all
  three workspace adapters report `hasBlock: true` (unchanged).
- Manual spot check on the script change: copy loop now treats `AGENTS.md` as
  a peer of the other two adapters and respects the same idempotency guard.

## Merge Notes

- Follow-up to v1.8.0 (`1a8078b`) and the v1.8.0 closing notes
  `ef71fb3` (D4) and the `adapter-change-routing` note dated 2026-04-28.
- Supersedes the "v1.8.0 governance batch is fully closed" follow-up line in
  `2026-04-28-adapter-change-routing.md`; this is the actual closing fix.

## Follow-ups

- None. v1.8.0 governance batch is now fully aligned across constitution,
  hooks, registry, contract, and worktree machinery.
