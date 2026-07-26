# Mainline Update Note: RB-3 Mainline Evidence Integrity

**Date**: 2026-07-20
**Source Branch**: `feature/wave-3-security-and-workflows`
**Target Branch**: `main`
**Status**: Ready
**Related Commits**: `4f757e5`
**Related PR**: https://github.com/dtgfdgfgf/SDD-WorkSpace/pull/3
**Reconciliation Status**: Closed
**Validation Scope**: Batch

## Summary

- Replace incomplete per-file shared-layer gates with category-complete rules for PowerShell scripts,
  Git hooks, and Studio extensions.
- Preserve both source and destination paths from Git rename records so governed content
  cannot leave the gate through a rename.
- Replace shape-only blocking `-RequireReady` acceptance with Git commit, branch membership,
  contract-bound repository, truthful Markdown-surface, and governed non-note shared-path coverage
  validation.
- Separate coherent Batch closure from Aggregate merge readiness. The Wave-3 umbrella note remains
  Draft and continues to block Aggregate readiness until R6.

## Why This Update Exists

RVR-05 and ledger R-A17 showed that the production `sharedGatePaths` list covered only part of the
shared PowerShell surface, omitted most hooks and every extension path, and used a branch diff that
lost the governed source path during rename detection. The tests used a broader fixture than the
production contract and therefore hid the gap.

RVR-06 and ledger R-A18 showed that blocking Ready acceptance accepted any hash-shaped string and
any pull-request-shaped string without proving the commit object, branch membership, canonical
repository, required note sections, or governed shared-path coverage. A smaller Ready note could
also make the aggregate branch appear ready while the Wave-3 umbrella note remained Draft with
`TBD` evidence.

RB-3 preflight found a separate acceptance-rule contradiction: a correct Aggregate gate must remain
red until R6, while the previous per-batch rule required that same aggregate command to be green.
Owner Choice A on 2026-07-20 resolves this as R-A20 by making Batch and Aggregate explicit,
fail-closed scopes.

## Scope

- R-A17 and RVR-05: category-complete shared roots, recursive matching, rename old and new paths,
  production-contract fixtures, and revert-sensitive runtime audit checks.
- R-A18 and RVR-06: commit-object and branch-range validation, contract-bound PR URLs, visible
  metadata and `Scope`, `Impact`, and `Validation` sections outside comments, code, and raw HTML,
  last-touch coverage for governed non-note shared paths, and machine-bound Aggregate note
  enforcement.
- R-A20: explicit Batch and Aggregate scopes. RB-3 uses immutable Batch base `8bf9f0e`; hosted
  pull-request and main-push gates use Aggregate.
- No changes under `projects/` or `learning/`. RB-4 through R6, workflow promotion, main merge,
  force-push, history rewriting, and PR-thread resolution remain out of scope.

## Affected Paths

| Path | Change |
|------|--------|
| `studio/runtime/shared-runtime-contract.json` | Define category-complete gates, repository identity, canonical Aggregate note path, CI scope, and revert-sensitive invariants. |
| `.githooks/pre-commit.ps1` | Match recursive category rules and make rename detection explicit while preserving old and new paths. |
| `studio/scripts/powershell/validate-mainline-notes.ps1` | Validate Git name-status records, blocking Ready evidence, truthful Markdown surface, governed non-note shared-path coverage, and Batch or Aggregate scope. |
| `studio/scripts/powershell/check-speckit-runtime.ps1` | Fail when required shared categories or the canonical Aggregate readiness policy is missing or redirected. |
| `.github/workflows/governance.yml` | Declare Aggregate scope explicitly for hosted pull-request and main-push enforcement. |
| `studio/templates/sdd-docs/mainline-update-note-template.md` | Show the explicit Batch validation command for coherent update-note accounting. |
| `studio/tests/mainline-note-validation.Tests.ps1` | Use production rules and real Git fixtures for BaseRef, commit, PR, hidden surface, coverage, aggregate-anchor, omitted-script, and rename counterexamples. |
| `studio/tests/pre-commit.Tests.ps1`, `check-speckit-runtime.Tests.ps1` | Cover recursive production categories, near-prefix exclusions, rename-out, and contract-policy mutation. |
| `docs/sdd-workspace-repair-inventory-and-update-plan-2026-07-12_zhTW.md` | Close R-A17/R-A18/R-A20, register open R-A21, and update the ledger to v1.11.0 with 127 findings. |
| `docs/sdd-workspace-wave-3-remediation-plan-2026-07-14_zhTW.md` | Record owner Choice A, Batch/Aggregate acceptance semantics, RB-3 evidence, and the RB-4 stopping boundary in v1.3.0. |
| This note and `docs/mainline-updates/README.md` | Publish the Ready Batch claim while preserving Aggregate NOT READY status. |

## Impact

- Any descendant of `studio/scripts/powershell/`, `.githooks/`, or `studio/extensions/` now enters the
  shared-layer note gate without per-file maintenance.
- Moving governed content outside a protected category still exposes the old path to the validator.
- Blocking `-RequireReady` acceptance can no longer rely on absent BaseRef context, nonexistent,
  wrong-type, or out-of-range commit objects, mutable-origin, cross-repository, or unqualified PR
  references, metadata or sections hidden in comments, fences, indented code, or raw HTML, or
  unrelated commits.
- Global validation without `-RequireReady` intentionally retains a shape-only no-Git fallback for
  isolated structural audit fixtures. That fallback cannot authorize Batch or Aggregate readiness.
- A Batch note may close one coherent incremental repair. It does not make the full Wave-3 branch
  ready.
- Aggregate validation remains intentionally blocked by
  `docs/mainline-updates/2026-05-05-studio-workflows-runtime.md` until that note is truthfully Ready
  after R6 evidence.

## Impact Reconciliation

| Target | Impact | Disposition | Evidence |
|--------|--------|-------------|----------|
| `studio/runtime/shared-runtime-contract.json` | `must_review` | `updated` | Commit `4f757e5` adds category-complete roots, canonical repository and Aggregate-note policy, and revert-sensitive semantic anchors; contract mutation tests pass. |
| `.githooks/pre-commit.ps1` | `must_review` | `updated` | Recursive production rules, near-prefix exclusion, and rename old-path preservation are covered by focused tests; the staged-snapshot hook accepted commit `4f757e5`. |
| `studio/scripts/powershell/check-speckit-runtime.ps1` | `must_review` | `updated` | Required shared categories and the canonical Aggregate policy fail closed under mutation; runtime audit reports `VALID=true`, 0 errors, and 0 warnings. |
| `studio/scripts/powershell/validate-mainline-notes.ps1` | `must_review` | `updated` | Current Git-backed and truthful-surface negatives pass; 34 discriminating negatives all fail against `8bf9f0e`; Aggregate reports only the canonical Draft-note blocker. |
| `.github/workflows/governance.yml` | `maybe_review` | `updated` | Pull-request and main-push calls explicitly retain `-ReadinessScope Aggregate`. |
| `studio/templates/sdd-docs/mainline-update-note-template.md` | `maybe_review` | `updated` | The template uses explicit `-ReadinessScope Batch` with a concrete batch base. |
| `docs/sdd-workspace-repair-inventory-and-update-plan-2026-07-12_zhTW.md` | `must_review` | `updated` | Ledger v1.11.0 records implementation commit `4f757e5`, closes R-A17/R-A18/R-A20, and preserves R-A21 as OPEN; total is 127. |
| `docs/sdd-workspace-wave-3-remediation-plan-2026-07-14_zhTW.md` | `must_review` | `updated` | Remediation plan v1.3.0 records Choice A, exact Batch and Aggregate commands, evidence totals, and the stop before RB-4. |
| `studio/constitution/constitution.md` | `maybe_review` | `reviewed-no-change` | RB-3 implements the existing Mainline Update Notes and Surface Truthfulness rules without changing constitutional policy. |
| `studio/QUICKSTART.md` | `maybe_review` | `reviewed-no-change` | Workflow invocation and promotion status do not change; maintainer acceptance semantics are recorded in governance plans and this note. |
| `studio/tests/path-traversal-hardening.Tests.ps1` | `must_review` | `reviewed-no-change` | RB-3 does not change path-containment primitives; the suite remains part of the full governance gate. |

## Validation

- Focused production-contract and real-Git suites: 134 passed, 0 failed.
- Detached `8bf9f0e` overlay: 34 discriminating negatives passed 0 of 34 against the old
  implementation, while 5 positive and regression controls passed 5 of 5. The current
  implementation passes all corresponding assertions.
- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json`: `VALID=true`, 0 errors, and
  0 warnings.
- `pwsh ./studio/scripts/powershell/run-governance-tests.ps1`: 616 passed, 0 failed.
- `pwsh ./studio/scripts/powershell/validate-mainline-notes.ps1 -BaseRef 8bf9f0e -HeadRef HEAD
  -RequireReady -ReadinessScope Batch -Json`: `VALID=true`, 0 errors, and 0 warnings.
- The same validator with `-BaseRef origin/main -ReadinessScope Aggregate`: expected nonzero with
  exactly one `aggregate-note-not-ready` error for the canonical Draft Wave-3 umbrella note.
- `git diff --check`: passed.

## Merge Notes

- This note is Ready for the RB-3 Batch after implementation commit `4f757e5`, old-versus-new
  evidence, independent adversarial review, 616-test full-suite verification, runtime audit, and
  Batch reconciliation completed.
- Ready status for this note will cover only the coherent RB-3 diff from `8bf9f0e`. It will not
  assert that the aggregate branch or PR #3 is ready to merge.
- RB-3 is the stopping point selected by the owner. RB-4 through R6 require a later explicit
  decision.

## Follow-ups

- Keep the Wave-3 umbrella note Draft with `TBD` evidence until fresh-fixture R6 acceptance.
- Keep `sdd-pipeline` experimental, default-disabled, and execution-denied.
- Keep R-B23 and all pre-existing findings outside R-A17, R-A18, and R-A20 unchanged.
- Keep R-A21 open: the mainline matcher still mishandles zero directory levels in a middle
  `/**/` segment. Exact and suffix rules currently cover the affected production routes, but the
  generic matcher must be repaired and tested separately.
