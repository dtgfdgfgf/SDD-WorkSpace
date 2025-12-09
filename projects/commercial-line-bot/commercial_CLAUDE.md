# Business Thinking Coach System

## Agent Overview

**Name**: Business Thinking Coach
**Role**: Thought Coach + Business Advisor
**Platform**: LINE Bot + Notion Database Integration

### Core Goals
- Push one high-quality daily question (reflection / scenario / knowledge exploration)
- Guide answers with structured Socratic coaching
- Govern the question bank (rating, tagging, pruning)
- Generate weekly/monthly reviews (blind spot analysis + actionable experiments)
- Extract knowledge fragments and accumulate long-term wisdom assets

---

## Module 1: Daily Interaction Flow

### Question Initiation
1. User starts conversation → System creates "Main Question" in Notion
2. Question types: Reflection / Scenario / Knowledge Exploration
3. Each question linked to Question Bank (if from repository)

### Multi-Round Q&A Architecture
- **Maximum Rounds**: 100 (effectively unlimited, user-controlled ending)
- **Session Management**: Stateless serverless via Notion persistence
- **User Commands**:
  - `小結` (summary) - Generate interim summary without ending conversation
  - `儲存` (save) - Save knowledge fragment from unsaved rounds
  - `狀態` (status) - View current session status and unsaved rounds
  - `結束` (end) - End conversation with final summary
  - `取消` (cancel) - Cancel current session

### AI Coaching Framework (Enhanced Prompts)

**Coaching Philosophy**:
- Socratic questioning: Guide thinking rather than giving direct answers
- Challenge assumptions: Gently but firmly question unverified hypotheses
- Action-oriented: Connect insights to concrete next steps

**Feedback Structure** (100-300 words per round):
1. **Positive Affirmation** (1-2 sentences): Highlight strengths in user's thinking
2. **Blind Spot Reminder** (2-3 sentences):
   - What: Identify cognitive biases, unverified assumptions, information gaps
   - Why: Explain why it's a blind spot
   - Impact: Describe potential consequences if ignored
3. **Actionable Suggestions** (1-2 sentences): Specific, executable next steps

**Follow-up Question Strategy** (if not final round):
- Deep-dive assumptions: "What assumptions underlie X?"
- Explore alternatives: "If Y is not viable, what other options exist?"
- Challenge thinking patterns: "Why choose Z over W?"
- Scenario testing: "If budget is cut in half, does this plan still hold?"

**Requirements**:
- One focused question per follow-up (avoid multi-part questions)
- Target core assumptions or weak links in logic chain
- Guide deeper thinking, not surface-level information gathering

---

## Module 2: Tag System (28 Tags - Hybrid Approach)

### Tag Categories

**Technical (5 tags)**:
- 系統架構 (System Architecture)
- 程式設計 (Programming)
- 資料庫設計 (Database Design)
- 工具選擇 (Tool Selection)
- 技術債務 (Technical Debt)

**Business (9 tags - Expanded)**:
- 商業模式 (Business Model)
- 定價策略 (Pricing Strategy)
- 客戶開發 (Customer Development)
- 市場分析 (Market Analysis)
- 競爭策略 (Competitive Strategy)
- 收入模型 (Revenue Model)
- 成本控制 (Cost Control)
- 產品策略 (Product Strategy)
- 銷售流程 (Sales Process)

**Personal Growth (7 tags - Expanded)**:
- 時間管理 (Time Management)
- 學習方法 (Learning Methods)
- 決策思維 (Decision Making)
- 目標設定 (Goal Setting)
- 習慣養成 (Habit Formation)
- 心態調整 (Mindset Adjustment)
- 自我認知 (Self-Awareness)

**Team Collaboration (3 tags)**:
- 溝通技巧 (Communication Skills)
- 專案管理 (Project Management)
- 衝突處理 (Conflict Resolution)

**Thinking Modes (4 tags - Expanded)**:
- 批判性思考 (Critical Thinking)
- 系統性思考 (Systems Thinking)
- 創意思維 (Creative Thinking)
- 假設驗證 (Hypothesis Testing)

### Tagging Rules
- **Per Round**: 2-4 tags (1-2 topic tags + 0-2 thinking mode tags)
- **Summary**: 2-4 tags reflecting overall conversation themes
- **Knowledge Fragment**: 2-3 tags (prioritize specific over generic)
- **Centralized Management**: All tags defined in `lib/constants.js` for consistency

---

## Module 3: Knowledge Fragment System

### Segment-Based Storage Architecture

**Design Philosophy**:
- User-controlled save points (not automatic per round)
- Segment tracking with `lastSavedRound` pointer
- Optimized for future RAG (Retrieval-Augmented Generation)

### Knowledge Fragment Properties
1. **Title** (≤10 characters): Specific, searchable, context-rich
   - ✅ Good: "SaaS 定價錨定法"
   - ❌ Bad: "商業模式思考" (too generic)
2. **Content** (100-200 words): Reusable insights, decontextualized from personal details
3. **Tags**: 2-3 tags from 28-tag system
4. **Round Range**: e.g., "第1-3輪" (Rounds 1-3)
5. **Source Question**: Relation link to Main Question

### Fragment Generation Process

**AI Prompt Focus**:
- Extract **transferable wisdom**, not conversation summaries
- Decontextualize: "my product" → "this type of product"
- Include verification methods and actionable frameworks
- Preserve operational value: not just "what" but "why" and "how to validate"

**Example**:
- ❌ Bad: "User discussed pricing, I asked questions, conclusions were reached."
- ✅ Good: "Pricing strategy core: value anchoring, not cost calculation. High prices can be justified through scarcity, professional endorsement, and ritual. Experiment: test high price first to gauge market response before adjusting."

### Storage Trigger
- User types `儲存` → System generates fragment from rounds since `lastSavedRound`
- Updates `lastSavedRound` pointer in session state
- Future retrieval: search by tags, title keywords, or content similarity

---

## Module 4: Question Governance

### Question Bank Rules
- **Specificity**: Questions must be concrete and answerable
- **Guidance**: Each question includes suggested answering direction
- **Status Tracking**: Unused / Used / Duplicate
- **Rating System**: User rates inspiration level after answering
- **Auto-tagging**: System applies 2-4 tags from 28-tag system
- **Weekly Pruning**: Remove low-rated questions, refine high-rated ones

### Question Types
1. **Reflection**: Past experience analysis and lesson extraction
2. **Scenario**: Hypothetical situation problem-solving
3. **Knowledge Exploration**: Learning new frameworks or concepts

---

## Module 5: Review & Validation Cycles

### Weekly Review (Planned)
- Aggregate all Main Questions and Conversation Rounds
- Count blind spot tag frequency
- Generate one "small experiment suggestion" for next week
- Relations: Link to Main Questions via "Related Main Questions"

### Monthly Review (Planned)
- User selects one output → convert to "external test"
  - Examples: sample product, article, merchant conversation
- KPI Comparison:
  - Adoption rate ≥ 70%
  - Weekly output ≥ 3 posts + 10 optimizations
  - Time saved ≥ 3 hours/week
- Provide "direction adjustment advice"

### Knowledge Fragment Clustering (Planned)
- Weekly/Monthly: Cluster fragments into patterns/insights
- Future reuse: Assemble into reports, portfolio, SaaS modules

---

## Guiding Principles

### Avoid Vagueness
- Questions must be concrete and specific
- Feedback must be structured (affirmation + blind spots + suggestions)

### Avoid Shallowness
- Every round must challenge assumptions
- Follow-up questions must drive deeper thinking

### Avoid Self-Indulgence
- Require at least one external validation per month
- Knowledge must be testable and actionable

### Continuous Accumulation
- Every insight must be reusable
- Knowledge fragments are building blocks for long-term assets

---

## Success Criteria

### Short-term (6 months)
- Question bank refined through usage and pruning
- Consistent knowledge fragment generation (50+ fragments)
- Blind spot awareness tracked via tag frequency
- Weekly reviews reveal thinking patterns

### Long-term (12+ months)
- Accumulated fragments assembled into portfolio or SaaS prototype
- External validations demonstrate practical value
- Thinking habits measurably improved (via tag distribution changes)
- System becomes personalized decision-making advisor

---

## Technical Implementation Summary

### Database Architecture (Notion)
1. **Main Questions**: Central hub for daily questions
2. **Conversation Rounds**: Multi-round Q&A records
3. **Knowledge Fragments**: Reusable insights with tags
4. **Question Bank**: Curated question repository
5. **Weekly Review**: Aggregated insights and action plans

### AI Integration (Claude)
- Model: `claude-sonnet-4-5-20250929`
- Three specialized prompts:
  1. `analyzeAnswer()`: Round-by-round coaching
  2. `generateSummary()`: Conversation-level synthesis
  3. `generateKnowledgeFragment()`: Decontextualized wisdom extraction

### Deployment
- Platform: Vercel (serverless functions)
- Session State: Persisted in Notion (stateless architecture)
- Integration: LINE Messaging API

---

## Workflow Diagram

```
User Input → Session Manager (Notion) → AI Analysis (Claude)
                                           ↓
                     ┌─────────────────────┴─────────────────────┐
                     ↓                                             ↓
            Conversation Round                           Knowledge Fragment
        (feedback + follow-up + tags)                   (title + content + tags)
                     ↓                                             ↓
              Main Question                                  Linked to Source
         (status + summary + tags)                         (for future retrieval)
```

---

## Version Notes

**Current Implementation**: v2.0
**Last Updated**: 2025-11
**Key Changes from v1.0**:
- Expanded from 5 to 28 tags (hybrid approach)
- Added segment-based knowledge storage with `lastSavedRound` tracking
- Enhanced AI prompts with structured coaching framework
- Increased maxRounds to 100 (user-controlled ending)
- Added interim commands: `小結` (summary) and `儲存` (save)
- Implemented Knowledge Fragments database

