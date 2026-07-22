---
description: Convert existing tasks into actionable, dependency-ordered GitHub issues for the feature based on available design artifacts.
tools: ['edit', 'runNotebooks', 'search', 'new', 'runCommands', 'runTasks', 'usages', 'vscodeAPI', 'problems', 'changes', 'testFailure', 'openSimpleBrowser', 'fetch', 'githubRepo', 'extensions', 'todos', 'runSubagent']
claude-tools: ['Read', 'Glob', 'Grep', 'Bash']
model: claude-opus-4-7
infer: true
---

## Output Language

**Default: Traditional Chinese (zh-TW)**. Keep technical terms in English (API, OAuth2, design tokens, etc.). See `copilot-instructions.md` Language Strategy for details.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

When `$ARGUMENTS` contains `-FeatureDir <path>`, treat that named option as the authoritative
feature context. Pass it to the first feature-context script, then preserve the returned absolute
`FEATURE_DIR` in every feature-bound action. Do not rebind from the branch, environment, or
free-form user text.

## Outline

1. Run `studio/scripts/powershell/check-prerequisites.ps1 -Json -RequireTasks -IncludeTasks` from repo root, or `studio/scripts/powershell/check-prerequisites.ps1 -FeatureDir <path> -Json -RequireTasks -IncludeTasks` when the named option is present, and parse FEATURE_DIR, AVAILABLE_DOCS, STUDIO_ROOT, and CONSTITUTIONS. All paths must be absolute. For single quotes in args like "I'm Groot", use escape syntax: e.g 'I'\''m Groot' (or double-quote if possible: "I'm Groot").
1. From the executed script, extract the path to **tasks**.
1. Get the Git remote by running:

```bash
git config --get remote.origin.url
```

**ONLY PROCEED TO NEXT STEPS IF THE REMOTE IS A GITHUB URL**

1. For each task in the list, use the GitHub MCP server to create a new issue in the repository that is representative of the Git remote.

**UNDER NO CIRCUMSTANCES EVER CREATE ISSUES IN REPOSITORIES THAT DO NOT MATCH THE REMOTE URL**
