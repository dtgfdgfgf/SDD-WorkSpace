# Mainline Update Note: Agent Constitution Conformance + Doc Drift Fixes

<!-- Note: F3 (copilot phase line) was pulled from this batch mid-commit because the adapter-sync
     gate correctly required tri-adapter co-staging; see Deferred below. The gate was not bypassed. -->


**Date**: 2026-07-12
**Source Branch**: `feature/wave-3-security-and-workflows`
**Target Branch**: `main`
**Status**: Ready
**Related Commits**: `60556ef`
**Related PR**: N/A

## Summary

Agent-layer conformance (verified external-analysis claims A1, A2, A3, A5, F1, F2):

- **A1**: removed the `speckit.specify` -> `speckit.readiness` handoff so specify cannot skip clarify.
- **A3**: removed the `speckit.tasks` -> `speckit.implement` handoff so tasks cannot skip analyze
  (the machine gate in `setup-implement.ps1` already enforces this; this removes the prompt-level
  shortcut too).
- **A2**: removed the clarify agent's "you may skip clarification" clause, which violated Studio
  Constitution Section 2 / Section 10; replaced with a mandatory-stage statement.
- **A5**: retightened `speckit.specify` to stop inventing requirements — scope-defining unknowns
  are marked `[NEEDS CLARIFICATION]`; conventional defaults are allowed only for purely local
  details and only as provisional Assumptions confirmed in clarify. Removed the "reasonable
  defaults (don't ask): auth method, retention, ..." list, which contradicted the constitution.
- **F2**: corrected the Spec-Kit-QA agent's repository note, which wrongly called the checked-in
  `studio/` tree a "historical placeholder" and was self-contradictory; it now states studio/ is
  the highest authority here and to defer to project-local `.specify/` only in consumer projects.
- **F1** (side effect): re-seeding the Claude mirrors resynced `speckit-analyze.md` (it had lost
  the Mainline-Bound Shared-Layer change-manifest section) and the other edited agents.

Doc drift (verified claim F4):

- **F4**: removed the dangling `features.txt` row from `README.md` and `WORKSPACE_STRUCTURE.md`
  (the file was deleted in an earlier root cleanup).

Deferred: **F3** (copilot adapter phase line `Practice (as of 2025-12)` vs constitution
`Practice + Internal (as of 2026-04)`) is left for a dedicated fix. It lives only in the copilot
adapter's manual section, but the pre-commit adapter-sync gate requires all three runtime adapters
to be co-staged on any adapter change, and AGENTS.md / CLAUDE.md have no parallel line. Fixing it
correctly means a deliberate tri-adapter reconciliation (or removing the drift-prone duplicated
phase state from the adapter entirely), which is disproportionate to bundle here. Not bypassed.

## Why This Update Exists

An adversarially verified external analysis (2026-07-11, all cited claims confirmed) showed the
seven-stage order was complete as a file inventory but had prompt-level shortcuts that let agents
skip clarify and analyze, plus a Specify assumption policy that directly conflicted with
Constitution Section 10 and a QA agent that misdescribed repository authority. The owner chose to
tighten Specify (stop guessing) and to fix the handoff graph. Enforcement of the analyze step lives
in the machine gate (prior note `2026-07-12-analyze-completion-gate`); these edits align the
prompt layer and remove constitution contradictions.

## Scope

- Copilot source agents in `.github/agents/`, re-seeded to `.claude/agents/`.
- Two informational docs and one adapter manual section.
- Non-goals: constitution text is unchanged (Specify now conforms to existing Section 10, no
  exemption added); consumer-project constitutions (Trading six-stage, claim E5) are deliberately
  not touched per the owner's decision to leave existing projects alone; the workflow-engine
  false-completion issues (claims C1-C5) are a separate batch.

## Affected Paths

| Path | Change |
|------|--------|
| `.github/agents/speckit.specify.agent.md` | Remove readiness handoff (A1); stop-guessing policy (A5) |
| `.github/agents/speckit.tasks.agent.md` | Remove implement handoff (A3) |
| `.github/agents/speckit.clarify.agent.md` | Remove skip clause; mandatory-stage statement (A2) |
| `.github/agents/spec-kit.agent.md` | Correct repository authority note (F2) |
| `.claude/agents/*.md` | Re-seeded mirrors (spec-kit-qa-bot, speckit-analyze, speckit-clarify, speckit-discover, speckit-specify) |
| `README.md`, `WORKSPACE_STRUCTURE.md` | Remove dangling `features.txt` row (F4) |

## Impact

- Copilot-runtime handoffs no longer offer stage-skipping paths; specify no longer bakes in
  unstated scope decisions.
- The QA agent no longer tells readers to ignore the authoritative studio/ tree.
- No contract, hook, or constitution change; the agent bootstrap generated block is untouched
  (only the copilot adapter's manual section changed), so three-adapter parity is preserved.

## Validation

- `check-speckit-runtime.ps1`: Errors 0 / Warnings 0 (agent contracts + bootstrap parity intact).
- Full governance suite: 249 passed / 0 failed / 1 skipped.
- Drift check: the skip clause and the "historical placeholder" text are absent from both source
  and mirror (grep = 0).
- Change manifests: none required.

## Merge Notes

- Correctness/conformance batch from the verified external analysis; ready to merge with Wave-3.

## Follow-ups

- Workflow-engine false-completion fixes (claims C1-C5) — next batch.
- Optionally instruct `speckit.analyze.agent.md` to flip the Analyze Gate status marker
  (discoverability; the blocker message already self-documents it).
