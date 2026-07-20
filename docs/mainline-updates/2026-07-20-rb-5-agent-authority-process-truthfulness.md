# Mainline Update Note: RB-5 Agent, Authority, and Process Truthfulness

**Date**: 2026-07-20
**Source Branch**: `feature/wave-3-security-and-workflows`
**Target Branch**: `main`
**Status**: Draft
**Related Commits**: `TBD`
**Related PR**: https://github.com/dtgfdgfgf/SDD-WorkSpace/pull/3
**Reconciliation Status**: Open
**Validation Scope**: Batch

## Summary

- Remove contradictory Specify instructions that capped material clarification markers, guessed the
  remainder, or offered Readiness before Clarify.
- Make Claude agent mirrors deterministic and content-verifiable, and fail loudly when a Copilot
  tool cannot be mapped to an explicit least-privilege Claude tool set.
- Define the canonical workspace governance self-application route as an evidence-equivalent,
  shared-only route that cannot authorize consumer work, Aggregate acceptance, runtime promotion,
  or the R6 fresh-fixture obligation.
- Replace the legacy Ready-note hash exception with a one-time, machine-bound historical evidence
  migration. R-A22 records the migration dependency; R-E09 remains incomplete until the Wave-3
  aggregate note is finalized in R6.

## Why This Update Exists

RVR-10 showed that the Specify source contradicted itself, the canonical audit accepted emptied
Claude mirror bodies, and an unknown tool mapping could remove the Claude `tools` field and broaden
permissions. RVR-12 also showed that the workspace used mainline notes and machine gates as an
undeclared alternative to per-feature SDD artifacts, while 18 historical notes retained
`Related Commits: TBD`.

RB-5 closes the agent and self-application authority gaps. Historical note recovery is deliberately
separate from current branch authorization: migrated historical commits cannot satisfy Batch or
Aggregate readiness, path coverage, or `must_update` reconciliation. The Wave-3 aggregate note
stays Draft until R6.

## Scope

In scope:

- R-D01, R-D04, and R-D05 agent-source, mirror-parity, and tool-mapping repair.
- R-E07 constitutional self-application boundary and synchronized adapter guidance.
- R-A22 one-time historical evidence migration controls.
- The historical portion of R-E09, including truth review of all 18 legacy Ready/TBD notes.

Out of scope:

- Consumer drift under `projects/` or `learning/`.
- Promotion of `sdd-pipeline`, Aggregate readiness, fresh-fixture seven-stage evidence, merge to
  `main`, post-merge validation, or PR thread resolution.
- R-E09 final Wave-3 aggregate accounting, which remains an R6 obligation.

## Affected Paths

| Path | Change |
|------|--------|
| `.github/agents/*.agent.md` | Remove Specify contradictions and declare bounded Claude mappings where automatic mapping is unavailable |
| `.claude/agents/*.md` | Deterministically regenerated dependent mirrors |
| `studio/scripts/powershell/seed-claude-agents.ps1` | Add normalized `-Verify` parity and fail-loud tool conversion |
| `studio/scripts/powershell/check-speckit-runtime.ps1` | Run Claude content parity as part of the canonical audit |
| `studio/constitution/constitution.md` | Define the canonical workspace shared-layer self-application route |
| `AGENTS.md`, `CLAUDE.md`, `.github/copilot-instructions.md` | Propagate the scoped governance route |
| `README.md`, `studio/QUICKSTART.md`, `studio/SDD-QUICKSTART-GUIDE.md` | Explain project delivery and workspace self-application boundaries |
| `studio/runtime/mainline-note-historical-evidence*.json` | Define and record the one-time historical note migration |
| `studio/scripts/powershell/validate-mainline-notes.ps1` | Validate historical records without granting current readiness evidence |
| `docs/mainline-updates/2026-04-*.md`, `docs/mainline-updates/2026-05-01-*.md` | Recover exact historical commits and correct overclaims |

## Impact

- Specify must preserve every material unknown for user clarification and can hand off only to
  Clarify.
- Any missing, extra, or body-drifted Claude mirror makes the canonical audit fail.
- Unsupported tool mappings stop generation before mirror writes instead of silently producing an
  unrestricted dependent agent.
- Workspace shared-layer maintenance has a narrow constitutional route with the same evidence
  obligations as this repair campaign; projects and ordinary features still use all seven stages.
- Historical notes become auditable debt records but cannot prove current merge readiness.

## Impact Reconciliation

| Target | Impact | Disposition | Evidence |
|--------|--------|-------------|----------|
| `README.md` | `must_update` | `pending` | R-E07 self-application boundary is drafted and awaits final RB-5 validation. |
| `studio/QUICKSTART.md` | `must_update` | `pending` | R-E07 quickstart boundary is drafted and awaits final RB-5 validation. |
| `studio/SDD-QUICKSTART-GUIDE.md` | `must_update` | `pending` | R-E07 guide boundary is drafted and awaits final RB-5 validation. |
| `.claude/agents/*.md` | `must_update` | `pending` | Source-derived mirrors are regenerated and await focused parity validation. |
| `AGENTS.md` | `must_update` | `pending` | Generated Constitution 1.9.0 bootstrap awaits final audit. |
| `CLAUDE.md` | `must_update` | `pending` | Generated Constitution 1.9.0 bootstrap awaits final audit. |
| `.github/copilot-instructions.md` | `must_update` | `pending` | Generated bootstrap and manual boundary await final audit. |

## Validation

Pending before promotion:

- Exact pre-batch negative overlays for Specify contradiction, empty mirror acceptance, and unknown
  tool fail-open behavior.
- Historical migration adversarial tests for schema, immutable base, exact note bytes, commit role,
  completed-state sealing, and non-authorization.
- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json`
- `pwsh ./studio/scripts/powershell/run-governance-tests.ps1`
- `pwsh ./studio/scripts/powershell/validate-mainline-notes.ps1 -BaseRef de61431ae8f50d66f59157e00e4d239e9b37efdb -HeadRef HEAD -RequireReady -ReadinessScope Batch -Json`
- `git diff --check`

## Merge Notes

- Draft while implementation, historical migration, and accounting are incomplete.
- RB-5 completion will make the branch closer to mergeable but will not make it merge-ready.
- The aggregate Wave-3 note remains Draft, and PR #3 remains `NOT READY TO MERGE` until R6.

## Follow-ups

- R6 must run fresh-fixture seven-stage E2E, satisfy every minimum merge gate, decide promotion,
  finalize the aggregate note, merge only when authorized, and perform post-merge validation.
- Unrelated open ledger items remain independent and are not absorbed by this batch.
