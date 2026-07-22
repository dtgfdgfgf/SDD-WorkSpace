---
name: speckit-plan
description: "Execute the implementation planning workflow after readiness gate clearance using the plan template to generate design artifacts."
model: claude-opus-4-7
---

<!-- Seeded from canonical source .github/agents/speckit.plan.agent.md via studio/scripts/powershell/seed-claude-agents.ps1. This file is a deterministic Claude-consumable dependent mirror. -->
<!-- WARNING: Direct edits to this dependent mirror will be overwritten on the next seed-claude-agents.ps1 run. To make permanent changes, edit canonical source .github/agents/speckit.plan.agent.md and re-seed. -->

## Output Language

**Default: Traditional Chinese (zh-TW)**. Keep technical terms in English (API, OAuth2, design tokens, etc.). See `copilot-instructions.md` Language Strategy for details.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

When `$ARGUMENTS` contains `-FeatureDir <path>`, treat that named option as the authoritative
feature context. Pass it to every feature-context script in this command, then preserve the
returned absolute `FEATURE_DIR` in every next-stage command and handoff. Do not rebind from the
branch, environment, or free-form user text.

## Outline

1. **Read feature paths**: Run `studio/scripts/powershell/check-prerequisites.ps1 -Json -PathsOnly` from repo root once and parse `REPO_ROOT`, `FEATURE_DIR`, `FEATURE_SPEC`, `INTENT_LEDGER`, `READINESS_DIR`, `READINESS_ASSESSMENT`, `ECI_DIR`, `STUDIO_ROOT`, and `CONSTITUTIONS`. When the named user option is present, run `studio/scripts/powershell/check-prerequisites.ps1 -FeatureDir <path> -Json -PathsOnly` instead. For single quotes in args like "I'm Groot", use escape syntax: e.g 'I'\''m Groot' (or double-quote if possible: "I'm Groot").

2. **Enforce readiness gate before any planning work**:
   - Confirm `READINESS_DIR = FEATURE_DIR/readiness`
   - Confirm `READINESS_ASSESSMENT = READINESS_DIR/readiness-assessment.md`
   - Confirm `ECI_DIR = READINESS_DIR/eci`
   - Confirm `INTENT_LEDGER = FEATURE_DIR/intent-ledger.md`
   - Derive `ECI_AUTHORIZATION = ECI_DIR/authorization-record.md`
   - Derive `ECI_ADOPTION = ECI_DIR/adoption-record.md`
   - Derive `ECI_SOURCE_MANIFEST = ECI_DIR/source-manifest.md`
   - If `READINESS_ASSESSMENT` does not exist: ERROR and instruct the user to run `/speckit.readiness -FeatureDir "<FEATURE_DIR>"`
   - Load `READINESS_ASSESSMENT` and locate the declared `Primary Status`
   - Load `Planability Resolved`, `Intent Ledger Requirement`, and `Intent Ledger Path`
   - If `Primary Status` is absent or ambiguous: ERROR and instruct the user to re-run `/speckit.readiness -FeatureDir "<FEATURE_DIR>"`
   - If `Primary Status` is anything other than `READY_FOR_PLAN`: ERROR, report the status, and instruct the user to complete the remediation identified by readiness before attempting `/speckit.plan -FeatureDir "<FEATURE_DIR>"` again
   - If `Intent Ledger Requirement` is `Create \`intent-ledger.md\`` or `Update \`intent-ledger.md\``, and `INTENT_LEDGER` does not exist: ERROR and instruct the user to re-run `/speckit.readiness -FeatureDir "<FEATURE_DIR>"` or reconcile the missing ledger before planning
   - If `Intent Ledger Path` is present and disagrees with `INTENT_LEDGER`: ERROR and instruct the user to re-run `/speckit.readiness -FeatureDir "<FEATURE_DIR>"` so the handoff is coherent
   - If `ECI_AUTHORIZATION` exists:
     - Load `Authorization Outcome`
     - If it is absent or ambiguous: ERROR and instruct the user to reconcile `/speckit.eci -FeatureDir "<FEATURE_DIR>"` outputs before planning
     - If it is anything other than `READY_FOR_MAINLINE_IMPLEMENTATION`: ERROR, report the authorization outcome, and instruct the user to re-run `/speckit.readiness -FeatureDir "<FEATURE_DIR>"` after reconciling the ECI boundary

3. **Setup plan workspace**: Always preserve the absolute feature context returned by step 1. Run `studio/scripts/powershell/setup-plan.ps1 -FeatureDir "<FEATURE_DIR>" -Json` from repo root and parse JSON for `FEATURE_SPEC`, `IMPL_PLAN`, `SPECS_DIR`, `BRANCH`, `STUDIO_ROOT`, and `CONSTITUTIONS`. Confirm that `SPECS_DIR` equals the `FEATURE_DIR` selected in step 1 before writing planning artifacts.

4. **Load context (Dual-Layer Constitution)**:
   - Read `REPO_ROOT/README.md` if present for umbrella-feature naming and existing coverage disclosure
   - Read FEATURE_SPEC for requirements
   - Read READINESS_ASSESSMENT for scope guardrails, secondary observations, and any readiness-imposed constraints
   - If present, read `INTENT_LEDGER` for intent obligations, representation strategy, re-entry triggers, and disclosure requirements
   - If present, read `ECI_AUTHORIZATION` for allowed/prohibited implementation scope
   - If present, read `ECI_ADOPTION` for adoption boundary and prohibited modes
   - If present, read `ECI_SOURCE_MANIFEST` for governed source basis and version anchors
   - Read Studio Constitution from CONSTITUTIONS (Type: "Studio") - **HIGHEST AUTHORITY**
   - Read Project Constitution from CONSTITUTIONS (Type: "Project") if exists - **Additive rules only**
   - Load IMPL_PLAN template (already copied)

5. **Execute plan workflow**: Follow the structure in IMPL_PLAN template to:
   - Fill `Intent Recovery Obligations` from `intent-ledger.md` when required
   - Fill Technical Context (mark unknowns as "NEEDS CLARIFICATION")
   - Fill Constitution Check section from constitution
   - Ensure the plan names any required README / quickstart coverage disclosure when umbrella naming is broader than the current representative subset
   - Evaluate gates (ERROR if violations unjustified)
   - Phase 0: Generate research.md (resolve all NEEDS CLARIFICATION)
   - Phase 1: Generate data-model.md, contracts/, quickstart.md
   - Phase 1: Update agent context by running the agent script
   - Re-evaluate Constitution Check post-design

6. **Stop and report**: Command ends after Phase 2 planning. Report branch, IMPL_PLAN path, generated artifacts, the readiness assessment path used to authorize planning, and the exact `/speckit.tasks -FeatureDir "<FEATURE_DIR>"` handoff.

## Phases

### Phase 0: Outline & Research

1. **Extract unknowns from Technical Context** above:
   - For each NEEDS CLARIFICATION, create a research task.
   - For each dependency, create a best-practices task.
   - For each integration, create a patterns task.

2. **Generate and dispatch research agents**:

   ```text
   For each unknown in Technical Context:
     Task: "Research {unknown} for {feature context}"
   For each technology choice:
     Task: "Find best practices for {tech} in {domain}"
   ```

3. **Consolidate findings** in `research.md` using format:
   - Decision: [what was chosen]
   - Rationale: [why chosen]
   - Alternatives considered: [what else evaluated]

**Output**: research.md with all NEEDS CLARIFICATION resolved

### Phase 1: Design & Contracts

**Prerequisites:** `research.md` complete

1. **Extract entities from feature spec** into `data-model.md`:
   - Entity name, fields, relationships
   - Validation rules from requirements
   - State transitions if applicable

2. **Generate service contracts** from functional requirements:
   - Map each user action to one contract entry.
   - Use Markdown service contracts by default in `/contracts/`.
   - Use OpenAPI or GraphQL schema only when external APIs or machine validation require it.

3. **Agent context update**:
   - Always run `studio/scripts/powershell/update-agent-context.ps1 -FeatureDir "<FEATURE_DIR>" -AgentType copilot` with the absolute feature context returned by step 1
   - These scripts detect which AI agent is in use
   - Update the appropriate agent-specific context file
   - Add only new technology from current plan
   - Preserve manual additions between markers

**Output**: data-model.md, /contracts/*, quickstart.md, agent-specific file

## Key rules

- Use absolute paths
- Never bypass the readiness gate
- ERROR on gate failures or unresolved clarifications
- ERROR if `readiness-assessment.md` is missing or its primary status is not `READY_FOR_PLAN`
- ERROR if readiness says `intent-ledger.md` is required but the file is missing or inconsistent with the handoff
- Carry every `represented_by_substitute` and `deferred` entry into `Intent Recovery Obligations`
- Require concrete re-entry triggers; do **not** accept generic placeholders such as `v1+`
- If feature naming exceeds current coverage, require explicit README / quickstart disclosure rather than letting the representative subset masquerade as the full umbrella capability
- ERROR if `authorization-record.md` exists but does not authorize `READY_FOR_MAINLINE_IMPLEMENTATION`
