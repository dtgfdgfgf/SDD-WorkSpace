# [PROJECT NAME] Agent Context

<!--
  STUDIO TEMPLATE v1.1.0
  This file provides project-specific agent context.
  Canonical project constitution: .specify/memory/constitution.md
  Target locations may include .github/copilot-instructions.md, CLAUDE.md, AGENTS.md, or similar.
-->

**Auto-generated from feature governance artifacts**
**Last updated**: [DATE]

## Governance Reference

Apply rules in this order:

1. `studio/constitution/constitution.md`
2. `.specify/memory/constitution.md`
3. This agent context file

This file is not the project constitution. It should summarize and operationalize the governing
rules, not replace them.

## Project Overview

**Name**: [PROJECT NAME]  
**Type**: [PROJECT TYPE]  
**Description**: [Brief project description]

## Active Technologies

| Category | Technology | Version |
|----------|------------|---------|
| Language | [e.g., TypeScript] | [e.g., 5.3] |
| Framework | [e.g., Next.js] | [e.g., 14.0] |
| Database | [e.g., PostgreSQL] | [e.g., 16] |
| Testing | [e.g., Jest] | [e.g., 29] |

## Project Structure

| Path | Purpose |
|------|---------|
| `project/.specify/memory/constitution.md` | Canonical project constitution |
| `project/.github/copilot-instructions.md` | Copilot project context |
| `project/CLAUDE.md` | Claude project context |
| `project/specs/NNN-feature/spec.md` | Feature specification |
| `project/specs/NNN-feature/readiness/` | Readiness assessment and remediation packets |
| `project/specs/NNN-feature/readiness/eci/` | ECI dossier artifacts |
| `project/specs/NNN-feature/plan.md` | Technical plan |
| `project/specs/NNN-feature/tasks.md` | Task decomposition |
| `project/specs/NNN-feature/contracts/` | Markdown or machine-readable contracts |
| `project/src/` | Source code |
| `project/tests/` | Tests |

## Commands

### Development

```bash
# Start development server
[command]

# Run tests
[command]

# Build for production
[command]
```

### Database

```bash
# Run migrations
[command]

# Seed data
[command]
```

## Code Style

### [Language]

- [Naming convention]
- [File organization]
- [Import order]

### Comments and Communication

- Use the project's established language rules for comments
- Use Traditional Chinese for operator communication unless the project requires otherwise
- Explain why when the reasoning is non-obvious

## AI Agent Instructions

### Do

- Follow spec, readiness, ECI dossier, plan, tasks, and constitutions exactly
- Treat ECI dossier files as governed input during readiness re-entry
- Ask for clarification when ambiguous
- Reference the specific document that supports a decision
- Flag document drift and consistency issues

### Do Not

- Add features not in the specification
- Skip SDD stages
- Treat sandbox-only or spike-only ECI authorization as permission to plan
- Treat this file as the project constitution
- Hallucinate APIs, data structures, or business logic

## Recent Changes

| Feature | Date | Summary |
|---------|------|---------|
| [NNN-feature-name] | [DATE] | [What was added or changed] |

## Known Issues / TODOs

- [ ] [Issue or TODO item]
- [ ] [Issue or TODO item]

<!-- MANUAL ADDITIONS START -->
<!-- Add project-specific notes here. This section is preserved when regenerating the file. -->
<!-- MANUAL ADDITIONS END -->
