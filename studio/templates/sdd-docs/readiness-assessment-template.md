# Readiness Assessment: [FEATURE NAME]

<!--
  Studio template for /speckit.readiness
  Create under specs/<feature>/readiness/readiness-assessment.md
-->

**Date**: YYYY-MM-DD
**Primary Status**: `READY_FOR_PLAN | ROUTE_TO_ECI | ROUTE_TO_REPO_CONTEXT | ROUTE_TO_DECISION | ROUTE_TO_VALIDATION | ROUTE_TO_ACCESS | EXPLORATORY_ONLY | NOT_READY`
**ECI Re-entry Status**: `NOT_REQUIRED | PENDING | COMPLETE`
**ECI Evidence SHA-256**: `N/A | <lowercase 64-character digest>`
**Recommended Next Step**: [command / packet / owner action]

Use `NOT_REQUIRED` with `N/A` only when no ECI trigger or dossier artifact exists. Use `PENDING`
with `N/A` only for the initial `ROUTE_TO_ECI` assessment. After re-entering Readiness with the
trigger and all four dossier files, run
`pwsh ./studio/scripts/powershell/validate-feature-structure.ps1 -FeatureDir specs/<feature> -RequireEciReentry -Json`
and copy `ECI_ACTUAL_EVIDENCE_SHA256` into the COMPLETE assessment. The validator frames each
canonical UTF-8 path relative to `readiness/` with a 4-byte big-endian length and each raw-byte
content with an 8-byte big-endian length in this order: `eci-trigger.md`,
`eci/eci-assessment.md`, `eci/source-manifest.md`, `eci/adoption-record.md`,
`eci/authorization-record.md`. All five files must exist and be non-empty.

## Summary

- [High-signal conclusion 1]
- [High-signal conclusion 2]
- [If this is a post-ECI rerun, distinguish what is already governed from what still blocks planning]

## Planability vs Intent Obligations

- **Planability Resolved**: Yes / No
- **Intent Obligations Retained**: None / [Summarize any represented, deferred, or dropped core spec items]
- **Intent Ledger Requirement**: Not Required / Create `intent-ledger.md` / Update `intent-ledger.md`
- **Intent Ledger Path**: `specs/<feature>/intent-ledger.md` / N/A

> Use this section to keep readiness focused on planning safety while preserving any core intent
> that was represented, deferred, or dropped. `READY_FOR_PLAN` MAY still be valid, but any
> required ledger must exist before plan handoff.

## Readiness Dimension Scan

| Dimension | Status | Notes |
|-----------|--------|-------|
| Spec Preconditions | Pass / Partial / Fail | |
| External Capability Adoption | Pass / Partial / Fail | |
| Repo Context & Runtime Authority | Pass / Partial / Fail | |
| Decision Completeness | Pass / Partial / Fail | |
| Validation / Evidence Readiness | Pass / Partial / Fail | |
| Access / Runtime Setup | Pass / Partial / Fail | |
| Exploration Boundary | Pass / Partial / Fail | |

## Primary Blocker Analysis

- [Why this primary status is correct]
- [Why other concerns are secondary]
- [If this is a post-ECI rerun, explain why external capability governance is no longer the primary blocker or why it still is]

## Allowed / Not Allowed Next Actions

### Allowed

- [Allowed action]

### Not Allowed

- [Blocked action]

## Secondary Observations

- [Optional secondary note]
