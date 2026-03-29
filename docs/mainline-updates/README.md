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
| 2026-03-30 | [`intent-ledger-runtime-governance`](./2026-03-30-intent-ledger-runtime-governance.md) | `001-yuanta-trading-workspace` | Ready | Enforce `intent-ledger` across readiness/plan/analyze runtime semantics and sync the branch with latest `main` before merge. |
