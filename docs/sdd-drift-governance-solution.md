# SDD Drift Governance Solution

> Historical design record. The change-manifest portions were superseded by R-G06 on 2026-07-13.
> Current merge reconciliation lives in `docs/mainline-updates/` and is enforced by Governance CI.

**Status:** Working Note
**Created:** 2026-04-10
**Depends On:** `docs/sdd-drift-governance-core-logic.md`
**Scope:** Concrete implementation design for multi-worktree SDD document drift governance within this
workspace

## Purpose

This document translates the ten governance principles defined in
`docs/sdd-drift-governance-core-logic.md` into concrete artifacts, schemas, and tooling extensions
designed for this workspace's existing infrastructure.

The design is additive. It builds on top of:

- `studio/runtime/shared-runtime-contract.json` (machine-verifiable invariants)
- `.githooks/pre-commit.ps1` (commit-time validation)
- `studio/scripts/powershell/check-speckit-runtime.ps1` (runtime audit)
- `studio/templates/sdd-docs/` (document templates)
- `docs/mainline-updates/` (merge-oriented change tracking)
- `/speckit.analyze` (cross-document consistency)
- `specs/<feature>/intent-ledger.md` (scope compression tracking)

It does not replace any of these mechanisms. It fills the gaps between them.

---

## Gap Analysis

Each of the ten principles is mapped to what currently exists and what is missing.

### Already Addressed

| Principle | Existing Coverage |
|-----------|-------------------|
| P8: Do not rely on LLM memory | `shared-runtime-contract.json` + `check-speckit-runtime.ps1` + pre-commit hooks provide evidence-based governance. Agent invariants are machine-checkable. |
| P10: Merge is the reconciliation point | Mainline update notes are merge-oriented. Worktree parity governance defines obligations. Pre-commit validates at commit time. |
| P4: Document authority layers (partial) | Constitution is declared as highest authority. `shared-runtime-contract.json` encodes which docs must contain which invariants. Studio templates are canonical sources. Authority order is understood by convention. |

### Gaps That Require New Artifacts

| Principle | Gap |
|-----------|-----|
| P1: Govern changes, not document links | No formal artifact that routes a specific change to impacted document layers. Readiness routes feature-level decisions but not per-change impact within a feature lifecycle. |
| P2: Relationship is not sync obligation | `sharedGatePaths` triggers a full audit when any listed path is touched. No distinction between "related" and "must update for this change type." |
| P3: Conditional impact rules | No per-document impact classification (reference / maybe_review / must_review / must_update). Currently binary: either a path triggers audit or it does not. |
| P4: Document authority layers (incomplete) | Documents do not self-declare their authority layer in machine-readable metadata. Authority is implied by path convention but not declared. |
| P5: Allow temporary drift, never unknown drift | No cross-worktree drift visibility artifact. If worktree A changes spec.md and worktree B changes plan.md for the same feature, nothing surfaces the divergence until merge conflict. |
| P6: Control per-step cognitive load | No formal batching mechanism. When a spec change cascades to 8 documents, there is no protocol for serial reconciliation. |
| P7: Large cascading changes = propagation work | Constitution mandates updates but provides no tracking for partial propagation (which docs are done, which are pending). |
| P9: Central index should be generated | `shared-runtime-contract.json` is the closest thing to a central index, but it is manually maintained and does not aggregate local document metadata. |

---

## Solution Architecture

The solution introduces four new mechanisms that close the gaps above.

```
                          change happens
                               |
                               v
                    +---------------------+
                    | 1. Change Manifest   |  (per-change routing artifact)
                    +---------------------+
                               |
              classifies change type + affected layers
                               |
                               v
                    +---------------------+
                    | 2. Impact Registry   |  (conditional routing rules)
                    +---------------------+
                               |
              determines: reference / maybe_review / must_review / must_update
                               |
                               v
                    +---------------------+
                    | 3. Propagation       |  (batched serial reconciliation)
                    |    Tracker           |
                    +---------------------+
                               |
              tracks: pending / done / skipped per document per change
                               |
                               v
                    +---------------------+
                    | 4. Merge Gate        |  (reconciliation enforcement)
                    +---------------------+
                               |
              blocks merge when unknown drift or unfinished propagation exists
```

---

## Mechanism 1: Change Manifest

### Problem Addressed

Principles 1, 3, 7: there is no artifact that says "this change affects these layers and these
documents need review or update."

### Design

A **change manifest** is a lightweight YAML-header Markdown file created when a change is expected to
propagate beyond the document being edited.

It is NOT required for every edit. It is required when:

- a spec change affects requirements that are already referenced in plan.md or tasks.md
- a constitution or template change affects multiple downstream documents
- a shared-layer change touches paths listed in `sharedGatePaths`

### Location

- Feature-scoped: `specs/<feature>/change-manifests/YYYY-MM-DD-<short-topic>.md`
- Shared-layer: `docs/change-manifests/YYYY-MM-DD-<short-topic>.md`

### Schema

```markdown
# Change Manifest: [SHORT TITLE]

**Date**: YYYY-MM-DD
**Change Type**: spec_change | constitution_change | template_change | agent_change | hook_change | script_change | doc_change
**Origin Document**: [path to the document where the change starts]
**Worktree**: [branch name or worktree identifier]
**Status**: open | propagating | closed

## Change Description

[1-3 sentences: what changed and why]

## Affected Authority Layer

- [ ] source_of_truth
- [ ] dependent
- [ ] informational

## Impact Assessment

| Document | Authority | Impact Level | Status | Notes |
|----------|-----------|--------------|--------|-------|
| [path] | source_of_truth | must_update | done | [origin of this change] |
| [path] | dependent | must_update | pending | [why this doc must update] |
| [path] | dependent | must_review | pending | [why review is needed] |
| [path] | informational | maybe_review | skipped | [why safe to skip] |
| [path] | informational | reference | -- | [no action needed] |

## Propagation Order

1. [first document to update, with reason]
2. [second document to update]
3. [third document to update]

## Completion Criteria

- [ ] All `must_update` rows are `done`
- [ ] All `must_review` rows are `done` or `skipped` with reason
- [ ] Status is `closed`
```

### Impact Level Definitions

| Level | Meaning | Action Required |
|-------|---------|-----------------|
| `must_update` | This document MUST be updated for this change type. Not updating it would create a known governance violation. | Update the document. Mark `done` when complete. |
| `must_review` | This document MUST be reviewed for this change type. It may or may not need an update. | Review. Mark `done` (updated) or `skipped` (reviewed, no update needed) with reason. |
| `maybe_review` | This document is related but only needs review if the change crosses a specific boundary. | Review if time permits. Mark `skipped` with reason if not reviewed. |
| `reference` | This document is related in knowledge but is not expected to need any action for this change type. | No action. Not tracked in propagation status. |

### Relationship to Existing Artifacts

- Change manifests are **not** mainline update notes. Mainline update notes describe a merge-ready
  batch for human understanding. Change manifests track per-change propagation status.
- Change manifests are **not** intent ledgers. Intent ledgers track scope compression for core spec
  items. Change manifests track document-level propagation for any change type.
- Change manifests may reference mainline update notes when the propagation is part of a
  shared-layer merge batch.

---

## Mechanism 2: Impact Registry

### Problem Addressed

Principles 2, 3, 4, 9: documents do not self-declare their authority layer or impact semantics,
and there is no machine-readable routing from change types to impacted documents.

### Design

The impact registry is a JSON file that declares:

1. The authority layer of each governed document
2. Conditional impact rules: which change types require which impact levels on which documents

This replaces the need for LLMs to infer document relationships from scratch. It also replaces the
binary `sharedGatePaths` trigger with conditional routing.

### Location

`studio/runtime/impact-registry.json`

### Schema

```json
{
  "documentAuthority": [
    {
      "path": "studio/constitution/constitution.md",
      "authority": "source_of_truth",
      "domain": "governance",
      "description": "Highest governance authority for all projects and workflows"
    },
    {
      "path": "README.md",
      "authority": "informational",
      "domain": "overview",
      "description": "Workspace overview, must reflect current governance state"
    },
    {
      "path": "WORKSPACE_STRUCTURE.md",
      "authority": "informational",
      "domain": "structure",
      "description": "Architecture documentation, must reflect current directory layout"
    },
    {
      "path": "studio/runtime/shared-runtime-contract.json",
      "authority": "source_of_truth",
      "domain": "runtime_verification",
      "description": "Machine-verifiable invariants for all governance requirements"
    },
    {
      "path": ".github/agents/*.agent.md",
      "authority": "source_of_truth",
      "domain": "agent_runtime",
      "description": "Copilot agent definitions, source for Claude agent mirrors"
    },
    {
      "path": ".claude/agents/*.md",
      "authority": "dependent",
      "domain": "agent_runtime",
      "description": "Claude agent definitions, seeded from .github/agents/"
    },
    {
      "path": "studio/templates/sdd-docs/*.md",
      "authority": "source_of_truth",
      "domain": "templates",
      "description": "Canonical document templates for SDD workflow"
    },
    {
      "path": "studio/QUICKSTART.md",
      "authority": "informational",
      "domain": "onboarding",
      "description": "Chinese-language onboarding guide"
    },
    {
      "path": "studio/SDD-QUICKSTART-GUIDE.md",
      "authority": "informational",
      "domain": "onboarding",
      "description": "Comprehensive SDD methodology guide"
    },
    {
      "path": ".github/copilot-instructions.md",
      "authority": "dependent",
      "domain": "agent_context",
      "description": "Copilot project context, must reflect governance rules"
    },
    {
      "path": ".githooks/pre-commit.ps1",
      "authority": "source_of_truth",
      "domain": "hooks",
      "description": "Commit-time validation logic"
    },
    {
      "path": "studio/scripts/powershell/check-speckit-runtime.ps1",
      "authority": "source_of_truth",
      "domain": "runtime_verification",
      "description": "Runtime audit entrypoint"
    },
    {
      "path": "docs/mainline-updates/README.md",
      "authority": "informational",
      "domain": "change_tracking",
      "description": "Index of mainline update notes"
    }
  ],

  "impactRouting": [
    {
      "changeType": "constitution_change",
      "description": "Any change to studio/constitution/constitution.md",
      "rules": [
        { "target": "studio/runtime/shared-runtime-contract.json", "impact": "must_review" },
        { "target": ".github/agents/*.agent.md", "impact": "must_review" },
        { "target": ".claude/agents/*.md", "impact": "must_review" },
        { "target": "studio/templates/sdd-docs/*.md", "impact": "must_review" },
        { "target": "README.md", "impact": "must_update" },
        { "target": "WORKSPACE_STRUCTURE.md", "impact": "maybe_review" },
        { "target": "studio/QUICKSTART.md", "impact": "must_update" },
        { "target": "studio/SDD-QUICKSTART-GUIDE.md", "impact": "must_update" },
        { "target": ".github/copilot-instructions.md", "impact": "must_review" },
        { "target": ".githooks/pre-commit.ps1", "impact": "maybe_review" }
      ]
    },
    {
      "changeType": "agent_change",
      "description": "Any change to .github/agents/ runtime agent definitions",
      "rules": [
        { "target": "studio/runtime/shared-runtime-contract.json", "impact": "must_review" },
        { "target": ".claude/agents/*.md", "impact": "must_update" },
        { "target": "studio/templates/sdd-agents/*.md", "impact": "must_update" },
        { "target": "studio/constitution/constitution.md", "impact": "reference" },
        { "target": "README.md", "impact": "reference" }
      ]
    },
    {
      "changeType": "template_change",
      "description": "Any change to studio/templates/sdd-docs/",
      "rules": [
        { "target": "studio/runtime/shared-runtime-contract.json", "impact": "must_review" },
        { "target": ".github/agents/*.agent.md", "impact": "maybe_review" },
        { "target": "studio/constitution/constitution.md", "impact": "maybe_review" },
        { "target": "README.md", "impact": "reference" }
      ]
    },
    {
      "changeType": "hook_change",
      "description": "Any change to .githooks/ validation logic",
      "rules": [
        { "target": "studio/runtime/shared-runtime-contract.json", "impact": "must_review" },
        { "target": "studio/constitution/constitution.md", "impact": "maybe_review" },
        { "target": "studio/QUICKSTART.md", "impact": "maybe_review" }
      ]
    },
    {
      "changeType": "script_change",
      "description": "Any change to studio/scripts/powershell/",
      "rules": [
        { "target": "studio/runtime/shared-runtime-contract.json", "impact": "must_review" },
        { "target": ".githooks/pre-commit.ps1", "impact": "maybe_review" }
      ]
    },
    {
      "changeType": "spec_change",
      "description": "Any change to specs/<feature>/spec.md that affects requirements referenced in downstream artifacts",
      "rules": [
        { "target": "specs/<feature>/readiness/readiness-assessment.md", "impact": "must_review" },
        { "target": "specs/<feature>/intent-ledger.md", "impact": "must_review" },
        { "target": "specs/<feature>/plan.md", "impact": "must_update" },
        { "target": "specs/<feature>/tasks.md", "impact": "must_update" }
      ]
    },
    {
      "changeType": "contract_change",
      "description": "Any change to studio/runtime/shared-runtime-contract.json",
      "rules": [
        { "target": ".githooks/pre-commit.ps1", "impact": "must_review" },
        { "target": "studio/scripts/powershell/check-speckit-runtime.ps1", "impact": "must_review" },
        { "target": "studio/constitution/constitution.md", "impact": "maybe_review" }
      ]
    },
    {
      "changeType": "doc_change",
      "description": "Changes to README.md, WORKSPACE_STRUCTURE.md, or other informational docs",
      "rules": [
        { "target": "studio/runtime/shared-runtime-contract.json", "impact": "maybe_review" }
      ]
    }
  ]
}
```

### How It Replaces Raw `sharedGatePaths`

Currently `sharedGatePaths` is a flat list: if any listed path is in the commit, trigger a full
runtime audit. The impact registry adds a conditional layer:

1. Pre-commit hook detects which `sharedGatePaths` are in the staged diff
2. Pre-commit classifies the change type from the path pattern
3. Impact registry returns the specific documents and impact levels for that change type
4. The hook warns about `must_update` / `must_review` documents that are not also in the staged diff

`sharedGatePaths` remains as the trigger set. The impact registry adds routing intelligence on top.

### Generation Strategy (Principle 9)

Phase 1 (current design): the impact registry is manually authored and maintained alongside
`shared-runtime-contract.json`. This is acceptable because:

- the workspace has a bounded document set (roughly 40 governed paths)
- the solo developer already maintains `shared-runtime-contract.json` manually
- the incremental maintenance cost is low

Phase 2 (future): documents carry local YAML frontmatter declaring their authority layer and
domain. A generation script reads all frontmatter and rebuilds `impact-registry.json`. This
inverts the maintenance direction: local metadata becomes the source, the registry becomes derived.

Example future frontmatter:

```yaml
---
authority: source_of_truth
domain: governance
impact_on_change:
  - target: README.md
    level: must_update
  - target: studio/QUICKSTART.md
    level: must_update
---
```

Phase 2 is not required for the registry to be useful. Phase 1 is sufficient to close the current
gaps.

---

## Mechanism 3: Propagation Tracker

### Problem Addressed

Principles 5, 6, 7: large cascading changes have no tracking mechanism for partial propagation, no
batching protocol, and no visibility into known-but-unreconciled drift.

### Design

The propagation tracker is the **Status** column and **Propagation Order** section within each
change manifest. It is not a separate artifact.

This is deliberate: creating a separate propagation database would violate the solo-dev principle of
minimal artifact surface. The change manifest already contains the impact assessment table. Adding
status tracking to each row turns it into a propagation tracker.

### Batching Protocol (Principle 6)

When a change manifest lists more than 5 `must_update` or `must_review` documents, the LLM MUST
process them in batches following the authority order:

**Batch 1: Source of Truth documents**

- Update all `source_of_truth` documents first
- These set the authoritative state that dependent documents will reference
- Maximum 3 documents per reasoning step

**Batch 2: Dependent documents**

- Update `dependent` documents that reference the changed source of truth
- Read the updated source of truth, not the pre-change version
- Maximum 3 documents per reasoning step

**Batch 3: Informational documents**

- Update `informational` documents last
- These may lag briefly if the change manifest tracks them as `pending`
- Maximum 5 documents per reasoning step (informational updates are typically lighter)

After each batch:

- Mark completed rows as `done` in the change manifest
- If the session is interrupted, the manifest preserves progress
- The next session can resume from the first `pending` row

### Cross-Worktree Drift Visibility (Principle 5)

In a multi-worktree environment, each worktree may create its own change manifests. Drift becomes
visible through two mechanisms:

1. **At commit time**: the pre-commit hook can check whether any open change manifests exist with
   `pending` rows. If so, it warns that propagation is incomplete. This is a warning, not a block,
   because partial commits during propagation are normal.

2. **At merge time**: the merge gate (Mechanism 4) checks whether open change manifests exist on
   the branch being merged. Unfinished propagation MUST be resolved or explicitly deferred before
   merge.

3. **Cross-worktree**: when two worktrees touch the same feature's documents, their change manifests
   will reference overlapping document paths. During merge, Git's normal conflict detection surfaces
   the overlap. The change manifests provide context for resolving the conflict: the reviewer can see
   what each worktree intended and which propagation steps are complete.

### When Propagation Tracking Is Not Needed

Not every change needs a propagation tracker. The overhead is justified only when:

- the change manifest lists 3 or more `must_update` / `must_review` rows
- the change spans more than one authority layer
- the work is expected to take more than one session

For smaller changes, the impact assessment table is sufficient without detailed status tracking.

---

## Mechanism 4: Merge Reconciliation Gate

### Problem Addressed

Principle 10: merge is the reconciliation point, but no merge-specific check exists beyond
pre-commit validation of individual document structure.

### Design

The merge gate is an extension to the pre-commit hook and an addition to the merge checklist in
mainline update notes.

### Pre-Merge Checklist (Manual)

Before creating a PR or merging to main, the developer MUST verify:

1. All change manifests on the branch are `closed` or explicitly deferred with reason
2. All `must_update` rows in open manifests are `done`
3. All `must_review` rows are `done` or `skipped` with documented reason
4. `check-speckit-runtime.ps1 -Json` passes
5. If intent ledger exists, `/speckit.analyze` Intent Drift Check passes

### Pre-Commit Hook Extension

Add a new check phase to `.githooks/pre-commit.ps1`:

```
Phase: Change Manifest Completeness (warning only)

For each change manifest in the staged diff:
  - If Status is 'open' or 'propagating':
    - Count pending must_update rows
    - Count pending must_review rows
    - If any pending must_update exists:
      - WARN: "Change manifest [path] has [N] pending must_update items"
    - If all must_update are done but must_review items are pending:
      - INFO: "Change manifest [path] has [N] pending must_review items"
```

This is a warning, not a block. Blocking would prevent incremental commits during propagation,
which contradicts the batching protocol.

### Mainline Update Note Extension

The mainline update note template already has a `Validation` section. Add a required line:

```markdown
## Validation

- `git diff --check`
- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json`
- Change manifests: [all closed / N deferred with reason]
```

### Integration with `shared-runtime-contract.json`

Add a new invariant section to the contract:

```json
{
  "changeManifestInvariants": [
    {
      "id": "mainline-update-note-manifest-validation",
      "path": "studio/templates/sdd-docs/mainline-update-note-template.md",
      "mustContainAll": [
        "Change manifests:"
      ]
    }
  ]
}
```

This ensures the template itself requires change manifest status reporting.

---

## Document Authority Classification

The following is the complete authority classification for all currently governed documents in this
workspace. This table is the human-readable form of the `documentAuthority` array in the impact
registry.

### Source of Truth

| Document | Domain | Governs |
|----------|--------|---------|
| `studio/constitution/constitution.md` | governance | All SDD workflow rules, project structure, AI collaboration |
| `studio/runtime/shared-runtime-contract.json` | runtime_verification | Machine-verifiable invariants for all governance |
| `.github/agents/*.agent.md` | agent_runtime | Copilot agent definitions, canonical source |
| `studio/templates/sdd-docs/*.md` | templates | Document templates for SDD workflow |
| `studio/templates/sdd-agents/*.md` | agent_templates | Agent template mirrors |
| `.githooks/pre-commit.ps1` | hooks | Commit-time validation rules |
| `studio/scripts/powershell/*.ps1` | scripts | Studio automation and runtime verification |
| `studio/runtime/impact-registry.json` | routing | Change-to-document impact routing rules |
| `specs/<feature>/spec.md` | feature | Feature requirements (per-feature source of truth) |
| `specs/<feature>/readiness/readiness-assessment.md` | feature | Planning safety classification |
| `specs/<feature>/readiness/eci/*.md` | feature | External capability governance |
| `docs/project-worktree-parity-governance.md` | governance | Worktree parity obligations |

### Dependent

| Document | Domain | Depends On |
|----------|--------|------------|
| `.claude/agents/*.md` | agent_runtime | `.github/agents/*.agent.md` (seeded via script) |
| `.github/copilot-instructions.md` | agent_context | `studio/constitution/constitution.md` |
| `specs/<feature>/plan.md` | feature | `spec.md`, `readiness-assessment.md`, `intent-ledger.md` |
| `specs/<feature>/tasks.md` | feature | `plan.md` |
| `specs/<feature>/intent-ledger.md` | feature | `spec.md`, `readiness-assessment.md` |

### Informational

| Document | Domain | Reflects |
|----------|--------|----------|
| `README.md` | overview | Current governance state, workflow sequence |
| `WORKSPACE_STRUCTURE.md` | structure | Current directory layout and conventions |
| `studio/QUICKSTART.md` | onboarding | Constitution rules in Chinese quickstart form |
| `studio/SDD-QUICKSTART-GUIDE.md` | onboarding | Full SDD methodology guide |
| `docs/mainline-updates/README.md` | change_tracking | Index of merge explanation notes |
| `docs/mainline-updates/*.md` | change_tracking | Individual merge batch explanations |

---

## Change Type Taxonomy

The following change types are recognized by the impact registry. Each type determines which
documents are candidates for impact assessment.

| Change Type | Trigger Condition | Typical Cascade Depth |
|-------------|-------------------|-----------------------|
| `constitution_change` | Edit to `studio/constitution/constitution.md` | Deep: touches contract, agents, templates, all informational docs |
| `contract_change` | Edit to `studio/runtime/shared-runtime-contract.json` | Medium: touches hooks, scripts, may touch constitution |
| `agent_change` | Edit to `.github/agents/*.agent.md` | Medium: touches Claude mirrors, agent templates, contract |
| `template_change` | Edit to `studio/templates/sdd-docs/*.md` | Shallow-to-medium: touches contract, possibly agents |
| `hook_change` | Edit to `.githooks/` | Shallow: touches contract, possibly quickstart |
| `script_change` | Edit to `studio/scripts/powershell/` | Shallow: touches contract, possibly hooks |
| `spec_change` | Edit to `specs/<feature>/spec.md` | Medium: touches readiness, ledger, plan, tasks (feature-scoped) |
| `doc_change` | Edit to informational docs | Shallow: may touch contract if invariant text changes |

---

## Implementation Phases

### Phase 0: Immediate (no new files needed)

Adopt the authority classification table above as a mental model. When making shared-layer changes,
consciously follow the update order: source of truth first, then dependent, then informational.

This requires zero new artifacts and immediately reduces unstructured drift.

### Phase 1: Change Manifest Template and Impact Registry

Deliverables:

1. `studio/templates/sdd-docs/change-manifest-template.md` -- template for change manifests
2. `studio/runtime/impact-registry.json` -- conditional impact routing rules
3. Update `studio/runtime/shared-runtime-contract.json`:
   - Add `impact-registry.json` to governed paths
   - Add change manifest template to `requiredDocTemplates`
   - Add mainline update note invariant for change manifest validation line
4. Update `studio/templates/sdd-docs/mainline-update-note-template.md`:
   - Add "Change manifests:" line to Validation section

### Phase 2: Pre-Commit Hook Extension

Deliverables:

1. Extend `.githooks/pre-commit.ps1`:
   - Detect staged change manifests
   - Warn on open manifests with pending `must_update` rows
   - Classify change type from staged file paths using impact registry
   - Warn when `must_update` targets are not in the staged diff
2. Update `studio/runtime/shared-runtime-contract.json` hook invariants

### Phase 3: Automated Impact Registry Generation (future)

Deliverables:

1. Define YAML frontmatter schema for document authority metadata
2. Add frontmatter to all governed documents
3. Create `studio/scripts/powershell/generate-impact-registry.ps1`
4. Update `check-speckit-runtime.ps1` to validate registry freshness

This phase inverts the maintenance direction: local metadata becomes the source, the registry
becomes derived. It is not required for the system to work but reduces long-term maintenance drift
on the registry itself.

---

## Integration with Existing Workflows

### SDD Feature Workflow

The seven-stage SDD workflow does not change. Change manifests are optional artifacts that appear
when a change at any stage is expected to propagate:

| Stage | When Change Manifest Is Relevant |
|-------|----------------------------------|
| `/speckit.specify` | Rarely. Spec creation does not propagate because downstream artifacts do not exist yet. |
| `/speckit.clarify` | Rarely. Unless clarification changes a requirement that was already referenced elsewhere. |
| `/speckit.readiness` | Sometimes. If readiness routing changes after plan/tasks already exist. |
| `/speckit.plan` | Sometimes. If plan decisions contradict or extend spec requirements. |
| `/speckit.tasks` | Rarely. Tasks are terminal artifacts that do not propagate upstream. |
| `/speckit.analyze` | Never creates manifests. Analyze may detect that a manifest should have been created. |
| `/speckit.implement` | Sometimes. Implementation discoveries that require spec/plan changes. |

### Shared-Layer Governance Workflow

For shared-layer changes (constitution, agents, templates, hooks, scripts):

1. Developer makes change to source of truth document
2. Developer creates change manifest (or the pre-commit hook reminds them)
3. Developer follows propagation order in the manifest
4. Developer marks rows as `done` as propagation completes
5. Developer creates mainline update note referencing the change manifest status
6. Merge gate verifies manifest closure

### `/speckit.analyze` Enhancement

`/speckit.analyze` should be extended to check:

- Whether any open change manifests exist for the feature being analyzed
- Whether pending `must_update` items in those manifests are consistent with the current document
  state
- Report open manifests as a finding (severity: Major if `must_update` items are pending)

This integrates drift visibility into the existing consistency-checking workflow.

---

## Relationship to `docs/sdd-drift-governance-core-logic.md`

| Core Logic Principle | Solution Mechanism |
|----------------------|--------------------|
| P1: Govern changes, not document links | Change manifest classifies change type and routes to specific documents |
| P2: Relationship is not sync obligation | Impact registry uses conditional levels (reference through must_update) |
| P3: Conditional impact rules | Impact registry `impactRouting` array with four impact levels |
| P4: Document authority layers | `documentAuthority` array + authority classification table |
| P5: Allow temporary drift, never unknown drift | Change manifest status tracking + pre-commit warnings |
| P6: Control per-step cognitive load | Batching protocol: max 3-5 docs per reasoning step, authority order |
| P7: Large cascading changes = propagation work | Change manifest with propagation order and completion criteria |
| P8: Do not rely on LLM memory | Impact registry is machine-readable; pre-commit hook enforces checks |
| P9: Central index should be generated | Phase 1: manual registry. Phase 3: generated from local frontmatter |
| P10: Merge is the reconciliation point | Merge gate checks manifest closure before merge |

---

## Non-Goals

This solution does not:

- Require every edit to have a change manifest (only propagating changes)
- Replace `shared-runtime-contract.json` (the contract remains the invariant verification source)
- Replace mainline update notes (notes remain for human merge context)
- Replace `/speckit.analyze` (analyze remains the cross-document consistency checker)
- Introduce CI/CD pipelines (validation remains hook-based and script-based)
- Require real-time cross-worktree synchronization (drift is tracked, not prevented)

---

## Open Questions

1. **Manifest granularity**: should one manifest cover a coherent batch of related changes (like
   mainline update notes), or should each individual propagating change get its own manifest?
   Recommendation: one manifest per coherent batch, matching the mainline update note granularity.

2. **Retention policy**: should closed change manifests be archived or deleted? Recommendation:
   keep them as historical record. They are small files and provide audit trail.

3. **Agent awareness**: should `/speckit.implement` automatically create change manifests when it
   detects spec/plan divergence during implementation? Recommendation: yes, but as a Phase 2
   enhancement after the manual workflow is validated.
