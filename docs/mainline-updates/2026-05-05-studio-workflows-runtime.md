# Mainline Update Note: Wave-3 Selective Alignment — Security Hardening + studio/workflows/ Runtime

**Date**: 2026-05-05
**Source Branch**: `feature/wave-3-security-and-workflows`
**Target Branch**: `main`
**Status**: Draft
**Related Commits**: TBD
**Related PR**: N/A
**Reconciliation Status**: Open
**Validation Scope**: Aggregate

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

Reconciliation remains open. This historical Aggregate note does not close any current
`must_update` route and does not authorize workflow promotion or merge. R6 must reconcile the
current aggregate branch diff and replace `TBD` only with verified final evidence.

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

This batch is mergeable in two passes if Stream B engine review takes longer than Stream A: Stream A (call-site hardening + tests + contract) is independently mergeable. Stream B (studio/workflows/ + engine + sdd-pipeline) builds on Stream A's `Assert-PathInsideRoot` discipline but does not depend on it for compilation.

If splitting is preferred:

1. Merge Stream A first, validating with `path-traversal-hardening.Tests.ps1` and `check-speckit-runtime.ps1 -Json`.
2. Merge Stream B once engine review completes, validating with the workflow test suite plus an end-to-end `run-workflow.ps1 -DryRun` against a fixture feature.

## Follow-ups

- Wave-4 candidates: Preset composition strategies (upstream v0.8.0), curated catalog policy / extension lifecycle (upstream v0.7.0+), workflow step types `while` / `do-while` / `fan-out` / `fan-in` if real-world use surfaces a need.
- Promotion of the workflow runtime into a constitution section once a real consumer project has used it end-to-end.
- Optional: add a `workflowInvariants` enforcement layer to pre-commit hook (currently audited only by `check-speckit-runtime.ps1`).
- Optional: replace operator-in-the-loop agent dispatch with a Copilot CLI / Claude Code CLI direct dispatch when those CLIs expose a non-interactive surface.
