# CLAUDE.md

This file is the Claude Code runtime adapter for Workspace.

<!-- governance-anchor: claude-direct-imports -->
## Direct Imports

@studio/constitution/constitution.md

<!-- BEGIN GENERATED GOVERNANCE BOOTSTRAP -->
## Generated Governance Bootstrap

**Bootstrap Version:** 1
**Studio Constitution:** `studio/constitution/constitution.md`
**Studio Constitution Version:** 1.9.0
**Project Constitution:** `N/A (workspace root)`

This runtime adapter participates in dual-layer constitution governance.

Load and apply rules in this order:

1. `studio/constitution/constitution.md`
2. `.specify/memory/constitution.md` when present
3. This adapter file

If either required constitution is missing or inaccessible, report governance context incomplete before planning or implementation.

Hard rules:

- Studio Constitution has highest authority.
- Project Constitution can only add stricter rules.
- Agent context files are adapters, not constitutions.
- Project and consumer-feature delivery follows: specify, clarify, readiness, plan, tasks, analyze, implement.
- The canonical workspace governance repository may enter Constitution Section 2.1 only after every entry prerequisite is proven and must remain Draft until every closure prerequisite is proven.
- If documents conflict, flag drift instead of silently choosing.
<!-- END GENERATED GOVERNANCE BOOTSTRAP -->

<!-- governance-anchor: claude-tool-notes -->
## Tool Notes

- Claude Code should use the direct imports plus the generated bootstrap before planning, editing, or running implementation work.
- Keep shared governance additions inside the generated bootstrap block so AGENTS.md and .github/copilot-instructions.md can be synchronized.

<!-- MANUAL ADDITIONS START -->

<!-- MANUAL ADDITIONS END -->
