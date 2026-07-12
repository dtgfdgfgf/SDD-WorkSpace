# Mainline Update Note: R1 Validation and Merge Enforcement

**Date**: 2026-07-13
**Source Branch**: `feature/wave-3-security-and-workflows`
**Target Branch**: `main`
**Status**: Ready
**Related Commits**: `e543f6a`, `f601685`
**Related PR**: https://github.com/dtgfdgfgf/SDD-WorkSpace/pull/3
**Reconciliation Status**: Closed

## Summary

- Repair false-green paths in the shared runtime audit and workflow registry validation.
- Add machine-enforced mainline-note state and branch-diff reconciliation gates.
- Retire the unused change-manifest surface while preserving commit-time impact advisories.
- Standardize the governed runtime on PowerShell 7, UTF-8 without BOM, and LF.
- Harden Governance CI and require its status check through a `main` branch ruleset.

## Why This Update Exists

R1 addresses the trust boundary identified by the 2026-07-12 governance review and repair ledger.
The local audit could previously lose warnings or report workflow-registry failures without failing,
and GitHub allowed direct pushes to `main`. The batch also replaces an unused change-manifest
surface with one branch-level reconciliation record that the merge CI can enforce.

## Scope

- R-A01 through R-A12, R-E05, R-E10, R-G06, R-H10, R-H16, R-H19, and R-I06.
- R-J01 includes both the local/CI wiring and remote activation: hosted validation must succeed
  before the active `main-governance` ruleset can close the finding.
- Completion of the account-side portion of R-J02 confirmed by the owner before R1 began.
- R-E09 history archaeology remains assigned to R5. Its 18 existing Ready/TBD notes are isolated
  by an explicit SHA-256 migration baseline and cannot use that exception after any content change.
- Workflow execution correctness, authorization, and fresh-fixture promotion remain R2, R3, and R6
  work. This batch does not promote the experimental workflow runtime.

## Affected Paths

| Path | Change |
|------|--------|
| `studio/scripts/powershell/check-speckit-runtime.ps1` and registry tools | Fail closed for missing dependencies, invalid registry/schema state, incomplete closure, and stale generated surfaces |
| `studio/scripts/powershell/validate-mainline-notes.ps1` | Validate note state, index parity, legacy hash baseline, aggregate routes, and reconciliation |
| `.github/workflows/governance.yml` | Pin dependencies/actions, add scheduled verification, coverage artifact, and PR merge gate |
| `studio/templates/sdd-docs/mainline-update-note-template.md` | Add rollback semantics and the authoritative impact-reconciliation table |
| `.gitattributes`, `.editorconfig`, `.gitignore` and project-init copies | Declare encoding, line-ending, editor, and narrow ignore policies |
| `.github/agents/` and `.claude/agents/` | Remove the retired manifest prompt and regenerate dependent Claude mirrors |
| `docs/mainline-updates/` and repair ledger | Reopen refuted Ready claims and record R1 completion evidence |

## Impact

- Missing modules, missing or invalid workflow registry documents, undeclared agents, stale mirrors,
  invalid Ready notes, and unresolved aggregate `must_update` routes now produce a nonzero result.
- Ordinary incremental commits retain advisory impact routing; the blocking reconciliation runs on
  the aggregate PR or mainline diff.
- Existing R5 note-accounting debt remains visible and hash-bound instead of being silently accepted
  or expanded during R1.
- GitHub `main` will require a PR and the `audit-and-tests` status check, with deletion and
  non-fast-forward updates blocked.

## Impact Reconciliation

`must_update` rows must use `updated` and point to concrete evidence. `reviewed-no-change` and
`deferred-owner-approved` are available only for non-`must_update` review records and do not close a
`must_update` route.

| Target | Impact | Disposition | Evidence |
|--------|--------|-------------|----------|
| `.claude/agents/*.md` | `must_update` | `updated` | Re-seeded all 15 dependent mirrors with the revised Analyze reconciliation prompt and UTF-8/LF writer. |
| `AGENTS.md` | `must_update` | `updated` | Re-synchronized the root adapter through `sync-agent-bootstrap.ps1`; a second comparison reported `CHANGED_COUNT=0`. |
| `CLAUDE.md` | `must_update` | `updated` | Re-synchronized the root adapter with LF and a final newline; bootstrap parity remained valid. |
| `.github/copilot-instructions.md` | `must_update` | `updated` | Re-synchronized the root adapter as the same atomic adapter set; bootstrap parity remained valid. |

## Validation

- Focused negative tests pass for missing module/state, invalid or permissive catalog/schema,
  schema-valid activation policy conflicts, undeclared agents, stale generated registry, invalid
  Ready/Merged evidence, hidden or malformed reconciliation, refreshed legacy-baseline bypass, and
  unresolved `must_update` targets.
- Full governance suite with Pester 5.7.1 and coverage: 320 passed, 0 failed, 0 skipped.
- Coverage baseline: Pester command coverage 0.71%; Cobertura line coverage 42/5,206 (0.81%).
  Most existing tests execute child `pwsh` processes or extracted anonymous ScriptBlocks, so the
  parent Pester process cannot attribute their executed lines to source files. Direct loading of the
  side-effect-free `common.ps1` makes the baseline nonzero; increasing cross-process attribution is
  a later test-architecture improvement, not a claim of high coverage in R1.
- Shared runtime audit: `VALID=true`, 0 errors, 0 warnings; mainline-note legacy migration baseline
  is explicitly reported as 18 hash-bound R5 entries.
- Adapter generator: root write completed, a second comparison returned `CHANGED_COUNT=0`, and all
  governed anchors remain present.
- Repository hygiene: no tracked governed text has BOM, CR, or a missing final LF; project-init
  outputs are LF/no-BOM and immediately sync-idempotent.
- `git diff --check`: passed.
- Hosted PR run `29209698022` succeeded on head `f601685`: runtime audit, aggregate
  reconciliation, 320 governance tests, and artifact upload all passed. An earlier clean-runner
  failure exposed a fixture that depended on this note remaining Draft; commit `f601685` makes the
  fixture force and assert `Ready + TBD + N/A` before testing the negative path.
- GitHub ruleset `18842326` (`main-governance`) is active for `~DEFAULT_BRANCH`, reports no bypass
  actor, and requires a PR plus strict `audit-and-tests` from integration `15368`. It also blocks
  branch deletion and non-fast-forward updates. Repository and branch-rule APIs report
  `main.protected=true` and all four rules active.
- The hosted run above established the check before ruleset activation. Every later PR head,
  including documentation-only closure commits, is blocked by GitHub until its own fresh
  `audit-and-tests` result succeeds; the live PR status is the canonical final-SHA evidence.

## Merge Notes

- Local implementation commit `e543f6a`, clean-runner fixture repair `f601685`, hosted validation,
  and remote ruleset evidence exist; R-J01 is operationally complete.
- PR #3 remains open for owner review. The active ruleset, rather than this note, is the
  authoritative enforcement point for the latest SHA; do not merge if GitHub reports its required
  check pending or failed.
- R-G06 and R-E05 must land atomically; neither the retired manifest surface nor the new merge gate
  is considered complete by itself.

## Follow-ups

- R2 through R6 remain governed by the repair inventory and update plan.
