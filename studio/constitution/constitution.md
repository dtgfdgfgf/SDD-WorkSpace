# 📄 《Studio Constitution》 (Optimized English Version)

**File name:** constitution.md  
**Version:** 1.2.0  
**Scope:** Studio-level governance for a single-person AI engineering practice  
**Applies to:** All projects, feature packs, and SDD workflows

## 1. Purpose

This constitution defines the standard operating principles, workflows, quality expectations, and collaboration rules for a one-person AI engineering studio using Specification-Driven Development (SDD). It serves as the highest-level authority across all projects.

Its goals:

- Enable repeatable, predictable, maintainable delivery
- Reduce communication overhead and rework
- Maintain consistency when collaborating with AI agents (Claude / Copilot)
- Establish a long-term scalable methodology for client work and internal projects

## 1.1 Project Classification

Projects are classified into three types with different levels of rigor:

| Type | Description | SDD Rigor | Knowledge Capture |
|------|-------------|-----------|-------------------|
| **Practice** | Learning exercises, demos, skill-building | Full SDD flow | `learnings.md` update (lightweight) |
| **Internal** | Studio tools, automation, personal projects | Full SDD flow | `retrospective.md` required |
| **Client** | Paid client work (future) | Full SDD flow + client review gates | `retrospective.md` required |

**Current Phase:** Practice (as of 2025-12)

Classification MUST be declared in the project's `README.md` or `.specify/memory/constitution.md`.

## 2. SDD Workflow (Mandatory Sequence)

All projects MUST follow the SDD sequence below without skipping steps:

- /speckit.specify — Create initial specification
- /speckit.clarify — Resolve ambiguities
- /speckit.plan — Produce the technical plan
- /speckit.tasks — Create task decomposition
- /speckit.analyze — Validate cross-document consistency
- /speckit.implement — Execute implementation

A stage MAY NOT begin until the previous stage is finalized.

## 3. Specification Requirements (spec.md)

Each specification MUST include:

- Problem / Goal
- Actors
- Scenarios / User Flows
- Functional Requirements (FR)
- Non-Functional Requirements (NFR)
- At least 3 Edge Cases
- Success Criteria (measurable)
- Out of Scope
- Document version (e.g. v1.0.0)

Specifications MUST avoid vague terms ("smart", "fast", "good UI") unless defined concretely.

## 4. Clarification Requirements (/speckit.clarify)

Clarification output MUST:

- Remove ambiguity
- Define precise boundaries
- Specify all input/output formats
- Complete business logic
- Align expectations with the client

If high-risk ambiguities remain, the project MAY NOT proceed to the planning stage.

## 5. Technical Plan Requirements (plan.md)

A technical plan MUST include:

- Architecture overview (text only OK)
- Technology decisions with rationale
- Integration points / APIs
- Data flow description
- Constraints and risks
- “Why Not” decisions (alternatives rejected)
- Estimated timeline and effort
- Document version history

## 6. Task Decomposition Requirements (tasks.md)

Tasks MUST follow:

- Granularity: 0.5–2 days per task
- Each task MUST map to items in spec/plan
- Each task MUST include a Definition of Done
- Dependencies MUST be explicit
- Risk level: Low / Medium / High
- Priority: P1 / P2 / P3

## 7. Consistency Checking (/speckit.analyze)

Interpretation rules:

- Critical findings → MUST be fixed before implementation
- Major findings → SHOULD be fixed
- Minor findings → Optional at engineer’s discretion

## 8. Implementation Rules

During implementation:

- Work MUST follow the task list exactly
- No feature MAY be added unless included in the spec
- Small-scope TDD MAY be used where beneficial
- Any specification change MUST update spec/plan/tasks with version bumps

## 9. Feature Packs [NOT ACTIVE]

> **Status:** This section is NOT ACTIVE. It will be activated when the studio has established reusable service templates from completed projects.

This section applies when the studio has established reusable service templates.

All reusable services (e.g., chatbot-basic, CRM-lite, automation-basic) SHOULD be stored in:

- templates/feature-packs/<service-name>/

Each Feature Pack SHOULD include:

- spec-template.md
- plan-template.md
- tasks-template.md
- Common prompts
- Common integration / API flows

New projects SHOULD start from an appropriate Feature Pack when:

- A matching Feature Pack exists, AND
- The project scope aligns with the template

Until Feature Packs are established, projects start from `templates/project-init/` skeleton.

## 10. AI Agent Collaboration Rules

AI agents MUST operate under the following principles:

- Studio Constitution is the highest context source
- Role expectations per SDD stage:
  - specify → express requirements, define boundaries
  - clarify → identify ambiguities and missing information
  - plan → assist in technical reasoning
  - tasks → propose decompositions and acceptance criteria
  - implement → assist in generation of code/comments/docs
- AI MUST follow spec/plan/tasks and MAY NOT hallucinate or assume missing requirements
- All AI-generated content MUST be manually reviewed
- AI MAY NOT skip SDD stages or suggest skipping stages

## 11. Required Project Structure

Each project MUST follow the structure:

```
/.specify/
    /memory/
        constitution.md     ← Project-level constitution (optional)
/specs/
    /<feature>/
        spec.md
        plan.md
        tasks.md
/src/
docs/
README.md
```

## 12. Governance Rules

### Dual-Layer Compliance

Projects MUST comply with BOTH:

1. **Studio Constitution** — Universal rules, non-negotiable
2. **Project Constitution** — Project-specific additions (located at `/.specify/memory/constitution.md`)

### What Project Constitution CAN Do

- Add project-specific terminology and glossary
- Define project-specific tech stack and conventions
- Add stricter rules (e.g., "all functions MUST have unit tests")
- Define project-specific review checklists
- Document client-specific requirements (future use)

### What Project Constitution CANNOT Do

- Relax or skip any Studio Constitution rules
- Skip any SDD stage
- Remove mandatory document sections (spec/plan/tasks)
- Override AI collaboration principles

### Conflict Resolution

If ambiguity exists between Studio and Project constitutions, Studio Constitution takes precedence.

### Versioning

- Versioning MUST follow Semantic Versioning
- Updates to Studio Constitution SHOULD trigger review of related templates

## 13. Knowledge Capture (Mandatory)

Every completed project MUST include a knowledge capture phase. Requirements vary by project type (see Section 1.1).

### 13.1 Practice Projects (Lightweight)

For Practice projects, update `studio/knowledge-base/learnings.md` with:

- **Date & Project name**
- **What I learned** — Key takeaways
- **Pain points** — What caused friction
- **Prompt candidates** — If a pain point can become a reusable prompt, note it here

Format:
```markdown
## [YYYY-MM-DD] Project: <name>
### Learned
- ...
### Pain Points
- ...
### Prompt Candidates
- [ ] <description> → target: studio/prompts/<stage>/
```

`retrospective.md` is OPTIONAL for Practice projects.

### 13.2 Internal / Client Projects (Full)

For Internal and Client projects, create `retrospective.md` in the project root with:

- **What went well?** — Practices worth repeating
- **What was painful?** — Friction points and blockers
- **What would I do differently?** — Lessons for next time
- **Time estimate vs actual** — For improving future estimates

Additionally, update `studio/knowledge-base/learnings.md` if significant learnings exist.

### 13.3 Asset Extraction Review

After each project (all types), ask:

- Any reusable prompt? → Extract to `studio/prompts/<stage>/`
- Any reusable template section? → Extract to `studio/templates/`
- Any pattern worth documenting? → Already in `learnings.md`

### 13.4 Constitution Review

If recurring friction points are found:

- Propose updates to Studio Constitution
- Document the change rationale in commit message or changelog

### 13.5 Knowledge Base Structure

```
studio/knowledge-base/
    learnings.md          ← Cumulative learnings (all projects)
    pain-points/          ← Detailed pain point analysis (optional)
```

### Enforcement

| Project Type | Completion Requirement |
|--------------|------------------------|
| Practice | `learnings.md` updated |
| Internal | `retrospective.md` exists + `learnings.md` updated (if applicable) |
| Client | `retrospective.md` exists + `learnings.md` updated (if applicable) |
