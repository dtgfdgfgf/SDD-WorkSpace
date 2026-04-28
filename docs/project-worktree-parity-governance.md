# Project Worktree Parity Governance

**Status:** Canonical
**Effective Date:** 2026-04-02
**Applies To:** All consumer projects under `projects/` and `learning/`

## Purpose

This policy defines the required parity model for derived worktrees created from workspace consumer
projects.

The governing principle is:

- A derived worktree MUST be treated as a project-equivalent instance of the source project.
- A derived worktree MUST NOT be treated as a reduced checkout that is considered healthy only
  because Git-tracked files are present.

This policy exists to prevent agent, operator, or tooling workflows from normalizing a repository's
branch and commit shape while silently breaking the project operating context required by that
project inside this workspace.

## Definitions

| Term | Definition |
|------|------------|
| Root project instance | The primary project checkout created under `projects/<repo>/` or `learning/<repo>/`, including its declared local bootstrap assets and project operating context. |
| Derived worktree | Any additional Git worktree created from the same project repository, regardless of branch name, feature scope, or physical directory name. |
| Project parity surface | The full set of artifacts and runtime assumptions required for a derived worktree to operate as the same project, not merely as the same Git history. |
| Tracked parity | The portion of parity provided by the repository's tracked tree at the checked-out revision. |
| Required local bootstrap parity | Workspace- or project-bootstrap assets that MUST exist or be resolvable for the project to operate correctly in this workspace, even when they are not part of the public tracked tree. |
| Project-declared local-only parity | Additional local-only assets that a specific project declares as operationally required for all of its worktrees, even if those assets are excluded from commits or public snapshots. |

## Core Policy

### 1. Derived Worktrees Are Same-Level Project Instances

Every derived worktree MUST be evaluated as a same-level instance of its source project.

Implications:

- The root project instance is not the only location allowed to have the project's operational
  identity.
- A derived worktree is not healthy merely because `git status` is clean and tracked files exist.
- Project-level operating context MUST remain available in every actively used derived worktree.

### 2. Tracked Parity Alone Is Not Sufficient

Tracked files are necessary but not sufficient.

Agents and operators MUST distinguish between:

- Git branch or commit correctness
- Project-operational completeness inside the workspace

If a derived worktree lacks required local bootstrap parity or declared local-only parity, it MUST
be treated as incomplete even when its tracked tree matches the expected branch.

### 3. Public Snapshot Boundaries Do Not Remove Parity Obligations

The following do **not** authorize the disappearance of required operational assets from derived
worktrees:

- public snapshot rules
- `.gitignore`
- local-only blacklists
- repo-boundary exclusions

If an asset is intentionally excluded from commits but the project still depends on it at runtime or
during agent operation, that asset remains part of the parity surface unless the project has a
documented equivalent source.

### 4. `.git` File Form In A Worktree Is Normal

In a Git worktree, `.git` is often a file that points to shared repository metadata. This is normal
Git plumbing and MUST NOT be treated as a parity defect by itself.

Parity checks MUST evaluate whether Git metadata is functioning correctly, not whether `.git` is a
directory in every derived worktree.

### 5. Cleanup Or Normalization Requires A Parity Comparison First

Before any agent or operator performs cleanup, normalization, branch reshaping, or worktree
recovery, they MUST first compare the source project's parity surface against the target derived
worktree.

At minimum, the comparison MUST ask:

- Which tracked assets define the current project state?
- Which bootstrap assets are required by workspace policy?
- Which local-only assets are declared by the project as operationally required?
- Which assets are shared by junction, mirror, copy, or explicit workspace-level source?

No cleanup action should remove or omit required parity assets solely because they are local-only or
not part of the public tracked tree.

## Minimum Required Bootstrap Parity

Every consumer-project derived worktree MUST have the following minimum parity surface available,
either directly in the worktree or through a documented equivalent source that the project bootstrap
contract explicitly permits.

| Asset | Requirement | Notes |
|------|-------------|-------|
| Git worktree metadata | MUST exist and function correctly | `.git` may be a file in derived worktrees; this is normal. |
| `.github/agents/` junction or equivalent shared runtime entry | MUST be available when the project uses shared runtime agents | Missing runtime entry means agent execution context is incomplete. |
| `.claude/agents/` junction or equivalent shared runtime entry | MUST be available when the project uses shared Claude runtime agents | Missing Claude runtime entry means Claude subagent discovery is incomplete. |
| `AGENTS.md` | MUST be available when the project bootstrap contract requires Codex / Copilot CLI runtime context | Generated governance bootstrap block must stay synchronized with `CLAUDE.md` and `.github/copilot-instructions.md`. |
| `CLAUDE.md` | MUST be available when the project bootstrap contract requires Claude project context | Not every project must have one, but required projects must preserve it. |
| `.github/copilot-instructions.md` | MUST be available when project bootstrap or workspace workflow depends on project-local Copilot context | Workspace-level instructions do not automatically replace project-specific context. |
| `.specify/memory/constitution.md` or explicit equivalent source | MUST be available for projects governed by a project constitution | Equivalent source MUST be documented, not assumed. |
| Project `.code-workspace` | MUST exist for initialized projects that rely on workspace bootstrap expectations | Derived worktrees should remain first-class project instances in editor tooling as well. |

Workspace-level `.claude/agents/` direct junctions are the canonical Claude runtime mechanism.
Project-local Claude agents are not supported by this workspace bootstrap model.

## Project-Declared Local-Only Parity

Projects MAY require additional local-only assets beyond the minimum bootstrap parity surface.

Examples:

- `.claude/`
- private SDK directories
- local workflow assets
- project-specific secrets bootstrap stubs
- local tool mirrors that the project declares as required for normal operation

Rules:

- If a project actually depends on these assets, that dependency MUST be declared in project
  governance or bootstrap documentation.
- Derived worktrees MUST preserve or restore those assets through the project's documented parity
  mechanism.
- These assets do not need to be Git-tracked to remain mandatory for parity.

## Acceptable Parity Mechanisms

Required parity may be satisfied through one of the following documented mechanisms:

- Git-tracked project files
- workspace-level canonical shared sources exposed through junctions or equivalent links
- project bootstrap output created by canonical init scripts
- project-documented local-only mirrors or copies

Undocumented assumptions are not sufficient. If a project depends on a parity asset, the source and
restoration mechanism SHOULD be explicit.

## Non-Goals

This policy does not require:

- every build artifact or cache directory to exist in every worktree
- every ignored file to be mirrored automatically
- immediate implementation of new bootstrap automation in the same change batch as the governance
  rule

The focus is operational parity for project identity, constitutions, agent/runtime access, and
declared project-local workflow context.

## Validation Guidance

When validating a derived worktree, agents and operators SHOULD check:

1. Git state and intended branch ancestry
2. Required bootstrap parity surface
3. Project-declared local-only parity surface
4. Whether any missing asset is covered by a documented equivalent source

If the worktree fails the parity check, it SHOULD be described as a project-parity problem, not
merely as branch drift or a dirty worktree.
