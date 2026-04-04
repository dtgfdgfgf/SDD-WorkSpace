# [PROJECT_NAME]

**Project Type:** [PROJECT_TYPE]  
**Created:** [CREATED_DATE]  
**Status:** In Progress

## Description

[PROJECT_DESCRIPTION]

## Quick Start

```bash
# Open project with multi-root workspace (recommended)
code <project-name>.code-workspace

# Start SDD workflow
/speckit.specify <your feature description>
```

## Project Structure

| Path | Purpose |
|------|---------|
| `.specify/memory/constitution.md` | Project-level canonical constitution |
| `.github/agents/` | Copilot shared runtime junction |
| `.claude/agents/` | Claude shared runtime junction |
| `.github/copilot-instructions.md` | Copilot project context if generated later |
| `CLAUDE.md` | Claude project context if generated later |
| `docs/governance-status.md` | Project-local governance compatibility notice |
| `specs/<feature>/spec.md` | Feature specification |
| `specs/<feature>/intent-ledger.md` | Secondary artifact for represented / deferred / dropped core intent items when required |
| `specs/<feature>/readiness/` | Readiness assessment and route packets (created on first readiness run) |
| `specs/<feature>/readiness/eci/` | ECI dossier (created only for `ROUTE_TO_ECI` features) |
| `specs/<feature>/plan.md` | Technical plan |
| `specs/<feature>/tasks.md` | Task breakdown |
| `src/` | Source code |
| `docs/` | Documentation |
| `README.md` | This file |

## SDD Workflow Progress

- [ ] Specify — Create specification
- [ ] Clarify — Resolve ambiguities
- [ ] Readiness — Confirm planning safety and emit remediation packets when needed
- [ ] Plan — Technical planning
- [ ] Tasks — Task decomposition
- [ ] Analyze — Consistency check
- [ ] Implement — Execute implementation

## Governance

This project follows the dual-layer constitution system:

1. **Studio Constitution** (highest authority): `studio/constitution/constitution.md`
2. **Project Constitution** (project canonical file): `.specify/memory/constitution.md`

**Note**: Use `<project-name>.code-workspace` to open the project. This multi-root workspace includes:
- Project folder (editable)
- Studio folder (read-only)
- Agents folder (read-only)
- Claude agents folder (read-only)

Project agent context files such as `.github/copilot-instructions.md` and `CLAUDE.md` may be
generated later, but they do not replace `.specify/memory/constitution.md`.

Approved scope compression does not make original intent disappear. If a feature only ships a
representative subset under an umbrella name, keep `intent-ledger.md` current and disclose current
coverage plus known gaps in `README.md` / `quickstart.md`.

## Governance Status

New projects created from this template default to `Current` under the shared `readiness` / `eci`
workflow baseline introduced on 2026-03-18. See `docs/governance-status.md` for the project-local
compatibility notice and `../../docs/project-governance-status.md` for the central ledger in the
workspace governance repo.

## Knowledge Capture

> Complete this section when the project is done.

**For Practice projects:** Update `studio/knowledge-base/learnings.md`

**For Internal/Client projects:** Complete `retrospective.md` in project root

## Related Documents

- Studio Constitution: `studio/constitution/constitution.md`
- Workspace Structure: `WORKSPACE_STRUCTURE.md`
- Project Constitution: `.specify/memory/constitution.md`
- Governance Status Notice: `docs/governance-status.md`
- AI Collaboration Context: `.github/copilot-instructions.md`
