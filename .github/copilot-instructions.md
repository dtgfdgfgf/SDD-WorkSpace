# Copilot Instructions: Workspace

This file is the GitHub Copilot runtime adapter for this project.

<!-- BEGIN GENERATED GOVERNANCE BOOTSTRAP -->
## Generated Governance Bootstrap

**Bootstrap Version:** 1
**Studio Constitution:** `studio/constitution/constitution.md`
**Studio Constitution Version:** 1.8.0
**Project Constitution:** `N/A (workspace root)`

This runtime adapter participates in dual-layer constitution governance.

Load and apply rules in this order:

1. `studio/constitution/constitution.md`
2. `.specify/memory/constitution.md` when present
3. This adapter file

If either required constitution is missing or inaccessible, report governance context incomplete before planning or implementation.

Hard rules:

- Studio Constitution has highest authority.
- Project Constitution can only add stricter rules.
- Agent context files are adapters, not constitutions.
- Governed delivery work follows: specify, clarify, readiness, plan, tasks, analyze, implement.
- If documents conflict, flag drift instead of silently choosing.
<!-- END GENERATED GOVERNANCE BOOTSTRAP -->

## Tool Notes

- GitHub Copilot and Copilot CLI should follow the governance bootstrap before planning, editing, or suggesting implementation work.
- Keep shared governance additions inside the generated bootstrap block so AGENTS.md and CLAUDE.md can be synchronized.

<!-- MANUAL ADDITIONS START -->
# Copilot Instructions

<!-- Authority: dependent runtime adapter for workspace-level Copilot agent context.
     The agent-scoped subset at .github/agents/copilot-instructions.md is a dependent
     document and should derive from this file's guidance, not compete with it. -->

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
| `.claude/agents/` | Runtime source for shared Claude agents |
| `.github/prompts/` | Runtime source for shared prompt assets |
| `studio/extensions/` | Canonical shared extension registry and workspace-level extension state |
| `resources/agent-skill-packs/` | Generated skill mirrors for skill-based agent ecosystems; not canonical source |
| `studio/templates/sdd-docs/` | Canonical studio document templates |
| `docs/project-worktree-parity-governance.md` | Canonical policy for consumer-project derived worktree parity |
| `<project>/AGENTS.md` | Codex / Copilot CLI runtime adapter only |
| `<project>/CLAUDE.md` | Claude Code runtime adapter only |
| `<project>/.github/copilot-instructions.md` | GitHub Copilot project context only |

## Governance Order

When working in a project, load rules in this order:

1. `studio/constitution/constitution.md`
2. `<project>/.specify/memory/constitution.md` if present
3. Runtime adapter files such as `AGENTS.md`, `CLAUDE.md`, or `.github/copilot-instructions.md`

Priority rules:

- Studio Constitution is non-negotiable.
- Project Constitution can add stricter rules only.
- Runtime adapter files summarize or operationalize the rules; they are not constitutions.
- If any conflict exists, Studio Constitution wins.

## Shared-Layer Audit

- For shared-layer convergence work, use `studio/scripts/powershell/check-speckit-runtime.ps1 -Json` as the primary audit entrypoint.
- Treat `projects/` and `learning/` as consumer spaces, not as the default acceptance surface for shared runtime convergence.

## Mandatory Workflow

All delivery work MUST follow this sequence:

1. `/speckit.specify`
2. `/speckit.clarify`
3. `/speckit.readiness`
4. `/speckit.plan`
5. `/speckit.tasks`
6. `/speckit.analyze`
7. `/speckit.implement`

Workflow support:

- `/speckit.discover` is an optional pre-spec aid for messy or incomplete inputs.
- `/speckit.checklist`, `/speckit.constitution`, and `/speckit.taskstoissues` are auxiliary commands.
- `/speckit.eci` is the specialized shared runtime command for `ROUTE_TO_ECI` cases. It consumes `readiness/eci-trigger.md`, writes `readiness/eci/*.md`, and then returns control to `/speckit.readiness`.
- Completing `/speckit.eci` does not authorize planning by itself. Only the latest `readiness-assessment.md` can authorize `/speckit.plan`.
- If ECI authorization remains sandbox-only or spike-only, readiness should shift to the next blocker such as validation, access, or a real owner decision instead of repeating `ROUTE_TO_ECI`.

## Project Structure

| Path | Purpose |
|------|---------|
| `<project>/.specify/memory/constitution.md` | Project-level canonical constitution |
| `<project>/.github/copilot-instructions.md` | Copilot-specific project context |
| `<project>/CLAUDE.md` | Claude-specific project context |
| `<project>/specs/<feature>/spec.md` | Feature specification |
| `<project>/specs/<feature>/readiness/` | Readiness assessment and remediation packets |
| `<project>/specs/<feature>/readiness/eci/` | ECI dossier artifacts for governed external capabilities |
| `<project>/specs/<feature>/plan.md` | Technical plan |
| `<project>/specs/<feature>/tasks.md` | Task decomposition |
| `<project>/specs/<feature>/contracts/` | Markdown or machine-readable service contracts |
| `<project>/src/` | Source code |
| `<project>/docs/` | Documentation |
| `<project>/README.md` | Project overview and project type declaration |

## Project Worktree Parity

When handling a derived worktree under `projects/` or `learning/`, do not assume project
completeness from the tracked tree alone.

Rules:

- Treat a derived worktree as a same-level project instance, not as a reduced checkout.
- Treat `.git` as a normal file-based Git worktree pointer when Git worktree plumbing uses that
  form.
- Compare the derived worktree against the source project's declared parity surface before cleanup,
  normalization, or diagnosis.
- If the source project depends on `.github/agents/`, `.claude/agents/`, `.github/copilot-instructions.md`,
  `CLAUDE.md`, `.specify/memory/constitution.md`, `.code-workspace`, or declared local-only assets,
  a derived worktree missing them is not operationally healthy unless a documented equivalent source
  exists.
- Do not use public snapshot boundaries, `.gitignore`, or local-only blacklists as justification for
  dropping required project-operational assets.

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

- `spec.md`, `readiness/**/*.md`, `plan.md`, `tasks.md`
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
- Run `/speckit.plan` without a `READY_FOR_PLAN` readiness assessment
- Treat `/speckit.eci` as direct authorization for planning without re-running `/speckit.readiness`
- Treat `READY_FOR_SANDBOX_ONLY` or `READY_FOR_SPIKE_ONLY` ECI authorization as sufficient for planning
- Treat `AGENTS.md`, `.github/copilot-instructions.md`, or `CLAUDE.md` as the project constitution
- Invent requirements that are not in the spec or clarified outputs
- Add features outside the approved scope
- Change governance files without explicit reason
- Treat `resources/agent-skill-packs/` as a canonical source of truth
- Create project-local extension registries that compete with `studio/extensions/`

Always:

- Resolve ambiguity before readiness, planning, or implementation
- Reference spec, readiness, plan, tasks, and constitutions when making changes
- Flag document drift and missing updates
- Preserve the studio-first centralized runtime model
- Treat generated skill packs as disposable mirrors that must be regenerated from shared runtime sources
- Treat workspace `/.claude/agents/` as the Claude shared runtime authority; Claude skills installs are a separate layer
- Treat `studio/extensions/` as the only shared extension registry authority
- Treat `docs/project-worktree-parity-governance.md` as the canonical rule when evaluating
  consumer-project derived worktree completeness

## Knowledge Feedback

When recurring friction appears:

1. Record the issue in project context or retrospective notes.
2. Suggest prompt extraction into `studio/prompts/<stage>/` when the pattern is reusable.
3. Update `studio/knowledge-base/learnings.md` after project completion when the learning matters beyond one task.
<!-- MANUAL ADDITIONS END -->
