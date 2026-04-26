# [PROJECT_NAME] Agent Context

<!--
  STUDIO TEMPLATE v1.0.0
  This file provides project-specific agent context for GitHub Copilot.
  Canonical project constitution: .specify/memory/constitution.md
  Place at: <project>/.github/copilot-instructions.md
-->

**Last updated**: [CREATED_DATE]

## Governance Reference

Apply rules in this order:

1. `studio/constitution/constitution.md`
2. `.specify/memory/constitution.md`
3. This agent context file

This file is not the project constitution. It should summarize and operationalize the governing rules, not replace them.

## Project Overview

**Name**: [PROJECT_NAME]
**Type**: [PROJECT_TYPE]
**Description**: [PROJECT_DESCRIPTION]

## Active Technologies

| Category | Technology | Version |
|----------|------------|---------|
| Language | [e.g., TypeScript] | [version] |
| Framework | [e.g., Next.js] | [version] |

## Commands

### Development

```bash
# Start development server
[command]

# Run tests
[command]
```

## Code Style

### Comments

- Use English for code comments
- Use Traditional Chinese (zh-TW) for business logic explanations

## AI Agent Instructions

### Do

- Follow spec/readiness/plan/tasks exactly
- Ask for clarification when ambiguous
- Reference specific documents when making decisions

### Do Not

- Add features not in specification
- Skip SDD stages
- Assume requirements not explicitly written
