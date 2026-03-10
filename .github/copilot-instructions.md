# Copilot Instructions

## Overview

This workspace is a studio-first Specification-Driven Development (SDD) environment for a solo AI
engineering practice.

- **Owner:** Solo AI engineer
- **Current Phase:** Practice (as of 2025-12)
- **Project Types:** Practice, Internal, Client
- **Governance Model:** Dual-layer constitutions with centralized studio governance

## Canonical Sources

| Path | Role |
|------|------|
| `studio/constitution/constitution.md` | Studio-level governance and highest authority |
| `<project>/.specify/memory/constitution.md` | Project-level canonical constitution when project rules exist |
| `.github/agents/` | Runtime source for shared SDD agents |
| `.github/prompts/` | Runtime source for shared prompt assets |
| `studio/extensions/` | Canonical shared extension registry and workspace-level extension state |
| `resources/agent-skill-packs/` | Generated skill mirrors for skill-based agent ecosystems; not canonical source |
| `studio/templates/sdd-agents/` | Mirrored agent templates; sync from `.github/agents/` only |
| `studio/templates/sdd-docs/` | Canonical studio document templates |
| `<project>/.github/copilot-instructions.md` | GitHub Copilot project context only |
| `<project>/CLAUDE.md` | Claude project context only |

## Governance Order

When working in a project, load rules in this order:

1. `studio/constitution/constitution.md`
2. `<project>/.specify/memory/constitution.md` if present
3. Agent context files such as `.github/copilot-instructions.md` or `CLAUDE.md`

Priority rules:

- Studio Constitution is non-negotiable.
- Project Constitution can add stricter rules only.
- Agent context files summarize or operationalize the rules; they are not constitutions.
- If any conflict exists, Studio Constitution wins.

## Mandatory Workflow

All delivery work MUST follow this sequence:

1. `/speckit.specify`
2. `/speckit.clarify`
3. `/speckit.plan`
4. `/speckit.tasks`
5. `/speckit.analyze`
6. `/speckit.implement`

Workflow support:

- `/speckit.discover` is an optional pre-spec aid for messy or incomplete inputs.
- `/speckit.checklist`, `/speckit.constitution`, and `/speckit.taskstoissues` are auxiliary commands.

## Project Structure

| Path | Purpose |
|------|---------|
| `<project>/.specify/memory/constitution.md` | Project-level canonical constitution |
| `<project>/.github/copilot-instructions.md` | Copilot-specific project context |
| `<project>/CLAUDE.md` | Claude-specific project context |
| `<project>/specs/<feature>/spec.md` | Feature specification |
| `<project>/specs/<feature>/plan.md` | Technical plan |
| `<project>/specs/<feature>/tasks.md` | Task decomposition |
| `<project>/specs/<feature>/contracts/` | Markdown or machine-readable service contracts |
| `<project>/src/` | Source code |
| `<project>/docs/` | Documentation |
| `<project>/README.md` | Project overview and project type declaration |

## Markdown Rules

All AI-authored Markdown in this workspace should favor formats that are easy for both humans and
LLMs to parse.

Preferred formats:

- Markdown tables for paths, mappings, comparisons, and structured data.
- Numbered lists for ordered procedures.
- Bullet lists for unordered requirements or constraints.
- Inline code for commands, paths, identifiers, and file names.
- Plain text descriptions for architecture and data flow.

Avoid:

- ASCII art and box-drawing diagrams.
- Tree diagrams.
- Directional symbols used as flow notation.
- Emoji in constitutions, SDD documents, and agent-facing instructions.

Good patterns:

- Describe flow in text, for example: "Data moves from input validation to persistence to response."
- Represent structures with path tables rather than visual trees.

## Language Strategy

Default human-facing document language is Traditional Chinese unless a project chooses otherwise.

Keep these in English:

- Code identifiers
- Branch names and commit type prefixes
- Requirement IDs such as `FR-001`, `NFR-002`, `T001`
- Normative keywords such as `MUST`, `SHOULD`, `MAY`, `NOT`
- Standards, protocols, tool names, and framework names
- Studio constitutions and shared agent instruction files unless a file is already established in another language

Use Chinese where it improves operator clarity:

- `spec.md`, `plan.md`, `tasks.md`
- User-facing documentation
- Learning records and retrospectives
- Business-context comments

## Git Conventions

AI assists with version control, but the human retains final approval.

AI may:

- Generate code and documentation
- Explain changes and their rationale
- Suggest Conventional Commits messages

AI must not:

- Run `git commit` without explicit approval
- Run `git push` automatically
- Amend, rebase, or rewrite history without instruction

Commit format:

```text
<type>: <zh-TW summary>
```

Recommended types:

- `feat`
- `fix`
- `docs`
- `refactor`
- `chore`
- `test`
- `style`

## Critical Constraints

Never:

- Skip an SDD stage
- Treat `.github/copilot-instructions.md` or `CLAUDE.md` as the project constitution
- Invent requirements that are not in the spec or clarified outputs
- Add features outside the approved scope
- Change governance files without explicit reason
- Treat `resources/agent-skill-packs/` as a canonical source of truth
- Create project-local extension registries that compete with `studio/extensions/`

Always:

- Resolve ambiguity before planning or implementation
- Reference spec, plan, tasks, and constitutions when making changes
- Flag document drift and missing updates
- Preserve the studio-first centralized runtime model
- Treat generated skill packs as disposable mirrors that must be regenerated from shared runtime sources
- Treat `studio/extensions/` as the only shared extension registry authority

## Knowledge Feedback

When recurring friction appears:

1. Record the issue in project context or retrospective notes.
2. Suggest prompt extraction into `studio/prompts/<stage>/` when the pattern is reusable.
3. Update `studio/knowledge-base/learnings.md` after project completion when the learning matters beyond one task.
