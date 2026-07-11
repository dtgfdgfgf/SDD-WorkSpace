# Workspace Structure Design

**Version:** 1.8.0
**Created:** 2025-12-08  
**Updated:** 2026-04-30
**Owner:** Solo AI Engineer  
**Methodology:** Specification-Driven Development (SDD)

## Overview

This workspace is a studio-first Spec Kit variant. Governance, runtime agents, prompts, templates,
extensions, and generated exports are centralized at the workspace level. Projects consume those
shared assets without turning each repo into a fully self-contained upstream Spec Kit clone.

Design priorities:

- Single source of truth for governance and runtime agents
- Dual-layer constitutions with additive project rules
- Predictable initialization for Practice, Internal, and Client projects
- Controlled template customization without losing studio defaults
- Additive upstream alignment through shared-layer capabilities instead of repo-local migration

## Root Layout

| Path | Purpose |
|------|---------|
| `.github/copilot-instructions.md` | Workspace-level Copilot rules |
| `.github/agents/` | Runtime source for shared SDD agents |
| `.claude/agents/` | Runtime source for shared Claude agents |
| `.github/prompts/` | Runtime source for shared prompt assets |
| `learning/<project>/` | Practice projects |
| `projects/<project>/` | Internal, Client, and historical sample projects |
| `docs/project-governance-status.md` | Central governance compatibility ledger for consumer projects |
| `docs/project-worktree-parity-governance.md` | Canonical governance policy for consumer-project derived worktree parity |
| `docs/mainline-updates/` | Centralized explanation notes for main-bound shared-layer update batches |
| `archive/` | Archived or deprecated items |
| `resources/` | Shared resources |
| `resources/agent-skill-packs/` | Generated AI skill packs exported from shared runtime sources |
| `WORKSPACE_STRUCTURE.md` | This document |

## Studio Canonical Sources

| Path | Purpose |
|------|---------|
| `studio/constitution/constitution.md` | Highest-authority studio governance |
| `studio/runtime/shared-runtime-contract.json` | Machine-verifiable shared runtime contract for studio-only convergence |
| `studio/extensions/` | Canonical shared extension source, manifest schema, catalog, and state |
| `studio/workflows/` | Canonical shared workflow runtime: schemas, catalog, state, POLICY, and built-in `sdd-pipeline/` |
| `studio/templates/project-init/` | Project bootstrap skeleton |
| `studio/templates/sdd-docs/` | Canonical document templates |
| `studio/knowledge-base/learnings.md` | Cross-project learning capture |
| `studio/prompts/<stage>/` | Stage-specific reusable prompts |
| `studio/scripts/powershell/` | Studio automation scripts |

## Project-Level Structure

Each project is expected to contain:

| Path | Purpose |
|------|---------|
| `.specify/memory/constitution.md` | Project-level canonical constitution |
| `.github/agents/` | Junction to workspace `.github/agents/` |
| `.claude/agents/` | Junction to workspace `.claude/agents/` |
| `AGENTS.md` | Codex / Copilot CLI runtime adapter |
| `CLAUDE.md` | Claude Code runtime adapter |
| `.github/copilot-instructions.md` | GitHub Copilot project context |
| `specs/<feature>/spec.md` | Feature specification |
| `specs/<feature>/intent-ledger.md` | Secondary artifact for represented / deferred / dropped core intent items when required |
| `specs/<feature>/readiness/` | Readiness assessment and route-specific packets |
| `specs/<feature>/readiness/eci/` | ECI dossier artifacts for external capability governance |
| `specs/<feature>/plan.md` | Technical plan |
| `specs/<feature>/tasks.md` | Task decomposition |
| `specs/<feature>/contracts/` | Markdown or machine-readable service contracts |
| `src/` | Source code |
| `docs/` | Documentation |
| `README.md` | Project overview and project type declaration |

Fresh consumer projects are independent Git repositories. Their Git root MUST be the project root,
and their `core.hooksPath` points back to the workspace `.githooks` directory so project-local
commits still run the shared governance gates.

Derived worktrees created from these projects MUST preserve the same project-operational surface
expected of the source project. They are not considered healthy merely because the tracked tree
exists. The canonical rule for this parity model is `docs/project-worktree-parity-governance.md`.

## Design Decisions

### 1. Dual-Layer Constitutions

| Layer | File | Purpose |
|-------|------|---------|
| Studio | `studio/constitution/constitution.md` | Universal methodology and quality gates |
| Project | `<project>/.specify/memory/constitution.md` | Additive domain rules and stricter standards |

Notes:

- Project constitutions can only add stricter rules.
- `AGENTS.md`, `CLAUDE.md`, and `.github/copilot-instructions.md` are synchronized runtime adapters, not constitutions.

### 2. Runtime Agent Source

The runtime source of truth is:

- `.github/agents/`
- `.claude/agents/`
- `.github/prompts/`

Agent definitions live in `.github/agents/` (source of truth) and `.claude/agents/` (seeded copy with Claude-specific format).

Project-local Claude agents are not supported in this workspace model.

### 3. Extension Registry

`studio/extensions/` is the canonical shared extension registry for this workspace. Manifests live
under `studio/extensions/<extension-id>/manifest.json`, while `catalog.json` and `state.json`
control curated visibility and enable/disable state at the workspace level.

Rules:

- Extensions are workspace-level shared capabilities, not project-local customization dumps.
- `catalog.json` controls curated registration metadata.
- `state.json` controls enable/disable state.
- No extension registry data belongs under `<project>/.specify/` or `<project>/.github/`.

### 4. Generated Skill Packs

`resources/agent-skill-packs/<agent>/` stores generated skill pack exports for skill-based agent
ecosystems. These exports are mirrors built from `.github/agents/` and `.github/prompts/`; they are
not a new source of truth and should be regenerated rather than edited by hand. Claude skills
install roots are a separate install/export layer and do not replace workspace `/.claude/agents/`
authority.

`readiness-assessment.md` remains the latest authoritative gate state for each feature. The
`readiness/eci/` dossier is supporting governance input during post-ECI re-entry and does not
replace the requirement to re-run readiness before planning.

`intent-ledger.md` is a secondary artifact rather than a new stage. It exists only when approved
scope compression affects core spec items through representative coverage, deferral, or explicit
drop with owner signoff. When present, it becomes part of the formal handoff from readiness to
plan and must stay aligned with outward-facing coverage disclosure.

### 4.1 Shared-Layer Convergence Acceptance

- `projects/` 與 `learning/` 是 consumer spaces，不是 shared-layer convergence 的預設驗收面
- shared-layer convergence 的 DOD 只看 studio runtime、templates、docs、hooks 與 shared scripts
- `check-speckit-runtime.ps1 -Json` 是 shared runtime 的主要機器驗證入口
- `readiness / eci` 的最終 shared-layer 收斂，以 `check-speckit-runtime.ps1 -Json` 為唯一 machine-verifiable acceptance source
- `docs/readiness_source/` 保留為 design reference，不屬於 canonical runtime acceptance surface

### 4.2 Mainline Update Notes

`docs/mainline-updates/` 是這個 workspace governance repo 的集中更新說明區。任何準備合回
`main` 的 shared-layer 變更批次，只要動到治理文件、runtime agents、templates、hooks、
shared scripts 或其 canonical explanatory docs，都應新增一份專門說明檔並更新索引。

規則：

- 一份說明檔可以覆蓋一個 coherent merge-ready batch，不要求每個 commit 各寫一份
- 檔名格式使用 `YYYY-MM-DD-short-topic.md`
- 內容至少要說明 summary、why、affected paths、validation、merge notes
- 正式模板位於 `studio/templates/sdd-docs/mainline-update-note-template.md`

### 4.3 Project Worktree Parity

Consumer-project derived worktrees are project-equivalent instances, not reduced checkouts.

Rules:

- A derived worktree MUST preserve both tracked parity and required local bootstrap parity.
- `.git` appearing as a file in a derived worktree is normal Git plumbing, not evidence of damage.
- Public snapshot boundaries and `.gitignore` rules do not authorize the loss of required local
  operational assets.
- If a project declares additional local-only operational assets, derived worktrees MUST preserve
  them or use a documented equivalent source.

### 5. Template Strategy

Studio templates are the default baseline. Projects may add local overrides under
`.specify/templates/`, but scripts must continue to work when only studio templates exist.

Key template paths:

| Path | Purpose |
|------|---------|
| `studio/templates/sdd-docs/spec-template.md` | Specification template |
| `studio/templates/sdd-docs/intent-ledger-template.md` | Intent ledger template for compressed core scope |
| `studio/templates/sdd-docs/readiness-assessment-template.md` | Readiness assessment template |
| `studio/templates/sdd-docs/eci-assessment-template.md` | ECI assessment template |
| `studio/templates/sdd-docs/eci-source-manifest-template.md` | ECI source manifest template |
| `studio/templates/sdd-docs/eci-adoption-record-template.md` | ECI adoption record template |
| `studio/templates/sdd-docs/eci-authorization-record-template.md` | ECI authorization record template |
| `studio/templates/sdd-docs/repo-context-packet-template.md` | Repo context packet template |
| `studio/templates/sdd-docs/decision-record-template.md` | Decision record template |
| `studio/templates/sdd-docs/validation-contract-template.md` | Validation contract template |
| `studio/templates/sdd-docs/access-setup-checklist-template.md` | Access setup checklist template |
| `studio/templates/sdd-docs/eci-trigger-template.md` | ECI trigger template |
| `studio/templates/sdd-docs/exploration-boundary-template.md` | Exploration boundary template |
| `studio/templates/sdd-docs/plan-template.md` | Plan template |
| `studio/templates/sdd-docs/tasks-template.md` | Checklist-first task template |
| `studio/templates/sdd-docs/checklist-template.md` | Checklist template |
| `studio/templates/sdd-docs/agent-file-template.md` | Project agent context template |
| `studio/templates/sdd-docs/project-constitution-template.md` | Project constitution template |

### 6. Project Classification

| Type | Primary Location | Notes |
|------|------------------|-------|
| Practice | `learning/` | New learning projects |
| Internal | `projects/` | Studio tooling and internal delivery |
| Client | `projects/` | Client work |

`projects/japanese-learning/` remains a historical sample and regression fixture. It is not part of
the new project classification scheme for fresh practice work.

## Initialization Behavior

`init-practice.ps1` and `init-project.ps1` must:

1. Copy `studio/templates/project-init/`
2. Generate a project `README.md`
3. Preserve or create `.specify/memory/constitution.md`
4. Create a project `.code-workspace`
5. Create a `.github/agents/` junction to workspace runtime agents
6. Create a `.claude/agents/` junction to workspace Claude runtime agents
7. Initialize the project root as an independent Git repo with `git init -b main` when `.git/` is missing
8. Set the project repo `core.hooksPath` to the relative path for the workspace `.githooks`

The project template `.gitignore` excludes `.github/agents/` and `.claude/agents/` junction content
so consumer repos do not accidentally track shared runtime files.

These initialization rules govern creation of the root project instance. They do not by themselves
guarantee derived worktree parity. Derived worktree parity is a separate obligation governed by
`docs/project-worktree-parity-governance.md`.

Derived worktree bootstrap uses `studio/scripts/powershell/new-project-worktree.ps1` to preserve
the same shared junction model for Copilot and Claude runtime agents.

## Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Feature directory | `NNN-kebab-case` | `001-user-registration` |
| SDD docs | `lowercase.md` | `spec.md`, `intent-ledger.md`, `readiness-assessment.md`, `eci-trigger.md`, `eci-assessment.md`, `source-manifest.md`, `adoption-record.md`, `authorization-record.md`, `plan.md`, `tasks.md` |
| Templates | `kebab-case-template.md` | `spec-template.md` |
| Prompts | descriptive kebab-case | `clarify-ambiguity.md` |
| Extensions | `kebab-case` | `security-gates`, `client-review` |

## Related Documents

| Document | Purpose |
|----------|---------|
| `studio/constitution/constitution.md` | Governance baseline |
| `docs/project-governance-status.md` | Central project governance compatibility ledger |
| `docs/project-worktree-parity-governance.md` | Canonical consumer-project derived worktree parity policy |
| `docs/mainline-updates/README.md` | Central index and usage guide for main-bound update notes |
| `AGENTS.md` | Workspace Codex / Copilot CLI runtime adapter |
| `CLAUDE.md` | Workspace Claude Code runtime adapter |
| `.github/copilot-instructions.md` | Workspace AI collaboration rules |
| `studio/QUICKSTART.md` | Fast-start instructions |
| `studio/SDD-QUICKSTART-GUIDE.md` | Full workflow guide |
| `spec-kit-upstream-wave2-transition-guide.md` | Wave 2 upstream alignment execution guide |

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.8.0 | 2026-04-30 | Make new consumer projects independent Git repos with workspace hook configuration and machine-enforced staged governance gates |
| 1.7.0 | 2026-04-04 | Add workspace-level Claude shared junction runtime, project init support, and derived worktree bootstrap for `.claude/agents/` |
| 1.6.0 | 2026-04-02 | Add canonical consumer-project derived worktree parity governance and clarify that project initialization bootstrap does not automatically satisfy derived worktree parity |
| 1.5.1 | 2026-03-30 | Add centralized `docs/mainline-updates/` management and template for main-bound shared-layer update explanations |
| 1.5.0 | 2026-03-27 | Add optional `intent-ledger.md` contract and document how readiness, plan, and outward coverage disclosure must carry compressed core intent |
| 1.4.1 | 2026-03-18 | Add post-ECI readiness re-entry semantics and clarify that `readiness-assessment.md` remains the latest gate authority |
| 1.4.0 | 2026-03-18 | Promote `/speckit.eci` to shared runtime and add `readiness/eci/` dossier artifacts |
| 1.3.0 | 2026-03-08 | Add shared extension registry foundations under `studio/extensions/` |
| 1.2.0 | 2026-03-08 | Add generated AI skill pack export path as a non-canonical shared artifact |
| 1.1.0 | 2026-03-07 | Align studio-first runtime sources, constitution paths, and project initialization rules |
| 1.0.0 | 2025-12-08 | Initial structure design |
