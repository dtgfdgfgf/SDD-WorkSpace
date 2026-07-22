---
description: Generate an actionable, dependency-ordered tasks.md for the feature based on available design artifacts.
model: claude-opus-4-7
infer: true
handoffs: 
  - label: Analyze For Consistency
    agent: speckit.analyze
    prompt: Run a project analysis for consistency with -FeatureDir <FEATURE_DIR>.
    send: true
---

## Output Language

**Default: Traditional Chinese (zh-TW)**. Keep technical terms in English (API, OAuth2, design tokens, etc.). See `copilot-instructions.md` Language Strategy for details.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

When `$ARGUMENTS` contains `-FeatureDir <path>`, treat that named option as the authoritative
feature context. Pass it to the first feature-context script, then preserve the returned absolute
`FEATURE_DIR` in every next-stage command and handoff. Do not rebind from the branch, environment,
or free-form user text.

## Outline

1. **Setup**: Run `studio/scripts/powershell/check-prerequisites.ps1 -Json` from repo root, or `studio/scripts/powershell/check-prerequisites.ps1 -FeatureDir <path> -Json` when the named option is present, and parse FEATURE_DIR, AVAILABLE_DOCS, STUDIO_ROOT, and CONSTITUTIONS. All paths must be absolute. For single quotes in args like "I'm Groot", use escape syntax: e.g 'I'\''m Groot' (or double-quote if possible: "I'm Groot").

2. **Load design documents**: Read from FEATURE_DIR:
   - **Required**: plan.md (tech stack, libraries, structure), spec.md (user stories with priorities)
   - **Optional**: data-model.md (entities), contracts/ (API endpoints), research.md (decisions), quickstart.md (test scenarios)
   - Note: Not all projects have all documents. Generate tasks based on what's available.

3. **Execute task generation workflow**:
   - Load plan.md and extract tech stack, libraries, project structure
   - Load spec.md and extract user stories with their priorities (P1, P2, P3, etc.)
   - If data-model.md exists: Extract entities and map to user stories
   - If contracts/ exists: Map endpoints to user stories
   - If research.md exists: Extract decisions for setup tasks
   - Generate tasks organized by user story (see Task Generation Rules below)
   - Generate dependency graph showing user story completion order
   - Create parallel execution examples per user story
   - Validate task completeness (each user story has all needed tasks, independently testable)

4. **Generate tasks.md**: Use `studio/templates/sdd-docs/tasks-template.md` as structure, fill with:
   - Correct feature name from plan.md
   - Phase 1: Setup tasks (project initialization)
   - Phase 2: Foundational tasks (blocking prerequisites for all user stories)
   - Phase 3+: One phase per user story (in priority order from spec.md)
   - Each phase includes: story goal, independent test criteria, tests (if requested), implementation tasks
   - Final Phase: Polish & cross-cutting concerns
   - All tasks must follow the strict checklist format from `studio/templates/sdd-docs/tasks-template.md` and any stricter project constitution rules (see Task Generation Rules below)
   - Clear file paths for each task
   - Dependencies section showing story completion order
   - Parallel execution examples per story
   - Implementation strategy section (MVP first, incremental delivery)

5. **Report**: Output path to generated tasks.md, the exact `/speckit.analyze -FeatureDir "<FEATURE_DIR>"` handoff, and summary:
   - Total task count
   - Task count per user story
   - Parallel opportunities identified
   - Independent test criteria for each story
   - Suggested MVP scope (typically just User Story 1)
   - Format validation: Confirm ALL tasks follow the checklist format (checkbox, task ID, priority label, risk label, story label, file paths)

Context for task generation: $ARGUMENTS

The tasks.md should be immediately executable - each task must be specific enough that an LLM can complete it without additional context.

## Task Generation Rules

**CRITICAL**: Tasks MUST be organized by user story to enable independent implementation and testing.

**Tests are OPTIONAL**: Only generate test tasks if explicitly requested in the feature specification or if user requests TDD approach.

### Checklist Format (REQUIRED)

If the project constitution or `studio/templates/sdd-docs/tasks-template.md` defines stricter task metadata than this generic workflow, follow the constitution/template as the canonical source.

Every task MUST strictly follow this format:

```text
- [ ] T### [P#] [Risk: X] [Story: ...] Description with file path
```

**Format Components**:

1. **Checkbox**: ALWAYS start with `- [ ]` (markdown checkbox)
2. **Task ID**: Sequential number (T001, T002, T003...) in execution order
3. **Priority label**: REQUIRED on every task
   - Format: `[P1]`, `[P2]`, `[P3]`
   - Represents delivery priority, not parallelism
4. **Risk label**: REQUIRED on every task
   - Format: `[Risk: Low]`, `[Risk: Medium]`, `[Risk: High]`
5. **Story label**: REQUIRED on every task
   - Format: `[Story: Foundation]`, `[Story: US1]`, `[Story: US2]`, `[Story: US3]`, `[Story: Polish]`
   - Setup / Foundational tasks should typically use `Foundation`
   - User Story phases must map to the corresponding user story ID from `spec.md`
   - Final Phase tasks should typically use `Polish`
6. **Description**: Clear action with exact file path
7. **Parallelism**: DO NOT encode parallel execution in the checklist line
   - Capture it in `Dependencies`, `Parallel Execution Examples`, or an optional follow-up line such as `Parallel with: T0xx, T0yy`

**Examples**:

- ✅ CORRECT: `- [ ] T001 [P1] [Risk: Low] [Story: Foundation] Create project structure per implementation plan in src/ and tests/`
- ✅ CORRECT: `- [ ] T005 [P1] [Risk: Medium] [Story: Foundation] Implement authentication middleware in src/middleware/auth.py`
- ✅ CORRECT: `- [ ] T012 [P1] [Risk: Medium] [Story: US1] Create User model in src/models/user.py`
- ✅ CORRECT: `- [ ] T014 [P1] [Risk: Medium] [Story: US1] Implement UserService in src/services/user_service.py`
- ❌ WRONG: `- [ ] Create User model` (missing task ID, priority, risk, story label)
- ❌ WRONG: `T001 [US1] Create model` (missing checkbox, priority, risk, story label)
- ❌ WRONG: `- [ ] T001 [US1] Create User model` (missing priority, risk, canonical story label prefix)
- ❌ WRONG: `- [ ] T001 [P] [US1] Create model` (uses parallel marker instead of priority/risk format)
- ❌ WRONG: `- [ ] T001 [P1] [Risk: Medium] [Story: US1] Create model` (missing file path)

### Task Organization

1. **From User Stories (spec.md)** - PRIMARY ORGANIZATION:
   - Each user story (P1, P2, P3...) gets its own phase
   - Map all related components to their story:
     - Models needed for that story
     - Services needed for that story
     - Endpoints/UI needed for that story
     - If tests requested: Tests specific to that story
   - Mark story dependencies (most stories should be independent)

2. **From Contracts**:
    - Map each contract/endpoint → to the user story it serves
    - If tests requested: Each contract → contract test task before implementation in that story's phase; note parallel opportunities outside the checklist line

3. **From Data Model**:
   - Map each entity to the user story(ies) that need it
   - If entity serves multiple stories: Put in earliest story or Setup phase
   - Relationships → service layer tasks in appropriate story phase

4. **From Setup/Infrastructure**:
   - Shared infrastructure → Setup phase (Phase 1)
   - Foundational/blocking tasks → Foundational phase (Phase 2)
   - Story-specific setup → within that story's phase

### Phase Structure

- **Phase 1**: Setup (project initialization)
- **Phase 2**: Foundational (blocking prerequisites - MUST complete before user stories)
- **Phase 3+**: User Stories in priority order (P1, P2, P3...)
  - Within each story: Tests (if requested) → Models → Services → Endpoints → Integration
  - Each phase should be a complete, independently testable increment
- **Final Phase**: Polish & Cross-Cutting Concerns
