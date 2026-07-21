# Mainline Update Note: R-D03 Implement Task Priority and Parallelism

**Date**: 2026-07-21
**Source Branch**: `feature/wave-3-security-and-workflows`
**Target Branch**: `main`
**Status**: Draft
**Related Commits**: `TBD`
**Related PR**: https://github.com/dtgfdgfgf/SDD-WorkSpace/pull/3
**Reconciliation Status**: Open
**Validation Scope**: Batch

## Revalidation (2026-07-21, Self-Application Entry Reset)

Implementation attempt `8101f9a380eb27c5004bece9aad77d42b2cc8a51` technically passed
747 governance tests with 0 failures and a canonical runtime audit with 0 errors and 0 warnings.
Those results do not authorize R-D03 closure because the attempt began before a committed,
dated, owner-authorized R-D03 remediation plan existed. Constitution Section 2.1 makes that an
entry prerequisite, not a post-implementation accounting field.

Truth-restoration commit `687625af6a9df299c1037e1ba3ec29ef154dc6d3` returned the five
implementation surfaces to the pre-R-D03 semantics and kept this note `Draft`, `TBD`, and
`Open`. On 2026-07-21, after the defect was reported, the owner explicitly authorized a clean
R-D03-only re-entry. The dated remediation plan was committed with that reset so that the new
implementation begins from a parent commit containing both the plan and the restored baseline.

Re-entry requires a new implementation commit after this reset, the discriminating old-fails and
new-passes evidence, canonical runtime and complete governance gates, a committed Batch gate, and
append-only accounting. The refuted attempt remains in Git history as evidence and must not be
cited as the closing implementation.

## Clean Re-entry Implementation (2026-07-21)

This candidate implementation begins after truth-restoration and plan commit
`687625af6a9df299c1037e1ba3ec29ef154dc6d3`. With only the new focused assertions applied
to that committed old-semantic baseline, the focused file reported 18 passed and 2 failed.

The candidate now reapplies the bounded R-D03 source, mirror, contract, and test changes. Related
commit evidence remains `TBD` until this candidate is committed; this note remains `Draft` and
reconciliation remains `Open` until the new implementation and all closure gates exist.

## Summary

- Restore truthful `Draft` and `Open` accounting after the missing pre-implementation plan was found.
- Establish an owner-authorized R-D03-only clean re-entry plan before any new implementation.
- Reapply the R-D03 repair only after the reset and plan commit exist in the parent history.
- Preserve R-G03 and every other residual as separate, unchanged work.

## Why This Update Exists

R-D03 records an authority conflict: the Tasks agent defines `[P#]` as delivery priority and
requires parallelism to be separate from the checklist line, while the pre-repair Implement agent
interprets `[P]` as permission to run tasks concurrently. That conflict can change execution order
without the dependency metadata required by the task authority.

The first repair attempt addressed the technical conflict but did not satisfy the self-application
entry chronology. Surface Truthfulness therefore requires a reset before the same repair can be
re-entered. The mandatory Implement entry gate is outside this residual and remains governed by
the completed R-D02 repair.

## Scope

In scope:

- R-D03 task priority and parallelism semantics only.
- Canonical Copilot Implement-agent source and deterministic Claude mirror.
- Revert-sensitive runtime-contract and Pester evidence.
- Truth restoration and a committed clean re-entry plan.

Out of scope:

- Consumer drift under `projects/` or `learning/`.
- R-G03 version-pinned reconciliation or any other residual finding.
- Workflow promotion, Aggregate readiness, merge, push, or PR-thread resolution.

## Affected Paths

| Path | Change |
|------|--------|
| `.github/agents/speckit.implement.agent.md` | Reset in `687625a`, then reapply canonical priority and parallelism semantics |
| `.claude/agents/speckit-implement.md` | Reset in `687625a`, then regenerate the matching dependent mirror |
| `studio/runtime/shared-runtime-contract.json` | Reset in `687625a`, then restore the two R-D03 invariants |
| `studio/tests/claude-agent-parity.Tests.ps1` | Reset in `687625a`, then restore the two focused assertions |
| `studio/tests/check-speckit-runtime.Tests.ps1` | Reset in `687625a`, then restore the coordinated revert mutation |
| `docs/sdd-workspace-repair-inventory-and-update-plan-2026-07-12_zhTW.md` | Keep R-D03 OPEN and record the reset chronology |
| `docs/sdd-workspace-wave-3-remediation-plan-2026-07-14_zhTW.md` | Commit the owner-authorized R-D03-only re-entry plan |
| `docs/README.md` | Align the ledger index with the reset status |
| `docs/mainline-updates/README.md` | Keep this note indexed as Draft |

## Impact

- Attempt `8101f9a` is retained as technically useful but non-closing evidence.
- R-D03 remains `OPEN` until a new implementation begins after the committed plan and passes all
  closure gates.
- The branch, Aggregate note, workflow promotion state, and all unrelated residuals remain
  unchanged.

## Impact Reconciliation

| Target | Impact | Disposition | Evidence |
|--------|--------|-------------|----------|
| `.github/agents/*.agent.md` | `must_review` | `pending` | Clean re-entry must update the canonical Implement source after this reset. |
| `.claude/agents/*.md` | `must_update` | `pending` | Clean re-entry must regenerate and verify the dependent mirror after the plan exists. |
| `studio/runtime/shared-runtime-contract.json` | `must_review` | `pending` | Clean re-entry must restore contract-bound R-D03 invariants. |
| `.githooks/pre-commit.ps1` | `must_review` | `pending` | Clean re-entry must confirm that the generic staged contract consumer requires no code change. |
| `studio/scripts/powershell/check-speckit-runtime.ps1` | `must_review` | `pending` | Clean re-entry must prove that the generic audit consumes both R-D03 invariants. |
| `studio/tests/*.ps1` | `must_review` | `pending` | Clean re-entry must restore focused parity and coordinated revert coverage. |
| `.github/agents/speckit.tasks.agent.md` | `maybe_review` | `reviewed-no-change` | It already defines `[P#]` as delivery priority and requires parallelism outside the checklist line. |
| `studio/templates/sdd-docs/tasks-template.md` | `maybe_review` | `reviewed-no-change` | It defines `[P#]` as priority, contains no inline `[P]` marker, and supplies separate `Depends on` metadata. |
| `studio/constitution/constitution.md` | `maybe_review` | `reviewed-no-change` | Section 2.1 requires this reset and the committed pre-implementation plan. |

## Validation

- Attempt `8101f9a` produced the intended discriminating evidence: pre-repair assertions were
  18 passed and 2 failed; proposed parity was 20 passed and 0 failed; coordinated mutation was
  1 passed and 0 failed.
- Attempt `8101f9a` also reported 747 passed, 0 failed, 0 skipped, and 0 not run in the full suite,
  plus runtime `VALID=true` with 0 errors and 0 warnings. These are explicitly non-closing results.
- Truth-restoration commit `687625af6a9df299c1037e1ba3ec29ef154dc6d3` reports focused
  parity 18 passed and 0 failed, full suite 744 passed and 0 failed, committed runtime
  `VALID=true` with 0 errors and 0 warnings, staged hook pass, and clean diff hygiene.
- After the plan commit, applying only the new R-D03 focused assertions to the restored old
  semantics reports 18 passed and 2 failed.
- The clean re-entry candidate reports focused parity 20 passed and 0 failed. The coordinated
  source-and-mirror legacy mutation reports 1 passed and 0 failed with 40 not run; Claude parity
  remains valid while both R-D03 contract invariants fail.
- `pwsh ./studio/scripts/powershell/seed-claude-agents.ps1 -Verify -Json` reports
  `VALID=true` and 0 errors for the candidate mirror.
- Candidate full-suite, committed runtime, Batch, Aggregate, and accounting evidence remain
  pending while this note is Draft.

## Merge Notes

- This note is `Draft` and does not authorize R-D03 closure or merge.
- The branch remains `NOT READY TO MERGE`; R6, R-E09, R-E11, residual dispositions, promotion,
  Aggregate acceptance, merge accounting, and post-merge evidence remain open.
- `sdd-pipeline` remains experimental, default-disabled, and execution-denied.

## Follow-ups

- Commit this reset and owner-authorized plan before reapplying any R-D03 implementation.
- Re-enter R-D03 in a new implementation commit, rerun all required gates, and account for closure
  only if every result remains valid.
- Reconcile R-G03 separately against explicitly pinned CLI, template, and upstream-doc versions.
