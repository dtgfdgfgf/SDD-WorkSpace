# Mainline Update Note: RB-5 Agent, Authority, and Process Truthfulness

**Date**: 2026-07-20
**Source Branch**: `feature/wave-3-security-and-workflows`
**Target Branch**: `main`
**Status**: Ready
**Related Commits**: `78c47eb0f3da7e75f3ba79943ea44f55984677a1`, `26da9a7412d902f2dfff48df23d04662687f4a9d`, `3666c4e9a6553ff82774d4a06037f48846d8b0fd`
**Related PR**: https://github.com/dtgfdgfgf/SDD-WorkSpace/pull/3
**Reconciliation Status**: Closed
**Validation Scope**: Batch

## Revalidation (2026-07-20, Post-Accounting)

The required post-accounting gates at committed head
`64669c43d531d9dd699d60e163e7b1c755d64963` refuted this note's `Ready` and `Closed`
status and the R-A22 closure claim. The full governance suite still reports 737 passed, 0 failed,
and 0 skipped, but the canonical runtime audit reports `VALID=false` with one
`historical-evidence-sealed-snapshot-mismatch`. The Batch gate reports 22 errors: the same sealed
snapshot blocker, 17 derived historical out-of-range errors, and four
`must-update-reconciliation-open` errors. The Aggregate gate reports 19 errors.

The confirmed immediate root cause at that head was that `Read-ExactLegacyBaselineAtCommit`
rejected the production legacy baseline metadata shape, so `HISTORICAL_EVIDENCE_VALID=0`. That
evidence superseded only the R-A22 completion and RB-5 Batch-readiness claims. R-D01, R-D04,
R-D05, and R-E07 remained `COMPLETED`; R-A22 returned to `IN_PROGRESS`, and R-E09 remained
`IN_PROGRESS`.

Re-entry at that point required a discriminating repair for the production legacy baseline shape,
a canonical runtime audit with zero errors and zero warnings, the full governance suite at no less
than the 737-test baseline, and a clean Batch gate. The four corrected `must_update` rows below
were kept `pending` until the repaired final gate could succeed. R6 was not the next executable
batch while that RB-5 repair was open.

### Repair Implementation Evidence

The repair now requires the immutable framework parent to contain exactly the five production
legacy-baseline fields `schemaVersion`, `purpose`, `created`, `removalBatch`, and `entries`, with
fixed one-time metadata literals and the existing entry-path and blob-hash checks. It does not
accept the former two-field test shortcut or arbitrary metadata.

Six focused regression cases passed before the repair commit: the exact production shape was
accepted, while the two-field shape, a sixth field, a same-count field substitution, a wrong-type
value, and a null value were denied. The complete mainline-note validator file passed 91 of 91
tests. At that point, this note remained `Draft` and `Open` until the repair could be committed and
the production gates rerun against that committed history.

### Repair Closure Superseding the Revalidation

Repair commit `3666c4e9a6553ff82774d4a06037f48846d8b0fd` commits the exact
five-field production-shape enforcement described above. Its committed runtime audit reports
`VALID=true`, 0 errors, and 0 warnings, with historical sealed evidence valid for 18 of 18
records. The dedicated mainline-note validator file passes 91 of 91 tests.

The discriminating metadata matrix accepts the exact production baseline and denies
`TwoField`, `ExtraField`, `SubstitutedField`, `WrongType`, and `Null`. Reverting to the former
`Count=2` shortcut is also rejected by the shared runtime contract anchor. These results supersede
the R-A22 `IN_PROGRESS` conclusion in the post-accounting revalidation without erasing that
historical refutation.

A post-repair diagnostic Batch run already reports historical evidence valid for 18 of 18 records
with no sealed-snapshot mismatch. Its 33 errors are limited to the note still being `Draft` at
diagnostic time and the resulting coverage, not-ready, and reconciliation-missing derivatives.
At that diagnostic point, the final full governance suite, Batch gate, and Aggregate gate still
had to be rerun after the accounting edits; this historical subsection did not pre-claim those
results.

### Final Accounting Validation Superseding the Pending-Gate Statements

The required final validation was completed at committed head
`44f768a12316cdb008f1fee263e03ed7ce9a8191` after the accounting edits:

| Validation surface | Observed result |
|---|---|
| Full governance suite | 742 passed, 0 failed, 0 skipped in 1115.2 seconds |
| Canonical runtime audit | `VALID=true`, 0 errors, 0 warnings |
| Historical sealed evidence | 18 of 18 records valid |
| Batch gate | BaseRef `de61431ae8f50d66f59157e00e4d239e9b37efdb`; `VALID=true`, 0 errors, 0 warnings |
| Aggregate gate | Expected nonzero result with exactly one `aggregate-note-not-ready` for `docs/mainline-updates/2026-05-05-studio-workflows-runtime.md` |
| Diff and worktree hygiene | `git diff --check` passed and the worktree was clean |

These observed results supersede only the pending-gate statements in the preceding repair
chronology. They preserve the post-accounting refutation, confirm RB-5 as `Ready`, `Closed`, and
`Batch`, and keep R-A22 `COMPLETED`. R-E09 remains `IN_PROGRESS`; the Wave-3 umbrella note remains
`Draft`, `TBD`, `Open`, and `Aggregate`. The result does not authorize workflow promotion or merge.
R6 is the next remediation batch, and `sdd-pipeline` remains experimental, default-disabled, and
execution-denied.

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

The implementation commit closes the agent and self-application authority gaps. The
post-accounting revalidation above truthfully recorded the historical evidence defect at that
time; repair commit `3666c4e9a6553ff82774d4a06037f48846d8b0fd` now supplies the
superseding closure for R-A22. Historical note recovery remains separate from current branch
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
| R-A22 | COMPLETED | Repair commit `3666c4e9a6553ff82774d4a06037f48846d8b0fd` enforces the exact five-field production baseline shape; committed audit reports 18 of 18 historical records valid. |
| R-E09 | IN_PROGRESS | The 18-note historical portion is complete; the Wave-3 Aggregate note, R6 evidence, and final merge accounting remain open. |

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
- Historical notes are auditable debt records under the repaired sealed snapshot, but their
  historical commits remain excluded from current Batch or Aggregate authorization.

## Impact Reconciliation

| Target | Impact | Disposition | Evidence |
|--------|--------|-------------|----------|
| `README.md` | `must_update` | `updated` | Commit `78c47eb0f3da7e75f3ba79943ea44f55984677a1` distinguishes seven-stage project delivery from the bounded workspace self-application route. |
| `studio/QUICKSTART.md` | `must_update` | `updated` | Commit `78c47eb0f3da7e75f3ba79943ea44f55984677a1` documents the entry and closure prerequisites and preserves the R6 boundary. |
| `studio/SDD-QUICKSTART-GUIDE.md` | `must_update` | `updated` | Commit `78c47eb0f3da7e75f3ba79943ea44f55984677a1` aligns the methodology guide with Constitution Section 2.1. |
| `.github/agents/*.agent.md` | `must_review` | `updated` | Specify contradictions and unsafe explicit tool declarations are removed at the canonical source in commit `78c47eb0f3da7e75f3ba79943ea44f55984677a1`. |
| `.claude/agents/*.md` | `must_update` | `updated` | Source-derived mirrors were regenerated in commit `78c47eb0f3da7e75f3ba79943ea44f55984677a1`; deterministic parity is part of the canonical audit. |
| `studio/templates/sdd-docs/*.md` | `must_review` | `updated` | The three runtime-adapter templates carry the Constitution 1.9.0 scoped self-application bootstrap. |
| `AGENTS.md` | `must_update` | `updated` | The Constitution 1.9.0 bootstrap was synchronized in commit `78c47eb0f3da7e75f3ba79943ea44f55984677a1`. |
| `CLAUDE.md` | `must_update` | `updated` | The Constitution 1.9.0 bootstrap was synchronized in commit `78c47eb0f3da7e75f3ba79943ea44f55984677a1`. |
| `.github/copilot-instructions.md` | `must_update` | `updated` | The generated bootstrap and workspace-only boundary were updated in commit `78c47eb0f3da7e75f3ba79943ea44f55984677a1`. |
| `studio/runtime/shared-runtime-contract.json` | `must_review` | `updated` | Revert-sensitive R-D01/R-D04/R-D05/R-E07/R-A22 invariants now include the exact five-field production baseline parser shape. |
| `studio/scripts/powershell/check-speckit-runtime.ps1` | `must_review` | `updated` | Canonical audit invokes normalized Claude parity and consumes the repaired mainline validator; no audit-script change is required. |
| `studio/scripts/powershell/validate-mainline-notes.ps1` | `must_review` | `updated` | The repair accepts only the exact production legacy metadata and retains entry-path, blob-hash, first-add, and first-seal checks. |
| `studio/tests/mainline-note-validation.Tests.ps1` | `must_review` | `updated` | The committed repair's production-positive plus five negative metadata-shape cases and the full 91-test validator file pass. |
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
- The last complete pre-repair accounting suite reported 737 passed, 0 failed, and 0 skipped.
  Final accounting validation at
  `44f768a12316cdb008f1fee263e03ed7ce9a8191` reports 742 passed, 0 failed, and
  0 skipped in 1115.2 seconds.
- On committed repair `3666c4e9a6553ff82774d4a06037f48846d8b0fd`,
  `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json` reports `VALID=true`,
  0 errors, and 0 warnings.
- The dedicated `mainline-note-validation.Tests.ps1` file reports 91 passed and 0 failed. Its
  production-shape matrix accepts the canonical five-field baseline and denies `TwoField`,
  `ExtraField`, `SubstitutedField`, `WrongType`, and `Null`.
- All 18 legacy notes were reviewed and the committed audit validates 18 of 18 sealed records:
  17 notes are `Merged` with reconciliation `Closed`; the disproven
  `2026-04-10-shared-layer-consistency-fix.md` remains `Draft` with reconciliation `Open`.
- The legacy baseline file is removed after the sealed transition; historical references are
  excluded from Batch and Aggregate commit evidence, path coverage, and reconciliation.
- `git diff --check` passes.
- Batch acceptance uses
  `pwsh ./studio/scripts/powershell/validate-mainline-notes.ps1 -BaseRef
  de61431ae8f50d66f59157e00e4d239e9b37efdb -HeadRef HEAD -RequireReady
  -ReadinessScope Batch -Json`. At validated head
  `44f768a12316cdb008f1fee263e03ed7ce9a8191`, it reports `VALID=true`, 0 errors,
  and 0 warnings with 18 of 18 historical records valid.

## Merge Notes

- Ready status covers the coherent RB-5 Batch implemented by
  `78c47eb0f3da7e75f3ba79943ea44f55984677a1`, migrated by
  `26da9a7412d902f2dfff48df23d04662687f4a9d`, and repaired by
  `3666c4e9a6553ff82774d4a06037f48846d8b0fd`.
- RB-5 is completed but does not make the branch merge-ready.
- The aggregate Wave-3 note remains Draft, R-E09 remains `IN_PROGRESS`, and PR #3 remains
  `NOT READY TO MERGE`.
- `sdd-pipeline` remains experimental, default-disabled, and execution-denied. R6 is the next
  remediation batch.

## Follow-ups

- Any change after validated head `44f768a12316cdb008f1fee263e03ed7ce9a8191` must
  rerun the applicable governance gates before reasserting the recorded result.
- R6 must then run fresh-fixture seven-stage E2E, satisfy every minimum merge gate, decide
  promotion, finalize the aggregate note, merge only when authorized, and perform post-merge
  validation.
- Unrelated open ledger items remain independent and are not absorbed by this batch.
