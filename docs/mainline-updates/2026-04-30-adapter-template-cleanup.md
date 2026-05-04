# Mainline Update Note: Adapter and template stale-text cleanup (Patch 4 of governance review)

<!--
  Part of the v1.8.0 deep review remediation series. This is Patch 4 of 9.
-->

**Date**: 2026-04-30
**Source Branch**: `main`
**Target Branch**: `main`
**Status**: Ready
**Related Commits**: TBD
**Related PR**: N/A

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

## Validation

- `pwsh ./studio/scripts/powershell/run-governance-tests.ps1` -> 116 passed, 0 failed.
- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json` -> `VALID: true`, `ERROR_COUNT: 0`.
- Manual: confirmed `.github/copilot-instructions.md` now has exactly one H1 (line 1).

## Merge Notes

- This patch land independent of Patch 5 sequencing, but Patch 5 (template completion) MUST land before Patch 6 (init-script refactor).

## Follow-ups

- L13 (agent file naming convention writeup): keep as low-priority cosmetic. Current state: `speckit.<cmd>.agent.md` for SDD stage commands, kebab-case bare filenames (`spec-kit.agent.md`, `async-python-reviewer.md`) for non-stage agents. Document this in `studio/SDD-QUICKSTART-GUIDE.md` when next touched.
- Existing mainline-update notes from Patches 1-4 currently have `Related Commits: TBD` and `Status: Ready` because they have not been committed yet at the time of this writing. They will be retroactively filled in once these patches land in their merge commit. Treat as expected transient state for the deep-review remediation batch.
- L6 (`async-python-reviewer.md` source verification): closed. The source file exists in `.github/agents/`; the seeded note is accurate.
