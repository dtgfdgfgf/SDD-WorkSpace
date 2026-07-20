# Mainline Update Note: Machine-Enforced Governance Gates

**Date**: 2026-04-30
**Source Branch**: `main`
**Target Branch**: `main`
**Status**: Merged
**Related Commits**: `c6ee1f1fcf2eda0b517e1e8d1518d0332563ffb6`
**Related PR**: `N/A`
**Reconciliation Status**: Closed

## Revalidation (2026-07-20)

Git history identifies `c6ee1f1fcf2eda0b517e1e8d1518d0332563ffb6` as both the introducing
and last-touch commit for this note before immutable migration base
`de61431ae8f50d66f59157e00e4d239e9b37efdb`. The pre-migration SHA-256 was
`cabfe7b6c353ad8e71438984389e560cb89b10ffa5656c2b4029ddcfc0217881`.

The Validation section below is retained as the contemporaneous report for that historical commit.
RB-5 did not rerun those historical counts as current acceptance evidence. Neither this note nor
its historical commit can satisfy present Batch or Aggregate evidence, path coverage,
`must_update` reconciliation, runtime promotion, or the R6 fresh-fixture gate.

The prior statement that this batch closed the governance gaps was too broad. R-A01 and R-A02
later proved audit false negatives and were fixed by
`e543f6a9818007bac67f1ec942cacc22e577d17a`; R-A17 later proved shared-path and rename
coverage incomplete and was fixed by `4f757e551ee196bc90e51ef21674c4983eae35ec`.

## Summary

- Move governance MUST checks from working-tree or agent-only enforcement to staged index validation in the pre-commit hook.
- Make new consumer projects independent Git repositories that reuse the workspace `.githooks` directory.
- Add hard readiness gates before `plan.md` creation and before staged `plan.md` / `tasks.md` commits.

## Why This Update Exists

Several governance rules were documented as mandatory but could still be bypassed by partial
staging, manual script use, or consumer projects silently falling back to non-Git feature flow.
This historical update added staged checks for its then-listed surfaces; later review found the
additional audit and path-coverage gaps recorded above.

## Scope

- Workspace pre-commit governance gates.
- Project initialization and hook setup behavior.
- `/speckit.plan` setup readiness enforcement.
- Runtime adapter docs, mirrors, and shared runtime contract invariants.
- Existing `projects/` and `learning/` contents are intentionally excluded.

## Affected Paths

| Path | Change |
|------|--------|
| `.githooks/pre-commit.ps1` | Validate staged snapshots, include delete / rename changes, and enforce adapter/readiness gates from the Git index. |
| `studio/scripts/powershell/init-project.ps1` | Initialize new Internal / Client projects as independent Git repos and configure hooks. |
| `studio/scripts/powershell/init-practice.ps1` | Initialize new Practice projects as independent Git repos and configure hooks. |
| `studio/scripts/powershell/setup-hooks.ps1` | Support workspace repo setup and explicit project repo setup. |
| `studio/scripts/powershell/create-new-feature.ps1` | Require consumer project Git root to equal project root. |
| `studio/scripts/powershell/setup-plan.ps1` | Block plan setup unless readiness, intent ledger, and ECI authorization gates are satisfied. |
| `studio/templates/project-init/.gitignore` | Ignore shared agent junction content in new project repos. |
| `.github/agents/speckit.specify.agent.md` | Fix malformed PowerShell command example. |
| `.claude/agents/speckit-specify.md` | Refresh Claude mirror for the specify agent. |
| `studio/runtime/shared-runtime-contract.json` | Add invariants for the new machine-enforced gates. |
| `studio/tests/` | Add Pester coverage for pre-commit, setup-plan, and project Git initialization behavior. |
| `README.md`, `WORKSPACE_STRUCTURE.md`, `studio/QUICKSTART.md` | Document independent project repos and workspace hook setup. |

## Impact

- For the paths and conditions then covered, commits that stage drifted adapters, missing
  readiness approval, or broken shared runtime changes fail before commit.
- New projects no longer depend on the workspace repo as their Git boundary.
- Existing projects can be migrated by initializing a project-local repo and running `setup-hooks.ps1 -ProjectRoot <project-root>`.

## Validation

- `git diff --check`
- `pwsh -NoProfile -File studio/scripts/powershell/check-speckit-runtime.ps1 -Json`
- `pwsh -NoProfile -Command "Invoke-Pester -Path 'studio/tests' -CI"`
- Change manifests: none required; this note covers the shared-layer batch.

## Impact Reconciliation

This historical note is sealed migration evidence only. It is excluded from current
reconciliation and cannot satisfy current `must_update` routes. Current RB-5 reconciliation is
owned by `2026-07-20-rb-5-agent-authority-process-truthfulness.md`; this note records no
present-day update disposition.

## Merge Notes

- Merged into `main` in `c6ee1f1fcf2eda0b517e1e8d1518d0332563ffb6`; current readiness is
  outside this historical note.
- No existing consumer project contents are migrated in this batch.

## Follow-ups

- Consider a future migration helper for existing consumer projects that need project-local Git initialization.
