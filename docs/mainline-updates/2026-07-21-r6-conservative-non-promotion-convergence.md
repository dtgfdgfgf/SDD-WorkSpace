# Mainline Update Note: R6 Conservative Non-Promotion Convergence

**Date**: 2026-07-21
**Source Branch**: `feature/wave-3-security-and-workflows`
**Target Branch**: `main`
**Status**: Draft
**Related Commits**: TBD
**Related PR**: https://github.com/dtgfdgfgf/SDD-WorkSpace/pull/3
**Reconciliation Status**: Open
**Validation Scope**: Batch

## Summary

- Record the owner-selected conservative R6 convergence plan before implementation begins.
- Register R-B25 and R-B26 as new independent `OPEN` workflow findings.
- Directly repair 17 bounded safety and truthfulness findings, then conditionally disposition 35
  non-critical findings to Wave-4 with exact re-entry triggers.
- Keep `sdd-pipeline` experimental, default-disabled and execution-denied.

## Why This Update Exists

The reconciled residual audit found that the branch can become materially safer and more truthful
without promoting the experimental workflow or attempting every lower-risk backlog item in Wave-3.
The owner selected this conservative route as Choice A. It preserves hard fail-closed boundaries,
requires direct repair where a reachable entrypoint or current governance surface is unsafe, and
permits Wave-4 deferral only when the re-entry condition is explicit.

The same audit found two untracked workflow analogues. R-B25 covers an unenforced and outdated
workflow compatibility field. R-B26 covers deprecated workflow enablement plus unsupported `sync`
provenance. They are separate from R-C04/R-C06 because workflow validation, state and authorization
are distinct execution surfaces. Both enter the ledger as `OPEN`; this Draft note does not claim
their implementation.

## Scope

In scope for the prospective R6 batch:

- Scoped machine authority and deterministic status folding for the findings ledger.
- Shared feature-directory binding and governed path matching.
- Extension and workflow compatibility/lifecycle truthfulness.
- Current shared governance documentation and repository configuration truthfulness.
- Exact per-ID Wave-4 dispositions with re-entry triggers.
- Umbrella reconciliation up to, but not including, an unauthorized merge.

Out of scope:

- Changes inside `projects/` or `learning/` consumers.
- Workflow promotion or execution authorization.
- Push, merge, force-push, history rewrite, PR-thread resolution or post-merge claims.
- Completing R-E09 or R-J03 before their real terminal evidence exists.

## Affected Paths

| Path or group | Planned change |
|---|---|
| `docs/sdd-workspace-repair-inventory-and-update-plan-2026-07-12_zhTW.md` | Register R-B25/R-B26, owner authorization, exact disposition matrix, triggers and future status records |
| `docs/sdd-workspace-wave-3-remediation-plan-2026-07-14_zhTW.md` | Record the committed pre-implementation R6 sequence and gates |
| `studio/constitution/constitution.md` and root adapters | Define bounded authority scope, current phase review and path/type formatting rule |
| `studio/runtime/`, `studio/scripts/powershell/`, `studio/tests/` | Add ledger validation, matcher/feature binding and lifecycle enforcement with discriminating tests |
| Root and `docs/` current surfaces plus `.vscode/settings.json` | Repair the authorized documentation and configuration findings without consumer edits |
| `docs/README.md` and `docs/mainline-updates/README.md` | Keep ledger and note indexes synchronized |

## Impact

- The branch receives a committed Constitution Section 2.1 entry plan before implementation.
- The known inventory becomes 130 findings with current fold 76 `COMPLETED`, 47 `OPEN`,
  6 `DECIDED`, 1 `IN_PROGRESS` and 0 `DISPOSITIONED`.
- No existing finding becomes `COMPLETED` or `DISPOSITIONED` in this plan-only change.
- R-E09 and R-J03 remain terminal blockers; PR #3 remains `NOT READY TO MERGE`.

## Impact Reconciliation

| Target | Impact | Disposition | Evidence |
|---|---|---|---|
| `docs/sdd-workspace-repair-inventory-and-update-plan-2026-07-12_zhTW.md` | `must_update` | `updated` | Version 1.26.0 records the owner authorization, two new OPEN findings, exhaustive matrix and gates. |
| `docs/sdd-workspace-wave-3-remediation-plan-2026-07-14_zhTW.md` | `must_update` | `updated` | Version 1.18.0 records the prospective R6 sequence before implementation. |
| `docs/README.md` | `must_update` | `updated` | Index reports 130 findings and the current plan-only fold. |
| `docs/mainline-updates/README.md` | `must_update` | `updated` | Index state matches this Draft note. |
| `studio/constitution/constitution.md` | `must_update` | `pending` | R-E11/R-D07/R-E08 implementation has not started. |
| `studio/runtime/shared-runtime-contract.json` | `must_update` | `pending` | Direct-repair contract anchors have not been implemented. |

## Validation

Plan-entry validation:

- `git diff --check`
- Mainline-note structural validation without a Ready requirement.
- Independent matrix review: every non-completed ID appears once, R-B25/R-B26 remain OPEN, and
  the current 130-item fold is unchanged except for their registration.

Required before this note may become `Ready`:

- Focused old-fails/new-passes tests and a revert-sensitive invariant for every completed finding.
- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json`, expecting `VALID=true`,
  0 errors and 0 warnings.
- `pwsh ./studio/scripts/powershell/run-governance-tests.ps1`, expecting at least the existing
  747 passed baseline and 0 failed.
- Explicit Batch mainline-note validation from the committed entry-plan base, expecting
  `VALID=true`, 0 errors and 0 warnings.
- Explicit Aggregate validation, allowing only the canonical umbrella blocker while it is Draft.
- `git diff --check` and clean exact-tree worktree verification.

## Merge Notes

- This note remains `Draft`, reconciliation `Open` and Related Commits `TBD` until implementation
  and accounting commits exist and the exact-tree gates pass.
- Choice A keeps explicit Batch/Aggregate validation; the obsolete no-scope invocation has no
  acceptance authority.
- This plan does not authorize workflow promotion, push or merge.

## Follow-ups

- Implement the four direct-repair sub-batches in the committed plan.
- Append evidence-backed status records and the exact 35 Wave-4 re-entry triggers in a separate
  accounting change.
- Stop at the R-E09/R-J03 merge-authorization checkpoint for separate owner direction.
