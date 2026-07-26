# SDD Drift Governance Core Logic

> Historical design record. The change-manifest portions were superseded by R-G06 on 2026-07-13.
> Current merge reconciliation lives in `docs/mainline-updates/` and is enforced by Governance CI.

**Status:** Working Note
**Created:** 2026-04-09
**Scope:** Multi-worktree SDD document drift governance

## Original Problem

During project implementation, opening multiple Git worktrees makes SDD-related documents drift
easily.

Typical triggers include:

- feature modification
- new feature introduction
- behavior changes that propagate across specs, contracts, plans, and operational documents

An initial response might be to add more governance rules, but this creates a second problem:

- the more rules that rely on memory or prompt discipline, the more attention burden they place on
  the LLM
- in a multi-worktree setup, parallel work amplifies that burden and makes document synchronization
  less reliable

A follow-up idea is to maintain a file that records relationships between documents. That helps with
visibility, but it introduces another risk:

- if document A is related to many documents, that does not mean changing A requires updating all of
  them
- if every change to A forces the LLM to scan every related document, the governance model becomes
  too expensive and too noisy

There is also a larger concern:

- some spec changes genuinely cascade across many documents
- the goal therefore cannot be "never touch many files"
- the real governance problem is how to control propagation and reconciliation without forcing the
  LLM to read the whole document graph at once

## Core Governance Logic

### 1. Govern Changes, Not Document Links

The primary governance unit should be the `change`, not the document.

The starting question is not:

- "Which files are related to document A?"

The starting question is:

- "What type of change happened?"
- "Which document layers does that change affect?"
- "Which documents must be reviewed or updated for that change type?"

This shifts governance from document-centric bookkeeping to change-centric routing.

### 2. Relationship Does Not Mean Sync Obligation

Document relationships should not be treated as automatic update obligations.

A relationship only says that two documents are connected in knowledge or context. It does not say
that every change in one document requires opening or updating the other.

The practical rule is:

- relationships define a candidate set
- impact rules decide whether a document must be reviewed or updated

Without this distinction, a relationship index becomes a source of over-reading and unnecessary
work.

### 3. Use Conditional Impact Rules Instead of Raw Related Lists

The useful question is not "what is related?" but "under what condition does this become relevant?"

Governance should therefore use conditional routing such as:

- `reference`: related, but not automatically opened
- `maybe_review`: review only when a relevant change type is detected
- `must_review`: review when the change type matches
- `must_update`: update is mandatory when the change type matches

This prevents the system from turning every related document into a mandatory read.

### 4. Classify Documents by Authority Layer

Not all documents should be treated as equally authoritative.

At minimum, documents should be understood in three roles:

- `source of truth`: the document that formally defines the requirement, rule, or behavior
- `dependent`: documents derived from or constrained by the source
- `informational`: overviews, indexes, or explanatory documents that can lag briefly if tracked

The update order should follow the authority chain:

1. update the `source of truth`
2. propagate to `dependent` documents
3. reconcile `informational` documents

This keeps drift bounded even when a change has broad impact.

### 5. Allow Temporary Drift, But Never Unknown Drift

In a multi-worktree environment, temporary drift is often unavoidable.

The governance goal is not perfect instant synchronization. The governance goal is:

- every drift must be known
- every impacted document must be discoverable
- every pending reconciliation must be trackable
- merge must not normalize unknown inconsistency

The real failure mode is not drift itself. The real failure mode is drift that nobody can see or
route.

### 6. Control Per-Step Cognitive Load, Not Total Impact Count

A large spec change may legitimately affect many documents. That is normal.

The key control point is not the total number of impacted files. The key control point is how many
documents the LLM must fully reason about in a single step.

This means:

- many documents may be updated across the life of a change
- only a limited subset should be read in full at one time
- propagation should happen in batches, not by global simultaneous synchronization

So the system should optimize for serial reconciliation rather than one-shot full-context updates.

### 7. Large Cascading Changes Should Be Treated As Propagation Work

When one spec change triggers a broad chain of dependent updates, that should not be handled as an
informal side effect.

It should be treated as explicit propagation work:

- one change introduces the new authoritative state
- a tracked impact set identifies dependent documents
- reconciliation happens step by step
- unfinished propagation remains visible until closed

This reframes large cascades as managed work rather than accidental drift.

### 8. Do Not Rely On LLM Memory For Compliance

Rules such as "remember to update the related docs" are weak governance.

They are memory-based and degrade quickly under:

- parallel worktrees
- long context chains
- repeated prompt handoffs
- partial edits spread across multiple sessions

Governance should instead rely on explicit artifacts and checks:

- document metadata
- change manifests
- impact routing
- PR or CI gates

This moves the system from memory-based governance to evidence-based governance.

### 9. If A Central Index Exists, It Should Be Generated

A central file that records document relationships can be useful, but it should not become a large
manually maintained master list.

Otherwise it becomes one more place where drift happens.

The safer model is:

- each document carries small, local metadata about its role and impact semantics
- tooling generates or refreshes the global index from those local declarations
- LLMs and CI consume the generated index instead of inferring relationships from scratch

This keeps the index useful without turning it into another unstable source of truth.

### 10. Merge Is The Reconciliation Point

Multi-worktree operation should not require each worktree to maintain full global document
consistency at every moment.

Instead:

- each worktree can maintain its own change delta
- propagation can happen incrementally
- merge or PR review becomes the required reconciliation point

This keeps the working model practical while still enforcing convergence before shared history is
updated.

## Governance Summary

The core governance logic can be reduced to five principles:

1. Govern `changes`, not raw document relationships.
2. Treat relationships as candidates, not automatic synchronization obligations.
3. Update by authority order: `source of truth` first, then `dependent`, then `informational`.
4. Allow temporary drift only when it is visible, routed, and reconcilable.
5. Use metadata, manifests, and gates to enforce convergence instead of relying on LLM memory.

## Practical Implication

The fundamental question is not:

- "How do we force the LLM to read every related document?"

The fundamental question is:

- "How do we make each change produce a bounded, explainable, and checkable propagation path?"

Once that is the governance target, multi-worktree SDD drift becomes a routing and reconciliation
problem rather than a prompt-discipline problem.
