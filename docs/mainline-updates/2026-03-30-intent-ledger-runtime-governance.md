# Mainline Update Note: Intent Ledger Runtime Governance

**Date**: 2026-03-30
**Source Branch**: `001-yuanta-trading-workspace`
**Target Branch**: `main`
**Status**: Ready
**Related Commits**: `08cd85c`, `4d74878`
**Related PR**: `N/A`

## Summary

- Enforce `intent-ledger` as a runtime-governed artifact instead of a docs-only convention.
- Require readiness, plan, and analyze to carry compressed core intent consistently.
- Sync the branch with the latest `main` and preserve a green shared runtime audit after conflict resolution.

## Why This Update Exists

The original governance patch fixed the policy gap around defer-induced intent drift, but the
runtime agents and shared audit still needed to carry that contract automatically. Without this
change, a feature could remain process-consistent while still misrepresenting coverage against the
original product intent.

## Scope

- Add `intent-ledger.md` handling to readiness, plan, and analyze runtime agents.
- Expand shared runtime contract and path helpers so the ledger is part of the machine-verifiable handoff.
- Add a dedicated mainline-update-note management flow for future main-bound shared-layer changes.

Non-goals:

- No new SDD stage
- No new primary readiness status
- No `tasks` or `implement` runtime expansion in this batch

## Affected Paths

| Path | Change |
|------|--------|
| `.github/agents/speckit.readiness.agent.md` | Add ledger creation/update rules, owner-signoff handling, and planability vs intent obligations output contract |
| `.github/agents/speckit.plan.agent.md` | Add ledger handoff validation and `Intent Recovery Obligations` carry-forward requirements |
| `.github/agents/speckit.analyze.agent.md` | Add `Intent Drift Check`, README truthfulness checks, and CRITICAL handling for missing ledger/signoff |
| `studio/scripts/powershell/common.ps1` | Add `INTENT_LEDGER`, `READINESS_DIR`, `READINESS_ASSESSMENT`, and `ECI_DIR` feature paths |
| `studio/scripts/powershell/check-prerequisites.ps1` | Expose new path fields and ledger-aware document discovery in JSON/text outputs |
| `studio/runtime/shared-runtime-contract.json` | Add audit invariants for ledger semantics, template presence, and truthfulness checks |
| `studio/templates/sdd-docs/intent-ledger-template.md` | Add canonical template for the new secondary artifact |
| `docs/mainline-updates/` | Add centralized explanation-note management for future main-bound shared-layer updates |

## Impact

- Future readiness runs can keep `READY_FOR_PLAN` lightweight while still retaining compressed core intent explicitly.
- Planning now hard-fails when a required ledger is missing or incoherent.
- Analyze now blocks implementation-ready conclusions when representative coverage is being over-claimed.
- Main-bound shared-layer changes now have a centralized explanation-note process instead of relying on scattered doc edits alone.

## Validation

- `git diff --check`
- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json`
- Result at note creation time: `VALID=true`, `ERROR_COUNT=0`, `WARNING_COUNT=0`

## Merge Notes

- This note covers the runtime-enforcement batch plus the subsequent merge of `origin/main` into the working branch.
- The branch was revalidated after merge conflict resolution to ensure runtime semantics, mirror parity, and template invariants remained green.

## Follow-ups

- If this branch is merged through a PR, link the PR number back into this note.
- If future shared-layer updates are unrelated, create a new note rather than appending to this one.
