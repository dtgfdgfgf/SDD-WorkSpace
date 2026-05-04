# Mainline Update Note: Machine-Enforced Governance Gates

**Date**: 2026-04-30
**Source Branch**: `main`
**Target Branch**: `main`
**Status**: Ready
**Related Commits**: `TBD`
**Related PR**: `N/A`

## Summary

- Move governance MUST checks from working-tree or agent-only enforcement to staged index validation in the pre-commit hook.
- Make new consumer projects independent Git repositories that reuse the workspace `.githooks` directory.
- Add hard readiness gates before `plan.md` creation and before staged `plan.md` / `tasks.md` commits.

## Why This Update Exists

Several governance rules were documented as mandatory but could still be bypassed by partial staging,
manual script use, or consumer projects silently falling back to non-git feature flow. This update
closes those gaps with script, hook, and test coverage.

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

- Commits that stage drifted adapters, missing readiness approval, or broken shared runtime changes now fail before commit.
- New projects no longer depend on the workspace repo as their Git boundary.
- Existing projects can be migrated by initializing a project-local repo and running `setup-hooks.ps1 -ProjectRoot <project-root>`.

## Validation

- `git diff --check`
- `pwsh -NoProfile -File studio/scripts/powershell/check-speckit-runtime.ps1 -Json`
- `pwsh -NoProfile -Command "Invoke-Pester -Path 'studio/tests' -CI"`
- Change manifests: none required; this note covers the shared-layer batch.

## Merge Notes

- Ready for main once the validation commands pass.
- No existing consumer project contents are migrated in this batch.

## Follow-ups

- Consider a future migration helper for existing consumer projects that need project-local Git initialization.
