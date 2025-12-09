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

```
workspace/
│
├── .github/
│   └── copilot-instructions.md      # AI collaboration rules for GitHub Copilot
│
├── agents/                           # GitHub Copilot Agents (root level)
│   └── [agent-name].md              # Custom agent definitions
│
├── studio/                           # Studio-level resources (SINGLE SOURCE OF TRUTH)
│   │
│   ├── constitution/
│   │   └── constitution.md           # Studio Constitution (HIGHEST AUTHORITY)
│   │
│   ├── knowledge-base/
│   │   ├── learnings.md              # Cumulative learnings from all projects
│   │   └── pain-points/              # Categorized pain point records
│   │       └── [category].md         # e.g., sdd-workflow.md, ai-collaboration.md
│   │
│   ├── prompts/                      # SDD Stage Prompt Library
│   │   ├── specify/                  # Specification prompts
│   │   ├── clarify/                  # Clarification prompts
│   │   ├── plan/                     # Planning prompts
│   │   ├── tasks/                    # Task decomposition prompts
│   │   ├── analyze/                  # Consistency analysis prompts
│   │   └── implement/                # Implementation prompts
│   │
│   ├── templates/
│   │   │
│   │   ├── project-init/             # Project skeleton (copy entire folder)
│   │   │   ├── .specify/
│   │   │   │   └── memory/           # Location for project constitution
│   │   │   ├── specs/                # Feature specifications go here
│   │   │   ├── src/                  # Source code
│   │   │   └── README.md             # Project template usage guide
│   │   │
│   │   ├── sdd-docs/                 # SDD document templates (copy to project, then customize)
│   │   │   ├── spec-template.md      # Specification template
│   │   │   ├── plan-template.md      # Technical plan template
│   │   │   ├── tasks-template.md     # Task decomposition template
│   │   │   ├── checklist-template.md # Quality checklist template
│   │   │   └── agent-file-template.md # AI agent context template
│   │   │
│   │   ├── project-constitution-template.md  # Project constitution example
│   │   │
│   │   └── feature-packs/            # [NOT ACTIVE] Reusable service templates
│   │
│   └── tools/                        # Studio automation scripts
│
├── learning/                         # Practice projects (current focus)
│   └── [project-name]/               # Each project follows project-init structure
│
├── projects/                         # Production projects
│   ├── [client-project]/             # Client work (future)
│   └── [internal-project]/           # Internal tools
│
├── archive/                          # Deprecated/completed items
│
├── resources/                        # Shared resources (configs, images, etc.)
│
├── WORKSPACE_STRUCTURE.md            # This file
└── features.txt                      # Current development goals
```

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

```
studio/templates/sdd-docs/          # (1) Studio initial version (generic)
        │
        │ Copy when creating project
        ▼
project/.specify/templates/         # (2) Project version (customizable)
        │
        │ AI customizes based on project constitution
        ▼
project/.specify/templates/         # (3) Project-specific templates
        │
        │ Use to generate feature documents
        ▼
project/specs/NNN-feature/
├── spec.md
├── plan.md
└── tasks.md                        # (4) Actual feature documents
```

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

```
Pain Point Discovered
        ↓
Document in learnings.md (lightweight)
        ↓
If pattern emerges → Extract to prompts/<stage>/
        ↓
Reference in copilot-instructions.md
        ↓
Future projects benefit automatically
```

**Files:**

| File | When to Update | Content |
|------|----------------|---------|
| `learnings.md` | After each project/feature | What worked, what didn't |
| `pain-points/<category>.md` | When friction occurs | Specific issue + resolution |
| `prompts/<stage>/*.md` | When pattern solidifies | Reusable prompt template |

### 6. Project Structure: specs/ Contains Everything

**Pattern from duotify-membership-v1:**

```
project/
├── specs/
│   └── 001-feature-name/
│       ├── spec.md
│       ├── plan.md
│       ├── tasks.md
│       └── checklists/
├── src/
└── tests/
```

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
