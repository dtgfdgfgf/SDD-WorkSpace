# Copilot Instructions

## Overview

This is a solo AI engineering studio workspace using **Specification-Driven Development (SDD)** methodology.

- **Owner:** Solo AI engineer
- **Current Phase:** Practice (as of 2025-12)
- **Project Types:** Demo projects, MVPs, skill-building exercises
- **Governance:** Dual-layer constitution system (Studio + Project level)

## Workspace Layout

```
studio/
├── constitution/          # Studio-level governance rules (HIGHEST AUTHORITY)
│   └── constitution.md
├── prompts/               # Reusable prompts organized by SDD stage
│   ├── specify/
│   ├── clarify/
│   ├── plan/
│   ├── tasks/
│   ├── analyze/
│   └── implement/
├── templates/             # Project templates and feature packs
│   ├── project-init/      # New project skeleton
│   └── feature-packs/     # [NOT ACTIVE] Reusable service templates
└── knowledge-base/        # Learnings and pain points
    └── learnings.md       # Cumulative learnings from all projects

learning/                  # Practice projects (current focus)
projects/                  # Internal/Client projects (future)
.github/                   # GitHub Copilot configurations
```

## Dual-Layer Governance

### Lookup Order

When entering a project, check for governance files in this order:

1. **Studio Constitution** (ALWAYS applies): `studio/constitution/constitution.md`
2. **Project Constitution** (if exists): `<project>/.specify/memory/constitution.md`

### Priority Rules

- Studio Constitution is the **highest authority** — non-negotiable
- Project Constitution can only **add stricter rules**, never relax Studio rules
- If conflict exists, Studio Constitution wins
- Both constitutions apply simultaneously when Project Constitution exists

### Merge Logic

```
Final Rules = Studio Constitution + Project Constitution (additive only)
```

Project Constitution CAN:
- Add project-specific terminology
- Define stricter coding standards
- Add extra review checklists

Project Constitution CANNOT:
- Skip any SDD stage
- Relax quality requirements
- Override AI collaboration principles

## Governance Reference

**Studio Constitution:** `studio/constitution/constitution.md`

This file defines:
- SDD workflow stages and requirements
- Document standards (spec.md, plan.md, tasks.md)
- AI collaboration rules
- Quality gates and constraints

Always check the constitution before making architectural decisions.

## SDD Workflow (Mandatory Sequence)

All work MUST follow this sequence without skipping:

1. **specify** → Create specification (spec.md)
2. **clarify** → Resolve ambiguities
3. **plan** → Produce technical plan (plan.md)
4. **tasks** → Create task decomposition (tasks.md)
5. **analyze** → Validate cross-document consistency
6. **implement** → Execute implementation

## Project Structure

Each project follows this structure:

```
<project>/
├── .specify/
│   └── memory/
│       └── constitution.md    # Project-level rules (optional)
├── specs/
│   └── <feature>/
│       ├── spec.md
│       ├── plan.md
│       └── tasks.md
├── src/
├── docs/
└── README.md
```

## Coding Conventions

### Language Strategy

Different content types require different languages for optimal AI understanding and human readability:

#### MUST Use English (AI-critical files)
- Constitution files (`constitution.md`, `copilot-instructions.md`)
- SDD documents (`spec.md`, `plan.md`, `tasks.md`)
- Code (variables, functions, classes)
- Technical comments (algorithm logic, data structures)
- Error messages (for searchability)
- Branch names

#### MAY Use Traditional Chinese (zh-TW)
- Business logic comments (explaining "why" from business perspective)
- User-facing documentation (`README.md` zh-TW version)
- Commit message descriptions (after the type prefix)
- Learning records (`learnings.md`, `retrospective.md`)
- Internal notes and reflections

### Git Conventions

#### Commit Message Format (Conventional Commits + zh-TW)

```
<type>: <中文描述>

[optional body in zh-TW]
```

**Types (English, required):**
- `feat` — New feature
- `fix` — Bug fix
- `docs` — Documentation changes
- `refactor` — Code refactoring (no feature change)
- `chore` — Build, config, tooling changes
- `test` — Test-related changes
- `style` — Code style (formatting, no logic change)

**Examples:**
```
feat: 新增使用者登入功能
fix: 修正購物車數量計算錯誤
docs: 更新 README 安裝說明
chore: 升級相依套件版本
refactor: 重構訂單處理邏輯
```

#### Branch Naming (English only)

Format: `<type>/<short-description>`

Examples:
- `feature/user-login`
- `fix/cart-calculation`
- `docs/readme-update`
- `refactor/order-processing`

### Code Style Guidelines
- JavaScript/TypeScript: camelCase for variables/functions, PascalCase for classes
- Python: snake_case for variables/functions, PascalCase for classes
- Always include meaningful comments for complex logic
- Prefer explicit over implicit

## Critical Constraints

### NEVER Do
- Skip any SDD stage or suggest skipping
- Assume requirements not explicitly written in spec
- Add features not included in the specification
- Hallucinate API endpoints, data structures, or business logic
- Modify constitution rules without explicit instruction

### ALWAYS Do
- Ask for clarification when requirements are ambiguous
- Reference spec/plan/tasks when implementing
- Suggest updating related documents when scope changes
- Flag potential consistency issues between documents
- Respect the dual-layer governance (Studio > Project)

## Knowledge Feedback System

When encountering issues or friction points:

1. **Document in context** — Note what caused the problem
2. **Suggest prompt candidates** — If a pattern emerges, suggest extracting to `studio/prompts/<stage>/`
3. **Flag for learnings.md** — Remind to update `studio/knowledge-base/learnings.md` after project completion

## Build & Validation

No unified build system — each project is independent.

For project-specific build instructions, check:
1. Project's `README.md`
2. Project's `package.json` or equivalent
3. Project's `.specify/memory/constitution.md`

## Response Style

- Be concise and direct
- Use tables and bullet points for clarity
- Show code examples when helpful
- Explain "why" for architectural decisions
- When uncertain, state assumptions explicitly

## Quick Reference

| Item | Location |
|------|----------|
| Studio Constitution | `studio/constitution/constitution.md` |
| Learnings | `studio/knowledge-base/learnings.md` |
| Prompt Library | `studio/prompts/<stage>/` |
| Project Templates | `studio/templates/project-init/` |
| Practice Projects | `learning/` |
