# ECI Trigger: [FEATURE NAME]

<!--
  Create when readiness primary status is ROUTE_TO_ECI
  This file is the intake seed for /speckit.eci and should be created before running that command
  After the ECI dossier exists, the latest authoritative state lives in readiness-assessment.md plus readiness/eci/*.md, not in this trigger alone.
-->

**Date**: YYYY-MM-DD
**Linked Readiness Assessment**: [path]
**Preliminary Recommendation**: `LIGHT_ECI | STANDARD_ECI | CRITICAL_ECI`

## Candidate External Capability

- **Name**: [Capability name]
- **Type**: SDK / external repo / framework / platform / protocol / service / other
- **Why It Is New Here**: [Why governance is required]

## Why This Blocks Planning

- [Primary blocker statement]
- [What would be unsafe to assume without governance]

## Suspected Impact Scope

- [Architecture boundary]
- [Permission / security model]
- [Execution or validation impact]

## Known Source Basis

- **Source candidates**: [URLs / repos / docs / packages]
- **Version references**: [version / tag / release / commit]
- **Last verified**: YYYY-MM-DD / unknown

## Current Prohibitions

- Mainline planning MUST NOT rely on unguided just-in-time learning of this capability.
- Mainline implementation MUST NOT begin until `/speckit.eci` has produced the dossier and readiness is re-run.

## Return Condition

- [What must exist before returning to /speckit.readiness]
