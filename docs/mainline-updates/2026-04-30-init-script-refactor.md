# Mainline Update Note: Init-script refactor (Patch 6 of governance review)

<!--
  Part of the v1.8.0 deep review remediation series. This is Patch 6 of 9.
-->

**Date**: 2026-04-30
**Source Branch**: `main`
**Target Branch**: `main`
**Status**: Ready
**Related Commits**: TBD
**Related PR**: N/A

## Summary

- Extract `Initialize-ProjectFromTemplate`, `New-CodeWorkspaceContent`, `Get-RetrospectiveContent`, and `Get-MarkdownField` helpers into `studio/scripts/powershell/common.ps1`.
- Reduce `init-project.ps1` and `init-practice.ps1` from ~140 lines each (with ~80 lines of duplicate scaffold logic) to thin wrappers that delegate to the shared helper.
- Add `[CmdletBinding(SupportsShouldProcess = $true)]` to both init scripts and the helper, enabling `-WhatIf` previews (M20).
- Replace the `✓` / `✗` Unicode markers in `Test-FileExists` / `Test-DirHasFiles` with `[OK]` / `[MISS]` text markers per constitution Section 10.1 emoji policy (M19).
- Replace the three duplicated Markdown field parsers (`Get-MarkdownFieldValue` in `setup-plan.ps1`, `get-speckit-version.ps1`, and `pre-commit.ps1`) with calls to the unified `Get-MarkdownField` helper. Pre-commit retains a self-contained shadow copy of the same regex (with an aligning comment) so the hook keeps working when `common.ps1` is mid-edit.
- The unified regex now supports both `**Field:**` (colon inside, used by `constitution.md` / `WORKSPACE_STRUCTURE.md`) and `**Field**:` (colon outside, used by readiness assessments) (M13).
- Add a contract invariant `common-init-from-template-helper` requiring `common.ps1` to host the new helper.

## Why This Update Exists

The deep review identified five structural cleanup items that landed in this single patch:

- **M3** — `init-project.ps1` and `init-practice.ps1` shared ~80 lines of identical scaffold code (template copy, README rewrite, project constitution, agent bootstrap, code-workspace JSON, junctions, git init, gitkeep cleanup). Any change had to be applied twice. The two scripts now share `Initialize-ProjectFromTemplate`.
- **M4** — Three near-identical `Get-MarkdownFieldValue` regex parsers existed in three scripts, with subtle behavior differences (one used `Select-String` on a path, two used `-match` on content, only one stripped backticks). They are now one function with one regex.
- **M13** — The setup-plan parser used a regex that broke on backtick-wrapped values when the value contained backticks; the new regex uses non-greedy `(.+?)` plus post-match wrapper stripping to handle backtick-wrapped, double-quoted, and plain values uniformly.
- **M19** — `Test-FileExists` printed `✓` / `✗` characters that violate the spirit of constitution Section 10.1 ("Use Plain text descriptions" / "MUST NOT use emoji in SDD documents"). The text markers `[OK]` / `[MISS]` are now used consistently.
- **M20** — Init scripts had no preview mode. With `-WhatIf`, a user can now see exactly which directories, files, junctions, and git repo would be touched before any change is applied.
- **M21** — `Copy-Item -Recurse` previously had no exclusion for stray `.git` metadata that might exist inside a template directory. The helper now copies with `-Exclude '.git'` and post-purges any top-level `.git` that slips through, before the real `git init` creates a fresh one.

## Scope

- New helpers in `common.ps1`.
- Refactor of `init-project.ps1` and `init-practice.ps1` to call the helpers (behavior-preserving).
- Removal of duplicated `Get-MarkdownFieldValue` from `setup-plan.ps1` and `get-speckit-version.ps1`; in-place rewrite of the same regex in `pre-commit.ps1` (kept self-contained by intent).
- Contract invariant updates (replace `Initialize-ProjectGitRepository` literal with `Initialize-ProjectFromTemplate` literal in init wrapper invariants; add new helper invariant against `common.ps1`).
- New Pester suite `studio/tests/init-project-helpers.Tests.ps1` (26 tests) covering `Get-MarkdownField`, `New-CodeWorkspaceContent`, `Get-RetrospectiveContent`, `Initialize-ProjectFromTemplate`, and `-WhatIf` parameter binder support.

Out of scope:

- Removing the inline retrospective scaffold from `init-project.ps1` (already removed during refactor — the helper consults `studio/templates/sdd-docs/retrospective-template.md` from Patch 5 and falls back to an inline scaffold if the template is missing).
- Refactoring `pre-commit.ps1` to dot-source `common.ps1` (intentionally kept self-contained — see in-code comment).

## Affected Paths

| Path | Change |
|------|--------|
| `studio/scripts/powershell/common.ps1` | New helpers: `Get-MarkdownField`, `New-CodeWorkspaceContent`, `Get-RetrospectiveContent`, `Initialize-ProjectFromTemplate`. Replaced `✓`/`✗` with `[OK]`/`[MISS]`. |
| `studio/scripts/powershell/init-project.ps1` | Reduced to ~110 lines, delegates to `Initialize-ProjectFromTemplate`. Adds `SupportsShouldProcess`. |
| `studio/scripts/powershell/init-practice.ps1` | Reduced to ~100 lines, delegates to `Initialize-ProjectFromTemplate`. Adds `SupportsShouldProcess`. |
| `studio/scripts/powershell/setup-plan.ps1` | Removed local `Get-MarkdownFieldValue`; calls `Get-MarkdownField -Content`. |
| `studio/scripts/powershell/get-speckit-version.ps1` | Removed local `Get-MarkdownFieldValue`; calls `Get-MarkdownField -Path`. |
| `.githooks/pre-commit.ps1` | `Get-MarkdownFieldValue` regex aligned with `Get-MarkdownField` behavior; comment added explaining intentional self-containment. |
| `studio/runtime/shared-runtime-contract.json` | Updated init-script invariants from `Initialize-ProjectGitRepository` literal to `Initialize-ProjectFromTemplate` literal. Added new `common-init-from-template-helper` invariant. |
| `studio/tests/init-project-helpers.Tests.ps1` | New: 26 Pester tests for the helpers. |

## Impact

- 116 → 142 tests, 0 failed, 0 skipped.
- `check-speckit-runtime.ps1 -Json` -> `VALID: true`, `ERROR_COUNT: 0`. New invariant `common-init-from-template-helper` verified.
- `generate-impact-registry.ps1 -Compare` -> still in-sync.
- Behavior parity: any feature that worked before (Practice / Internal / Client init, README substitution, agent bootstrap, junctions, git init with workspace hooksPath, `.gitkeep` cleanup, retrospective scaffold for Internal/Client) still works exactly the same.
- `init-project.ps1 -Name preview -Type Internal -WhatIf` now previews every step without touching the filesystem.
- The unified `Get-MarkdownField` is correct against both `**Field:**` (constitution-style) and `**Field**:` (readiness-style) Markdown layouts; `get-speckit-version.ps1` continues to read constitution version successfully.

## Validation

- `pwsh ./studio/scripts/powershell/run-governance-tests.ps1` -> 142 passed, 0 failed.
- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json` -> `VALID: true`, all invariants green.
- `pwsh ./studio/scripts/powershell/generate-impact-registry.ps1 -Compare` -> in-sync.

## Merge Notes

- Patch 6 unblocks Patch 7 (`validate-feature-structure.ps1` will use `Get-MarkdownField` to read spec / readiness fields cleanly) and Patch 8 (the five new stage entry-gate scripts can scaffold via the helper-friendly utilities).
- No external-facing behavior change — purely an internal refactor with the new `-WhatIf` capability as an additive bonus.

## Follow-ups

- Patch 7 will add `validate-feature-structure.ps1` and `core.hooksPath` configuration to `new-project-worktree.ps1`, plus `-Branch` / `-Commitish` `ValidateScript` hardening.
- Long-term: consider auditing the rest of the codebase for any remaining `Get-MarkdownFieldValue` callers and migrating them to the unified helper.
