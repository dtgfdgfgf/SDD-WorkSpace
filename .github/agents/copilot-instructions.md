# Workspace Development Guidelines

<!-- Authority: dependent (agent-scoped subset).
     This file is a project-template-oriented agent context. Per constitution Section 10,
     agent-scoped subsets do NOT carry an independent GENERATED GOVERNANCE BOOTSTRAP block;
     they derive from their workspace-level adapter (.github/copilot-instructions.md) and
     MUST NOT contradict it. The canonical Studio Constitution is studio/constitution/constitution.md. -->

<!--
  STUDIO TEMPLATE v1.1.0
  Project-template agent context. Copy to project/.specify/templates/ and customize if needed.
  Auto-generated from feature governance artifacts plus a manually maintained section.
-->

**Auto-generated from feature governance artifacts**
**Last updated**: 2026-04-30

---

## Project Overview

**Name**: Workspace  
**Type**: Practice | Internal | Client  
**Description**: [Brief project description]

---

## Active Technologies

<!--
  Extracted from plan.md files and related governance artifacts of all features.
  Update when adding new features or changing tech stack.
-->

| Category | Technology | Version |
|----------|------------|---------|
| Language | [e.g., TypeScript] | [e.g., 5.3] |
| Framework | [e.g., Next.js] | [e.g., 14.0] |
| Database | [e.g., PostgreSQL] | [e.g., 16] |
| Testing | [e.g., Jest] | [e.g., 29] |

---

## Project Structure

| Path | Purpose |
|------|--------|
| `project/.specify/memory/constitution.md` | Project constitution |
| `project/specs/NNN-feature/spec.md` | Feature specification |
| `project/specs/NNN-feature/readiness/` | Readiness assessment and remediation packets |
| `project/specs/NNN-feature/readiness/eci/` | ECI dossier artifacts |
| `project/specs/NNN-feature/plan.md` | Technical plan |
| `project/specs/NNN-feature/tasks.md` | Task decomposition |
| `project/src/` | Source code |
| `project/tests/` | Tests |

<!-- Update with actual structure from feature governance artifacts -->

---

## Commands

<!--
  Only include commands for technologies actually in use.
-->

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

---

## Code Style

<!--
  Language-specific conventions.
  Only include for languages actually in use.
-->

### [Language]

- [Naming convention]
- [File organization]
- [Import order]

### Comments

- Use English for code comments
- Use Traditional Chinese (zh-TW) for business logic explanations
- Include "why" not just "what"

---

## AI Agent Instructions

### Do

- Follow spec/readiness/eci/plan/tasks exactly
- Treat ECI dossier files as governed input during readiness re-entry
- Ask for clarification when ambiguous
- Reference specific documents when making decisions
- Flag potential consistency issues

### Don't

- Add features not in specification
- Skip SDD stages
- Treat sandbox-only or spike-only ECI authorization as permission to plan
- Assume requirements not explicitly written
- Hallucinate APIs or data structures

### Context Priority

1. Studio Constitution (`studio/constitution/constitution.md`)
2. Project Constitution (`.specify/memory/constitution.md`)
3. Feature Spec (`specs/NNN-feature/spec.md`)
4. Feature Readiness (`specs/NNN-feature/readiness/*.md`)
5. Feature ECI Dossier (`specs/NNN-feature/readiness/eci/*.md`)
6. Feature Plan (`specs/NNN-feature/plan.md`)
7. Feature Tasks (`specs/NNN-feature/tasks.md`)

---

## Recent Changes

<!--
  Last 3-5 features and what they added.
  Helps AI understand current project state.
-->

| Feature | Date | Summary |
|---------|------|---------|
| [NNN-feature-name] | 2025-12-20 | [What was added/changed] |

---

## Known Issues / TODOs

<!--
  Track items that AI should be aware of.
-->

- [ ] [Issue or TODO item]
- [ ] [Issue or TODO item]

---

<!-- MANUAL ADDITIONS START -->
<!--
  Add project-specific notes here.
  This section is preserved when regenerating the file.
-->

<!-- MANUAL ADDITIONS END -->
