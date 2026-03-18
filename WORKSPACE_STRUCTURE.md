# Workspace Structure Design

**Version:** 1.4.1
**Created:** 2025-12-08  
**Updated:** 2026-03-18
**Owner:** Solo AI Engineer  
**Methodology:** Specification-Driven Development (SDD)

## Overview

This workspace is a studio-first Spec Kit variant. Governance, runtime agents, prompts, templates,
extensions, and generated exports are centralized at the workspace level. Projects consume those
shared assets without turning each repo into a fully self-contained upstream Spec Kit clone.

Design priorities:

- Single source of truth for governance and runtime agents
- Dual-layer constitutions with additive project rules
- Predictable initialization for Practice, Internal, and Client projects
- Controlled template customization without losing studio defaults
- Additive upstream alignment through shared-layer capabilities instead of repo-local migration

## Root Layout

| Path | Purpose |
|------|---------|
| `.github/copilot-instructions.md` | Workspace-level Copilot rules |
| `.github/agents/` | Runtime source for shared SDD agents |
| `.github/prompts/` | Runtime source for shared prompt assets |
| `learning/<project>/` | Practice projects |
| `projects/<project>/` | Internal, Client, and historical sample projects |
| `archive/` | Archived or deprecated items |
| `resources/` | Shared resources |
| `resources/agent-skill-packs/` | Generated AI skill packs exported from shared runtime sources |
| `WORKSPACE_STRUCTURE.md` | This document |
| `features.txt` | Current development goals |

## Studio Canonical Sources

| Path | Purpose |
|------|---------|
| `studio/constitution/constitution.md` | Highest-authority studio governance |
| `studio/runtime/shared-runtime-contract.json` | Machine-verifiable shared runtime contract for studio-only convergence |
| `studio/extensions/` | Canonical shared extension source, manifest schema, catalog, and state |
| `studio/templates/project-init/` | Project bootstrap skeleton |
| `studio/templates/sdd-docs/` | Canonical document templates |
| `studio/templates/sdd-agents/` | Mirror of runtime agents; update from `.github/agents/` |
| `studio/knowledge-base/learnings.md` | Cross-project learning capture |
| `studio/prompts/<stage>/` | Stage-specific reusable prompts |
| `studio/scripts/powershell/` | Studio automation scripts |

## Project-Level Structure

Each project is expected to contain:

| Path | Purpose |
|------|---------|
| `.specify/memory/constitution.md` | Project-level canonical constitution |
| `.github/agents/` | Junction to workspace `.github/agents/` |
| `.github/copilot-instructions.md` | GitHub Copilot project context |
| `CLAUDE.md` | Claude project context |
| `specs/<feature>/spec.md` | Feature specification |
| `specs/<feature>/readiness/` | Readiness assessment and route-specific packets |
| `specs/<feature>/readiness/eci/` | ECI dossier artifacts for external capability governance |
| `specs/<feature>/plan.md` | Technical plan |
| `specs/<feature>/tasks.md` | Task decomposition |
| `specs/<feature>/contracts/` | Markdown or machine-readable service contracts |
| `src/` | Source code |
| `docs/` | Documentation |
| `README.md` | Project overview and project type declaration |

## Design Decisions

### 1. Dual-Layer Constitutions

| Layer | File | Purpose |
|-------|------|---------|
| Studio | `studio/constitution/constitution.md` | Universal methodology and quality gates |
| Project | `<project>/.specify/memory/constitution.md` | Additive domain rules and stricter standards |

Notes:

- Project constitutions can only add stricter rules.
- `.github/copilot-instructions.md` and `CLAUDE.md` are context files, not constitutions.

### 2. Runtime Agent Source

The runtime source of truth is:

- `.github/agents/`
- `.github/prompts/`

`studio/templates/sdd-agents/` is retained as a mirror for scaffolding and auditability. It should
be updated from the runtime source, not edited independently as a competing authority.

### 3. Extension Registry

`studio/extensions/` is the canonical shared extension registry for this workspace. Manifests live
under `studio/extensions/<extension-id>/manifest.json`, while `catalog.json` and `state.json`
control curated visibility and enable/disable state at the workspace level.

Rules:

- Extensions are workspace-level shared capabilities, not project-local customization dumps.
- `catalog.json` controls curated registration metadata.
- `state.json` controls enable/disable state.
- No extension registry data belongs under `<project>/.specify/` or `<project>/.github/`.

### 4. Generated Skill Packs

`resources/agent-skill-packs/<agent>/` stores generated skill pack exports for skill-based agent
ecosystems. These exports are mirrors built from `.github/agents/` and `.github/prompts/`; they are
not a new source of truth and should be regenerated rather than edited by hand.

`readiness-assessment.md` remains the latest authoritative gate state for each feature. The
`readiness/eci/` dossier is supporting governance input during post-ECI re-entry and does not
replace the requirement to re-run readiness before planning.

### 4.1 Shared-Layer Convergence Acceptance

- `projects/` 與 `learning/` 是 consumer spaces，不是 shared-layer convergence 的預設驗收面
- shared-layer convergence 的 DOD 只看 studio runtime、templates、docs、hooks 與 shared scripts
- `check-speckit-runtime.ps1 -Json` 是 shared runtime 的主要機器驗證入口
- `readiness / eci` 的最終 shared-layer 收斂，以 `check-speckit-runtime.ps1 -Json` 為唯一 machine-verifiable acceptance source
- `docs/readiness_source/` 保留為 design reference，不屬於 canonical runtime acceptance surface

### 5. Template Strategy

Studio templates are the default baseline. Projects may add local overrides under
`.specify/templates/`, but scripts must continue to work when only studio templates exist.

Key template paths:

| Path | Purpose |
|------|---------|
| `studio/templates/sdd-docs/spec-template.md` | Specification template |
| `studio/templates/sdd-docs/readiness-assessment-template.md` | Readiness assessment template |
| `studio/templates/sdd-docs/eci-assessment-template.md` | ECI assessment template |
| `studio/templates/sdd-docs/eci-source-manifest-template.md` | ECI source manifest template |
| `studio/templates/sdd-docs/eci-adoption-record-template.md` | ECI adoption record template |
| `studio/templates/sdd-docs/eci-authorization-record-template.md` | ECI authorization record template |
| `studio/templates/sdd-docs/repo-context-packet-template.md` | Repo context packet template |
| `studio/templates/sdd-docs/decision-record-template.md` | Decision record template |
| `studio/templates/sdd-docs/validation-contract-template.md` | Validation contract template |
| `studio/templates/sdd-docs/access-setup-checklist-template.md` | Access setup checklist template |
| `studio/templates/sdd-docs/eci-trigger-template.md` | ECI trigger template |
| `studio/templates/sdd-docs/exploration-boundary-template.md` | Exploration boundary template |
| `studio/templates/sdd-docs/plan-template.md` | Plan template |
| `studio/templates/sdd-docs/tasks-template.md` | Checklist-first task template |
| `studio/templates/sdd-docs/checklist-template.md` | Checklist template |
| `studio/templates/sdd-docs/agent-file-template.md` | Project agent context template |
| `studio/templates/sdd-docs/project-constitution-template.md` | Project constitution template |

### 6. Project Classification

| Type | Primary Location | Notes |
|------|------------------|-------|
| Practice | `learning/` | New learning projects |
| Internal | `projects/` | Studio tooling and internal delivery |
| Client | `projects/` | Client work |

`projects/japanese-learning/` remains a historical sample and regression fixture. It is not part of
the new project classification scheme for fresh practice work.

## Initialization Behavior

`init-practice.ps1` and `init-project.ps1` must:

1. Copy `studio/templates/project-init/`
2. Generate a project `README.md`
3. Preserve or create `.specify/memory/constitution.md`
4. Create a project `.code-workspace`
5. Create a `.github/agents/` junction to workspace runtime agents

## Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Feature directory | `NNN-kebab-case` | `001-user-registration` |
| SDD docs | `lowercase.md` | `spec.md`, `readiness-assessment.md`, `eci-trigger.md`, `eci-assessment.md`, `source-manifest.md`, `adoption-record.md`, `authorization-record.md`, `plan.md`, `tasks.md` |
| Templates | `kebab-case-template.md` | `spec-template.md` |
| Prompts | descriptive kebab-case | `clarify-ambiguity.md` |
| Extensions | `kebab-case` | `security-gates`, `client-review` |

## Related Documents

| Document | Purpose |
|----------|---------|
| `studio/constitution/constitution.md` | Governance baseline |
| `.github/copilot-instructions.md` | Workspace AI collaboration rules |
| `studio/QUICKSTART.md` | Fast-start instructions |
| `studio/SDD-QUICKSTART-GUIDE.md` | Full workflow guide |
| `spec-kit-upstream-wave2-transition-guide.md` | Wave 2 upstream alignment execution guide |

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.4.1 | 2026-03-18 | Add post-ECI readiness re-entry semantics and clarify that `readiness-assessment.md` remains the latest gate authority |
| 1.4.0 | 2026-03-18 | Promote `/speckit.eci` to shared runtime and add `readiness/eci/` dossier artifacts |
| 1.3.0 | 2026-03-08 | Add shared extension registry foundations under `studio/extensions/` |
| 1.2.0 | 2026-03-08 | Add generated AI skill pack export path as a non-canonical shared artifact |
| 1.1.0 | 2026-03-07 | Align studio-first runtime sources, constitution paths, and project initialization rules |
| 1.0.0 | 2025-12-08 | Initial structure design |
