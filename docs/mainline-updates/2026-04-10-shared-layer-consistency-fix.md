# Mainline Update Note: Shared-Layer Consistency Fix

<!--
  Create under docs/mainline-updates/YYYY-MM-DD-short-topic.md
  Required for workspace-governance branches intended to merge into main when shared-layer
  governance, runtime agents, prompts, templates, hooks, shared scripts, or canonical docs change.
-->

**Date**: 2026-04-10
**Source Branch**: `main`
**Target Branch**: `main`
**Status**: Ready
**Related Commits**: TBD
**Related PR**: N/A

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

## Validation

- `git diff --check`
- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json`
- Change manifests: none required (shared-layer governance fix, not feature delivery)
- Grep for stale section references (`Section 10` through `Section 14`) confirms no orphaned references
- Verify `docs/change-manifests/` directory exists

## Merge Notes

- All changes are on `main` branch directly (shared-layer governance fix)
- No conflicts expected as changes are isolated to shared layer
- Mirror sync was performed as final step to ensure clean audit output

## Follow-ups

- None immediate
- Future: consider adding pre-commit validation for CLAUDE.md and copilot-instructions.md existence in project directories
