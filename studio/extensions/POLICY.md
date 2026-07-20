# Studio Extension Policy

## Authority

- `studio/extensions/<id>/` is the canonical source for extension-owned assets.
- `catalog.json` is the workspace governance ledger for review, trust, and rollout.
- The `catalog.json` document format is version `1.2.0`; this version adds required content and approval digests.
- During the `1.2.0` migration, approvals without verifiable evidence for the current bytes are
  cleared and returned to draft review, experimental trust, and disabled-by-default state.
- `state.json` is the workspace enable/disable ledger.
- `resources/studio-runtime/merged/` is a generated mirror only. It is disposable and must never be hand-edited.
- `contentSha256` binds the catalog entry to the current extension bytes. `approvedContentSha256` binds approval evidence to the reviewed bytes.

## Review Status

- `draft`: local intake only; cannot be default-enabled.
- `approved`: curated and allowed to participate in managed rollout.
- `experimental`: locally testable but never default-enabled.
- `deprecated`: still cataloged for compatibility, but should not be newly enabled.
- `rejected`: retained only for audit history; not installable.

## Trust Levels

- `core`: maintained as first-party shared-layer capability.
- `curated`: accepted into the workspace curated catalog after review.
- `experimental`: local-only evaluation status.

## Default Enable Rules

- `defaultEnabled=true` is allowed only when `reviewStatus=approved` and `trustLevel` is `core` or `curated`.
- Uncataloged, `draft`, `experimental`, `deprecated`, and `rejected` extensions are never default-enabled.
- `autoEnableNewExtensions` remains `false`; enablement is always explicit or policy-driven.

## Lifecycle

- Intake: add a local source directory with a valid `manifest.json`.
- Governance: register it in `catalog.json` with `reviewStatus=draft` or stricter.
- Approval: record the reviewed content digest together with `approvedBy` and `approvedAt`.
- Activation: write `state.json` via `set-extension-state.ps1`.
- Runtime: export through `export-extensions.ps1` into the generated merged mirror.
- Removal: remove catalog entry, state entry, and extension directory together.
- Replacement: validate before mutation, reset approval, trust, default enablement, and explicit state, then require a new review.
- Recovery: when a rollback substep fails, preserve the hash-bound transaction under
  `resources/studio-runtime/.extension-transactions/<transaction-id>/` and use the path reported by
  the failed command for manual recovery and verification.

## Guardrails

- No remote catalog sync.
- No direct writes into existing `projects/` or `learning/`.
- No extension may override core shared files or another extension's exported files.
- Entry points must remain inside both the extension root and their normalized declared runtime scope.
- Reparse points are rejected from extension content, including sources accepted by `add-extension.ps1`.
- Export output must stay inside the workspace and is staged before promotion.
- Any add, replacement, enable, disable, or removal invalidates the existing merged mirror.
- Retained transaction journals and baselines are local recovery evidence. They may contain absolute
  workstation paths and must not be staged, committed, or shared. Remove them only after recovery
  and baseline verification are complete.
