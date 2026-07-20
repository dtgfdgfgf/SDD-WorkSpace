# Mainline Update Note: RB-4 Extension, Consumer, and Upgrade Boundaries

**Date**: 2026-07-20
**Source Branch**: `feature/wave-3-security-and-workflows`
**Target Branch**: `main`
**Status**: Draft
**Related Commits**: `TBD`
**Related PR**: https://github.com/dtgfdgfgf/SDD-WorkSpace/pull/3
**Reconciliation Status**: Open
**Validation Scope**: Batch

## Summary

- Make extension intake, approval, export, state transitions, and generated mirrors use one
  fail-closed content, recovery, and path boundary.
- Keep consumer worktree hook configuration local to the derived worktree and keep shared-agent
  junction contents out of fresh consumer Git status.
- Make runtime upgrades validate passive candidate bytes with a frozen trusted authority, promote
  atomically, and either restore the complete canonical baseline or retain hash-bound recovery
  evidence when rollback itself cannot finish.
- Include R-C03 as an owner-approved RB-4 dependency because the mandatory schema-violation gate
  cannot be satisfied while extension schemas remain unenforced.

## Why This Update Exists

RVR-08 and ledger R-C01, R-C02, R-C05, R-C07, and R-C08 showed that extension scope,
approval, mutation order, export destinations, and generated mirrors could disagree. RB-4
preflight additionally confirmed that the batch acceptance rule requires schema violations to be
rejected while R-C03 was not named in the original RB-4 mapping. The owner explicitly authorized
R-C03 as a batch dependency on 2026-07-20.

RVR-09 and ledger R-A19 showed that ordinary linked-worktree configuration could rewrite the
repository-wide `core.hooksPath`, and that the project template claimed to exclude shared-agent
junction contents without actually doing so.

RVR-11 and ledger R-F06 showed that the runtime upgrade command mutated canonical files before
running the audit and left a partially updated runtime after failure.

## Scope

- R-C01, R-C02, R-C03, R-C05, R-C07, and R-C08: schema-enforced extension intake,
  physical path and scope containment, content-bound approval, transactional mutation, bounded
  export, lifecycle verification, generated-mirror invalidation, and durable rollback evidence.
- R-A19: per-worktree hook configuration plus clean fresh-consumer junction handling.
- R-F06: frozen trusted staged verification, hash-bound atomic promotion or rollback, and durable
  failure evidence. Candidate checker, version, and export scripts receive no transaction
  execution authority.
- No changes under `projects/` or `learning/`. RB-5, R6, workflow promotion, main merge,
  force-push, history rewriting, and PR-thread resolution remain out of scope.
- R-C04 and R-C06 remain open. Removing candidate skills and extension smoke callers from the
  upgrade transaction is only partial alignment for R-F04; R-F04 remains open.

## Affected Paths

| Path | Change |
|------|--------|
| `.gitignore` | Keep retained extension transaction evidence outside repository intake. |
| `studio/extensions/` | Enforce schemas and content-bound extension registry policy. |
| `studio/scripts/powershell/*extension*.ps1` | Close intake, export, state, removal, scope, and mirror boundaries. |
| `studio/scripts/powershell/new-project-worktree.ps1` and shared helpers | Configure hooks without changing another worktree. |
| `studio/templates/project-init/.gitignore` | Exclude shared-agent junction contents from consumer Git intake. |
| `studio/scripts/powershell/upgrade-studio-runtime.ps1` | Use frozen trusted audits, complete baselines, atomic promotion or rollback, and durable recovery journals. |
| `docs/0308upstreams/spec-kit-studio-first-upstream-usage-guide-2026-03-08.md` | Correct the upgrade transaction description and preserve R-F04 as open. |
| `studio/runtime/shared-runtime-contract.json` | Add revert-sensitive invariants for all RB-4 acceptance surfaces. |
| `studio/tests/` | Add discriminating extension, worktree, consumer, and upgrade tests. |
| This note and `docs/mainline-updates/README.md` | Record RB-4 as an in-progress coherent Batch. |

## Impact

- Extension bytes, catalog approval, state, declared runtime scope, and generated mirror state
  cannot silently diverge through the supported commands.
- The pre-existing `extension-smoke` approval was not evidence for its current bytes. The catalog
  therefore records it as draft, experimental, default-disabled, and unapproved instead of
  carrying stale trust forward.
- A failed extension rollback preserves an ignored, hash-bound local recovery directory and reports
  its path; policy forbids staging, committing, or sharing that local evidence.
- A derived worktree receives its own governed hook path without rewriting the source or sibling
  worktree setting.
- A fresh consumer repository does not report or stage workspace-owned agent junction contents.
- A normal runtime upgrade failure restores and verifies the complete canonical baseline. If
  external interference corrupts that baseline, rollback rejects the corrupted bytes before
  canonical overwrite, fails loudly, and retains the transaction journal and baseline for
  recovery.
- This Batch does not make the full Wave-3 branch merge-ready. The Aggregate gate remains blocked
  by the Draft Wave-3 umbrella note until R6.

## Impact Reconciliation

| Target | Impact | Disposition | Evidence |
|--------|--------|-------------|----------|
| `studio/runtime/shared-runtime-contract.json` | `must_review` | `updated` | Extension recovery, content approval, worktree-local hooks, trusted upgrade authority, atomic journal, and baseline-hash restoration are revert-sensitive; all mutation fixtures fail closed. |
| `studio/scripts/powershell/check-speckit-runtime.ps1` | `must_review` | `reviewed-no-change` | The production audit consumes the updated contract and reports `VALID=true`, 0 errors, and 0 warnings; no checker implementation change was required. |
| `studio/constitution/constitution.md` | `maybe_review` | `reviewed-no-change` | RB-4 implements existing fail-closed, authority-order, and Surface Truthfulness rules without changing constitutional policy. |
| `WORKSPACE_STRUCTURE.md` | `must_review` | `updated` | Version 1.9.0 now describes worktree-local hook configuration; different-depth source and sibling worktrees retain their own values in tests. |
| `studio/extensions/POLICY.md` | `must_review` | `updated` | Version 1.2.0 content-bound approval, replacement reset, mirror invalidation, and retained recovery-evidence handling match tested behavior. |
| `docs/0308upstreams/spec-kit-studio-first-upstream-usage-guide-2026-03-08.md` | `must_review` | `updated` | The guide no longer claims that untrusted candidate checker, version, or export scripts run in the upgrade transaction and explicitly leaves R-F04 open. |
| `docs/sdd-workspace-repair-inventory-and-update-plan-2026-07-12_zhTW.md` | `must_review` | `pending` | Pending implementation commit and closure evidence. |
| `docs/sdd-workspace-wave-3-remediation-plan-2026-07-14_zhTW.md` | `must_review` | `pending` | Pending owner R-C03 decision record and RB-4 evidence. |

## Validation

- Extension lifecycle: 21 passed, 0 failed. Exact `02f12cb` overlay passed only the one positive
  compatibility control and failed all 20 discriminating tests. Negatives cover schema bypass,
  lexical and physical scope escape, reparse points, approval-byte replacement, multi-file
  rollback, mirror rollback and invalidation, recovery retention and Git ignore, atomic baseline
  restoration, unsafe output, and lifecycle divergence.
- Worktree and consumer suites: 114 passed, 0 failed. Exact `02f12cb` overlay passed 97 unaffected
  controls and failed the three discriminating assertions for shared hook mutation, junction
  status or staging, and missing rooted consumer ignores.
- Runtime upgrade: 17 passed, 0 failed in the root run and in two independent full reruns; the
  deterministic corrupted-baseline case passed five consecutive targeted runs. Exact `02f12cb`
  overlay failed 17 of 17. Negatives cover incomplete snapshots, lexical and physical reparse
  escape, stale mirror masking, string Boolean, wrong-type and null counts, self-approving checker
  or dependency, absolute writes, trusted or baseline sibling tampering, candidate smoke
  execution, post-promotion audit failure, later-file promotion failure and retry, and corrupted
  rollback evidence.
- Production-map isolated Apply returned exit 0 with zero changes; trusted staging and canonical
  audits each returned Boolean `true` and Int64 `0/0`, and the transaction reported passed,
  committed, and rollback not required.
- Path hardening: 14 passed, 0 failed. Runtime contract mutation suite: 31 passed, 0 failed.
- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json`: `VALID=true`, 0 errors, and
  0 warnings.
- `pwsh ./studio/scripts/powershell/run-governance-tests.ps1`: 664 passed, 0 failed.
- PowerShell parsing: 14 changed or added scripts parsed with 0 errors.
- `pwsh ./studio/scripts/powershell/validate-mainline-notes.ps1 -BaseRef 02f12cb -HeadRef
  HEAD -RequireReady -ReadinessScope Batch -Json`: pending until the implementation commit exists.
- Aggregate validation is expected to remain nonzero only for the canonical Draft Wave-3 umbrella
  note.
- `git diff --check`: passed.

## Merge Notes

- This note remains Draft only until the implementation commit exists and the dated ledger and
  remediation accounting are appended.
- Ready status, if earned, will cover only the coherent RB-4 diff from immutable base `02f12cb`.
- PR #3 remains not ready to merge after RB-4; RB-5 and R6 remain required.

## Follow-ups

- Keep `sdd-pipeline` experimental, default-disabled, and execution-denied until R6.
- Keep R-A21, R-B23, R-C04, R-C06, and all other findings outside this batch unchanged unless
  new evidence requires a separately identified ledger entry.
