# Mainline Update Note: RB-2 Execution Identity and ECI Routing

**Date**: 2026-07-18
**Source Branch**: `feature/wave-3-security-and-workflows`
**Target Branch**: `main`
**Status**: Ready
**Related Commits**: `e4d2167`; `d548124`; `ec25c07`
**Related PR**: https://github.com/dtgfdgfgf/SDD-WorkSpace/pull/3
**Reconciliation Status**: Closed

## Summary

- Bind approved `workflow.yml` raw bytes to the catalog and RunState with SHA-256, then reject
  fresh execution, resume, or restart when the graph identity is not explicitly approved.
- Validate exactly one of eight Readiness statuses and exactly one of four ECI outcomes, require
  `eci-trigger.md` plus the complete four-file ECI dossier, bind all five canonical evidence files
  to a framed digest and a persistent feature-bound requirement latch, and make direct Plan entry
  use the same fail-closed validator.
- Replace the ECI reminder gate with a distinct second Readiness agent step. The three bounded
  outcomes may re-enter Readiness; `NOT_READY` cannot reach re-entry or Plan.
- Repair the adjacent counterexamples discovered during RB-2: shared manifest and physical-path
  authorization for R-B20/R-B05, plus collision-resistant no-overwrite restart archives for
  R-B10/R-B24.

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
  enforcement, a distinct post-ECI Readiness step, a persistent feature-bound local requirement
  latch, and eight-status plus four-outcome routing tests.
- R-B20/R-B05 and R-B10/R-B24: truth-first reopening followed by shared manifest and physical
  reparse authorization, exact `sourcePath` execution, and no-overwrite restart archive repair.
  These are adjacent repairs, not subcases absorbed into R-B21.
- No changes under `projects/` or `learning/`, no PR thread resolution, no main merge, and no workflow
  promotion. `sdd-pipeline` remains experimental, disabled, and execution-denied until R6.
- R-B23 remains a separate open finding. Coordinated marker and evidence deletion or forgery,
  RunState and sidecar co-forgery, `completed_steps`, routing, or gate-decision injection, and run-ID
  or path substitution remain outside RB-2's closure. Graph identity and the local ECI latch do not
  prove the provenance of those checkpoints.

## Affected Paths

| Path | Change |
|------|--------|
| `studio/workflows/catalog.schema.json`, `studio/workflows/catalog.json` | Require a lowercase approval digest for approved or deprecated workflows; keep the experimental built-in digest null and denied. |
| `studio/scripts/powershell/common.ps1`, `run-workflow.ps1`, `list-workflows.ps1` | Compute and compare graph digests, validate manifest identity, resolve every existing reparse target inside the physical workflow root, execute the authorized `sourcePath`, and share one list/run decision. |
| `studio/scripts/powershell/workflow-engine.ps1` | Hash and parse one byte snapshot, persist graph identity, and reject legacy or mismatched resume before replay. |
| `studio/scripts/powershell/setup-eci.ps1`, `validate-feature-structure.ps1`, `setup-plan.ps1` | Atomically latch the exact initial ECI requirement, enforce complete five-file evidence, closed enums, exactly-one fields, coherent authorization, and direct Plan gating. |
| `studio/workflows/sdd-pipeline/workflow.yml`, `manifest.json`, `docs/README.md` | Move the graph to version 1.1.0 with validated initial routing, four ECI outcomes, and a distinct second Readiness assessment. |
| `studio/workflows/POLICY.md` | Document raw-byte approval, RunState identity, ECI latch limits, reapproval, resume, and no-overwrite restart semantics without claiming local checkpoint authenticity. |
| `studio/runtime/shared-runtime-contract.json` | Anchor graph identity, dossier, exactly-one, re-entry, direct Plan, listing, schema, and denied-workflow invariants. |
| `studio/tests/*.Tests.ps1` | Add discriminating graph mutation, RunState identity, catalog digest, dossier, direct Plan, duplicate-field, eight-status, and four-outcome coverage. |

## Impact

- A comment-only or semantic same-version `workflow.yml` change invalidates approval. Reapproval can
  authorize a new run but cannot turn an old RunState into a hybrid resume.
- Missing, null, wrong-type, malformed, uppercase, or mismatched workflow digests fail closed.
- Removing any ECI dossier file, leaving only the trigger, duplicating a status or outcome, or
  presenting a non-mainline outcome to direct Plan cannot authorize planning.
- The initial Readiness result may enter ECI only when its exact primary status is `ROUTE_TO_ECI`.
  `setup-eci.ps1` is the non-bypassable first action for both canonical ECI agent surfaces and
  atomically creates the feature-bound local requirement marker without overwriting an existing
  marker.
- The canonical ECI evidence is `eci-trigger.md` plus the four dossier files. Their names and raw
  bytes are length-framed into one digest, which must agree with the readiness
  `ECI Re-entry Status` and `ECI Evidence SHA-256` fields. A fresh or restarted run with an already
  complete, coherent dossier skips ECI and proceeds through the post-ECI Readiness assessment.
- The latest post-ECI Readiness assessment, rather than the first assessment or a reminder gate,
  controls the final eight-status routing decision.
- Listing and execution share manifest existence, object shape, id, version, exact `sourcePath`, and
  all-component physical reparse-boundary authorization. Restart archives use collision-resistant
  names and atomic no-overwrite publication, preserving every prior run identity.

## Impact Reconciliation

| Target | Impact | Disposition | Evidence |
|--------|--------|-------------|----------|
| `.claude/agents/*.md` | `must_update` | `updated` | ECI and Readiness Claude mirrors carry the same setup-eci first-action, marker, five-evidence, and re-entry semantics as their canonical Copilot sources; contract and focused tests cover both surfaces. |
| `.github/agents/*.agent.md` | `maybe_review` | `updated` | Canonical ECI and Readiness agents expose the non-bypassable ECI entry gate and persistent requirement semantics. |
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
- Focused RB-2 integration suite: 353 passed, 0 failed, 0 skipped.
- `pwsh ./studio/scripts/powershell/run-governance-tests.ps1`: 579 passed, 0 failed, 0 skipped.
- Detached old-head overlay at `6030b27`: the R-B21 identity block was 1 of 13; ECI validator
  negatives were 0 of 25; direct Plan was 1 of 13; adapted outcome and re-entry cases were 0 of 9.
  The old listing authorized a manifest version mismatch, an external junction reached execution,
  and a same-destination restart archive overwrite erased the first run.
- Current-head tests deny those cases. The marker-retained deletion and `NOT_REQUIRED` rewrite,
  stale framed evidence, fresh and restarted complete-dossier routing, exact archive collision,
  manifest identity, and physical reparse boundary are included.
- Independent adversarial review reported no remaining RB-2 blocker.
- `pwsh ./studio/scripts/powershell/validate-mainline-notes.ps1 -BaseRef origin/main -HeadRef HEAD
  -RequireReady -Json`: `VALID=true`, 0 errors, 0 warnings.
- `git diff --check`: no whitespace errors.

## Merge Notes

- Implementation commit `ec25c07` and the truth-first reopening commits `e4d2167` and `d548124`
  provide the coherent RB-2 history. The note is Ready only with the dated ledger closure and final
  accounting gates.
- RB-2 makes the branch closer to merge readiness but PR #3 remains NOT READY TO MERGE. RB-3 through
  RB-5 and R6 remain mandatory, and `sdd-pipeline` remains experimental, default-disabled, and
  execution-denied.

## Follow-ups

- Keep R-B23 open for comprehensive RunState and sidecar authenticity; do not reinterpret the R-B21
  digest or ECI marker as progress, routing, gate-decision, run-ID/path, or local-checkpoint
  provenance.
- Execute RB-3 through RB-5 and R6. Do not re-promote `sdd-pipeline` before fresh-fixture R6 acceptance.
