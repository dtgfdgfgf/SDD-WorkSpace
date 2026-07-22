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
- Register R-B25, R-B26 and R-H20 as new independent `OPEN` findings.
- Directly repair 18 bounded safety and truthfulness findings, then conditionally disposition 35
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

R6-A1 preflight on 2026-07-22 then found a separate authority contradiction: the Constitution
classifies `.claude/agents/*.md` as seeded dependent mirrors, while the generator, all generated
mirrors, current adapter/guides and runtime contract call the same directory source/runtime
authority. R-H03 is README-specific, so the owner authorized new High OPEN R-H20 instead of
silently expanding R-H03.

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
- The known inventory becomes 131 findings with current fold 76 `COMPLETED`, 48 `OPEN`,
  6 `DECIDED`, 1 `IN_PROGRESS` and 0 `DISPOSITIONED`.
- No existing finding becomes `COMPLETED` or `DISPOSITIONED` in this plan-only change.
- R-E09 and R-J03 remain terminal blockers; PR #3 remains `NOT READY TO MERGE`.

## Impact Reconciliation

| Target | Impact | Disposition | Evidence |
|---|---|---|---|
| `docs/sdd-workspace-repair-inventory-and-update-plan-2026-07-12_zhTW.md` | `must_update` | `updated` | Version 1.29.0 bootstraps the scoped status authority without changing the 131-item fold or closing R6-A1. |
| `docs/sdd-workspace-wave-3-remediation-plan-2026-07-14_zhTW.md` | `must_update` | `updated` | Version 1.20.0 records the exact 15-source/1-dependent correction before implementation resumes. |
| `docs/README.md` | `must_update` | `updated` | Index reports 131 findings, revision 1 and the unchanged candidate fold. |
| `docs/mainline-updates/README.md` | `must_update` | `updated` | Index state matches this Draft note. |
| `studio/constitution/constitution.md` | `must_update` | `updated` | The implementation candidate defines the scoped authority, artifact policy and July 2026 phase review; no closure is claimed. |
| `studio/runtime/shared-runtime-contract.json` | `must_update` | `updated` | The implementation candidate contains direct-repair policy and revert anchors; committed evidence and exact-tree gates remain pending. |

## Validation

Plan-entry validation:

- `git diff --check`
- Mainline-note structural validation without a Ready requirement.
- Independent matrix review: every non-completed ID appears once, R-B25/R-B26/R-H20 remain OPEN,
  and the current 131-item fold is unchanged except for their registration.

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

## 2026-07-22 Scope Reconciliation

- Entry-plan commit `f669e3dcd116ed8ff612b9a8875167bd5b3a3881` remains the committed
  pre-implementation base, but its 130-item matrix is superseded by the owner-authorized R-H20
  correction.
- R-H20 is High and `OPEN`. It covers generator, all generated Claude mirrors, Copilot adapter,
  both Studio quickstarts, WORKSPACE_STRUCTURE and runtime contract. README remains under R-H03.
- The corrected matrix has 131 findings, 18 direct repairs, 35 Wave-4 dispositions and two
  terminal blockers. No implementation or closure is claimed by this reconciliation.

## 2026-07-22 Canonical Input Partition Reconciliation

- A second preflight found 16 Markdown files under `.github/agents/`: 14 `*.agent.md` canonical
  inputs, canonical `async-python-reviewer.md`, and dependent `copilot-instructions.md`.
- Owner Choice A refines R-H20 instead of adding a new finding. The generator must consume the 15
  canonical inputs, exclude the dependent adapter, and produce 15 dependent Claude mirrors.
- R-D12 remains `DECIDED`; R-E04 remains independent. Counts, statuses, consumer files and
  workflow promotion state do not change.
- This note remains `Draft`, Related Commits `TBD`, reconciliation `Open` and validation scope
  `Batch`; no implementation or closure is claimed by this plan correction.

## 2026-07-22 R6-A1 Implementation Candidate

- The implementation candidate adds the scoped R-E11 status schema, append-only validator,
  dependent index and runtime audit integration while keeping revision 1 at the unchanged 131-ID
  fold. R-E11 remains `OPEN` in that bootstrap record.
- Constitution 1.10.0 and current entry surfaces define the R-D07 path/type formatting policy,
  refresh the phase review, repair README and workspace-structure truth, and use the exact R-H20
  partition of 15 canonical inputs, one excluded dependent adapter and 15 dependent mirrors.
- The generator now fails closed on unclassified Markdown and the 15 Claude mirrors are reseeded
  with dependent-mirror headers. `sdd-pipeline` remains experimental, default-disabled and
  execution-denied; R-D12 remains unimplemented.
- This section records an implementation candidate only. The seven R6-A1 finding statuses do not
  change until a committed implementation hash, discriminating tests and exact-tree gates exist.
  The note therefore remains `Draft`, Related Commits `TBD` and reconciliation `Open`.

## 2026-07-22 R6-A2 Implementation Candidate

- The R-A21 candidate corrects the governed middle-recursive path matcher so
  `specs/<feature>/readiness/**/*.md` covers zero, one or multiple middle directories while
  rejecting near-prefix, sibling-stage and doubled-separator counterexamples. Production-function
  tests and a runtime mutation test distinguish the corrected expression from the prior one.
- The R-B18 candidate adds one repository-root feature-context resolver in `common.ps1`. Explicit
  absolute or normalized relative feature paths must resolve to a direct child of the configured
  repository `specs` directory. Branch and Git discovery are evaluated against that same resolved
  root, including off-directory invocation, and the physical `specs` authority is checked before
  any non-Git branch fallback can enumerate it. Foreign repositories, sibling `specs` directories,
  nested feature directories, traversal, near-prefix roots and `-Force` bypass attempts are
  rejected. Existing selected feature trees containing any junction or symbolic link are also
  rejected during the resolver scan before subsequent artifact-content access. This evidence
  covers static path tampering; concurrent filesystem replacement after the scan is outside the
  R-B18 closure boundary.
- Clarify, Readiness, ECI, Plan, Tasks, Analyze, Implement, prerequisite discovery,
  feature-structure validation and agent-context updates now consume the shared resolver. Explicit
  `-FeatureDir` remains authoritative over branch or `SPECIFY_FEATURE` diagnostics.
- All feature-bound canonical agents preserve the named option when a feature context already
  exists, dependent Claude mirrors are regenerated from those sources, and every post-Specify
  feature-bound `sdd-pipeline` operator handoff names `specs/{{ inputs.feature }}`. After Plan
  discovers an absolute feature directory, its setup and agent-context update commands reuse that
  value unconditionally. Contract mutations reject removal of the resolver boundary, a canonical
  agent handoff or a workflow handoff.
- The active no-regression baseline entering R6-A2 is 878 passed with 0 failed, superseding the
  earlier 747-test planning baseline. R-A21 and R-B18 remain `OPEN` until R6-A5 records the committed
  implementation hash and exact-tree gates. This note remains `Draft`, Related Commits `TBD` and
  reconciliation `Open`.
- `sdd-pipeline` remains experimental, default-disabled and execution-denied. This candidate does
  not authorize promotion, push or merge.

## Follow-ups

- Implement the four direct-repair sub-batches in the committed plan.
- Append evidence-backed status records and the exact 35 Wave-4 re-entry triggers in a separate
  accounting change.
- Stop at the R-E09/R-J03 merge-authorization checkpoint for separate owner direction.
