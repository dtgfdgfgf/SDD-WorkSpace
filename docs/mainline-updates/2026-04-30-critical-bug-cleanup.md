# Mainline Update Note: Critical bug cleanup (Patch 1 of governance review)

<!--
  Part of the v1.8.0 deep review remediation series. This is Patch 1 of 9.
-->

**Date**: 2026-04-30
**Source Branch**: `main`
**Target Branch**: `main`
**Status**: Ready
**Related Commits**: TBD
**Related PR**: N/A

## Update — 2026-05-01

Added one more pre-commit hook scope fix discovered during the Patch 9 push:
the plan.md / tasks.md SDD-structure validators were matching any `*plan.md`
or `*tasks.md` filename, including seeded agent definitions under
`.claude/agents/speckit-plan.md` and `.claude/agents/speckit-tasks.md`. The
regex is now anchored to `specs/<feature>/plan.md` and `specs/<feature>/tasks.md`
so only SDD feature artifacts are validated.

## Summary

- Fix `Invoke-SharedRuntimeAuditOnStagedSnapshot` to refuse to silently pass when no error path was covered (defensive `$auditConfirmed` marker in `finally`).
- Fix `.gitkeep` cleanup count bug in `init-project.ps1` and `init-practice.ps1` (single-result `Get-ChildItem` returned `$null` count instead of 1).
- Fix `create-new-feature.ps1` `git checkout -b` failure to exit non-zero instead of warning and continuing with mismatched spec/branch state.
- Promote `seed-claude-agents.ps1` frontmatter parse failures from silent skip to `Write-Warning` and track skipped files in result output.
- Simplify `check-speckit-runtime.ps1` `-Compare` exit code detection and promote impact-registry stale state from warning to audit failure.
- Extend `generate-impact-registry.ps1` exclude pattern to skip `resources/`, `studio/upstream/`, and `merged/` directories that may carry mirrored content.

## Why This Update Exists

A v1.8.0 deep review identified eight pure-bug cases where the workspace governance machinery either silently absorbed errors or had off-by-one path-handling defects. These fixes move the baseline closer to the "machine-enforced governance" promise that constitution §12 makes, without adding any new policy. They are intentionally scoped to bug fixes only so that subsequent enforcement-tightening patches start from a clean baseline.

## Scope

- Pre-commit hook defensive marker only; no new policy or rule introduced.
- PowerShell scripts that produce or audit governance artifacts.
- New regression unit tests for the `.gitkeep` count bug.
- Out of scope: hook policy expansion, new templates, helper refactors, new entry-gate scripts (covered in later patches).

## Affected Paths

| Path | Change |
|------|--------|
| `.githooks/pre-commit.ps1` | `Invoke-SharedRuntimeAuditOnStagedSnapshot`: add `$auditConfirmed` marker in `finally` to detect silent-pass paths (H4). |
| `studio/scripts/powershell/init-project.ps1` | `.gitkeep` cleanup: wrap `Get-ChildItem` in `@()` so `.Count` is always an integer (H5). |
| `studio/scripts/powershell/init-practice.ps1` | Same `.gitkeep` count fix (H5). |
| `studio/scripts/powershell/create-new-feature.ps1` | `git checkout -b` failure now checks `$LASTEXITCODE` and `exit 1` (H6). |
| `studio/scripts/powershell/seed-claude-agents.ps1` | Frontmatter parse failures emit `Write-Warning`; result tracks `skipped` and `skippedCount`; `outputPath` normalized to forward slashes (M12, M22). |
| `studio/scripts/powershell/check-speckit-runtime.ps1` | `-Compare` exit code simplified to `$LASTEXITCODE`; impact-registry stale state pushed to `$failures` (M14, M15). |
| `studio/scripts/powershell/generate-impact-registry.ps1` | Recursive scan exclude pattern extended to `resources`, `merged`, `studio/upstream` (L11). |
| `studio/tests/common.Tests.ps1` | New `Describe '.gitkeep cleanup Count safety (H5 regression)'` block with 3 cases. |

## Impact

- Existing 80 governance tests continue to pass; total now 83 with the new H5 regression cases.
- `check-speckit-runtime.ps1 -Json` continues to return `VALID` and `FAILURES` empty (impact-registry currently fresh).
- Behavior change: a stale impact-registry will now make `check-speckit-runtime.ps1` fail instead of warn. Developers MUST run `generate-impact-registry.ps1 -Write` before committing if they have introduced a new `drift-governance` block.
- `create-new-feature.ps1` will now refuse to scaffold a `specs/<branch>/` directory when `git checkout -b` fails (e.g. branch already exists). Recover by deleting the conflicting branch or stashing the dirty worktree, then re-run.

## Validation

- `pwsh ./studio/scripts/powershell/run-governance-tests.ps1` -> 83 passed, 0 failed, 0 skipped.
- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json` -> `VALID: true`, `ERROR_COUNT: 0`.
- `pwsh ./studio/scripts/powershell/generate-impact-registry.ps1 -Compare` -> exit 0 (registry fresh).
- `git diff --check` -> clean.

## Merge Notes

- This is the first of 9 staged patches from the workspace governance deep-review remediation.
- Patch 2 (hook enforcement tightening) MUST land next so that constitution §12 mainline-update enforcement and Conventional Commits become machine-validated.
- Independent of Patch 4 / Patch 9, can be merged in parallel.

## Follow-ups

- Integration test for `Invoke-SharedRuntimeAuditOnStagedSnapshot` is intentionally deferred to Patch 2 (H3) so its scope sits with the rest of the hook-enforcement work.
- `create-new-feature.ps1` H6 fix has no unit test in this patch; an end-to-end test using `TestDrive` and a fixture repo will land with Patch 7 (validation hardening).
