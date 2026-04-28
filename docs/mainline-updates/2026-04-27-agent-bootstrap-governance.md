# Mainline Update Note: Agent Bootstrap Governance

**Date**: 2026-04-27
**Source Branch**: `main`
**Target Branch**: `main`
**Status**: Ready
**Related Commits**: `TBD`
**Related PR**: `N/A`

## Summary

- Add synchronized runtime adapter governance for `AGENTS.md`, `CLAUDE.md`, and `.github/copilot-instructions.md`.
- Add PowerShell scripts and hook checks that keep generated governance bootstrap blocks aligned.
- Update the Studio Constitution to define the five-file constitution/bootstrap relationship.

## Why This Update Exists

Copilot CLI, Claude Code, and Codex load different default context files. The workspace needed a
stable environment-level bootstrap model so future projects consistently load the Studio
Constitution plus the project constitution without copying the Studio Constitution into each
project.

## Scope

- Workspace root runtime adapters.
- New project bootstrap generation.
- Pre-commit enforcement for adapter, Studio Constitution, and project constitution drift.
- Existing consumer projects are intentionally not batch-migrated.

## Affected Paths

| Path | Change |
|------|--------|
| `AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md` | Runtime adapters now share a generated governance bootstrap block. |
| `studio/scripts/powershell/*agent-bootstrap*.ps1` | Add sync/check/update support for the bootstrap model. |
| `.githooks/pre-commit.ps1` | Add synchronization and blocking checks for bootstrap drift. |
| `studio/templates/sdd-docs/` | Add and update adapter templates for future projects. |
| `studio/constitution/constitution.md` | Define five-file bootstrap governance and bump to v1.8.0. |

## Impact

- New projects receive `AGENTS.md`, `CLAUDE.md`, and `.github/copilot-instructions.md` at init time.
- Editing one adapter requires the other two to be synchronized before commit.
- Studio Constitution changes refresh root adapter metadata and require a mainline update note.

## Validation

- `git diff --check`
- `pwsh ./studio/scripts/powershell/check-agent-bootstrap.ps1 -ProjectRoot . -Json`
- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json`
- Change manifests: none required

## Merge Notes

- Ready once Pester and runtime audit pass.
- No existing `projects/*` or `learning/*` migration is included.

## Follow-ups

- Consider a future opt-in migration command for selected existing projects.
