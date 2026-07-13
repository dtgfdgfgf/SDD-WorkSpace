# Mainline Update Notes

Central index for main-bound shared-layer update explanation notes.

## Purpose

This directory is the canonical place to record dedicated explanation notes for workspace-governance
branches that are intended to merge into `main`.

These notes are for human understanding and review. They do not replace canonical runtime artifacts,
the studio constitution, or the shared runtime audit.

## When A Note Is Required

Any branch intended to merge into `main` that changes shared-layer governance,
runtime agents, prompts, templates, hooks, shared scripts, or their canonical explanatory docs.

Guidelines:

- One note may cover one coherent merge-ready batch of related commits.
- A separate note is not required for every individual commit.
- Local experiments that are not being prepared for merge do not need a note yet.

## Naming Rule

Use `YYYY-MM-DD-short-topic.md`.

Example:

- `2026-03-30-intent-ledger-runtime-governance.md`

## Authoring Rule

Start from `studio/templates/sdd-docs/mainline-update-note-template.md`, then add the new file to
the index below in the same change batch.

## Index

| Date | Topic | Source Branch | Status | Summary |
|------|-------|---------------|--------|---------|
| 2026-07-14 | [`r2-verification-hardening`](./2026-07-14-r2-verification-hardening.md) | `feature/wave-3-security-and-workflows` | Ready | Commit `df31106` repairs three defects found by the independent R2 verification: pre-commit personal-data gate fail-open on non-UTF-8 consoles (R-A15), workflow feature rebind via operator inputs or tampered RunState (R-B17), and revert-insensitive stage-plan-prep contract tokens (R-A16). R-B18 recorded as open follow-up. |
| 2026-07-13 | [`r2-r-b06-dispatch-consistency`](./2026-07-13-r2-r-b06-dispatch-consistency.md) | `feature/wave-3-security-and-workflows` | Ready | Commit `29adc67` partially repairs R-B06 for the two PR #3 review threads: deterministic ProjectRoot script dispatch plus explicit setup-plan and plan-agent feature binding; RunState relocation remains open. |
| 2026-07-13 | [`r1-validation-and-merge-enforcement`](./2026-07-13-r1-validation-and-merge-enforcement.md) | `feature/wave-3-security-and-workflows` | Ready | R1 implementation `e543f6a`, clean-runner fixture repair `f601685`, PR #3 hosted validation, and active `main-governance` ruleset `18842326`: audit and registry gates fail closed, branch reconciliation replaces the retired change-manifest surface, PowerShell 7 and text hygiene are standardized, and `main` now requires PR plus `audit-and-tests`. |
| 2026-07-13 | [`r0-containment-and-source-cleanup`](./2026-07-13-r0-containment-and-source-cleanup.md) | `feature/wave-3-security-and-workflows` | Ready | Owner-approved R0 baseline: remove 396 obsolete or unlicensed tracked files plus local residue; add bounded MIT and third-party provenance; demote workflow catalog metadata; add staged-path privacy protection and workspace-scoped noreply identity. Runner authorization and server-side enforcement remain scheduled follow-ups. |
| 2026-07-12 | [`workflow-engine-completion-integrity`](./2026-07-12-workflow-engine-completion-integrity.md) | `feature/wave-3-security-and-workflows` | Draft | Historical partial repair reopened by GOV-02: changing part of `tasks.md` could still complete Implement. It is not a delivery acceptance signal pending R2 and R6 evidence. |
| 2026-07-12 | [`agent-conformance-and-doc-drift`](./2026-07-12-agent-conformance-and-doc-drift.md) | `feature/wave-3-security-and-workflows` | Draft | Historical partial repair reopened by GOV-05: Specify still guessed material unknowns and offered a mandatory-stage skip. R3 source, mirror, and handoff checks are required before promotion. |
| 2026-07-12 | [`analyze-completion-gate`](./2026-07-12-analyze-completion-gate.md) | `feature/wave-3-security-and-workflows` | Draft | Historical partial implementation reopened by GOV-04: direct Implement bypassed the setup gate and the Critical parser disagreed with canonical Analyze output. R3 repair is required before promotion. |
| 2026-07-11 | [`extension-lifecycle-hardening`](./2026-07-11-extension-lifecycle-hardening.md) | `feature/wave-3-security-and-workflows` | Ready | Path-boundary hardening for `add-extension.ps1` / `remove-extension.ps1`: id format validation + `Assert-PathInsideRoot` before any mutation, 3 negative-path regression tests, 2 new `scriptInvariants`. Closes the destructive-delete gap found by the verified 2026-07-11 external analysis. |
| 2026-07-11 | [`governance-ci`](./2026-07-11-governance-ci.md) | `feature/wave-3-security-and-workflows` | Ready | New `.github/workflows/governance.yml` GitHub Actions workflow: runs `check-speckit-runtime.ps1 -Json` and the full governance Pester suite on `windows-latest` for every push / PR / manual dispatch, uploads `testResults.xml` as artifact. Adds independent (non-LLM, non-local) verification of the two existing acceptance entrypoints; no new rules or process constraints. |
| 2026-05-05 | [`studio-workflows-runtime`](./2026-05-05-studio-workflows-runtime.md) | `feature/wave-3-security-and-workflows` | Draft | Wave-3 selective alignment with upstream `github/spec-kit` v0.3.0/v0.7.0/v0.7.5 PRs. Stream A: 8-site path-traversal hardening reusing `Assert-PathInsideRoot`, new regression test file, 8 new `scriptInvariants`. Stream B: new `studio/workflows/` runtime with three-layer registry, four step types (`command`/`gate`/`if`/`switch`) with dispatch script/agent boundary, sandboxed expression subset, RunState with atomic write + advisory lock, and first built-in `sdd-pipeline` workflow encoding all 8 readiness statuses and 3 ECI outcomes. Constitution unchanged (v1.8.0); 2 new `workflowInvariants`, 3 new workflow `scriptInvariants`, new `workflow_change` impact route, new `STUDIO_WORKFLOW_*` audit fields. |
| 2026-05-01 | [`housekeeping`](./2026-05-01-housekeeping.md) | `main` | Ready | Patch 9 (final) of governance deep-review remediation: `.gitignore` for test artifacts (L2); `run-governance-tests.ps1` writes NUnitXml to `studio/tests/_artifacts/` (L3); `tasks-template.md` phase-semantics HTML comment (M16); `speckit.analyze.agent.md` wires `change-manifest-template.md` via Mainline-Bound Shared-Layer prompt (M17); Project Structure tables in QUICKSTART / SDD-QUICKSTART-GUIDE / agent-file-template now reference constitution §11 as master (M18); `speckit.discover.agent.md` frontmatter style aligned (L8); new `mustContainAnchors` contract field + `<!-- governance-anchor: <id> -->` markers in 5 most-changed files + 5 anchor-based pilot doc invariants (L12). |
| 2026-05-01 | [`stage-entry-gates`](./2026-05-01-stage-entry-gates.md) | `main` | Ready | Patch 8 of governance deep-review remediation: new entry-gate scripts `setup-clarify.ps1`, `setup-readiness.ps1`, `setup-tasks.ps1`, `setup-analyze.ps1`, `setup-implement.ps1` to mechanize constitution §2's seven-stage order at the script layer; uniform `-FeatureDir`/`-Json`/`-Force` shape; analyze and implement reuse `validate-feature-structure.ps1`; five new contract invariants. |
| 2026-05-01 | [`validation-and-worktree-hardening`](./2026-05-01-validation-and-worktree-hardening.md) | `main` | Ready | Patch 7 of governance deep-review remediation: new `validate-feature-structure.ps1` per-feature §11 validator; configure `core.hooksPath` for derived worktrees in `new-project-worktree.ps1`; add `ValidateScript` to `-Branch` / `-Commitish` and `sync-agent-bootstrap -From`; clarify `upgrade-studio-runtime` help and mutual-exclusion error. |
| 2026-04-30 | [`init-script-refactor`](./2026-04-30-init-script-refactor.md) | `main` | Ready | Patch 6 of governance deep-review remediation: extract `Initialize-ProjectFromTemplate`, `New-CodeWorkspaceContent`, `Get-RetrospectiveContent`, and unified `Get-MarkdownField` helpers into `common.ps1`; reduce ~80 lines of duplication between `init-project.ps1` and `init-practice.ps1`; add `-WhatIf` support; replace legacy success/failure glyphs with `[OK]`/`[MISS]`; align Markdown field regex across all consumers. |
| 2026-04-30 | [`template-completion`](./2026-04-30-template-completion.md) | `main` | Ready | Patch 5 of governance deep-review remediation: add 5 missing SDD templates (retrospective, learnings-entry, research, data-model, quickstart), register them in contract `requiredDocTemplates`, fix project-init `.gitignore` to preserve workspace agent junctions per worktree parity policy. |
| 2026-04-30 | [`adapter-template-cleanup`](./2026-04-30-adapter-template-cleanup.md) | `main` | Ready | Patch 4 of governance deep-review remediation: remove stale `studio/` warning from agent-scoped adapter, document agent-scoped subset bootstrap exemption in constitution Section 10, fix duplicate H1 in workspace Copilot adapter, document Direct Imports asymmetry in three templates, strengthen mainline-update note Status state machine. |
| 2026-04-30 | [`impact-routing-and-contract-split`](./2026-04-30-impact-routing-and-contract-split.md) | `main` | Ready | Patch 3 of governance deep-review remediation: split requiredCommands into mandatoryStageCommands + auxiliaryCommands, define auxiliary command roles in constitution Section 10, add worktree_parity_change and readiness_change routes, add surface-truthfulness advisories to spec_change, inject seeded-warning HTML comment into all Claude agents. |
| 2026-04-30 | [`hook-enforcement-tightening`](./2026-04-30-hook-enforcement-tightening.md) | `main` | Ready | Patch 2 of governance deep-review remediation: generalize mainline-update enforcement to all shared-layer changes, force adapter sync on constitution change, strengthen commit-msg Conventional Commits hook, add staged-snapshot audit e2e test, relax phase freshness to quarterly grace. |
| 2026-04-30 | [`critical-bug-cleanup`](./2026-04-30-critical-bug-cleanup.md) | `main` | Ready | Patch 1 of governance deep-review remediation: 8 pure-bug fixes across pre-commit hook defensive marker, init-script `.gitkeep` count, create-new-feature exit propagation, seed-claude-agents warnings, check-speckit-runtime registry-stale promotion, and impact-registry exclude widening. |
| 2026-04-30 | [`machine-enforced-governance-gates`](./2026-04-30-machine-enforced-governance-gates.md) | `main` | Ready | Enforce staged pre-commit governance gates, independent consumer project repos, and hard readiness checks for planning artifacts. |
| 2026-04-28 | [`worktree-agents-md-parity`](./2026-04-28-worktree-agents-md-parity.md) | `main` | Ready | Extend `new-project-worktree.ps1` and parity governance doc to include `AGENTS.md` so derived worktrees carry all three v1.8.0 runtime adapters. |
| 2026-04-28 | [`update-constitution-invariants`](./2026-04-28-update-constitution-invariants.md) | `main` | Ready | Strengthen `update-constitution-script` invariant to lock the three v1.8.0 governance rules embedded in the script. |
| 2026-04-28 | [`adapter-change-routing`](./2026-04-28-adapter-change-routing.md) | `main` | Ready | Add `adapter_change` changeType to impact routing so adapter edits produce precise must_update advisories. |
| 2026-04-28 | [`quickstart-adapter-invariants`](./2026-04-28-quickstart-adapter-invariants.md) | `main` | Ready | Lock the v1.8.0 adapter narrative in QUICKSTART and SDD-GUIDE via two new contract docInvariants. |
| 2026-04-27 | [`agent-bootstrap-governance`](./2026-04-27-agent-bootstrap-governance.md) | `main` | Ready | Add synchronized runtime adapter governance for Codex, Claude Code, and Copilot startup context. |
| 2026-04-10 | [`shared-layer-consistency-fix`](./2026-04-10-shared-layer-consistency-fix.md) | `main` | Ready | Fix 8 shared-layer issues: constitution renumber, authority classification, pre-commit MUST validations, stale mirrors, ghost directory, init script templates, audit auto-fix. |
| 2026-04-04 | [`claude-junction-runtime`](./2026-04-04-claude-junction-runtime.md) | `main` | Ready | Add workspace-level Claude shared junction runtime, project init support, derived worktree bootstrap, and runtime audit coverage. |
| 2026-04-02 | [`project-worktree-parity-governance`](./2026-04-02-project-worktree-parity-governance.md) | `main` | Ready | Define consumer-project derived worktrees as project-equivalent instances and require parity checks beyond Git-tracked files. |
| 2026-03-30 | [`intent-ledger-runtime-governance`](./2026-03-30-intent-ledger-runtime-governance.md) | `001-yuanta-trading-workspace` | Ready | Enforce `intent-ledger` across readiness/plan/analyze runtime semantics and sync the branch with latest `main` before merge. |
