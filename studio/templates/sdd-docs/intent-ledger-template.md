# Intent Ledger: [FEATURE NAME]

<!--
  Studio template for intent-ledger secondary artifact
  Create under specs/<feature>/intent-ledger.md only when a core spec item is
  represented_by_substitute, deferred, or dropped_with_owner_signoff.
-->

**Date**: YYYY-MM-DD
**Spec**: [link to spec.md]
**Status**: Active

## Usage Rules

- Create this file only when a core spec item is compressed out of full in-scope delivery.
- Keep one row per affected core spec item.
- Update existing rows when classification, representation, disclosure, or re-entry conditions change.
- Do not silently remove rows just because the current iteration shipped.

## Allowed `current_classification` Values

- `represented_by_substitute`
- `deferred`
- `dropped_with_owner_signoff`

## Ledger

| source_intent_item | spec_anchor | current_classification | current_representation | defer_or_drop_reason | reentry_trigger | follow_on_feature_hint | surface_disclosure_required | owner_signoff_required |
|--------------------|-------------|------------------------|------------------------|----------------------|-----------------|------------------------|-----------------------------|-----------------------|
| [Original intent item] | [FR-004 / US-002 / Success Criteria #1] | `represented_by_substitute` | [Current representative capability or substitute source] | [Why scope is compressed right now] | [Concrete trigger or `N/A`] | [Future feature or packet hint] | [Where disclosure is required, or `No`] | `No` |
| [Original intent item] | [FR-00X / US-00X] | `deferred` | [Current partial representation or `Not yet represented`] | [Why this iteration is not doing it] | [Concrete re-entry condition] | [Future feature or packet hint] | [Where disclosure is required, or `No`] | `No` |
| [Original intent item] | [FR-00X / US-00X] | `dropped_with_owner_signoff` | [Current non-support statement or `N/A`] | [Why it is being dropped] | [Optional reversal trigger or `N/A`] | [Optional follow-on hint or `N/A`] | [Where disclosure is required, or `No`] | [Owner name / date / signoff reference] |

## Notes

- `represented_by_substitute` MUST name the active substitute or representative surface.
- `deferred` MUST state a concrete re-entry trigger; generic notes such as `v1+` are not enough.
- `dropped_with_owner_signoff` MUST include explicit owner signoff and should normally be reflected in outward-facing coverage disclosure when omission could surprise readers.
