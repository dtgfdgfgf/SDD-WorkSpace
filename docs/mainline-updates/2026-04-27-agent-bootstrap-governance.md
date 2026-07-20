# Mainline Update Note: Agent Bootstrap Governance

**Date**: 2026-04-27
**Source Branch**: `main`
**Target Branch**: `main`
**Status**: Merged
**Related Commits**: `1a8078bec9f9c549c390a1f280bc2a7f81dc235f`
**Related PR**: `N/A`
**Reconciliation Status**: Closed

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

## Impact Reconciliation

Historical reconciliation is closed only for recovering the exact introducing commit and confirming
the scoped five-file bootstrap governance, synchronization scripts, hook checks, templates, and
documentation changes. Current migration-route reconciliation belongs to
`docs/mainline-updates/2026-07-20-rb-5-agent-authority-process-truthfulness.md`; this historical note
is excluded from current readiness authorization.

## Revalidation (2026-07-20)

Git history identifies `1a8078bec9f9c549c390a1f280bc2a7f81dc235f` as both the introducing and
last-touch commit for this note before immutable migration base
`de61431ae8f50d66f59157e00e4d239e9b37efdb`. The pre-migration SHA-256 was
`8b6149ac99266e6ce56738bd686359b3bf0c71b00aef5ee718056775dc91fcef`.

No material correction is required for the scoped bootstrap-governance changes. Merged status
records exact historical commit recovery only and does not close later adapter routing, worktree,
or audit findings.

The Validation section below is retained as the contemporaneous report for that historical commit.
Any counts or outcomes in it are historical and were not rerun by RB-5 as current acceptance
evidence. Neither this note nor its historical commit can satisfy current Batch or Aggregate
readiness, path coverage, `must_update` reconciliation, runtime promotion, or the R6 fresh-fixture
gate.

## Validation

- `git diff --check`
- `pwsh ./studio/scripts/powershell/check-agent-bootstrap.ps1 -ProjectRoot . -Json`
- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json`
- Change manifests: none required

## Merge Notes

- The historical batch landed after its contemporaneous validation.
- No existing `projects/*` or `learning/*` migration is included.

## Follow-ups

- Consider a future opt-in migration command for selected existing projects.
