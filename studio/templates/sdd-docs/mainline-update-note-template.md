# Mainline Update Note: [SHORT TITLE]

<!--
  Create under docs/mainline-updates/YYYY-MM-DD-short-topic.md
  Required for workspace-governance branches intended to merge into main when shared-layer
  governance, runtime agents, prompts, templates, hooks, shared scripts, or canonical docs change.

  Status state machine:
  - Draft: in progress; Related Commits MAY be TBD.
  - Ready: this batch is finalized and the commits exist. Related Commits MUST list at least
    one concrete commit hash (or PR link). A Ready note with all-TBD commit metadata is invalid.
  - Merged: the batch has been merged into main. Related Commits MUST list the final hash(es).
-->

**Date**: YYYY-MM-DD
**Source Branch**: [branch-name]
**Target Branch**: `main`
**Status**: Draft / Ready / Merged
**Related Commits**: [hashes or `TBD` only while Status: Draft]
**Related PR**: [link or `N/A`]

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

## Validation

- `git diff --check`
- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json`
- Change manifests: [all closed / N deferred with reason / none required]
- [Any additional validation command or manual check]

## Merge Notes

- [Whether this is ready to merge, already merged, or waiting on review]
- [Any conflict-resolution or follow-up context]

## Follow-ups

- [None / future enhancement / migration note]
