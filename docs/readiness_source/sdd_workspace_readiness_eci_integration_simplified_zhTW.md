# SDD-WorkSpace 專用治理融合版（精簡版）
## Implementation Readiness Triage（IRT）+ External Capability Intake（ECI v2）

## 文件定位

本文件是 **SDD-WorkSpace 專用的精簡治理融合版**。

它要解的問題不是再新增一排 command，而是：

1. 保留你已經收斂出的 **readiness / triage 思維**。
2. 保留 **ECI v2** 作為成熟的 external capability 專用子流程。
3. 避免把 repo context、decision、validation、access 各自長成一支獨立 command，導致流程過碎、操作成本過高。

---

## 核心結論

> **分類不能少，但 command 不一定要多。**

SDD-WorkSpace 建議只保留 **2 個正式入口**：

1. `/speckit.readiness`
2. `/speckit.eci`（或先沿用既有 ECI v2 文件流程）

其餘缺口類型不另做獨立 command，而是作為 `/speckit.readiness` 的 **內部 route 類型** 與 **標準輸出包**。

---

## 一句話定義

### `/speckit.readiness`

> 一個位於 `clarify` 之後、`plan` 之前的前規劃治理閘門，用來判斷目前 spec 是否已具備往下規劃與架構決策的前提；若尚未具備，則明確指出缺口類型，並輸出對應的 remediation packet。

### `ECI v2`

> 一個專門處理 **external capability adoption** 的正式子流程，用來評估、分級、納管、限制並授權新外部能力在本 workspace / repo 中的採用型態。

---

## 為什麼不用 5 個 command

因為目前真正需要的是：

- 一個上位 triage 入口，負責回答「現在為什麼還不能安全往下做」
- 一條成熟且較重的 ECI 支線，專門處理外部能力導入

而不是把每一種缺口都變成一支 command。

如果把 route 類型直接展開成：

- `/speckit.repo-context`
- `/speckit.decide`
- `/speckit.validation-readiness`
- `/speckit.access`

雖然語義上也成立，但對目前的 SDD-WorkSpace 來說，會有幾個問題：

1. **命令面太碎**：使用者與 agent 都要記住太多入口。
2. **治理重心偏移**：本來要解的是前提是否充足，最後變成維護一排命令。
3. **使用成本過高**：很多 case 並不需要完整 agent，只需要明確指出缺口並產出標準包。
4. **過早 agent 化**：在治理語義還在穩定期時，先把所有 route 都做成 command，後續反而難改。

因此，建議先把 **route 保留、入口收斂**。

---

## 建議的最終入口設計

## 正式 command / agent（精簡版）

1. `/speckit.readiness`
2. `/speckit.eci`

### 說明

- `/speckit.readiness`：唯一的上位 triage 入口。
- `/speckit.eci`：僅在 readiness 判定為 external capability 問題時啟動。

其餘問題類型不直接成為 command，而是由 `/speckit.readiness` 輸出對應 packet。

---

## 流程位置

```text
discover
→ specify
→ clarify
→ readiness
   ├─ READY_FOR_PLAN → plan
   ├─ ROUTE_TO_ECI → ECI v2 → 回流 readiness / plan
   ├─ ROUTE_TO_REPO_CONTEXT → 產出 Repo Context Packet → 回流 readiness
   ├─ ROUTE_TO_DECISION → 產出 Decision Record → 回流 readiness
   ├─ ROUTE_TO_VALIDATION → 產出 Validation Contract → 回流 readiness
   ├─ ROUTE_TO_ACCESS → 產出 Access Setup Checklist → 回流 readiness
   ├─ EXPLORATORY_ONLY → 只允許 spike / sandbox
   └─ NOT_READY → 暫停往下
→ tasks
→ analyze
→ implementation / verification
```

---

## `clarify`、`readiness`、`ECI`、`analyze` 的職責切分

### `clarify`
處理：
- spec ambiguity
- 高影響缺失資訊
- scope / UX / security / functional correctness 層級的澄清

不處理：
- external capability 是否已納管
- repo 是否已被充分理解
- access / runtime 是否備妥
- 是否已可進 mainline implementation

### `readiness`
處理：
- 目前 spec 是否具備進入 `plan` 的前提
- 若不具備，主因屬於哪一類缺口
- 下一步應補哪種 packet / 子流程
- 在缺口補齊前，允許做什麼、不允許做什麼

不處理：
- 深度 ECI dossier 產出
- 完整 architecture freeze
- 後段 cross-artifact consistency 審查

### `ECI v2`
處理：
- external capability 的 trigger、分級、採用、限制、授權與 re-intake
- capability pack、source basis、ADR / ADR-lite、implementation authorization

不處理：
- 所有其他 readiness 類型
- 整個專案的總體 readiness 結論

### `analyze`
處理：
- `tasks` 之後的 cross-artifact consistency
- spec / plan / tasks / constitution 的對齊與衝突

不處理：
- 前段 triage
- readiness routing

---

## `/speckit.readiness` 的正式輸出狀態

### 1. `READY_FOR_PLAN`
表示目前已具備進入 `plan` 的最低前提。

### 2. `ROUTE_TO_ECI`
表示主阻塞是 **external capability adoption**，必須進 ECI v2。

### 3. `ROUTE_TO_REPO_CONTEXT`
表示主阻塞是 **repo-specific context 不足**。

### 4. `ROUTE_TO_DECISION`
表示主阻塞是 **關鍵決策尚未拍板**。

### 5. `ROUTE_TO_VALIDATION`
表示主阻塞是 **done / evidence / evaluation 尚未定義**。

### 6. `ROUTE_TO_ACCESS`
表示主阻塞是 **權限、credential、sandbox、runtime 條件未備妥**。

### 7. `EXPLORATORY_ONLY`
表示目前只允許 spike / sandbox / lab 式探索，不得直接進 mainline。

### 8. `NOT_READY`
表示存在高風險前提缺口，現階段不得往下。

---

## 為什麼這些 route 類型不能硬合併成一種「缺口」

因為它們的補救方式不同：

- **ECI**：要做外部能力納管與採用授權
- **Repo Context**：要補 internal authority、boundary、現況理解
- **Decision**：要由 owner 拍板，不能讓 AI 自行補完
- **Validation**：要先定義如何證明完成
- **Access**：要先準備現實環境條件

所以：

- **治理語義不能合併**
- **command 入口可以合併**

---

## `/speckit.readiness` 內部 route 的標準輸出包

這四類 route 先不獨立 command，而是先輸出標準包。

### A. Repo Context Packet

適用於：`ROUTE_TO_REPO_CONTEXT`

目的：
- 把「這個 repo 自己的真實約束」顯性化
- 避免 AI 以一般工程常識取代 repo-specific reality

最小內容：
- Canonical source / runtime authority map
- 相關目錄與模組邊界
- 不得破壞或不得越界的路徑 / 規則
- 已存在 contract / interface / script / workflow 摘要
- 受影響區域與非目標區域
- 仍未知之處與後續需補讀項目

---

### B. Decision Record

適用於：`ROUTE_TO_DECISION`

目的：
- 把「還沒拍板」和「可以合理假設」明確分開
- 防止 AI 把未決策事項偷偷變成預設實作

最小內容：
- 問題陳述
- 為何此決策會阻塞 planning / architecture
- 可選方案（2–4 個即可）
- 每個方案的主要影響
- 建議 owner / approver
- 截止條件：什麼決定一旦拍板，就可回流 readiness

---

### C. Validation Contract

適用於：`ROUTE_TO_VALIDATION`

目的：
- 先定義如何證明 done，而不是先大量拆 task

最小內容：
- 需要被證明的 claims
- 成功 / 失敗 signal
- 最低可接受 evidence
- 測試 / eval / review / oracle 方式
- 哪些部分只能 exploratory evidence、哪些需要正式驗證
- 回流 readiness 的最低條件

---

### D. Access Setup Checklist

適用於：`ROUTE_TO_ACCESS`

目的：
- 把「現實環境條件尚未具備」從 implementation 細節提升為正式阻塞

最小內容：
- 缺少的 credentials / service accounts / permissions
- 缺少的 sandbox / infra / runtime prerequisites
- 申請或準備責任人
- 驗證方式（如何確認 access 已就緒）
- 安全與審計注意事項
- 回流 readiness 的完成條件

---

## `/speckit.eci` 為什麼應維持獨立

因為 ECI v2 與其他 route 類型相比，已具備以下特徵：

1. 已有成熟 SOP 與 gate 設計
2. 已有 Light / Standard / Critical 分級
3. 已有 mainline / spike / sandbox 授權語義
4. 已涉及 source basis、capability pack、ADR / ADR-lite、adoption boundary
5. 與 architecture、repo contract、AI implementation 穩定性高度耦合

因此，ECI 不應被退化成 readiness 的一張普通表單。它應維持為一條 **專用、較重、正式的治理子流程**。

---

## 建議的最小可行治理版本（推薦）

### 正式 command
1. `/speckit.readiness`
2. `/speckit.eci`

### 先不獨立 agent 化的項目
- Repo Context Packet
- Decision Record
- Validation Contract
- Access Setup Checklist

### 實作方式
- 先以模板 + human-in-the-loop + readiness routing 實作
- 後續若某一類 route 高頻且模式穩定，再考慮獨立 agent 化

---

## 何時才建議拆出第 3 個 command

只有在以下條件同時成立時才建議拆：

1. 某一類 route 出現頻率顯著高
2. 內容結構高度穩定
3. 已有足夠標準化輸入 / 輸出
4. 拆出後能明顯降低治理摩擦，而不是只增加 command 數量

### 優先候選
若未來真的要拆，第 3 個最可能值得拆的是：

- `/speckit.repo-context`

因為對 SDD-WorkSpace 這種高度治理、強調 canonical source 與 runtime authority 的工作區來說，repo-specific context 很常是實際 blocker。

但這不是現在的必要動作。

---

## 與現有 SDD-WorkSpace 的兼容性

本精簡版不改動以下既有角色：

- `discover` 的商業現實錨定功能
- `specify` 的 spec 結構化功能
- `clarify` 的 ambiguity 收斂功能
- `analyze` 的後段一致性審查功能
- `ECI v2` 的 external capability governance 主體

它只新增一件事：

> **在 `clarify` 與 `plan` 之間，插入一個上位 triage 閘門，避免 spec 雖清楚、文件雖一致，卻仍在前提不足下往下推進。**

---

## 治理注意事項

### 1. 不要讓 route 類型直接等於 command 數量
這會讓治理工具化過度，反而失去判斷力。

### 2. 不要把 readiness 當成另一個 analyze
它不是後段一致性檢查，而是前段前提判定。

### 3. 不要讓 `clarify` 承擔 readiness
`clarify` 再重要，也只解 spec ambiguity，不解 implementation readiness。

### 4. 不要讓 ECI 取代總體 triage
ECI 很成熟，但它只處理 external capability 類問題。

### 5. 要持續檢查治理文件與 runtime source 是否 drift
例如 `WORKSPACE_STRUCTURE.md`、README、`.github/agents/`、`.github/prompts/`、constitution 之間，必須持續保持語義對齊，避免說明文件與實際 canonical source 脫節。

---

## 最終治理判語

> **SDD-WorkSpace 應採用「一個上位 readiness 入口 + 一條成熟的 ECI 支線」的治理模型，而不是五個平行 command。**

也就是：

- 用 `/speckit.readiness` 統一做前提分流
- 用 `/speckit.eci` 正式處理 external capability
- 用標準 packet 處理 repo context / decision / validation / access
- 等治理模式穩定且高頻後，再決定是否拆出額外 command

