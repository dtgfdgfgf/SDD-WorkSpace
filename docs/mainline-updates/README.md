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
| 2026-07-20 | [`rb-5-agent-authority-process-truthfulness`](./2026-07-20-rb-5-agent-authority-process-truthfulness.md) | `feature/wave-3-security-and-workflows` | Draft | RB-5 is in progress: Specify contradiction removal, deterministic Claude content parity, fail-loud tool mapping, the Constitution 1.9.0 workspace self-application boundary, and machine-bound recovery of 18 historical Ready/TBD notes. The aggregate Wave-3 note remains Draft and R6 remains required. |
| 2026-07-20 | [`rb-4-extension-consumer-upgrade-boundaries`](./2026-07-20-rb-4-extension-consumer-upgrade-boundaries.md) | `feature/wave-3-security-and-workflows` | Ready | Commit `9819e30` completes R-C01/R-C02/R-C03/R-C05/R-C07/R-C08, R-A19, and R-F06 with schema-enforced and content-bound extension transactions, worktree-local hooks and clean consumer junction intake, plus frozen-trust staged upgrade and hash-bound rollback. R-C04/R-C06/R-F04 remain open; the branch remains NOT READY until RB-5 and R6. |
| 2026-07-20 | [`rb-3-mainline-evidence-integrity`](./2026-07-20-rb-3-mainline-evidence-integrity.md) | `feature/wave-3-security-and-workflows` | Ready | Commit `4f757e5` closes R-A17, R-A18, and R-A20 with category-complete shared-path gates, rename preservation, Git-backed blocking evidence, truthful Markdown-surface parsing, and explicit Batch or Aggregate readiness. R-A21 remains open; the Wave-3 umbrella note remains Draft and blocks merge until R6. |
| 2026-07-18 | [`rb-2-execution-identity-and-eci-routing`](./2026-07-18-rb-2-execution-identity-and-eci-routing.md) | `feature/wave-3-security-and-workflows` | Ready | Commit `ec25c07` closes RB-2 graph identity, five-file framed ECI evidence, feature-bound requirement latching, exact eight-status/four-outcome re-entry, direct Plan enforcement, shared manifest/source/reparse authorization, and no-overwrite restart archives. R-B23 remains independently open; `sdd-pipeline` remains experimental, default-disabled, and denied. |
| 2026-07-15 | [`rb-1-critical-governance-gates`](./2026-07-15-rb-1-critical-governance-gates.md) | `feature/wave-3-security-and-workflows` | Ready | RB-1 returns to Ready after `ec25c07` centralizes manifest existence/object/id/version, exact `sourcePath`, and all-component physical reparse authorization for listing and execution. The strict-Boolean, missing-state, wrong-type, null, scalar, schema-substitution, and digest denials remain effective. |
| 2026-07-14 | [`r2-1-truth-restoration`](./2026-07-14-r2-1-truth-restoration.md) | `feature/wave-3-security-and-workflows` | Ready | R2.1 accounting-only batch: the 2026-07-14 governance re-review reproduced counterexamples refuting the R-B02 (RVR-01) and R-B05 (RVR-03) closures, so both reopen to IN_PROGRESS, nine RVR findings enter the ledger (R-A17/A18/A19, R-B19/B20/B21/B22, R-C08, R-F06; 114 to 123), and the engine-integrity note is demoted to Draft. No runtime code changes. |
| 2026-07-14 | [`r2-workflow-engine-integrity`](./2026-07-14-r2-workflow-engine-integrity.md) | `feature/wave-3-security-and-workflows` | Ready | Historical R-B02/R-B05/R-B10 reopenings remain documented; commits through `ec25c07` close R-B19 task-baseline integrity, R-B20 shared fail-closed authorization, R-B24 no-overwrite restart archives, and R-B21 exact graph identity. R-B23 stays open and `sdd-pipeline` stays denied until R6. |
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
| 2026-05-01 | [`housekeeping`](./2026-05-01-housekeeping.md) | `main` | Merged | Historical Patch 9 from `c6ee1f1`; the 195-test figure is contemporaneous, and the advisory change-manifest wiring was later retired under R-G06. |
| 2026-05-01 | [`stage-entry-gates`](./2026-05-01-stage-entry-gates.md) | `main` | Merged | Historical Patch 8 from `c6ee1f1`; five setup-script gates landed, while direct slash-command wiring remained explicitly out of scope. |
| 2026-05-01 | [`validation-and-worktree-hardening`](./2026-05-01-validation-and-worktree-hardening.md) | `main` | Merged | Historical Patch 7 from `c6ee1f1`; validator and parameter hardening landed, while shared hook isolation was later corrected by RB-4 under R-A19. |
| 2026-04-30 | [`init-script-refactor`](./2026-04-30-init-script-refactor.md) | `main` | Merged | Historical Patch 6 from `c6ee1f1`; helper extraction and preview support landed, while parity evidence is limited to the listed initialization scenarios. |
| 2026-04-30 | [`template-completion`](./2026-04-30-template-completion.md) | `main` | Merged | Historical Patch 5 from `c6ee1f1`; template additions landed, while the junction-ignore decision was superseded by the RB-4 R-A19 repair. |
| 2026-04-30 | [`adapter-template-cleanup`](./2026-04-30-adapter-template-cleanup.md) | `main` | Merged | Historical Patch 4 commit evidence was recovered exactly; its validation remains contemporaneous and does not authorize current readiness. |
| 2026-04-30 | [`impact-routing-and-contract-split`](./2026-04-30-impact-routing-and-contract-split.md) | `main` | Merged | Historical Patch 3 from `c6ee1f1`; the contract already had six auxiliary commands including ECI, while R-E01 and R-E04 remain independently open. |
| 2026-04-30 | [`hook-enforcement-tightening`](./2026-04-30-hook-enforcement-tightening.md) | `main` | Merged | Historical Patch 2 from `c6ee1f1`; coverage was limited to then-enumerated paths, and R-A17's category and rename gaps were later fixed by RB-3. |
| 2026-04-30 | [`critical-bug-cleanup`](./2026-04-30-critical-bug-cleanup.md) | `main` | Merged | Historical Patch 1 from `c6ee1f1`; exact commit evidence was recovered and its validation figures remain contemporaneous. |
| 2026-04-30 | [`machine-enforced-governance-gates`](./2026-04-30-machine-enforced-governance-gates.md) | `main` | Merged | Historical staged-gate work from `c6ee1f1`; later R-A01, R-A02, and R-A17 findings narrowed its closure claims and were fixed by R1 and RB-3. |
| 2026-04-28 | [`worktree-agents-md-parity`](./2026-04-28-worktree-agents-md-parity.md) | `main` | Merged | Historical adapter propagation evidence was recovered exactly; later R-A19 and RB-4 narrowed the broader worktree-parity claim. |
| 2026-04-28 | [`update-constitution-invariants`](./2026-04-28-update-constitution-invariants.md) | `main` | Merged | Historical literal-token invariants were recovered exactly; they do not close the semantic-enforcement gap tracked by R-A13. |
| 2026-04-28 | [`adapter-change-routing`](./2026-04-28-adapter-change-routing.md) | `main` | Merged | Historical `adapter_change` routing evidence was recovered exactly; the former full-and-final closure wording is withdrawn. |
| 2026-04-28 | [`quickstart-adapter-invariants`](./2026-04-28-quickstart-adapter-invariants.md) | `main` | Merged | Historical QUICKSTART adapter invariants and their exact commit evidence were recovered; their counts remain contemporaneous. |
| 2026-04-27 | [`agent-bootstrap-governance`](./2026-04-27-agent-bootstrap-governance.md) | `main` | Merged | Historical three-adapter bootstrap governance and exact commit evidence were recovered; this is not current Batch evidence. |
| 2026-04-10 | [`shared-layer-consistency-fix`](./2026-04-10-shared-layer-consistency-fix.md) | `main` | Draft | Historical commit evidence was recovered, but deletion-based mirror handling, reserved `-Fix` wording, and broad enforcement claims remain unproven; reconciliation stays open. |
| 2026-04-04 | [`claude-junction-runtime`](./2026-04-04-claude-junction-runtime.md) | `main` | Merged | Historical Claude junction runtime evidence was recovered exactly; its validation remains contemporaneous and cannot authorize current promotion. |
| 2026-04-02 | [`project-worktree-parity-governance`](./2026-04-02-project-worktree-parity-governance.md) | `main` | Merged | Historical project-worktree parity governance evidence was recovered exactly; its validation remains contemporaneous and is excluded from current readiness. |
| 2026-03-30 | [`intent-ledger-runtime-governance`](./2026-03-30-intent-ledger-runtime-governance.md) | `001-yuanta-trading-workspace` | Ready | Enforce `intent-ledger` across readiness/plan/analyze runtime semantics and sync the branch with latest `main` before merge. |
