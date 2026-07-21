# Mainline Update Note: R6-A1 Governance Authority and Entry Truth

**Date**: 2026-07-22
**Source Branch**: `feature/wave-3-security-and-workflows`
**Target Branch**: `main`
**Status**: Draft
**Related Commits**: `TBD`
**Related PR**: https://github.com/dtgfdgfgf/SDD-WorkSpace/pull/3
**Reconciliation Status**: Open
**Validation Scope**: Batch

## Summary

- Establish a machine-bounded, append-only finding-status authority without making the full repair
  ledger authoritative.
- Complete R-D07, R-E02, R-E08, R-E11, R-H03, R-H04 and R-H20 from implementation
  `105a09cd02f7d8b4765e49859390908e55bd97d1`.
- Keep consumer repositories, workflow promotion, Aggregate acceptance and the remaining R6
  batches outside this checkpoint.

## Why This Update Exists

R6-A1 repairs seven connected truth surfaces. The ledger previously had no machine-scoped status
authority; formatting scope depended on artifact type; current adapters and guides exposed stale
phase or workflow guidance; README and workspace structure described outdated entry surfaces; and
the Claude generator path incorrectly blurred fifteen canonical GitHub inputs, one dependent
Copilot adapter and fifteen dependent Claude mirrors.

The implementation adds exact schema, fold, visibility, index and BaseRef-history validation for
finding statuses; path-scoped Markdown formatting; current phase and entry-point truth; and an exact
source-to-mirror partition. Plan correction
`3e64e4e785496d604e16975752392d7bc2b6c50e` authorizes this A1-only accounting checkpoint while
retaining the later R6-A5 accounting boundary for Wave-4 dispositions and cross-batch convergence.

## Scope

In scope:

- R-E11 scoped finding-status schema, validator, runtime integration and append-only revision 2.
- R-D07 artifact path/type formatting enforcement with bounded semantic exceptions.
- R-E02 and R-E08 adapter phase and current-phase truth.
- R-H03 and R-H04 README and workspace-structure truth.
- R-H20 exact canonical-agent and dependent-mirror authority partition.

Out of scope:

- R6-A2 through R6-A6, all Wave-4 dispositions, R-E09 and R-J03.
- `projects/`, `learning/`, workflow promotion, push, merge and PR-thread resolution.

## Affected Paths

| Path | Change |
|------|--------|
| `studio/constitution/constitution.md` | Define scoped finding-status authority, exact agent partition and artifact formatting policy |
| `studio/runtime/shared-runtime-contract.json` | Bind strict policies, source/mirror sets and revert-sensitive invariants |
| `studio/runtime/finding-status-record.schema.json` | Define the closed status-record schema |
| `studio/scripts/powershell/validate-finding-status-ledger.ps1` | Validate visible canonical records, fold/index parity and append-only history |
| `studio/scripts/powershell/check-speckit-runtime.ps1` | Fail closed on ledger, formatting and agent-partition drift |
| `studio/scripts/powershell/validate-mainline-notes.ps1` | Require strict child-ledger results and history evidence |
| `studio/scripts/powershell/seed-claude-agents.ps1` | Generate only from the exact fifteen canonical inputs and skip the dependent adapter |
| `.claude/agents/*.md` | Retain deterministic dependent-mirror headers for all fifteen outputs |
| `README.md`, `WORKSPACE_STRUCTURE.md` | Reconcile current workflow and workspace entry truth |
| `AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md` | Synchronize the Constitution 1.10.0 bootstrap and current adapter truth |
| `studio/QUICKSTART.md`, `studio/SDD-QUICKSTART-GUIDE.md` | Reconcile current phase and Claude mirror semantics |
| `docs/sdd-workspace-repair-inventory-and-update-plan-2026-07-12_zhTW.md` | Append revision 2 for only the seven evidence-backed completions |
| `docs/README.md` | Match the revision-2 fold in the dependent index |

## Impact

- Finding status becomes machine-readable and append-only without promoting ledger narrative.
- Current adapters and documentation agree on phase, entry points and source/mirror direction.
- R6 remains incomplete and `sdd-pipeline` remains experimental, default-disabled and denied.

## Impact Reconciliation

| Target | Impact | Disposition | Evidence |
|--------|--------|-------------|----------|
| `README.md` | `must_update` | `updated` | Implementation `105a09c` reconciles current workflow denial and entry surfaces. |
| `studio/QUICKSTART.md` | `must_update` | `updated` | Implementation `105a09c` reconciles current phase and dependent Claude mirror semantics. |
| `studio/SDD-QUICKSTART-GUIDE.md` | `must_update` | `updated` | Implementation `105a09c` reconciles methodology and mirror semantics. |
| `AGENTS.md` | `must_update` | `updated` | Implementation `105a09c` synchronizes the generated Constitution 1.10.0 bootstrap. |
| `CLAUDE.md` | `must_update` | `updated` | Implementation `105a09c` synchronizes the generated Constitution 1.10.0 bootstrap. |
| `.github/copilot-instructions.md` | `must_update` | `updated` | Implementation `105a09c` synchronizes bootstrap, phase and dependent-adapter truth. |
| `docs/README.md` | `must_update` | `updated` | Revision 2 index matches 131 findings and the 83/42/5/1/0 fold. |

## Validation

Observed implementation evidence:

- The complete governance suite reports 878 passed, 0 failed, 0 skipped and 0 not run.
- The staged-snapshot pre-commit gate passes shared runtime, adapter and impact-route checks.
- Committed runtime and mainline validation report `VALID=true`, 0 errors and 0 warnings.
- Committed revision-1 history validation reports one record, 131 findings and `HISTORY_VALID=true`.
- Claude verification reports 15 generated mirrors, 1 skipped dependent adapter and 0 errors.
- Impact-registry comparison reports fresh generated output.

Pending before this note may become Ready:

- Record the accounting commit hash and replace `Related Commits: TBD`.
- Validate revision 2 as an exact append-only prefix with 131 findings and fold 83/42/5/1/0.
- Run the complete governance suite and runtime audit on the final note tree.
- Run explicit Batch readiness from `9b83f7a5d2e8630955efdb458f0e0e9a1c367839` and require
  `VALID=true`, 0 errors and 0 warnings.
- Run explicit Aggregate readiness and require exactly the canonical Draft-umbrella blocker.
- Pass `git diff --check` and clean-worktree verification.

## Merge Notes

- This note remains `Draft` with reconciliation `Open` until the pending accounting identity and
  exact-tree gates exist.
- Even after bounded A1 readiness, the branch remains `NOT READY TO MERGE` because R6-A2 through
  R6-A6, Aggregate acceptance, merge and post-merge evidence remain incomplete.
- This batch does not authorize workflow promotion, push, merge or PR-thread resolution.

## Follow-ups

- Finalize this note only after the accounting commit is immutable and the exact-tree gates pass.
- Continue R6-A2 without absorbing any A3 through A6 finding or Wave-4 disposition.
