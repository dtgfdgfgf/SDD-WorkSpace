# Mainline Update Note: RB-5 Agent, Authority, and Process Truthfulness

**Date**: 2026-07-20
**Source Branch**: `feature/wave-3-security-and-workflows`
**Target Branch**: `main`
**Status**: Draft
**Related Commits**: `78c47eb0f3da7e75f3ba79943ea44f55984677a1`, `26da9a7412d902f2dfff48df23d04662687f4a9d`
**Related PR**: https://github.com/dtgfdgfgf/SDD-WorkSpace/pull/3
**Reconciliation Status**: Open
**Validation Scope**: Batch

## Revalidation (2026-07-20, Post-Accounting)

The required post-accounting gates at committed head
`64669c43d531d9dd699d60e163e7b1c755d64963` refuted this note's `Ready` and `Closed`
status and the R-A22 closure claim. The full governance suite still reports 737 passed, 0 failed,
and 0 skipped, but the canonical runtime audit reports `VALID=false` with one
`historical-evidence-sealed-snapshot-mismatch`. The Batch gate reports 22 errors: the same sealed
snapshot blocker, 17 derived historical out-of-range errors, and four
`must-update-reconciliation-open` errors. The Aggregate gate reports 19 errors.

The confirmed immediate root cause is that `Read-ExactLegacyBaselineAtCommit` rejects the
production legacy baseline metadata shape, so `HISTORICAL_EVIDENCE_VALID=0`. This evidence
supersedes only the R-A22 completion and RB-5 Batch-readiness claims. R-D01, R-D04, R-D05, and
R-E07 remain `COMPLETED`; R-A22 returns to `IN_PROGRESS`, and R-E09 remains `IN_PROGRESS`.

Re-entry requires a discriminating repair for the production legacy baseline shape, a canonical
runtime audit with zero errors and zero warnings, the full governance suite at no less than the
737-test baseline, and a clean Batch gate. The four corrected `must_update` rows below remain
`pending` until that repaired final gate succeeds. R6 is not the next executable batch while this
RB-5 repair is open.

### Repair Implementation Evidence

The repair now requires the immutable framework parent to contain exactly the five production
legacy-baseline fields `schemaVersion`, `purpose`, `created`, `removalBatch`, and `entries`, with
fixed one-time metadata literals and the existing entry-path and blob-hash checks. It does not
accept the former two-field test shortcut or arbitrary metadata.

Six focused regression cases pass: the exact production shape is accepted, while the two-field
shape, a sixth field, a same-count field substitution, a wrong-type value, and a null value are
denied. The complete mainline-note validator file passes 91 of 91 tests. This note remains
`Draft` and `Open` until the repair is committed and the production runtime, Batch, and Aggregate
gates are rerun against that committed history.

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

The implementation commit closes the agent and self-application authority gaps, but the
post-accounting revalidation above proves that the historical evidence framework is not yet a
valid closure for R-A22. Historical note recovery remains separate from current branch
authorization: migrated historical commits cannot satisfy Batch or Aggregate readiness, path
coverage, or `must_update` reconciliation. The Wave-3 aggregate note stays Draft.

## Scope

In scope:

- R-D01, R-D04, and R-D05 agent-source, mirror-parity, and tool-mapping repair.
- R-E07 constitutional self-application boundary and synchronized adapter guidance.
- R-A22 one-time historical evidence migration controls.
- The historical portion of R-E09, including truth review of all 18 legacy Ready/TBD notes.

RB-5 disposition:

| ID | Status | RB-5 result |
|----|--------|-------------|
| R-D01 | COMPLETED | Specify preserves material unknowns for Clarify and no longer offers a direct Readiness handoff. |
| R-D04 | COMPLETED | Canonical audit verifies deterministic normalized Claude mirror content, including missing, extra, empty, and body-drift cases. |
| R-D05 | COMPLETED | Tool conversion uses explicit least-privilege mappings and fails before writes on malformed, unsupported, or permission-broadening input. |
| R-E07 | COMPLETED | Constitution 1.9.0 defines the shared-only workspace self-application entry and closure boundary without weakening project delivery. |
| R-A22 | IN_PROGRESS | The committed migration is not valid canonical evidence because the sealed snapshot cannot be reconstructed from the production legacy baseline metadata shape. |
| R-E09 | IN_PROGRESS | The 18-note truth review and file updates landed, but their canonical historical-evidence validation is blocked by R-A22; the Wave-3 Aggregate note and final merge accounting also remain open. |

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
- Historical notes are intended to become auditable debt records, but the current sealed snapshot
  is invalid and cannot prove current merge readiness.

## Impact Reconciliation

| Target | Impact | Disposition | Evidence |
|--------|--------|-------------|----------|
| `README.md` | `must_update` | `updated` | Commit `78c47eb0f3da7e75f3ba79943ea44f55984677a1` distinguishes seven-stage project delivery from the bounded workspace self-application route. |
| `studio/QUICKSTART.md` | `must_update` | `updated` | Commit `78c47eb0f3da7e75f3ba79943ea44f55984677a1` documents the entry and closure prerequisites and preserves the R6 boundary. |
| `studio/SDD-QUICKSTART-GUIDE.md` | `must_update` | `updated` | Commit `78c47eb0f3da7e75f3ba79943ea44f55984677a1` aligns the methodology guide with Constitution Section 2.1. |
| `.github/agents/*.agent.md` | `must_review` | `updated` | Specify contradictions and unsafe explicit tool declarations are removed at the canonical source in commit `78c47eb0f3da7e75f3ba79943ea44f55984677a1`. |
| `.claude/agents/*.md` | `must_update` | `pending` | Source-derived mirrors were regenerated in commit `78c47eb0f3da7e75f3ba79943ea44f55984677a1`; reconciliation remains open until the repaired final Batch gate succeeds. |
| `studio/templates/sdd-docs/*.md` | `must_review` | `updated` | The three runtime-adapter templates carry the Constitution 1.9.0 scoped self-application bootstrap. |
| `AGENTS.md` | `must_update` | `pending` | The Constitution 1.9.0 bootstrap was synchronized in commit `78c47eb0f3da7e75f3ba79943ea44f55984677a1`; reconciliation remains open until the repaired final Batch gate succeeds. |
| `CLAUDE.md` | `must_update` | `pending` | The Constitution 1.9.0 bootstrap was synchronized in commit `78c47eb0f3da7e75f3ba79943ea44f55984677a1`; reconciliation remains open until the repaired final Batch gate succeeds. |
| `.github/copilot-instructions.md` | `must_update` | `pending` | The generated bootstrap and workspace-only boundary were updated in commit `78c47eb0f3da7e75f3ba79943ea44f55984677a1`; reconciliation remains open until the repaired final Batch gate succeeds. |
| `studio/runtime/shared-runtime-contract.json` | `must_review` | `updated` | Revert-sensitive R-D01/R-D04/R-D05/R-E07/R-A22 invariants now include the exact five-field production baseline parser shape. |
| `studio/scripts/powershell/check-speckit-runtime.ps1` | `must_review` | `updated` | Canonical audit invokes normalized Claude parity and consumes the repaired mainline validator; no audit-script change is required. |
| `studio/scripts/powershell/validate-mainline-notes.ps1` | `must_review` | `updated` | The repair accepts only the exact production legacy metadata and retains entry-path, blob-hash, first-add, and first-seal checks. |
| `studio/tests/mainline-note-validation.Tests.ps1` | `must_review` | `updated` | Six focused metadata-shape cases and the full 91-test validator file pass before the repair commit. |
| `studio/constitution/constitution.md` | `maybe_review` | `updated` | Version 1.9.0 adds the evidence-equivalent, shared-only self-application route while retaining Aggregate and R6 obligations. |
| `studio/runtime/impact-registry.json` | `maybe_review` | `reviewed-no-change` | RB-5 changes no generated routing rule; the separate R-E04 authority-classification finding remains open. |
| `WORKSPACE_STRUCTURE.md` | `maybe_review` | `reviewed-no-change` | RB-5 changes governance semantics but no workspace path ownership or layout. |
| `.githooks/pre-commit.ps1` | `maybe_review` | `reviewed-no-change` | The hook already consumes the contract and staged audit; no hook implementation change was required for this batch. |

## Validation

- Specify and agent-authority negatives cover capped clarification markers, guessed material
  unknowns, direct Readiness handoff, missing or extra mirrors, empty or drifted mirror bodies,
  malformed frontmatter lists, unsupported tools, numeric tool values, and explicit permission
  broadening. The pre-batch implementation does not satisfy these closure assertions.
- Historical migration negatives cover schema violations, wrong types, nulls, additional
  properties, path aliases and duplicates, wrong immutable base, wrong commit roles, migration
  scope drift, dirty authority surfaces, record rewriting, missing Git context, and attempted use
  of historical hashes as current readiness evidence.
- `pwsh ./studio/scripts/powershell/run-governance-tests.ps1` reports 737 passed, 0 failed, and
  0 skipped.
- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json` currently reports
  `VALID=false` with one `historical-evidence-sealed-snapshot-mismatch`; this is the blocking
  canonical result even though the stored migration state is `sealed`.
- All 18 legacy notes were reviewed: 17 are `Merged` with reconciliation `Closed`; the disproven
  `2026-04-10-shared-layer-consistency-fix.md` remains `Draft` with reconciliation `Open`. Their
  stored records do not constitute valid current evidence while
  `HISTORICAL_EVIDENCE_VALID=0`.
- The legacy baseline file is removed after the sealed transition; historical references are
  excluded from Batch and Aggregate commit evidence, path coverage, and reconciliation.
- `git diff --check` passes.
- Batch acceptance uses
  `pwsh ./studio/scripts/powershell/validate-mainline-notes.ps1 -BaseRef
  de61431ae8f50d66f59157e00e4d239e9b37efdb -HeadRef HEAD -RequireReady
  -ReadinessScope Batch -Json`. At head
  `64669c43d531d9dd699d60e163e7b1c755d64963` it reports 22 errors and does not authorize
  Batch readiness.

## Merge Notes

- Draft status retains the implementation and migration evidence from
  `78c47eb0f3da7e75f3ba79943ea44f55984677a1` and sealed by
  `26da9a7412d902f2dfff48df23d04662687f4a9d`, but neither commit currently closes R-A22.
- RB-5 remains open and does not make the branch merge-ready.
- The aggregate Wave-3 note remains Draft, R-E09 remains `IN_PROGRESS`, and PR #3 remains
  `NOT READY TO MERGE`.
- `sdd-pipeline` remains experimental, default-disabled, and execution-denied. The R-A22 repair
  and repaired RB-5 final gates must precede R6.

## Follow-ups

- Repair R-A22's production legacy-baseline reconstruction and rerun the runtime, Pester, Batch,
  Aggregate, and diff-hygiene gates before advancing to R6.
- After RB-5 is truthfully Ready, R6 must run fresh-fixture seven-stage E2E, satisfy every minimum
  merge gate, decide promotion, finalize the aggregate note, merge only when authorized, and
  perform post-merge validation.
- Unrelated open ledger items remain independent and are not absorbed by this batch.
