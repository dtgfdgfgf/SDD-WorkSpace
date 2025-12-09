# Notion 環境變數自動同步工具

## 📋 功能說明

`scripts/sync-env.js` 是一個自動化工具，可以：

1. 🔍 **自動掃描** Notion workspace 中的所有資料庫
2. 🎯 **智能映射** 資料庫名稱到環境變數名稱
3. 📝 **自動更新** .env 文件（並生成備份）
4. ✅ **驗證配置** 測試所有資料庫連接
5. 🚀 **同步 Vercel** 批量上傳環境變數到 Vercel（可選）

---

## 🚀 使用方式

### 基礎用法（推薦）

```bash
node scripts/sync-env.js
```

**功能**：
- 掃描 Notion 資料庫
- 自動更新 .env
- 生成 .env.backup 備份
- 驗證所有資料庫連接

**輸出示例**：
```
╔══════════════════════════════════════╗
║   Notion 環境變數自動同步工具       ║
╚══════════════════════════════════════╝

🔍 正在掃描 Notion workspace...

找到 6 個資料庫：

✅ Daily Q&A 主問題 → NOTION_MAIN_DB_ID
✅ Conversation Rounds 回合 → NOTION_ROUNDS_DB_ID
✅ Question Bank 題庫 → NOTION_QUESTION_BANK_DB_ID
✅ Weekly Review 週報 → WEEKLY_DB_ID
✅ Knowledge Fragments 知識片段 → NOTION_KNOWLEDGE_DB_ID
✅ Topic Summaries 主題總結 → NOTION_TOPIC_SUMMARY_DB_ID

📝 正在更新 .env...

✅ 備份已創建：.env.backup
✅ .env 已更新

📊 變更摘要：
   NOTION_TOPIC_SUMMARY_DB_ID
   資料庫：Topic Summaries 主題總結
   舊值：（未設置）
   新值：2a75ef9980b98146a112fff1bdf3e708

🔍 正在驗證配置...

✅ Daily Q&A 主問題
   環境變數：NOTION_MAIN_DB_ID
   狀態：連接正常

✅ 所有資料庫配置正確

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🎉 環境變數同步完成！

📝 下一步：
1. 檢查 .env 文件是否正確
2. 運行 vercel env add 同步到 Vercel（可選）
3. 重新部署：vercel --prod
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

### 同步到 Vercel

```bash
node scripts/sync-env.js --vercel
```

**功能**：
- 執行基礎用法的所有功能
- 批量上傳環境變數到 Vercel
- 支援選擇環境（Production only 或 All environments）

**交互提示**：
```
🚀 正在同步到 Vercel...

請選擇環境 (1: Production, 2: All): 1

   上傳 NOTION_MAIN_DB_ID 到 production...
   上傳 NOTION_ROUNDS_DB_ID 到 production...
   ...

✅ Vercel 同步完成
⚠️  請記得重新部署：vercel --prod
```

---

### Dry Run 模式（預覽）

```bash
node scripts/sync-env.js --dry-run
```

**功能**：
- 只掃描資料庫
- 顯示會進行的變更
- **不會**修改 .env 文件
- 適合用於預覽效果

---

### 健康檢查模式

```bash
node scripts/sync-env.js --check
```

**功能**：
- 掃描所有資料庫
- 驗證每個資料庫的連接狀態
- 檢測授權問題
- **不會**修改 .env 文件

**輸出示例**：
```
🔍 正在驗證配置...

✅ Daily Q&A 主問題
   環境變數：NOTION_MAIN_DB_ID
   狀態：連接正常

❌ Topic Summaries 主題總結
   環境變數：NOTION_TOPIC_SUMMARY_DB_ID
   狀態：Notion Integration 未授權

⚠️  發現錯誤，請檢查 Notion Integration 授權
```

---

## 🎯 資料庫名稱映射規則

| Notion 資料庫名稱 | 環境變數名稱 |
|-----------------|-------------|
| Daily Q&A / 主問題 | NOTION_MAIN_DB_ID |
| Conversation Rounds / 回合 | NOTION_ROUNDS_DB_ID |
| Question Bank / 題庫 | NOTION_QUESTION_BANK_DB_ID |
| Weekly Review / 週報 | WEEKLY_DB_ID |
| Knowledge Fragments / 知識片段 | NOTION_KNOWLEDGE_DB_ID |
| Topic Summaries / 主題總結 | NOTION_TOPIC_SUMMARY_DB_ID |

**智能匹配**：
- 支援完全匹配（例如：「Daily Q&A」）
- 支援部分匹配（例如：「Daily Q&A 主問題」也會匹配）
- 支援中英文名稱（例如：「主問題」和「Daily Q&A」都有效）

---

## 📝 .env 文件格式

腳本會**保留**你的 .env 文件格式：
- ✅ 保留所有註釋
- ✅ 保留空行
- ✅ 保留其他環境變數（LINE、Claude API）
- ✅ 只更新 Notion 相關的環境變數

**範例**：

原始 .env：
```bash
# LINE Bot 設定
LINE_CHANNEL_ACCESS_TOKEN=your_token

# Notion 設定
NOTION_TOKEN=your_notion_token
NOTION_MAIN_DB_ID=old_value

# Claude AI 設定
ANTHROPIC_API_KEY=your_key
```

執行後：
```bash
# LINE Bot 設定
LINE_CHANNEL_ACCESS_TOKEN=your_token

# Notion 設定
NOTION_TOKEN=your_notion_token
NOTION_MAIN_DB_ID=new_value
NOTION_ROUNDS_DB_ID=auto_added_value
NOTION_KNOWLEDGE_DB_ID=auto_added_value
NOTION_TOPIC_SUMMARY_DB_ID=auto_added_value

# Claude AI 設定
ANTHROPIC_API_KEY=your_key
```

---

## 🔧 疑難排解

### 問題 1：找不到資料庫

**錯誤訊息**：
```
⚠️  未找到任何資料庫
```

**可能原因**：
1. `PARENT_PAGE_ID` 設置錯誤
2. Notion Integration 未授權 parent page
3. 資料庫不在 parent page 的直接子層

**解決方法**：
1. 確認 PARENT_PAGE_ID 是否正確（從 Notion URL 複製）
2. 在 Notion 中，確保 parent page 已授權你的 Integration
3. 確保資料庫是 parent page 的直接子項目（不是嵌套在其他頁面中）

---

### 問題 2：資料庫無法映射

**輸出**：
```
⚠️  My Custom Database → 未映射
```

**原因**：資料庫名稱不在預設的映射規則中

**解決方法**：

**選項 A**：重新命名 Notion 資料庫
- 在 Notion 中將資料庫改名為預設名稱（例如：「主題總結」）
- 重新運行腳本

**選項 B**：手動添加映射規則
編輯 `scripts/sync-env.js`，在 `DB_MAPPING` 中添加：
```javascript
const DB_MAPPING = {
  // ... 現有映射
  'My Custom Database': 'MY_CUSTOM_DB_ID',
};
```

---

### 問題 3：Notion Integration 未授權

**輸出**：
```
❌ Topic Summaries 主題總結
   狀態：Notion Integration 未授權
```

**解決方法**：
1. 打開該資料庫在 Notion 中
2. 點擊右上角 `...` → `Connections`
3. 搜尋並添加你的 Integration

---

### 問題 4：環境變數未同步到 Vercel

**症狀**：本地測試成功，Vercel 部署失敗

**解決方法**：

**方式 1**：使用 `--vercel` 參數
```bash
node scripts/sync-env.js --vercel
```

**方式 2**：手動上傳
```bash
vercel env add NOTION_TOPIC_SUMMARY_DB_ID production
# 輸入值：2a75ef9980b98146a112fff1bdf3e708
```

**方式 3**：在 Vercel Dashboard 手動添加
1. 進入 Vercel 專案設定
2. Environment Variables 分頁
3. 添加變數

**重要**：添加後必須重新部署！
```bash
vercel --prod
```

---

## 🎯 最佳實踐

### 1. 定期運行檢查

每週運行一次健康檢查：
```bash
node scripts/sync-env.js --check
```

### 2. 新建資料庫後立即同步

創建新的 Notion 資料庫後：
```bash
node scripts/sync-env.js --vercel
vercel --prod
```

### 3. 備份管理

腳本會自動生成 `.env.backup`，但建議：
- 定期手動備份 `.env` 到安全的地方
- 不要將 `.env` 提交到 Git（已在 .gitignore 中）

### 4. 測試流程

在 Vercel 部署前，先本地測試：
```bash
# 1. 運行腳本
node scripts/sync-env.js

# 2. 檢查 .env
cat .env

# 3. 本地測試
vercel dev

# 4. 同步到 Vercel
node scripts/sync-env.js --vercel

# 5. 部署
vercel --prod
```

---

## 📊 技術細節

### 資料庫 ID 格式化

Notion API 返回的資料庫 ID 格式：
```
2a75ef99-80b9-8146-a112-fff1bdf3e708
```

腳本會自動格式化為：
```
2a75ef9980b98146a112fff1bdf3e708
```
（移除連字符，符合環境變數格式）

### 安全性

- ✅ 不會覆蓋非 Notion 相關的環境變數
- ✅ 自動生成備份
- ✅ Dry run 模式可安全預覽
- ✅ 敏感信息不會輸出到 console

---

## 🚀 進階用法

### 組合使用

**場景 1**：第一次設置
```bash
# 1. 預覽效果
node scripts/sync-env.js --dry-run

# 2. 更新 .env
node scripts/sync-env.js

# 3. 健康檢查
node scripts/sync-env.js --check

# 4. 同步到 Vercel
node scripts/sync-env.js --vercel
```

**場景 2**：定期維護
```bash
# 每週運行一次健康檢查
node scripts/sync-env.js --check
```

**場景 3**：新建資料庫
```bash
# 一步完成所有操作
node scripts/sync-env.js --vercel && vercel --prod
```

---

## 💡 常見問題

**Q: 腳本會覆蓋我的自定義環境變數嗎？**
A: 不會。腳本只更新 Notion 相關的環境變數（以 `NOTION_` 開頭或 `WEEKLY_DB_ID`）。

**Q: 如果我重命名 Notion 資料庫會怎樣？**
A: 重新運行腳本會自動更新映射。建議使用 `--check` 先驗證。

**Q: 可以自動運行嗎？**
A: 可以，但不推薦。環境變數通常不需要頻繁變更，手動運行更安全。

**Q: 支援多個 Notion workspace 嗎？**
A: 目前不支援。如需多 workspace，請為每個 workspace 創建獨立的 .env。

---

## 📚 相關文檔

- [Notion API 文檔](https://developers.notion.com/)
- [Vercel 環境變數文檔](https://vercel.com/docs/concepts/projects/environment-variables)
- [主題總結功能設置指引](./NOTION_TOPIC_SUMMARY_SETUP.md)

---

## 🤝 貢獻

如果你發現 bug 或有改進建議，歡迎：
1. 編輯 `scripts/sync-env.js`
2. 添加新的資料庫映射規則到 `DB_MAPPING`
3. 提交 Pull Request
