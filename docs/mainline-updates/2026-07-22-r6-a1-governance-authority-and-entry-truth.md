# Mainline Update Note: R6-A1 Governance Authority and Entry Truth

**Date**: 2026-07-22
**Source Branch**: `feature/wave-3-security-and-workflows`
**Target Branch**: `main`
**Status**: Ready
**Related Commits**: `105a09cd02f7d8b4765e49859390908e55bd97d1`, `3e64e4e785496d604e16975752392d7bc2b6c50e`, `bafe90467c326bf7d4b69988ebbf93c321cb4a91`, `13d6b282321cf06309b02779f93fbf3a93411649`, `ea78b64fec17ee074018b9dc17abea31404f8f16`, `483947a19cc4790785ae710bd7cf5e9ab9fff335`, `a74a08a191b8ec1bd67b2f2b9112e2810f10959c`, `4d8bbe23a2e0bca39bc1e786780866af06227d7c`, `f0f325b41563dea5cfa5d53582fbc0c316938f02`, `4ce95a4ed2ce941ae2291dd1002b6c7f99bbb59a`, `f4ca59d274fffe8f1e49950d8bf796b95eda05d6`, `be938ab07d68a229eb8b8b150e65f6971768ae8c`
**Related PR**: https://github.com/dtgfdgfgf/SDD-WorkSpace/pull/3
**Reconciliation Status**: Closed
**Validation Scope**: Batch

## Revalidation (2026-07-22, Non-Self-Referential Revision 6 Accounting)

Honesty demotion `4ce95a4ed2ce941ae2291dd1002b6c7f99bbb59a` preserved the Batch failure as
revision 5 and returned only R-E11 to `IN_PROGRESS`. Plan
`f4ca59d274fffe8f1e49950d8bf796b95eda05d6` then committed a non-self-referential re-entry
sequence without weakening the validator or exempting `docs/README.md` from branch evidence
coverage.

On the clean demotion-and-plan tree, the complete governance suite reports 878 passed and 0 failed,
runtime reports `VALID=true` with 0 errors and 0 warnings, and BaseRef history reports exactly five
consecutive valid revisions, 131 findings, fold 82/42/5/2/0 and `HISTORY_VALID=true`. Revision 6
therefore restores only R-E11 to `COMPLETED`, producing fold 83/42/5/1/0. The other six A1 findings
remain `COMPLETED`, and every other finding status remains unchanged.

Accounting commit `be938ab07d68a229eb8b8b150e65f6971768ae8c` changed exactly the four
authorized accounting paths, preserved revisions 1 through 5 as an immutable prefix and passed
its staged-snapshot audit, committed history validation, structural mainline validation and
runtime audit. This separate finalization changes exactly this note and its matching index row,
adds the real accounting, plan and demotion hashes together, and records the bounded Ready/Closed
transition. Every exact-tree gate below governs whether that state may remain; any deviation
requires immediate append-only demotion.

## Revalidation (2026-07-22, Evidence-Coverage Failure)

Explicit Batch readiness from `9b83f7a5d2e8630955efdb458f0e0e9a1c367839` through finalization head
`f0f325b41563dea5cfa5d53582fbc0c316938f02` failed with exactly one
`branch-evidence-coverage-missing` error for `docs/README.md`. The same commit changed that path to
Ready/Closed prose, so its last-touch was `f0f325b`; the Ready note inside that commit could not
cite the commit hash before it existed. Aggregate returned only the expected umbrella blocker and
the four-revision ledger remained valid, but those partial passes cannot override mandatory Batch.

The concurrently started runtime and complete governance suite were stopped after this
deterministic failure and provide no finalization-tree result. Revision 5 therefore returns only
R-E11 to `IN_PROGRESS`; the other six A1 findings remain `COMPLETED`, and this note returns to Draft
with reconciliation Open. Re-entry requires a new committed sequence that avoids self-referential
last-touch evidence and then passes every exact-tree gate.

## Revalidation (2026-07-22, Finalization-Tree Failure)

The complete governance suite at committed finalization head
`8f0dd46b3002626892d02bdf1808e68f21828005` refuted this note's Ready/Closed status. Its
`promotes finding-status index tampering into a runtime audit failure` case expected a nonzero
runtime result but received zero because the fixture still replaced revision-1 counts `76/48`;
the revision-2 index contains `83/42`, so no mutation occurred. Inspection also found that
`docs/README.md` still described this note as Draft/Open after finalization made it Ready/Closed.

This failure reopened only R-E11 as `IN_PROGRESS`. The evidence for R-D07, R-E02, R-E08, R-H03,
R-H04 and R-H20 remained valid, so those six stayed `COMPLETED`.

Repair commit `ea78b64fec17ee074018b9dc17abea31404f8f16` now derives the current index marker,
asserts that each mutation changes the fixture, and makes the isolated ledger fixture
revision-aware. On the clean repair-and-plan tree at
`483947a19cc4790785ae710bd7cf5e9ab9fff335`, the complete governance suite reports 878 passed and
0 failed, runtime reports `VALID=true` with 0 errors and 0 warnings, and the three-revision ledger
history remains valid at 131 findings and fold 82/42/5/2/0. Revision 4 therefore restores only
R-E11 to `COMPLETED`. Accounting commit `a74a08a191b8ec1bd67b2f2b9112e2810f10959c`
preserved exactly four consecutive revisions and passed its staged-snapshot audit. Documentation
finalization `f0f325b41563dea5cfa5d53582fbc0c316938f02`, authorized by surface-set correction
`4d8bbe23a2e0bca39bc1e786780866af06227d7c`, then synchronized the three note-state surfaces but
failed the Batch evidence-coverage gate described above. R6-A2 through R6-A6 remain pending and the
branch remains `NOT READY TO MERGE`.

## Summary

- Establish a machine-bounded, append-only finding-status authority without making the full repair
  ledger authoritative.
- Preserve completed implementation for R-D07, R-E02, R-E08, R-H03, R-H04 and R-H20 while
  revision 6 restores only R-E11 after the non-self-referential pre-accounting gates pass.
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
`3e64e4e785496d604e16975752392d7bc2b6c50e` authorizes the original A1-only accounting checkpoint.
After the first failed finalization, amendment `483947a19cc4790785ae710bd7cf5e9ab9fff335`
preserved the honesty-demotion record and authorized the revision-4 re-entry sequence. Surface-set
correction `4d8bbe23a2e0bca39bc1e786780866af06227d7c` addressed dependent prose, but finalization
`f0f325b41563dea5cfa5d53582fbc0c316938f02` exposed a separate last-touch evidence-sequencing
failure. Demotion `4ce95a4ed2ce941ae2291dd1002b6c7f99bbb59a` and plan
`f4ca59d274fffe8f1e49950d8bf796b95eda05d6` preserve that failure and authorize only the bounded
revision-6 accounting and later two-file finalization sequence. The later R6-A5 boundary for
Wave-4 dispositions and cross-batch convergence is unchanged.

## Scope

In scope:

- R-E11 scoped finding-status schema, validator, runtime integration and append-only revisions 1
  through 6, including both honesty demotions, the refuted revision-4 re-entry and the bounded
  revision-6 re-accounting.
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
| `studio/tests/check-speckit-runtime.Tests.ps1` | Derive the current finding-status index marker and require a real tampering mutation |
| `studio/tests/mainline-note-validation.Tests.ps1` | Derive the current marker for runtime-propagation tampering evidence |
| `studio/tests/validate-finding-status-ledger.Tests.ps1` | Keep the isolated unit fixture explicitly revision-aware |
| `docs/sdd-workspace-repair-inventory-and-update-plan-2026-07-12_zhTW.md` | Preserve revisions 1 through 5 and append revision 6 for only R-E11 completion |
| `docs/README.md` | Match revision 6 and fold 83/42/5/1/0 with state-neutral readiness prose |

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
| `docs/README.md` | `must_update` | `updated` | Revision 6 matches 131 findings and fold 83/42/5/1/0; readiness prose defers to this note and its index row. |

## Validation

Observed evidence is separated by tree:

- The original implementation and revision-2 accounting tree reported 878 passed, 0 failed,
  runtime and Batch `VALID=true` with 0 errors and 0 warnings, and two valid finding-status
  revisions at fold 83/42/5/1/0.
- Finalization head `8f0dd46b3002626892d02bdf1808e68f21828005` refuted the Ready claim because the
  finding-status tampering fixture performed no mutation. Demotion commit
  `13d6b282321cf06309b02779f93fbf3a93411649` preserved that evidence as revision 3 and returned
  only R-E11 to `IN_PROGRESS`.
- Repair commit `ea78b64fec17ee074018b9dc17abea31404f8f16` passes 69 ledger tests, 102
  mainline-note tests and three focused runtime/mainline integration cases with 0 failures.
- On clean repair-and-plan head `483947a19cc4790785ae710bd7cf5e9ab9fff335`, the complete
  governance suite reports 878 passed, 0 failed, 0 skipped, 0 inconclusive and 0 not run; runtime
  reports `VALID=true`, 0 errors and 0 warnings; and BaseRef history validation reports exactly
  three valid records, revision 3, 131 findings, fold 82/42/5/2/0 and `HISTORY_VALID=true`.
- Accounting commit `a74a08a191b8ec1bd67b2f2b9112e2810f10959c` passes its staged-snapshot
  audit and committed BaseRef history validation with exactly four consecutive valid revisions,
  revision 4, 131 findings, fold 83/42/5/1/0 and `HISTORY_VALID=true`.
- Under surface-set correction `4d8bbe23a2e0bca39bc1e786780866af06227d7c`, finalization
  `f0f325b41563dea5cfa5d53582fbc0c316938f02` changed exactly the three authorized note-state
  surfaces and preserved the revision-4 machine marker, but explicit Batch readiness failed with
  one `branch-evidence-coverage-missing` error for `docs/README.md`.
- The concurrently started runtime and complete governance suite were intentionally stopped after
  the Batch failure and are not finalization-tree evidence. Revision 5 records the required
  demotion to fold 82/42/5/2/0.
- Demotion `4ce95a4ed2ce941ae2291dd1002b6c7f99bbb59a` and committed plan
  `f4ca59d274fffe8f1e49950d8bf796b95eda05d6` produce a clean pre-accounting tree where the
  complete governance suite reports 878 passed, 0 failed, 0 skipped, 0 inconclusive and 0 not run;
  runtime reports `VALID=true`, 0 errors and 0 warnings; and history reports exactly five valid
  revisions, 131 findings, fold 82/42/5/2/0 and `HISTORY_VALID=true`.
- Accounting commit `be938ab07d68a229eb8b8b150e65f6971768ae8c` appends only revision 6,
  restores only R-E11 to `COMPLETED`, updates the index marker to fold 83/42/5/1/0, and keeps this
  note Draft/Open/Batch in that accounting tree. This later two-file finalization captures its
  real hash together with the plan and demotion hashes without self-reference.

This committed Ready tree is subject to this immediate fail-and-demote contract:

- The complete governance suite must report at least 878 passed and 0 failed.
- Runtime must report `VALID=true`, 0 errors and 0 warnings.
- Finding-status history must contain exactly six consecutive valid revisions, preserve revisions
  1 through 5 as an immutable prefix, report 131 findings and match fold 83/42/5/1/0 in the index.
- Explicit Batch readiness from `9b83f7a5d2e8630955efdb458f0e0e9a1c367839` must report
  `VALID=true`, 0 errors and 0 warnings.
- Explicit Aggregate readiness must fail only with the canonical `aggregate-note-not-ready`
  blocker for `docs/mainline-updates/2026-05-05-studio-workflows-runtime.md`.
- `git diff --check` and clean-worktree verification must pass.
- Any deviation requires this note to be demoted to Draft immediately under the Reopened rule.

## Merge Notes

- This dedicated Batch note is `Ready` with reconciliation `Closed` only for bounded R6-A1; the
  exact-tree gates determine whether that state may remain.
- Even after bounded A1 readiness, the branch remains `NOT READY TO MERGE` because R6-A2 through
  R6-A6, Aggregate acceptance, merge and post-merge evidence remain incomplete.
- This batch does not authorize workflow promotion, push, merge or PR-thread resolution.

## Follow-ups

- Run every exact-tree gate on this committed two-file finalization. Any failure requires immediate
  Draft/Open demotion and a new append-only revision before other work continues.
- Continue R6-A2 only after R6-A1 is truthfully revalidated, without absorbing any A3 through A6
  finding or Wave-4 disposition.
