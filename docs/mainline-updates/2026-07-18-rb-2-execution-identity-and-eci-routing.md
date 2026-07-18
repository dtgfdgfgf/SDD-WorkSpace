# Mainline Update Note: RB-2 Execution Identity and ECI Routing

**Date**: 2026-07-18
**Source Branch**: `feature/wave-3-security-and-workflows`
**Target Branch**: `main`
**Status**: Draft
**Related Commits**: `TBD`
**Related PR**: https://github.com/dtgfdgfgf/SDD-WorkSpace/pull/3
**Reconciliation Status**: Open

## Summary

- Bind approved `workflow.yml` raw bytes to the catalog and RunState with SHA-256, then reject
  fresh execution, resume, or restart when the graph identity is not explicitly approved.
- Validate exactly one of eight Readiness statuses and exactly one of four ECI outcomes, require
  the complete four-file ECI dossier, and make direct Plan entry use the same fail-closed validator.
- Replace the ECI reminder gate with a distinct second Readiness agent step. The three bounded
  outcomes may re-enter Readiness; `NOT_READY` cannot reach re-entry or Plan.

## Why This Update Exists

RVR-04 and ledger R-B21 showed that id and version did not identify the reviewed workflow graph:
same-version content changes could start a fresh run, and resume could combine old
`completed_steps` with a changed graph. RVR-07 and ledger R-B07/R-B22 showed that the ECI branch
accepted only `authorization-record.md`, reused the completed first Readiness step instead of
running a second assessment, and parsed the first matching field rather than enforcing exactly-one.

RB-2 opened with a governance drift: its original plan said three ECI outcomes, while the canonical
ECI agent and templates defined a fourth value, `NOT_READY`. The owner confirmed the four-value enum
on 2026-07-18. The dated remediation-plan addendum preserves that decision and the superseded text.

## Scope

- R-B21: catalog approval digest, exact-byte engine parsing, RunState graph identity, resume and
  restart semantics, listing visibility, policy, contract, and regression coverage.
- R-B07 and R-B22: complete ECI dossier validation, exactly-one Readiness and ECI fields, direct Plan
  enforcement, a distinct post-ECI Readiness step, and eight-status plus four-outcome routing tests.
- No changes under `projects/` or `learning/`, no PR thread resolution, no main merge, and no workflow
  promotion. `sdd-pipeline` remains experimental, disabled, and execution-denied until R6.
- R-B23 remains a separate open finding. Graph identity does not prove the provenance of
  `completed_steps`, persisted routing variables, gate decisions, or coordinated same-principal
  RunState and sidecar edits.

## Affected Paths

| Path | Change |
|------|--------|
| `studio/workflows/catalog.schema.json`, `studio/workflows/catalog.json` | Require a lowercase approval digest for approved or deprecated workflows; keep the experimental built-in digest null and denied. |
| `studio/scripts/powershell/common.ps1`, `run-workflow.ps1`, `list-workflows.ps1` | Compute and compare actual and approved graph digests through the shared registry decision and expose the result in listing output. |
| `studio/scripts/powershell/workflow-engine.ps1` | Hash and parse one byte snapshot, persist graph identity, and reject legacy or mismatched resume before replay. |
| `studio/scripts/powershell/validate-feature-structure.ps1`, `setup-plan.ps1` | Enforce complete ECI evidence, closed enums, exactly-one fields, coherent authorization, and direct Plan gating. |
| `studio/workflows/sdd-pipeline/workflow.yml`, `manifest.json`, `docs/README.md` | Move the graph to version 1.1.0 with validated initial routing, four ECI outcomes, and a distinct second Readiness assessment. |
| `studio/workflows/POLICY.md` | Document raw-byte approval, RunState identity, reapproval, resume, and restart semantics without claiming local checkpoint authenticity. |
| `studio/runtime/shared-runtime-contract.json` | Anchor graph identity, dossier, exactly-one, re-entry, direct Plan, listing, schema, and denied-workflow invariants. |
| `studio/tests/*.Tests.ps1` | Add discriminating graph mutation, RunState identity, catalog digest, dossier, direct Plan, duplicate-field, eight-status, and four-outcome coverage. |

## Impact

- A comment-only or semantic same-version `workflow.yml` change invalidates approval. Reapproval can
  authorize a new run but cannot turn an old RunState into a hybrid resume.
- Missing, null, wrong-type, malformed, uppercase, or mismatched workflow digests fail closed.
- Removing any ECI dossier file, leaving only the trigger, duplicating a status or outcome, or
  presenting a non-mainline outcome to direct Plan cannot authorize planning.
- The latest post-ECI Readiness assessment, rather than the first assessment or a reminder gate,
  controls the final eight-status routing decision.

## Impact Reconciliation

| Target | Impact | Disposition | Evidence |
|--------|--------|-------------|----------|
| `studio/runtime/shared-runtime-contract.json` | `must_review` | `updated` | New catalog, engine, runner, listing, Plan, validator, policy, manifest, and workflow invariants pass the canonical audit. |
| `.githooks/pre-commit.ps1` | `must_review` | `reviewed-no-change` | The existing staged-snapshot audit consumes the updated contract without hook semantic changes. |
| `studio/scripts/powershell/check-speckit-runtime.ps1` | `must_review` | `reviewed-no-change` | The generic contract consumer reports `VALID=true`, 0 errors, and 0 warnings. |
| `studio/constitution/constitution.md` | `maybe_review` | `reviewed-no-change` | RB-2 implements existing v1.8.0 exactly-one, ECI re-entry, stage-order, and Surface Truthfulness rules. |
| `studio/tests/path-traversal-hardening.Tests.ps1` | `must_review` | `reviewed-no-change` | No path-boundary primitive or governed root changed; the existing suite remains part of the full gate. |
| `studio/scripts/powershell/workflow-engine.ps1` | `must_review` | `updated` | Exact-byte graph identity and strict resume/restart binding are implemented and covered by old/new evidence. |
| `studio/scripts/powershell/validate-workflow.ps1` | `must_review` | `reviewed-no-change` | Existing schema parsing validates workflow 1.1.0 without validator changes. |
| `studio/tests/sdd-pipeline.Tests.ps1` | `must_review` | `updated` | Tests cover the distinct second Readiness step, eight latest statuses, and four ECI outcomes. |
| `studio/tests/workflow-schema.Tests.ps1` | `must_review` | `updated` | Live catalog and manifest version, denial state, and digest visibility are asserted. |
| `WORKSPACE_STRUCTURE.md` | `maybe_review` | `reviewed-no-change` | No path, ownership, or workspace-layout boundary changed. |
| `studio/QUICKSTART.md` | `maybe_review` | `reviewed-no-change` | Public invocation remains unchanged and the built-in workflow remains denied; detailed runtime semantics live in workflow policy and docs. |

## Validation

- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json`: `VALID=true`, 0 errors,
  0 warnings.
- Focused RB-2 integration suite: 276 passed, 0 failed, 0 skipped.
- Detached old-head overlay at `6030b27`: the new R-B21 graph and RunState identity block was
  0 of 12; direct Plan dossier and duplicate-field negatives were 0 of 7; exactly-one Readiness
  negatives were 0 of 3; new ECI re-entry graph invariants were 8 of 16.
- Current-head discriminating blocks and full governance results remain pending before this Draft
  note can become Ready.

## Merge Notes

- This note is Draft until the implementation commit exists, independent adversarial review closes,
  the ledger receives a dated status update, and all final machine gates pass at the committed head.
- RB-2 completion will not make PR #3 ready to merge. RB-3 through RB-5 and R6 remain mandatory.

## Follow-ups

- Keep R-B23 open for comprehensive RunState and sidecar authenticity; do not reinterpret the R-B21
  digest as progress, routing, gate-decision, or local-checkpoint provenance.
- Execute RB-3 through RB-5 and R6. Do not re-promote `sdd-pipeline` before fresh-fixture R6 acceptance.
