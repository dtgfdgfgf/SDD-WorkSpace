---
name: speckit-taskstoissues
description: "Convert existing tasks into actionable, dependency-ordered GitHub issues for the feature based on available design artifacts."
model: claude-opus-4-7
---

<!-- Seeded from .github/agents/speckit.taskstoissues.agent.md via studio/scripts/powershell/seed-claude-agents.ps1. The workspace root /.claude/agents directory is the Claude shared runtime authority after generation. -->
<!-- WARNING: This file is a seeded copy from .github/agents/speckit.taskstoissues.agent.md. Direct edits will be overwritten on the next seed-claude-agents.ps1 run. To make permanent changes, edit the source file and re-seed. -->

## Output Language

**Default: Traditional Chinese (zh-TW)**. Keep technical terms in English (API, OAuth2, design tokens, etc.). See `copilot-instructions.md` Language Strategy for details.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Outline

1. Run `studio/scripts/powershell/check-prerequisites.ps1 -Json -RequireTasks -IncludeTasks` from repo root and parse FEATURE_DIR, AVAILABLE_DOCS, STUDIO_ROOT, and CONSTITUTIONS. All paths must be absolute. For single quotes in args like "I'm Groot", use escape syntax: e.g 'I'\''m Groot' (or double-quote if possible: "I'm Groot").
1. From the executed script, extract the path to **tasks**.
1. Get the Git remote by running:

```bash
git config --get remote.origin.url
```

**ONLY PROCEED TO NEXT STEPS IF THE REMOTE IS A GITHUB URL**

1. For each task in the list, use the GitHub MCP server to create a new issue in the repository that is representative of the Git remote.

**UNDER NO CIRCUMSTANCES EVER CREATE ISSUES IN REPOSITORIES THAT DO NOT MATCH THE REMOTE URL**
