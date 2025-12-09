# Commercial LINE Bot

LINE Bot x Notion x Claude AI - Business Thinking Coach System

A comprehensive conversational bot that delivers daily business thinking questions via LINE, analyzes user responses with Claude AI, and records everything to Notion databases.

## Features

- 🤖 LINE Bot integration for daily Q&A interactions
- 🧠 Claude AI (Sonnet 4.5) for intelligent feedback and follow-ups
- 📊 Notion database for persistent storage and knowledge management
- 🔄 Multi-turn conversations (up to 3 rounds)
- 🏷️ Automated blind spot tagging and analysis
- 🛠️ Database initialization and testing tools

## Quick Start

### 1. Setup

```bash
npm install
```

### 2. Configure Environment

Copy `.env.example` to `.env` and fill in your credentials:

```bash
cp .env.example .env
```

### 3. Initialize Notion Databases (First Time Only)

```bash
npm run init:db
```

Save the returned database IDs to your `.env` file.

### 4. Local Development

```bash
npm run dev
```

### 5. Deploy to Production

```bash
npm run deploy
```

## Project Structure

```
commercial-line-bot/
├── api/                    # LINE Bot webhook endpoints
│   └── webhook.js
├── lib/                    # Core runtime modules
│   ├── sessionManager.js   # Conversation state management
│   ├── ai.js              # Claude AI integration
│   └── notion.js          # Notion API operations
├── scripts/               # Database setup and testing tools
│   ├── init.js           # Initialize Notion databases
│   ├── constants.js      # Shared tag definitions
│   ├── test.js           # Simple test data
│   ├── test-all.js       # Comprehensive test data
│   └── check-db.js       # Schema validation
├── commercial_thinking/   # Business logic documents
├── CLAUDE.md             # AI development guidelines
├── commercial_CLAUDE.md  # Business logic documentation
└── vercel.json           # Vercel deployment config
```

## Documentation

- [CLAUDE.md](./CLAUDE.md) - Technical documentation and AI guidelines (English)
- [CLAUDE-zh-tw.md](./CLAUDE-zh-tw.md) - Technical documentation (Traditional Chinese)
- [commercial_CLAUDE.md](./commercial_CLAUDE.md) - Business logic and workflow (English)
- [commercial_CLAUDE-zh-tw.md](./commercial_CLAUDE-zh-tw.md) - Business logic and workflow (Traditional Chinese)

## Commands

### Development
- `npm run dev` - Start local development server
- `npm run deploy` - Deploy to Vercel production

### Database Management
- `npm run init:db` - Initialize all Notion databases
- `npm run test:db` - Create sample test data
- `npm run test:db-all` - Create comprehensive test data
- `npm run check:db` - Verify database schema

## LINE Bot Commands

### Structured Training Mode
- `問` - Start a new question (daily business thinking training)
- `儲存` - Save current conversation as knowledge fragment
- `小結` - View interim summary (conversation continues)
- `結束` - End current conversation and save
- `狀態` - Check current session status

### System Commands
- `清除` - Clear chat history (for free conversation mode)
- `系統` - View system information (version, deployment)
- `幫助` - Show help message

### Free Conversation Mode
- Simply type any question to chat directly with Claude AI without structured training

## License

ISC
