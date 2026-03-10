# Studio Extension Policy

## Authority

- `studio/extensions/<id>/` is the canonical source for extension-owned assets.
- `catalog.json` is the workspace governance ledger for review, trust, and rollout.
- `state.json` is the workspace enable/disable ledger.
- `resources/studio-runtime/merged/` is a generated mirror only. It is disposable and must never be hand-edited.

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
- Activation: write `state.json` via `set-extension-state.ps1`.
- Runtime: export through `export-extensions.ps1` into the generated merged mirror.
- Removal: remove catalog entry, state entry, and extension directory together.

## Guardrails

- No remote catalog sync.
- No direct writes into existing `projects/` or `learning/`.
- No extension may override core shared files or another extension's exported files.
- Any path escaping the extension root or shared-layer allowlist is rejected.
