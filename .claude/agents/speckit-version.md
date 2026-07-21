---
name: speckit-version
description: "Show the local studio-first Spec Kit version state and upstream alignment summary."
model: claude-opus-4-7
---

<!-- Seeded from canonical source .github/agents/speckit.version.agent.md via studio/scripts/powershell/seed-claude-agents.ps1. This file is a deterministic Claude-consumable dependent mirror. -->
<!-- WARNING: Direct edits to this dependent mirror will be overwritten on the next seed-claude-agents.ps1 run. To make permanent changes, edit canonical source .github/agents/speckit.version.agent.md and re-seed. -->

## Output Language

**Default: Traditional Chinese (zh-TW)**. Keep technical terms in English where they are standard identifiers.

## User Input

```text
$ARGUMENTS
```

## Goal

Report the current local studio-first Spec Kit version state, runtime inventory, and upstream alignment
summary.

## Execution Flow

1. Run `studio/scripts/powershell/get-speckit-version.ps1 -Json`.
2. Summarize these fields for the user:
   - local mode (`studio-first`)
   - Studio Constitution version
   - Workspace Structure version
   - upstream analysis range / baseline date
   - runtime agent count and prompt count
   - adopted capabilities
   - deferred capabilities
   - non-goals
3. If the user asks for more detail, list supported agent contexts and runtime file names.
4. If the script fails, fall back to reading:
   - `studio/constitution/constitution.md`
   - `WORKSPACE_STRUCTURE.md`
   - `spec-kit-upstream-alignment-matrix.md`
5. Be explicit that this is a support command, not a mandatory SDD stage.

## Constraints

- Do not treat `/speckit.version` as a delivery stage.
- Do not propose repo-local `.specify` migration.
- Do not suggest changing `studio-first template precedence`.
- Do not suggest modifying existing projects as part of this command.
