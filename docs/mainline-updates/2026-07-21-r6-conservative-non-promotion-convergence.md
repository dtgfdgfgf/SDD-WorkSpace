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
- Register R-B25, R-B26, R-H20 and R-E13 as new independent `OPEN` findings.
- Directly repair 19 bounded safety and truthfulness findings, then conditionally disposition 35
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

R6-A5 preflight on 2026-07-23 found that the canonical status-entry schema cannot carry the exact
re-entry trigger required for a `DISPOSITIONED` finding. The owner authorized Medium OPEN R-E13
instead of silently expanding completed R-E11. Revisions 1 through 6 contain no disposition and
remain valid; implementation and accounting remain separate.

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
- The known inventory is 132 findings with current fold 83 `COMPLETED`, 43 `OPEN`,
  5 `DECIDED`, 1 `IN_PROGRESS` and 0 `DISPOSITIONED` after revision 7 registers R-E13.
- No A2 through A4 finding becomes `COMPLETED` and no Wave-4 finding becomes `DISPOSITIONED`
  in the R-E13 registration.
- R-E09 and R-J03 remain terminal blockers; PR #3 remains `NOT READY TO MERGE`.

## Impact Reconciliation

| Target | Impact | Disposition | Evidence |
|---|---|---|---|
| `docs/sdd-workspace-repair-inventory-and-update-plan-2026-07-12_zhTW.md` | `must_update` | `updated` | Version 1.35.0 revision 7 registers only Medium R-E13 as OPEN and preserves revisions 1 through 6. |
| `docs/sdd-workspace-wave-3-remediation-plan-2026-07-14_zhTW.md` | `must_update` | `updated` | Version 1.25.0 records the trigger-authority repair and accounting sequence before implementation. |
| `docs/README.md` | `must_update` | `updated` | Index reports revision 7, 132 findings and current fold 83/43/5/1/0. |
| `docs/mainline-updates/README.md` | `must_update` | `updated` | Index state matches this Draft note. |
| `studio/constitution/constitution.md` | `must_update` | `updated` | The implementation candidate defines the scoped authority, artifact policy and July 2026 phase review; no closure is claimed. |
| `studio/runtime/shared-runtime-contract.json` | `must_update` | `updated` | The implementation candidate contains direct-repair policy and revert anchors; committed evidence and exact-tree gates remain pending. |

## Validation

Plan-entry validation:

- `git diff --check`
- Mainline-note structural validation without a Ready requirement.
- Independent matrix review: every non-completed ID appears once, R-E13 is registered as OPEN,
  and revisions 1 through 6 remain an immutable prefix.

Required before this note may become `Ready`:

- Focused old-fails/new-passes tests and a revert-sensitive invariant for every completed finding.
- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json`, expecting `VALID=true`,
  0 errors and 0 warnings.
- `pwsh ./studio/scripts/powershell/run-governance-tests.ps1`, expecting at least the existing
  958 passed baseline and 0 failed.
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

## 2026-07-22 R6-A3 Lifecycle Truthfulness Implementation Candidate

- The R-C04 candidate retires both unenforced extension compatibility version fields from the
  manifest schema and canonical smoke manifest. The compatibility surface now declares only the
  enforced `studio-first` mode, and an intake mutation that restores either retired field is
  rejected.
- The R-C06 candidate removes the producerless `sync` source from extension catalog policy,
  catalog and state schemas, and shared parsing. A deprecated extension can no longer be newly
  enabled. Only an existing state entry with Boolean `enabled=true` and an exact current-version
  pin can repeat the enable request as a byte-preserving no-op; absent, disabled, null, wrong-type,
  stale-pin and `sync` variants fail closed.
- The independent R-B25 candidate retires the workflow analogue from the canonical
  `sdd-pipeline` manifest and makes shared listing and execution authorization reject field
  reintroduction. This is field retirement only and does not promote the workflow.
- The independent R-B26 candidate applies the same deprecated same-pin no-op boundary to workflow
  state mutation and shared authorization, and removes `sync` from workflow catalog policy and
  schemas. Listing and execution continue to consume the same fail-closed registry result.
- Discriminating lifecycle tests exercise the retired fields, case-variant and unknown workflow
  compatibility keys, every deprecated-state variant, and source null, wrong-type and `sync`
  cases. Runtime contract mutations separately anchor all four finding boundaries against
  reversion.
- R-C04, R-C06, R-B25 and R-B26 remain `OPEN` until R6-A5 appends their committed implementation
  hash and exact-tree evidence. This note remains `Draft`, Related Commits `TBD` and reconciliation
  `Open`.
- `sdd-pipeline` remains experimental, default-disabled and execution-denied. No consumer tree,
  promotion, push or merge is authorized by this candidate.

## 2026-07-22 R6-A4 Documentation and Configuration Truthfulness Implementation Candidate

- The R-G01 candidate refreshes the central governance ledger to 2026-07-22, adds Trading-002 and
  Trading-003 as `Mixed`, and records the post-2026-03-18 seven-stage, ECI re-entry and Implement
  gate effects. All nine local-notice paths exist, but the two new Trading notices still say
  `Legacy`; this shared-only batch does not call them synchronized and does not edit consumers.
- The R-G03 candidate quarantines the 2026-05-08 obstacle review without rewriting its historical
  body. A bounded 2026-07-22 revalidation separates the installed CLI Version 0.0.22 command
  surface from official Spec Kit v0.13.3: the local executable still exposes `--ai` and lacks
  extension, preset and workflow groups, while official v0.13.3 uses `--integration` and documents
  all three groups. R-G02 and the Wave-4 upstream alignment findings remain independent and open.
- The R-G04 candidate marks the v0.8.5 strategy and compatibility matrix historical-unverified,
  replaces flow and directory diagrams with lists or tables, and brings the exact strategy path
  into the strict Constitution Section 10.1 runtime selector. Restoring the stale `tested` row,
  Unicode arrows or an ASCII flow now fails the contract.
- The R-H06 candidate relocates the six-stage 2026-03-08 assessment under `docs/0308upstreams/`,
  adds a visible historical warning and repairs three references across two documents. The plan's
  phrase “three documents” was a count drift; the owner authorized the repository-observed scope
  of two files and three occurrences. The historical body remains byte-content equivalent after
  line-ending and trailing-newline normalization.
- The R-H09 candidate removes the terminal auto-approval block, obsolete duotify ignore and global
  Markdown lint ignore while retaining the Markdownlint formatter. Four additional Git and
  Explorer risk preferences discovered during preflight remain untouched because they are outside
  R-H09's authorized scope.
- Five dedicated rollback tests and per-finding contract anchors distinguish the repaired surfaces
  from the prior date, rows, guidance, matrix, location, references and settings. R-G01, R-G03,
  R-G04, R-H06 and R-H09 remain `OPEN` until R6-A5 appends their committed implementation hash and
  exact-tree evidence.
- This note remains `Draft`, Related Commits `TBD` and reconciliation `Open`. `sdd-pipeline`
  remains experimental, default-disabled and execution-denied; no promotion, consumer edit, push
  or merge is authorized by this candidate.

## Follow-ups

- Implement R-E13 without changing the revision-7 fold.
- Append evidence-backed A2 through A4 and R-E13 completions, then the exact 35 Wave-4 re-entry
  triggers, in a separate accounting change.
- Stop at the R-E09/R-J03 merge-authorization checkpoint for separate owner direction.

## 2026-07-23 R6-A5 Trigger-Authority Registration

- Remediation plan `a45b7d33a59dd41d7765d29626bf43d2adb02cca` records owner Choice A and
  classifies the trigger representation gap as independent Medium R-E13.
- Ledger revision 7 registers only R-E13 as `OPEN`, producing 132 findings, severity 8/32/53/39
  and fold 83/43/5/1/0. The eleven A2 through A4 candidates remain `OPEN`.
- A dedicated A2-A5 Batch note now owns bounded finalization. This broad note remains Draft/Open/TBD
  because R6-A6, R-E09, R-J03, merge authorization and post-merge evidence remain pending.
- `sdd-pipeline` remains experimental, default-disabled and execution-denied. No disposition,
  promotion, consumer edit, push, merge or PR-thread resolution is authorized by registration.
