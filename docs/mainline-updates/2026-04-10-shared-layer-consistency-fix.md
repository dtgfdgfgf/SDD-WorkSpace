# Mainline Update Note: Shared-Layer Consistency Fix

<!--
  Create under docs/mainline-updates/YYYY-MM-DD-short-topic.md
  Required for workspace-governance branches intended to merge into main when shared-layer
  governance, runtime agents, prompts, templates, hooks, shared scripts, or canonical docs change.
-->

**Date**: 2026-04-10
**Source Branch**: `main`
**Target Branch**: `main`
**Status**: Draft
**Related Commits**: `3355fc7e6252e44f5947f44b937bf0c78493df62`
**Related PR**: N/A
**Reconciliation Status**: Open

## Summary

- Fix constitution section numbering by removing inactive Section 10 and renumbering 11-14 to 10-13
- Establish clear authority hierarchy for dual copilot-instructions files
- Add 5 missing MUST validations to pre-commit hook (Document version, Estimated timeline, Planability vs Intent Obligations, intent-ledger)
- Sync all 15 stale mirror templates and add `-Fix` parameter to audit script
- Create ghost directory `docs/change-manifests/` referenced by sharedGatePaths
- Downgrade `studio/templates/sdd-agents/*.md` from Source of Truth to Dependent in constitution
- Add CLAUDE.md and copilot-instructions.md template generation to init scripts
- Add naming note for spec-kit-qa-bot asymmetry in shared runtime contract

## Why This Update Exists

A review-level audit of the shared layer (excluding `projects/` and `learning/`) identified 8 issues
ranging from Critical to Low severity. These issues create a gap between the strict MUST rules
defined in governance documents and what is actually enforced at runtime. Left unfixed, any project
trying to follow the design principles would encounter contradictions, missing validations, and
stale mirrors that undermine confidence in the governance model.

## Scope

- Studio constitution (renumber, authority classification, version bump)
- Shared runtime contract (mirror pairs, doc templates, hook requirements, naming note)
- Pre-commit hook (spec.md, plan.md, readiness-assessment.md, intent-ledger.md validations)
- Audit script (auto-fix capability)
- Init scripts (CLAUDE.md and copilot-instructions.md generation from templates)
- New document templates (claude-md-template.md, copilot-instructions-template.md)
- Authority headers on copilot-instructions files
- Mirror parity sync
- Ghost directory creation
- Non-goals: no changes to `projects/` or `learning/` consumer spaces

## Affected Paths

| Path | Change |
|------|--------|
| `studio/constitution/constitution.md` | Remove Section 10, renumber 11-14 to 10-13, fix authority classification, bump to v1.7.0 |
| `studio/runtime/shared-runtime-contract.json` | Remove copilot-instructions mirror pair, add doc templates, add hook requirements, add naming note |
| `.githooks/pre-commit.ps1` | Add Document version (spec/plan), Estimated timeline (plan), Planability vs Intent Obligations (readiness), intent-ledger validation section |
| `studio/scripts/powershell/check-speckit-runtime.ps1` | Add `-Fix` switch for auto-sync of stale mirrors |
| `studio/scripts/powershell/init-practice.ps1` | Generate CLAUDE.md and .github/copilot-instructions.md from templates |
| `studio/scripts/powershell/init-project.ps1` | Generate CLAUDE.md and .github/copilot-instructions.md from templates |
| `studio/templates/sdd-docs/claude-md-template.md` | New template for project CLAUDE.md generation |
| `studio/templates/sdd-docs/copilot-instructions-template.md` | New template for project copilot-instructions.md generation |
| `.github/copilot-instructions.md` | Add source_of_truth authority header |
| `.github/agents/copilot-instructions.md` | Add dependent authority header |
| `studio/templates/sdd-agents/*.agent.md` | 15 files synced from `.github/agents/` runtime source |
| `docs/change-manifests/.gitkeep` | New ghost directory for sharedGatePaths |

## Impact

- Constitution consumers see correct section numbering and accurate authority classifications
- Pre-commit hook now enforces all MUST requirements documented in constitution and runtime contract
- Init scripts produce operationally complete projects with both CLAUDE.md and copilot-instructions.md
- Audit script can auto-fix mirror drift with `-Fix` parameter
- No breaking changes to existing projects; all changes are additive or corrective

## Impact Reconciliation

Reconciliation remains open because the historical commit does not prove this note's broad parity,
auto-fix, and complete-MUST-enforcement claims. Current migration-route reconciliation belongs to
`docs/mainline-updates/2026-07-20-rb-5-agent-authority-process-truthfulness.md`; this historical note
is excluded from current readiness authorization and remains Draft.

## Revalidation (2026-07-20)

Git history identifies `3355fc7e6252e44f5947f44b937bf0c78493df62` as both the introducing and
last-touch commit for this note before immutable migration base
`de61431ae8f50d66f59157e00e4d239e9b37efdb`. The pre-migration SHA-256 was
`e665de253412bd0b510c211fccb9354be3a1ea08ad482dbe62790084c95e472f`.

The historical commit added drift-governance tooling and several hook, runtime, template, and
documentation changes, but its changed paths refute material claims in this note. It deleted all 16
files under `studio/templates/sdd-agents/` rather than synchronizing 15 stale mirror templates or
downgrading that mirror set. The audit accepted a `[switch]$Fix` parameter but contained no
corresponding auto-fix write path. The statement that the hook enforced all documented MUST
requirements was also broader than the demonstrated rule-to-gate evidence. Those parity, auto-fix,
and complete-enforcement claims are false as written, so the note cannot be promoted to Merged.

Re-entry requires a dated review that maps every retained Summary and Impact claim to the exact
historical changed paths and discriminating evidence. Any retained auto-fix claim must demonstrate
an actual bounded write path and a negative test; any complete-MUST-enforcement claim must include
an exhaustive rule-to-gate inventory. Until those conditions are met, reconciliation remains Open.

The Validation section below is retained as the contemporaneous report for that historical commit.
Any counts or outcomes in it are historical and were not rerun by RB-5 as current acceptance
evidence. Neither this note nor its historical commit can satisfy current Batch or Aggregate
readiness, path coverage, `must_update` reconciliation, runtime promotion, or the R6 fresh-fixture
gate.

## Validation

- `git diff --check`
- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json`
- Change manifests: none required (shared-layer governance fix, not feature delivery)
- Grep for stale section references (`Section 10` through `Section 14`) confirms no orphaned references
- Verify `docs/change-manifests/` directory exists

## Merge Notes

- The historical commit exists on `main`, but this note remains Draft because its broad closure
  claims are not supported by the recovered evidence.
- The claimed mirror synchronization and audit auto-fix behavior are not accepted as historical
  closure evidence.

## Follow-ups

- Satisfy the dated re-entry conditions above before attempting to close this note.
- Project adapter validation remains independent of this unproven historical closure.
