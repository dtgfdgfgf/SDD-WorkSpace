# Project Constitution: [PROJECT NAME]

**Version:** 1.0.0  
**Project Type:** Practice | Internal | Client  
**Created:** [DATE]

---

## Purpose

This constitution defines project-specific rules that ADD to the Studio Constitution.

**Governance Priority:**
1. Studio Constitution (`studio/constitution/constitution.md`) — HIGHEST AUTHORITY
2. This Project Constitution — Additive rules only

This document can only ADD stricter rules, never relax Studio Constitution rules.

---

## Studio Reference Paths

This project follows the SDD methodology defined at workspace level.

| Resource | Path (from multi-root workspace) | Purpose |
|----------|----------------------------------|--------|
| Studio Constitution | `studio/constitution/constitution.md` | Highest authority rules |
| SDD Agents | `studio/templates/sdd-agents/` | Workflow agents |
| SDD Doc Templates | `studio/templates/sdd-docs/` | Document templates |
| Scripts | `studio/scripts/powershell/` | Automation scripts |
| Prompts | `studio/prompts/<stage>/` | Stage-specific prompts |
| Learnings | `studio/knowledge-base/learnings.md` | Cumulative learnings |

**Note**: Open this project using `<project-name>.code-workspace` to ensure all studio paths are accessible as read-only folders.

---

## Project Context

### Domain

[Describe the project domain, e.g., "E-commerce order management system"]

### Target Users

[Who will use this system?]

### Key Terminology

| Term | Definition |
|------|------------|
| [Term 1] | [Definition] |
| [Term 2] | [Definition] |

---

## Project-Specific Rules

### Code Standards (Additive)

[Add stricter coding standards if needed, e.g.:]

- All database queries MUST use parameterized statements
- API responses MUST follow JSON:API specification
- [Add more as needed]

### Testing Requirements (Additive)

[Add stricter testing requirements if needed, e.g.:]

- Integration tests MUST cover all API endpoints
- E2E tests required for checkout flow
- [Add more as needed]

### Documentation Requirements (Additive)

[Add stricter documentation requirements if needed, e.g.:]

- All API endpoints MUST have OpenAPI documentation
- User-facing features MUST have user guide documentation
- [Add more as needed]

---

## Quality Gates (Project-Specific)

### Pre-Development Gates

- [ ] [Project-specific gate 1]
- [ ] [Project-specific gate 2]

### Pre-Deployment Gates

- [ ] [Project-specific gate 1]
- [ ] [Project-specific gate 2]

---

## Constraints

### Technical Constraints

- [e.g., Must run on Node.js 18+]
- [e.g., Database must be PostgreSQL]

### Business Constraints

- [e.g., Must comply with GDPR]
- [e.g., Must support Traditional Chinese (zh-TW)]

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | [DATE] | Initial project constitution |
