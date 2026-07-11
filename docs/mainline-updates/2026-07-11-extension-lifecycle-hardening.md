# Mainline Update Note: Extension Lifecycle Path-Boundary Hardening

**Date**: 2026-07-11
**Source Branch**: `feature/wave-3-security-and-workflows`
**Target Branch**: `main`
**Status**: Draft
**Related Commits**: TBD
**Related PR**: N/A

## Summary

- `add-extension.ps1` and `remove-extension.ps1` now validate the extension id against
  `^[a-z0-9][a-z0-9-]{1,63}$` (same pattern as `run-workflow.ps1`) and assert the resolved
  target directory stays inside `studio/extensions/` before any mutation.
- Three new negative-path regression tests in `path-traversal-hardening.Tests.ps1`; two new
  `scriptInvariants` (`add-extension-path-boundary`, `remove-extension-path-boundary`) lock the
  guards into the contract.

## Why This Update Exists

An adversarially verified external analysis (2026-07-11) found both scripts joined the untrusted
manifest `id` / `-Id` parameter directly onto `EXTENSIONS_ROOT` with no format validation and no
containment check, then executed `Remove-Item -Recurse -Force` on the result. A traversal id such
as `../../<dir>` could delete directories outside the extensions registry. This violated
`studio/extensions/POLICY.md` (escaping path rejection) and was the one gap left by the Wave-3
eight-site path-traversal hardening, which covered the stage-gate scripts but not the extension
lifecycle pair.

## Scope

- Guard insertion only; no behavior change for well-formed ids.
- Non-goals (tracked as follow-ups from the same analysis): schema-based `Test-Json` validation in
  `validate-extension-registry.ps1`, validate-before-mutate ordering with rollback, and
  catalog/state execution authorization for `run-workflow.ps1`.

## Affected Paths

| Path | Change |
|------|--------|
| `studio/scripts/powershell/add-extension.ps1` | Id format validation + `Assert-PathInsideRoot` on target before delete/copy |
| `studio/scripts/powershell/remove-extension.ps1` | Id format validation + `Assert-PathInsideRoot` on target before catalog/state/dir mutation |
| `studio/tests/path-traversal-hardening.Tests.ps1` | New Describe block: traversal ids rejected, well-formed ids reach normal handling |
| `studio/runtime/shared-runtime-contract.json` | Two new `*-path-boundary` scriptInvariants |
| `docs/mainline-updates/2026-07-11-extension-lifecycle-hardening.md` | This note |
| `docs/mainline-updates/README.md` | Index entry |

## Impact

- Malicious or mistyped extension ids now fail loudly before any filesystem or registry mutation.
- Contract audit will fail if the guards are ever removed.

## Validation

- `Invoke-Pester studio/tests/path-traversal-hardening.Tests.ps1`: 12/12 passed (2026-07-11),
  including `../../pwn-target` manifest id and `../../studio` remove id rejected with non-zero
  exit before mutation.
- `check-speckit-runtime.ps1`: Errors 0 / Warnings 0 with the two new invariants active.
- Change manifests: none required.

## Merge Notes

- Part of the correctness/safety batch derived from the verified external analysis; ready to merge
  with the Wave-3 branch.

## Follow-ups

- Extension validator schema enforcement and validate-before-mutate ordering (P1).
- Workflow catalog/state execution authorization in `run-workflow.ps1` (P1).
