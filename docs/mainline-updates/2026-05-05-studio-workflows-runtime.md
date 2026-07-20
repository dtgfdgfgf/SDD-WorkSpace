# Mainline Update Note: Wave-3 Selective Alignment — Security Hardening + studio/workflows/ Runtime

**Date**: 2026-05-05
**Source Branch**: `feature/wave-3-security-and-workflows`
**Target Branch**: `main`
**Status**: Draft
**Related Commits**: TBD
**Related PR**: N/A
**Reconciliation Status**: Open
**Validation Scope**: Aggregate

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
