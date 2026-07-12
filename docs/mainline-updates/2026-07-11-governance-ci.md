# Mainline Update Note: Governance CI (GitHub Actions)

**Date**: 2026-07-11
**Source Branch**: `feature/wave-3-security-and-workflows`
**Target Branch**: `main`
**Status**: Ready
**Related Commits**: `6e80ed0`
**Related PR**: N/A
**Reconciliation Status**: Closed

## Summary

- Add `.github/workflows/governance.yml`: a GitHub Actions workflow that runs the shared runtime
  audit (`check-speckit-runtime.ps1 -Json`) and the full governance Pester suite
  (`run-governance-tests.ps1`) on `windows-latest` for every push, pull request, and manual dispatch.
- Test results (`testResults.xml`) are uploaded as a build artifact on every run, including failures.

Supersession on 2026-07-13: R1 narrows push and PR triggers to `main`, adds a weekly schedule and
branch-reconciliation steps, pins Pester and powershell-yaml, uploads NUnit plus Cobertura artifacts,
and pins the Node 24 releases of checkout v7.0.0 and upload-artifact v7.0.1 by commit. The original
behavior below remains the historical scope of commit `6e80ed0`.

## Why This Update Exists

Until now every governance check ran only on the local machine (pre-commit hook or manual
invocation). This left two structural gaps, both documented in `studio/knowledge-base/learnings.md`:

1. Verification was self-referential: the LLM that produced a change also reported its
   verification. A stale `testResults.xml` carrying 23 failures sat unnoticed in the working tree
   for two months because no independent party ever re-ran the suite (learnings entry 2026-07-07
   to 07-08).
2. The 2026-04-12 audit named `--no-verify` as a single point of bypass with no compensating
   control. CI is that compensating control: it re-runs the same two machine-verifiable
   entrypoints outside anyone's hands, on every push.

CI adds no new rules and no new process constraints; it only re-executes the two existing
acceptance entrypoints (outcome verification, zero prompt-side cost), consistent with the
"gate over prompt" principle recorded in learnings.

## Scope

- CI workflow definition only. No change to constitution, contract, hooks, scripts, templates,
  agents, or prompts.
- Non-goals: caching PowerShell modules, matrix builds, non-Windows runners, publishing badges,
  branch protection rules (may follow later).

## Affected Paths

| Path | Change |
|------|--------|
| `.github/workflows/governance.yml` | New CI workflow: module install, runtime audit, Pester suite, artifact upload |
| `docs/mainline-updates/2026-07-11-governance-ci.md` | This note |
| `docs/mainline-updates/README.md` | Index entry |

## Impact

- Every push and PR now gets an independent green/red verdict from GitHub-hosted runners;
  a broken shared layer can no longer hide behind an unexamined local state.
- `exit $LASTEXITCODE` is propagated explicitly after each entrypoint, and both entrypoints were
  verified fail-loud before wiring (audit ends with `exit $exitCode`; test runner sets
  `$config.Run.Exit = $true`), per the negative-path lesson in learnings (gate must demonstrably
  fail, otherwise it is indistinguishable from a no-op).
- Windows runner billing applies on private repos (2x multiplier); a full run is expected to take
  roughly 4 to 6 minutes (module install + audit + 72s test suite).

## Validation

- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json` run locally on 2026-07-11:
  exit 0, `FAILURES: []`, `WARNINGS: []`.
- `pwsh ./studio/scripts/powershell/run-governance-tests.ps1` run locally on 2026-07-11:
  244 passed / 0 failed / 1 skipped.
- Workflow YAML parsed successfully with `powershell-yaml` `ConvertFrom-Yaml`.
- Fail-loud verification: both entrypoints exit non-zero on failure (static inspection of exit
  paths; Pester `Run.Exit = $true`).
- Change manifests: none required.
- First real acceptance happens on the first push to GitHub: the Actions run itself is the
  remaining unverified step and may surface runner-environment differences (module versions,
  missing local tools). Tool-availability probes in the audit are report-only and do not fail.

## Impact Reconciliation

The isolated initial-CI diff was compared with the current impact registry. It has no
`must_update` target: the workflow, its validation record, and the mainline-note index were updated
together. R1 subsequently hardens the same workflow and records that broader reconciliation in its
own note.

## Merge Notes

- Committed as `6e80ed0`; note flipped to Ready in the immediate follow-up commit (per the Status
  state machine and the self-violation lesson: a Ready note with TBD commits is invalid).
- No conflict risk expected: all paths are new files except the index.

## Follow-ups

- Completed in R1: add the status badge and coverage artifacts after hosted validation.
- Consider `Install-Module` caching if runner minutes become a concern.
- Completed in R1: active ruleset `18842326` requires PR plus strict `audit-and-tests` on `main`.
