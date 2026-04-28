<!-- drift-governance
authority: source_of_truth
domain: governance
impact_on_change:
  - target: studio/runtime/shared-runtime-contract.json
    level: must_review
    reason: Constitution invariants may need new or updated mustContainAll entries
  - target: studio/runtime/impact-registry.json
    level: maybe_review
    reason: Authority classification or routing rules may need adjustment
  - target: .github/agents/*.agent.md
    level: must_review
    reason: Agent behavior semantics may be affected by new governance rules
  - target: .claude/agents/*.md
    level: must_review
    reason: Claude agents mirror Copilot agents and must reflect updated semantics
  - target: studio/templates/sdd-docs/*.md
    level: must_review
    reason: Templates may need new sections or updated guidance
  - target: README.md
    level: must_update
    reason: Must reflect current governance state and workflow sequence
  - target: WORKSPACE_STRUCTURE.md
    level: maybe_review
    reason: Structure doc may need updates if paths or conventions changed
  - target: studio/QUICKSTART.md
    level: must_update
    reason: Must reflect constitution rules in quickstart form
  - target: studio/SDD-QUICKSTART-GUIDE.md
    level: must_update
    reason: Must reflect updated methodology rules
  - target: .github/copilot-instructions.md
    level: must_review
    reason: Copilot context may need updated governance references
  - target: .githooks/pre-commit.ps1
    level: maybe_review
    reason: Validation logic may need updates for new governance rules
-->

# Studio Constitution

**File name:** constitution.md  
**Version:** 1.8.0
**Scope:** Studio-level governance for a single-person AI engineering practice  
**Applies to:** All projects and SDD workflows

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

**Current Phase:** Practice + Internal (as of 2026-04)

Classification MUST be declared in the project's `README.md` or `.specify/memory/constitution.md`.

## 2. SDD Workflow (Mandatory Sequence)

All projects MUST follow the SDD sequence below without skipping steps:

- /speckit.specify — Create initial specification
- /speckit.clarify — Resolve ambiguities
- /speckit.readiness — Triage implementation readiness and emit the minimum remediation packet
- /speckit.plan — Produce the technical plan
- /speckit.tasks — Create task decomposition
- /speckit.analyze — Validate cross-document consistency
- /speckit.implement — Execute implementation

A stage MAY NOT begin until the previous stage is finalized.

`/speckit.discover` is an optional pre-spec aid for messy or incomplete inputs. It can inform
`/speckit.specify`, but it is not mandatory and it is not the only valid input source.

`/speckit.checklist`, `/speckit.constitution`, and `/speckit.taskstoissues` are auxiliary
commands. They support the workflow but are not part of the seven mandatory delivery stages.

`/speckit.eci` is a specialized shared runtime command for `ROUTE_TO_ECI` cases. It is not one of
the seven mandatory delivery stages, but when readiness identifies an external capability blocker,
teams MUST run `/speckit.eci` with `readiness/eci-trigger.md` before returning to
`/speckit.readiness`.

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

Core spec items are any requirements, primary scenarios, success criteria, or explicitly named
capabilities that materially define the promised feature surface. Minor internal decomposition or
purely local implementation detail changes do not trigger intent-ledger requirements by
themselves.

## 4. Clarification Requirements (/speckit.clarify)

Clarification output MUST:

- Remove ambiguity
- Define precise boundaries
- Specify all input/output formats
- Complete business logic
- Align expectations with the client

If high-risk ambiguities remain, the project MAY NOT proceed to the readiness or planning stage.

## 5. Implementation Readiness Requirements (/speckit.readiness)

Readiness output MUST:

- Classify exactly one primary status from:
  - `READY_FOR_PLAN`
  - `ROUTE_TO_ECI`
  - `ROUTE_TO_REPO_CONTEXT`
  - `ROUTE_TO_DECISION`
  - `ROUTE_TO_VALIDATION`
  - `ROUTE_TO_ACCESS`
  - `EXPLORATORY_ONLY`
  - `NOT_READY`
- Write `specs/<feature>/readiness/readiness-assessment.md`
- Write only the minimum route-specific remediation packet required by the chosen status
- Keep the primary judgment focused on planning safety rather than product-intent completion
- Distinguish `planability resolved` from `intent obligations retained` (section heading: `## Planability vs Intent Obligations`)
- Require `specs/<feature>/intent-ledger.md` whenever a core spec item is handled as `represented_by_substitute`, `deferred`, or `dropped_with_owner_signoff`
- Explicitly state allowed next actions and prohibited next actions
- Recommend `/speckit.plan` only when the primary status is `READY_FOR_PLAN`

If readiness status is not `READY_FOR_PLAN`, the project MAY NOT proceed to `/speckit.plan`.

`intent-ledger.md` is a secondary artifact. It does not create a new stage or a new readiness
primary status. `READY_FOR_PLAN` MAY still be correct when planning is safe, but the handoff to
planning is incomplete until any required ledger entries exist and are current.

If readiness routes to ECI, the project MUST continue through `/speckit.eci`. `eci-trigger.md`
remains the intake seed, and the resulting ECI dossier MUST be written under `readiness/eci/`
before returning to `/speckit.readiness`.

When readiness re-enters after a coherent ECI dossier exists:

- the dossier MUST be treated as governed input, not ignored as if ECI never happened
- `READY_FOR_MAINLINE_IMPLEMENTATION` means external capability adoption is no longer the primary blocker by itself
- `READY_FOR_SANDBOX_ONLY` or `READY_FOR_SPIKE_ONLY` means readiness MUST route to the next blocker needed to upgrade authorization, typically validation, access, or an owner decision
- the project MUST NOT fall back to `ROUTE_TO_ECI` again unless the dossier is stale, contradictory, misrouted, or no longer matches current external capability scope

### Intent Ledger (Secondary Artifact)

When required, `specs/<feature>/intent-ledger.md` MUST record one row per affected core spec item
using these fixed columns:

- `source_intent_item`
- `spec_anchor`
- `current_classification`
- `current_representation`
- `defer_or_drop_reason`
- `reentry_trigger`
- `follow_on_feature_hint`
- `surface_disclosure_required`
- `owner_signoff_required`

`current_classification` MUST be exactly one of:

- `represented_by_substitute`
- `deferred`
- `dropped_with_owner_signoff`

Additional rules:

- `represented_by_substitute` entries MUST name the current representative capability or source.
- `deferred` entries MUST state a concrete re-entry trigger.
- `dropped_with_owner_signoff` entries MUST capture explicit owner agreement and MUST NOT be silently absorbed by the assistant.
- If all core spec items remain fully in scope, `intent-ledger.md` is not required.

## 5.1 External Capability Intake Requirements (/speckit.eci)

ECI output MUST:

- Accept only features whose readiness primary status is `ROUTE_TO_ECI`
- Write `specs/<feature>/readiness/eci/eci-assessment.md`
- Write `specs/<feature>/readiness/eci/source-manifest.md`
- Write `specs/<feature>/readiness/eci/adoption-record.md`
- Write `specs/<feature>/readiness/eci/authorization-record.md`
- Classify exactly one `ECI Level`
- Classify exactly one `Authorization Outcome`
- Make readiness re-entry expectations explicit, including what readiness should inspect next and what would require another ECI run
- Recommend re-running `/speckit.readiness`

`/speckit.eci` MAY NOT directly authorize `/speckit.plan`.

## 6. Technical Plan Requirements (plan.md)

A technical plan MUST include:

- Architecture overview (text only OK)
- Technology decisions with rationale
- Integration points / APIs
- Data flow description
- `Intent Recovery Obligations` when `intent-ledger.md` exists
- Constraints and risks
- “Why Not” decisions (alternatives rejected)
- Estimated timeline and effort
- Document version history

When `intent-ledger.md` exists, `plan.md` MUST summarize every
`represented_by_substitute` and `deferred` entry under `Intent Recovery Obligations`, including:

- how the intent is currently represented
- why it is not fully implemented in the current iteration
- what concrete condition will re-open it
- what downstream coverage disclosure is required

Generic placeholders such as `v1+` without a real re-entry condition are not sufficient.

## 7. Task Decomposition Requirements (tasks.md)

Tasks MUST follow:

- Canonical checklist line format: `- [ ] T### [P#] [Risk: X] [Story: ...] Description`
- Granularity: 0.5–2 days per task
- Each task MUST map to items in spec/plan
- Each task MUST include a Definition of Done
- Dependencies MUST be explicit
- Risk level: Low / Medium / High
- Priority: P1 / P2 / P3

## 8. Consistency Checking (/speckit.analyze)

Interpretation rules:

- Critical findings must be fixed before implementation
- Major findings should be fixed before implementation whenever feasible
- Minor findings are optional at the engineer's discretion
- `/speckit.analyze` MUST run an `Intent Drift Check` whenever the feature may have compressed core scope
- `Intent Drift Check` MUST verify that all represented, deferred, or dropped core spec items are recorded in `intent-ledger.md`, that dropped items retain explicit owner signoff references, that `plan.md` carries the required `Intent Recovery Obligations`, and that outward-facing docs do not over-claim current coverage
- Failing `Intent Drift Check` MUST block an implementation-ready analysis outcome until the artifacts are aligned, even if readiness itself previously remained `READY_FOR_PLAN`

## 9. Implementation Rules

During implementation:

- Work MUST follow the task list exactly
- No feature MAY be added unless included in the spec
- Small-scope TDD MAY be used where beneficial
- Any specification change MUST update spec, readiness artifacts, `intent-ledger.md`, plan, and tasks with version bumps when those artifacts are affected

## 10. AI Agent Collaboration Rules

AI agents MUST operate under the following principles:

- Studio Constitution is the highest context source
- Role expectations per SDD stage:
  - specify: express requirements, define boundaries
  - clarify: identify ambiguities and missing information
  - readiness: classify planning safety, identify the primary blocker, and emit the next-safe packet
  - eci: govern external capability adoption, source basis, adoption boundary, and authorization
  - plan: assist in technical reasoning
  - tasks: propose decompositions and acceptance criteria
  - implement: assist in generation of code/comments/docs
- AI MUST follow spec/readiness/eci/plan/tasks and MAY NOT hallucinate or assume missing requirements
- All AI-generated content MUST be manually reviewed
- AI MAY NOT skip SDD stages or suggest skipping stages

### Runtime Agent Bootstrap Governance

Agent startup context MUST use a five-file governance model:

| File | Constitutional Role | Authority |
|------|---------------------|-----------|
| `studio/constitution/constitution.md` | Studio Constitution and highest governance source | 1 |
| `.specify/memory/constitution.md` | Project Constitution and additive project rules | 2 |
| `AGENTS.md` | Codex / Copilot CLI runtime adapter with generated governance bootstrap | 3 |
| `CLAUDE.md` | Claude Code runtime adapter with generated governance bootstrap and direct `@path` imports | 3 |
| `.github/copilot-instructions.md` | GitHub Copilot runtime adapter with generated governance bootstrap | 3 |

Maintenance rules:

- True constitution content MUST live only in `studio/constitution/constitution.md` and `.specify/memory/constitution.md`.
- Runtime adapter files MUST NOT become competing constitutions.
- `AGENTS.md`, `CLAUDE.md`, and `.github/copilot-instructions.md` MUST contain the same generated `GENERATED GOVERNANCE BOOTSTRAP` block.
- Tool-specific wrapper text MAY differ, but shared governance additions MUST be made in the generated bootstrap block and synchronized across all three adapters.
- When one adapter changes, the other two MUST be synchronized before commit.
- When `studio/constitution/constitution.md` changes, root adapters and new-project bootstrap templates MUST continue to reference the centralized Studio Constitution path and current version metadata.
- Projects MUST reference the centralized Studio Constitution; project-local copies of the Studio Constitution are prohibited.

## 10.1 LLM-Friendly Document Formatting

All AI-generated `.md` files MUST follow these formatting rules:

**MUST Use:**

| Format | Use Case |
|--------|----------|
| Markdown tables | Structured data, comparisons, path listings |
| Numbered/bullet lists | Sequential or non-sequential items |
| Inline code backticks | File paths, commands, identifiers |
| Plain text descriptions | Explaining relationships and data flow |

**MUST NOT Use:**

| Format | Problem | Alternative |
|--------|---------|------------|
| ASCII art / box diagrams | Low information density, wastes tokens | Tables or text |
| Tree structures (`├──`, `└──`) | Ambiguous LLM parsing | Path tables |
| Arrow symbols (`→`, `←`, `⇒`) | Inconsistent encoding | "to", "from", or dashes |
| Emoji in SDD documents | Unpredictable tokenization | Text markers `[OK]`, `[WARN]` |

**Emoji Policy by File Type:**

| File Type | Emoji Allowed |
|-----------|---------------|
| `constitution.md`, `copilot-instructions.md` | NO |
| `spec.md`, `readiness/**/*.md`, `plan.md`, `tasks.md` | NO |
| `README.md`, human-facing docs | YES |
| `learnings.md`, `retrospective.md` | YES |

## 11. Required Project Structure

Each project MUST contain the following base paths. Items marked "when required" or "when triggered" are conditional on their trigger criteria being met (see relevant sections for details):

| Path | Purpose |
|------|--------|
| .specify/memory/constitution.md | Project-level canonical constitution when project-specific rules exist |
| AGENTS.md | Codex / Copilot CLI runtime adapter; not a constitution |
| .github/copilot-instructions.md | GitHub Copilot project context only; not a constitution |
| CLAUDE.md | Claude project context only; not a constitution |
| `specs/<feature>/spec.md` | Feature specification |
| `specs/<feature>/intent-ledger.md` | Secondary artifact for represented / deferred / dropped core intent items when required |
| `specs/<feature>/readiness/` | Readiness assessment and route-specific packets |
| `specs/<feature>/readiness/eci/` | ECI dossier artifacts for external capability governance |
| `specs/<feature>/plan.md` | Technical plan |
| `specs/<feature>/tasks.md` | Task breakdown |
| `src/` | Source code |
| `docs/` | Documentation |
| `README.md` | Project overview |

## 12. Governance Rules

### Dual-Layer Compliance

Projects MUST comply with BOTH:

1. **Studio Constitution** — Universal rules, non-negotiable
2. **Project Constitution** — Project-specific additions (located at `<project>/.specify/memory/constitution.md`)

### What Project Constitution CAN Do

- Add project-specific terminology and glossary
- Define project-specific tech stack and conventions
- Add stricter rules (e.g., "all functions MUST have unit tests")
- Define project-specific review checklists
- Document client-specific requirements (future use)

### What Project Constitution CANNOT Do

- Relax or skip any Studio Constitution rules
- Skip any SDD stage
- Remove mandatory document sections or required governance artifacts (`spec`, `readiness`, `eci`, `intent-ledger` when triggered, `plan`, `tasks`)
- Override AI collaboration principles

### Defer Does Not Disappear

Approved scope compression does not erase original intent. When a core spec item is represented by
substitute capability, deferred, or dropped, that obligation remains governed through
`intent-ledger.md` until it is truthfully re-entered, explicitly dropped with owner signoff, or
fully delivered.

### Surface Truthfulness

If a feature uses an umbrella name while the current implementation only covers a representative
subset, `README.md`, `quickstart.md`, and `/speckit.analyze` outputs MUST disclose the current
coverage and known gaps clearly enough that readers will not mistake the shipped surface for the
full original intent.

This constitution currently requires documentation truthfulness only. UI-level truthfulness markers
or badges MAY be added later, but they are not mandatory in this patch.

### Mainline Update Notes

For this workspace governance repo, any branch intended to merge into `main` that changes
shared-layer governance, runtime agents, prompts, templates, hooks, shared scripts, or their
canonical explanatory docs MUST add a dedicated update note under `docs/mainline-updates/`.

Additional rules:

- Each note MUST be indexed in `docs/mainline-updates/README.md`.
- One note MAY cover one coherent merge-ready batch; a separate note is not required for every
  individual commit.
- The note MUST summarize scope, impact, and validation, but it does not replace canonical runtime
  artifacts or the shared runtime audit.

### Conflict Resolution

If ambiguity exists between Studio and Project constitutions, Studio Constitution takes precedence.

Project agent context files such as AGENTS.md, .github/copilot-instructions.md, and CLAUDE.md MAY
summarize or reference the governing rules, but they MUST NOT be treated as the project
constitution.

### Versioning

- Versioning MUST follow Semantic Versioning
- Updates to Studio Constitution SHOULD trigger review of related templates

### Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.8.0 | 2026-04-27 | Added runtime agent bootstrap governance for AGENTS.md, CLAUDE.md, and .github/copilot-instructions.md synchronization. |
| 1.7.0 | 2026-04-10 | Shared-layer consistency update and document authority classification. |

### Document Authority and Update Order

All governed documents in this workspace belong to one of three authority layers:

| Authority Layer | Definition | Update Priority |
|-----------------|------------|-----------------|
| `source_of_truth` | The document that formally defines the requirement, rule, or behavior. Changes originate here. | First |
| `dependent` | Documents derived from or constrained by a source of truth. Must stay consistent with their source. | Second |
| `informational` | Overviews, indexes, or explanatory documents. May lag briefly if drift is tracked. | Third |

When a change propagates across multiple documents, the update order MUST follow the authority chain:

1. Update `source_of_truth` documents first.
2. Propagate to `dependent` documents.
3. Reconcile `informational` documents.

This ordering ensures that dependent documents always reference the current authoritative state,
not a stale version.

#### Workspace Document Authority Classification

**Source of Truth:**

- `studio/constitution/constitution.md` (governance)
- `studio/runtime/shared-runtime-contract.json` (runtime verification)
- `studio/runtime/impact-registry.json` (change-to-document impact routing)
- `.github/agents/*.agent.md` (agent runtime definitions)
- `studio/templates/sdd-docs/*.md` (document templates)
- `.githooks/pre-commit.ps1` (commit-time validation)
- `studio/scripts/powershell/*.ps1` (studio automation)
- `specs/<feature>/spec.md` (feature requirements, per-feature)
- `specs/<feature>/readiness/**/*.md` (readiness and ECI governance, per-feature)
- `docs/project-worktree-parity-governance.md` (worktree parity)

**Dependent:**

- `.claude/agents/*.md` (seeded from `.github/agents/`)
- `AGENTS.md` (workspace-level Codex / Copilot CLI runtime adapter, reflects constitution rules)
- `CLAUDE.md` (workspace-level Claude Code runtime adapter, reflects constitution rules)
- `.github/copilot-instructions.md` (workspace-level Copilot context, reflects constitution rules)
- `.github/agents/copilot-instructions.md` (agent-scoped subset of workspace copilot-instructions)
- `specs/<feature>/plan.md` (depends on spec, readiness, intent-ledger)
- `specs/<feature>/tasks.md` (depends on plan)
- `specs/<feature>/intent-ledger.md` (depends on spec, readiness)

**Informational:**

- `README.md` (workspace overview)
- `WORKSPACE_STRUCTURE.md` (architecture documentation)
- `studio/QUICKSTART.md` (onboarding guide)
- `studio/SDD-QUICKSTART-GUIDE.md` (methodology guide)
- `docs/mainline-updates/*.md` (merge explanation notes)

### Shared-Layer Verification

- Shared-layer convergence MUST be validated against studio runtime artifacts, templates, docs, hooks, and shared scripts.
- `projects/` and `learning/` are consumer spaces and MUST NOT be treated as the default acceptance surface for shared-layer convergence.
- The primary machine-verifiable shared-layer audit entrypoint is `studio/scripts/powershell/check-speckit-runtime.ps1 -Json`.
- The final shared-layer closure for readiness / eci MUST treat `studio/scripts/powershell/check-speckit-runtime.ps1 -Json` as the only machine-verifiable acceptance source.
- `docs/readiness_source/` MAY remain as design reference material, but it MUST NOT be treated as the canonical runtime acceptance surface.

## 13. Knowledge Capture (Mandatory)

Every completed project MUST include a knowledge capture phase. Requirements vary by project type (see Section 1.1).

## 13.1 Practice Projects (Lightweight)

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
- [ ] <description> (target: `studio/prompts/<stage>/`)
```

`retrospective.md` is OPTIONAL for Practice projects.

## 13.2 Internal / Client Projects (Full)

For Internal and Client projects, create `retrospective.md` in the project root with:

- **What went well?** — Practices worth repeating
- **What was painful?** — Friction points and blockers
- **What would I do differently?** — Lessons for next time
- **Time estimate vs actual** — For improving future estimates

Additionally, update `studio/knowledge-base/learnings.md` if significant learnings exist.

## 13.3 Asset Extraction Review

After each project (all types), ask:

- Any reusable prompt? Extract it to `studio/prompts/<stage>/`
- Any reusable template section? Extract it to `studio/templates/`
- Any pattern worth documenting? Record it in `learnings.md`

## 13.4 Constitution Review

If recurring friction points are found:

- Propose updates to Studio Constitution
- Document the change rationale in commit message or changelog

## 13.5 Knowledge Base Structure

| Path | Purpose |
|------|--------|
| `studio/knowledge-base/learnings.md` | Cumulative learnings (all projects) |
| `studio/knowledge-base/pain-points/` | Detailed pain point analysis (optional) |

### Enforcement

| Project Type | Completion Requirement |
|--------------|------------------------|
| Practice | `learnings.md` updated |
| Internal | `retrospective.md` exists + `learnings.md` updated (if applicable) |
| Client | `retrospective.md` exists + `learnings.md` updated (if applicable) |

