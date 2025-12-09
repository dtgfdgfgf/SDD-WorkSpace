<!--
SYNC IMPACT REPORT
==================
Version Change: 1.2.0 → 1.2.1
Rationale: PATCH version bump - Validation review confirming all four requested focus areas (code quality, testing standards, user experience consistency, performance requirements) are comprehensively covered in existing principles I-IV

Review Date: 2025-11-30

Principles Validated:
- I. Code Quality ✅ - Comprehensive coverage of naming conventions, documentation, code organization, architectural patterns, DRY principle
- II. Testing Standards ✅ - Full coverage of unit/integration/E2E testing, coverage thresholds, CI/CD integration, test data management
- III. User Experience Consistency ✅ - Complete standards for UI/UX patterns, accessibility (WCAG 2.1 AA), responsive design, user feedback mechanisms
- IV. Performance Requirements ✅ - Detailed benchmarks for page load times, API response times, resource optimization, scalability, monitoring

Existing Principles (Preserved):
- I. Code Quality
- II. Testing Standards
- III. User Experience Consistency
- IV. Performance Requirements
- V. Language and Localization

Added Sections:
- None (validation review only)

Modified Sections:
- None (all principles already meet requirements)

Templates Status:
- ✅ plan-template.md: Compatible - includes Constitution Check section, performance goals, constraints
- ✅ spec-template.md: Compatible - includes user scenarios, acceptance criteria, functional requirements
- ✅ tasks-template.md: Compatible - includes test phases, implementation phases, checkpoint validation
- ✅ .github/prompts/ command templates: Compatible - 9 command prompts available for workflow automation

Follow-up TODOs:
- ⚠️ Verify all existing specs/plans are in zh-TW or schedule translation
- ⚠️ Update command prompts to enforce zh-TW output for specs/plans/docs
- Consider adding automated zh-TW validation for deliverable artifacts in CI/CD
- Consider adding automated performance regression detection in CI pipeline
-->

# Duotify Membership Constitution

## Core Principles

### I. Code Quality

**Principle**: All code MUST be maintainable, readable, and follow established architectural patterns to ensure long-term sustainability and team velocity.

**Standards**:
- **Naming Conventions**: Variables, functions, and classes MUST use descriptive names that reveal intent. Avoid abbreviations unless industry-standard (e.g., API, URL, ID). Use camelCase for variables/functions, PascalCase for classes/components.
- **Documentation**: Every public API, component, and service MUST include JSDoc/TSDoc comments describing purpose, parameters, return values, and examples. Complex business logic MUST include inline comments explaining "why," not "what."
- **Code Organization**: Follow domain-driven design principles. Group related functionality by feature/domain, not by technical layer. Maximum function length: 50 lines. Maximum file length: 300 lines.
- **Architectural Patterns**: MUST use established patterns (e.g., Repository for data access, Service for business logic, Controller for API endpoints). No direct database calls from controllers. Dependency injection required for all services.
- **DRY Principle**: Code duplication beyond 3 lines in more than 2 places MUST be extracted into reusable functions/modules.

**Rationale**: Code quality directly impacts development velocity, bug rates, and team satisfaction. Clear standards reduce cognitive load during code reviews and onboarding.

**Enforcement**: All PRs MUST pass automated linting (ESLint/Prettier) and require 2 approving reviews verifying adherence to these standards.

### II. Testing Standards

**Principle**: Comprehensive automated testing MUST provide confidence in deployments and enable safe refactoring without regression.

**Standards**:
- **Unit Test Coverage**: MUST maintain minimum 80% code coverage. Critical business logic paths MUST have 100% coverage. New code reducing overall coverage below threshold MUST NOT be merged.
- **Integration Testing**: All API endpoints MUST have integration tests covering happy path, error cases, and edge cases. Database interactions MUST be tested against real database instances (test environment).
- **End-to-End Testing**: Critical user journeys (signup, login, subscription management) MUST have automated E2E tests. Run against staging environment before production deployments.
- **Test Documentation**: Each test MUST have descriptive names following pattern: `should_[expected_behavior]_when_[condition]`. Test suites MUST include comments explaining complex setup or assertions.
- **CI/CD Integration**: All tests MUST run on every PR. Unit and integration tests MUST pass before merge. E2E tests MUST pass before production deployment. Failed test = blocked deployment.
- **Test Data Management**: Use factories/fixtures for test data. No hard-coded test data. Integration tests MUST clean up data after execution.

**Rationale**: Testing standards prevent regressions, enable confident refactoring, and serve as executable documentation. High coverage ensures changes don't break existing functionality.

**Enforcement**: CI pipeline MUST block merges if coverage drops below threshold or any tests fail. Monthly review of flaky tests with mandatory fixes within 1 sprint.

### III. User Experience Consistency

**Principle**: Users MUST experience consistent, accessible, and intuitive interfaces across all touchpoints to maximize usability and satisfaction.

**Standards**:
- **UI/UX Patterns**: MUST use established design system components. No custom UI components without design team approval. Consistent spacing, typography, and color usage per design tokens.
- **Accessibility Standards**: MUST comply with WCAG 2.1 Level AA. All interactive elements MUST be keyboard navigable. Form inputs MUST have associated labels. Color contrast ratios MUST meet 4.5:1 minimum. Screen reader testing required for new features.
- **Responsive Design**: All interfaces MUST be fully functional on mobile (320px), tablet (768px), and desktop (1024px+) viewports. Touch targets MUST be minimum 44x44px. Test on iOS Safari, Android Chrome, and desktop browsers.
- **User Feedback Mechanisms**: All user actions MUST provide immediate feedback (loading states, success/error messages). Error messages MUST be actionable ("Email already exists" vs "Error"). Form validation MUST be inline and real-time.
- **Design System Adherence**: MUST use design system (e.g., Material-UI, Ant Design, or custom) for all UI components. No inline styles. CSS modules or styled-components only. Design tokens for colors, spacing, typography.

**Rationale**: Consistent UX reduces user cognitive load, improves conversion rates, and ensures accessibility for all users including those with disabilities.

**Enforcement**: All PRs with UI changes MUST include screenshots/videos for mobile and desktop. Accessibility audits using Axe DevTools required before merge. Design review required for new patterns.

### IV. Performance Requirements

**Principle**: Application performance MUST meet defined benchmarks to ensure optimal user experience and resource efficiency under expected load.

**Standards**:
- **Page Load Times**: Initial page load MUST be < 2 seconds on 3G connection. Time to Interactive (TTI) MUST be < 3.5 seconds. First Contentful Paint (FCP) MUST be < 1.5 seconds.
- **API Response Times**: GET requests MUST respond in < 200ms at p95. POST/PUT/DELETE requests MUST respond in < 500ms at p95. Queries returning > 1000 records MUST implement pagination.
- **Resource Optimization**: Bundle size MUST be < 250KB gzipped for initial load. Images MUST be optimized (WebP format, lazy loading). Code splitting MUST be implemented for routes. No unused dependencies.
- **Scalability Requirements**: System MUST handle 1000 concurrent users without degradation. Database queries MUST be optimized (indexed columns, query analysis). Caching strategy (Redis) required for frequently accessed data.
- **Monitoring & Alerting**: MUST instrument all critical paths with performance monitoring (e.g., DataDog, New Relic). Alerts MUST trigger if p95 response times exceed thresholds. Weekly performance review of slowest endpoints.

**Rationale**: Performance directly impacts user satisfaction, conversion rates, and operational costs. Proactive monitoring prevents performance degradation.

**Enforcement**: CI MUST run Lighthouse audits on PRs (score ≥ 90 required). Load testing required before major releases. Performance regression blocking for p95 increases > 20%.

### V. Language and Localization

**Principle**: All specifications, plans, and user-facing documentation MUST be written in Traditional Chinese (zh-TW) to ensure consistency and accessibility for the target user base. Meta-documents governing the project itself (constitution, internal process templates) remain in English for clarity and consistency.

**Standards**:

**Meta-Document Exemption**:
- **Constitution Document**: This constitution document (`.specify/memory/constitution.md`) MUST remain in English. The constitution is a meta-document that governs the project but exists outside the scope of deliverable artifacts.
- **Internal Process Templates**: Development process templates (`.specify/templates/*.md`, `.github/prompts/*.md`) MAY remain in English as they are internal governance documents. However, these templates MUST generate outputs (specs, plans, tasks) in Traditional Chinese.
- **Scope**: The zh-TW requirement applies to all deliverable artifacts and user-facing content, NOT to internal governance/process documentation.

**Deliverable Artifact Requirements**:
- **Specification Documents**: All feature specifications (`specs/*/spec.md`), implementation plans (`specs/*/plan.md`), and technical design documents MUST be authored in Traditional Chinese (zh-TW). Use proper technical terminology in Chinese with English terms in parentheses for clarity (e.g., "應用程式介面 (API)").
- **User-Facing Content**: All UI text, error messages, help documentation, notifications, and user communications MUST be in Traditional Chinese. No mixed-language content unless explicitly required for technical identifiers.
- **Code Documentation**: Public API documentation, user-facing comments, and README files MUST be in Traditional Chinese. Internal code comments and developer documentation MAY use English for technical precision but SHOULD prefer Traditional Chinese where practical.
- **Existing Documentation Translation**: Any existing documentation (specifications, plans, user-facing content) NOT currently in Traditional Chinese MUST be translated to Traditional Chinese (zh-TW). Translation should be prioritized based on user impact: user-facing content first, then specifications and plans. All new documentation MUST be created in Traditional Chinese from the outset.
- **Variable and Function Naming**: Code identifiers (variables, functions, classes) MUST use English following standard naming conventions for maintainability and tooling compatibility. Comments explaining business logic MUST be in Traditional Chinese.
- **Localization Testing**: All user-facing features MUST be tested with Traditional Chinese content. Test data MUST use realistic Traditional Chinese text (names, addresses, content) to validate layout, encoding, and display.
- **Translation Quality**: Use professional translation services or native Traditional Chinese speakers for user-facing content. Machine translation tools MAY be used for drafts only. Final content MUST be reviewed by native speakers.

**Rationale**: Consistent use of Traditional Chinese ensures the product meets the linguistic and cultural expectations of the target market (Taiwan, Hong Kong, Macau). Proper localization increases user trust, reduces support burden, and demonstrates commitment to the local market. Clear language standards prevent confusion in documentation and maintain professional quality. The constitution itself remains in English to maintain clarity in governance and avoid ambiguity in foundational project rules.

**Enforcement**: All PRs with specifications, plans, or user-facing changes MUST be reviewed for Traditional Chinese compliance. Deliverable documentation in English without justification MUST be rejected. Automated checks for character encoding (UTF-8 with zh-TW locale) required for deliverable artifacts. Localization review by native Traditional Chinese speaker mandatory before production deployment.

## Quality Gates

**Pre-Development Gates**:
- Feature specification MUST be approved with clear acceptance criteria
- Technical design reviewed for architectural alignment
- Performance impact assessment for features touching critical paths

**Pre-Merge Gates**:
- All automated tests passing (unit, integration, E2E where applicable)
- Code coverage threshold maintained (≥ 80%)
- Linting and formatting checks passing
- 2 code review approvals
- Accessibility audit passing for UI changes
- Performance benchmarks met (Lighthouse score ≥ 90)
- Localization compliance verified for specifications and user-facing content

**Pre-Deployment Gates**:
- All E2E tests passing against staging environment
- Manual QA sign-off for high-risk changes
- Performance monitoring shows no degradation in staging
- Database migrations tested and reversible

## Development Workflow

**Feature Development**:
1. Create feature branch from `main` using pattern `[###-feature-name]`
2. Write specifications and plans in Traditional Chinese (zh-TW)
3. Implement following TDD approach: Write tests → Red → Green → Refactor
4. Update documentation (inline comments, API docs, user-facing docs) in Traditional Chinese
5. Run local quality checks before pushing: linting, tests, coverage, localization validation
6. Create PR with description referencing specification and including test evidence

**Code Review Process**:
- Reviewers MUST verify constitution compliance explicitly
- Check for code quality, test coverage, performance implications, accessibility, and localization
- Verify Traditional Chinese content quality and consistency
- Request changes if standards not met
- Re-review after changes until approval

**Merge & Deployment**:
- Squash commits on merge to maintain clean history
- Automated deployment to staging on merge to `main`
- Manual promotion to production after staging validation

**Monitoring & Feedback**:
- Monitor production performance for 24 hours post-deployment
- Address critical issues within 4 hours, high-priority within 24 hours
- Retrospective for incidents to update constitution if needed

## Governance

**Constitution Authority**: This constitution supersedes all other development practices and standards. When conflicts arise, constitution principles take precedence.

**Amendment Process**:
1. Proposed amendments MUST be documented with rationale and impact analysis
2. Team discussion and approval required (≥ 75% consensus)
3. Update constitution with new version following semantic versioning
4. Migration plan required for breaking changes
5. Update all dependent templates and documentation
6. Communicate changes to entire team with transition timeline

**Versioning Policy**:
- **MAJOR**: Breaking changes to principles, removal of standards, incompatible governance changes
- **MINOR**: New principles added, material expansions to existing standards
- **PATCH**: Clarifications, wording improvements, typo fixes, non-semantic updates

**Compliance Review**:
- Monthly constitution compliance audit on random sample of merged PRs
- Quarterly team review to discuss effectiveness and potential improvements
- Annual comprehensive review of all principles and standards

**Complexity Justification**: Any violation of constitution standards MUST be explicitly justified in PR description, documented in Complexity Tracking section of plan.md, and approved by tech lead.

**Version**: 1.2.1 | **Ratified**: 2025-11-24 | **Last Amended**: 2025-11-30
