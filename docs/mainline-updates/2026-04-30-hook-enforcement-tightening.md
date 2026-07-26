# Mainline Update Note: Hook enforcement tightening (Patch 2 of governance review)

<!--
  Part of the v1.8.0 deep review remediation series. This is Patch 2 of 9.
-->

**Date**: 2026-04-30
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
`a41637531a8d15b7dc8ee6697d679db3b142d5726f59559f03ac675761a88962`.

The Validation section below is retained as the contemporaneous report for that historical commit.
RB-5 did not rerun those historical counts as current acceptance evidence. Neither this note nor
its historical commit can satisfy present Batch or Aggregate evidence, path coverage,
`must_update` reconciliation, runtime promotion, or the R6 fresh-fixture gate.

The historical phrases claiming coverage of all shared-layer changes are limited to the paths
then enumerated by `sharedGatePaths`. R-A17 later proved that script, hook, extension, and
rename-source coverage remained incomplete. Commit
`4f757e551ee196bc90e51ef21674c4983eae35ec` closed that later finding with category-complete
roots and rename preservation.

## Summary

- Expand mainline-update note enforcement from constitution-only to the shared-layer paths then
  enumerated by `sharedGatePaths` (constitution §12).
- Force `studio/constitution/constitution.md` changes to stage all three workspace adapters together with version-string match.
- Strengthen existing commit-msg hook: support `feat!:` breaking marker, `BREAKING CHANGE:` footer, additional types (`ci`, `perf`, `build`, `revert`), and align output style with pre-commit hook (no emoji per §10.1).
- Extract H1 enforcement into reusable helpers (`Get-NonNoteSharedLayerFiles`, `Get-StagedMainlineUpdateNotes`) for unit testability.
- Add end-to-end staged-snapshot audit failure test (H3) — first integration coverage of `Invoke-SharedRuntimeAuditOnStagedSnapshot`.
- Relax constitution phase freshness assertion from 3 months to 4 months (one-month grace, still quarterly).

## Why This Update Exists

Constitution §12 mandates that any branch touching shared-layer governance, runtime agents,
prompts, templates, hooks, shared scripts, or canonical explanatory docs MUST add a
`docs/mainline-updates/*.md` note. The pre-commit hook previously enforced this rule only for
`studio/constitution/constitution.md` changes, a tiny subset of the then-current
`sharedGatePaths`. Patch 2 broadened enforcement across that enumerated contract surface; it did
not prove that the enumeration itself was category-complete.

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
| `studio/tests/constitution-contract.Tests.ps1` | Phase freshness threshold changed from 3 months to 4 months. |

## Impact

- 83 to 111 tests passing (28 new). All previously passing tests still pass.
- `check-speckit-runtime.ps1 -Json` still `VALID: true`, `ERROR_COUNT: 0`, `WARNING_COUNT: 0`.
- New rule for committers at that commit: any change matching the then-enumerated shared-layer
  paths MUST stage a `docs/mainline-updates/*.md` note. This patch's own commit follows the rule.
- Behavior change: commits to `studio/constitution/constitution.md` will now fail unless `AGENTS.md`, `CLAUDE.md`, and `.github/copilot-instructions.md` are also staged with matching `**Studio Constitution Version:**` strings. Use `pwsh ./studio/scripts/powershell/sync-agent-bootstrap.ps1` to regenerate adapters after constitution edits.
- Commit-msg hook will reject malformed subjects more strictly. Migration: review WIP / experimental commit messages before re-running git commit; existing local history is unaffected.

## Validation

- `pwsh ./studio/scripts/powershell/run-governance-tests.ps1` -> 111 passed, 0 failed, 0 skipped.
- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json` -> `VALID: true`, `ERROR_COUNT: 0`.
- H3 e2e test mirrors workspace, breaks contract, asserts hook exit != 0 and `'Shared runtime audit failed against staged snapshot'` message — passes.
- Commit-msg integration tests cover 18 cases (accepts feat/fix/docs/refactor/chore/test/style/ci/perf/build/revert with and without scope, breaking marker, merge/revert canonical, BREAKING CHANGE footer; rejects unknown types, empty, comment-only).

## Impact Reconciliation

This historical note is sealed migration evidence only. It is excluded from current
reconciliation and cannot satisfy current `must_update` routes. Current RB-5 reconciliation is
owned by `2026-07-20-rb-5-agent-authority-process-truthfulness.md`; this note records no
present-day update disposition.

## Merge Notes

- Sequential after Patch 1 (`2026-04-30-critical-bug-cleanup.md`).
- Subsequent patches MUST follow Conventional Commits format and ship with their own mainline-update note (this is now machine-enforced).
- Patch 3 (registry & contract restructuring) is unblocked once this lands.

## Follow-ups

- The H3 e2e test currently mirrors the full studio subset. If TestDrive setup time becomes a concern, consider creating a shared minimal-workspace fixture under `studio/tests/fixtures/` that other staged-snapshot tests can reuse.
- `commit-msg` hook does not yet validate body line wrap (72-char per line) — leave to future style enforcement if requested.
