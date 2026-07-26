# Mainline Update Note: R0 Containment and Source Cleanup

**Date**: 2026-07-13
**Source Branch**: `feature/wave-3-security-and-workflows`
**Target Branch**: `main`
**Status**: Ready
**Related Commits**: `bdd2780`
**Related PR**: N/A
**Reconciliation Status**: Closed

## Summary

- Records the owner-approved 18-decision repair baseline and adds the four workspace analysis
  records to version control.
- Removes the unlicensed 392-file vendor snapshot and four other obsolete tracked files, cleans
  local-only residue and empty placeholders, and removes the corresponding live documentation
  entries.
- Adds a repository MIT license only after a current-tree provenance inventory, with a conservative
  `THIRD_PARTY_NOTICES.md` that preserves GitHub Spec Kit's MIT notice and explicitly excludes the
  removed vendor snapshot from the root license.
- Demotes `sdd-pipeline` catalog metadata to experimental, unapproved, and default-disabled until
  the R6 promotion gates pass.
- Adds a fail-closed staged-path privacy gate for workspace and independent consumer repositories,
  plus root and project-template ignore rules.
- Fixes a staged-hook false positive that treated an already removed nested source tree as a live
  adapter project while still preserving validation when the project root exists.
- Configures future commits under this workspace to use the GitHub noreply identity without
  rewriting history.

## Why This Update Exists

The 2026-07-12 repair inventory identified an unsafe public-release baseline: the repository had no
license or third-party attribution, contained a large snapshot whose source repository had no
verified repository-level license, advertised an unqualified workflow as approved and enabled, and
relied on one ignore rule to keep personal data out of Git. It also retained an installer that could
overwrite user-home agents, stale parallel translations, local residue, and empty structures that
fresh clones would never contain.

R0 is the bounded containment batch approved by the owner. It establishes a truthful baseline before
the later runtime, CI, workflow-authorization, extension, and documentation repairs.

## Scope

In scope:

- R-G13, R-B09, R-H01, R-H02, R-H05, R-H08, R-H11 through R-H13, R-H17,
  R-G10, R-I07, R-I08, and the locally actionable portion of R-J02.
- Source attribution, public licensing, privacy guardrails, workflow catalog demotion, obsolete
  tracked-source removal, local residue cleanup, and current structural documentation.

Explicitly out of scope:

- Runner-side workflow authorization. `run-workflow.ps1` does not yet consume catalog authorization;
  R-B05 remains scheduled for R2. This batch changes the truthful catalog and listing surface only.
- Server-side enforcement. A local pre-commit hook can still be bypassed with `--no-verify`; branch
  protection and required CI are R-J01 work in R1.
- Retirement of the agent-skills chain selected in owner decision 2A. That remains an atomic R4
  change with its scripts, callers, contract, audit, tests, documentation, and output directory.
- GitHub account email privacy and push-blocking toggles, which required an authenticated account
  settings action. At the R0 implementation snapshot, the workspace-scoped Git identity was
  complete and the account toggle remained manual.

Revalidation on 2026-07-13: the owner confirmed both account toggles complete. This preserves the
R0-time scope statement while closing R-J02 in the current repair ledger.

## Affected Paths

| Path | Change |
|------|--------|
| `docs/README.md` and three `docs/sdd-workspace-*.md` records | Add the analysis index and owner-approved repair baseline |
| `resources/github-copilot-configs/` | Remove 392 tracked vendor files; ignore future working-checkout intake at this path |
| `bone.ini`, `setup-copilot-agents.ps1`, `docs/basic-prompt.txt`, `中文文件管理/` | Remove obsolete or drifting tracked assets |
| `archive/`, `studio/tools/`, `studio/templates/feature-packs/`, `studio/knowledge-base/pain-points/` | Remove local-only empty placeholders; retain the constitution's optional pain-points definition |
| `testResults.xml` | Remove only the ignored root residue; retain `studio/tests/_artifacts/` behavior |
| `LICENSE`, `THIRD_PARTY_NOTICES.md`, `README.md` | Add bounded MIT licensing, provenance, dependency notices, and public license explanation |
| `studio/workflows/catalog.json` | Set experimental trust and review status, default disabled, with null approval metadata |
| `.githooks/pre-commit.ps1` | Reject active staged destinations under the protected personal-data directory, fail closed when Git staging cannot be evaluated, and skip adapter grouping only for project roots removed by the staged change |
| `.gitignore`, `studio/templates/project-init/.gitignore` | Add external-intake and personal-data ignore coverage |
| `studio/runtime/shared-runtime-contract.json` | Lock licensing provenance, vendor intake ignore, catalog demotion, the privacy hook, and both personal-data ignore policies; add their sources to shared-gate coverage |
| `studio/tests/pre-commit.Tests.ps1` | Add privacy helper, rename and deletion semantics, root fixture, independent consumer, non-disclosure, corrupt-index, and removed adapter-root tests |
| `studio/tests/workflow-schema.Tests.ps1` | Lock the experimental and disabled catalog presentation |
| `README.md`, `WORKSPACE_STRUCTURE.md` | Remove obsolete archive and installer entries |

## Impact

- A normal or forced stage of an active path under a directory named `履歷` is rejected before later
  validators can print a filename. Deleting such a tracked path or moving it out remains possible.
- New consumer projects inherit the same ignore rule. Existing consumers are protected by the shared
  hook when it is installed.
- `list-workflows.ps1` reports `sdd-pipeline` as experimental and disabled. Direct runner
  authorization is deliberately not claimed by this batch.
- The current checkout no longer distributes the unlicensed vendor snapshot. Its historical
  provenance remains documented because ordinary Git history still contains the old blobs.
- Seven Git repositories currently discovered under the workspace resolve the account's GitHub
  noreply email through a workspace-scoped conditional include; the pre-existing global identity was
  not overwritten.

## Validation

- `git diff --check`: passed
- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json`: `VALID=true`, 0 errors,
  0 warnings
- `Invoke-Pester studio/tests/pre-commit.Tests.ps1`: 63 passed, 0 failed
- `Invoke-Pester studio/tests/workflow-schema.Tests.ps1`: 10 passed, 0 failed, 1 expected skip
- Full governance suite: 265 passed, 0 failed, 1 expected skip
- Contract-focused Pester tests: 20 passed, 0 failed
- Changed-document relative links: 31 checked, 0 broken
- Staged pre-commit: passed, including the shared runtime audit against the staged snapshot
- Deletion inventory: 396 tracked deletions, including all 392 vendor files; all nine local cleanup
  targets absent; active generated test artifact path retained
- Noreply verification: 7 of 7 discovered workspace repositories resolve the expected noreply
  identity, with no repo-local email override
- Change manifests: none created; this batch records reconciliation in this mainline note

## Impact Reconciliation

The isolated R0 diff was compared with the current impact registry. It has no unresolved
`must_update` target: its runtime contract, staged hook, regression tests, catalog metadata,
licensing and provenance records, and current structural documentation were updated as one batch
in commit `bdd2780`.

## Merge Notes

- Implementation commit `bdd2780` exists and the final validation results are recorded. This batch is
  ready for review and eventual merge with the broader repair branch.
- No Git history rewrite and no push are part of R0.

## Follow-ups

- Completed on 2026-07-13: GitHub account email privacy and command-line push-blocking toggles.
- Completed in R1: repair audit false-green paths and add server-side branch and merge enforcement.
- R2: make the workflow runner consume catalog and state authorization before it creates any feature
  or RunState artifacts.
- R4: retire the owner-selected agent-skills capability as one atomic change.
