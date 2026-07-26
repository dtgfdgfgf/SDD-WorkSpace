# Mainline Update Note: Owner Closure Baseline and Delivery-Surface Calibration

**Date**: 2026-07-26
**Source Branch**: `feature/wave-3-security-and-workflows`
**Target Branch**: `main`
**Status**: Draft
**Related Commits**: Section 38 plan `f428029467f3ba214ee6eef1eb6b4d5983f28aed`; R-A23 registration `3393d9bb5784d9a4e0a2812bde2efbc264b31446`; fixture repair `f8d064c81b592e1c42966a68db6325f1685db089`; CI calibration `742a7fba7cbf088195211f0e35432c4734858b78`; README truthfulness `b63dff89fda341c3d291e48a57403458d5033deb`; R-A23 completion accounting `00424901aa315d708c88c763ca77f52db3b981e5`; finalization `758d1699f4742ef781d36d1f14753f23e9705dc7`; honesty demotion `132a1139467592d19f978c07a0f0bec52afcf9be`; R-A24 plan amendment `43b90622c2b39eeac20d9f00c7ab79a9fe72b25e`; R-A24 registration `7fa4845c5c697f78e3810d4c644e0123e17d5f03`; R-A24 repair `TBD`
**Related PR**: https://github.com/dtgfdgfgf/SDD-WorkSpace/pull/3
**Reconciliation Status**: Open
**Validation Scope**: Batch

## Consumer-Path Dependency Honesty Demotion (2026-07-26)

GitHub Actions run `30199620889` evaluated finalization
`758d1699f4742ef781d36d1f14753f23e9705dc7` on pull request #3 and reported 988 passed with 1
failed in 3077 seconds. Both delivery-surface calibrations from this batch behaved as intended:
the run finished well inside the calibrated 120-minute timeout, the coverage step was correctly
skipped for a pull request, and the Aggregate mainline-note reconciliation step succeeded on the
runner.

The single failure is a real shared-layer defect that this batch did not introduce but must now
address, because it made every prior local acceptance of the suite a false green.
`studio/tests/check-speckit-runtime.Tests.ps1` requires nine consumer-space files under
`learning/` and `projects/` to exist before exercising the R-G01 fixture, yet those directories
are gitignored and absent from any fresh clone.

This note and the Wave-3 umbrella return to Draft/Open with their index rows. This consumes the
first of the two finalization re-entries permitted by plan Section 38.

Plan amendment `43b90622c2b39eeac20d9f00c7ab79a9fe72b25e` adds Section 39, which authorizes new
Medium finding R-A24 and bounds the repair to removing the consumer-space existence precondition
while preserving the genuine R-G01 revert-sensitive fixture body, plus a consumer-space
independence guard in `studio/tests/repository-hygiene.Tests.ps1`. Ledger revision 12 registers
R-A24 as `OPEN` before any code change, raising the inventory to 134 with severity 8/32/55/39 and
fold 96 `COMPLETED` / 2 `OPEN` / 0 `DECIDED` / 1 `IN_PROGRESS` / 35 `DISPOSITIONED`. Because a
clean checkout is the condition that exposed this defect, Section 39 requires independent GitHub
Actions success on the pull request before any merge; a local suite alone is not sufficient
evidence for this re-entry.

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
- Ledger revision 10 registering R-A23 as `OPEN` and revision 11 recording it as `COMPLETED`,
  with the dependent `docs/README.md` index row advanced in the same commit as each revision.
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
| `docs/sdd-workspace-repair-inventory-and-update-plan-2026-07-12_zhTW.md` | Sections 47 and 48, revisions 10 and 11 (version 1.39.0) |
| `docs/README.md` | Finding-status index row advanced to revision 11 |
| `docs/mainline-updates/README.md` | Index row for this note |
| `studio/tests/check-speckit-runtime.Tests.ps1` | Fixture decoding repair, discriminating test and CI-calibration revert anchor |
| `.github/workflows/governance.yml` | Timeout raised to 120 minutes; coverage limited to schedule and dispatch |
| `README.md` | Consumer-directory truthfulness disclosure (untracked directories, absent from a public clone) |

## Impact

- R-A23 is the only finding this batch opens, and it closes inside the same batch. Revision 10
  registers it as `OPEN` at fold 95 / 2 / 0 / 1 / 35, and revision 11 records it as `COMPLETED`,
  leaving the batch terminal fold at 96 `COMPLETED` / 1 `OPEN` / 0 `DECIDED` / 1 `IN_PROGRESS` /
  35 `DISPOSITIONED` across 133 findings.
- The impact registry has no change-type route for `.github/workflows/`, so the CI calibration is
  disclosed here explicitly instead of through machine routing.
- R-E09 remains `IN_PROGRESS` and R-J03 remains `OPEN`; both close only through real merge and
  post-merge evidence under the separate owner authorization nodes.

## Impact Reconciliation

| Target | Impact | Disposition | Evidence |
|--------|--------|-------------|----------|
| `docs/README.md` | `must_update` | `updated` | Finding-status index row advanced to `revision=11; ledgerVersion=1.39.0; inventoryCount=133` in accounting commit `00424901aa315d708c88c763ca77f52db3b981e5` |
| `README.md` | `must_update` | `updated` | Consumer-directory disclosure replaced the misleading line-7 claim; a revert-sensitive Pester assertion guards the disclosure and rejects the old wording |
| `studio/QUICKSTART.md` | `must_review` | `reviewed-no-change` | Reviewed on the accounting candidate: no governed statement about CI gating or consumer-directory tracking changes; consumer-space descriptions remain accurate |
| `studio/SDD-QUICKSTART-GUIDE.md` | `must_review` | `reviewed-no-change` | Reviewed on the accounting candidate: no governed statement about CI gating or consumer-directory tracking changes; consumer-space descriptions remain accurate |

## Validation

- Discriminating R-A23 evidence: the new test
  `preserves non-ASCII child audit output when the parent console uses code page 950` fails
  against the pre-repair helper grafted into a clean worktree at the registration commit and
  passes against the repaired helper; the previously failing bad-state test and the
  `-WithoutYamlModule` branch both pass with the repaired helper.
Pre-finalization evidence, executed on accounting candidate
`d9b09160ad9ce23f2a47ad43e74bab4e2b840e8d` per Section 38 gate order item 1:

| Gate | Result |
|---|---|
| Official complete suite, canonical pwsh 7.5.4 terminal, no coverage | 989 total, 0 failures, 0 errors, 0 skipped, 0 inconclusive, 0 not-run in 2644.9 seconds, with a complete NUnit report emitted |
| Suite command exit code | Not captured separately. `run-governance-tests.ps1` sets Pester `Run.Exit = $true`, so a zero-failure run exits 0; this is an inference from the recorded counts, not an observed value |
| Suite tree identity | The report records `date="2026-07-26" time="05:49:24"`, which postdates the final batch commit at 05:36:56, and the owner attests a clean worktree throughout. This is a time-window plus attestation identity, not a hash-pinned exact-tree proof |
| Batch assertions in the emitted report | R-A23 decoding test, CI coverage-split assertion and README disclosure assertion all present |
| Canonical runtime audit | `VALID=true`, 0 errors, 0 warnings |
| Finding-status ledger | Revision 11, 133 findings, fold 96/1/0/1/35, schema and index consistent |

The R-A23 repair, the CI calibration and the README disclosure each carry a discriminating or
revert-sensitive assertion inside that suite, so reverting any one of them fails the suite.

The following gates belong to Section 38 gate order item 3 and run only after the finalization
commit exists. They had not been executed when this note was written:

- `git diff --check` and clean-worktree verification
- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json`
- `pwsh ./studio/scripts/powershell/validate-finding-status-ledger.ps1 -BaseRef <batch-base> -HeadRef <finalization-commit> -Json`, which supplies the append-only history comparison
- `pwsh ./studio/scripts/powershell/validate-mainline-notes.ps1 -BaseRef main -HeadRef <finalization-commit> -RequireReady -ReadinessScope Batch -Json`
- `pwsh ./studio/scripts/powershell/validate-mainline-notes.ps1 -BaseRef main -HeadRef <finalization-commit> -RequireReady -ReadinessScope Aggregate -Json`

Both readiness gates use `-BaseRef main`, matching the precedent in plan Sections 35 and 36. A
narrower base would place this batch's own entry-plan commit outside the evaluated range and
produce a spurious `commit-evidence-out-of-range` failure.

## Merge Notes

- Ready/Closed. Every landed Section 38 item has a real commit hash, and the gate order item 1
  suite evidence recorded under Validation was produced on accounting candidate
  `d9b09160ad9ce23f2a47ad43e74bab4e2b840e8d`. The item 3 fast gates run after this commit.
- Ready grants no push or merge authority. Push with PR update, merge, and post-merge accounting
  each require a separate explicit owner instruction under Section 38. Work stops at the
  Section 34 merge-authorization checkpoint.
- Any post-finalization gate deviation returns this note and its index row to Draft/Open;
  Section 38 permits at most two such re-entries before the work halts for owner re-scoping.

## Follow-ups

- Aggregate finalization of the Wave-3 umbrella landed in this same note-only change. The
  remaining pre-merge work is the Section 38 gate order item 3 fast-gate set listed under
  Validation, followed by the Section 34 merge-authorization decision.
- The calibrated `governance.yml` has never executed on GitHub Actions. The branch is unpushed,
  so the 120-minute timeout is calibrated only against the local 2644.9-second measurement. Live
  CI calibration, capped at two iterations by Section 38 item 4, remains outstanding.
- Observation for a future dated amendment, not repaired here:
  `studio/scripts/powershell/validate-mainline-notes.ps1` decodes `git show` output through the
  host console encoding, the same coupling class as R-A23. On a non-UTF-8 console it cannot parse
  the non-ASCII runtime contract and reports a spurious
  `historical-evidence-sealed-snapshot-mismatch` that cascades into `commit-evidence-out-of-range`
  for every sealed historical note. Operators must force a UTF-8 console before running the
  readiness gates until this is repaired under its own finding ID.
- Post-merge protocol: ledger revision closing R-E09 and R-J03 plus a dedicated Ready note in the
  same push to `main`, then one full-suite scheduled or dispatched run on `main`.
