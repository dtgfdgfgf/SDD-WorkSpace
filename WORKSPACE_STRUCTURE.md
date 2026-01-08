# Workspace Structure Design

**Version:** 1.0.0  
**Created:** 2025-12-08  
**Owner:** Solo AI Engineer  
**Methodology:** Specification-Driven Development (SDD)

## Overview

This document defines the workspace directory structure for a solo AI engineering studio. The design prioritizes:

- **Single Source of Truth**: Templates and governance files are centralized at studio level
- **Dual-Layer Governance**: Studio constitution (highest authority) + Project constitution (additive rules)
- **Knowledge Feedback Loop**: Systematic capture of learnings and pain points during practice phase
- **Scalability**: Structure supports growth from practice projects to client work

### Current Phase

**Practice** (as of 2025-12) — Focus on learning SDD workflow through demo projects and MVPs.

---

## Directory Structure

### Root Level

| Path | Purpose |
|------|---------|
| `.github/copilot-instructions.md` | AI collaboration rules for GitHub Copilot |
| `agents/[agent-name].md` | GitHub Copilot custom agent definitions |
| `learning/[project-name]/` | Practice projects (current focus) |
| `projects/[client-project]/` | Client work (future) |
| `projects/[internal-project]/` | Internal tools |
| `archive/` | Deprecated/completed items |
| `resources/` | Shared resources (configs, images, etc.) |
| `WORKSPACE_STRUCTURE.md` | This file |
| `features.txt` | Current development goals |

### Studio (Single Source of Truth)

| Path | Purpose |
|------|---------|
| `studio/constitution/constitution.md` | Studio Constitution (HIGHEST AUTHORITY) |
| `studio/knowledge-base/learnings.md` | Cumulative learnings from all projects |
| `studio/knowledge-base/pain-points/[category].md` | Categorized pain point records |
| `studio/prompts/specify/` | Specification prompts |
| `studio/prompts/clarify/` | Clarification prompts |
| `studio/prompts/plan/` | Planning prompts |
| `studio/prompts/tasks/` | Task decomposition prompts |
| `studio/prompts/analyze/` | Consistency analysis prompts |
| `studio/prompts/implement/` | Implementation prompts |
| `studio/tools/` | Studio automation scripts |

### Studio Templates

| Path | Purpose |
|------|---------|
| `studio/templates/project-init/` | Project skeleton (copy entire folder) |
| `studio/templates/project-init/.specify/memory/` | Location for project constitution |
| `studio/templates/project-init/specs/` | Feature specifications go here |
| `studio/templates/project-init/src/` | Source code |
| `studio/templates/project-init/README.md` | Project template usage guide |
| `studio/templates/sdd-docs/spec-template.md` | Specification template |
| `studio/templates/sdd-docs/plan-template.md` | Technical plan template |
| `studio/templates/sdd-docs/tasks-template.md` | Task decomposition template |
| `studio/templates/sdd-docs/checklist-template.md` | Quality checklist template |
| `studio/templates/sdd-docs/agent-file-template.md` | AI agent context template |
| `studio/templates/project-constitution-template.md` | Project constitution example |
| `studio/templates/feature-packs/` | [NOT ACTIVE] Reusable service templates |

---

## Design Decisions

### 1. Dual-Layer Constitution (Independent, Not Inherited)

| Layer | File | Purpose |
|-------|------|---------|
| Studio | `studio/constitution/constitution.md` | Universal rules, SDD workflow, quality gates |
| Project | `<project>/.specify/memory/constitution.md` | Project-specific terminology, stricter standards |

**Why Independent?**

- Studio constitution defines **methodology and process** (how to do SDD)
- Project constitution defines **domain-specific rules** (what this project requires)
- Low content correlation — project rules don't extend studio rules, they add orthogonal constraints
- Priority is clear: Studio wins on conflict, but content rarely overlaps

**Template Location:** `studio/templates/project-constitution-template.md` (not inside `project-init/`)

### 2. Templates: Studio Initial → Copy to Project → AI Customize

| Template Type | Location | Usage |
|---------------|----------|-------|
| Project skeleton | `project-init/` | Copy entire folder to start new project |
| SDD documents | `sdd-docs/` | Copy to `project/.specify/templates/`, then AI customizes |
| Project constitution | `project-constitution-template.md` | Copy to project if needed |

**Workflow:**

1. `studio/templates/sdd-docs/` (Studio initial version - generic)
2. Copy to `project/.specify/templates/` when creating project
3. AI customizes based on project constitution
4. Use to generate feature documents in `project/specs/NNN-feature/`

**Why Copy Then Customize?**

- Each project may have different tech stacks, conventions, and requirements
- AI can adapt templates based on project constitution
- Project templates are version-controlled with the project
- Studio templates remain as the "starting point" for new projects

### 3. Prompts at Studio Level (Not Project Level)

**Location:** `studio/prompts/<stage>/`

**Why Studio Level?**

- Prompts encode **reusable patterns** discovered during practice
- Same prompts apply across all projects (methodology consistency)
- Extracted from pain points and learnings over time
- Unlike large teams, solo developer doesn't need per-project prompt customization

**Population Strategy:**

1. Start empty (current state)
2. During practice, identify friction points
3. Extract recurring prompt patterns into `studio/prompts/<stage>/`
4. Reference in `copilot-instructions.md` or use directly

### 4. Agents at Root Level

**Location:** `workspace/agents/`

**Why Root Level?**

- GitHub Copilot agent discovery works from workspace root
- Agents are workspace-wide, not project-specific
- Keeps `.github/` clean (only `copilot-instructions.md`)

### 5. Knowledge Feedback System Design

**Process Flow:**

1. Pain Point Discovered during development
2. Document in `learnings.md` (lightweight)
3. If pattern emerges, extract to `prompts/<stage>/`
4. Reference in `copilot-instructions.md`
5. Future projects benefit automatically

**Files:**

| File | When to Update | Content |
|------|----------------|---------|
| `learnings.md` | After each project/feature | What worked, what didn't |
| `pain-points/<category>.md` | When friction occurs | Specific issue + resolution |
| `prompts/<stage>/*.md` | When pattern solidifies | Reusable prompt template |

### 6. Project Structure: specs/ Contains Everything

**Pattern from duotify-membership-v1:**

| Path | Purpose |
|------|--------|
| `project/specs/001-feature-name/spec.md` | Feature specification |
| `project/specs/001-feature-name/plan.md` | Technical plan |
| `project/specs/001-feature-name/tasks.md` | Task decomposition |
| `project/specs/001-feature-name/checklists/` | Quality checklists |
| `project/src/` | Source code |
| `project/tests/` | Tests |

**Why Not Separate `plan/` and `tasks/` Folders?**

- Feature cohesion: All SDD documents for a feature stay together
- Easier navigation: One folder per feature
- Clear numbering: `001-`, `002-` prefix for ordering
- Matches mature project structure (duotify reference)

---

## Usage Guide

### Creating a New Project

```powershell
# 1. Copy project skeleton
Copy-Item -Recurse studio/templates/project-init learning/my-new-project

# 2. Copy SDD templates to project
New-Item -ItemType Directory -Path learning/my-new-project/.specify/templates -Force
Copy-Item studio/templates/sdd-docs/* learning/my-new-project/.specify/templates/

# 3. (Optional) Create project constitution
Copy-Item studio/templates/project-constitution-template.md learning/my-new-project/.specify/memory/constitution.md

# 4. Ask AI to customize templates based on project needs
# "請根據這個專案的技術棧和 constitution 調整 .specify/templates/ 內的模板"
```

### Creating a New Feature Specification

```powershell
# 1. Create feature directory
New-Item -ItemType Directory learning/my-project/specs/001-feature-name

# 2. Reference template and create spec
# Open studio/templates/sdd-docs/spec-template.md as reference
# Create learning/my-project/specs/001-feature-name/spec.md

# 3. Follow SDD workflow: specify → clarify → plan → tasks → analyze → implement
```

### Recording a Learning

1. Open `studio/knowledge-base/learnings.md`
2. Add entry with date, context, and insight
3. If it's a recurring pattern, consider extracting to `prompts/`

---

## File Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Feature directory | `NNN-kebab-case` | `001-user-registration` |
| SDD documents | `lowercase.md` | `spec.md`, `plan.md`, `tasks.md` |
| Templates | `kebab-case-template.md` | `spec-template.md` |
| Pain points | `kebab-case.md` | `sdd-workflow.md` |
| Prompts | `stage-name.md` or descriptive | `specify-clarify-ambiguity.md` |

---

## Related Documents

| Document | Purpose | Location |
|----------|---------|----------|
| Studio Constitution | Governance rules | `studio/constitution/constitution.md` |
| Copilot Instructions | AI collaboration rules | `.github/copilot-instructions.md` |
| Learnings | Knowledge capture | `studio/knowledge-base/learnings.md` |

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-12-08 | Initial structure design |
