# CLAUDE.md

<!--
  STUDIO TEMPLATE v1.0.0
  Usage: Copy to project root and fill in placeholders.
  This file is operational context for Claude Code, not the project constitution.
  Place at: <project>/CLAUDE.md
-->

This file provides guidance to Claude Code when working with code in this repository.

## Governance Hierarchy

Apply rules in this order (higher wins):

1. `studio/constitution/constitution.md` -- studio-level governance
2. `.specify/memory/constitution.md` -- project-level constitution (if exists)
3. `.github/copilot-instructions.md` -- agent context
4. This file

This file is operational context, not the constitution. If it conflicts with spec/readiness/plan/analyze artifacts, follow those documents and flag the drift.

## Project

**Name**: [PROJECT_NAME]
**Type**: [PROJECT_TYPE]
**Created**: [CREATED_DATE]

## Commands

```bash
# Build
[command]

# Run all tests
[command]

# Run the app
[command]
```

## Architecture

[Brief architecture description]

## SDD Workflow

The constitution mandates a seven-stage workflow. Do not skip stages.

```
specify -> clarify -> readiness -> plan -> tasks -> analyze -> implement
```

Feature artifacts live in `specs/<feature-id>/`.

## AI Agent Rules

- Do not add features not in the specification
- Reference the specific document or repo-local evidence that supports a decision
- Before starting a task, check whether an available skill or workflow is better suited

## Code Style

- Comments explaining business logic: use Traditional Chinese
