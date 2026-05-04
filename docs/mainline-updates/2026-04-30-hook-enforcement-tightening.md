# Mainline Update Note: Hook enforcement tightening (Patch 2 of governance review)

<!--
  Part of the v1.8.0 deep review remediation series. This is Patch 2 of 9.
-->

**Date**: 2026-04-30
**Source Branch**: `main`
**Target Branch**: `main`
**Status**: Ready
**Related Commits**: TBD
**Related PR**: N/A

## Summary

- Expand mainline-update note enforcement from constitution-only to ALL shared-layer governance changes (constitution §12).
- Force `studio/constitution/constitution.md` changes to stage all three workspace adapters together with version-string match.
- Strengthen existing commit-msg hook: support `feat!:` breaking marker, `BREAKING CHANGE:` footer, additional types (`ci`, `perf`, `build`, `revert`), and align output style with pre-commit hook (no emoji per §10.1).
- Extract H1 enforcement into reusable helpers (`Get-NonNoteSharedLayerFiles`, `Get-StagedMainlineUpdateNotes`) for unit testability.
- Add end-to-end staged-snapshot audit failure test (H3) — first integration coverage of `Invoke-SharedRuntimeAuditOnStagedSnapshot`.
- Relax constitution phase freshness assertion from 3 months to 4 months (one-month grace, still quarterly).

## Why This Update Exists

Constitution §12 mandates that any branch touching shared-layer governance, runtime agents, prompts, templates, hooks, shared scripts, or canonical explanatory docs MUST add a `docs/mainline-updates/*.md` note. The pre-commit hook previously enforced this rule only for `studio/constitution/constitution.md` changes — a tiny subset of `sharedGatePaths`. Patch 2 closes that gap so the rule actually has teeth.

`Invoke-SharedRuntimeAuditOnStagedSnapshot` is the §12 designated machine-verifiable acceptance entry. Until this patch it had no integration test — passing tests gave false confidence. The H3 e2e test mirrors a workspace subset into a fixture repo, breaks the contract, stages governance changes, and asserts the hook fails.

`commit-msg` hook existed but used legacy emoji output, did not support breaking-change markers, and missed the common ci/perf/build/revert types — meaning Conventional Commits enforcement was partially symbolic. Patch 2 brings it to current spec coverage.

## Scope

- Pre-commit hook: H1 mainline-update generalization, H2 constitution-triggered adapter sync, H4 inspection coverage.
- Commit-msg hook: M6 strengthening.
- Test infrastructure: 28 new tests (helper unit, hook inspection, commit-msg integration, e2e audit failure).
- Out of scope: registry/contract restructuring (Patch 3), template additions (Patch 5).

## Affected Paths

| Path | Change |
|------|--------|
| `.githooks/pre-commit.ps1` | New helpers `Get-NonNoteSharedLayerFiles`, `Get-StagedMainlineUpdateNotes`; H1 rule generalized to all shared-layer files; H2 calls `Test-StagedAgentBootstrapForProject -RequireAllAdaptersStaged` when constitution staged. |
| `.githooks/commit-msg.ps1` | Replace emoji with `[OK]/[WARN]/[ERROR]/[INFO]`; accept `feat!:` and `BREAKING CHANGE:` footer; expand allowed types; allow merge/revert canonical commits; skip `#` comment lines for subject. |
| `studio/tests/pre-commit.Tests.ps1` | New `Describe` blocks: helpers (9 tests), defensive marker inspection (3 tests), H3 e2e audit failure (1 test). |
| `studio/tests/commit-msg.Tests.ps1` | New file with 18 integration tests covering the strengthened format. |
| `studio/tests/constitution-contract.Tests.ps1` | Phase freshness threshold 3 → 4 months. |

## Impact

- 83 → 111 tests passing (28 new). All previously passing tests still pass.
- `check-speckit-runtime.ps1 -Json` still `VALID: true`, `ERROR_COUNT: 0`, `WARNING_COUNT: 0`.
- New rule for committers: any commit touching shared-layer governance MUST stage a `docs/mainline-updates/*.md` note. This patch's own commit follows the rule.
- Behavior change: commits to `studio/constitution/constitution.md` will now fail unless `AGENTS.md`, `CLAUDE.md`, and `.github/copilot-instructions.md` are also staged with matching `**Studio Constitution Version:**` strings. Use `pwsh ./studio/scripts/powershell/sync-agent-bootstrap.ps1` to regenerate adapters after constitution edits.
- Commit-msg hook will reject malformed subjects more strictly. Migration: review WIP / experimental commit messages before re-running git commit; existing local history is unaffected.

## Validation

- `pwsh ./studio/scripts/powershell/run-governance-tests.ps1` -> 111 passed, 0 failed, 0 skipped.
- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json` -> `VALID: true`, `ERROR_COUNT: 0`.
- H3 e2e test mirrors workspace, breaks contract, asserts hook exit != 0 and `'Shared runtime audit failed against staged snapshot'` message — passes.
- Commit-msg integration tests cover 18 cases (accepts feat/fix/docs/refactor/chore/test/style/ci/perf/build/revert with and without scope, breaking marker, merge/revert canonical, BREAKING CHANGE footer; rejects unknown types, empty, comment-only).

## Merge Notes

- Sequential after Patch 1 (`2026-04-30-critical-bug-cleanup.md`).
- Subsequent patches MUST follow Conventional Commits format and ship with their own mainline-update note (this is now machine-enforced).
- Patch 3 (registry & contract restructuring) is unblocked once this lands.

## Follow-ups

- The H3 e2e test currently mirrors the full studio subset. If TestDrive setup time becomes a concern, consider creating a shared minimal-workspace fixture under `studio/tests/fixtures/` that other staged-snapshot tests can reuse.
- `commit-msg` hook does not yet validate body line wrap (72-char per line) — leave to future style enforcement if requested.
