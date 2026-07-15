# Mainline Update Note: RB-1 Critical Governance Gates

**Date**: 2026-07-15
**Source Branch**: `feature/wave-3-security-and-workflows`
**Target Branch**: `main`
**Status**: Draft
**Related Commits**: `TBD`
**Related PR**: https://github.com/dtgfdgfgf/SDD-WorkSpace/pull/3
**Reconciliation Status**: Closed

## Summary

- Preserve the canonical task-ID inventory at the first terminal Implement arrival, and require every
  baseline ID to remain canonical, unique, and checked before completion. Terminal completion also
  revalidates the Implement authorization evidence so evidence removed between resumes fails closed.
- Make `/speckit.implement` begin with a non-bypassable readiness, conditional ECI, Analyze-result,
  intent-obligation, artifact-currentness, and feature-structure gate. Analyze now produces a
  schema-governed machine result; the Markdown checklist is informational only.
- Centralize workflow registry authorization for `run-workflow.ps1` and `list-workflows.ps1`, validate
  catalog and state against trusted schemas, parse booleans strictly, and deny missing, null, scalar,
  wrong-type, or schema-substitution inputs.

## Why This Update Exists

The 2026-07-14 governance re-review reproduced three Critical RB-1 bypasses. RVR-01 showed that the
terminal postcondition could report completion after `tasks.md` lost its task inventory. RVR-02
showed that a direct `/speckit.implement` invocation skipped readiness, ECI, and Analyze enforcement.
RVR-03 showed that PowerShell's `[bool]'false'` conversion, absent schema validation, and a missing
state fallback could authorize a workflow that governance intended to deny. These counterexamples
reopened R-B02 and R-B05 and assigned closure to R-B19, R-D02 with R-B08, and R-B20.

## Scope

- RB-1 only: terminal completion integrity, the mandatory Implement entry and completion gates, the
  Analyze machine-result contract, feature-structure readiness and ECI shape, and shared workflow
  registry authorization.
- No consumer drift repair under `projects/` or `learning/`, no PR thread resolution, no main merge,
  and no workflow promotion. `sdd-pipeline` remains experimental and execution-denied pending R6.

## Affected Paths

| Path | Change |
|------|--------|
| `.github/agents/speckit.analyze.agent.md`, `.claude/agents/speckit-analyze.md` | Define the read-only, schema-valid Analyze machine result and exact intent obligations. |
| `.github/agents/speckit.implement.agent.md`, `.claude/agents/speckit-implement.md` | Make `setup-implement.ps1` the first action and remove the direct-entry bypass. |
| `studio/runtime/analysis-result.schema.json` | Add the canonical machine-readable Analyze authorization schema. |
| `studio/runtime/shared-runtime-contract.json` | Anchor the RB-1 invariants so reverting the enforcement breaks the runtime audit. |
| `studio/scripts/powershell/setup-analyze.ps1`, `studio/scripts/powershell/setup-implement.ps1` | Bind trusted schemas; enforce readiness, conditional ECI, Analyze, exact intent accounting, current artifact hashes, and validator exit status. |
| `studio/scripts/powershell/validate-feature-structure.ps1` | Fail closed when readiness or the ECI container is absent and require a complete dossier when ECI is engaged. |
| `studio/scripts/powershell/workflow-engine.ps1` | Persist baseline task IDs and revalidate Implement authorization before terminal completion. |
| `studio/scripts/powershell/common.ps1`, `studio/scripts/powershell/run-workflow.ps1`, `studio/scripts/powershell/list-workflows.ps1` | Share strict, trusted-schema workflow authorization between execution and listing. |
| `studio/workflows/manifest.schema.json`, `studio/workflows/sdd-pipeline/workflow.yml` | Model explicit terminal completion validation and bind it to the Implement gate. |
| `studio/templates/sdd-docs/checklist-template.md` | Mark the Markdown Analyze checklist informational rather than authoritative. |
| `studio/tests/*.Tests.ps1`, `studio/tests/fixtures/terminal-completion-validator.ps1` | Add discriminating and regression coverage for every RB-1 bypass class. |

## Impact

- Deleting, renaming, deforming, replacing, or blanking baseline tasks can no longer manufacture a
  completed workflow run.
- Direct Implement entry and a later terminal resume use the same authorization evidence and fail
  closed on stale, missing, malformed, or semantically incomplete evidence.
- Workflow execution and workflow listing use one authorization decision; string booleans, nulls,
  wrong shapes, a missing state ledger, and redirected permissive schemas are denied.

## Impact Reconciliation

| Target | Impact | Disposition | Evidence |
|--------|--------|-------------|----------|
| `.claude/agents/*.md` | `must_update` | `updated` | Analyze and Implement Claude mirrors changed with their canonical Copilot sources; contract and direct-entry tests cover both surfaces. |
| `studio/runtime/shared-runtime-contract.json` | `must_review` | `updated` | New agent, schema, script, engine, runner, listing, and workflow invariants pass the shared runtime audit. |
| `.githooks/pre-commit.ps1` | `must_review` | `reviewed-no-change` | The existing staged-snapshot audit consumes `sharedGatePaths` and needs no hook semantic change. |
| `studio/scripts/powershell/check-speckit-runtime.ps1` | `must_review` | `reviewed-no-change` | The generic contract consumer accepts the new invariants and reports `VALID=true`, 0 errors, 0 warnings. |
| `studio/constitution/constitution.md` | `maybe_review` | `reviewed-no-change` | RB-1 operationalizes existing v1.8.0 stage order, Surface Truthfulness, intent, ECI, and note rules without changing constitutional policy. |
| `.github/agents/*.agent.md` | `maybe_review` | `updated` | Canonical Analyze and Implement agents now expose the machine result and first-action gate. |
| `studio/tests/path-traversal-hardening.Tests.ps1` | `must_review` | `reviewed-no-change` | Existing setup-analyze/setup-implement boundary tests remain green; RB-1 gate semantics are covered in stage-entry tests. |
| `studio/scripts/powershell/workflow-engine.ps1` | `must_review` | `updated` | Baseline inventory and explicit terminal completion validation are implemented and covered by old/new negative evidence. |
| `studio/scripts/powershell/validate-workflow.ps1` | `must_review` | `reviewed-no-change` | The validator already consumes `manifest.schema.json`; workflow schema tests prove the new field is accepted only in the terminal shape. |
| `studio/tests/sdd-pipeline.Tests.ps1` | `must_review` | `updated` | Pipeline tests assert the Analyze machine artifact and terminal completion validator binding. |
| `studio/tests/workflow-schema.Tests.ps1` | `must_review` | `updated` | Schema tests reject completion validation on a non-terminal agent command. |
| `WORKSPACE_STRUCTURE.md` | `maybe_review` | `reviewed-no-change` | No workspace path or ownership boundary changed. |
| `studio/QUICKSTART.md` | `maybe_review` | `reviewed-no-change` | No user-facing workflow invocation or RunState location changed in RB-1. |

## Validation

- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json`: `VALID=true`, 0 errors,
  0 warnings.
- `pwsh ./studio/scripts/powershell/run-governance-tests.ps1`: 420 passed, 0 failed, 0 skipped;
  the prior branch baseline was 361 passed, 0 failed.
- R-B19 discriminating overlay: all five required task-inventory tamper cases completed under the old
  implementation and are denied by the new implementation; the current terminal inventory block is
  9 passed.
- RVR-02 discriminating overlay: the original 17 direct-entry cases were 0 of 17 under the old gate
  and 17 of 17 under the new gate. The current terminal revalidation set is 13 of 13; the old engine
  passed only its positive control and incorrectly completed all 12 negative cases.
- R-B20 discriminating overlay: the original 13 authorization cases were 0 of 13 under the old
  implementation and 13 of 13 under the new implementation. The expanded current set is 15 of 15,
  including shaped permissive schema substitutions.
- `git diff --check`: no whitespace errors.

## Merge Notes

- This Draft records the implementation batch before its commit hash exists. Accounting will bind
  the concrete implementation hash and move the note to Ready only after staged and final-HEAD gates
  pass.
- RB-1 completion does not make PR #3 ready to merge. RB-2 through RB-5 and R6 remain mandatory.

## Follow-ups

- Execute RB-2 through RB-5 and R6 from the dated remediation plan. Do not re-promote
  `sdd-pipeline` before R6 acceptance.
