# Mainline Update Note: Template completion (Patch 5 of governance review)

<!--
  Part of the v1.8.0 deep review remediation series. This is Patch 5 of 9.
-->

**Date**: 2026-04-30
**Source Branch**: `main`
**Target Branch**: `main`
**Status**: Merged
**Related Commits**: `c6ee1f1fcf2eda0b517e1e8d1518d0332563ffb6`
**Related PR**: N/A
**Reconciliation Status**: Closed

## Revalidation (2026-07-20)

Git history identifies `c6ee1f1fcf2eda0b517e1e8d1518d0332563ffb6` as both the introducing
and last-touch commit for this note before immutable migration base
`de61431ae8f50d66f59157e00e4d239e9b37efdb`. The pre-migration SHA-256 was
`f4d76ca3a5a653a5a25e7778d608cc66328b57686eb497e42365c3ad7c1a90c5`.

The Validation section below is retained as the contemporaneous report for that historical commit.
RB-5 did not rerun those historical counts as current acceptance evidence. Neither this note nor
its historical commit can satisfy present Batch or Aggregate evidence, path coverage,
`must_update` reconciliation, runtime promotion, or the R6 fresh-fixture gate.

The historical rationale for leaving agent junction contents visible to consumer Git intake was
later refuted by R-A19. Commit `9819e301318230ca0413d44a5bdf3d2a3b3e3ca6` introduced
rooted ignores that preserve junction usability without reporting or staging shared bytes. The
template additions and contract registration remain valid historical changes.

## Summary

- Add five missing SDD document templates: `retrospective-template.md` (constitution Section 13.2), `learnings-entry-template.md` (Section 13.1), `research-template.md` (plan agent Phase 1), `data-model-template.md` (plan agent Phase 1), `quickstart-template.md` (plan agent Phase 1 + Section 12 surface truthfulness).
- Add the five new templates to `requiredDocTemplates` in the runtime contract; audit now enforces their presence.
- Fix `studio/templates/project-init/.gitignore` so it does not blanket-ignore `.claude/agents/` and `.github/agents/` (they are workspace junctions that derived worktrees MUST preserve per `docs/project-worktree-parity-governance.md`).

## Why This Update Exists

The deep review identified five required artifacts with no template:

- Constitution Section 13.2 mandates `retrospective.md` for Internal and Client projects, but no template existed. `init-project.ps1` was carrying an inline retrospective stub instead.
- Constitution Section 13.1 specifies an exact Markdown format for `studio/knowledge-base/learnings.md` entries, but no append-style snippet template existed to make that format reusable.
- The `speckit.plan` agent expects Phase 1 outputs `research.md`, `data-model.md`, and `quickstart.md`, but none of them had templates. New plan authors had to invent structure each time.

At that time, the old `project-init/.gitignore` rules for `.claude/agents/` and
`.github/agents/` were interpreted as contradicting the worktree parity policy, which lists those
junctions as required local bootstrap parity. Patch 5 narrowed the ignore to `.local/`; R-A19
later refuted the conclusion that shared junction bytes should remain visible to consumer Git
intake.

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
- At `c6ee1f1fcf2eda0b517e1e8d1518d0332563ffb6`, newly created Practice / Internal /
  Client projects showed `.claude/agents/` and `.github/agents/` workspace junction content in
  `git status`; the pattern then silenced only `.local/` sub-state. R-A19 later superseded this
  intake behavior.
- Future `/speckit.plan` runs can reference the new research / data-model / quickstart templates instead of inventing structure.

## Validation

- `pwsh ./studio/scripts/powershell/run-governance-tests.ps1` -> 116 passed, 0 failed.
- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json` -> `VALID: true`, all 28 required templates present.

## Impact Reconciliation

This historical note is sealed migration evidence only. It is excluded from current
reconciliation and cannot satisfy current `must_update` routes. Current RB-5 reconciliation is
owned by `2026-07-20-rb-5-agent-authority-process-truthfulness.md`; this note records no
present-day update disposition.

## Merge Notes

- Patch 5 unblocks Patch 6 (init-script refactor will source retrospective from `retrospective-template.md`) and Patch 8 (stage entry gates can scaffold research / data-model / quickstart from these templates).

## Follow-ups

- Patch 6 will refactor `init-project.ps1`'s inline retrospective scaffold to read from `retrospective-template.md` with token substitution.
- Consider whether `mainline-update-note-template.md` should also be in `requiredDocTemplates` (it was already there since Patch 3 era; verified during this patch).
