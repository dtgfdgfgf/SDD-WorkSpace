# Mainline Update Note: Template completion (Patch 5 of governance review)

<!--
  Part of the v1.8.0 deep review remediation series. This is Patch 5 of 9.
-->

**Date**: 2026-04-30
**Source Branch**: `main`
**Target Branch**: `main`
**Status**: Ready
**Related Commits**: TBD
**Related PR**: N/A

## Summary

- Add five missing SDD document templates: `retrospective-template.md` (constitution Section 13.2), `learnings-entry-template.md` (Section 13.1), `research-template.md` (plan agent Phase 1), `data-model-template.md` (plan agent Phase 1), `quickstart-template.md` (plan agent Phase 1 + Section 12 surface truthfulness).
- Add the five new templates to `requiredDocTemplates` in the runtime contract; audit now enforces their presence.
- Fix `studio/templates/project-init/.gitignore` so it does not blanket-ignore `.claude/agents/` and `.github/agents/` (they are workspace junctions that derived worktrees MUST preserve per `docs/project-worktree-parity-governance.md`).

## Why This Update Exists

The deep review identified five required artifacts with no template:

- Constitution Section 13.2 mandates `retrospective.md` for Internal and Client projects, but no template existed. `init-project.ps1` was carrying an inline retrospective stub instead.
- Constitution Section 13.1 specifies an exact Markdown format for `studio/knowledge-base/learnings.md` entries, but no append-style snippet template existed to make that format reusable.
- The `speckit.plan` agent expects Phase 1 outputs `research.md`, `data-model.md`, and `quickstart.md`, but none of them had templates. New plan authors had to invent structure each time.

The old `project-init/.gitignore` rule `.claude/agents/` and `.github/agents/` directly contradicted the worktree parity policy (`docs/project-worktree-parity-governance.md`), which lists those junctions as required local bootstrap parity. Patch 5 narrows the ignore to genuinely-local sub-state (`.local/`).

## Scope

- New SDD document templates only.
- Contract `requiredDocTemplates` registration.
- Project-init `.gitignore` narrowing.
- Out of scope: modifying `init-project.ps1` to source `retrospective.md` from the new template (deferred to Patch 6 with the wider helper extraction). The current inline retrospective scaffold in `init-project.ps1` continues to work.

## Affected Paths

| Path | Change |
|------|--------|
| `studio/templates/sdd-docs/retrospective-template.md` | New: Internal/Client retrospective scaffold (constitution Section 13.2 fields plus Asset Extraction Review checklist). |
| `studio/templates/sdd-docs/learnings-entry-template.md` | New: append-style snippet matching Section 13.1 format with absolute-date guidance. |
| `studio/templates/sdd-docs/research-template.md` | New: plan-stage Phase 1 research output (Decisions / Open Questions / Out of Scope). |
| `studio/templates/sdd-docs/data-model-template.md` | New: plan-stage Phase 1 data model (Entities / Fields / Relationships / Invariants). |
| `studio/templates/sdd-docs/quickstart-template.md` | New: plan-stage Phase 1 quickstart with Section 12 surface-truthfulness Current Coverage / Known Gaps sections. |
| `studio/runtime/shared-runtime-contract.json` | `requiredDocTemplates` extended from 23 to 28 entries. |
| `studio/templates/project-init/.gitignore` | Replace blanket `.claude/agents/` and `.github/agents/` ignore with narrow `.local/` sub-state ignore; comment block explains worktree parity rationale. |

## Impact

- 116 tests still passing.
- `check-speckit-runtime.ps1 -Json` still `VALID: true`, `ERROR_COUNT: 0`. Audit now verifies the five new templates exist on disk.
- Newly created Practice / Internal / Client projects via `init-project.ps1` and `init-practice.ps1` will, going forward, see `.claude/agents/` and `.github/agents/` workspace junctions show up in `git status` if they are accidentally local content; the new ignore pattern only silences `.local/` sub-state.
- Future `/speckit.plan` runs can reference the new research / data-model / quickstart templates instead of inventing structure.

## Validation

- `pwsh ./studio/scripts/powershell/run-governance-tests.ps1` -> 116 passed, 0 failed.
- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json` -> `VALID: true`, all 28 required templates present.

## Merge Notes

- Patch 5 unblocks Patch 6 (init-script refactor will source retrospective from `retrospective-template.md`) and Patch 8 (stage entry gates can scaffold research / data-model / quickstart from these templates).

## Follow-ups

- Patch 6 will refactor `init-project.ps1`'s inline retrospective scaffold to read from `retrospective-template.md` with token substitution.
- Consider whether `mainline-update-note-template.md` should also be in `requiredDocTemplates` (it was already there since Patch 3 era; verified during this patch).
