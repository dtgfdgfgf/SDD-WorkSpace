# ECI Assessment: [FEATURE NAME]

<!--
  Studio template for /speckit.eci
  Create under specs/<feature>/readiness/eci/eci-assessment.md
-->

**Date**: YYYY-MM-DD
**Linked Trigger**: [path to readiness/eci-trigger.md]
**ECI Level**: `NO_ECI | LIGHT_ECI | STANDARD_ECI | CRITICAL_ECI`
**Recommended Authorization**: `READY_FOR_MAINLINE_IMPLEMENTATION | READY_FOR_SPIKE_ONLY | READY_FOR_SANDBOX_ONLY | NOT_READY`

## Summary

- [2-6 bullets summarizing the governance result]

## Capability Inventory

| Capability | Type | Candidate Source Basis | Impact Area | Notes |
|------------|------|------------------------|-------------|-------|
| [name] | [SDK / service / protocol / other] | [docs / repo / package] | [architecture / security / validation] | [notes] |

## Governance Determination

- [Why this ECI level is correct]
- [Why this is or is not still a real external capability blocker]

## Recommended Authorization Path

- [Why this authorization outcome is the right current bound]
- [What still requires readiness judgment after ECI]

## Return To Readiness

- [What the operator should do next before re-running /speckit.readiness]
- [What readiness should inspect next]
- [What would require another /speckit.eci run instead of normal readiness progression]
