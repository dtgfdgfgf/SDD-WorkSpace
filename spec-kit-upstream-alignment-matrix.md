# Spec Kit Upstream Alignment Matrix（2026-03-08）

## Purpose

This document defines how this workspace will align to the latest upstream `github/spec-kit` while
preserving the local `studio-first` architecture.

Detailed transition guide: `spec-kit-upstream-wave2-transition-guide.md`

## Hard Constraints

- Keep `studio-first template precedence`.
- Do not modify existing projects in `projects/` or `learning/` as part of this alignment wave.
- Do not refactor `update-agent-context.ps1` in this wave.
- Do not adopt repo-local full `.specify` migration.

## Decision Matrix

| Upstream capability | Local status before this wave | Decision | Local adaptation / rationale |
|---------------------|-------------------------------|----------|------------------------------|
| `/speckit.*` namespaced commands | Already adopted | Keep | Already consistent with local workflow |
| `clarify / analyze / checklist / taskstoissues` | Already adopted | Keep | Already part of local runtime and docs |
| Broader multi-agent support | Already adopted in practice | Keep | `update-agent-context.ps1` already supports many agent types |
| Constitution preservation on re-init | Already aligned in spirit | Keep | Local init flow preserves or creates project constitution stubs |
| `specify version` | Not available locally | Adopted | Local adaptation via `get-speckit-version.ps1` plus `/speckit.version` |
| `--ai generic --ai-commands-dir ...` | Not available locally | Adopted | `export-generic-agent-pack.ps1` exports shared agents/prompts for unsupported or BYO agents |
| `--ai-skills` | Not available locally | Adopted (export-only) | `export-agent-skills.ps1` exports generated skill packs from shared runtime sources without installing into agent homes |
| Extension system | Not available locally | Adopted (registry foundation) | `studio/extensions/`, `catalog.json`, `state.json`, `list-extensions.ps1`, and `set-extension-state.ps1` establish the shared-layer registry without repo-local behavior |
| Catalog / extension lifecycle | Not available locally | Defer | Depends on trust policy, lifecycle boundaries, and curated distribution rules |
| Community extension ecosystem | Not available locally | Defer | Too early before local catalog governance exists |
| Repo-local full `.specify` migration | Intentionally not used | Reject | Conflicts with `studio-first` centralized runtime model |

## Implemented So Far

1. **Local version capability**
   - Script: `studio/scripts/powershell/get-speckit-version.ps1`
   - Agent: `.github/agents/speckit.version.agent.md`
   - Prompt: `.github/prompts/speckit.version.prompt.md`
   - Mirror: `studio/templates/sdd-agents/speckit.version.agent.md`

2. **Generic/BYO agent pack export**
   - Script: `studio/scripts/powershell/export-generic-agent-pack.ps1`
   - Purpose: export runtime agents/prompts as a mirror pack for unsupported agent environments

3. **AI skills export model**
   - Script: `studio/scripts/powershell/export-agent-skills.ps1`
   - Output: `resources/agent-skill-packs/<target>/`
   - Current targets: `codex`, `claude`
   - Model: generated skill mirrors from `.github/agents/` and `.github/prompts/`

4. **Extension registry foundation**
   - Canonical source: `studio/extensions/`
   - Registry files: `manifest.schema.json`, `catalog.json`, `state.json`
   - Scripts: `list-extensions.ps1`, `set-extension-state.ps1`
   - Model: workspace-level registry only; no project-local extension trees

## Explicit Non-Goals For This Wave

- No migration of existing projects
- No rework of `update-agent-context.ps1`
- No change to `studio-first template precedence`
- No extension runtime export or install manager yet
- No direct install into agent home directories

## Recommended Next Wave

After this wave, evaluate these in order:

1. Curated catalog policy and trust model
2. Extension runtime export / lifecycle boundaries
3. Optional skill installation convenience on top of the export-only model

## Validation Notes

This wave should be validated with:

- `get-speckit-version.ps1 -Json`
- `export-generic-agent-pack.ps1 -OutputDir <workspace-local-path> -Json`
- `export-agent-skills.ps1 -Target codex -OutputDir <workspace-local-path> -Json`
- `export-agent-skills.ps1 -Target claude -OutputDir <workspace-local-path> -Json`
- `list-extensions.ps1 -Json`
- `set-extension-state.ps1 -Id <registered-extension> -State enabled -Json`
- `/speckit.version` in the agent runtime
