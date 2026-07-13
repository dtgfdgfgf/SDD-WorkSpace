# Mainline Update Note: R2 R-B06 Dispatch Consistency

**Date**: 2026-07-13
**Source Branch**: `feature/wave-3-security-and-workflows`
**Target Branch**: `main`
**Status**: Draft
**Related Commits**: `TBD`
**Related PR**: https://github.com/dtgfdgfgf/SDD-WorkSpace/pull/3
**Reconciliation Status**: Open

## Summary

- Run workflow script steps with the configured project root as the child process working directory.
- Bind plan preparation and the `/speckit.plan` handoff to the workflow's explicit feature instead of deriving their target from the current branch.
- Add path-boundary, cross-feature, workflow-shape, and caller-working-directory regression coverage.

## Why This Update Exists

PR #3 review exposed two independently reproducible parts of R-B06. First, relative arguments sent
to a script-dispatch step were resolved from the caller's working directory even though the engine
had already resolved a different `ProjectRoot`. Second, `stage-plan-prep` invoked `setup-plan.ps1`
without the workflow feature, allowing branch-derived context to select a different feature.

Together these paths could read or create planning artifacts outside the feature selected by the
workflow operator. The runtime contract now locks the dispatch and agent-handoff invariants.

## Scope

- Correct the two R-B06 review findings in PR #3.
- Preserve the actual branch value in setup-plan JSON while using explicit `SPECS_DIR`,
  `FEATURE_SPEC`, and `IMPL_PLAN` paths for the requested feature.
- Require explicit plan targets to be direct children of the configured project's `specs/` folder.
- Pass the same named feature option through the operator handoff and plan agent path discovery.
- Keep R-B06 `IN_PROGRESS`: RunState relocation and canonical feature-ID allocation remain open.
- Keep R-B16 unchanged until the final RunState location exists.

## Affected Paths

| Path | Change |
|------|--------|
| `studio/scripts/powershell/workflow-engine.ps1` | Start script-dispatch child PowerShell in `ProjectRoot`. |
| `studio/scripts/powershell/setup-plan.ps1` | Add bounded `-FeatureDir` context and explicit-feature precedence. |
| `studio/scripts/powershell/check-prerequisites.ps1` | Resolve plan-agent path discovery from the same explicit feature context. |
| `studio/workflows/sdd-pipeline/workflow.yml` | Pass `specs/{{ inputs.feature }}` to plan preparation and the operator handoff. |
| `.github/agents/speckit.plan.agent.md` and `.claude/agents/speckit-plan.md` | Preserve the workflow feature through the manual plan-agent handoff. |
| `studio/runtime/shared-runtime-contract.json` | Lock child cwd, explicit plan context, and pipeline argument invariants. |
| `studio/tests/workflow-engine.Tests.ps1` | Exercise a relative script argument from an unrelated caller cwd. |
| `studio/tests/setup-plan.Tests.ps1` | Exercise cross-feature selection and an outside-project rejection. |
| `studio/tests/path-traversal-hardening.Tests.ps1` | Cover setup-plan's explicit feature boundary. |
| `studio/tests/sdd-pipeline.Tests.ps1` | Parse YAML and assert the exact plan-preparation arguments. |

## Impact

- Relative script arguments now have one deterministic base: the configured project root.
- A workflow can prepare `specs/<workflow-feature>/plan.md` even when the current branch or
  `SPECIFY_FEATURE` names another feature.
- Lexically outside-project and nested non-feature plan targets are rejected. R-C05 remains open
  for junction/reparse-aware canonicalization across the shared runtime.
- No workflow schema shape, constitution rule, public quickstart, or workspace layout changes.

## Impact Reconciliation

| Target | Impact | Disposition | Evidence |
|--------|--------|-------------|----------|
| `studio/runtime/shared-runtime-contract.json` | `must_review` | `updated` | Added three explicit R-B06 runtime/workflow invariants. |
| `.claude/agents/*.md` | `must_update` | `updated` | Re-seeded the plan agent mirror after adding explicit feature handoff semantics. |
| `studio/tests/path-traversal-hardening.Tests.ps1` | `must_review` | `updated` | Added an outside-configured-project `-FeatureDir` rejection test. |
| `.githooks/pre-commit.ps1` | `must_review` | `reviewed-no-change` | Existing hook consumes the contract through the unchanged audit entry point. |
| `studio/scripts/powershell/check-speckit-runtime.ps1` | `must_review` | `reviewed-no-change` | Existing invariant evaluation handles the added contract records without a code change. |
| `studio/constitution/constitution.md` | `maybe_review` | `reviewed-no-change` | Dispatch correctness implements existing ordered-stage and boundary rules; it adds no governance policy. |
| `studio/scripts/powershell/workflow-engine.ps1` | `must_review` | `updated` | Engine now supplies `-WorkingDirectory $ProjectRoot` for script dispatch. |
| `studio/scripts/powershell/validate-workflow.ps1` | `must_review` | `reviewed-no-change` | The existing command `args` schema already accepts the added arguments. |
| `studio/tests/sdd-pipeline.Tests.ps1` | `must_review` | `updated` | Structured YAML assertion locks the exact setup-plan arguments. |
| `studio/tests/workflow-schema.Tests.ps1` | `must_review` | `reviewed-no-change` | No schema field or type changed; existing schema validation remains applicable. |
| `WORKSPACE_STRUCTURE.md` | `maybe_review` | `reviewed-no-change` | No path or workspace component was added, removed, or relocated in this partial repair. |
| `studio/QUICKSTART.md` | `maybe_review` | `reviewed-no-change` | No user-facing command surface or prerequisite changed. |

## Validation

- Focused R-B06 and conformance suite: 61 passed, 0 failed, 0 skipped.
- `git diff --check`: passed.
- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json`: `VALID=true`,
  0 errors, 0 warnings.
- Full governance Pester suite: 328 passed, 0 failed, 0 skipped.
- Hosted PR `audit-and-tests`: pending on the final pushed SHA.

## Merge Notes

- Keep this note Draft until the implementation commit exists and local validation passes.
- Resolve the two PR #3 review threads only after the final pushed SHA passes hosted validation.
- This partial R-B06 repair does not promote the experimental workflow runtime.

## Follow-ups

- Complete R-B06 RunState relocation and canonical feature-ID allocation in the remaining R2 batch.
- Apply the owner-decided R-B16 local-transient policy only after the final RunState location is selected.
