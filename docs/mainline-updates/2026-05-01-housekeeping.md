# Mainline Update Note: Housekeeping (Patch 9 of governance review — final patch)

<!--
  Part of the v1.8.0 deep review remediation series. This is Patch 9 of 9 — the
  closing patch.
-->

**Date**: 2026-05-01
**Source Branch**: `main`
**Target Branch**: `main`
**Status**: Ready
**Related Commits**: TBD
**Related PR**: N/A

## Summary

- Add `testResults.xml` and `studio/tests/_artifacts/` to `.gitignore` so Pester output never
  pollutes the working tree (L2).
- `run-governance-tests.ps1` now writes NUnitXml results into `studio/tests/_artifacts/testResults.xml`
  instead of leaving them disabled (L3).
- `tasks-template.md` carries an HTML comment that documents how its phase structure aligns with
  `speckit.tasks.agent.md` (Setup, Foundation, Story Delivery, Polish; Tests are conditional) (M16).
- `speckit.analyze.agent.md` instructs the analyze agent to emit a one-line "Mainline-Bound
  Shared-Layer Change Manifest" prompt when shared-layer surfaces are touched, finally wiring
  `change-manifest-template.md` into a real flow (M17).
- The three downstream Project Structure tables (`studio/QUICKSTART.md` "專案結構",
  `studio/SDD-QUICKSTART-GUIDE.md` §13.1, and `studio/templates/sdd-docs/agent-file-template.md`)
  now point readers to constitution §11 as the master, removing ambiguity about which list is
  canonical (M18).
- `speckit.discover.agent.md` frontmatter switches from a multi-line `description: >` block to a
  single-line description, matching the style of every other agent in `.github/agents/` (L8).
- New `mustContainAnchors` contract field plus `<!-- governance-anchor: <id> -->` HTML markers in
  five most-changed files (`studio/constitution/constitution.md`, `studio/QUICKSTART.md`,
  `studio/SDD-QUICKSTART-GUIDE.md`, `CLAUDE.md`, `AGENTS.md`). Five new doc invariants exercise
  the mechanism end-to-end. New Pester suite `studio/tests/anchor-mechanism.Tests.ps1` (6 tests)
  covers pass/fail and edge cases (L12 pilot).

## Why This Update Exists

The deep review identified eight loose ends that did not fit into Patches 1-8:

- **L2/L3** — Tests wrote nothing to disk by default, and when run with `TestResult.Enabled` the
  XML landed in the workspace root and was untracked but never gitignored. The repo always had
  one stray `testResults.xml` after a green run.
- **M16** — `tasks-template.md` had a phase layout that mirrored the `speckit.tasks.agent.md`
  agent's behavior, but neither side documented the mapping. Tests-phase conditionality was
  invisible to template readers.
- **M17** — `change-manifest-template.md` shipped with the studio for months but was never
  referenced by any agent. It existed as a dead asset.
- **M18** — Three downstream documents (`QUICKSTART.md`, `SDD-QUICKSTART-GUIDE.md`,
  `agent-file-template.md`) carried abbreviated Project Structure tables. They were *not* wrong,
  but they were not labelled as informational — readers could mistake any of them for the
  canonical list (which is constitution §11).
- **L8** — `speckit.discover.agent.md` was the only agent using YAML's multi-line `>` syntax for
  the description. Every other agent uses a single-line description, and some agent-loaders are
  brittle around the multi-line form.
- **L12** — Contract `mustContainAll` matches literal substrings, which means innocuous
  punctuation or whitespace edits in a governed document can fail the audit. The deep review
  proposed an HTML-anchor pattern as a more durable hook for the most-changed files.

## Scope

- `.gitignore`, `run-governance-tests.ps1`, three docs, two templates, two adapters, one constitution,
  one agent, and one contract field. No script logic redesign.
- Five new doc invariants (anchor-based) added to `docInvariants`; existing 100+ entries unchanged.
- New `studio/tests/anchor-mechanism.Tests.ps1` (6 tests) plus the existing 189 stay green.

Out of scope:

- Rewriting any existing `mustContainAll` invariant to use `mustContainAnchors`. The pilot
  proves the mechanism on five high-churn files; broader migration is a future patch where each
  candidate document gets its own anchor design.
- Per-document anchor coverage analysis. Anchors are added where they capture stable section
  identity; not every section needs an anchor.

## Affected Paths

| Path | Change |
|------|--------|
| `.gitignore` | Adds `testResults.xml` and `studio/tests/_artifacts/`. |
| `studio/scripts/powershell/run-governance-tests.ps1` | Enables `TestResult` with NUnitXml at `studio/tests/_artifacts/testResults.xml`. |
| `studio/templates/sdd-docs/tasks-template.md` | Adds phase-semantics HTML comment aligning template with `speckit.tasks.agent.md`. |
| `.github/agents/speckit.analyze.agent.md` | Adds Mainline-Bound Shared-Layer Change Manifest one-line prompt section, wiring `change-manifest-template.md`. |
| `studio/QUICKSTART.md` | Adds "Canonical reference: 憲章 §11" note above 專案結構 table; adds `quickstart-seven-stage-workflow` anchor. |
| `studio/SDD-QUICKSTART-GUIDE.md` | Adds canonical-reference note in §13.1; adds `sdd-guide-core-principles` anchor. |
| `studio/templates/sdd-docs/agent-file-template.md` | Adds canonical-reference note above Project Structure table. |
| `.github/agents/speckit.discover.agent.md` | Frontmatter description collapsed to single line. |
| `studio/constitution/constitution.md` | Adds anchors above §11 and §12. |
| `CLAUDE.md` | Adds `claude-direct-imports` and `claude-tool-notes` anchors (outside the auto-generated bootstrap block). |
| `AGENTS.md` | Adds `agents-tool-notes` anchor (outside the auto-generated bootstrap block). |
| `studio/scripts/powershell/check-speckit-runtime.ps1` | `Test-ContentContract` accepts `MustContainAnchors`; `Invoke-PathContractChecks` forwards `entry.mustContainAnchors`. |
| `studio/runtime/shared-runtime-contract.json` | Adds five `governance-anchor-pilot-*` doc invariants. |
| `studio/tests/anchor-mechanism.Tests.ps1` | New: 6 tests covering anchor pass / fail / edge cases. |

## Impact

- 189 → 195 tests, 0 failed, 0 skipped.
- `check-speckit-runtime.ps1 -Json` -> `VALID: true`, `ERROR_COUNT: 0`. Five anchor-based invariants verified end-to-end.
- `generate-impact-registry.ps1 -Compare` -> in-sync.
- The anchor mechanism is opt-in and additive: existing `mustContainAll` and `mustMatchAll`
  fields continue to work exactly as before. Future patches can migrate brittle string checks to
  anchors at their own pace.

## Validation

- `pwsh ./studio/scripts/powershell/run-governance-tests.ps1` -> 195 passed, 0 failed.
- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json` -> `VALID: true`.
- `pwsh ./studio/scripts/powershell/generate-impact-registry.ps1 -Compare` -> in-sync.

## Merge Notes

- Patch 9 closes the v1.8.0 deep-review remediation series. Combined effect over Patches 1-9:
  baseline tests grew from 80 to 195, the staged-snapshot audit and the seven-stage entry gates
  are now machine-verifiable, and the constitution §10/§11/§12 invariants are enforced by hooks,
  contracts, or scripts rather than agent prompts alone.
- The `mustContainAnchors` mechanism intentionally introduces no breaking change. A future
  patch can migrate brittle `mustContainAll` checks to anchors document by document; this patch
  only proves the mechanism works.

## Follow-ups

- Future patch: gradually migrate fragile `mustContainAll` invariants (those that fail on cosmetic
  document edits) to `mustContainAnchors`. Candidates are anything tied to a specific phrase that
  has changed at least twice in the last six months.
- Future patch: add an `anchors` documentation section to `studio/SDD-QUICKSTART-GUIDE.md`
  explaining the `<!-- governance-anchor: <id> -->` convention so authors know how to add new
  anchors when they rename or restructure governed sections.
- Future patch: opt-in agent prompt wiring for the Patch 8 stage entry gates so a `/speckit.<stage>`
  invocation surfaces the same `BLOCKERS[]` the script would emit.
