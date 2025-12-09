# 需求品質檢查清單：會員註冊流程

**用途**: PR 審查時驗證規格品質（Unit Tests for Requirements）  
**建立日期**: 2025-12-01  
**規格**: [spec.md](../spec.md)  
**深度**: 標準  
**重點領域**: 全面檢查（完整性、明確性、一致性、安全性、UX）

---

## 需求完整性 (Requirement Completeness)

- [ ] CHK001 - 是否定義了所有必填欄位的驗證規則？ [Completeness, Spec §FR-001]
- [ ] CHK002 - 是否定義了 E-Mail 格式驗證規則？ [Gap, Spec §FR-001]
- [ ] CHK003 - 是否定義了姓名欄位的長度限制與允許字元？ [Gap, Spec §FR-001]
- [ ] CHK004 - 是否定義了註冊成功後的導向頁面或行為？ [Gap, Spec §US-2]
- [ ] CHK005 - 是否定義了驗證碼輸入錯誤的次數上限（或明確說明無上限）？ [Completeness, Spec §邊界情況]
- [ ] CHK006 - 是否定義了「受限功能」的具體清單或判斷標準？ [Gap, Spec §FR-012]
- [ ] CHK007 - 是否定義了 7 天清除未驗證帳號的執行機制（排程時機）？ [Gap, Spec §FR-018]

---

## 需求明確性 (Requirement Clarity)

- [ ] CHK008 - 「符合台灣身分證字號規則」是否包含外籍居留證號？ [Clarity, Spec §FR-002]
- [ ] CHK009 - 密碼規則「包含英文大小寫與數字」是否表示三者皆必須？ [Clarity, Spec §FR-004]
- [ ] CHK010 - 「部分功能受限」的「部分」是否有明確定義？ [Ambiguity, Spec §FR-012]
- [ ] CHK011 - 「友善錯誤訊息」是否有具體文案或規範？ [Clarity, Spec §邊界情況]
- [ ] CHK012 - 重新發送驗證碼的冷卻時間 60 秒是否從點擊開始計算或從成功發送開始？ [Clarity, Spec §FR-010]

---

## 需求一致性 (Requirement Consistency)

- [ ] CHK013 - US-1 驗收情境與 FR-003/FR-003a 的重複檢查邏輯是否一致？ [Consistency, Spec §US-1, FR-003]
- [ ] CHK014 - 驗證碼描述在 US-2（6 位數）與 FR-005（6 位純數字 000000-999999）是否一致？ [Consistency]
- [ ] CHK015 - 成功標準 SC-001（3 分鐘完成）與驗證碼有效期 5 分鐘是否合理配合？ [Consistency, Spec §SC-001, FR-006]

---

## 驗收標準品質 (Acceptance Criteria Quality)

- [ ] CHK016 - 所有功能需求是否都有對應的驗收情境？ [Coverage, Spec §FR-009, FR-010]
- [ ] CHK017 - FR-018（7 天清除帳號）是否有對應的驗收情境？ [Gap]
- [ ] CHK018 - 成功標準是否都可客觀量測（無主觀形容詞）？ [Measurability, Spec §SC-001~005]
- [ ] CHK019 - SC-002（95% 驗證信 30 秒內送達）的量測方法是否已定義？ [Measurability]

---

## 情境覆蓋 (Scenario Coverage)

- [ ] CHK020 - 是否定義了使用者中途放棄註冊的處理方式？ [Coverage, Spec §邊界情況]
- [ ] CHK021 - 是否定義了同一使用者短時間內多次嘗試註冊（不同資料）的處理？ [Gap, Exception Flow]
- [ ] CHK022 - 是否定義了驗證碼輸入頁面的 Session 過期處理？ [Gap, Exception Flow]
- [ ] CHK023 - 是否定義了未驗證會員登入後如何繼續完成驗證？ [Gap, Spec §US-4]
- [ ] CHK024 - 是否定義了密碼確認欄位（二次輸入）的需求？ [Gap]

---

## 邊界情況覆蓋 (Edge Case Coverage)

- [ ] CHK025 - 是否定義了身分證字號大小寫處理（如 A123456789 vs a123456789）？ [Edge Case, Spec §FR-002]
- [ ] CHK026 - 是否定義了 E-Mail 大小寫處理（如 User@Example.com vs user@example.com）？ [Edge Case, Spec §FR-003a]
- [ ] CHK027 - 是否定義了前後空白字元的處理（trim）？ [Edge Case]
- [ ] CHK028 - 是否定義了特殊字元在姓名欄位的處理（如連字號、中間點）？ [Edge Case, Spec §FR-001]

---

## 非功能需求 - 安全性 (Non-Functional: Security)

- [ ] CHK029 - 密碼儲存方式「雜湊後儲存」是否指定演算法或安全等級？ [Gap, Spec §關鍵實體]
- [ ] CHK030 - 是否定義了防止暴力破解驗證碼的機制？ [Gap, Security]
- [ ] CHK031 - 是否定義了防止自動化註冊攻擊的機制（如 CAPTCHA）？ [Gap, Security]
- [ ] CHK032 - 是否定義了身分證字號等敏感資料的傳輸加密需求？ [Gap, Security]
- [ ] CHK033 - 是否定義了驗證碼在 E-Mail 中的顯示安全性（防截取）？ [Gap, Security]

---

## 非功能需求 - 使用者體驗 (Non-Functional: UX)

- [ ] CHK034 - 是否定義了表單欄位的驗證時機（即時 vs 送出時）？ [Gap, UX]
- [ ] CHK035 - 是否定義了錯誤訊息的顯示位置與樣式？ [Gap, UX]
- [ ] CHK036 - 是否定義了驗證碼輸入介面的格式（6 格獨立輸入框 vs 單一輸入框）？ [Gap, UX, Spec §FR-007]
- [ ] CHK037 - 是否定義了重新發送冷卻時間的倒數顯示？ [Gap, UX, Spec §FR-010]
- [ ] CHK038 - 是否定義了載入狀態的顯示需求？ [Gap, UX]

---

## 相依性與假設 (Dependencies & Assumptions)

- [ ] CHK039 - E-Mail 發送服務的假設是否記錄了服務名稱或介面規格？ [Assumption, Spec §假設]
- [ ] CHK040 - 是否記錄了此功能與其他功能（如登入、忘記密碼）的相依關係？ [Dependency]

---

## 審查摘要

| 維度 | 項目數 | 說明 |
|------|--------|------|
| 完整性 | 7 | 驗證規格是否涵蓋所有必要需求 |
| 明確性 | 5 | 驗證需求是否具體、無歧義 |
| 一致性 | 3 | 驗證需求之間是否一致 |
| 驗收標準 | 4 | 驗證成功標準是否可量測 |
| 情境覆蓋 | 5 | 驗證主要與替代流程是否完整 |
| 邊界情況 | 4 | 驗證邊界條件是否定義 |
| 安全性 | 5 | 驗證安全需求是否完整 |
| UX | 5 | 驗證使用者體驗需求是否明確 |
| 相依性 | 2 | 驗證假設與相依是否記錄 |
| **總計** | **40** | |

---

## 使用說明

1. **審查時機**: PR 審查階段，在合併前完成所有檢查
2. **標記方式**: 
   - `[x]` 需求已明確定義且品質合格
   - `[ ]` 需求有缺漏或需要澄清
3. **追蹤標籤**:
   - `[Gap]` - 缺少需求定義
   - `[Ambiguity]` - 需求有歧義
   - `[Clarity]` - 需要更明確的說明
   - `[Consistency]` - 需求間存在不一致
   - `[Completeness]` - 需求不完整
   - `[Coverage]` - 情境覆蓋不足
   - `[Measurability]` - 無法客觀量測
