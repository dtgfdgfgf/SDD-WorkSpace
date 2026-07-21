# Mainline Update Note: R-D03 Implement Task Priority and Parallelism

**Date**: 2026-07-21
**Source Branch**: `feature/wave-3-security-and-workflows`
**Target Branch**: `main`
**Status**: Draft
**Related Commits**: `TBD`
**Related PR**: https://github.com/dtgfdgfgf/SDD-WorkSpace/pull/3
**Reconciliation Status**: Open
**Validation Scope**: Batch

## Summary

- Align the Implement agent with the canonical Tasks meaning of `[P#]` as delivery priority.
- Permit parallel execution only when separate dependency metadata explicitly declares it.
- Add source-and-mirror contract anchors plus a coordinated legacy-semantics mutation test.

## Why This Update Exists

R-D03 records an authority conflict: the canonical Tasks surface defines `[P#]` as priority and
forbids an inline parallel marker, while the Implement agent interpreted `[P]` as permission to run
tasks concurrently. That conflict could change execution order without the dependency metadata
required by the task authority.

The mandatory Implement entry gate is outside this residual and remains governed by the completed
R-D02 repair. This batch changes only task priority and parallelism interpretation.

## Scope

In scope:

- Canonical Copilot Implement-agent task parsing and execution semantics.
- Deterministically generated Claude Implement-agent mirror parity.
- Revert-sensitive runtime-contract and Pester coverage for the R-D03 semantics.

Out of scope:

- Consumer drift under `projects/` or `learning/`.
- R-G03 version-pinned reconciliation or any other residual finding.
- Workflow promotion, Aggregate readiness, merge, push, or PR-thread resolution.

## Affected Paths

| Path | Change |
|------|--------|
| `.github/agents/speckit.implement.agent.md` | Read parallelism only from separate dependency metadata and treat `[P#]` as priority |
| `.claude/agents/speckit-implement.md` | Regenerate the dependent Implement-agent mirror with matching semantics |
| `studio/runtime/shared-runtime-contract.json` | Anchor the required source and mirror semantics and forbid the legacy phrases |
| `studio/tests/claude-agent-parity.Tests.ps1` | Assert the canonical priority and parallelism rules on both agent surfaces |
| `studio/tests/check-speckit-runtime.Tests.ps1` | Mutate both surfaces back to the legacy semantics and require the audit to deny them |

## Impact

- `[P#]` cannot be interpreted as permission to execute tasks concurrently.
- Only `Dependencies`, `Parallel Execution Examples`, or `Parallel with:` metadata can authorize
  parallel task execution.
- A coordinated source-and-mirror reversion still fails the runtime contract even when mirror
  parity by itself remains valid.

## Impact Reconciliation

| Target | Impact | Disposition | Evidence |
|--------|--------|-------------|----------|
| `.github/agents/*.agent.md` | `must_review` | `updated` | The canonical Implement source now uses the Tasks-authority semantics. |
| `.claude/agents/*.md` | `must_update` | `updated` | `seed-claude-agents.ps1 -Verify -Json` reports `VALID=true` with 0 errors for the regenerated mirror. |
| `studio/runtime/shared-runtime-contract.json` | `must_review` | `updated` | Two R-D03 invariants bind the source and mirror and reject four legacy instructions. |
| `studio/tests/*.ps1` | `must_review` | `updated` | Focused parity tests and the coordinated revert mutation cover the changed semantics. |
| `.github/agents/speckit.tasks.agent.md` | `maybe_review` | `reviewed-no-change` | The canonical Tasks agent already defines `[P#]` as priority and separate dependency metadata as the parallelism authority. |
| `studio/templates/commands/tasks.md` | `maybe_review` | `reviewed-no-change` | The task template already forbids inline parallel markers and supplies separate dependency metadata. |
| `studio/constitution/constitution.md` | `maybe_review` | `reviewed-no-change` | The existing authority and Surface Truthfulness rules already require this alignment. |

## Validation

- Before the semantic repair, the new focused parity assertions reported 18 passed and 2 failed.
- After the repair, `pwsh -NoProfile -Command "Invoke-Pester -Path './studio/tests/claude-agent-parity.Tests.ps1' -Output Detailed"` reports 20 passed and 0 failed.
- The coordinated source-and-mirror legacy mutation test reports 1 passed and 0 failed; it requires
  Claude parity to remain valid while both R-D03 contract invariants fail.
- `pwsh ./studio/scripts/powershell/seed-claude-agents.ps1 -Verify -Json` reports `VALID=true` and 0 errors.
- `git diff --cached --check` passes.
- The canonical runtime audit, full governance suite, committed Batch gate, and final accounting
  validation remain pending while this note is Draft.

## Merge Notes

- This Draft records an implementation batch in progress and does not authorize merge.
- The branch remains `NOT READY TO MERGE`; R6 and the aggregate Wave-3 obligations remain open.
- `sdd-pipeline` remains experimental, default-disabled, and execution-denied.

## Follow-ups

- Commit the implementation, run the canonical runtime audit and full governance suite, and then
  complete append-only ledger and remediation-plan accounting in a separate commit.
- Reconcile R-G03 separately against an explicitly pinned CLI, template, and upstream-doc version;
  this batch does not choose between the conflicting version facts.
