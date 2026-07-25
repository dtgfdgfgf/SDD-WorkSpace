# Mainline Update Note: Owner Closure Baseline and Delivery-Surface Calibration

**Date**: 2026-07-26
**Source Branch**: `feature/wave-3-security-and-workflows`
**Target Branch**: `main`
**Status**: Draft
**Related Commits**: Section 38 plan `f428029467f3ba214ee6eef1eb6b4d5983f28aed`; R-A23 registration `3393d9bb5784d9a4e0a2812bde2efbc264b31446`; fixture repair `f8d064c81b592e1c42966a68db6325f1685db089`; CI calibration `742a7fba7cbf088195211f0e35432c4734858b78`; README truthfulness `TBD`
**Related PR**: https://github.com/dtgfdgfgf/SDD-WorkSpace/pull/3
**Reconciliation Status**: Open
**Validation Scope**: Batch

## Summary

- Record the owner closure baseline fixed on 2026-07-26: establishing the workspace environment
  is the goal, the end-to-end dogfood demo feature and interview-facing packaging are excluded,
  `projects/` and `learning/` stay frozen, and terminal acceptance is conditional
  (0 `OPEN`, 0 `DECIDED`, 0 `IN_PROGRESS` with valid history), not a fixed numeric fold.
- Register new Medium R-A23 in append-only ledger revision 10 after the elevated fixture failure
  reproduced in a directly executed canonical pwsh 7.5.4 terminal whose console code page is 950.
- Authorize the bounded delivery-surface calibration batch of wave-3 plan Section 38: the
  conditional fixture decoding repair, CI timeout and coverage calibration, and a closed-list
  README truthfulness repair, with slow gates moved before finalization and a hard cap of two
  finalization re-entries.

## Why This Update Exists

Four consecutive R6-A6 finalize-and-demote cycles between 2026-07-23 and 2026-07-24 showed that
the failures were in the acceptance tooling and environment, not in the repairs: missing commit
coverage, a bounded tool timeout, a sandbox-denied CIM call, and finally a real fixture defect.
Section 38 of the wave-3 remediation plan records the owner closure baseline, moves the slow and
environment-sensitive gates onto the Draft accounting-candidate tree before finalization, machine
limits the finalization diff to note and index files, caps re-entries at two, and separates the
push, merge and post-merge accounting authorization nodes.

The canonical reproduction then proved the fixture defect is real rather than a sandbox artifact:
`Invoke-RuntimeAuditFixture` decodes captured child-audit stdout with the parent console encoding
while the child pwsh writes UTF-8. On a CP950 host, non-ASCII contract text corrupts and one
corrupted sequence yields an unescaped quote that makes the captured JSON unparseable, failing an
otherwise-correct bad-state test. Ledger revision 10 registers this as Medium R-A23 before any
code repair, per the Section 38 authorization.

## Scope

In scope:

- The Section 38 plan-only amendment and this dedicated Batch note.
- Ledger revision 10 registering R-A23 as `OPEN`, with the dependent `docs/README.md` index row
  advanced in the same commit.
- Conditional R-A23 repair limited to `studio/tests/check-speckit-runtime.Tests.ps1` with an
  old-fails/new-passes discriminating test.
- `.github/workflows/governance.yml` timeout and coverage calibration that does not touch any
  contract-pinned line and does not expand `mustContainAll` assertions.
- A closed-list `README.md` truthfulness repair for the consumer-directory description and badge
  wording, without changing any `docInvariant` anchor string.

Out of scope:

- `projects/` and `learning/`, including the 2026-07-22 agent-mirror sync residue in nested
  consumer worktrees.
- Workflow promotion, upstream alignment, reopening any `DISPOSITIONED` finding without its
  trigger, adapter or bootstrap-generator changes, and interview-facing packaging.
- Push, merge, force-push, history rewrite, PR-thread resolution and post-merge accounting,
  which require the separate owner authorization nodes defined in Section 38.

## Affected Paths

| Path | Change |
|------|--------|
| `docs/sdd-workspace-wave-3-remediation-plan-2026-07-14_zhTW.md` | Section 38 amendment (version 1.32.0) |
| `docs/sdd-workspace-repair-inventory-and-update-plan-2026-07-12_zhTW.md` | Section 47 and revision 10 (version 1.38.0) |
| `docs/README.md` | Finding-status index row advanced to revision 10 |
| `docs/mainline-updates/README.md` | Index row for this note |
| `studio/tests/check-speckit-runtime.Tests.ps1` | Fixture decoding repair, discriminating test and CI-calibration revert anchor |
| `.github/workflows/governance.yml` | Timeout raised to 120 minutes; coverage limited to schedule and dispatch |
| `README.md` | Consumer-directory truthfulness disclosure (untracked directories, absent from a public clone) |

## Impact

- The ledger fold becomes 95 `COMPLETED` / 2 `OPEN` / 0 `DECIDED` / 1 `IN_PROGRESS` /
  35 `DISPOSITIONED` across 133 findings; R-A23 is the only newly opened item.
- The impact registry has no change-type route for `.github/workflows/`, so the planned CI
  calibration is disclosed here explicitly instead of through machine routing.
- R-E09 remains `IN_PROGRESS` and R-J03 remains `OPEN`; both close only through real merge and
  post-merge evidence under the separate owner authorization nodes.

## Impact Reconciliation

| Target | Impact | Disposition | Evidence |
|--------|--------|-------------|----------|
| `docs/README.md` | `must_update` | `updated` | Finding-status index row advanced to `revision=10; ledgerVersion=1.38.0; inventoryCount=133` in the registration commit |
| `README.md` | `must_update` | `updated` | Consumer-directory disclosure replaced the misleading line-7 claim; a revert-sensitive Pester assertion guards the disclosure and rejects the old wording |
| `studio/QUICKSTART.md` | `must_review` | `pending` | Review at finalization; no planned change |
| `studio/SDD-QUICKSTART-GUIDE.md` | `must_review` | `pending` | Review at finalization; no planned change |

## Validation

- Discriminating R-A23 evidence: the new test
  `preserves non-ASCII child audit output when the parent console uses code page 950` fails
  against the pre-repair helper grafted into a clean worktree at the registration commit and
  passes against the repaired helper; the previously failing bad-state test and the
  `-WithoutYamlModule` branch both pass with the repaired helper.
- `git diff --check`
- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json`
- `pwsh ./studio/scripts/powershell/validate-finding-status-ledger.ps1 -BaseRef <batch-base> -HeadRef <head> -Json`
- Planned before finalization, per Section 38 gate order: the official complete governance suite
  in a canonical environment on the Draft accounting-candidate tree, then
  `pwsh ./studio/scripts/powershell/validate-mainline-notes.ps1 -BaseRef <batch-base> -HeadRef <head> -RequireReady -ReadinessScope Batch -Json`.

## Merge Notes

- Draft. This note may become Ready only after every landed Section 38 item has a real commit
  hash and the pre-finalization gates pass on the accounting-candidate tree.
- Ready grants no push or merge authority. Push with PR update, merge, and post-merge accounting
  each require a separate explicit owner instruction under Section 38.

## Follow-ups

- Aggregate finalization of the Wave-3 umbrella under the Section 38 gate order, with at most two
  re-entries before mandatory stop and owner re-scoping.
- Post-merge protocol: ledger revision closing R-E09 and R-J03 plus a dedicated Ready note in the
  same push to `main`, then one full-suite scheduled or dispatched run on `main`.
