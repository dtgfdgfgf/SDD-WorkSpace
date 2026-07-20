# Mainline Update Note: Adapter and template stale-text cleanup (Patch 4 of governance review)

<!--
  Part of the v1.8.0 deep review remediation series. This is Patch 4 of 9.
-->

**Date**: 2026-04-30
**Source Branch**: `main`
**Target Branch**: `main`
**Status**: Merged
**Related Commits**: `c6ee1f1fcf2eda0b517e1e8d1518d0332563ffb6`
**Related PR**: N/A
**Reconciliation Status**: Closed

## Summary

- Remove the stale "this repository does not contain a checked-in `studio/` governance tree" warning from `.github/agents/copilot-instructions.md`. The repository does check in `studio/`; the warning was inherited from a historical template and contradicted current state.
- Add explicit constitution Section 10 wording that agent-scoped subset adapters (e.g., `.github/agents/copilot-instructions.md`) are dependent documents that derive from their workspace-level adapter and MAY NOT carry an independent `GENERATED GOVERNANCE BOOTSTRAP` block.
- Replace duplicate `# Copilot Instructions` H1 in `.github/copilot-instructions.md` line 38 with a non-conflicting `## Workspace Overview` heading; the file's canonical H1 stays at line 1 (`# Copilot Instructions: Workspace`).
- Add HTML comment to all three runtime adapter templates (`agents-md-template.md`, `claude-md-template.md`, `copilot-instructions-template.md`) documenting why only Claude carries a `## Direct Imports` section (Codex and Copilot do not support `@path` imports).
- Strengthen `mainline-update-note-template.md` Status state machine: Ready notes MUST list at least one concrete commit hash; only Draft notes may have `Related Commits: TBD`.

## Why This Update Exists

The `.github/agents/copilot-instructions.md` warning was a stale carry-over from when the workspace did not yet check in the studio tree. New contributors reading the file would see contradictory guidance versus the live repo. Patch 4 removes the contradiction and replaces it with a positive authority declaration aligned with constitution Section 10.

The `agent-scoped subset` exemption from `GENERATED GOVERNANCE BOOTSTRAP` synchronization was implicit in Section 10's "five-file model" but not stated. Patch 4 makes it explicit so future contributors do not erroneously try to add a bootstrap block to the agent-scoped subset (or rewrite Section 10 to require it).

The duplicate H1 in `.github/copilot-instructions.md` was a markdown structural defect that some renderers handle ambiguously and many lint tools flag.

The Direct Imports asymmetry across the three adapter templates was correct by design (Claude-only feature) but undocumented; new contributors syncing the three templates risked accidentally deleting the CLAUDE.md section or copy-pasting it into the others.

## Scope

- Stale text removal in `.github/agents/copilot-instructions.md`.
- Heading-level fix in workspace-level `.github/copilot-instructions.md`.
- New constitution Section 10 paragraph (additive, no version bump — clarifies existing five-file model).
- HTML comment additions in three adapter templates.
- Updated mainline-update template state-machine documentation.
- Out of scope: agent file-naming convention writeup (L13) and async-python-reviewer source verification (L6) — both either no longer needed or moved to follow-ups.

## Affected Paths

| Path | Change |
|------|--------|
| `.github/agents/copilot-instructions.md` | Removed stale `studio/` repo note; replaced with positive authority declaration; updated last-modified date; bumped template marker to v1.1.0. |
| `.github/copilot-instructions.md` | Replaced duplicate `# Copilot Instructions` H1 with `## Workspace Overview` H2 inside the MANUAL ADDITIONS block. |
| `studio/constitution/constitution.md` | Section 10 (Runtime Agent Bootstrap Governance): new paragraph documenting agent-scoped subset exemption from GENERATED GOVERNANCE BOOTSTRAP synchronization. |
| `studio/templates/sdd-docs/agents-md-template.md` | New HTML comment explaining Codex/Copilot CLI lack of `@path` import support. |
| `studio/templates/sdd-docs/claude-md-template.md` | New HTML comment explaining Direct Imports is Claude-only by design. |
| `studio/templates/sdd-docs/copilot-instructions-template.md` | New HTML comment explaining GitHub Copilot lack of `@path` import support. |
| `studio/templates/sdd-docs/mainline-update-note-template.md` | Status state machine documented inline; Ready requires concrete commit hash. |

## Impact

- 116 tests still passing (no test changes in this patch).
- `check-speckit-runtime.ps1 -Json` still `VALID: true`.
- Constitution Section 10 added a clarifying paragraph but did not change any normative rule, so adapter version strings did not change and the three workspace adapters did not need re-syncing in this patch.
- Future authors of `.github/agents/<scope>-instructions.md`-style agent-scoped subsets now have explicit guidance not to add a bootstrap block.
- mainline-update note authors should now treat `Status: Ready` as a contract that `Related Commits` is filled in.

## Impact Reconciliation

Historical reconciliation is closed only for recovering the exact introducing commit and confirming
the scoped adapter-text, template-comment, heading, constitution clarification, and note-template
changes. Current migration-route reconciliation belongs to
`docs/mainline-updates/2026-07-20-rb-5-agent-authority-process-truthfulness.md`; this historical note
is excluded from current readiness authorization.

## Revalidation (2026-07-20)

Git history identifies `c6ee1f1fcf2eda0b517e1e8d1518d0332563ffb6` as both the introducing and
last-touch commit for this note before immutable migration base
`de61431ae8f50d66f59157e00e4d239e9b37efdb`. The pre-migration SHA-256 was
`fa37919ccf812be0b442eb28d273a9022de17345cd508b249e675c800706a2d3`.

No material correction is required for the scoped adapter and template cleanup. Merged status
records exact historical commit recovery only. The transient `Related Commits: TBD` explanation in
the original follow-up text ceased to apply once the historical commit was recovered.

The Validation section below is retained as the contemporaneous report for that historical commit.
Any counts or outcomes in it are historical and were not rerun by RB-5 as current acceptance
evidence. Neither this note nor its historical commit can satisfy current Batch or Aggregate
readiness, path coverage, `must_update` reconciliation, runtime promotion, or the R6 fresh-fixture
gate.

## Validation

- `pwsh ./studio/scripts/powershell/run-governance-tests.ps1` reported 116 passed and 0 failed.
- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json` reported `VALID: true` and
  `ERROR_COUNT: 0`.
- Manual: confirmed `.github/copilot-instructions.md` now has exactly one H1 (line 1).

## Merge Notes

- This patch landed in the historical deep-review batch. Its contemporaneous sequencing rule
  required Patch 5 (template completion) before Patch 6 (init-script refactor).

## Follow-ups

- L13 (agent file naming convention writeup): keep as low-priority cosmetic. Current state: `speckit.<cmd>.agent.md` for SDD stage commands, kebab-case bare filenames (`spec-kit.agent.md`, `async-python-reviewer.md`) for non-stage agents. Document this in `studio/SDD-QUICKSTART-GUIDE.md` when next touched.
- The historical transient `Related Commits: TBD` state for Patches 1-4 was resolved by the
  2026-07-20 evidence migration and is not a current exception.
- L6 (`async-python-reviewer.md` source verification): closed. The source file exists in `.github/agents/`; the seeded note is accurate.
