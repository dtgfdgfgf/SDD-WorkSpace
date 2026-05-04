# CLAUDE.md

This file is the Claude Code runtime adapter for [PROJECT_NAME].

<!--
  Direct Imports note (Claude-specific): Claude Code natively supports the @path import syntax
  to inline-load referenced files into the runtime context. AGENTS.md (Codex / Copilot CLI) and
  .github/copilot-instructions.md (Copilot) do NOT support @-imports; their templates therefore
  omit this section by design. When syncing the three adapters via sync-agent-bootstrap.ps1,
  this Direct Imports block stays Claude-only.
-->

## Direct Imports

@[RELATIVE_STUDIO_CONSTITUTION]
@.specify/memory/constitution.md

<!-- BEGIN GENERATED GOVERNANCE BOOTSTRAP -->
## Generated Governance Bootstrap

**Bootstrap Version:** 1
**Studio Constitution:** `[RELATIVE_STUDIO_CONSTITUTION]`
**Studio Constitution Version:** [STUDIO_CONSTITUTION_VERSION]
**Project Constitution:** `.specify/memory/constitution.md`

This runtime adapter participates in dual-layer constitution governance.

Load and apply rules in this order:

1. `[RELATIVE_STUDIO_CONSTITUTION]`
2. `.specify/memory/constitution.md` when present
3. This adapter file

If either required constitution is missing or inaccessible, report governance context incomplete before planning or implementation.

Hard rules:

- Studio Constitution has highest authority.
- Project Constitution can only add stricter rules.
- Agent context files are adapters, not constitutions.
- Governed delivery work follows: specify, clarify, readiness, plan, tasks, analyze, implement.
- If documents conflict, flag drift instead of silently choosing.
<!-- END GENERATED GOVERNANCE BOOTSTRAP -->

## Tool Notes

- Claude Code should use the direct imports plus the generated bootstrap before planning, editing, or running implementation work.
- Keep shared governance additions inside the generated bootstrap block so AGENTS.md and .github/copilot-instructions.md can be synchronized.

<!-- MANUAL ADDITIONS START -->
<!-- Add project-specific notes here. This section is preserved when regenerating the file. -->
<!-- MANUAL ADDITIONS END -->
