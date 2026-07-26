# Mainline Update Note: Wave-3 Post-Merge Closure

**Date**: 2026-07-26
**Source Branch**: `chore/post-merge-accounting`
**Target Branch**: `main`
**Status**: Draft
**Related Commits**: `TBD`
**Related PR**: `TBD`
**Reconciliation Status**: Open
**Validation Scope**: Batch

## Summary

- Close R-E09 and R-J03, the two terminal merge items, against the real merge of pull request #3
  into `main` as merge commit `db97cfdd7efea007f90515e67af6d55f734d19b5`.
- Record ledger revision 14, which leaves the fold at 99 `COMPLETED` / 0 `OPEN` / 0 `DECIDED` /
  0 `IN_PROGRESS` / 35 `DISPOSITIONED` across 134 findings.
- Record that this accounting reaches `main` through its own pull request because the
  `main-governance` ruleset forbids the direct push shape described in remediation-plan
  Section 38.

## Why This Update Exists

R-E09 and R-J03 were deliberately designed so that no branch-local work could close them. R-E09
required real merge accounting rather than a self-declared claim, and R-J03 required `main` itself
to carry the converged shared layer. Both conditions are now satisfied by evidence that neither
the workstation nor the assistant sandbox could manufacture.

Merge commit `db97cfdd7efea007f90515e67af6d55f734d19b5` has two parents,
`c6ee1f1fcf2eda0b517e1e8d1518d0332563ffb6` and `017cfa6ce698a26dde84548c52674f894446aab8`, so the
campaign history is preserved rather than squashed. `main` advanced from its 2026-05-04 state to
the merged tree, and the governance workflow now runs on `main` instead of only on a feature
branch.

Pull-request run `30203491921` reported 991 passed with zero non-pass results, and the subsequent
merged-`main` push run `30205330383` reported the same counts while also passing the Aggregate
mainline-note reconciliation on the merged tree.

## Scope

In scope:

- Ledger revision 14 closing exactly R-E09 and R-J03, with the dependent `docs/README.md` index
  row advanced in the same commit.
- This dedicated note and its `docs/mainline-updates/README.md` index row.

Out of scope:

- Any runtime, agent, prompt, template, hook, script or workflow change.
- Reopening or altering any `DISPOSITIONED` finding.
- `projects/` and `learning/`, which remain frozen consumer spaces.
- Workflow promotion. `sdd-pipeline` remains experimental, default-disabled and execution-denied.

## Affected Paths

| Path | Change |
|------|--------|
| `docs/sdd-workspace-repair-inventory-and-update-plan-2026-07-12_zhTW.md` | Section 51 and revision 14 (version 1.42.0) |
| `docs/README.md` | Finding-status index row advanced to revision 14 |
| `docs/mainline-updates/2026-07-26-wave-3-post-merge-closure.md` | This note |
| `docs/mainline-updates/README.md` | Index row for this note |

## Impact

- No finding remains `OPEN`, `DECIDED` or `IN_PROGRESS`. The 35 `DISPOSITIONED` items stay
  conditionally deferred under their exact machine-validated re-entry triggers, which is a
  deferral and not an implementation or risk-acceptance claim.
- Wave-3 is closed. No further shared-layer batch starts from the wave-3 remediation plan; later
  work enters only through a `DISPOSITIONED` re-entry trigger or a new owner-authorized plan.

## Impact Reconciliation

| Target | Impact | Disposition | Evidence |
|--------|--------|-------------|----------|
| `docs/README.md` | `must_update` | `updated` | Finding-status index row advanced to `revision=14; ledgerVersion=1.42.0; statusCounts=COMPLETED:99,OPEN:0,DECIDED:0,IN_PROGRESS:0,DISPOSITIONED:35` in the accounting commit of this batch |

## Validation

- `git diff --check`
- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json`
- `pwsh ./studio/scripts/powershell/validate-finding-status-ledger.ps1 -BaseRef <merge-commit> -HeadRef <head> -Json`
- `pwsh ./studio/scripts/powershell/validate-mainline-notes.ps1 -BaseRef main -HeadRef <head> -RequireReady -ReadinessScope Batch -Json`
- Independent GitHub Actions evidence already recorded above: pull-request run `30203491921` and
  merged-`main` push run `30205330383`, each 991 passed with zero non-pass results.
- Outstanding after this batch merges: one `workflow_dispatch` full-suite run on `main`, which
  also exercises the coverage step that no run has executed since the calibration.

## Merge Notes

- This accounting travels through its own pull request. The `main-governance` ruleset `18842326`
  requires a pull request with a strict `audit-and-tests` check and permits no bypass actor, so
  the direct-push shape described in remediation-plan Section 38 is not executable. Routing the
  accounting through a pull request satisfies the same intent more strictly, because both the
  pull-request gate and the subsequent `main` push gate evaluate it.
- Honouring the enforced protection rather than working around it is the correct reading of R-J01.

## Follow-ups

- One `workflow_dispatch` full-suite run on `main` to complete the Section 38 post-merge
  acceptance and to exercise the coverage path for the first time since calibration.
- `studio/scripts/powershell/validate-mainline-notes.ps1` decodes `git show` output through the
  host console encoding, the same coupling class as R-A23. It does not manifest on GitHub-hosted
  runners but does on a non-UTF-8 local console. This remains recorded for a future dated
  amendment under its own finding ID.
