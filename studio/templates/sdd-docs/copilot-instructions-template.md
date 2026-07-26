# Copilot Instructions: [PROJECT_NAME]

This file is the GitHub Copilot runtime adapter for this project.

<!--
  Direct Imports note: GitHub Copilot does NOT support Claude's @path import syntax.
  Reference paths to constitutions appear inside the GENERATED GOVERNANCE BOOTSTRAP block as
  human-readable references. The Direct Imports section lives only in CLAUDE.md.
-->

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
- Project and consumer-feature delivery follows: specify, clarify, readiness, plan, tasks, analyze, implement.
- The canonical workspace governance repository may enter Constitution Section 2.1 only after every entry prerequisite is proven and must remain Draft until every closure prerequisite is proven.
- If documents conflict, flag drift instead of silently choosing.
<!-- END GENERATED GOVERNANCE BOOTSTRAP -->

## Tool Notes

- GitHub Copilot and Copilot CLI should follow the governance bootstrap before planning, editing, or suggesting implementation work.
- Keep shared governance additions inside the generated bootstrap block so AGENTS.md and CLAUDE.md can be synchronized.

<!-- MANUAL ADDITIONS START -->
<!-- Add project-specific notes here. This section is preserved when regenerating the file. -->
<!-- MANUAL ADDITIONS END -->
