# Change Manifest: [SHORT TITLE]

<!--
  Studio template for change manifest artifact.
  Create when a change is expected to propagate beyond the document being edited.

  Feature-scoped: specs/<feature>/change-manifests/YYYY-MM-DD-<short-topic>.md
  Shared-layer:   docs/change-manifests/YYYY-MM-DD-<short-topic>.md

  A change manifest is required when:
  - a spec change affects requirements already referenced in plan.md or tasks.md
  - a constitution or template change affects multiple downstream documents
  - a shared-layer change touches paths listed in sharedGatePaths

  A change manifest is NOT required for:
  - initial creation of a document with no downstream dependents yet
  - terminal artifacts (tasks.md) that do not propagate upstream
  - edits contained entirely within a single document with no cross-document impact
-->

**Date**: YYYY-MM-DD
**Change Type**: spec_change | constitution_change | template_change | agent_change | hook_change | script_change | contract_change | doc_change
**Origin Document**: [path to the document where the change starts]
**Worktree**: [branch name or worktree identifier]
**Status**: open | propagating | closed

## Change Description

[1-3 sentences: what changed and why]

## Affected Authority Layer

- [ ] source_of_truth
- [ ] dependent
- [ ] informational

## Impact Assessment

<!--
  Impact levels:
  - must_update:  Document MUST be updated. Not updating creates a governance violation.
  - must_review:  Document MUST be reviewed. May or may not need an update.
  - maybe_review: Related but only needs review if the change crosses a specific boundary.
  - reference:    Related in knowledge but no action expected. Do not add to this table.

  Authority values: source_of_truth | dependent | informational
  Status values:    pending | done | skipped (with reason in Notes)

  Use studio/runtime/impact-registry.json to determine impact levels for the change type.
  The registry provides default routing; override with justification when the specific
  change warrants a different level.
-->

| Document | Authority | Impact Level | Status | Notes |
|----------|-----------|--------------|--------|-------|
| [origin path] | [authority] | must_update | done | Origin of this change |
| [path] | [authority] | must_update | pending | [why] |
| [path] | [authority] | must_review | pending | [why] |
| [path] | [authority] | maybe_review | pending | [why] |

## Propagation Order

<!--
  List documents in the order they should be updated.
  Follow the authority chain: source_of_truth first, then dependent, then informational.
  Maximum 3-5 documents per reasoning step to control cognitive load.
-->

1. [first document, with reason]
2. [second document]
3. [third document]

## Completion Criteria

- [ ] All `must_update` rows are `done`
- [ ] All `must_review` rows are `done` or `skipped` with reason
- [ ] Status is `closed`
