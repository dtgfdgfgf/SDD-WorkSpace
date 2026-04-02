# Mainline Update Note: Project Worktree Parity Governance

**Date**: 2026-04-02
**Source Branch**: `main`
**Target Branch**: `main`
**Status**: Ready
**Related Commits**: `TBD`
**Related PR**: `N/A`

## Summary

- Add a canonical workspace policy that defines consumer-project derived worktrees as
  project-equivalent instances instead of reduced Git checkouts.
- Clarify that tracked parity alone is insufficient and that required local bootstrap parity must be
  preserved across actively used worktrees.
- Align workspace structure docs and Copilot instructions so agents must check parity surface before
  cleanup or normalization work.

## Why This Update Exists

The Trading worktree incident exposed a governance gap in the workspace model.

The workspace already defined initialization behavior, public snapshot boundaries, and shared
runtime conventions, but it did not explicitly define how a derived worktree should inherit the
operational identity of its source project. That allowed a Git-correct cleanup to still produce a
project-incomplete derived worktree.

This update closes that gap by making project-worktree parity an explicit shared-layer rule.

## Scope

- Add canonical governance for consumer-project derived worktree parity.
- Update workspace structure and AI operating instructions to reference the new rule.
- Record the change in the mainline shared-layer update log.

Non-goals:

- No project init or worktree bootstrap script automation is introduced in this batch.
- No consumer project is migrated in this note by itself.

## Affected Paths

| Path | Change |
|------|--------|
| `docs/project-worktree-parity-governance.md` | New canonical governance policy for derived worktree parity |
| `WORKSPACE_STRUCTURE.md` | Add parity rule to workspace structure, related docs, and initialization interpretation |
| `README.md` | Clarify that consumer-project feature worktrees are project-equivalent instances |
| `.github/copilot-instructions.md` | Require parity-surface checks for consumer-project derived worktrees |
| `docs/mainline-updates/README.md` | Add index entry for this update note |

## Impact

- Agents and operators now have a canonical rule that distinguishes branch correctness from project
  completeness.
- Feature worktrees can no longer be assumed healthy solely because tracked files or clean Git state
  exist.
- Local-only operational assets must be evaluated through documented parity rules rather than ignored
  as non-tracked noise.

## Validation

- `git diff --check`
- Manual consistency review across `WORKSPACE_STRUCTURE.md`, `README.md`, and
  `.github/copilot-instructions.md`
- Manual verification that the new policy explicitly covers:
  - tracked parity
  - required local bootstrap parity
  - project-declared local-only parity
  - normal `.git` file behavior in derived worktrees

## Merge Notes

- Ready to merge as a shared-layer governance clarification.
- This note intentionally separates policy definition from any future bootstrap automation or
  project-specific remediation.

## Follow-ups

- Consider adding explicit project-declared parity manifests or bootstrap checks if repeated
  incidents appear.
