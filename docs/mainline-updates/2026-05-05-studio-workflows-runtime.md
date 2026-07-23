# Mainline Update Note: Wave-3 Selective Alignment — Security Hardening + studio/workflows/ Runtime

**Date**: 2026-05-05
**Source Branch**: `feature/wave-3-security-and-workflows`
**Target Branch**: `main`
**Status**: Draft
**Related Commits**: Wave-3 implementation `b01c36692cbaceec0ac9556b06c444fa4b069fb1`; R0 `bdd27809d82a9f99fc66db0a0db3fe325d53c226`; R1 `e543f6a9818007bac67f1ec942cacc22e577d17a`; RB-1 terminal schema `961df61ceb42dff8f6e9b9e5dc4253e9a6bfb374`; RB-1 template boundary `cb43de50385838888eedd94b48e6c4446e255e5a`; R2 workflow validation `6a53f6601510b58e0907ce14f3a015f6b03aea43`; RB-2 `ec25c073dbf7b04b7670e0923c08a79b792e3da8`; RB-3 `4f757e551ee196bc90e51ef21674c4983eae35ec`; RB-4 `9819e301318230ca0413d44a5bdf3d2a3b3e3ca6`; RB-5 implementation `78c47eb0f3da7e75f3ba79943ea44f55984677a1`; RB-5 evidence `26da9a7412d902f2dfff48df23d04662687f4a9d`; RB-5 closure `44f768a12316cdb008f1fee263e03ed7ce9a8191`; R6 fixture `f2df26e98300c034f7fa03c7831b8f00aa6c470a`; R-D03 `6b749a1f153dc88412714db0ed6d8708170c5936`; R-F04 `e24d958421b4dc90ed04d507f008d7ec2bc3bec3`; R6-A1 `105a09cd02f7d8b4765e49859390908e55bd97d1`; R6-A1 finalization `b3e7c15c2e70aebf3bd40b5a73f24285de507476`; R6-A2 `814cc6169e6d1bf9167ce91249dbd58ac548674d`; R6-A3 `be5fb24fd79a47d8f0db9f61be2a747d06b29088`; R6-A4 `32a58e653cc4b541db88b23ad4b90fd7b81007a5`; R6-A5 trigger contract `5e99ad9569cc0212212a0191193702c25f6af052`; R6-A5 accounting `05fe6f16ec334263bc1432e18ecb4a648a6dc38b`; R6-A2 through A5 finalization `501f4d7e02d17dcf7a9663a5ad60ff5d0d880cdf`; R6-A6 plan `5e9f470857f4958ff3b6198ca5887de3fa2f5d13`; R6-A6 accounting `7910e0e54796fdb79abbc700993bf95327fa2390`; failed Aggregate finalization `0470fc528a93e51160b03c0f19a340ac89582db9`; honesty demotion `c16f2fa02b362569de21e51692a6b9e8d0592f05`; complete-coverage plan `aa6a08e2d75b9eb16a862e9978217d042bdac8c7`; complete-coverage accounting `2d963a72fcd49ced2a7ae8498e3faa3366858946`; complete-coverage finalization `0ee547da6ecc85c848fa9f647dcc548ff66dcd33`; suite-timeout demotion `d8dbdf275858d445087a39b35839566bf87697c7`; bounded-suite plan `77a9db0be48ae4a36188722a5d6a46434685d88a`
**Related PR**: https://github.com/dtgfdgfgf/SDD-WorkSpace/pull/3
**Reconciliation Status**: Open
**Validation Scope**: Aggregate

## R6-A6 Pester Report-Export Honesty Demotion

Bounded-suite finalization `cc957a0` runs the unchanged official governance entrypoint with a
4500-second limit and process-scoped inherited `PSExecutionPolicyPreference=Bypass`. Pester
discovers exactly 986 tests in 27 files and completes in 2945.4 seconds with 986 passed, 0 failed,
0 skipped, 0 inconclusive and 0 not run. Persistent execution-policy values match exactly before
and after the run.

After the complete green test summary, Pester's NUnit report End step calls `Get-CimInstance` and
the managed sandbox denies access. Report export fails, the official command exits `-1`, and no new
complete XML artifact is produced. The result proves every test outcome but does not prove that the
official entrypoint completed successfully with its required report.

This Aggregate note and matching index row therefore return immediately to Draft/Open. The
report-export failure does not refute a test, machine gate, finding status or the Ready R6 Batch
umbrella. Re-entry requires a committed validation-environment plan and a read-only elevated
preflight proving CIM access, followed by the unchanged official suite outside the restricted
sandbox. R-E09 remains `IN_PROGRESS`, R-J03 remains `OPEN`, and no push, merge, workflow
promotion, PR-thread resolution or post-merge action is authorized.

## R6-A6 Bounded Full-Suite Re-entry

Suite-only plan `77a9db0be48ae4a36188722a5d6a46434685d88a` authorizes this
documentation-only finalization after honesty demotion
`d8dbdf275858d445087a39b35839566bf87697c7`. It changes no runtime, test, finding record,
workflow authorization or acceptance count.

This note and matching index row return to Ready/Closed subject to the exact-tree gates in plan
version 1.30.0. The official suite must discover exactly 986 tests and complete within the bounded
4500-second validation window with 986 passed, 0 failed, 0 skipped, 0 inconclusive and 0 not run.
Runtime, ledger history, Batch and Aggregate must remain valid with 0 errors and 0 warnings after
the suite. Any deviation immediately restores Draft/Open.

Ready/Closed remains a merge-review checkpoint only. R-E09 stays `IN_PROGRESS`, R-J03 stays
`OPEN`, and this state grants no push, merge, workflow promotion, PR-thread resolution or
post-merge authority.

## R6-A6 Full-Suite Timeout Honesty Demotion

Complete-coverage finalization `0ee547da6ecc85c848fa9f647dcc548ff66dcd33` passed canonical
runtime, nine-record finding history, Batch readiness and Aggregate readiness from `main`, all with
0 errors and 0 warnings. The official governance suite discovered exactly 986 tests in 27 files
and began running with inherited process-scoped `PSExecutionPolicyPreference=Bypass`.

The validation command reached its 2400-second tool timeout before Pester emitted a final summary.
The partial output showed completed green files, including `check-speckit-runtime.Tests.ps1`,
`mainline-note-validation.Tests.ps1` and `r6-fresh-fixture-e2e.Tests.ps1`, but it did not prove
986 passed, 0 failed, 0 skipped, 0 inconclusive and 0 not run. A timeout without a complete result
cannot satisfy the mandatory full-suite gate.

This Aggregate note and matching index row therefore return immediately to Draft/Open. The timeout
does not refute the Ready/Closed R6 Batch umbrella, a machine gate, finding status or completed test
file. Re-entry requires a committed suite-only validation plan with a sufficient bounded timeout,
followed by the same exact-tree runtime, ledger, Batch, Aggregate, hygiene and persistent-policy
checks. R-E09 remains `IN_PROGRESS`, R-J03 remains `OPEN`, and no push, merge, workflow promotion,
PR-thread resolution or post-merge action is authorized.

## R6-A6 Aggregate Honesty Demotion and Re-entry

Finalization `0470fc528a93e51160b03c0f19a340ac89582db9` passed the staged runtime
audit. Its exact committed tree also passed canonical runtime with 0 errors and 0 warnings,
finding-status history with nine valid records and fold 95/1/0/1/35, and Batch readiness from
`main` with 0 errors and 0 warnings.

Aggregate readiness from `main` failed with 80 `branch-evidence-coverage-missing` errors. Aggregate
scope accepts commit coverage from the configured Aggregate note itself; the current Related
Commits field cites material batch milestones but does not cite every changed path's exact
last-touch commit. The result refutes this note's Ready/Closed claim without refuting the R6 Batch
umbrella, a finding status, runtime behavior or test result.

This note therefore returns immediately to Draft/Open. It may re-enter Ready/Closed only after a
committed re-entry plan enumerates the exact missing last-touch commit set, a separate
documentation candidate supplies those complete references, and a later finalization passes
runtime, ledger history, Batch, Aggregate, full-suite and hygiene gates on one exact committed
tree. R-E09 remains `IN_PROGRESS`, R-J03 remains `OPEN`, and no push, merge, promotion or
post-merge action is authorized.

### Exact Missing Last-Touch Set

Complete-coverage re-entry plan `aa6a08e2d75b9eb16a862e9978217d042bdac8c7`
authorizes the exact twelve-commit repair below. An isolated diagnostic clone reproduced all
80 errors at `0470fc528a93e51160b03c0f19a340ac89582db9` with no other error category.

| Missing commit | Path count | Evidence boundary |
|---|---:|---|
| `05fe6f16ec334263bc1432e18ecb4a648a6dc38b` | 1 | R6-A5 finding-status accounting |
| `105a09cd02f7d8b4765e49859390908e55bd97d1` | 16 | R6-A1 authority, adapters, current guides and shared registry truth |
| `26da9a7412d902f2dfff48df23d04662687f4a9d` | 1 | RB-5 sealed historical evidence |
| `32a58e653cc4b541db88b23ad4b90fd7b81007a5` | 1 | R6-A4 current documentation audit surface |
| `5e99ad9569cc0212212a0191193702c25f6af052` | 3 | R6-A5 trigger-bearing disposition contract |
| `6a53f6601510b58e0907ce14f3a015f6b03aea43` | 1 | R2 workflow validation implementation |
| `78c47eb0f3da7e75f3ba79943ea44f55984677a1` | 6 | RB-5 agent, authority and template implementation |
| `814cc6169e6d1bf9167ce91249dbd58ac548674d` | 32 | R6-A2 feature binding across agents, setup scripts and workflow |
| `961df61ceb42dff8f6e9b9e5dc4253e9a6bfb374` | 1 | RB-1 terminal analysis-result schema |
| `bdd27809d82a9f99fc66db0a0db3fe325d53c226` | 2 | R0 containment, license and provenance cleanup |
| `be5fb24fd79a47d8f0db9f61be2a747d06b29088` | 15 | R6-A3 extension and workflow lifecycle truthfulness |
| `cb43de50385838888eedd94b48e6c4446e255e5a` | 1 | RB-1 critical gate template boundary |

The counts total exactly 80. This Draft candidate adds all twelve hashes to Related Commits while
preserving every previously valid reference. It changes no runtime, test, ledger or Batch evidence.
A later finalization must additionally cite this candidate's real hash before restoring
Ready/Closed.

### Complete-Coverage Candidate Validation

Accounting candidate `2d963a72fcd49ced2a7ae8498e3faa3366858946` provides the real hash
required by plan `aa6a08e2d75b9eb16a862e9978217d042bdac8c7`. Its exact committed tree
reports:

| Validation surface | Result |
|---|---|
| Canonical runtime | `VALID=true`, 0 errors, 0 warnings |
| Finding-status history | 9 valid records, 132 findings, fold 95/1/0/1/35 |
| Batch readiness from `main` | `VALID=true`, 0 errors, 0 warnings |
| Aggregate readiness from `main` while Draft | Exactly one `aggregate-note-not-ready`; 0 coverage errors |
| Historical evidence | 18 of 18 valid |

This finalization therefore restores this Aggregate note and matching index row to Ready/Closed.
The transition supersedes the Draft/Open current-state sentence above but preserves its failure
evidence. R-E09 remains `IN_PROGRESS`, R-J03 remains `OPEN`, and Ready/Closed grants no push,
merge, workflow promotion, PR-thread resolution or post-merge authority.

## R6-A6 Aggregate Reconciliation

R6-A6 entry plan `5e9f470857f4958ff3b6198ca5887de3fa2f5d13` authorizes this
documentation-only reconciliation. Accounting candidate
`7910e0e54796fdb79abbc700993bf95327fa2390` supplies the non-self-referential current-state
bytes. This section is the current Wave-3 disposition and supersedes every older pending-state
statement below without erasing the historical chronology.

The branch has completed its bounded security, governance, agent, extension, workflow,
documentation and evidence repairs through:

- RB-1 through RB-5 implementation and accounting.
- R6 fresh-fixture E2E and its Ready/Closed Batch note.
- R6-A1 finalization `b3e7c15c2e70aebf3bd40b5a73f24285de507476`.
- R6-A2 through A5 finalization `501f4d7e02d17dcf7a9663a5ad60ff5d0d880cdf`.
- Finding-status revision 9 with 132 findings, severity 8/32/53/39 and fold 95/1/0/1/35.

The owner-selected Wave-3 result is permanent non-promotion within this branch.
`sdd-pipeline` remains experimental, default-disabled and execution-denied. Any future promotion
requires a separately governed re-entry after the applicable disposition trigger is met. This
decision closes the pre-merge promotion-decision obligation without claiming that the experimental
runtime is a supported delivery surface.

Read-only preflight at `501f4d7e02d17dcf7a9663a5ad60ff5d0d880cdf` produced:

| Validation surface | Result |
|---|---|
| Canonical runtime | `VALID=true`, 0 errors, 0 warnings |
| Finding-status ledger | 9 records, 132 findings, fold 95/1/0/1/35 |
| Batch readiness from `b3e7c15c2e70aebf3bd40b5a73f24285de507476` | `VALID=true`, 0 errors, 0 warnings |
| Aggregate readiness from `main` | Exactly one `aggregate-note-not-ready` error for this Draft note |
| Worktree | Clean |

This note is Ready/Closed because the accounting candidate now has a real hash and the material
batch evidence is cited. Ready/Closed means the branch is coherent for owner merge review; it does
not authorize push or merge. R-E09 remains `IN_PROGRESS` for actual merge accounting and
post-merge verification, and R-J03 remains `OPEN` because `main` has not been updated.

## R6 Fresh-Fixture Evidence Reconciliation (2026-07-21)

Owner authorized this accounting-only reconciliation after a read-only preflight found that the
current-status text below still described the fresh-fixture evidence as pending. This section
supersedes only those stale pending statements in the 2026-07-20 chronology; it does not erase or
rewrite the historical record.

Implementation commit `aef41b1bac2e56bf717d9ded5328c3c601fd7037` completed the bounded R6
fresh-fixture evidence sub-batch. Accounting commit
`28fbc8280000124e15c9c4913f6c130af1df78bb` recorded its Batch disposition, and final tested
head `f2df26e98300c034f7fa03c7831b8f00aa6c470a` produced these results:

| Validation surface | Observed final-head result |
|---|---|
| Full governance suite | 744 passed, 0 failed, 0 skipped, 0 not run in 1251.1 seconds |
| Canonical runtime audit | `VALID=true`, 0 errors, 0 warnings |
| Historical sealed evidence | 18 of 18 records valid |
| R6 evidence Batch gate | BaseRef `f8e3fe0bd9d62b7f8e0110bc2a13e73548311c3f`; `VALID=true`, 0 errors, 0 warnings across 8 changed paths |
| Aggregate gate | Expected exit 1 with exactly one `aggregate-note-not-ready` for this umbrella note |
| Diff and worktree hygiene | `git diff --check` passed and the worktree was clean |

The bounded evidence note is
[`2026-07-21-r6-fresh-fixture-evidence.md`](./2026-07-21-r6-fresh-fixture-evidence.md).
Its `Ready`, `Closed`, and `Batch` status does not replace Aggregate acceptance.

This umbrella note therefore remains `Draft` with `Related Commits: TBD`, reconciliation `Open`,
and validation scope `Aggregate`. R6 overall and R-E09 remain `IN_PROGRESS`; R-E11 and residual
dispositions remain unresolved under the ledger. Workflow promotion is undecided, and
`sdd-pipeline` remains experimental, default-disabled, and execution-denied. This reconciliation
does not authorize promotion, push, merge, or post-merge accounting. PR #3 remains
`NOT READY TO MERGE`.

## Revalidation (2026-07-20)

RB-1 through RB-5 now provide coherent Batch repairs for the defects discovered after this note
was drafted. RB-5 implementation commit
`78c47eb0f3da7e75f3ba79943ea44f55984677a1` completes R-D01, R-D04, R-D05, R-E07, and
R-A22; migration commit `26da9a7412d902f2dfff48df23d04662687f4a9d` seals all 18
historical-note records. The historical portion of R-E09 is complete, but R-E09 remains
`IN_PROGRESS` because this Aggregate note and final merge accounting belong to R6.

The body below is the contemporaneous 2026-05-05 proposal, not current acceptance evidence.
Constitution 1.9.0 and the later repair notes supersede its original version, outcome-count,
validation-count, merge-splitting, and promotion assumptions. `sdd-pipeline` remains experimental,
default-disabled, and execution-denied.

This note stays `Draft` with `Related Commits: TBD`, reconciliation `Open`, and validation scope
`Aggregate`. R6 must still run the fresh-fixture seven-stage flow, exercise ECI re-entry and
non-ready routes, satisfy the minimum merge gates, decide promotion, finalize Aggregate evidence,
and perform authorized merge and post-merge verification. PR #3 remains `NOT READY TO MERGE`.

### Post-Accounting Revalidation (2026-07-20)

This subsection supersedes the preceding statement that RB-1 through RB-5 provide coherent Batch
repairs. At accounting head `64669c43d531d9dd699d60e163e7b1c755d64963`, the full
governance suite remains 737 passed, 0 failed, and 0 skipped, but the canonical runtime audit is
`VALID=false` with one `historical-evidence-sealed-snapshot-mismatch`. Batch reports 22 errors and
Aggregate reports 19 errors. `Read-ExactLegacyBaselineAtCommit` currently rejects the production
legacy baseline metadata shape, leaving `HISTORICAL_EVIDENCE_VALID=0`.

R-D01, R-D04, R-D05, and R-E07 remain `COMPLETED`. R-A22 is `IN_PROGRESS`, R-E09 remains
`IN_PROGRESS`, and RB-5 is not Ready. The R-A22 repair and repaired RB-5 final gates must complete
before R6 can begin. This Aggregate note remains `Draft`, `TBD`, `Open`, and `Aggregate`;
`sdd-pipeline` remains experimental, default-disabled, and execution-denied.

### Repair Closure Superseding Post-Accounting Revalidation

Repair commit `3666c4e9a6553ff82774d4a06037f48846d8b0fd` supersedes the R-A22 and
RB-5 disposition in the immediately preceding subsection. Its committed runtime audit reports
`VALID=true`, 0 errors, 0 warnings, and 18 of 18 historical sealed records valid. The dedicated
mainline-note validator file passes 91 of 91 tests. The exact production baseline is accepted,
while `TwoField`, `ExtraField`, `SubstitutedField`, `WrongType`, and `Null` are denied; the
contract anchor also rejects a revert to the former `Count=2` shortcut.

At the repair-head point, RB-5 was completed and R-A22 returned to `COMPLETED`. The 18-note
historical portion of R-E09 was complete, but R-E09 remained `IN_PROGRESS` for this umbrella note,
R6 evidence, final merge accounting, and post-merge verification. A diagnostic Batch run after the
repair had 18 of 18 historical records valid and no sealed mismatch; its 33 errors derived only
from the RB-5 note still being Draft and its coverage, not-ready, and reconciliation-missing
consequences. At that point, final full-suite, Batch, and Aggregate results were still pending
until the accounting edits were complete.

This umbrella note remained `Draft`, `TBD`, `Open`, and `Aggregate`. R6 would be the next
remediation batch after the accounting final gates were rerun. `sdd-pipeline` remained
experimental, default-disabled, and execution-denied.

### Final Accounting Validation Superseding the Pending-Gate Statements

Final validation at committed head `44f768a12316cdb008f1fee263e03ed7ce9a8191`
produced the following observed results:

| Validation surface | Observed result |
|---|---|
| Full governance suite | 742 passed, 0 failed, 0 skipped in 1115.2 seconds |
| Canonical runtime audit | `VALID=true`, 0 errors, 0 warnings |
| Historical sealed evidence | 18 of 18 records valid |
| RB-5 Batch gate | BaseRef `de61431ae8f50d66f59157e00e4d239e9b37efdb`; `VALID=true`, 0 errors, 0 warnings |
| Aggregate gate | Expected nonzero result with exactly one `aggregate-note-not-ready` for this umbrella note |
| Diff and worktree hygiene | `git diff --check` passed and the worktree was clean |

The Aggregate result preserves the current merge disposition: this note remains `Draft` with
`Related Commits: TBD`, reconciliation `Open`, and validation scope `Aggregate`. R-E09 remains
`IN_PROGRESS`; R6 is the next remediation batch and must provide the fresh-fixture, promotion
decision, final merge-accounting, and post-merge evidence. `sdd-pipeline` remains experimental,
default-disabled, and execution-denied. These results do not authorize workflow promotion or
merge.

## Summary

- **Stream A (security hardening)** mirrors upstream `github/spec-kit` v0.3.0 PR #1809 (shell-injection robustness) and v0.7.5 PR #2229/#2296 (directory-traversal in agent command write paths). Eight existing PowerShell scripts now invoke the already-shipped `Assert-PathInsideRoot` / `Test-PathInsideRoot` helpers from `common.ps1`. New regression suite `studio/tests/path-traversal-hardening.Tests.ps1` covers every call site. Eight new `scriptInvariants` lock the contract; `script_change` impact route gains a `must_review` advisory pointing at the new tests.
- **Stream B (studio/workflows/ runtime)** mirrors upstream v0.7.0 PR #2158 (workflow engine + catalog system) but lands as a PowerShell implementation aligned with the studio-first model. New three-layer registry (`POLICY.md`, `manifest.schema.json`, `catalog.schema.json`, `state.schema.json`, `catalog.json`, `state.json`), plus a Wave-3 step-type set (`command` with script/agent dispatch, `gate`, `if`, `switch`), a sandboxed expression subset, RunState with atomic write + 60-second advisory lock, and the first built-in workflow `sdd-pipeline` encoding all eight readiness primary statuses and three ECI authorization outcomes.
- Constitution stays at **v1.8.0**. The workflow runtime is additive infrastructure — premature codification would lock implementation choices that should be refined first via real-world use. The runtime contract gains `workflowInvariants` instead.

## Why This Update Exists

The workspace was aligned to upstream `spec-kit` v0.2.0 (2026-03-09). Upstream advanced 30 releases to v0.8.5 (2026-05-04). Wave-3 selectively absorbs three discrete capabilities that fit the studio-first model:

1. Path-boundary defense was effectively shipped in `common.ps1` but only used by extension-registry scripts. The seven-stage entry-gate scripts and `create-new-feature.ps1` constructed paths from `SPECIFY_FEATURE` env var or `-FeatureDir` parameter without `Assert-PathInsideRoot`. Tampering with either could escape `REPO_ROOT`.
2. The seven-stage SDD flow was enforced by three loose layers (agent prompts, `setup-*.ps1` entry gates, contract invariants) with no single declarative orchestration surface. `dispatch: agent` halt-and-resume gives operators a re-entrant flow with explicit `expected_artifact` checks; `gate` halt-and-resume gives them a re-entrant approval surface.
3. Readiness's eight primary statuses and ECI's three authorization outcomes were governance-only concepts. The `switch` step type lets operators see them as concrete branches in one yaml file.

Workspaces with consumer projects living anywhere on disk needed a path-boundary model that did not assume "everything is inside the workspace tree". The boundary now derives from the SDD `<project>/specs/<feature>` structure when `-FeatureDir` is supplied, and from `Get-RepoRoot` (which honors `SDD_PROJECT_ROOT`) when reading the env-var path.

## Scope

In scope:

- Stream A: 8 call sites in `studio/scripts/powershell/{create-new-feature, update-agent-context, setup-{plan,readiness,tasks,analyze,implement}, sync-agent-bootstrap}.ps1`. New regression test file. New scriptInvariants. New impact-registry advisory.
- Stream B: `studio/workflows/` registry (POLICY, three schemas, catalog/state, runs/), `sdd-pipeline/` (manifest, workflow.yml, docs), four new shared scripts (`workflow-engine.ps1`, `run-workflow.ps1`, `validate-workflow.ps1`, `list-workflows.ps1`, `set-workflow-state.ps1`), four new test files (workflow-schema, workflow-engine, workflow-expression, workflow-runstate, sdd-pipeline). New `workflowInvariants`, three new `scriptInvariants`, new `sharedGatePaths` entries, new `workflow_change` impact route, new `STUDIO_WORKFLOW_*` audit fields.
- Documentation: this note; `studio/QUICKSTART.md` Optional: Workflow Runtime section; `studio/SDD-QUICKSTART-GUIDE.md` Wave-3 cross-reference; `WORKSPACE_STRUCTURE.md` row for `studio/workflows/`.

Explicitly out of scope (deferred):

- Step types `prompt`, `shell`, `while`, `do-while`, `fan-out`, `fan-in`. Engine raises `step-type-not-implemented`; schema also rejects them.
- Multi-layer catalog (env / project / user / built-in). Wave-3 ships only a single built-in workflows directory.
- Auto-install of `powershell-yaml`. Detection only; install hint surfaced via `check-speckit-runtime.ps1` warning.
- Full Jinja2 expression engine. Wave-3 ships interpolation + `==` / `!=` + `and` / `or` / `not` (+ parens) + `default` filter. Function calls and reflection are explicitly rejected.
- Constitution version bump.
- Replacement of existing `setup-*.ps1` entry gates. They become `dispatch: script` targets in the workflow.

## Affected Paths

| Path | Change |
|------|--------|
| `studio/scripts/powershell/create-new-feature.ps1` | Three new `Assert-PathInsideRoot` calls (specsDir / featureDir / specFile) |
| `studio/scripts/powershell/update-agent-context.ps1` | New boundary check on `envData.FEATURE_DIR` and `IMPL_PLAN` |
| `studio/scripts/powershell/setup-{plan,readiness,tasks,analyze,implement}.ps1` | New `$projectRootForBoundary` derivation + `Assert-PathInsideRoot` on each path field |
| `studio/scripts/powershell/sync-agent-bootstrap.ps1` | Paranoid `Assert-PathInsideRoot` on every adapter target inside `$context.ProjectRoot` |
| `studio/scripts/powershell/workflow-engine.ps1` | New: parser + expression evaluator + state machine + step dispatchers |
| `studio/scripts/powershell/run-workflow.ps1` | New: CLI entry (`-Id`/`-Feature`/`-Resume`/`-ConfirmGate`/`-RejectGate`/`-DryRun`/`-Json`) |
| `studio/scripts/powershell/validate-workflow.ps1` | New: yaml + schema validator |
| `studio/scripts/powershell/list-workflows.ps1` | New: catalog + state listing |
| `studio/scripts/powershell/set-workflow-state.ps1` | New: state ledger update |
| `studio/scripts/powershell/check-speckit-runtime.ps1` | New STUDIO_WORKFLOW_* fields and `workflowInvariants` audit hook |
| `studio/scripts/powershell/generate-impact-registry.ps1` | New `workflow_change` route + amended `script_change` rule |
| `studio/runtime/shared-runtime-contract.json` | 8 path-boundary scriptInvariants + 3 workflow scriptInvariants + 2 workflowInvariants + 6 sharedGatePaths |
| `studio/runtime/impact-registry.json` | Regenerated to include `workflow_change` route and `script_change` test advisory |
| `studio/workflows/POLICY.md`, `manifest.schema.json`, `catalog.schema.json`, `state.schema.json`, `catalog.json`, `state.json`, `runs/.gitkeep` | New |
| `studio/workflows/sdd-pipeline/manifest.json`, `workflow.yml`, `docs/README.md` | New |
| `studio/tests/path-traversal-hardening.Tests.ps1`, `workflow-schema.Tests.ps1`, `workflow-engine.Tests.ps1`, `workflow-expression.Tests.ps1`, `workflow-runstate.Tests.ps1`, `sdd-pipeline.Tests.ps1` | New |
| `WORKSPACE_STRUCTURE.md` | New row for `studio/workflows/` in Studio Canonical Sources |
| `studio/QUICKSTART.md` | New Optional: Workflow Runtime section |
| `studio/SDD-QUICKSTART-GUIDE.md` | Cross-reference paragraph after Implement stage |

## Impact

- Operators of the studio scripts gain defense-in-depth path boundaries. Nothing in normal use is affected; tampered `SPECIFY_FEATURE` env vars or malicious `-FeatureDir` arguments now exit non-zero with a precise "escapes project root" message.
- Operators who want declarative orchestration over the seven-stage flow can now run `pwsh ./studio/scripts/powershell/run-workflow.ps1 -Id sdd-pipeline -Feature <id>`. The runtime is opt-in; the canonical seven-stage flow continues to work through `setup-*.ps1` and slash commands.
- Agents and slash commands are unchanged.
- Constitution and project memories are unchanged.
- Generated documents that reference the contract or `check-speckit-runtime.ps1` -Json output now see `STUDIO_WORKFLOW_*` keys; ignore-them defaults are safe.
- `powershell-yaml` becomes an optional dependency. Without it, `validate-workflow.ps1` and `run-workflow.ps1` fail with an actionable install hint; everything else works.

## Impact Reconciliation

The current `main`-to-head branch diff requires the following eight `must_update` targets. Every
target is present in the branch diff and already has a dedicated Ready/Closed Batch proof.

| Target | Impact | Disposition | Evidence |
|---|---|---|---|
| `README.md` | `must_update` | `updated` | R6-A1 implementation `105a09cd02f7d8b4765e49859390908e55bd97d1` aligns current governance and authority truth; the R6-A1 Batch note is Ready/Closed at `b3e7c15c2e70aebf3bd40b5a73f24285de507476`. |
| `studio/QUICKSTART.md` | `must_update` | `updated` | R6-A1 implementation `105a09cd02f7d8b4765e49859390908e55bd97d1` updates the governed quickstart; the R6-A1 Batch note provides exact-tree proof. |
| `studio/SDD-QUICKSTART-GUIDE.md` | `must_update` | `updated` | R6-A1 implementation `105a09cd02f7d8b4765e49859390908e55bd97d1` updates the governed methodology guide; the R6-A1 Batch note provides exact-tree proof. |
| `.claude/agents/*.md` | `must_update` | `updated` | R6-A2 implementation `814cc6169e6d1bf9167ce91249dbd58ac548674d` reseeds the dependent mirrors; A2-A5 finalization `501f4d7e02d17dcf7a9663a5ad60ff5d0d880cdf` passes the reconciled Batch gate. |
| `AGENTS.md` | `must_update` | `updated` | R6-A1 implementation `105a09cd02f7d8b4765e49859390908e55bd97d1` synchronizes the generated bootstrap; adapter validation is included in the Ready/Closed R6-A1 evidence. |
| `CLAUDE.md` | `must_update` | `updated` | R6-A1 implementation `105a09cd02f7d8b4765e49859390908e55bd97d1` synchronizes the generated bootstrap; adapter validation is included in the Ready/Closed R6-A1 evidence. |
| `.github/copilot-instructions.md` | `must_update` | `updated` | R6-A1 implementation `105a09cd02f7d8b4765e49859390908e55bd97d1` synchronizes the generated bootstrap; adapter validation is included in the Ready/Closed R6-A1 evidence. |
| `docs/README.md` | `must_update` | `updated` | R6-A5 accounting `05fe6f16ec334263bc1432e18ecb4a648a6dc38b` records revision 9 and fold 95/1/0/1/35; A2-A5 finalization `501f4d7e02d17dcf7a9663a5ad60ff5d0d880cdf` validates the exact branch evidence. |

## Validation

```powershell
git diff --check
pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json
pwsh ./studio/scripts/powershell/run-governance-tests.ps1
pwsh ./studio/scripts/powershell/validate-workflow.ps1 -Id sdd-pipeline -Json
pwsh ./studio/scripts/powershell/list-workflows.ps1 -Json
```

Expected:

- `check-speckit-runtime.ps1`: `VALID=true`, `ERROR_COUNT=0`, `STUDIO_WORKFLOW_REGISTRY_VALID=true`, `STUDIO_WORKFLOW_COUNT>=1`, `STUDIO_WORKFLOW_YAML_AVAILABLE=true`, `REGISTRY_FRESHNESS.fresh=true`, every new path-boundary `scriptInvariants` entry shows `missingRequirements=[]`, both new `workflowInvariants` entries show `missingRequirements=[]`.
- `run-governance-tests.ps1`: full Pester suite green (244 passing in clean baseline; 1 skipped is the powershell-yaml-detection branch and is correct when the module is installed).
- `validate-workflow.ps1`: `VALID=true`, `SCHEMA_VALID=true`.
- `list-workflows.ps1`: registers `sdd-pipeline`, `valid=true`.

CI prerequisite: `Install-Module -Name powershell-yaml -Scope CurrentUser` (one-time per machine; not auto-installed).

## Merge Notes

The historical two-pass proposal is superseded. The current branch is one reconciled Wave-3
candidate. It may reach the owner merge-authorization checkpoint only after a separate
Ready/Closed finalization and exact-tree full-suite, runtime, ledger, Batch, Aggregate and hygiene
gates all pass.

No push, merge, force-push, workflow promotion, PR-thread resolution or post-merge accounting is
authorized by this note. R-E09 and R-J03 remain non-terminal until the owner authorizes a real
merge and the post-merge gates produce evidence.

## Follow-ups

- Wave-4 candidates: Preset composition strategies (upstream v0.8.0), curated catalog policy / extension lifecycle (upstream v0.7.0+), workflow step types `while` / `do-while` / `fan-out` / `fan-in` if real-world use surfaces a need.
- Promotion of the workflow runtime into a constitution section once a real consumer project has used it end-to-end.
- Optional: add a `workflowInvariants` enforcement layer to pre-commit hook (currently audited only by `check-speckit-runtime.ps1`).
- Optional: replace operator-in-the-loop agent dispatch with a Copilot CLI / Claude Code CLI direct dispatch when those CLIs expose a non-interactive surface.
