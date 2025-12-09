# LINE Webhook 簽名驗證 - 測試計劃

## 實作摘要

✅ **已完成**：LINE Webhook 簽名驗證功能已實作於 `api/webhook.js`

### 新增功能
1. **簽名驗證邏輯**
   - 使用 HMAC-SHA256 計算簽名
   - 比對 `x-line-signature` header
   - 驗證失敗返回 401 Unauthorized

2. **安全日誌**
   - 記錄驗證成功/失敗
   - 記錄來源 IP 和 User-Agent（安全審計）
   - 詳細的錯誤訊息（便於調試）

3. **改進的日誌格式**
   - 使用 emoji 標記不同類型的日誌
   - 結構化錯誤訊息

---

## 測試階段

### Phase 1: 本地測試（開發環境）

#### 1.1 驗證代碼語法
```bash
# 確認沒有語法錯誤
cd C:\Users\user\commercial-line-bot
npm run dev
```

**預期結果**：
- ✅ Server 啟動成功
- ✅ 沒有 import 錯誤
- ✅ 沒有語法錯誤

#### 1.2 測試偽造請求（應被拒絕）

創建測試腳本 `test-webhook-signature.js`：

```javascript
import fetch from 'node-fetch';

async function testFakeRequest() {
  console.log('🧪 測試 1: 偽造請求（無簽名）');

  const response1 = await fetch('http://localhost:3000/api/webhook', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      events: [
        {
          type: 'message',
          message: { type: 'text', text: '測試' },
          source: { userId: 'U1234567890' },
          replyToken: 'fake-token'
        }
      ]
    })
  });

  console.log('   狀態碼:', response1.status);
  console.log('   預期: 401 (Unauthorized)');
  console.log(response1.status === 401 ? '   ✅ PASS' : '   ❌ FAIL');

  console.log('\n🧪 測試 2: 偽造請求（錯誤簽名）');

  const response2 = await fetch('http://localhost:3000/api/webhook', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-line-signature': 'fake-signature-12345'
    },
    body: JSON.stringify({
      events: [
        {
          type: 'message',
          message: { type: 'text', text: '測試' },
          source: { userId: 'U1234567890' },
          replyToken: 'fake-token'
        }
      ]
    })
  });

  console.log('   狀態碼:', response2.status);
  console.log('   預期: 401 (Unauthorized)');
  console.log(response2.status === 401 ? '   ✅ PASS' : '   ❌ FAIL');
}

testFakeRequest();
```

運行測試：
```bash
node test-webhook-signature.js
```

**預期結果**：
- ✅ 測試 1：返回 401（缺少簽名）
- ✅ 測試 2：返回 401（簽名錯誤）
- ✅ Vercel logs 顯示 "🚨 安全警告"

---

### Phase 2: Vercel 預覽部署測試

#### 2.1 部署到預覽環境
```bash
git add api/webhook.js
git commit -m "security(webhook): Add LINE signature verification

- api/webhook.js: Implement HMAC-SHA256 signature validation
  - Added crypto import for signature computation
  - Validate x-line-signature header before processing events
  - Return 401 Unauthorized for missing/invalid signatures
  - Added detailed security logging (IP, User-Agent)
  - Improved log formatting with emojis for better readability
  - Fixed indentation after removing redundant else branch

Security:
- Prevents unauthorized webhook requests
- Protects against API quota exhaustion attacks
- Follows LINE official documentation best practices
- Reference: https://developers.line.biz/en/docs/messaging-api/receiving-messages/#verifying-signatures

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"

git push
```

#### 2.2 檢查 Vercel 預覽部署
1. 前往 Vercel Dashboard
2. 找到預覽部署的 URL（例如：`commercial-line-bot-xxx.vercel.app`）
3. 檢查部署日誌，確認沒有錯誤

**預期結果**：
- ✅ 部署成功
- ✅ 函數構建成功
- ✅ 沒有 runtime errors

---

### Phase 3: Production 測試（真實 LINE 訊息）

#### 3.1 部署到 Production
```bash
vercel --prod
```

或使用 npm script：
```bash
npm run deploy
```

#### 3.2 使用 LINE App 發送測試訊息

**測試場景 1：基本對話**
1. 在 LINE App 中找到你的 Bot
2. 發送訊息：`幫助`
3. 觀察回應

**預期結果**：
- ✅ Bot 正常回應幫助訊息
- ✅ Vercel logs 顯示 "✅ LINE 簽名驗證通過"
- ✅ 沒有 401 錯誤

**測試場景 2：結構化訓練**
1. 發送：`問`
2. Bot 提供一個問題
3. 回答問題
4. 觀察 AI 回饋

**預期結果**：
- ✅ 對話正常進行
- ✅ 每次訊息都通過簽名驗證
- ✅ Notion 正常記錄數據

**測試場景 3：各種指令**
測試所有 15 個指令：
- `問`, `儲存`, `小結`, `結束`, `狀態`
- `查詢 定價策略`
- `總結 商業模式`
- `總結狀態`
- `週報`
- `標籤列表`
- `清除`, `系統`, `幫助`
- 自由對話：`今天天氣如何？`

**預期結果**：
- ✅ 所有指令正常工作
- ✅ 每次都通過簽名驗證

---

### Phase 4: 監控和驗證

#### 4.1 檢查 Vercel Logs

前往 Vercel Dashboard → Logs，檢查：

**成功的請求應該看到**：
```
📥 收到 webhook 請求
✅ LINE 簽名驗證通過
📊 事件數量: 1
📝 事件類型: message
👤 使用者ID: U...
💬 訊息內容: ...
✅ 處理完成
✅ 回覆 LINE 成功
✅ Webhook 處理完成，返回 200 OK
```

**如果有偽造請求，應該看到**：
```
📥 收到 webhook 請求
🚨 安全警告: 缺少 x-line-signature header
   來源 IP: xxx.xxx.xxx.xxx
   User-Agent: ...
```

或：
```
📥 收到 webhook 請求
🚨 安全警告: 簽名驗證失敗
   收到的簽名: ...
   預期的簽名: ...
   來源 IP: xxx.xxx.xxx.xxx
```

#### 4.2 安全審計

在接下來的 24-48 小時內，監控 Vercel logs：

**檢查項目**：
- ✅ 所有來自 LINE 的請求都通過驗證
- ✅ 沒有 401 錯誤（表示 LINE 的簽名正確）
- ✅ 如果有 401 錯誤，檢查來源 IP 是否可疑

**常見問題排查**：

1. **如果看到很多 401 錯誤**
   - 檢查 `LINE_CHANNEL_SECRET` 是否正確
   - 確認環境變數沒有多餘的空格或換行符
   - 檢查 Vercel 環境變數是否更新

2. **如果 LINE 訊息無法送達**
   - 檢查是否返回 401（簽名問題）
   - 檢查 LINE 平台設定是否正確
   - 使用 LINE Webhook debugger 測試

---

## 安全效益

### 防護能力

✅ **已防護的攻擊**：
1. ❌ 偽造 webhook 請求（無簽名）
2. ❌ 中間人攻擊（簽名不匹配）
3. ❌ 重放攻擊（LINE 會改變簽名）
4. ❌ API 配額濫用（只處理合法請求）
5. ❌ 數據污染（拒絕假冒的用戶 ID）

### 監控能力

✅ **可追蹤的資訊**：
- 攻擊來源 IP
- 攻擊者的 User-Agent
- 攻擊時間
- 攻擊頻率

---

## Rollback 計劃

如果簽名驗證導致問題，可以快速 rollback：

### 方案 1: Git Revert
```bash
git revert HEAD
git push
```

### 方案 2: 臨時禁用驗證

在 `api/webhook.js` 中：
```javascript
// 緊急：臨時禁用簽名驗證（僅用於調試）
if (process.env.DISABLE_SIGNATURE_VERIFICATION === 'true') {
  console.warn('⚠️  簽名驗證已禁用 - 僅用於調試');
} else {
  // 原有的簽名驗證邏輯...
}
```

然後在 Vercel 設置環境變數：
```
DISABLE_SIGNATURE_VERIFICATION=true
```

**重要**：這只是緊急 rollback 方案，不應長期使用！

---

## 成功標準

✅ **部署成功的標誌**：
1. ✅ Vercel 部署無錯誤
2. ✅ LINE Bot 正常回應訊息
3. ✅ Vercel logs 顯示 "✅ LINE 簽名驗證通過"
4. ✅ 所有 15 個指令正常工作
5. ✅ 偽造請求被拒絕（401 錯誤）
6. ✅ 24 小時內無異常 401 錯誤

---

## 後續建議

### 短期（1 週內）
- [ ] 監控 Vercel logs（每天檢查）
- [ ] 確認沒有異常的 401 錯誤
- [ ] 測試所有核心功能

### 中期（1 個月內）
- [ ] 實作 rate limiting（防止 DDoS）
- [ ] 添加 IP 白名單（只允許 LINE 的 IP 範圍）
- [ ] 設置告警（如果 401 錯誤過多）

### 長期
- [ ] 實作 request logging（完整審計追蹤）
- [ ] 定期安全審查
- [ ] 考慮添加 WAF (Web Application Firewall)

---

## 聯繫資訊

**LINE 官方文檔**：
- [Verifying Signatures](https://developers.line.biz/en/docs/messaging-api/receiving-messages/#verifying-signatures)
- [Webhook Event Objects](https://developers.line.biz/en/reference/messaging-api/#webhook-event-objects)

**Vercel 文檔**：
- [Serverless Functions](https://vercel.com/docs/functions/serverless-functions)
- [Environment Variables](https://vercel.com/docs/projects/environment-variables)

**如果遇到問題**：
1. 檢查 Vercel logs
2. 使用 LINE Webhook debugger
3. 查看本項目的 CODE_REVIEW_REPORT_V2.md

---

**測試計劃版本**: 1.0
**創建日期**: 2025-11-12
**實作者**: Claude Code
