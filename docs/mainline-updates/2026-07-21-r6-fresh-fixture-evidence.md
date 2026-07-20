# Mainline Update Note: R6 Fresh-Fixture Evidence

**Date**: 2026-07-21
**Source Branch**: `feature/wave-3-security-and-workflows`
**Target Branch**: `main`
**Status**: Draft
**Related Commits**: `TBD`
**Related PR**: https://github.com/dtgfdgfgf/SDD-WorkSpace/pull/3
**Reconciliation Status**: Open
**Validation Scope**: Batch

## Summary

- Add one reproducible fresh-fixture journey for the canonical `sdd-pipeline` graph, using an
  isolated project and an isolated fixture-only approved registry.
- Exercise canonical authorization denial, DryRun isolation, workflow-byte mutation denial,
  non-ready rejection and restart, ECI re-entry, Analyze Critical blocking, and terminal baseline
  completion.
- Bind the evidence markers to the shared runtime contract and make the canonical audit fail when
  the terminal marker is removed.

This note covers an R6 evidence sub-batch only. It does not complete R6, approve or enable the
canonical workflow, accept open ledger findings, make the branch merge-ready, or authorize a push
or merge.

## Why This Update Exists

The Wave-3 review requires a saved fresh-fixture execution that joins the previously isolated
runtime gates into one coherent journey. Unit tests already cover individual status and outcome
matrices, but they do not by themselves prove that a new isolated run can recover from a non-ready
route, complete ECI re-entry, block an unresolved Critical finding, and reject partial terminal
completion before succeeding.

The canonical catalog intentionally remains experimental, default-disabled, and
execution-denied. The test therefore copies the exact canonical workflow and manifest bytes into a
temporary Studio root, binds those bytes to a fixture-only approval digest, and enables only the
temporary state entry. It never changes the canonical registry to obtain a positive result.

## Scope

In scope:

- A Pester 5.7.1 fresh-fixture E2E for the canonical `sdd-pipeline` workflow version 1.1.0.
- Revert-sensitive shared runtime contract markers and one audit negative.
- Canonical workflow, catalog, state, `projects/`, and `learning/` no-write assertions.

Out of scope:

- Workflow promotion, canonical catalog or state mutation, PR thread resolution, push, merge, or
  post-merge validation.
- Repair or disposition of R-A21, R-B23, R-C04, R-C06, R-D03, R-E11, R-F04, R-J03, R-E09, or
  any other residual finding.
- Consumer drift inside `projects/` or `learning/`.

## Affected Paths

| Path | Change |
|------|--------|
| `studio/tests/r6-fresh-fixture-e2e.Tests.ps1` | Add the isolated R6 seven-stage, ECI, recovery, and terminal journey |
| `studio/runtime/shared-runtime-contract.json` | Require all nine evidence markers and their key behavioral anchors |
| `studio/tests/check-speckit-runtime.Tests.ps1` | Prove removal of the terminal marker makes the canonical audit fail |
| `docs/mainline-updates/2026-07-21-r6-fresh-fixture-evidence.md` | Record the bounded evidence sub-batch |
| `docs/mainline-updates/README.md` | Index this note while preserving its Draft state |

## Impact

- Maintainers can replay one coherent R6 fixture instead of inferring integration behavior from
  separate unit suites.
- The current canonical workflow remains denied; a fixture-only approval cannot be treated as
  promotion evidence.
- Removing the E2E surface or one of its required evidence markers makes
  `check-speckit-runtime.ps1` fail closed.

## Impact Reconciliation

| Target | Impact | Disposition | Evidence |
|--------|--------|-------------|----------|
| `.githooks/pre-commit.ps1` | `must_review` | `reviewed-no-change` | The hook already invokes the canonical runtime audit that consumes `scriptInvariants`; no hook change is required. |
| `studio/scripts/powershell/check-speckit-runtime.ps1` | `must_review` | `reviewed-no-change` | Generic path-contract enforcement consumes the new invariant; the focused marker-removal negative passes. |
| `studio/constitution/constitution.md` | `maybe_review` | `reviewed-no-change` | The evidence sub-batch implements existing validation and Surface Truthfulness duties without changing constitutional authority. |

## Validation

Observed before the implementation commit:

- `r6-fresh-fixture-e2e.Tests.ps1`: 1 passed, 0 failed, 0 skipped in 80.25 seconds.
- Required markers observed:
  `R6_FRESH_FIXTURE_CANONICAL_REGISTRY_DENIED`,
  `R6_FRESH_FIXTURE_DRYRUN_ISOLATED`,
  `R6_FRESH_FIXTURE_WORKFLOW_MUTATION_DENIED`,
  `R6_FRESH_FIXTURE_NON_READY_REJECTED`,
  `R6_FRESH_FIXTURE_RESTART_ARCHIVED`,
  `R6_FRESH_FIXTURE_ECI_REENTRY_COMPLETE`,
  `R6_FRESH_FIXTURE_ANALYZE_CRITICAL_BLOCKED`,
  `R6_FRESH_FIXTURE_PARTIAL_IMPLEMENT_BLOCKED`, and
  `R6_FRESH_FIXTURE_TERMINAL_SUCCESS`.
- Focused runtime-contract revert negative: 1 passed, 0 failed; replacing
  `R6_FRESH_FIXTURE_TERMINAL_SUCCESS` produces audit failure ID
  `r6-fresh-fixture-e2e`.
- Canonical `sdd-pipeline/workflow.yml` SHA-256:
  `bd2710491c9a4cdd179f5b559c706ed781c5fbe933fd13dc0570494fba7a26ed`.
- `git diff --check` passes.

The uncommitted canonical runtime audit is expected to remain red only because the sealed
historical-evidence guard requires authority bytes in
`studio/runtime/shared-runtime-contract.json` to match `HEAD`. The implementation commit must be
created before the audit can validate those exact committed bytes. Runtime audit, full governance
suite, Batch, Aggregate, and final worktree hygiene remain pending and this note therefore remains
Draft and Open.

## Merge Notes

- This evidence sub-batch is not merge authorization.
- The Wave-3 umbrella note remains Draft, Open, TBD, and Aggregate.
- `sdd-pipeline` remains experimental, default-disabled, and execution-denied.
- PR #3 remains NOT READY TO MERGE.

## Follow-ups

- Commit the bounded implementation and rerun the runtime audit against committed authority bytes.
- Complete append-only ledger and remediation accounting, including the owner-authorized
  `docs/README.md` ledger-index drift correction.
- Run the full governance, Batch, Aggregate, and diff gates.
- Request owner decisions for residual dispositions, R-E11, workflow promotion, and merge only
  after the evidence sub-batch is independently verified.
