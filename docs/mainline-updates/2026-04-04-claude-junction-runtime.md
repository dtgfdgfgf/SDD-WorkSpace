# Mainline Update Note: Claude Junction Runtime

**Date**: 2026-04-04
**Source Branch**: `main`
**Target Branch**: `main`
**Status**: Ready
**Related Commits**: `TBD`
**Related PR**: `N/A`

## Summary

- Add workspace-level Claude shared runtime authority at `/.claude/agents/`.
- Extend project initialization so new consumer projects receive both `.github/agents/` and
  `.claude/agents/` direct junctions plus read-only editor treatment.
- Add a shared `new-project-worktree.ps1` entrypoint that bootstraps derived worktree parity for
  shared Copilot and Claude agents.
- Extend `check-speckit-runtime.ps1 -Json` and the shared runtime contract to validate Claude
  shared agents as part of the shared-layer acceptance surface.

## Why This Update Exists

The workspace previously had a formal shared runtime model only for Copilot.

That left Claude Code in an awkward state: consumer projects could adopt `CLAUDE.md` manually, but
there was no canonical workspace-level shared agent authority, no init-time bootstrap, and no
derived worktree bootstrap path that treated Claude runtime discovery as first-class.

This update closes that gap while preserving the existing direct junction model already used for
Copilot runtime agents.

## Scope

- Add tracked workspace shared Claude agents under `/.claude/agents/`.
- Add a one-way seed script to bootstrap Claude shared agents from the current shared agent surface.
- Update `init-project.ps1` and `init-practice.ps1` to create `.claude/agents/` direct junctions.
- Add `new-project-worktree.ps1` for derived worktree bootstrap.
- Update workspace governance docs and quickstarts to distinguish Claude shared runtime from Claude
  skills/install-export layers.

Non-goals:

- No project-local Claude agents are introduced.
- No automatic `CLAUDE.md` generation is introduced in this batch.
- No bulk retrofit of existing consumer projects is performed in this batch.

## Affected Paths

| Path | Change |
|------|--------|
| `.claude/agents/` | New workspace shared Claude runtime authority |
| `README.md` | Document Claude shared runtime authority and install/export boundary |
| `WORKSPACE_STRUCTURE.md` | Add Claude runtime layout, init behavior, and worktree bootstrap rule |
| `docs/project-worktree-parity-governance.md` | Add `.claude/agents/` to required bootstrap parity |
| `studio/QUICKSTART.md` | Add Claude shared junction bootstrap behavior |
| `studio/SDD-QUICKSTART-GUIDE.md` | Clarify Claude runtime authority vs Claude skills/install root |
| `studio/templates/project-init/README.md` | Reflect generated `.claude/agents/` junction in project skeleton docs |
| `studio/runtime/shared-runtime-contract.json` | Add Claude shared agent contract and script/doc invariants |
| `studio/scripts/powershell/common.ps1` | Add reusable shared junction helpers and Claude shared path resolution |
| `studio/scripts/powershell/init-project.ps1` | Bootstrap `.claude/agents/` for new Internal/Client projects |
| `studio/scripts/powershell/init-practice.ps1` | Bootstrap `.claude/agents/` for new Practice projects |
| `studio/scripts/powershell/new-project-worktree.ps1` | New shared derived worktree bootstrap entrypoint |
| `studio/scripts/powershell/seed-claude-agents.ps1` | Seed workspace Claude agents from the existing shared surface |
| `studio/scripts/powershell/check-speckit-runtime.ps1` | Validate Claude shared agents in runtime audit output |
| `docs/mainline-updates/README.md` | Add index entry for this note |

## Impact

- Claude Code can now discover shared workspace agents through the same junction-based consumption
  model used by Copilot runtime agents.
- New consumer projects no longer need ad hoc local `.claude/agents/` setup.
- Derived worktrees can preserve Claude shared agent parity through one canonical bootstrap script.
- Shared-layer validation now treats Claude shared agents as a machine-verifiable runtime surface
  instead of a purely documented convention.

## Validation

- `.\studio\scripts\powershell\seed-claude-agents.ps1 -WorkspaceRoot .`
- `.\studio\scripts\powershell\check-speckit-runtime.ps1 -Json`
- `.\studio\scripts\powershell\init-project.ps1 -Name "<temp>" -Type Internal`
- `.\studio\scripts\powershell\init-practice.ps1 -Name "<temp>"`
- `.\studio\scripts\powershell\new-project-worktree.ps1 -SourceRoot "<project-root>" -Branch "<temp-branch>" -Path "<target-path>"`
- Manual verification that generated `.code-workspace` files mark `**/.claude/agents/**` as read-only

## Merge Notes

- Ready to merge as a shared-layer runtime/governance batch.
- The workspace root `/.claude/agents/` directory becomes the canonical Claude shared runtime
  authority after this change; future project-local Claude agent support would require a separate
  governance change.
