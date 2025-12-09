2# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## AI Workflow Rules

**IMPORTANT: These rules MUST be followed automatically without asking the user:**

1. **Bilingual Documentation**
   - When generating or updating CLAUDE.md (English), ALWAYS automatically generate or update CLAUDE-zh-tw.md (Traditional Chinese) in parallel
   - Both files must contain identical information, only differing in language
   - CLAUDE.md must be in English
   - CLAUDE-zh-tw.md must be in Traditional Chinese (繁體中文)

2. **Automatic Git Push and Deployment**
   - After ANY code changes, MUST follow this two-step sequence:

   **Step 1: Push to GitHub (MANDATORY)**
   - Execute `git add . && git commit -m "..." && git push`
   - Verify push success with `git status` or `git log --oneline -3`
   - This step is REQUIRED even if Vercel deployment fails
   - GitHub serves as the source of truth and version control

   **Step 2: Deploy to Vercel Production (MANDATORY)**
   - Execute `vercel --prod` after successful GitHub push
   - Verify deployment success with `vercel ls` or `vercel inspect`
   - If deployment fails, retry with `vercel --prod`
   - Check deployment status in output

   - NO user confirmation needed - proceed automatically with both steps
   - Both steps must complete for each code change

3. **Business Logic Synchronization**
   - When updating code that affects Q&A logic, AI prompts, tag system, or core workflow, MUST review and update `commercial_CLAUDE.md`
   - Ensure documentation accurately reflects current implementation
   - The business logic document is the source of truth for system design decisions

4. **Commercial Documentation Translation**
   - When updating `commercial_CLAUDE.md`, MUST create or update `commercial_CLAUDE-zh-tw.md` (Traditional Chinese version)
   - `commercial_CLAUDE.md` MUST always be in English
   - `commercial_CLAUDE-zh-tw.md` must be complete Traditional Chinese translation

5. **Language Requirements**
   - `CLAUDE.md` → English only
   - `commercial_CLAUDE.md` → English only
   - `CLAUDE-zh-tw.md` → Traditional Chinese (完整翻譯版本)
   - `commercial_CLAUDE-zh-tw.md` → Traditional Chinese (完整翻譯版本)

6. **Communication Language Rules**
   - **ALL responses, explanations, and user communications MUST be in Traditional Chinese (繁體中文)**
   - **MUST NOT use Simplified Chinese (簡體中文) or English in responses**
   - Technical terms without standard Chinese translations may remain in English
   - When using emoji in code, carefully check for potential bugs:
     - Emoji uses UTF-16 encoding and may occupy 2 code units
     - String operations like `substring()` or `.length` may cause issues with emoji
     - Use `[...text]` or `Array.from(text)` for safe string manipulation
     - Avoid storing emoji in database keys or critical identifiers

7. **Documentation Synchronization**
   - When ANY code changes are made, MUST review and update `CLAUDE.md` if needed
   - Critical areas requiring documentation updates:
     - Architecture changes (new modules, modified flow)
     - New features or commands
     - Database schema modifications
     - API integrations or external service changes
     - Configuration or environment variable changes
     - Changes to conversation flow or business logic
   - If `CLAUDE.md` is updated, MUST also update `CLAUDE-zh-tw.md` accordingly
   - Keep documentation in sync with actual implementation to prevent outdated information
   - Documentation should always reflect the current state of the codebase

8. **Detailed Commit Messages**
   - Every file change MUST be explicitly documented in the commit message
   - Use structured commit message format:
     ```
     <type>(<scope>): <subject>

     <body>
     - File1: What changed and why
     - File2: What changed and why
     - File3: What changed and why

     <footer>
     ```

   **Commit Message Requirements:**
   - **Type**: feat, fix, docs, refactor, chore, test, style, etc.
   - **Scope**: Module or component affected (e.g., ai, notion, webhook, docs)
   - **Subject**: Brief summary (50 chars or less)
   - **Body**: Detailed explanation for EACH changed file
     - What was changed in each file
     - Why the change was necessary
     - Impact of the change
   - **Footer**: Co-authored-by, references, breaking changes

   **Example:**
   ```
   refactor(ai): Increase tag count from 2-4 to 3-6 per round

   - lib/ai.js: Updated analyzeAnswer() prompt to request 3-6 tags
     - Changed tag selection strategy to be more comprehensive
     - Added requirement for 1-2 topic + 1-2 thinking + 0-2 growth tags
   - CLAUDE.md: Documented new tag generation strategy
     - Added tag count details to lib/ai.js section
   - CLAUDE-zh-tw.md: Synchronized Chinese version with English changes

   🤖 Generated with [Claude Code](https://claude.com/claude-code)
   Co-Authored-By: Claude <noreply@anthropic.com>
   ```

   **Benefits:**
   - Clear change tracking for each file
   - Easier code review and history navigation
   - Better understanding of why changes were made
   - Improved collaboration and knowledge transfer

## Code Review Principles

**Purpose**: These principles help AI conduct effective code reviews focused on this project's specific risks.

### Core Review Rules (Essential)

When reviewing code changes, prioritize these checks:

1. **External API Error Handling**
   - All calls to LINE, Notion, and Claude APIs must have proper error handling
   - Include timeout handling and retry logic where appropriate
   - Log errors with sufficient context for debugging
   - Gracefully handle API failures without crashing the bot

2. **Serverless State Management**
   - Remember that sessions are stored **in-memory only** (cleared on restart)
   - Never assume session data persists between function invocations
   - Document any code that relies on session state
   - Consider edge cases when sessions are lost mid-conversation

3. **Auto-Deployment Impact**
   - Every commit triggers automatic production deployment
   - Test thoroughly before committing - there's no staging gate
   - Consider backward compatibility with active user conversations
   - Avoid breaking changes to Notion schema or API contracts

4. **Notion Schema Alignment**
   - Verify code matches the actual Notion database schema
   - Check property names (問題, 狀態, 總結, etc.) match exactly
   - Test relation fields (來源題目, 所屬問題) are correctly linked
   - Update schema documentation if database structure changes

5. **Claude API Cost Control**
   - Be mindful of token usage in prompts and responses
   - Avoid unnecessary API calls (e.g., in loops or error retries)
   - Verify conversation history doesn't grow unbounded
   - Consider cost impact of new features

6. **Language Consistency**
   - User-facing messages must be in Traditional Chinese (繁體中文)
   - Code comments and internal logs can be in English
   - Error messages shown to users must be helpful and in Chinese
   - Maintain consistent terminology (問, 結束, 狀態, 幫助)

7. **Documentation Synchronization**
   - Update `CLAUDE.md` + `CLAUDE-zh-tw.md` when workflow changes
   - Update `commercial_CLAUDE.md` + `commercial_CLAUDE-zh-tw.md` when business logic changes
   - Keep documentation in sync with actual implementation
   - Document breaking changes or new environment variables

### Review Severity Levels

Use these labels to prioritize issues:

- 🚨 **BLOCKING** - Critical issues that must be fixed immediately
  - Security vulnerabilities, data loss risks, breaking production functionality

- ⚠️ **MUST-FIX** - Important issues that should be fixed before merging
  - Bugs, poor error handling, maintainability problems, missing documentation

- 💡 **SUGGESTION** - Nice-to-have improvements
  - Code style, minor optimizations, best practice recommendations

### When to Conduct Reviews

- Before committing any code changes (since auto-deployment is active)
- When external dependencies are updated
- When business logic or conversation flow changes
- When Notion schema is modified

### Extended Guidelines

For comprehensive review criteria beyond this project's specific needs, consult general software engineering best practices. These 7 core rules represent the 80/20 - focus here first.

## Project Overview

**LINE Bot x Notion x Claude AI - Business Thinking Coach System**

A comprehensive conversational bot that delivers daily business thinking questions via LINE, analyzes user responses with Claude AI, and records everything to Notion databases. The system includes both the production runtime (LINE Bot + AI + Notion integration) and development tools for database initialization and testing.

### System Components

1. **Production Runtime** (`api/`, `lib/`)
   - LINE webhook handler for receiving user messages
   - Session management for multi-turn conversations
   - Claude AI integration for intelligent feedback
   - Notion API integration for data persistence
   - Analytics and reporting for weekly insights
   - Knowledge search and topic summarization

2. **Database Setup Tools** (`scripts/`)
   - Database initialization scripts
   - Test data generation
   - Schema validation utilities

## Development Commands

### Setup
```bash
npm install
```

### Local Development
```bash
npm run dev          # Start Vercel dev server
vercel dev           # Alternative command
```

### Production Deployment
```bash
npm run deploy       # Deploy to Vercel production
vercel --prod        # Alternative command
```

### Database Management
```bash
npm run init:db      # Initialize all 4 Notion databases
npm run test:db      # Create sample test data
npm run test:db-all  # Create comprehensive test data
npm run check:db     # Check database schema
```

Direct script execution:
```bash
node scripts/init.js       # Initialize databases
node scripts/test.js       # Simple test
node scripts/test-all.js   # Comprehensive test
node scripts/check-db.js   # Schema verification
```

No test suite is currently configured.

## Architecture

### Production Runtime Flow

```
LINE User Message
  → LINE Webhook (/api/webhook.js)
  → Session Manager (lib/sessionManager.js) - checks conversation state
  → Command Handler OR Answer Handler
  → AI Analysis (lib/ai.js) - Claude Sonnet 4.5
  → Notion Recording (lib/notion.js)
  → Analytics (lib/analytics.js) - for weekly reports
  → LINE Reply
```

### Core Components

**api/webhook.js** - Main entry point
- Handles LINE webhook POST requests
- Routes 15 commands:
  - Structured Training: `問` (start), `儲存` (save), `小結` (summary), `結束` (end), `狀態` (status)
  - Knowledge Search: `查詢` (search by tag), `總結` (generate topic summary)
  - Analytics: `週報` (weekly report), `標籤列表` (tag statistics), `總結狀態` (summary status), `總結 [類別]` (batch summary by category)
  - System: `清除` (clear), `系統` (system info), `幫助` (help)
  - Free Conversation: Any text without active structured session
- Manages two operational modes:
  1. **Structured Training**: Multi-turn Q&A with AI feedback (max 100 rounds, user-controlled ending)
  2. **Free Conversation**: Direct chat with Claude AI without structured workflow
- Command handlers:
  - `handleSearchKnowledge()`: Three-layer knowledge search (Topic Summary > Knowledge Fragments > Conversation Summary)
  - `handleWeeklyReport()`: Generate weekly thinking report with tag analysis
  - `handleTagList()`: Show all 28 tags with usage statistics
  - `handleGenerateTopicSummary()`: Generate or update comprehensive topic summary for a single tag
  - `handleBatchSummaryByCategory()`: Batch generate summaries for all tags in a category (e.g., 技術類, 商業類)
  - `handleSummaryStatus()`: View summary status for all 28 tags with smart update recommendations
  - `handleHelp()`: Updated to include all 15 commands
- Orchestrates between session, AI, Notion, and analytics modules

**lib/sessionManager.js** - In-memory conversation state (for Structured Training)
- Uses Map() to store user sessions (cleared on serverless restart)
- Tracks: question, round number (1-100), conversation history, lastSavedRound
- Session structure includes all Q&A rounds with full context
- **IMPORTANT**: Production should use Redis/database instead
- Auto-cleanup: removes sessions inactive for 2+ hours

**lib/directChat.js** - Free conversation mode with RAG (Retrieval Augmented Generation)
- Enables unstructured dialogue with Claude AI outside structured training
- **NEW: Integrated RAG knowledge retrieval** for contextual responses
- Automatically searches user's knowledge base when relevant topics detected
- Independent conversation history per user (last 10 rounds)
- No round limits or Notion recording
- Used when user sends message without active structured session
- Flow: User message → RAG retrieval → Enhanced AI response with knowledge context

**lib/rag.js** - RAG (Retrieval Augmented Generation) module
- **Core feature**: Contextual knowledge retrieval for intelligent conversations
- `extractRelevantTags()`: Uses Claude to identify 1-3 relevant tags from user message
  - Analyzes message intent and context
  - Returns tags, keywords, and confidence level (high/medium/low)
  - Filters out irrelevant messages (casual chat)
- `retrieveRelevantKnowledge()`: Three-layer knowledge search
  - Layer 0: Topic Summary (if single tag)
  - Layer 1: Knowledge Fragments (up to 3)
  - Layer 2: Main Questions (up to 2)
  - Returns combined results with metadata
- `formatKnowledgeForPrompt()`: Structures retrieved knowledge for AI injection
  - Formats summaries, fragments, and historical blind spots
  - Provides coaching hints for AI to reference user's past insights
  - Keeps prompt concise (summaries truncated to 500 chars)
- `performRAG()`: Complete RAG pipeline in one call
  - Extracts tags → Retrieves knowledge → Formats prompt
  - Returns enhanced prompt and metadata for logging
- **User experience**: AI naturally references past knowledge like "根据你之前的洞察..."
- **Smart filtering**: Only activates on relevant topics (confidence threshold)

**lib/ai.js** - Claude AI integration
- Uses `claude-sonnet-4-5-20250929` model
- `analyzeAnswer()`: Provides feedback + follow-up question based on conversation depth
  - Generates 3-6 tags per round for comprehensive categorization
  - Tag strategy: 1-2 topic tags + 1-2 thinking tags + 0-2 growth/collaboration tags
- `generateSummary()`: Creates conversation summary with blind spot tags
- `generateKnowledgeFragment()`: Extracts reusable knowledge from conversation rounds
- `generateTopicSummary()`: Creates comprehensive topic summaries integrating knowledge fragments, main questions, and conversation rounds
  - Synthesizes all content related to a specific tag
  - Provides structured insights with key patterns, best practices, and action items
  - Supports both single and multi-tag queries
- Always expects JSON responses from Claude, with fallback parsing

**lib/notion.js** - Notion database operations
- 5 databases: Question Bank (題庫), Daily Q&A (主問題), Conversation Rounds (回合), Knowledge Fragments (知識片段), Topic Summary (主題總結)
- Question lifecycle: fetch random unused → create main Q&A → mark as used
- Records each round with user answer, AI feedback, AI follow-up, tags
- Updates main Q&A with summary and blind spot tags when complete
- Creates knowledge fragments for extracting and storing reusable insights
- **New: Knowledge Search Functions** (3 functions):
  - `searchKnowledgeByTag()`: Search knowledge fragments by single tag
  - `searchKnowledgeByMultipleTags()`: Search by multiple tags with AND logic
  - `getAllKnowledgeFragments()`: Retrieve all knowledge fragments
- **New: Rounds Search Functions** (3 functions):
  - `searchRoundsByTag()`: Search conversation rounds by single tag
  - `searchRoundsByMultipleTags()`: Search rounds by multiple tags with AND logic
  - `formatRoundContent()`: Format round data for display with user answer, AI feedback, and source question
- **New: Main Questions Search Functions** (2 functions):
  - `searchMainQuestionsByTag()`: Search main questions by single tag
  - `searchMainQuestionsByMultipleTags()`: Search by multiple tags with AND logic
- **New: Topic Summary Functions** (4 functions):
  - `createTopicSummary()`: Create new topic summary entry
  - `updateTopicSummary()`: Update existing topic summary
  - `getTopicSummaryByTag()`: Retrieve topic summary for specific tag
  - `getAllContentByTag()`: Comprehensive retrieval of all content (knowledge fragments, rounds, main questions) by tag
- Key original functions:
  - `getRandomQuestion()`, `markQuestionAsUsed()`: Question management
  - `createMainQuestion()`, `completeMainQuestion()`, `updateMainQuestionSummary()`: Main Q&A lifecycle
  - `createConversationRound()`: Round recording
  - `createKnowledgeFragment()`, `getKnowledgeFragments()`: Knowledge management

**lib/analytics.js** - Data analysis and weekly report generation
- `getMainQuestionsByDateRange()`: Fetch all main questions within a date range with their properties (tags, summary, status)
- `getKnowledgeFragmentsByDateRange()`: Retrieve knowledge fragments created within a date range
- `generateWeeklyReport()`: Generate comprehensive weekly thinking report
  - Analyzes tag frequency and patterns
  - Identifies top insights and growth areas
  - Provides weekly summary with actionable recommendations
  - Integrates data from main questions and knowledge fragments
- `getAllTagsFrequency()`: Calculate usage statistics for all 28 blind spot tags
  - Returns tag counts across all databases
  - Helps identify thinking patterns and focus areas
  - Supports tag statistics display in `標籤列表` command

**scripts/init.js** - Database initialization
- Creates all 5 Notion databases with proper schema
- Establishes bidirectional relations between databases
- Two-phase creation: databases first, then relations

**lib/constants.js** - Shared constants and tag definitions
- 28 blind spot tags organized in 5 categories:
  - Technical Domain (技術面): 技術盲點, 產品設計盲點, 數據分析盲點
  - Business Domain (商業面): 商業盲點, 財務盲點, 策略盲點
  - Thinking Patterns (思維面): 思維盲點, 問題定義, 解決方案思考
  - Collaboration (協作面): 協作盲點, 領導力, 利害關係人管理
  - Personal Growth (個人成長面): 個人成長盲點, 學習方法, 職涯發展
  - Plus 14 specialized tags: Risk Management, User Empathy, Market Validation, etc.
- `getTagsByCategory()`: Returns formatted tag list for AI prompts
- Used across runtime (lib/) and setup scripts (scripts/)

**scripts/constants.js** - Setup script constants
- Converts tag definitions to Notion format for database initialization
- Provides question type options
- Exported for use in initialization and test scripts

### Conversation Flow

**Structured Training Mode:**
1. User sends `問` command
2. Bot fetches random question from Notion Question Bank (status: 未使用)
3. Creates session + main question record in Notion
4. User answers → AI analyzes → records round to Notion
5. Continues for up to 100 rounds (user decides when to end)
6. During conversation:
   - `小結` - Generate interim summary without ending (updates Notion, conversation continues)
   - `儲存` - Save conversation fragment as knowledge (tracks lastSavedRound)
   - `狀態` - Check current status (round number, unsaved rounds)
7. When user sends `結束` or AI decides conversation is complete:
   - Generate final summary with blind spot tags
   - Update Notion main question as completed
   - Clear session

**Free Conversation Mode:**
- User sends any text without active structured session
- Direct chat with Claude AI via lib/directChat.js
- No Notion recording, no round limits
- `清除` command clears conversation history

**Knowledge Search Mode:**
- User sends `查詢 [標籤]` or `查詢 [標籤1]+[標籤2]` to search by tag(s)
- Three-layer search strategy:
  1. Topic Summary: Check for existing comprehensive summary
  2. Knowledge Fragments: Search saved knowledge entries
  3. Conversation Summary: Search main question summaries
- Supports both single tag and multiple tags (AND logic)
- Returns formatted results with source references

**Analytics Mode:**
- User sends `週報` to generate weekly thinking report
- Analyzes last 7 days of conversations and knowledge fragments
- Provides tag frequency analysis and growth insights
- User sends `標籤列表` to view all 28 tags with usage statistics
- User sends `總結 [標籤]` to generate or update topic summary for a specific tag
- User sends `總結 [類別]` to batch generate summaries for all tags in a category (e.g., 技術類, 商業類)
- User sends `總結狀態` to view summary status dashboard with smart update recommendations

### Database Architecture

The system consists of 5 interconnected Notion databases with bidirectional relations:

1. **Daily Q&A (Main Questions)** - Central hub tracking daily questions
2. **Conversation Rounds** - Multi-round Q&A interactions linked to main questions
3. **Question Bank** - Repository of curated questions with usage tracking
4. **Knowledge Fragments (知識片段)** - Extracted reusable insights from conversations
5. **Topic Summary (主題總結)** - Comprehensive summaries organized by tags
6. **Weekly Review** - Aggregated insights and action plans (optional, not yet implemented in runtime)

#### Database Relationships

- Main Questions → Rounds (one-to-many via "Round Records")
- Main Questions → Question Bank (via "Source Question")
- Main Questions → Knowledge Fragments (one-to-many via "Related Knowledge")
- Main Questions → Weekly Review (via "Weekly Association")
- Topic Summary → Knowledge Fragments (via "Related Knowledge")
- Topic Summary → Main Questions (via "Related Main Questions")
- All relations are created programmatically except Rollup fields (must be added manually in Notion UI)

#### Two-Phase Database Creation

Due to Notion API limitations with circular relations, databases are created in two phases:

1. **Phase 1**: Create all 5 databases with their basic properties
2. **Phase 2**: Update databases to add cross-references and relations

This two-phase approach is necessary because you cannot reference a database that doesn't exist yet.

## Environment Variables

Required in `.env` (see `.env.example`):

**Production Runtime:**
- `LINE_CHANNEL_ACCESS_TOKEN` / `LINE_CHANNEL_SECRET`
- `ANTHROPIC_API_KEY`
- `NOTION_TOKEN`
- `NOTION_MAIN_DB_ID` - ID of Daily Q&A database
- `NOTION_ROUNDS_DB_ID` - ID of Conversation Rounds database
- `NOTION_QUESTION_BANK_DB_ID` - ID of Question Bank database
- `NOTION_KNOWLEDGE_DB_ID` - ID of Knowledge Fragments database (optional, for knowledge management feature)
- `NOTION_TOPIC_SUMMARY_DB_ID` - ID of Topic Summary database (required for topic summary and knowledge search features)

**Database Initialization (scripts/):**
- `NOTION_TOKEN` - Notion integration token
- `PARENT_PAGE_ID` - Parent page where databases will be created (for init.js)
- `MAIN_DB_ID` - (For test scripts) Same as NOTION_MAIN_DB_ID
- `ROUNDS_DB_ID` - (For test scripts) Same as NOTION_ROUNDS_DB_ID
- `QUESTION_BANK_DB_ID` - (For test scripts) Same as NOTION_QUESTION_BANK_DB_ID
- `WEEKLY_DB_ID` - (For test scripts) ID of Weekly Review database

**NOTE**: .env.example contains actual credentials - ensure these are rotated if compromised.

## Notion Database Schema

### Question Bank (題庫)
- 問題 (title), 類型 (select), 建議回答方向 (rich_text)
- 狀態 (select): 未使用/已使用/重複
- 使用日期 (date)
- 關聯主問題 (relation → Daily Q&A)

### Daily Q&A (主問題)
- 問題 (title), 日期 (date), 問題類型 (select)
- 狀態 (select): 進行中/已完成
- 總結 (rich_text), 盲點標籤 (multi_select - 28 tags)
- 來源題目 (relation → Question Bank)
- 回合紀錄 (relation → Conversation Rounds)
- 關聯知識 (relation → Knowledge Fragments)
- 週報關聯 (relation → Weekly Review)

**Blind Spot Tags (28 multi_select options organized in 5 categories):**
- **Technical Domain**: 技術盲點, 產品設計盲點, 數據分析盲點
- **Business Domain**: 商業盲點, 財務盲點, 策略盲點
- **Thinking Patterns**: 思維盲點, 問題定義, 解決方案思考
- **Collaboration**: 協作盲點, 領導力, 利害關係人管理
- **Personal Growth**: 個人成長盲點, 學習方法, 職涯發展
- **Plus 14 specialized tags**: Risk Management, User Empathy, Market Validation, Resource Allocation, Team Culture, Communication Effectiveness, Process Optimization, Goal Setting, Time Management, Decision Framework, Feedback Loop, Competitive Analysis, Customer Journey, Value Proposition

### Conversation Rounds (回合)
- 標題 (title), 回合編號 (number)
- 所屬問題 (relation → Daily Q&A)
- 使用者回答, AI 回饋, AI 追問 (all rich_text)
- 標籤 (multi_select), 時間戳記 (created_time)
- 是否最後一輪 (checkbox)

### Knowledge Fragments (知識片段)
- 標題 (title): Fragment title
- 內容 (rich_text): Knowledge content
- 標籤 (multi_select): Fragment tags (same 28 tags as above)
- 來源主問題 (relation → Daily Q&A): Source conversation
- 回合範圍 (rich_text): Source rounds (e.g., "第1-3輪")
- 建立時間 (created_time): Auto-timestamp

### Topic Summary (主題總結)
- 標題 (title): Topic summary title (usually tag name or combination)
- 標籤 (multi_select): Primary tag(s) this summary covers
- 總結內容 (rich_text): Comprehensive summary content synthesizing all related knowledge
- 關聯知識 (relation → Knowledge Fragments): Source knowledge fragments
- 關聯主問題 (relation → Daily Q&A): Related main questions
- 更新時間 (last_edited_time): Auto-timestamp for last update

### Weekly Review (週報)
- 標題 (title), 週期 (date)
- 行動計畫 (rich_text), 小實驗驗證 (rich_text)
- 關聯主問題 (relation → Daily Q&A)
- **Note**: Schema defined but not yet implemented in runtime workflow

## Key Implementation Details

### ES Modules
All scripts use ES module syntax (`import`/`export`). The `package.json` has `"type": "module"` configured.

### Notion API Limitations
- **Rollup properties cannot be created via API** - must be added manually in Notion UI after database creation
- **Relations must be established in two phases**: create databases first, then update with cross-references
- **Title property required**: Every Notion database must have at least one property of type `title`

### Session Management
- Session storage is **in-memory only** - Vercel serverless functions restart frequently
- Maximum 100 conversation rounds per question (user-controlled ending)
- Tracks lastSavedRound for knowledge fragment extraction
- For production, consider Redis or database-backed sessions

### LINE Commands
Commands are in Chinese (accepts variants like 储存/保存 for 儲存, etc.):

**Structured Training Mode (5 commands):**
- `問` - Start new question (daily business thinking training)
- `儲存` - Save current conversation as knowledge fragment
- `小結` - View interim summary (conversation continues)
- `結束` - End current conversation and save
- `狀態` - Check current session status (round number, unsaved rounds)

**Knowledge Search & Analytics (6 commands):**
- `查詢 [標籤]` - Search knowledge by tag (supports single or multiple tags with `+`)
  - Example: `查詢 商業盲點` (single tag search)
  - Example: `查詢 商業盲點+策略盲點` (multiple tags with AND logic)
- `總結 [標籤]` - Generate or update comprehensive topic summary for a single tag
  - Example: `總結 客戶開發`
- `總結 [類別]` - Batch generate summaries for all tags in a category
  - Example: `總結 商業類` (processes all tags in Business category)
  - Supports 5 categories: 技術類, 商業類, 個人成長類, 團隊協作類, 思維模式類
- `總結狀態` - View summary status for all 28 tags
  - Shows last update time, source count, and smart update recommendations
  - Status icons: ✅ (current), 🔄 (needs update), ⚠️ (30+ days), 🆕 (not summarized), ⚪ (no content)
- `週報` - Generate weekly thinking report with blind spot analysis and insights
- `標籤列表` - Show all 28 tags with usage statistics

**System Commands (3 commands):**
- `清除` - Clear chat history (for free conversation mode)
- `系統` - View system information (version, deployment, environment)
- `幫助` - Show help message with all 13 commands

**Free Conversation Mode:**
- Simply type any question to chat directly with Claude AI without structured training
- No specific command needed - system auto-detects when not in structured session

### AI Integration
- Claude model: `claude-sonnet-4-5-20250929` (hardcoded in lib/ai.js)
- AI responses use JSON format with fallback parsing for robustness
- Conversation history passed for contextual follow-ups
- Topic summary generation integrates knowledge fragments and conversation context for comprehensive insights

### Knowledge Search Strategy
Three-layer search approach for `查詢` command:
1. **Topic Summary Layer**: Check if comprehensive topic summary exists
2. **Knowledge Fragments Layer**: Search saved knowledge entries
3. **Conversation Summary Layer**: Fall back to main question summaries
This progressive search ensures users get the most synthesized insights available.

## Business Logic Context

This system implements a coaching workflow defined in `commercial_CLAUDE.md`:
- Daily interaction flow with up to 100 rounds (user-controlled ending)
- Two operational modes: Structured Training and Free Conversation
- Question governance with 28-tag blind spot analysis system
- Knowledge fragment extraction with `儲存` command
- Interim summary with `小結` command (conversation continues)
- Topic-based knowledge search with `查詢` command (three-layer search)
- Topic summary generation with `總結 [標籤]` command
- Batch summary generation with `總結 [類別]` command (processes all tags in a category)
- Summary status dashboard with `總結狀態` command (shows update recommendations)
- Weekly analytics with `週報` command
- Tag usage insights with `標籤列表` command
- Weekly/monthly review cycles (schema ready, runtime pending)

## Important Notes

**Session Management:**
- Session storage is **in-memory only** - Vercel serverless functions restart frequently
- For production: Use Redis or database-backed sessions for reliability
- Auto-cleanup removes sessions inactive for 2+ hours

**Conversation System:**
- Maximum 100 conversation rounds per structured training session (user-controlled ending)
- Two modes: Structured Training (with Notion recording) and Free Conversation (without recording)
- **NEW: Free Conversation now includes RAG (Retrieval Augmented Generation)**
  - Automatically detects relevant topics and retrieves user's past knowledge
  - AI responses reference historical insights, blind spots, and knowledge fragments
  - Smart filtering: only activates on relevant business/technical topics (not casual chat)
  - Enhances continuity and personalization across conversations
- Knowledge fragments can be saved mid-conversation with `儲存` command
- Interim summaries available with `小結` command without ending conversation

**Commands:**
- All LINE commands are in Chinese with variant support
- 15 total commands organized in 3 categories:
  - Structured Training (5): 問, 儲存, 小結, 結束, 狀態
  - Knowledge Search & Analytics (7): 查詢, 總結 [標籤], 總結 [類別], 總結狀態, 週報, 標籤列表, [tag-based searches]
  - System (3): 清除, 系統, 幫助
- Free Conversation: Just type your message (no command needed)

**Technical Details:**
- AI responses use JSON format with fallback parsing for robustness
- Database initialization is a one-time setup (unless recreating schema)
- Test scripts help validate database structure and relations
- 28 blind spot tags organized in 5 categories for comprehensive analysis
- Knowledge search uses three-layer progressive strategy for best insights
- Analytics module provides weekly reports and tag frequency analysis
