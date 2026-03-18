# SDD-WorkSpace 治理演進統整文檔（給另一個 LLM 的 Intake / Orientation Brief）

## 文件目的

本文件的目的，是把目前使用者在 **SDD-WorkSpace** 上正在做的治理演進工作，整理成一份可直接交給另一個 LLM 模型閱讀的核心統整文檔。

這不是一般專案 README，也不是單一 SOP 重述。

它的任務是讓另一個模型快速理解：

1. 使用者現在真正想解的核心問題是什麼。
2. 既有 SDD / spec-kit 流程的盲點在哪裡。
3. 為什麼需要新增 **Implementation Readiness Triage / `/speckit.readiness`**。
4. **ECI v2** 在整體治理中的正確位置是什麼。
5. 為什麼最後收斂成「**2 個正式 command + 多個內部 route 類型**」，而不是一排平行 command。
6. 未來若要繼續演進，應該遵守哪些核心原則，避免再次偏離。

---

# 1. 背景：使用者目前在做什麼

使用者不是只想做一個功能，也不是單純想替某個 SDK 補文件。

使用者正在做的事情，本質上是：

> **把 SDD-WorkSpace 從一個「能跑 spec-kit / SDD 流程的 workspace」，進一步演進成一個更完整的 studio-first 治理系統，特別補上「可實作性 / 前提充足性」這個既有流程中的缺口。**

換句話說，使用者目前的焦點不是一般開發，而是：

- 治理
- 流程一致性
- authority order
- canonical source
- AI / agent 能否在受控前提下穩定生成與落地
- 如何避免 LLM 在前提不足時仍繼續假裝能做

這個目標帶有很明確的 meta 層次：

> 使用者不是在優化單一專案，而是在優化「AI 如何在他的整套 SDD / studio operating system 裡工作」。

---

# 2. 已知 workspace 定位

根據目前對 repo 的理解，**SDD-WorkSpace** 並不是單純的程式碼 repo，而是一個：

- studio-first
- governance-oriented
- authority-aware
- shared-runtime-oriented
- SDD / spec-kit orchestration workspace

其核心特性包含：

1. 有明確的 **studio-level constitution**。
2. 有 project-level constitution，但不得放寬 studio constitution。
3. 有明確的 runtime source / canonical source / mirror source 區分。
4. 將 `.github/agents/`、`.github/prompts/`、templates、scripts、knowledge capture 等視為整體系統的一部分。
5. 已具有 `discover / specify / clarify / plan / tasks / analyze` 等流程治理思維。

這代表任何新的治理設計，都不應被理解成「再多掛一個功能」，而應被理解為：

> **在既有 studio operating model 裡，補上一個缺失已久但極關鍵的治理閘門。**

---

# 3. 使用者真正想解的問題

使用者提出的原始疑問是：

> 如果現有 spec-kit / SDD 流程開出的 spec，在原理上很難完成，或若沒有讓模型先學某些特定知識就幾乎無法完成，會發生什麼情況？
> 為什麼好像很少看到 LLM 直接回覆「難以執行」？

這個疑問後來逐步收斂成一個更深的治理命題：

> **現有流程很會生成 spec、plan、tasks，也很會做 clarify 與 analyze；但它不一定能在前置階段明確判斷「這份 spec 雖然清楚，但其實目前不具備安全往下做的前提」。**

也就是說，真正的缺口不是「LLM 不夠聰明」，而是：

> **流程裡沒有一個正式的治理節點，要求模型判斷「這份 spec 是否已具備往下規劃與架構決策的前提」。**

---

# 4. 核心觀察：為什麼 LLM 很少說「難以執行」

目前已收斂出的核心觀察如下：

1. **LLM 預設傾向繼續生成，而不是中止任務。**
2. 當資訊不足時，LLM 常會把未知轉成假設，把阻塞點轉成合理化敘述。
3. 只要 spec 格式看起來完整，LLM 往往會誤以為任務具備可執行性。
4. 現有流程若沒有制度化要求模型輸出「前提不足」類型的狀態，模型很少主動這樣做。

因此，常見的真實風險不是「模型說做不到」，而是：

> **模型輸出一份看起來合理的 spec / plan / code，但真正的阻塞點其實被隱藏在假設、TODO、stub、或 deferred issue 裡。**

---

# 5. 既有流程中各節點的定位（非常重要）

這部分是給另一個 LLM 的關鍵上下文，必須正確理解，不能混淆。

## 5.1 `discover`

`discover` 的重點是：

- 幫助把 messy、含混、情緒化、偏商業或偏問題導向的輸入，整理成可被規格化的問題陳述
- 保持 problem-first / business-first
- 不過早跳進 implementation

它主要處理的是：

- 問題是否值得被規格化
- 商業與需求層級的 grounding

它**不是 feasibility gate**。

---

## 5.2 `specify`

`specify` 的重點是：

- 根據 discover 輸出，產出結構化 spec
- 允許一定程度的 informed guess
- 對重大不明處標示為 needs clarification

它主要處理的是：

- 規格形成
- 功能與需求結構化

它**不是 readiness gate**。

---

## 5.3 `clarify`

這是非常容易被誤解的一點。

`clarify` 的重點是：

- 針對當前 `spec.md` 的高影響 ambiguity 提出問題
- 在進 `plan` 前，讓 spec 變得更清楚、更可規劃

它主要處理的是：

- 規格清晰度
- ambiguity
- 功能邊界、資料模型、UX、成功條件等高影響缺口

它**不是 feasibility / readiness gate**。

也就是說：

> `clarify` 能回答「spec 是否夠清楚」，但不保證回答「spec 是否已具備往下做的前提」。

---

## 5.4 `analyze`

`analyze` 的重點是：

- 在 `tasks` 之後做 cross-artifact consistency 檢查
- 查看 spec / plan / tasks / constitution 之間是否一致、是否有衝突、是否有 coverage gap

它主要處理的是：

- 文件一致性
- 覆蓋率
- 憲章對齊
- 缺漏、衝突、重複

它很重要，但它**出現得太後**。

也就是說：

> `analyze` 可以告訴你文件彼此是否合理，卻未必能在更早的時點阻止「前提不足的 spec 仍一路進入 plan / tasks」。

---

# 6. 目前已確認的核心缺口

目前已收斂出的結論是：

> **現有流程缺少一個位於 `clarify` 之後、`plan` 之前的正式治理閘門，用來判斷 spec 是否已具備往下規劃與架構決策的前提。**

這個缺口不是一般 ambiguity，也不是後段 consistency，而是：

- 前提是否充足
- 是否缺乏關鍵知識
- 是否缺乏 repo-specific context
- 是否尚未拍板
- 是否尚未定義驗證方式
- 是否真實 access / runtime 條件尚未備妥
- 是否只能 exploratory，而不應直接進 mainline

這個缺口最後收斂成：

> **需要一個上位的 Implementation Readiness Triage（IRT） / `/speckit.readiness`。**

---

# 7. External Capability Intake（ECI）在這件事裡扮演什麼角色

ECI 不是新的主流程，也不是要取代現有 SDD。

它的正確定位是：

> **當 spec 的主要阻塞來自 external capability adoption（外部能力導入）時，ECI 是一條正式、專門、較重的治理子流程。**

這裡的 external capability 指的是：

- 新 SDK
- 新 external repo
- 新 framework
- 新 protocol
- 新 platform
- 新 service

如果某能力的導入會影響：

- architecture boundary
- permission / security model
- execution model
- validation method
- AI 主幹可實作性

那它不應被當成 implementation 階段的臨場學習，而應先進 ECI。

---

# 8. ECI v1 與 v2 的演進脈絡（給另一個 LLM 的理解）

## 8.1 v1 的核心精神

ECI v1 的核心主張是：

- 外部能力導入不應在 implementation 階段偷偷決定架構
- AI 不應每次實作都重新臨場讀外部 repo / docs
- 應把外部能力轉化成可審核、可交接、可追蹤的治理資產
- 應在 Spec 與 Architecture 之間插入一個前架構治理閘門

這個方向是正確的。

---

## 8.2 v2 的重要升級

ECI v2 不是只是把 v1 改寫得更漂亮，而是有幾個本質升級：

1. 不再只是 `YES / NO`，而是：
   - `NO_ECI`
   - `LIGHT_ECI`
   - `STANDARD_ECI`
   - `CRITICAL_ECI`

2. 不再只是 Ready / Not Ready，而是明確區分授權等級：
   - `READY_FOR_MAINLINE_IMPLEMENTATION`
   - `READY_FOR_SPIKE_ONLY`
   - `READY_FOR_SANDBOX_ONLY`
   - `NOT_READY`

3. 補上 source basis / source manifest 概念：
   - source URLs / references
   - target version / tag / commit / release
   - canonical source candidates
   - last verified date

4. 承認探索、沙盒、主幹採用需要明確分流，而不是模糊地說「先試試看」。

因此，v2 已經是一個很成熟的 external capability governance SOP。

---

# 9. 為什麼 ECI v2 仍然不能取代上位 readiness gate

這是整個統整文檔最重要的判斷之一。

ECI v2 雖然已經很成熟，但它的世界觀仍然是：

> 當前 case 已被辨識為「external capability 問題」，現在要決定它怎麼被納管。

但使用者想補的缺口更上位。

真正的問題是：

> 在 `clarify` 之後，到底為什麼現在還不能安全往下進 `plan`？

這個答案不一定是 external capability。

還可能是：

- repo context 不足
- 關鍵決策未完成
- 驗證方式未定義
- access / runtime 條件未備妥
- 目前只允許 exploratory，不允許進 mainline

所以：

> **ECI v2 是 readiness 體系中的一條重要分支，但不是整體 readiness triage 的替代品。**

---

# 10. 最終收斂出的核心治理模型

目前已收斂出的最終治理模型如下：

## 10.1 上位層：`/speckit.readiness`

這是一個位於：

- `clarify` 之後
- `plan` 之前

的正式治理閘門。

它的任務不是產完整 architecture，也不是做後段 consistency review。

它的任務是：

> **判斷目前 spec 是否已具備往下進行 planning / architecture 的前提；若未具備，主阻塞屬於哪一類，並輸出對應的 remediation packet 或 routing 結果。**

---

## 10.2 下位層：`/speckit.eci`（或 ECI v2 文件流程）

這是 `/speckit.readiness` 的一條正式專門支線。

只有在 readiness 判定為：

- `ROUTE_TO_ECI`

時，才會進入 ECI v2。

---

# 11. 為什麼最後不做成 5 個 command

這是使用者特別關心、且已明確同意收斂結果的地方。

一開始曾考慮把各種 route 都 agent 化，例如：

- `/speckit.readiness`
- `/speckit.eci`
- `/speckit.repo-context`
- `/speckit.decide`
- `/speckit.validation-readiness`
- 甚至還包含 access / runtime 類型

但後來已明確收斂為：

> **分類不能少，但 command 不一定要多。**

原因如下：

1. command 太多，入口會過碎。
2. 治理本來要解的是「前提是否充足」，不是維護一排命令。
3. 很多缺口類型其實不需要獨立 agent，只需要清楚指出缺口並輸出固定包。
4. 在治理語義尚在穩定期時，過早把每個 route 都 agent 化，後續更難改。

因此最後的正式入口被收斂為：

1. `/speckit.readiness`
2. `/speckit.eci`

其餘類型保留為 readiness 內部的 route 類型與標準輸出包。

---

# 12. 最終採納的 route 類型

`/speckit.readiness` 的正式輸出狀態目前收斂為以下幾類：

1. `READY_FOR_PLAN`
2. `ROUTE_TO_ECI`
3. `ROUTE_TO_REPO_CONTEXT`
4. `ROUTE_TO_DECISION`
5. `ROUTE_TO_VALIDATION`
6. `ROUTE_TO_ACCESS`
7. `EXPLORATORY_ONLY`
8. `NOT_READY`

這些狀態的設計原則是：

- 狀態要能清楚表達「為什麼現在不能往下」
- 狀態要能對應到不同補救方式
- 狀態不能只是一句模糊的「資訊不足」

---

# 13. 為什麼這些 route 類型不能硬合併

雖然 command 入口可以收斂，但治理語義不能硬合併。

因為它們對應的補救動作本質不同：

## 13.1 `ROUTE_TO_ECI`
主阻塞是 external capability adoption。

需要做的是：
- 分級
- 採用決策
- capability scan / mapping
- governed packaging
- implementation authorization

---

## 13.2 `ROUTE_TO_REPO_CONTEXT`
主阻塞是 repo-specific context 不足。

需要做的是：
- canonical source / runtime authority map
- boundary / forbidden moves / existing contract 梳理
- 現有 repo reality 顯性化

---

## 13.3 `ROUTE_TO_DECISION`
主阻塞是關鍵事項尚未拍板。

需要做的是：
- decision framing
- option comparison
- owner / approver 指派
- 拍板後回流 readiness

---

## 13.4 `ROUTE_TO_VALIDATION`
主阻塞是 done / evidence / evaluation 尚未定義。

需要做的是：
- validation contract
- success / failure signals
- acceptable evidence
- test / eval / review / oracle strategy

---

## 13.5 `ROUTE_TO_ACCESS`
主阻塞是實際 access / runtime / credential 條件未備妥。

需要做的是：
- access setup checklist
- credentials / sandbox / environment prerequisites
- 何時可回流 readiness

因此，結論是：

> **治理語義不能合併，但操作入口可以合併。**

---

# 14. 最終建議的最小可行版本（MVP）

這是目前最推薦、也最符合使用者現階段的版本。

## 正式 command

只保留兩個：

1. `/speckit.readiness`
2. `/speckit.eci`

## readiness 內部 route 類型

保留：

- `ROUTE_TO_ECI`
- `ROUTE_TO_REPO_CONTEXT`
- `ROUTE_TO_DECISION`
- `ROUTE_TO_VALIDATION`
- `ROUTE_TO_ACCESS`
- `EXPLORATORY_ONLY`
- `NOT_READY`

## route 的交付形式

一開始先不要全部 agent 化。

而是由 `/speckit.readiness` 輸出對應的標準包：

- `Repo Context Packet`
- `Decision Record`
- `Validation Contract`
- `Access Setup Checklist`

也就是說：

> **先穩定治理語義與輸出格式，再決定哪些 route 未來值得獨立 agent 化。**

---

# 15. 建議流程位置（固定理解）

目前最終收斂的流程位置是：

```text
discover
→ specify
→ clarify
→ readiness
   ├─ READY_FOR_PLAN → plan
   ├─ ROUTE_TO_ECI → ECI v2 → 回流 readiness / plan
   ├─ ROUTE_TO_REPO_CONTEXT → Repo Context Packet → 回流 readiness
   ├─ ROUTE_TO_DECISION → Decision Record → 回流 readiness
   ├─ ROUTE_TO_VALIDATION → Validation Contract → 回流 readiness
   ├─ ROUTE_TO_ACCESS → Access Setup Checklist → 回流 readiness
   ├─ EXPLORATORY_ONLY → 只允許 spike / sandbox
   └─ NOT_READY → 停止往下
→ tasks
→ analyze
→ implementation / verification
```

這個順序不可隨意改動。

特別注意：

- `readiness` 不應放在 `discover` 前，也不應放在 `specify` 前。
- `readiness` 也不應晚到 `plan` 或 `tasks` 之後。
- `clarify` 不是 `readiness` 的替代品。
- `analyze` 不是前置 triage 的替代品。

---

# 16. 另一個 LLM 在接手時應避免的誤解

這一節非常重要，因為很多模型會在這些地方走偏。

## 誤解 1：把 `clarify` 當成 readiness gate

錯。

`clarify` 只保證 spec 較清楚，不保證 spec 前提已充分。

---

## 誤解 2：把 `ECI v2` 當成總體 readiness gate

錯。

ECI v2 只處理 external capability adoption。

---

## 誤解 3：以為 route 類型應各自獨立成 command

錯。

目前已明確收斂為：

- command 精簡
- route 類型保留
- 先用標準包，不急著全 agent 化

---

## 誤解 4：以為 command 少就代表治理語義也可以簡化成一個模糊狀態

錯。

command 可以少，但狀態與 remediation 類型仍需清楚。

---

## 誤解 5：把外部 repo / docs 的臨場閱讀當成正式主幹實作依據

錯。

這正是 ECI 要治理的問題之一。

---

## 誤解 6：一旦進入 `EXPLORATORY_ONLY` 就代表治理失敗

錯。

探索是允許的，但必須被授權、被標記、被限制，不得偽裝成 mainline-ready。

---

# 17. 目前建議給另一個 LLM 的工作準則

如果另一個模型要接續這個議題，應遵守以下工作準則：

1. 先維持目前收斂出的兩層結構：
   - 上位：`/speckit.readiness`
   - 支線：`/speckit.eci`

2. 若判斷某 case 不是 external capability 問題，不要硬塞進 ECI。

3. 若判斷某 case 的阻塞是 repo-specific context、decision、validation、access，不要急著提議新增一支新 command；優先維持「route 類型 + 標準包」模型。

4. 若未來某 route 類型極常出現、且其輸出格式穩定，再考慮獨立 agent 化。

5. 所有設計都要優先維護：
   - authority clarity
   - canonical source 明確性
   - 可審核性
   - 可交接性
   - AI 不依賴臨場隨機學習

---

# 18. 治理文件 drift 風險（必須記住）

這是使用者特別要求記住的事項。

> **在 SDD-WorkSpace repo 中，`WORKSPACE_STRUCTURE.md` 需要持續檢查是否與目前實際 runtime / canonical source 設計一致，避免治理文件與實際來源權威產生 drift。**

更一般化地說：

- 凡是說明 structure / source-of-truth / runtime authority 的文件
- 都應持續與 repo 實際設計保持同步
- 避免 agent 讀到語義過期但看似正式的文件

這件事本身就是治理議題，而不是單純文件維護細節。

---

# 19. 目前最重要的結論（給另一個 LLM 的最終摘要）

如果只能記住最重要的幾句，請記住以下內容：

1. **使用者目前在做的是 SDD-WorkSpace 的治理演進，不是單一功能設計。**
2. **核心缺口是：現有流程缺少一個位於 `clarify` 與 `plan` 之間的 readiness gate。**
3. **`clarify` 解的是 ambiguity，不是 readiness。**
4. **`analyze` 解的是後段一致性，不是前段 triage。**
5. **ECI v2 很成熟，但它是 external capability 專用支線，不是總體 readiness gate。**
6. **最終收斂的架構是：`/speckit.readiness` + `/speckit.eci`。**
7. **其餘缺口類型保留為 readiness 的 route 類型與標準輸出包，不急著全部 agent 化。**
8. **治理語義不能少，但 command 不一定要多。**
9. **要避免 AI 在前提不足時仍一路生成看似合理的 spec / plan / code。**
10. **所有後續設計都應優先維護 authority clarity、canonical source、可審核性與可交接性。**

---

# 20. 建議後續可直接產出的實作物

若下一步要把這份統整轉成可執行治理資產，最合理的產出順序是：

1. `.github/agents/speckit.readiness.agent.md`
2. `.github/prompts/speckit.readiness.prompt.md`
3. `readiness` 的標準輸出模板：
   - Repo Context Packet
   - Decision Record
   - Validation Contract
   - Access Setup Checklist
4. `README / QUICKSTART / WORKSPACE_STRUCTURE` 中對 readiness gate 的正式佈局說明
5. 必要時再補 `ECI v2` 與 `readiness` 的交接規則文件

---

## 文件結尾一句話

> **本次治理演進的本質，不是多加一個流程，而是正式承認：spec 清楚不等於可以安全往下做；因此需要一個上位的 readiness gate，來判斷前提是否充足，並把 external capability 導入問題交給 ECI v2 處理。**
