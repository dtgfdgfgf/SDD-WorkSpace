# Mainline Update Note: RB-3 Mainline Evidence Integrity

**Date**: 2026-07-20
**Source Branch**: `feature/wave-3-security-and-workflows`
**Target Branch**: `main`
**Status**: Draft
**Related Commits**: TBD
**Related PR**: https://github.com/dtgfdgfgf/SDD-WorkSpace/pull/3
**Reconciliation Status**: Open
**Validation Scope**: Batch

## Summary

- Replace incomplete per-file shared-layer gates with category-complete rules for PowerShell scripts,
  Git hooks, and Studio extensions.
- Preserve both source and destination paths from Git rename records so governed content
  cannot leave the gate through a rename.
- Replace shape-only Ready-note evidence with Git commit, branch membership, repository-bound pull
  request, required-section, and changed-path coverage validation.
- Separate coherent Batch closure from Aggregate merge readiness. The Wave-3 umbrella note remains
  Draft and continues to block Aggregate readiness until R6.

## Why This Update Exists

RVR-05 and ledger R-A17 showed that the production `sharedGatePaths` list covered only part of the
shared PowerShell surface, omitted most hooks and every extension path, and used a branch diff that
lost the governed source path during rename detection. The tests used a broader fixture than the
production contract and therefore hid the gap.

RVR-06 and ledger R-A18 showed that Ready evidence accepted any hash-shaped string and any
pull-request-shaped string without proving the commit object, branch membership, repository,
required note sections, or diff coverage. A smaller Ready note could also make the aggregate branch
appear ready while the Wave-3 umbrella note remained Draft with `TBD` evidence.

RB-3 preflight found a separate acceptance-rule contradiction: a correct Aggregate gate must remain
red until R6, while the previous per-batch rule required that same aggregate command to be green.
Owner Choice A on 2026-07-20 resolves this as R-A20 by making Batch and Aggregate explicit,
fail-closed scopes.

## Scope

- R-A17 and RVR-05: category-complete shared roots, recursive matching, rename old and new paths,
  production-contract fixtures, and revert-sensitive runtime audit checks.
- R-A18 and RVR-06: commit-object and branch-range validation, repository-bound PR URLs, visible
  `Scope`, `Impact`, and `Validation` sections, last-touch evidence coverage, and machine-bound
  Aggregate note enforcement.
- R-A20: explicit Batch and Aggregate scopes. RB-3 uses immutable Batch base `8bf9f0e`; hosted
  pull-request and main-push gates use Aggregate.
- No changes under `projects/` or `learning/`. RB-4 through R6, workflow promotion, main merge,
  force-push, history rewriting, and PR-thread resolution remain out of scope.

## Affected Paths

| Path | Change |
|------|--------|
| `studio/runtime/shared-runtime-contract.json` | Define category-complete gates, repository identity, canonical Aggregate note path, CI scope, and revert-sensitive invariants. |
| `.githooks/pre-commit.ps1` | Match recursive category rules and make rename detection explicit while preserving old and new paths. |
| `studio/scripts/powershell/validate-mainline-notes.ps1` | Validate Git name-status records, Ready evidence, required sections, path coverage, and Batch or Aggregate scope. |
| `studio/scripts/powershell/check-speckit-runtime.ps1` | Fail when required shared categories or the canonical Aggregate readiness policy is missing or redirected. |
| `.github/workflows/governance.yml` | Declare Aggregate scope explicitly for hosted pull-request and main-push enforcement. |
| `studio/templates/sdd-docs/mainline-update-note-template.md` | Show the explicit Batch validation command for coherent update-note accounting. |
| `studio/tests/mainline-note-validation.Tests.ps1` | Use production rules and real Git fixtures for commit, PR, section, coverage, aggregate-anchor, and rename counterexamples. |
| `studio/tests/pre-commit.Tests.ps1`, `check-speckit-runtime.Tests.ps1` | Cover recursive production categories, near-prefix exclusions, rename-out, and contract-policy mutation. |

## Impact

- Any descendant of `studio/scripts/powershell/`, `.githooks/`, or `studio/extensions/` now enters the
  shared-layer note gate without per-file maintenance.
- Moving governed content outside a protected category still exposes the old path to the validator.
- Ready notes can no longer rely on nonexistent, wrong-type, or out-of-range commit objects,
  cross-repository or unqualified PR references, hidden required sections, or unrelated commits.
- A Batch note may close one coherent incremental repair. It does not make the full Wave-3 branch
  ready.
- Aggregate validation remains intentionally blocked by
  `docs/mainline-updates/2026-05-05-studio-workflows-runtime.md` until that note is truthfully Ready
  after R6 evidence.

## Impact Reconciliation

| Target | Impact | Disposition | Evidence |
|--------|--------|-------------|----------|
| `studio/runtime/shared-runtime-contract.json` | `must_review` | `pending` | Final canonical audit and mutation-test evidence will be recorded after the implementation commit. |
| `.githooks/pre-commit.ps1` | `must_review` | `pending` | Recursive matching, near-prefix, and rename-out focused results will be recorded after the implementation commit. |
| `studio/scripts/powershell/check-speckit-runtime.ps1` | `must_review` | `pending` | Required-category and canonical-policy mutation results will be recorded after the implementation commit. |
| `studio/scripts/powershell/validate-mainline-notes.ps1` | `must_review` | `pending` | Git-backed evidence and aggregate-anchor results will be recorded after the implementation commit. |
| `.github/workflows/governance.yml` | `maybe_review` | `pending` | Hosted calls must retain explicit Aggregate scope and canonical contract coverage. |
| `studio/templates/sdd-docs/mainline-update-note-template.md` | `maybe_review` | `pending` | The template must retain an explicit Batch validation command. |
| `studio/constitution/constitution.md` | `maybe_review` | `reviewed-no-change` | RB-3 implements the existing Mainline Update Notes and Surface Truthfulness rules without changing constitutional policy. |
| `studio/QUICKSTART.md` | `maybe_review` | `reviewed-no-change` | Workflow invocation and promotion status do not change; maintainer acceptance semantics are recorded in governance plans and this note. |
| `studio/tests/path-traversal-hardening.Tests.ps1` | `must_review` | `reviewed-no-change` | RB-3 does not change path-containment primitives; the suite remains part of the full governance gate. |

## Validation

- Focused production-contract and real-Git suites must pass with no failures.
- Detached old-head overlays must demonstrate that the new negative assertions fail against the old
  implementation and pass against the new implementation.
- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json` must report `VALID=true`, 0
  errors, and 0 warnings.
- `pwsh ./studio/scripts/powershell/run-governance-tests.ps1` must remain above the 579-test RB-2
  baseline with 0 failures.
- `pwsh ./studio/scripts/powershell/validate-mainline-notes.ps1 -BaseRef 8bf9f0e -HeadRef HEAD
  -RequireReady -ReadinessScope Batch -Json` must report `VALID=true`, 0 errors, and 0 warnings.
- The same validator with `-BaseRef origin/main -ReadinessScope Aggregate` must fail with the
  canonical Draft Wave-3 umbrella note as the only blocker.
- `git diff --check` must pass.

## Merge Notes

- This note will become Ready only after the implementation commit, old-versus-new evidence,
  independent adversarial review, full governance suite, runtime audit, and Batch reconciliation
  are complete.
- Ready status for this note will cover only the coherent RB-3 diff from `8bf9f0e`. It will not
  assert that the aggregate branch or PR #3 is ready to merge.
- RB-3 is the stopping point selected by the owner. RB-4 through R6 require a later explicit
  decision.

## Follow-ups

- Keep the Wave-3 umbrella note Draft with `TBD` evidence until fresh-fixture R6 acceptance.
- Keep `sdd-pipeline` experimental, default-disabled, and execution-denied.
- Keep R-B23 and all findings outside R-A17, R-A18, and R-A20 unchanged.
