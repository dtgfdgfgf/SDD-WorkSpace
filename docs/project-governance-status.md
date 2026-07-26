# Project Governance Status Ledger

**Updated:** 2026-07-22

**Current Workflow Baseline:** `readiness` / `eci` governance model effective 2026-03-18

## Purpose

This file is the central compatibility ledger for project repos that consume the studio-first shared
runtime. It exists to prevent governance drift when the workspace governance repo evolves faster than
historical project repos.

This ledger is a status and compatibility document only. It is not a new runtime source of truth, a
replacement constitution, or a substitute for project-local context.

## Status Semantics

| Status | Meaning |
|--------|---------|
| `Legacy` | Historical project or feature history predates the current `readiness` / `eci` workflow baseline. |
| `Mixed` | Historical work is legacy, but at least one newer feature has re-entered SDD under the current workflow. |
| `Current` | The project was created or has active governed work fully under the current workflow baseline. |

## Operating Rules

1. Do not backfill historical `readiness` / `eci` artifacts for old features just to simulate
   compliance.
2. When a `Legacy` project starts a new governed feature, create or update the project-local
   `docs/governance-status.md` notice and move the project to `Mixed`.
3. A project can become `Current` only when active governed work follows the post-2026-03-18
   workflow baseline rather than relying on pre-baseline artifacts.
4. Shared runtime authority remains in the workspace governance repo. Project-local notices are
   consumer-facing compatibility hints only.

## Post-2026-03-18 Gate Effects

The 2026-03-18 baseline has since been strengthened without rewriting historical consumer
artifacts:

1. The mandatory delivery sequence is Specify, Clarify, Readiness, Plan, Tasks, Analyze and
   Implement.
2. Readiness must complete before Plan. When Readiness routes work through ECI, an authorized ECI
   outcome must return through a new Readiness assessment before Plan.
3. Direct Implement entry is fail-closed unless the feature has the required Readiness evidence,
   any routed ECI authorization, a machine-readable Analyze result and fulfilled intent
   obligations.
4. These stricter gates apply when a consumer begins new governed work. They do not retroactively
   convert legacy artifacts into current evidence or authorize edits inside consumer repositories.
5. The Constitution Section 2.1 workspace self-application route is limited to the canonical
   workspace governance repository. Consumer projects cannot use it as a seven-stage waiver.

## Inventory

| Project | Repo Path | Management Mode | Governance Status | Baseline / Effective Date | Legacy Scope | Rule For Next Feature | Authority Reference |
|---------|-----------|-----------------|-------------------|---------------------------|--------------|-----------------------|---------------------|
| `codex-smoke-practice-20260307` | `learning/codex-smoke-practice-20260307` | Workspace-tracked practice project | `Legacy` | Pre-2026-03-18 legacy project | Smoke project scaffold predates the shared `readiness` / `eci` gate and has no historical `readiness/` or `readiness/eci/` artifacts. | The first real governed feature must use the current seven-stage workflow, including `readiness` before planning and `eci` only when routed by `readiness`. | Workspace governance repo remains authoritative; local notice: `learning/codex-smoke-practice-20260307/docs/governance-status.md` |
| `codex-smoke-internal-20260307` | `projects/codex-smoke-internal-20260307` | Workspace-tracked internal project | `Legacy` | Pre-2026-03-18 legacy project | Smoke project scaffold predates the shared `readiness` / `eci` gate and has no historical `readiness/` or `readiness/eci/` artifacts. | The first real governed feature must use the current seven-stage workflow, including `readiness` before planning and `eci` only when routed by `readiness`. | Workspace governance repo remains authoritative; local notice: `projects/codex-smoke-internal-20260307/docs/governance-status.md` |
| `commercial-line-bot` | `projects/commercial-line-bot` | Workspace-tracked historical consumer project | `Legacy` | Pre-2026-03-18 legacy project | Historical bot code and documents predate the current SDD governance baseline and should not be assumed to provide `readiness` / `eci` coverage. | Any future governed scope should start a new feature packet under the current workflow instead of retrofitting old history. | Workspace governance repo remains authoritative; local notice: `projects/commercial-line-bot/docs/governance-status.md` |
| `japanese-learning` | `projects/japanese-learning` | Standalone repo historical sample / regression fixture | `Legacy` | Pre-2026-03-18 legacy project | Historical sample work predates the current shared `readiness` / `eci` workflow and has no historical `readiness/` or `readiness/eci/` dossier. | New governed work should start from the current workflow baseline without rewriting older feature history. | Workspace governance repo remains authoritative; local notice: `projects/japanese-learning/docs/governance-status.md` |
| `KMS` | `projects/KMS` | Standalone repo internal project | `Legacy` | Pre-2026-03-18 legacy project | Existing `001-rag-kb-mvp` spec / plan / tasks history predates the shared `readiness` / `eci` gate and has no historical `readiness/` or `readiness/eci/` artifacts. | Any new governed feature or governance refresh should begin under the current workflow baseline and leave historical artifacts intact. | Workspace governance repo remains authoritative; local notice: `projects/KMS/docs/governance-status.md` |
| `yuanxi_personal_site_ready` | `projects/personal_website/yuanxi_personal_site_ready` | Standalone repo nested under project container | `Legacy` | Pre-2026-03-18 legacy project | Existing website refactor SOP artifacts predate the shared `readiness` / `eci` gate and have no historical `readiness/` or `readiness/eci/` dossier. | Any new governed feature or SOP refresh should start from the current workflow baseline rather than backfilling old steps. | Workspace governance repo remains authoritative; local notice: `projects/personal_website/yuanxi_personal_site_ready/docs/governance-status.md` |
| `Trading` | `projects/Trading` | Standalone repo client project | `Legacy` | Pre-2026-03-18 legacy feature snapshot | The current `001-yuanta-trading-workspace` snapshot predates the shared `readiness` gate and has no historical `readiness/` or `readiness/eci/` dossier. | Any new scope, plan refresh, or worktree-driven phase increment must start from the current workflow baseline before planning. | Workspace governance repo remains authoritative; local notice: `projects/Trading/docs/governance-status.md` |
| `Trading-002-decision-evidence-platform` | `projects/Trading-002-decision-evidence-platform` | Standalone repo client project | `Mixed` | Re-entered governed work after 2026-03-18 | Historical `001` work is legacy. Feature `002-decision-evidence-platform` contains post-baseline Readiness and ECI material, but its chronology and current-gate conformance require review before any new delivery claim. | Treat existing artifacts as mixed-generation evidence. Any new scope or refresh must re-enter the current seven-stage workflow and cannot rely on the workspace-only Section 2.1 route. | Workspace governance repo remains authoritative; the project-local notice still says `Legacy` and is not synchronized in this shared-only batch: `projects/Trading-002-decision-evidence-platform/docs/governance-status.md` |
| `Trading-003-stock-selection-backtest` | `projects/Trading-003-stock-selection-backtest` | Standalone repo client project | `Mixed` | Re-entered governed work after 2026-03-18 | Historical inherited work is legacy. Feature `003-stock-selection-backtest` contains a later Readiness document, but it is retrospective and uses a non-canonical primary status, so it is not current gate evidence. | Treat existing artifacts as mixed-generation evidence. Any new scope or refresh must re-enter the current seven-stage workflow and cannot reuse retrospective Readiness as authorization. | Workspace governance repo remains authoritative; the project-local notice still says `Legacy` and is not synchronized in this shared-only batch: `projects/Trading-003-stock-selection-backtest/docs/governance-status.md` |

## 2026-07-22 Review Evidence

- The central inventory contains nine consumer rows, including Trading-002 and Trading-003.
- All nine listed project-local `docs/governance-status.md` notice paths were confirmed present;
  presence does not mean their content is synchronized with this central review.
- This review changed only the shared ledger. It did not edit `projects/` or `learning/` consumers
  or claim that either stale Trading notice is current.

## Review Trigger

Review and update this ledger when either of the following happens:

- The workspace governance repo adds or redefines mandatory stages, artifacts, or authority
  boundaries.
- A historical project re-enters governed SDD work and needs to move from `Legacy` to `Mixed` or
  `Current`.
