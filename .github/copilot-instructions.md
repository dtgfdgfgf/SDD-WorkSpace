# Copilot Instructions

## Overview

This is a solo AI engineering studio workspace using **Specification-Driven Development (SDD)** methodology.

- **Owner:** Solo AI engineer
- **Current Phase:** Practice (as of 2025-12)
- **Project Types:** Demo projects, MVPs, skill-building exercises
- **Governance:** Dual-layer constitution system (Studio + Project level)

## Workspace Layout

| Path                                  | Purpose                                                           |
| ------------------------------------- | ----------------------------------------------------------------- |
| `studio/constitution/constitution.md` | Studio-level governance rules (HIGHEST AUTHORITY)                 |
| `studio/templates/project-init/`      | New project skeleton                                              |
| `studio/templates/sdd-agents/`        | SDD workflow agents (copy to projects)                            |
| `studio/templates/feature-packs/`     | Reusable service templates [NOT ACTIVE]                           |
| `studio/knowledge-base/learnings.md`  | Cumulative learnings from all projects                            |
| `learning/`                           | Practice projects (current focus)                                 |
| `projects/`                           | Internal/Client projects (future)                                 |
| `.github/agents/`                     | Studio-level agents (constitution, taskstoissues, spec-kit entry) |
| `.github/copilot-instructions.md`     | GitHub Copilot AI collaboration rules                             |

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

Each project contains these paths:

| Path                                        | Purpose                        |
| ------------------------------------------- | ------------------------------ |
| `<project>/.specify/memory/constitution.md` | Project-level rules (optional) |
| `<project>/specs/<feature>/spec.md`         | Feature specification          |
| `<project>/specs/<feature>/plan.md`         | Technical plan                 |
| `<project>/specs/<feature>/tasks.md`        | Task breakdown                 |
| `<project>/src/`                            | Source code                    |
| `<project>/docs/`                           | Documentation                  |
| `<project>/README.md`                       | Project overview               |

## LLM-Friendly Markdown Formatting

All `.md` files generated in this workspace MUST follow these formatting rules to maximize LLM comprehension and minimize token waste.

### MUST Use (LLM-Friendly)

| Format                  | Use Case                                | Example                       |
| ----------------------- | --------------------------------------- | ----------------------------- |
| Markdown tables         | Structured data, comparisons, mappings  | See Workspace Layout section  |
| Numbered lists          | Sequential steps, workflows, priorities | `1. First step`               |
| Bullet lists            | Non-sequential items, features, options | `- Item one`                  |
| Inline code             | File paths, commands, identifiers       | `` `path/to/file.md` ``       |
| Headers                 | Document structure, sections            | `## Section Name`             |
| Plain text descriptions | Explaining relationships, data flow     | "Data flows from A to B to C" |

### MUST NOT Use (LLM-Unfriendly)

| Format                         | Problem                                  | Alternative                            |
| ------------------------------ | ---------------------------------------- | -------------------------------------- |
| ASCII art diagrams             | Low information density, wastes tokens   | Use tables or text descriptions        |
| Box-drawing characters         | Poor LLM parsing                         | Use Markdown tables                    |
| Tree structures (`├──`, `└──`) | Ambiguous parsing, token-heavy           | Use path tables with Purpose column    |
| Arrow symbols (`→`, `←`, `⇒`)  | Inconsistent encoding, unclear semantics | Use "to", "from", "--", or text        |
| Emoji in AI-critical files     | Unpredictable tokenization               | Use text markers like `[OK]`, `[WARN]` |

### File Type Classification

| File Type                                                | Emoji Allowed | Reason                             |
| -------------------------------------------------------- | ------------- | ---------------------------------- |
| `constitution.md`, `copilot-instructions.md`             | NO            | AI governance, must be unambiguous |
| `spec.md`, `plan.md`, `tasks.md`                         | NO            | SDD documents, AI-processed        |
| `README.md`, `CHANGELOG.md`                              | YES           | Human-facing documentation         |
| `learnings.md`, `retrospective.md`                       | YES           | Human reflection records           |
| Status tracking files (e.g., `IMPLEMENTATION_STATUS.md`) | YES           | Visual scanning aids               |

### Data Flow Description

Instead of arrow diagrams:

```
[Input] → [Process A] → [Process B] → [Output]   ❌ BAD
```

Use text description:

```
Data flow: Input to Process A to Process B to Output   ✅ GOOD
```

Or use a table:

| Step | Component | Description              |
| ---- | --------- | ------------------------ |
| 1    | Input     | Receives user data       |
| 2    | Process A | Validates and transforms |
| 3    | Process B | Applies business logic   |
| 4    | Output    | Returns result           |

### Folder Structure Description

Instead of tree diagrams:

```
project/           ❌ BAD
├── src/
│   └── index.js
└── tests/
```

Use path tables:

| Path                   | Purpose     | ✅ GOOD |
| ---------------------- | ----------- | ------- |
| `project/src/`         | Source code |
| `project/src/index.js` | Entry point |
| `project/tests/`       | Test files  |

---

## Coding Conventions

### Language Strategy

#### Default Language: Traditional Chinese (zh-TW)

All generated documents use Traditional Chinese unless otherwise specified.

#### MUST Use English (Non-translatable)

- Code identifiers (variables, functions, classes)
- Branch names, commit type prefixes (feat, fix, docs, etc.)
- Requirement IDs (FR-001, NFR-002, US-1, T001)
- Normative keywords (MUST, SHOULD, MAY, NOT)
- International standards and protocols (REST, OAuth2, JWT, WCAG, HTTP)
- Tools and frameworks (.NET, React, Docker, Astro, etc.)
- Constitution files (`constitution.md`, `copilot-instructions.md`) - maintain English for cross-project consistency
- Agent instruction files (`.github/agents/*.md`) - system-level, maintain English

#### AI Judgment Principle for Technical Terms

When encountering technical terms, AI should determine:

1. Does the term have a widely accepted translation in the Chinese tech community?
2. Would translation lose precision or searchability?
3. If uncertain, keep English and add parenthetical explanation if needed

Examples:

| Term             | Decision                  | Reason                                       |
| ---------------- | ------------------------- | -------------------------------------------- |
| API              | Keep English              | Universal, no good translation               |
| design tokens    | Keep English              | Technical term, "設計權杖" not commonly used |
| state file       | Keep English              | Code-related concept                         |
| audit            | Can translate to 稽核     | Common business term                         |
| batch processing | Can translate to 批次處理 | Widely understood                            |

#### Files That CAN Use Chinese

- `spec.md`, `plan.md`, `tasks.md` - SDD documents (primary audience is human operator)
- Business logic comments (explaining "why" from business perspective)
- User-facing documentation (`README.md` zh-TW version)
- Commit message descriptions (after the type prefix)
- Learning records (`learnings.md`, `retrospective.md`)
- Internal notes and reflections

### Git Conventions

#### AI-Assisted Git Workflow

**Principle:** AI assists with version control, but human retains final approval authority.

**AI Responsibilities:**

- Generate code and documentation
- Suggest commit messages following Conventional Commits format
- Explain what changes were made and why
- Group related changes logically before suggesting commit

**Human Responsibilities:**

- Review all changes before committing (use `git diff` or VS Code Source Control)
- Approve or modify suggested commit messages
- Execute commit after review
- Decide when to push to remote

**AI MUST NOT:**

- Execute `git commit` without explicit user confirmation
- Execute `git push` automatically
- Amend or rebase commits without user instruction
- Make commits with vague messages like "fix" or "update"

**Recommended Workflow:**

1. AI generates/modifies code
2. Human reviews changes (`git diff`)
3. AI suggests commit message
4. Human confirms or modifies message
5. Human approves → AI executes `git commit`
6. After accumulating meaningful commits → Human decides to push

**Commit Frequency Guideline:**

- One commit per completed task (from tasks.md)
- Don't commit every single line change
- Group related changes into logical commits

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
- Use ASCII art or text-based diagrams (low information density, wastes tokens, LLM unfriendly)

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

| Item                | Location                              |
| ------------------- | ------------------------------------- |
| Studio Constitution | `studio/constitution/constitution.md` |
| Learnings           | `studio/knowledge-base/learnings.md`  |
| Prompt Library      | `studio/prompts/<stage>/`             |
| Project Templates   | `studio/templates/project-init/`      |
| Practice Projects   | `learning/`                           |
