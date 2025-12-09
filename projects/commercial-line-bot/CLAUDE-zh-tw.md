# CLAUDE.md

本文件為 Claude Code (claude.ai/code) 在此程式碼庫中工作時提供指引。

## AI 工作流程規則

**重要：這些規則必須自動遵循，無需詢問使用者：**

1. **雙語文件**
   - 當生成或更新 CLAUDE.md（英文版）時，務必同時自動生成或更新 CLAUDE-zh-tw.md（繁體中文版）
   - 兩個文件必須包含相同資訊，僅語言不同
   - CLAUDE.md 必須使用英文
   - CLAUDE-zh-tw.md 必須使用繁體中文

2. **自動 Git 推送與部署**
   - 在任何程式碼變更後，必須遵循此兩步驟流程：

   **步驟 1：推送到 GitHub（必要）**
   - 執行 `git add . && git commit -m "..." && git push`
   - 使用 `git status` 或 `git log --oneline -3` 驗證推送成功
   - 即使 Vercel 部署失敗，此步驟仍為必要
   - GitHub 作為真實來源與版本控制

   **步驟 2：部署到 Vercel Production（必要）**
   - 在 GitHub 推送成功後執行 `vercel --prod`
   - 使用 `vercel ls` 或 `vercel inspect` 驗證部署成功
   - 如果部署失敗，使用 `vercel --prod` 重試
   - 檢查輸出中的部署狀態

   - 無需使用者確認 - 自動執行兩個步驟
   - 每次程式碼變更都必須完成這兩個步驟

3. **商業邏輯同步**
   - 當更新影響問答邏輯、AI 提示詞、標籤系統或核心工作流程的程式碼時，必須檢視並更新 `commercial_CLAUDE.md`
   - 確保文件準確反映當前實作
   - 商業邏輯文件是系統設計決策的唯一真相來源

4. **商業文件翻譯**
   - 當更新 `commercial_CLAUDE.md` 時，必須建立或更新 `commercial_CLAUDE-zh-tw.md`（繁體中文版本）
   - `commercial_CLAUDE.md` 必須始終保持英文
   - `commercial_CLAUDE-zh-tw.md` 必須為完整的繁體中文翻譯

5. **語言要求**
   - `CLAUDE.md` → 僅英文
   - `commercial_CLAUDE.md` → 僅英文
   - `CLAUDE-zh-tw.md` → 繁體中文（完整翻譯版本）
   - `commercial_CLAUDE-zh-tw.md` → 繁體中文（完整翻譯版本）

6. **溝通語言規則**
   - **所有回應、解釋及與使用者的溝通都必須使用繁體中文（zh-tw）**
   - **不得使用簡體中文或英文回應**
   - 技術術語在沒有標準中文翻譯時可保留英文
   - 在程式碼中使用 emoji 時，須謹慎檢查是否可能造成 bug：
     - Emoji 使用 UTF-16 編碼，可能佔用 2 個 code units
     - 字串操作如 `substring()` 或 `.length` 可能對 emoji 造成問題
     - 使用 `[...text]` 或 `Array.from(text)` 進行安全的字串操作
     - 避免在資料庫鍵值或關鍵識別碼中儲存 emoji

7. **文檔同步**
   - 當進行任何程式碼變更時，必須檢視並更新 `CLAUDE.md`（如有需要）
   - 需要更新文檔的關鍵領域：
     - 架構變更（新模組、修改的流程）
     - 新功能或指令
     - 資料庫 schema 修改
     - API 整合或外部服務變更
     - 配置或環境變數變更
     - 對話流程或商業邏輯的變更
   - 如果更新了 `CLAUDE.md`，也必須相應更新 `CLAUDE-zh-tw.md`
   - 保持文檔與實際實作同步，以防止資訊過時
   - 文檔應始終反映程式碼庫的當前狀態

8. **詳細的 Commit 訊息**
   - 每個檔案的變更都必須在 commit 訊息中明確說明
   - 使用結構化的 commit 訊息格式：
     ```
     <類型>(<範圍>): <主題>

     <內容>
     - 檔案1：變更內容及原因
     - 檔案2：變更內容及原因
     - 檔案3：變更內容及原因

     <註腳>
     ```

   **Commit 訊息要求：**
   - **類型**：feat、fix、docs、refactor、chore、test、style 等
   - **範圍**：受影響的模組或元件（例如：ai、notion、webhook、docs）
   - **主題**：簡短摘要（50 字元以內）
   - **內容**：每個變更檔案的詳細說明
     - 每個檔案變更了什麼
     - 為什麼需要這個變更
     - 變更的影響
   - **註腳**：共同作者、參考資料、重大變更

   **範例：**
   ```
   refactor(ai): 將每回合標籤數量從 2-4 個增加到 3-6 個

   - lib/ai.js: 更新 analyzeAnswer() 提示詞以要求 3-6 個標籤
     - 變更標籤選擇策略使其更全面
     - 新增要求 1-2 個主題 + 1-2 個思維 + 0-2 個成長標籤
   - CLAUDE.md: 記錄新的標籤生成策略
     - 在 lib/ai.js 區段新增標籤數量細節
   - CLAUDE-zh-tw.md: 同步中文版本與英文版本的變更

   🤖 Generated with [Claude Code](https://claude.com/claude-code)
   Co-Authored-By: Claude <noreply@anthropic.com>
   ```

   **優點：**
   - 清楚追蹤每個檔案的變更
   - 更容易進行程式碼審查和歷史導航
   - 更好地理解為什麼進行變更
   - 改善協作和知識轉移

## 程式碼審查原則

**目的**：這些原則幫助 AI 針對本專案的特定風險進行有效的程式碼審查。

### 核心審查規則（必要項目）

在審查程式碼變更時，優先檢查以下項目：

1. **外部 API 錯誤處理**
   - 所有對 LINE、Notion 和 Claude API 的呼叫都必須有適當的錯誤處理
   - 在適當的地方包含逾時處理和重試邏輯
   - 記錄錯誤時要有足夠的上下文以便除錯
   - 優雅地處理 API 失敗，不讓機器人崩潰

2. **Serverless 狀態管理**
   - 記住 session 只儲存在**記憶體中**（重啟時會清除）
   - 永遠不要假設 session 資料會在函式呼叫之間持續存在
   - 為任何依賴 session 狀態的程式碼撰寫文件
   - 考慮 session 在對話中途遺失時的邊界情況

3. **自動部署影響**
   - 每次 commit 都會觸發自動正式環境部署
   - commit 前要徹底測試 - 沒有預備環境閘道
   - 考慮與進行中使用者對話的向後相容性
   - 避免對 Notion schema 或 API 契約進行破壞性變更

4. **Notion Schema 對齊**
   - 驗證程式碼符合實際的 Notion 資料庫 schema
   - 檢查屬性名稱（問題、狀態、總結等）完全符合
   - 測試關聯欄位（來源題目、所屬問題）是否正確連結
   - 如果資料庫結構變更，更新 schema 文件

5. **Claude API 成本控制**
   - 注意提示詞和回應中的 token 使用量
   - 避免不必要的 API 呼叫（例如在迴圈或錯誤重試中）
   - 驗證對話歷史不會無限增長
   - 考慮新功能的成本影響

6. **語言一致性**
   - 面向使用者的訊息必須使用繁體中文
   - 程式碼註解和內部日誌可以使用英文
   - 顯示給使用者的錯誤訊息必須有幫助且使用中文
   - 維持一致的術語（問、結束、狀態、幫助）

7. **文件同步**
   - 當工作流程變更時更新 `CLAUDE.md` + `CLAUDE-zh-tw.md`
   - 當商業邏輯變更時更新 `commercial_CLAUDE.md` + `commercial_CLAUDE-zh-tw.md`
   - 保持文件與實際實作同步
   - 記錄破壞性變更或新的環境變數

### 審查嚴重程度層級

使用這些標籤來排定問題優先順序：

- 🚨 **BLOCKING（阻塞）** - 必須立即修復的關鍵問題
  - 安全漏洞、資料遺失風險、破壞正式環境功能

- ⚠️ **MUST-FIX（必須修復）** - 合併前應該修復的重要問題
  - Bug、錯誤處理不足、維護性問題、缺少文件

- 💡 **SUGGESTION（建議）** - 值得改進的項目
  - 程式碼風格、小型優化、最佳實踐建議

### 何時進行審查

- 在 commit 任何程式碼變更之前（因為自動部署已啟用）
- 當外部相依套件更新時
- 當商業邏輯或對話流程變更時
- 當 Notion schema 被修改時

### 擴展指南

對於超出本專案特定需求的全面審查標準，請參考一般軟體工程最佳實踐。這 7 條核心規則代表了 80/20 法則 - 請先聚焦於此。

## 專案概述

**LINE Bot x Notion x Claude AI - 商業思維教練系統**

一個綜合性的對話機器人，透過 LINE 傳送每日商業思維問題，使用 Claude AI 分析使用者回應，並將所有內容記錄到 Notion 資料庫。系統包含生產運行時（LINE Bot + AI + Notion 整合）和資料庫初始化與測試的開發工具。

### 系統元件

1. **生產運行時** (`api/`, `lib/`)
   - LINE webhook 處理器用於接收使用者訊息
   - Session 管理用於多輪對話
   - Claude AI 整合用於智能回饋
   - Notion API 整合用於資料持久化

2. **資料庫設置工具** (`scripts/`)
   - 資料庫初始化腳本
   - 測試資料生成
   - Schema 驗證工具

## 開發指令

### 設定
```bash
npm install
```

### 本地開發
```bash
npm run dev          # 啟動 Vercel 開發伺服器
vercel dev           # 替代指令
```

### 正式環境部署
```bash
npm run deploy       # 部署到 Vercel 正式環境
vercel --prod        # 替代指令
```

### 資料庫管理
```bash
npm run init:db      # 初始化所有 4 個 Notion 資料庫
npm run test:db      # 建立範例測試資料
npm run test:db-all  # 建立完整測試資料
npm run check:db     # 檢查資料庫架構
```

直接執行腳本：
```bash
node scripts/init.js       # 初始化資料庫
node scripts/test.js       # 簡單測試
node scripts/test-all.js   # 完整測試
node scripts/check-db.js   # Schema 驗證
```

目前未配置測試套件。

## 架構

### 生產運行時流程

```
LINE 使用者訊息
  → LINE Webhook (/api/webhook.js)
  → Session Manager (lib/sessionManager.js) - 檢查對話狀態
  → 指令處理器 或 回答處理器
  → AI 分析 (lib/ai.js) - Claude Sonnet 4.5
  → Notion 記錄 (lib/notion.js)
  → LINE 回覆
```

### 核心元件

**api/webhook.js** - 主要進入點
- 處理 LINE webhook POST 請求
- 路由 15 個指令：
  - 結構化訓練：`問`（開始）、`儲存`（儲存）、`小結`（小結）、`結束`（結束）、`狀態`（狀態）
  - 知識檢索：`查詢`（按標籤搜尋）、`總結`（生成主題總結）
  - 分析功能：`週報`（週報）、`標籤列表`（標籤統計）、`總結狀態`（總結狀態）、`總結 [類別]`（按類別批次總結）
  - 系統：`清除`（清除）、`系統`（系統資訊）、`幫助`（幫助）
  - 自由對話：未啟動結構化 session 時的任何文字
- 管理兩種運作模式：
  1. **結構化訓練**：多輪問答與 AI 回饋（最多 100 輪，使用者控制結束）
  2. **自由對話**：與 Claude AI 直接聊天，無結構化工作流程
- 指令處理器：
  - `handleSearchKnowledge()`：三層知識搜尋（主題總結 > 知識片段 > 對話總結）
  - `handleWeeklyReport()`：生成帶有標籤分析的每週思維報告
  - `handleTagList()`：顯示所有 28 個標籤及使用統計
  - `handleGenerateTopicSummary()`：生成或更新單一標籤的全面主題總結
  - `handleBatchSummaryByCategory()`：批次生成某類別所有標籤的總結（例如：技術類、商業類）
  - `handleSummaryStatus()`：查看所有 28 個標籤的總結狀態及智能更新建議
  - `handleHelp()`：更新以包含所有 15 個指令
- 協調 session、AI、Notion 和分析模組

**lib/sessionManager.js** - 記憶體內對話狀態（用於結構化訓練）
- 使用 Map() 儲存使用者 session（serverless 重啟時清除）
- 追蹤：問題、回合數（1-100）、對話歷史、lastSavedRound
- Session 結構包含所有問答回合的完整上下文
- **重要**：正式環境應使用 Redis/資料庫
- 自動清理：移除 2 小時以上未活動的 session

**lib/directChat.js** - 自由對話模式
- 在結構化訓練之外，啟用與 Claude AI 的非結構化對話
- 每位使用者獨立的對話歷史
- 無回合限制或 Notion 記錄
- 當使用者在沒有活動結構化 session 時傳送訊息時使用

**lib/ai.js** - Claude AI 整合
- 使用 `claude-sonnet-4-5-20250929` 模型
- `analyzeAnswer()`：根據對話深度提供回饋 + 追問
  - 每回合生成 3-6 個標籤以進行全面分類
  - 標籤策略：1-2 個主題標籤 + 1-2 個思維標籤 + 0-2 個成長/協作標籤
- `generateSummary()`：生成對話總結與盲點標籤
- `generateKnowledgeFragment()`：從對話回合中提取可重用的知識
- `generateTopicSummary()`：整合多個知識來源（知識片段、主問題、對話回合）以生成深度主題總結
  - 支援三層知識架構：主題總結 > 知識片段 > 對話總結
  - 具有品質評估的智能內容整合
  - 支援主題演化與關聯標籤追蹤
- 總是期望 Claude 返回 JSON 格式，並有備援解析機制

**lib/notion.js** - Notion 資料庫操作
- 5 個資料庫：題庫（Question Bank）、主問題（Daily Q&A）、回合（Conversation Rounds）、知識片段（Knowledge Fragments）、主題總結（Topic Summary）
- 問題生命週期：取得隨機未使用問題 → 建立主 Q&A → 標記為已使用
- 記錄每一輪的使用者回答、AI 回饋、AI 追問、標籤
- 完成時更新主 Q&A 的總結與盲點標籤
- 建立知識片段以提取和儲存可重用的洞察
- 主要函式：
  - `getRandomQuestion()`, `markQuestionAsUsed()`：問題管理
  - `createMainQuestion()`, `completeMainQuestion()`, `updateMainQuestionSummary()`：主 Q&A 生命週期
  - `createConversationRound()`：回合記錄
  - `createKnowledgeFragment()`, `getKnowledgeFragments()`：知識管理
  - **新增的知識檢索函式（14 個）**：
    - 知識片段搜尋（3）：`searchKnowledgeByTag()`, `searchKnowledgeByMultipleTags()`, `getAllKnowledgeFragments()`
    - 回合搜尋（3）：`searchRoundsByTag()`, `searchRoundsByMultipleTags()`, `formatRoundContent()`
    - 主問題搜尋（2）：`searchMainQuestionsByTag()`, `searchMainQuestionsByMultipleTags()`
    - 主題總結（4）：`createTopicSummary()`, `updateTopicSummary()`, `getTopicSummaryByTag()`, `getAllContentByTag()`
  - `getAllContentByTag()`：智能降級邏輯 - 當精煉內容 < 5 時回退到對話回合

**lib/analytics.js** - 數據分析與週報生成模組（新增）
- `generateWeeklyReport()`：生成每週思維訓練報告
  - 自動計算本週範圍（週一至今天）
  - 統計對話次數、知識片段、盲點標籤
  - 盲點頻率分析（高/中/低頻）
  - 提供個人化改善建議
- `getAllTagsFrequency()`：統計所有標籤的使用頻率（全歷史）
- `getMainQuestionsByDateRange()`：取得指定日期範圍內的主問題
- `getKnowledgeFragmentsByDateRange()`：取得指定日期範圍內的知識片段

**scripts/init.js** - 資料庫初始化
- 建立所有 4 個 Notion 資料庫及適當的 schema
- 建立資料庫間的雙向關聯
- 兩階段建立：先建立資料庫，再建立關聯

**lib/constants.js** - 共享常數和標籤定義
- 28 個盲點標籤，組織成 5 個類別：
  - 技術面（Technical Domain）：技術盲點、產品設計盲點、數據分析盲點
  - 商業面（Business Domain）：商業盲點、財務盲點、策略盲點
  - 思維面（Thinking Patterns）：思維盲點、問題定義、解決方案思考
  - 協作面（Collaboration）：協作盲點、領導力、利害關係人管理
  - 個人成長面（Personal Growth）：個人成長盲點、學習方法、職涯發展
  - 另外 14 個專業標籤：Risk Management、User Empathy、Market Validation 等
- `getTagsByCategory()`：返回格式化的標籤清單供 AI 提示詞使用
- 在運行時（lib/）和設置腳本（scripts/）中使用

**scripts/constants.js** - 設置腳本常數
- 將標籤定義轉換為 Notion 格式以進行資料庫初始化
- 提供問題類型選項
- 匯出供初始化和測試腳本使用

### 對話流程

**結構化訓練模式：**
1. 使用者傳送 `問` 指令
2. 機器人從 Notion 題庫取得隨機問題（狀態：未使用）
3. 建立 session + 在 Notion 建立主問題記錄
4. 使用者回答 → AI 分析 → 記錄回合到 Notion
5. 持續最多 100 輪（使用者決定何時結束）
6. 對話期間：
   - `小結` - 生成中期總結而不結束（更新 Notion，對話繼續）
   - `儲存` - 將對話片段儲存為知識（追蹤 lastSavedRound）
   - `狀態` - 檢查當前狀態（回合數、未儲存回合）
7. 當使用者傳送 `結束` 或 AI 決定對話完成時：
   - 生成最終總結與盲點標籤
   - 更新 Notion 主問題為已完成
   - 清除 session

**自由對話模式：**
- 使用者在沒有活動結構化 session 時傳送任何文字
- 透過 lib/directChat.js 與 Claude AI 直接聊天
- 無 Notion 記錄、無回合限制
- `清除` 指令清除對話歷史

**知識檢索與分析模式：**
- `查詢 [標籤]`：搜尋相關知識（三層架構：主題總結 > 知識片段 > 對話總結）
  - 支援多標籤搜尋（使用空格分隔，AND 邏輯）
  - 智能降級：當精煉內容不足時自動回退到原始對話回合
- `總結 [標籤]`：為特定標籤生成或更新深度主題總結
  - 整合所有相關知識片段、主問題、對話回合
  - AI 驅動的主題綜合分析
- `總結 [類別]`：批次生成某類別所有標籤的總結（例如：技術類、商業類）
  - 智能過濾：自動跳過無內容的標籤以節省 token
  - 即時進度追蹤及最終統計報告
- `總結狀態`：查看所有 28 個標籤的總結狀態儀表板
  - 顯示最後更新時間及來源數量
  - 智能更新建議（有新內容 + 7 天以上）
- `週報`：生成本週思維訓練報告（盲點分析、改善建議）
- `標籤列表`：顯示所有 28 個標籤及使用頻率統計

### 資料庫架構

系統由 5 個具有雙向關聯的互連 Notion 資料庫組成：

1. **主問題（Daily Q&A）** - 追蹤每日問題的中心樞紐
2. **回合（Conversation Rounds）** - 與主問題連結的多輪問答互動
3. **題庫（Question Bank）** - 具有使用追蹤的精選問題儲存庫
4. **知識片段（Knowledge Fragments）** - 從對話中提取的可重用洞察
5. **主題總結（Topic Summary）** - 按標籤組織的深度主題綜合（新增）
6. **週報（Weekly Review）** - 彙整的洞察與行動計畫（可選，運行時尚未實作）

#### 資料庫關聯

- 主問題 → 回合（透過「回合紀錄」的一對多關聯）
- 主問題 → 題庫（透過「來源題目」）
- 主問題 → 知識片段（透過「關聯知識」的一對多關聯）
- 主問題 → 週報（透過「週報關聯」）
- 主題總結 → 知識片段（透過「相關知識片段」的多對多關聯）
- 所有關聯都是程式化建立，除了 Rollup 欄位（必須在 Notion UI 中手動新增）

#### 兩階段資料庫建立

由於 Notion API 對循環關聯的限制，資料庫分兩個階段建立：

1. **階段 1**：建立所有資料庫及其基本屬性
2. **階段 2**：更新資料庫以新增交叉引用和關聯

這種兩階段方法是必要的，因為你無法引用尚不存在的資料庫。

## 環境變數

在 `.env` 中必填（參考 `.env.example`）：

**生產運行時：**
- `LINE_CHANNEL_ACCESS_TOKEN` / `LINE_CHANNEL_SECRET`
- `ANTHROPIC_API_KEY`
- `NOTION_TOKEN`
- `NOTION_MAIN_DB_ID` - Daily Q&A 資料庫 ID
- `NOTION_ROUNDS_DB_ID` - Conversation Rounds 資料庫 ID
- `NOTION_QUESTION_BANK_DB_ID` - Question Bank 資料庫 ID
- `NOTION_KNOWLEDGE_DB_ID` - Knowledge Fragments 資料庫 ID（選用，用於知識管理功能）
- `NOTION_TOPIC_SUMMARY_DB_ID` - Topic Summary 資料庫 ID（選用，用於主題總結功能）

**資料庫初始化（scripts/）：**
- `NOTION_TOKEN` - Notion 整合 token
- `PARENT_PAGE_ID` - 將建立資料庫的父頁面（用於 init.js）
- `MAIN_DB_ID` - （用於測試腳本）同 NOTION_MAIN_DB_ID
- `ROUNDS_DB_ID` - （用於測試腳本）同 NOTION_ROUNDS_DB_ID
- `QUESTION_BANK_DB_ID` - （用於測試腳本）同 NOTION_QUESTION_BANK_DB_ID
- `WEEKLY_DB_ID` - （用於測試腳本）Weekly Review 資料庫 ID

**注意**：.env.example 包含實際憑證 - 如果洩露請務必更換。

## Notion 資料庫架構

### 題庫（Question Bank）
- 問題（title）、類型（select）、建議回答方向（rich_text）
- 狀態（select）：未使用/已使用/重複
- 使用日期（date）
- 關聯主問題（relation → Daily Q&A）

### 主問題（Daily Q&A）
- 問題（title）、日期（date）、問題類型（select）
- 狀態（select）：進行中/已完成
- 總結（rich_text）、盲點標籤（multi_select - 28 個標籤）
- 來源題目（relation → Question Bank）
- 回合紀錄（relation → Conversation Rounds）
- 關聯知識（relation → Knowledge Fragments）
- 週報關聯（relation → Weekly Review）

**盲點標籤（28 個 multi_select 選項，組織成 5 個類別）：**
- **技術面**：技術盲點、產品設計盲點、數據分析盲點
- **商業面**：商業盲點、財務盲點、策略盲點
- **思維面**：思維盲點、問題定義、解決方案思考
- **協作面**：協作盲點、領導力、利害關係人管理
- **個人成長面**：個人成長盲點、學習方法、職涯發展
- **另外 14 個專業標籤**：Risk Management、User Empathy、Market Validation、Resource Allocation、Team Culture、Communication Effectiveness、Process Optimization、Goal Setting、Time Management、Decision Framework、Feedback Loop、Competitive Analysis、Customer Journey、Value Proposition

### 回合（Conversation Rounds）
- 標題（title）、回合編號（number）
- 所屬問題（relation → Daily Q&A）
- 使用者回答、AI 回饋、AI 追問（all rich_text）
- 標籤（multi_select）、時間戳記（created_time）
- 是否最後一輪（checkbox）

### 知識片段（Knowledge Fragments）
- 標題（title）：片段標題
- 內容（rich_text）：知識內容
- 標籤（multi_select）：片段標籤（與上述 28 個標籤相同）
- 來源主問題（relation → Daily Q&A）：來源對話
- 回合範圍（rich_text）：來源回合（例如：「第1-3輪」）
- 建立時間（created_time）：自動時間戳記

### 主題總結（Topic Summary）（新增）
- 標題（title）：主題標籤名稱
- 總結內容（rich_text）：綜合主題洞察
- 核心洞察（rich_text）：關鍵要點
- 實踐建議（rich_text）：可行動的建議
- 關聯標籤（multi_select）：相關標籤
- 知識片段數量（number）：引用的片段數量
- 更新時間（last_edited_time）：最後更新時間戳記
- 相關知識片段（relation → Knowledge Fragments）：來源片段連結

### 週報（Weekly Review）
- 標題（title）、週期（date）
- 行動計畫（rich_text）、小實驗驗證（rich_text）
- 關聯主問題（relation → Daily Q&A）
- **注意**：已定義架構但運行時工作流程尚未實作

## 重要實作細節

### ES 模組
所有腳本使用 ES 模組語法（`import`/`export`）。`package.json` 已設定 `"type": "module"`。

### Notion API 限制
- **Rollup 屬性無法透過 API 建立** - 必須在資料庫建立後於 Notion UI 中手動新增
- **關聯必須分兩階段建立**：先建立資料庫，然後更新交叉引用
- **必須有標題屬性**：每個 Notion 資料庫必須至少有一個 `title` 類型的屬性

### Session 管理
- Session 儲存**僅在記憶體中** - Vercel serverless 函式會頻繁重啟
- 每個問題最多 100 輪對話（使用者控制結束）
- 追蹤 lastSavedRound 以進行知識片段提取
- 正式環境建議使用 Redis 或資料庫支援的 session

### LINE 指令
指令為中文（接受變體，如 储存/保存 代表 儲存 等）：

**結構化訓練模式（5 個指令）：**
- `問` - 開始新問題（每日商業思維訓練）
- `儲存` - 將當前對話儲存為知識片段
- `小結` - 查看中期總結（對話繼續）
- `結束` - 結束當前對話並儲存
- `狀態` - 檢查當前 session 狀態（回合數、未儲存回合）

**知識檢索與分析（6 個指令）：**
- `查詢 [標籤]` - 按標籤搜尋知識（支援單標籤或多標籤 `+` 組合）
  - 範例：`查詢 商業盲點`（單標籤搜尋）
  - 範例：`查詢 商業盲點+策略盲點`（多標籤 AND 邏輯）
- `總結 [標籤]` - 生成或更新單一標籤的深度主題總結
  - 範例：`總結 客戶開發`
- `總結 [類別]` - 批次生成某類別所有標籤的總結
  - 範例：`總結 商業類`（處理商業類別的所有標籤）
  - 支援 5 個類別：技術類、商業類、個人成長類、團隊協作類、思維模式類
- `總結狀態` - 查看所有 28 個標籤的總結狀態
  - 顯示最後更新時間、來源數量及智能更新建議
  - 狀態圖示：✅（最新）、🔄（需要更新）、⚠️（30 天以上）、🆕（未總結）、⚪（無內容）
- `週報` - 生成本週思維訓練報告（盲點分析與洞察）
- `標籤列表` - 列出所有 28 個標籤及使用統計

**系統指令（3 個指令）：**
- `清除` - 清除聊天歷史（用於自由對話模式）
- `系統` - 查看系統資訊（版本、部署、環境）
- `幫助` - 顯示所有指令的說明訊息

**自由對話模式（1 個用法）：**
- 只需輸入任何問題即可與 Claude AI 直接聊天，無需結構化訓練
- 無需特定指令 - 系統會自動偵測何時不在結構化 session 中

**總共：15 個指令/用法**

### 三層知識架構
系統實作了三層知識檢索架構：

1. **主題總結（最高層）**：
   - AI 生成的跨多次對話的綜合洞察
   - 按標籤組織，包含核心洞察與實踐建議
   - 最精煉和可行動的知識形式

2. **知識片段（中層）**：
   - 使用者使用 `儲存` 指令提取的精選洞察
   - 從特定對話回合中提取的可重用學習
   - 手動策劃並附有上下文

3. **對話總結（基礎層）**：
   - 完成對話的 AI 生成摘要
   - 包含完整的上下文和思維過程
   - 當高層內容不足時作為備用

**智能降級**：當搜尋標籤時，如果精煉內容（主題總結 + 知識片段）少於 5 個，系統會自動包含原始對話回合以確保完整性。

### AI 整合
- Claude 模型：`claude-sonnet-4-5-20250929`（在 lib/ai.js 中硬編碼）
- AI 回應使用 JSON 格式，具備備援解析以提高穩健性
- 傳遞對話歷史以提供有上下文的追問
- 主題總結功能整合多個知識來源以生成綜合洞察

## 商業邏輯背景

此系統實作了在 `commercial_CLAUDE.md` 中定義的教練工作流程：
- 每日互動流程，最多 100 輪（使用者控制結束）
- 三種運作模式：結構化訓練、自由對話、知識檢索
- 具有 28 標籤盲點分析系統的問題管理
- 使用 `儲存` 指令進行知識片段提取
- 使用 `小結` 指令生成中期總結（對話繼續）
- 使用 `查詢` 指令進行基於主題的知識搜尋（三層搜尋）
- 使用 `總結 [標籤]` 指令生成主題總結
- 使用 `總結 [類別]` 指令批次總結（處理類別中的所有標籤）
- 使用 `總結狀態` 指令查看總結狀態儀表板（顯示更新建議）
- 使用 `週報` 指令進行週報分析
- 使用 `標籤列表` 指令查看標籤使用洞察
- 每週/每月回顧週期（架構就緒，運行時待實作）

## 重要提醒

**Session 管理：**
- Session 儲存**僅在記憶體中** - Vercel serverless 函式會頻繁重啟
- 正式環境：使用 Redis 或資料庫支援的 session 以提高可靠性
- 自動清理會移除 2 小時以上未活動的 session

**對話系統：**
- 每個結構化訓練 session 最多 100 輪對話（使用者控制結束）
- 三種模式：結構化訓練（有 Notion 記錄）、自由對話（無記錄）、知識檢索（搜尋與分析）
- 可使用 `儲存` 指令在對話中途儲存知識片段
- 可使用 `小結` 指令取得中期總結而不結束對話
- 三層知識架構確保知識積累與檢索的最佳效果

**指令：**
- 所有 LINE 指令均為中文，支援變體
- 結構化訓練（5）：問、儲存、小結、結束、狀態
- 知識檢索與分析（7）：查詢、總結 [標籤]、總結 [類別]、總結狀態、週報、標籤列表、[基於標籤的搜尋]
- 系統（3）：清除、系統、幫助
- 自由對話：只需輸入您的訊息（無需指令）
- 總共 15 個指令/用法

**技術細節：**
- AI 回應使用 JSON 格式，具備備援解析以提高穩健性
- 資料庫初始化是一次性設置（除非重新建立 schema）
- 測試腳本有助於驗證資料庫結構和關聯
- 28 個盲點標籤組織成 5 個類別以進行全面分析
- 智能降級確保即使在早期階段也能提供有用的知識檢索結果
