# Mainline Update Note: Stage Entry Gates for the Other Six SDD Stages (Patch 8 of governance review)

<!--
  Part of the v1.8.0 deep review remediation series. This is Patch 8 of 9.
-->

**Date**: 2026-05-01
**Source Branch**: `main`
**Target Branch**: `main`
**Status**: Ready
**Related Commits**: TBD
**Related PR**: N/A

## Summary

- New PowerShell entry-gate scripts for the five stages that previously had no script-level gate:
  - `studio/scripts/powershell/setup-clarify.ps1`
  - `studio/scripts/powershell/setup-readiness.ps1`
  - `studio/scripts/powershell/setup-tasks.ps1`
  - `studio/scripts/powershell/setup-analyze.ps1`
  - `studio/scripts/powershell/setup-implement.ps1`
- Each script supports `-FeatureDir`, `-Json`, `-Force`, and `-Help`, and emits a uniform JSON shape
  containing `STAGE`, `READY`, `FORCED`, `FEATURE_DIR`, `BLOCKERS`, and `MESSAGES` so agents and
  audit tools can consume the result the same way.
- `setup-analyze.ps1` and `setup-implement.ps1` reuse `validate-feature-structure.ps1` (Patch 7)
  for structural prerequisite checks rather than duplicating its logic.
- Five new contract invariants under `studio/runtime/shared-runtime-contract.json` lock the entry-gate
  surface so future edits to these scripts cannot silently weaken the gates.
- New Pester suite `studio/tests/stage-entry-gates.Tests.ps1` (23 fixture-driven tests) exercises
  happy-path and blocker-path behavior for every script plus a JSON-shape consistency check.

## Why This Update Exists

The deep review identified that `setup-plan.ps1` was the only PowerShell-level entry gate among the
seven mandatory SDD stages. This created three concrete weaknesses:

- **L1a–L1e** — Stage order in constitution §2 was enforced only by agent prompts. A direct script
  invocation could skip prerequisite stages without surfacing a blocker.
- **No reusable structural pre-check** — `validate-feature-structure.ps1` (Patch 7) was available
  but had no caller wiring; analyze and implement could not benefit from it.
- **No emergency override** — When inheriting a feature mid-stage (or recovering after a botched
  partial run), there was no documented escape hatch. `-Force` provides one with explicit
  `[FORCED]` logging.

## Scope

- New scripts only: `setup-clarify.ps1`, `setup-readiness.ps1`, `setup-tasks.ps1`,
  `setup-analyze.ps1`, `setup-implement.ps1`. None of the existing scripts changed shape.
- Five new contract invariants. No existing invariants modified.
- New Pester suite `studio/tests/stage-entry-gates.Tests.ps1` (23 tests, 6 Describe blocks).

Out of scope:

- Wiring agent prompts (`.github/agents/speckit.*.agent.md`) to call the new scripts. Prompts
  remain the human-facing surface; the scripts are an additional machine-verifiable layer that
  agents and CI may opt into. Prompt-level wiring is deferred to a future patch where the prompt
  invocation contract is designed properly.
- A combined `run-all-stages` harness. Each stage entry gate runs independently to keep the surface
  area small and the failure messages precise.

## Affected Paths

| Path | Change |
|------|--------|
| `studio/scripts/powershell/setup-clarify.ps1` | New: enumerates `[NEEDS CLARIFICATION]` markers, requires spec.md. |
| `studio/scripts/powershell/setup-readiness.ps1` | New: blocks while spec markers remain; scaffolds readiness-assessment.md and `readiness/eci/`. |
| `studio/scripts/powershell/setup-tasks.ps1` | New: requires plan.md with a Version field; scaffolds tasks.md. |
| `studio/scripts/powershell/setup-analyze.ps1` | New: requires spec/readiness/plan/tasks; calls `validate-feature-structure.ps1`; scaffolds analysis-checklist.md. |
| `studio/scripts/powershell/setup-implement.ps1` | New: requires at least one pending canonical task; blocks on unresolved Critical analyze findings; supports `-Task T###` filter. |
| `studio/runtime/shared-runtime-contract.json` | Adds `setup-clarify-spec-gate`, `setup-readiness-clarify-gate`, `setup-tasks-plan-gate`, `setup-analyze-prerequisites`, `setup-implement-tasks-gate`. |
| `studio/tests/stage-entry-gates.Tests.ps1` | New: 23 fixture-driven Pester tests across 6 Describe blocks. |

## Impact

- 166 → 189 tests, 0 failed, 0 skipped.
- `check-speckit-runtime.ps1 -Json` -> `VALID: true`, `ERROR_COUNT: 0`. Five new contract invariants verified.
- `generate-impact-registry.ps1 -Compare` -> in-sync.
- All five entry gates produce machine-verifiable JSON; agents and CI can consume `READY=false`
  with `BLOCKERS[]` to drive remediation messages instead of silent stage skipping.

## Validation

- `pwsh ./studio/scripts/powershell/run-governance-tests.ps1` -> 189 passed, 0 failed.
- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json` -> `VALID: true`, all
  invariants green.
- `pwsh ./studio/scripts/powershell/generate-impact-registry.ps1 -Compare` -> in-sync.
- Manual smoke: each new script invoked against a fresh fixture directory produces the expected
  JSON shape and exit code.

## Merge Notes

- Patch 8 closes the script-layer gap that constitution §2 always implied but only enforced via
  agent prompts. The seven-stage order is now machine-verifiable for the first time.
- No external-facing behavior change for happy-path callers because none of the existing scripts
  were touched. The new scripts are purely additive.
- `-Force` exists for genuine emergencies (recovering an inherited feature, replaying a partial
  stage). Audit logs will show `FORCED: true` for any forced run.

## Follow-ups

- Patch 9 housekeeping: testResults.xml in `.gitignore` (L2), TestResult.OutputPath rerouting
  (L3), tasks-template phase HTML comment (M16), change-manifest agent wiring (M17), Project
  Structure table alignment (M18), speckit.discover.agent.md frontmatter (L8), governance-anchor
  pilot (L12).
- Future patch: agent prompts opt into the new entry-gate scripts so a `/speckit.<stage>`
  invocation surfaces the same `BLOCKERS[]` the script would emit.
- Future patch: an `assert-stage-ready` thin wrapper that selects the right setup-* script based
  on a stage name argument, for callers (CI, mainline-update gates) that don't want to know the
  full path.
