# Mainline Update Note: Validation, worktree, and parameter hardening (Patch 7 of governance review)

<!--
  Part of the v1.8.0 deep review remediation series. This is Patch 7 of 9.
-->

**Date**: 2026-05-01
**Source Branch**: `main`
**Target Branch**: `main`
**Status**: Merged
**Related Commits**: `c6ee1f1fcf2eda0b517e1e8d1518d0332563ffb6`
**Related PR**: N/A
**Reconciliation Status**: Closed

## Revalidation (2026-07-20)

Git history identifies `c6ee1f1fcf2eda0b517e1e8d1518d0332563ffb6` as both the introducing
and last-touch commit for this note before immutable migration base
`de61431ae8f50d66f59157e00e4d239e9b37efdb`. The pre-migration SHA-256 was
`acad1ea4a0a1c52dc8993440e2d6ffbbfee297ae5e9ef105ca85a33fe2d0e9d9`.

The Validation section below is retained as the contemporaneous report for that historical commit.
RB-5 did not rerun those historical counts as current acceptance evidence. Neither this note nor
its historical commit can satisfy present Batch or Aggregate evidence, path coverage,
`must_update` reconciliation, runtime promotion, or the R6 fresh-fixture gate.

The worktree hook-isolation claim was later refuted by R-A19. Normal
`git config core.hooksPath` in a linked worktree wrote shared repository configuration, and a
relative value could affect source or sibling worktrees at different depths. Commit
`9819e301318230ca0413d44a5bdf3d2a3b3e3ca6` fixed this with
`extensions.worktreeConfig` and `git config --worktree`; the historical test observed only the
target worktree value.

## Summary

- New `studio/scripts/powershell/validate-feature-structure.ps1` script that validates a `specs/<feature>/` directory against constitution Section 11. Supports `-Json` and `-WarningsAsErrors`.
- `new-project-worktree.ps1` now configures `core.hooksPath` for the new worktree (relative to the worktree root) so that commits inside derived worktrees are governed by the workspace `.githooks` directory.
- `new-project-worktree.ps1` `-Branch` and `-Commitish` parameters now use `ValidateScript` to reject obviously-malformed git ref names before invoking `git worktree add`.
- `sync-agent-bootstrap.ps1 -From` now uses `ValidateScript` to reject any value whose basename does not match `AGENTS.md`, `CLAUDE.md`, or `.github/copilot-instructions.md` (or `copilot-instructions.md` when callers pass a fully-resolved path).
- `upgrade-studio-runtime.ps1` help text now explicitly states default behavior is dry-run and that `-DryRun` and `-Apply` are mutually exclusive. The mutual-exclusion error message is more descriptive.
- New contract invariants `validate-feature-structure-shape`, `sync-agent-bootstrap-from-validation`, and updated `new-project-worktree-claude-bootstrap` (now requires `core.hooksPath` and `ValidateScript`).

## Why This Update Exists

The deep review identified that the workspace had only one PowerShell-level entry gate (`setup-plan.ps1`) and that several scripts accepted free-form inputs that only failed at runtime. Concrete pain points:

- **M5** — Constitution Section 11 lists the required artifact tree per feature, but no script enforced it. `/speckit.analyze` did this work indirectly, but there was no machine-verifiable per-feature validator that other tooling could call.
- **M8** — `new-project-worktree.ps1` created Git worktrees but did not configure
  `core.hooksPath`. Patch 7 wrote a target-relative value, but it did not isolate linked-worktree
  configuration from the shared repository config; R-A19 later identified and corrected that
  boundary.
- **L9** — `sync-agent-bootstrap.ps1 -From` accepted any string and threw an unhelpful runtime error when the value didn't match a canonical adapter.
- **L9'** — `new-project-worktree.ps1 -Branch` / `-Commitish` accepted any string. A typo with a space or `..` ended up as a confusing `git worktree add` failure.
- **L10** — `upgrade-studio-runtime.ps1`'s help text didn't make explicit that `-DryRun` is the default; users sometimes thought omitting both flags meant "do nothing" or "do everything."

## Scope

- New script only: `validate-feature-structure.ps1`. The script does not modify state; it reads a feature directory and emits findings.
- Behavior-additive changes to `new-project-worktree.ps1`, `sync-agent-bootstrap.ps1`, `upgrade-studio-runtime.ps1`. None of the existing happy-path call sites change shape.
- Contract additions for the new script and updated worktree invariant.
- New Pester suite `studio/tests/validate-feature-structure.Tests.ps1` (24 tests).

Out of scope:

- Wiring `validate-feature-structure.ps1` into `check-speckit-runtime.ps1` as a per-project advisory (M5'). That requires a separate decision on how to render per-project findings inside the global audit summary; it is deferred to Patch 9 housekeeping or a follow-up patch where the rendering is designed properly.
- Migrating the `Get-MarkdownFieldValue` helper inside `pre-commit.ps1` to dot-source `common.ps1` (intentionally kept self-contained — see in-code comment from Patch 6).

## Affected Paths

| Path | Change |
|------|--------|
| `studio/scripts/powershell/validate-feature-structure.ps1` | New: per-feature §11 validator. |
| `studio/scripts/powershell/new-project-worktree.ps1` | Adds `ValidateScript` to `-Branch` and `-Commitish`; configures `core.hooksPath` after `git worktree add`; surfaces `worktreeHooksPath` in JSON output. |
| `studio/scripts/powershell/sync-agent-bootstrap.ps1` | Adds `ValidateScript` to `-From` (accepts canonical names or paths whose basename matches). |
| `studio/scripts/powershell/upgrade-studio-runtime.ps1` | Help text rewrite; clearer mutual-exclusion error. |
| `studio/runtime/shared-runtime-contract.json` | Adds `validate-feature-structure-shape`, `sync-agent-bootstrap-from-validation`. Strengthens `new-project-worktree-claude-bootstrap` to require `core.hooksPath` + `ValidateScript`. |
| `studio/tests/validate-feature-structure.Tests.ps1` | New: 24 tests across 5 Describe blocks (validator, worktree validation, worktree hooksPath e2e, sync-agent-bootstrap From validation, upgrade-studio-runtime help). |

## Impact

- 142 to 166 tests, 0 failed, 0 skipped.
- `check-speckit-runtime.ps1 -Json` -> `VALID: true`, `ERROR_COUNT: 0`. Three new contract invariants verified.
- `generate-impact-registry.ps1 -Compare` -> in-sync.
- The historical `new-project-worktree.ps1` end-to-end test confirmed the target worktree's
  `core.hooksPath` value matched `../*/.githooks`; it did not prove source or sibling isolation.
- Existing `agent-bootstrap.Tests.ps1` test that passes an absolute path to `-From` still works because we used `ValidateScript` (basename-aware) instead of `ValidateSet`.

## Validation

- `pwsh ./studio/scripts/powershell/run-governance-tests.ps1` -> 166 passed, 0 failed.
- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json` -> `VALID: true`, all invariants green.
- `pwsh ./studio/scripts/powershell/generate-impact-registry.ps1 -Compare` -> in-sync.

## Impact Reconciliation

This historical note is sealed migration evidence only. It is excluded from current
reconciliation and cannot satisfy current `must_update` routes. Current RB-5 reconciliation is
owned by `2026-07-20-rb-5-agent-authority-process-truthfulness.md`; this note records no
present-day update disposition.

## Merge Notes

- Patch 7 unblocks Patch 8 (the five new stage entry-gate scripts can call `validate-feature-structure.ps1` for prerequisite checks).
- No external-facing behavior change for happy-path callers. Malformed inputs to `sync-agent-bootstrap` and `new-project-worktree` now fail at parameter binding with clearer messages.

## Follow-ups

- Patch 8 adds `setup-clarify`, `setup-readiness`, `setup-tasks`, `setup-analyze`, and `setup-implement` scripts that should reuse `validate-feature-structure.ps1` for stage-prerequisite checks.
- Long-term M5' (per-project validator integration into `check-speckit-runtime.ps1`) remains open and will need a small design decision on output shape.
