---
description: Perform a non-destructive cross-artifact consistency and quality analysis across spec.md, readiness artifacts, plan.md, and tasks.md after task generation.
model: claude-opus-4-6
infer: true
---

## Output Language

**Default: Traditional Chinese (zh-TW)**. Keep technical terms in English (API, OAuth2, design tokens, etc.). See `copilot-instructions.md` Language Strategy for details.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Goal

Identify inconsistencies, duplications, ambiguities, underspecified items, readiness-gate violations, and document drift across the core execution artifacts (`spec.md`, `readiness/*.md`, `readiness/eci/*.md`, `plan.md`, `tasks.md`) and any available supporting design artifacts (`data-model.md`, `contracts/`, `research.md`, `quickstart.md`) before implementation. This command MUST run only after `/speckit.tasks` has successfully produced a complete `tasks.md`.

## Operating Constraints

**STRICTLY READ-ONLY**: Do **not** modify any files. Output a structured analysis report. Offer an optional remediation plan (user must explicitly approve before any follow-up editing commands would be invoked manually).

**Constitution Authority**: The dual-layer constitution system is **non-negotiable** within this analysis scope:
- **Studio Constitution** (`studio/constitution/constitution.md`): Highest authority, always applies
- **Project Constitution** (`$PROJECT_ROOT/.specify/memory/constitution.md`): Optional, can only add stricter rules
Constitution conflicts are automatically CRITICAL and require adjustment of the spec, readiness artifacts, plan, or tasks—not dilution, reinterpretation, or silent ignoring of the principle. If a principle itself needs to change, that must occur in a separate, explicit constitution update outside `/speckit.analyze`.

## Execution Steps

### 1. Initialize Analysis Context

Run `studio/scripts/powershell/check-prerequisites.ps1 -Json -RequireTasks -IncludeTasks` once from repo root and parse JSON for FEATURE_DIR, AVAILABLE_DOCS, STUDIO_ROOT, and CONSTITUTIONS. Derive absolute paths:

- SPEC = FEATURE_DIR/spec.md
- READINESS_DIR = FEATURE_DIR/readiness
- READINESS_ASSESSMENT = READINESS_DIR/readiness-assessment.md
- PLAN = FEATURE_DIR/plan.md
- TASKS = FEATURE_DIR/tasks.md

Abort with an error message if any required file is missing (instruct the user to run the missing prerequisite command). Missing `readiness-assessment.md` is always a CRITICAL gate failure.
For single quotes in args like "I'm Groot", use escape syntax: e.g 'I'\''m Groot' (or double-quote if possible: "I'm Groot").

### 2. Load Artifacts (Progressive Disclosure)

Load only the minimal necessary context from each artifact:

**From spec.md:**

- Overview/Context
- Functional Requirements
- Non-Functional Requirements
- User Stories
- Edge Cases (if present)

**From readiness-assessment.md (REQUIRED):**

- Primary status
- Recommended next step
- Readiness Dimension Scan
- Primary Blocker Analysis
- Allowed / Not Allowed Next Actions
- Secondary observations

**From route-specific readiness packets (if present):**

- `eci-trigger.md`
- `repo-context-packet.md`
- `decision-record.md`
- `validation-contract.md`
- `access-setup-checklist.md`
- `exploration-boundary.md`

**From ECI dossier artifacts (if present):**

- `readiness/eci/eci-assessment.md`
- `readiness/eci/source-manifest.md`
- `readiness/eci/adoption-record.md`
- `readiness/eci/authorization-record.md`

**From plan.md:**

- Architecture/stack choices
- Data Model references
- Phases
- Technical constraints

**From data-model.md (if present):**

- Entity definitions
- Field/type expectations
- State transitions
- Invariants and relationship rules

**From contracts/ (if present):**

- Inputs / outputs
- Validation rules
- Processing rules
- Failure cases

**From research.md (if present):**

- Confirmed technical decisions
- Open constraints and unresolved assumptions

**From quickstart.md (if present):**

- Expected run / test workflows
- Environment assumptions that tasks implicitly rely on

**From tasks.md:**

- Task IDs
- Descriptions
- Phase grouping
- Priority / risk / story labels in checklist lines
- `Parallel with:` lines
- Dependency Summary
- Parallel Execution Examples
- Referenced file paths
- Document drift / conflict notes (if present)

**From constitution (dual-layer):**

- Load `studio/constitution/constitution.md` (REQUIRED - highest authority)
- Load `$PROJECT_ROOT/.specify/memory/constitution.md` if exists (optional, additive)
- Merge rules: Project constitution can only add stricter rules, never relax Studio rules

### 3. Build Semantic Models

Create internal representations (do not include raw artifacts in output):

- **Requirements inventory**: Each functional + non-functional requirement with a stable key (derive slug based on imperative phrase; e.g., "User can upload file" → `user-can-upload-file`)
- **Readiness guardrail inventory**: Primary status, route-specific prohibitions, allowed actions, and follow-up conditions
- **User story/action inventory**: Discrete user actions with acceptance criteria
- **Task coverage mapping**: Map each task to one or more requirements or stories (inference by keyword / explicit reference patterns like IDs or key phrases)
- **Entity / invariant inventory**: Core entities, state transitions, and invariants from `data-model.md`
- **Contract rule inventory**: Validation rules, processing rules, outputs, and failure cases from `contracts/`
- **Operational workflow inventory**: Expected developer workflows from `quickstart.md`
- **Constitution rule set**: Extract principle names and MUST/SHOULD normative statements

### 4. Detection Passes (Token-Efficient Analysis)

Focus on high-signal findings. Limit to 50 findings total; aggregate remainder in overflow summary.

#### A. Duplication Detection

- Identify near-duplicate requirements
- Mark lower-quality phrasing for consolidation

#### B. Ambiguity Detection

- Flag vague adjectives (fast, scalable, secure, intuitive, robust) lacking measurable criteria
- Flag unresolved placeholders (TODO, TKTK, ???, `<placeholder>`, etc.)

#### C. Underspecification

- Requirements with verbs but missing object or measurable outcome
- User stories missing acceptance criteria alignment
- Tasks referencing files or components not defined in spec/plan/data-model/contracts
- Tasks that leave core implementation choices unresolved even though supporting artifacts already define them

#### D. Readiness Gate Integrity

- Missing `readiness-assessment.md`
- Missing or ambiguous `Primary Status`
- `Primary Status` other than `READY_FOR_PLAN` while `plan.md` or `tasks.md` exists
- Latest readiness status is `ROUTE_TO_VALIDATION`, `ROUTE_TO_ACCESS`, or `ROUTE_TO_DECISION` after ECI re-entry, but `plan.md` or `tasks.md` already exists
- Required route packet missing for the declared primary status
- `ROUTE_TO_ECI` cases missing the expected `readiness/eci/*.md` dossier after ECI was supposedly completed
- Plan/tasks assumptions that violate readiness `Allowed` / `Not Allowed Next Actions`
- Plan/tasks assumptions that violate ECI `Allowed Implementation Scope`, `Explicit Prohibitions`, or adoption boundary
- Post-ECI readiness no longer routes to ECI, but plan/tasks still ignore sandbox-only or spike-only authorization constraints
- Spec, readiness assessment, and plan/tasks disagree on blocker type, execution boundary, or next-safe action
- Readiness, ECI authorization, and plan/tasks disagree on whether mainline implementation is currently authorized
- Readiness artifact clearly stale relative to current spec or plan/tasks scope (for example, spec changed materially but readiness still reflects an older blocker model)
- ECI dossier clearly stale relative to trigger/spec/plan assumptions (for example, plan names provider usage or versions outside the source manifest / adoption record)

#### E. Constitution Alignment

- Any requirement or plan element conflicting with a MUST principle
- Missing mandated sections or quality gates from constitution
- `tasks.md` checklist lines that violate the canonical format required by constitution/template (`T### [P#] [Risk: X] [Story: ...]`)

#### F. Coverage Gaps

- Requirements with zero associated tasks
- Tasks with no mapped requirement/story
- Non-functional requirements not reflected in tasks (e.g., performance, security)
- Data-model invariants or contract rules with no corresponding task coverage

#### G. Inconsistency

- Terminology drift (same concept named differently across files)
- Data entities referenced in plan but absent in spec (or vice versa)
- Readiness blocker analysis contradicted by plan or tasks
- ECI authorization or adoption boundary contradicted by plan or tasks
- Source manifest version / source basis contradicted by plan, contracts, or quickstart assumptions
- Data-model / contract rules contradicted by plan or tasks
- Task ordering contradictions (e.g., integration tasks before foundational setup tasks without dependency note)
- Task assumptions that conflict with quickstart or research decisions
- Conflicting requirements (e.g., one requires Next.js while other specifies Vue)

### 5. Severity Assignment

Use this heuristic to prioritize findings:

- **CRITICAL**: Violates constitution MUST, missing `readiness-assessment.md`, any non-`READY_FOR_PLAN` readiness state contradicted by plan/tasks existence, readiness prohibitions ignored, ECI authorization or adoption boundary contradicted by plan/tasks, or requirement with zero coverage that blocks baseline functionality
- **HIGH**: Duplicate or conflicting requirement, ambiguous security/performance attribute, untestable acceptance criterion
- **MEDIUM**: Terminology drift, missing non-functional task coverage, underspecified edge case, route packet incompleteness that weakens governance clarity
- **LOW**: Style/wording improvements, minor redundancy not affecting execution order

### 6. Produce Compact Analysis Report

Output a Markdown report (no file writes) with the following structure:

## Specification Analysis Report

| ID | Category | Severity | Location(s) | Summary | Recommendation |
|----|----------|----------|-------------|---------|----------------|
| A1 | Duplication | HIGH | spec.md:L120-134 | Two similar requirements ... | Merge phrasing; keep clearer version |

(Add one row per finding; generate stable IDs prefixed by category initial.)

**Coverage Summary Table:**

| Requirement Key | Has Task? | Task IDs | Notes |
|-----------------|-----------|----------|-------|

**Governance Gate Issues:** (if any)

**Supporting Artifact Alignment Issues:** (if any)

**Constitution Alignment Issues:** (if any)

**Unmapped Tasks:** (if any)

**Metrics:**

- Total Requirements
- Total Tasks
- Coverage % (requirements with >=1 task)
- Invariant Coverage % (data-model / contract rules with >=1 task, if supporting docs exist)
- Readiness Gate Issues Count
- Ambiguity Count
- Duplication Count
- Critical Issues Count

### 7. Provide Next Actions

At end of report, output a concise Next Actions block:

- If CRITICAL issues exist: Recommend resolving before `/speckit.implement`
- If readiness gate issues exist: Recommend re-running `/speckit.readiness` or completing the required remediation packet before touching plan/tasks/implementation
- If only LOW/MEDIUM: User may proceed, but provide improvement suggestions
- Provide explicit command suggestions: e.g., "Run /speckit.specify with refinement", "Run /speckit.eci to complete external capability governance", "Run /speckit.readiness to refresh gate status", "Run /speckit.plan to adjust architecture after gate clearance", "Manually edit tasks.md to add coverage for 'performance-metrics'", "Align data-model.md / contracts/ with task assumptions"

### 8. Offer Remediation

Ask the user: "Would you like me to suggest concrete remediation edits for the top N issues?" (Do NOT apply them automatically.)

## Operating Principles

### Context Efficiency

- **Minimal high-signal tokens**: Focus on actionable findings, not exhaustive documentation
- **Progressive disclosure**: Load artifacts incrementally; don't dump all content into analysis
- **Token-efficient output**: Limit findings table to 50 rows; summarize overflow
- **Deterministic results**: Rerunning without changes should produce consistent IDs and counts

### Analysis Guidelines

- **NEVER modify files** (this is read-only analysis)
- **NEVER hallucinate missing sections** (if absent, report them accurately)
- **Prioritize readiness and constitution violations** (these are always highest severity)
- **Use examples over exhaustive rules** (cite specific instances, not generic patterns)
- **Report zero issues gracefully** (emit success report with coverage statistics)

## Context

$ARGUMENTS
