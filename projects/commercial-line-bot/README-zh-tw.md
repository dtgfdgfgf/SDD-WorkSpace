# Commercial LINE Bot

LINE Bot x Notion x Claude AI - 商業思考教練系統

這是一個全方位的對話機器人，透過 LINE 每日提供商業思考問題，使用 Claude AI 分析使用者回應，並將所有內容記錄到 Notion 資料庫中。

## 功能特色

- 🤖 LINE Bot 整合，提供每日問答互動
- 🧠 Claude AI (Sonnet 4.5) 提供智慧回饋與追問
- 📊 Notion 資料庫用於持久化儲存與知識管理
- 🔄 多輪對話（最多 3 輪）
- 🏷️ 自動化盲點標籤與分析
- 🛠️ 資料庫初始化與測試工具

## 快速開始

### 1. 安裝

```bash
npm install
```

### 2. 設定環境變數

複製 `.env.example` 為 `.env` 並填入你的憑證：

```bash
cp .env.example .env
```

### 3. 初始化 Notion 資料庫（僅首次使用）

```bash
npm run init:db
```

將返回的資料庫 ID 儲存到你的 `.env` 檔案中。

### 4. 本地開發

```bash
npm run dev
```

### 5. 部署到生產環境

```bash
npm run deploy
```

## 專案結構

```
commercial-line-bot/
├── api/                    # LINE Bot webhook 端點
│   └── webhook.js
├── lib/                    # 核心執行模組
│   ├── sessionManager.js   # 對話狀態管理
│   ├── ai.js              # Claude AI 整合
│   ├── directChat.js      # 自由對話模式
│   ├── notion.js          # Notion API 操作
│   └── constants.js       # 共用常數定義
├── scripts/               # 資料庫設定與測試工具
│   ├── init.js           # 初始化 Notion 資料庫
│   ├── constants.js      # 共用標籤定義
│   ├── test.js           # 簡單測試資料
│   ├── test-all.js       # 完整測試資料
│   └── check-db.js       # Schema 驗證
├── commercial_thinking/   # 商業邏輯文件
├── CLAUDE.md             # AI 開發指南（英文）
├── CLAUDE-zh-tw.md       # AI 開發指南（繁體中文）
├── commercial_CLAUDE.md  # 商業邏輯文件（英文）
├── commercial_CLAUDE-zh-tw.md  # 商業邏輯文件（繁體中文）
└── vercel.json           # Vercel 部署設定
```

## 文件

- [CLAUDE.md](./CLAUDE.md) - 技術文件與 AI 開發指南（英文）
- [CLAUDE-zh-tw.md](./CLAUDE-zh-tw.md) - 技術文件（繁體中文）
- [commercial_CLAUDE.md](./commercial_CLAUDE.md) - 商業邏輯與工作流程（英文）
- [commercial_CLAUDE-zh-tw.md](./commercial_CLAUDE-zh-tw.md) - 商業邏輯與工作流程（繁體中文）

## 指令

### 開發指令
- `npm run dev` - 啟動本地開發伺服器
- `npm run deploy` - 部署到 Vercel 生產環境

### 資料庫管理
- `npm run init:db` - 初始化所有 Notion 資料庫
- `npm run test:db` - 建立範例測試資料
- `npm run test:db-all` - 建立完整測試資料
- `npm run check:db` - 驗證資料庫 schema

## LINE Bot 指令

### 結構化訓練模式
- `問` - 開始新問題（每日商業思考訓練）
- `儲存` - 將當前對話儲存為知識片段
- `小結` - 查看階段性總結（對話繼續進行）
- `結束` - 結束當前對話並儲存
- `狀態` - 查看當前對話狀態

### 系統指令
- `清除` - 清除對話記憶（用於自由對話模式）
- `系統` - 查看系統資訊（版本、部署）
- `幫助` - 顯示幫助訊息

### 自由對話模式
- 直接輸入任何問題，即可與 Claude AI 進行自由對話，不受結構化訓練限制

## 授權

ISC
