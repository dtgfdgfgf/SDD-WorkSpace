# Mainline Update Notes

Central index for main-bound shared-layer update explanation notes.

## Purpose

This directory is the canonical place to record dedicated explanation notes for workspace-governance
branches that are intended to merge into `main`.

These notes are for human understanding and review. They do not replace canonical runtime artifacts,
the studio constitution, or the shared runtime audit.

## When A Note Is Required

Any branch intended to merge into `main` that changes shared-layer governance,
runtime agents, prompts, templates, hooks, shared scripts, or their canonical explanatory docs.

Guidelines:

- One note may cover one coherent merge-ready batch of related commits.
- A separate note is not required for every individual commit.
- Local experiments that are not being prepared for merge do not need a note yet.

## Naming Rule

Use `YYYY-MM-DD-short-topic.md`.

Example:

- `2026-03-30-intent-ledger-runtime-governance.md`

## Authoring Rule

Start from `studio/templates/sdd-docs/mainline-update-note-template.md`, then add the new file to
the index below in the same change batch.

## Index

| Date | Topic | Source Branch | Status | Summary |
|------|-------|---------------|--------|---------|
| 2026-04-28 | [`update-constitution-invariants`](./2026-04-28-update-constitution-invariants.md) | `main` | Ready | Strengthen `update-constitution-script` invariant to lock the three v1.8.0 governance rules embedded in the script. |
| 2026-04-28 | [`adapter-change-routing`](./2026-04-28-adapter-change-routing.md) | `main` | Ready | Add `adapter_change` changeType to impact routing so adapter edits produce precise must_update advisories. |
| 2026-04-28 | [`quickstart-adapter-invariants`](./2026-04-28-quickstart-adapter-invariants.md) | `main` | Ready | Lock the v1.8.0 adapter narrative in QUICKSTART and SDD-GUIDE via two new contract docInvariants. |
| 2026-04-27 | [`agent-bootstrap-governance`](./2026-04-27-agent-bootstrap-governance.md) | `main` | Ready | Add synchronized runtime adapter governance for Codex, Claude Code, and Copilot startup context. |
| 2026-04-10 | [`shared-layer-consistency-fix`](./2026-04-10-shared-layer-consistency-fix.md) | `main` | Ready | Fix 8 shared-layer issues: constitution renumber, authority classification, pre-commit MUST validations, stale mirrors, ghost directory, init script templates, audit auto-fix. |
| 2026-04-04 | [`claude-junction-runtime`](./2026-04-04-claude-junction-runtime.md) | `main` | Ready | Add workspace-level Claude shared junction runtime, project init support, derived worktree bootstrap, and runtime audit coverage. |
| 2026-04-02 | [`project-worktree-parity-governance`](./2026-04-02-project-worktree-parity-governance.md) | `main` | Ready | Define consumer-project derived worktrees as project-equivalent instances and require parity checks beyond Git-tracked files. |
| 2026-03-30 | [`intent-ledger-runtime-governance`](./2026-03-30-intent-ledger-runtime-governance.md) | `001-yuanta-trading-workspace` | Ready | Enforce `intent-ledger` across readiness/plan/analyze runtime semantics and sync the branch with latest `main` before merge. |
