# Mainline Update Note: Analyze Completion Machine Gate

**Date**: 2026-07-12
**Source Branch**: `feature/wave-3-security-and-workflows`
**Target Branch**: `main`
**Status**: Draft
**Related Commits**: TBD
**Related PR**: N/A

## Summary

- `setup-implement.ps1` now verifies `/speckit.analyze` actually completed before reporting READY:
  a missing `analysis-checklist.md` blocks (analyze never ran) and an `**Analysis Status**: PENDING`
  blocks (analyze not signed off). Previously a missing checklist was indistinguishable from
  "analyzed, no Critical findings".
- Adds an `**Analysis Status**: PENDING` marker (with an Analyze Gate section) to
  `checklist-template.md`, so scaffolded analysis checklists start PENDING and the operator flips
  them to COMPLETE only after recording findings.
- New `ANALYZE_STATE` field in the JSON output (`missing` / `pending` / `complete`), two new
  negative-path tests, and a new `setup-implement-analyze-gate` scriptInvariant.

## Why This Update Exists

An adversarially verified external analysis (2026-07-11, claims B1-B3, confirmed 3/3) showed the
analyze -> implement transition was the one mandatory stage with no machine gate:
`speckit.analyze.agent.md` is read-only and writes no file, and `setup-implement.ps1` returned an
empty finding set when `analysis-checklist.md` was absent, so `READY:true` came back for a feature
that was never analyzed. This fix places enforcement at the gate (machine, non-bypassable) rather
than the agent prompt, consistent with the "gate over prompt" principle in
`studio/knowledge-base/learnings.md`. It also machine-closes the dangerous tasks -> implement
shortcut (verified claim A3): skipping analyze now blocks implement regardless of any agent handoff.

## Scope

- Gate logic + template marker + tests + contract invariant.
- Analyze stays read-only; the operator records findings and flips the status (operator-in-the-loop,
  matching the existing `workflow.yml` operator_message design).
- Non-goals: readiness / ECI re-verification at implement (already gated upstream at
  `setup-plan.ps1` via `Assert-ReadyForPlan`, so re-checking here would be redundant); agent-prompt
  handoff-graph edits and the Specify assumption-policy conflict (verified claims A1/A2/A5) are a
  separate agent-layer decision, deliberately not bundled here.

## Affected Paths

| Path | Change |
|------|--------|
| `studio/scripts/powershell/setup-implement.ps1` | `Get-AnalyzeCompletionState`; missing/pending analyze blocks; `ANALYZE_STATE` output; updated help |
| `studio/templates/sdd-docs/checklist-template.md` | New Analyze Gate section with `**Analysis Status**: PENDING` |
| `studio/tests/stage-entry-gates.Tests.ps1` | READY test now requires complete analyze; two new negative-path tests; `-Task`/critical tests use a complete checklist |
| `studio/runtime/shared-runtime-contract.json` | New `setup-implement-analyze-gate` scriptInvariant |
| `docs/mainline-updates/2026-07-12-analyze-completion-gate.md` | This note |
| `docs/mainline-updates/README.md` | Index entry |

## Impact

- `/speckit.implement` can no longer proceed on an un-analyzed feature; the blocker message is
  self-documenting (tells the operator to set the status to COMPLETE after recording findings).
- Existing features whose `analysis-checklist.md` predates the marker will read as PENDING and
  block until an operator confirms and flips them, or `-Force` is used for inherited-feature
  investigation. This is the intended fail-loud default.

## Validation

- `Invoke-Pester studio/tests/stage-entry-gates.Tests.ps1`: 25/25 passed (2026-07-12), including
  the two new negative-path tests (missing checklist blocks; PENDING blocks).
- Full governance suite: 249 passed / 0 failed / 1 skipped.
- `check-speckit-runtime.ps1`: Errors 0 / Warnings 0 with the new invariant active.
- Change manifests: none required.

## Merge Notes

- Part of the correctness/safety batch derived from the verified external analysis; ready to merge
  with the Wave-3 branch.

## Follow-ups

- Agent-layer decision (separate batch): remove the constitution-violating clarify skip clause
  (A2), resolve the specify -> readiness / tasks -> implement handoff shortcuts (A1/A3) and the
  Specify informed-guesses vs constitution conflict (A5), then re-seed the Claude agent mirrors.
- Update `speckit.analyze.agent.md` to instruct the operator to flip the Analyze Gate status
  (currently the self-documenting blocker message covers discoverability).
