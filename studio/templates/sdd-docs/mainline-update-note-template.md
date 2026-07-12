# Mainline Update Note: [SHORT TITLE]

<!--
  Create under docs/mainline-updates/YYYY-MM-DD-short-topic.md
  Required for workspace-governance branches intended to merge into main when shared-layer
  governance, runtime agents, prompts, templates, hooks, shared scripts, or canonical docs change.

  Status state machine:
  - Draft: in progress; Related Commits MAY be TBD.
  - Ready: this batch is finalized and the commits exist. Related Commits MUST list at least
    one concrete commit hash (or PR link), and Reconciliation Status MUST be Closed. A Ready note
    with all-TBD commit metadata or unresolved must_update reconciliation is invalid.
  - Merged: the batch has been merged into main. Related Commits MUST list the final hash(es).
  - Reopened: when later evidence refutes a material Ready or Merged claim, immediately change the
    Status back to Draft and add a Revalidation section naming the evidence and re-entry conditions.
-->

**Date**: YYYY-MM-DD
**Source Branch**: [branch-name]
**Target Branch**: `main`
**Status**: Draft / Ready / Merged
**Related Commits**: [hashes or `TBD` only while Status: Draft]
**Related PR**: [link or `N/A`]
**Reconciliation Status**: Open / Closed

## Summary

- [High-signal change 1]
- [High-signal change 2]

## Why This Update Exists

[Explain the motivation, problem being fixed, or governance gap being closed.]

## Scope

- [Workflow / runtime / template / docs scope]
- [Any non-goals or excluded areas]

## Affected Paths

| Path | Change |
|------|--------|
| [path] | [what changed] |

## Impact

- [User or maintainer-visible effect]
- [Governance / workflow / migration effect]

## Impact Reconciliation

Record every aggregate branch-diff route that requires `must_update`. A `must_update` row closes
only when the target is present in the branch diff, Disposition is `updated`, and Evidence is
concrete. Use `reviewed-no-change` or `deferred-owner-approved` only for non-`must_update` review
records; they do not weaken a `must_update` route. Ready or Merged requires no `pending` rows.

| Target | Impact | Disposition | Evidence |
|--------|--------|-------------|----------|
| [exact impact-registry target] | `must_update` / `must_review` / `maybe_review` | `updated` / `reviewed-no-change` / `deferred-owner-approved` / `pending` | [changed path, test, owner approval, or other concrete evidence] |

## Validation

- `git diff --check`
- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json`
- `pwsh ./studio/scripts/powershell/validate-mainline-notes.ps1 -BaseRef <base> -HeadRef <head> -RequireReady -Json`
- [Any additional validation command or manual check]

## Merge Notes

- [Whether this is ready to merge, already merged, or waiting on review]
- [Any conflict-resolution or follow-up context]

## Follow-ups

- [None / future enhancement / migration note]
