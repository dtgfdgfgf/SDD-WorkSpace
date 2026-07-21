# Mainline Update Note: R-D03 Implement Task Priority and Parallelism

**Date**: 2026-07-21
**Source Branch**: `feature/wave-3-security-and-workflows`
**Target Branch**: `main`
**Status**: Ready
**Related Commits**: `2f941002009b1e05b33d790e7c6c8fc06e8daf3c`, `7ad8bb76eccccf91a7b87954ce19f97c3ff12951`
**Related PR**: https://github.com/dtgfdgfgf/SDD-WorkSpace/pull/3
**Reconciliation Status**: Closed
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

Clean re-entry implementation requires a new commit after this reset, discriminating old-fails and
new-passes evidence, and canonical runtime and complete governance gates. Retaining the final
`Ready` and `COMPLETED` states additionally requires a committed accounting head, Batch validation,
the expected Aggregate result, and append-only evidence. The refuted attempt remains in Git history
and must not be cited as the closing implementation.

## Clean Re-entry Implementation (2026-07-21)

The clean re-entry implementation begins after truth-restoration and plan commit
`687625af6a9df299c1037e1ba3ec29ef154dc6d3`. With only the new focused assertions applied
to that committed old-semantic baseline, the focused file reported 18 passed and 2 failed.

Commit `2f941002009b1e05b33d790e7c6c8fc06e8daf3c` reapplies the bounded R-D03 source,
mirror, contract, and test changes. Accounting commit
`7ad8bb76eccccf91a7b87954ce19f97c3ff12951` records the coherent R-D03 implementation as
`Ready` with reconciliation `Closed`. Its exact committed tree passed runtime, the complete suite,
Batch validation, and the expected Aggregate check before this final-gate addendum.

## Summary

- Preserve the truthful reset chronology after the missing pre-implementation plan was found.
- Use the committed owner-authorized R-D03-only clean re-entry plan as the implementation parent.
- Complete the R-D03 repair only through the post-authorization commit `2f941002009b1e05b33d790e7c6c8fc06e8daf3c`.
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
| `docs/sdd-workspace-repair-inventory-and-update-plan-2026-07-12_zhTW.md` | Preserve the reset chronology and record R-D03 COMPLETED by the clean re-entry commit |
| `docs/sdd-workspace-wave-3-remediation-plan-2026-07-14_zhTW.md` | Record implementation evidence and the completed accounting-head gates |
| `docs/README.md` | Align the ledger index with v1.22.0 and the R-D03 disposition |
| `docs/mainline-updates/README.md` | Index this note with the same Ready status and final-gate evidence |

## Impact

- Attempt `8101f9a` is retained as technically useful but non-closing evidence.
- R-D03 is completed only by clean re-entry commit
  `2f941002009b1e05b33d790e7c6c8fc06e8daf3c`; R-D02 is not double-counted.
- The branch, Aggregate note, workflow promotion state, and all unrelated residuals remain
  unchanged.

## Impact Reconciliation

| Target | Impact | Disposition | Evidence |
|--------|--------|-------------|----------|
| `.github/agents/*.agent.md` | `must_review` | `updated` | Commit `2f941002009b1e05b33d790e7c6c8fc06e8daf3c` applies the canonical Tasks-authority semantics after the committed reset and plan. |
| `.claude/agents/*.md` | `must_update` | `updated` | Commit `2f941002009b1e05b33d790e7c6c8fc06e8daf3c` contains the regenerated mirror; deterministic verification reports `VALID=true` with 0 errors. |
| `studio/runtime/shared-runtime-contract.json` | `must_review` | `updated` | Commit `2f941002009b1e05b33d790e7c6c8fc06e8daf3c` restores the source and mirror R-D03 invariants after authorization. |
| `.githooks/pre-commit.ps1` | `must_review` | `reviewed-no-change` | The existing hook invokes the staged canonical runtime audit and requires no R-D03-specific logic. |
| `studio/scripts/powershell/check-speckit-runtime.ps1` | `must_review` | `reviewed-no-change` | The generic path-contract consumer rejects the coordinated legacy mutation through both R-D03 invariant IDs. |
| `studio/tests/*.ps1` | `must_review` | `updated` | Commit `2f941002009b1e05b33d790e7c6c8fc06e8daf3c` restores focused parity assertions and the coordinated source-and-mirror mutation. |
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
- Clean re-entry commit `2f941002009b1e05b33d790e7c6c8fc06e8daf3c` reports focused
  parity 20 passed and 0 failed. The coordinated source-and-mirror legacy mutation reports
  1 passed and 0 failed; Claude parity remains valid while both R-D03 contract invariants fail.
- `pwsh ./studio/scripts/powershell/seed-claude-agents.ps1 -Verify -Json` reports
  `VALID=true` and 0 errors for the committed mirror.
- At the same implementation head, `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1
  -Json` reports `VALID=true`, 0 errors, and 0 warnings.
- At the same implementation head, the complete governance suite reports 747 passed, 0 failed,
  0 skipped, and 0 not run.
- Accounting head `7ad8bb76eccccf91a7b87954ce19f97c3ff12951` reports runtime
  `VALID=true`, 0 errors, 0 warnings, and 18 of 18 historical evidence records valid.
- The same accounting tree reports 747 passed, 0 failed, 0 skipped, and 0 not run in 1041.44
  seconds. It is byte-identical to the formal accounting commit because the detached candidate
  and branch commit use the same tree, parent, message, and commit metadata.
- Batch validation from BaseRef `687625af6a9df299c1037e1ba3ec29ef154dc6d3` reports
  `VALID=true`, 0 errors, 0 warnings, and 10 changed paths.
- Aggregate validation against `origin/main` exits 1 with exactly one error:
  `aggregate-note-not-ready` for `docs/mainline-updates/2026-05-05-studio-workflows-runtime.md`.
- `git diff --check` passes and both the accounting worktree and isolated candidate worktree are
  clean.

## Merge Notes

- `Ready` and `Closed` apply only to the coherent R-D03 clean re-entry implementation in commit
  `2f941002009b1e05b33d790e7c6c8fc06e8daf3c`; they do not authorize merge.
- Accounting-head Batch is valid, while Aggregate remains blocked only by the expected Draft
  umbrella note. Any later contrary evidence requires immediate demotion to `Draft` and `Open`,
  with R-D03 restored to `OPEN`.
- The branch remains `NOT READY TO MERGE`; R6, R-E09, R-E11, residual dispositions, promotion,
  Aggregate acceptance, merge accounting, and post-merge evidence remain open.
- `sdd-pipeline` remains experimental, default-disabled, and execution-denied.

## Follow-ups

- Continue R6 without treating this bounded Batch closure as Aggregate acceptance or promotion.
- Reconcile R-G03 separately against explicitly pinned CLI, template, and upstream-doc versions.
