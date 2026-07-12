# SDD 專案啟動完整指南

> 版本：1.0.0 | 更新日期：2025-12-12 | 作者：AI Studio

本指南提供從零開始啟動 Specification-Driven Development (SDD) 專案的完整流程，適用於個人 AI 工程師或小型團隊。

---

## 目錄

1. [什麼是 SDD](#1-什麼是-sdd)
2. [開始之前：環境準備](#2-開始之前環境準備)
3. [SDD 核心原則](#3-sdd-核心原則)
4. [階段 0：需求發掘 (Discover)](#4-階段-0需求發掘-discover)
5. [階段 1：規格撰寫 (Specify)](#5-階段-1規格撰寫-specify)
6. [階段 2：需求釐清 (Clarify)](#6-階段-2需求釐清-clarify)
7. [階段 3：Implementation Readiness Triage (Readiness)](#7-階段-3implementation-readiness-triage-readiness)
8. [階段 4：技術規劃 (Plan)](#8-階段-4技術規劃-plan)
9. [階段 5：任務分解 (Tasks)](#9-階段-5任務分解-tasks)
10. [階段 6：一致性分析 (Analyze)](#10-階段-6一致性分析-analyze)
11. [階段 7：實作執行 (Implement)](#11-階段-7實作執行-implement)
12. [Git 工作流程](#12-git-工作流程)
13. [專案資料夾結構](#13-專案資料夾結構)
14. [常見陷阱與解決方案](#14-常見陷阱與解決方案)
15. [給初階 AI 工程師的建議](#15-給初階-ai-工程師的建議)
16. [快速啟動 Checklist](#16-快速啟動-checklist)
17. [附錄：文件模板](#17-附錄文件模板)

---

## 1. 什麼是 SDD

### 1.1 定義

Specification-Driven Development (SDD) 是一種以規格文件為核心的開發方法論。與傳統的「先寫 code 再補文件」不同，SDD 要求：

| 傳統開發 | SDD 開發 |
|----------|----------|
| 想到什麼做什麼 | 先想清楚再做 |
| 文件是附屬品 | 文件是設計本身 |
| Code 決定行為 | Spec 決定行為，Code 只是實現 |
| 返工成本高 | 前期投資換取後期穩定 |

### 1.2 SDD 七階段流程

| 階段 | 主要輸出 |
|------|----------|
| `specify` | `spec.md` |
| `clarify` | 更新後的 `spec.md` |
| `readiness` | `readiness/readiness-assessment.md` |
| `plan` | `plan.md` |
| `tasks` | `tasks.md` |
| `analyze` | 分析報告 |
| `implement` | `src/` 與 `tests/` |

**關鍵規則**：每個階段必須完成後才能進入下一階段，不可跳過。

`intent-ledger.md` 不是新 stage，而是只有在核心 spec 項目被 represented、deferred 或正式 dropped 時才建立的 secondary artifact。

### 1.3 為什麼要用 SDD

| 好處 | 說明 |
|------|------|
| 減少返工 | 問題在文件階段就被發現，不用改 code |
| AI 協作友善 | 結構化文件讓 AI 能更好地理解和協助 |
| 知識保留 | 決策理由都記錄在文件中 |
| 可追溯性 | 每個 task 都能追溯到 spec 中的需求 |
| 團隊協作 | 新成員可以快速理解專案脈絡 |

---

## 2. 開始之前：環境準備

### 2.1 Runtime 與 VS Code 環境確認

| 項目 | 要求 | 檢查方式 |
|------|------|----------|
| PowerShell | 7 或更新版本；命令名稱為 `pwsh` | `pwsh --version` |
| powershell-yaml | 0.4.12 | `pwsh -NoProfile -Command "Get-Module powershell-yaml -ListAvailable"` |
| Pester | 5.7.1 | `pwsh -NoProfile -Command "Get-Module Pester -ListAvailable"` |
| VS Code 版本 | 1.107+ | Help > About |
| GitHub Copilot Chat | 已安裝並登入 | Extensions 面板 |
| Custom Agents | 已載入 | Chat 中輸入 `@` 查看 agent 列表 |

本工作區的 shared PowerShell 腳本不支援 Windows PowerShell 5.1。可執行範例應以 `pwsh ./studio/scripts/powershell/<script>.ps1` 形式呼叫，讓版本不符時在腳本進入點立即失敗。

### 2.2 啟用 SDD 優化設定

在 `.vscode/settings.json` 中加入：

```json
{
  // Custom Agents 可被主 Agent 自動呼叫為 Subagent
  "chat.customAgentInSubagent.enabled": true,

  // Background Agents 支援 Custom Agents
  "github.copilot.chat.cli.customAgents.enabled": true,

  // 重用 Claude Skills
  "chat.useClaudeSkills": true,

  // 摺疊 Agent 的 Tool Calls 輸出
  "chat.agent.thinking.collapsedTools": "always",

  // 啟用 Agent Sessions 整合視圖
  "chat.viewSessions.enabled": true,

  // 啟用新版 Inline Chat
  "inlineChat.enableV2": true,

  // 重啟後自動恢復上一個 Chat Session
  "chat.viewRestorePreviousSession": true,

  // 啟用 GitHub MCP Server（可選）
  "github.copilot.chat.githubMcpServer.enabled": true
}
```

### 2.3 必讀文件

在開始任何專案之前，必須閱讀以下文件：

| 文件 | 路徑 | 內容 |
|------|------|------|
| Studio Constitution | `studio/constitution/constitution.md` | 最高權限規則，所有專案必須遵守 |
| Copilot Instructions | `.github/copilot-instructions.md` | AI 協作規則，影響所有 agent 行為 |
| 本指南 | `studio/SDD-QUICKSTART-GUIDE.md` | SDD 完整流程說明 |

### 2.4 Shared-Layer 驗收邊界

當你修改的是 workspace / studio shared layer，而不是某個 consumer project 時，主要驗收面只看：

- studio runtime
- shared templates
- canonical docs
- shared hooks
- shared PowerShell scripts

此時 `projects/` 與 `learning/` 只是 consumer spaces，不是 shared-layer convergence 的預設驗收面。
主要機器驗證入口是：

```powershell
pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json
```

另外，`.claude/agents/` 是 shared Claude runtime authority，`<project>/.claude/agents` 是 direct junction consumption path。Claude skills install root 與 workspace shared agents runtime 是不同層。

**為何這麼做**：Constitution 定義了「什麼可以做、什麼不能做」。不了解規則就開始，會導致後續大量返工。

### 2.4 可用的 Custom Agents

| Agent | 觸發命令 | 用途 |
|-------|----------|------|
| Speckit-Discover | `/speckit.discover` | 需求發掘教練 |
| speckit.specify | `/speckit.specify` | 規格撰寫 |
| speckit.clarify | `/speckit.clarify` | 需求釐清 |
| speckit.readiness | `/speckit.readiness` | 前規劃 readiness triage |
| speckit.eci | `/speckit.eci` | `ROUTE_TO_ECI` 的 external capability governance |
| speckit.plan | `/speckit.plan` | 技術規劃 |
| speckit.tasks | `/speckit.tasks` | 任務分解 |
| speckit.analyze | `/speckit.analyze` | 一致性分析 |
| speckit.implement | `/speckit.implement` | 實作執行 |
| speckit.checklist | `/speckit.checklist` | 品質檢查清單 |
| speckit.constitution | `/speckit.constitution` | 專案憲章管理 |

> `/speckit.eci` 已是 shared runtime command，但只在 `/speckit.readiness` 判定 `ROUTE_TO_ECI` 時啟動。`eci-trigger.md` 是 intake seed，不是最終治理終點；ECI 完成後仍必須回到 `/speckit.readiness` 重新判定下一個 blocker。

---

<!-- governance-anchor: sdd-guide-core-principles -->
## 3. SDD 核心原則

### 3.1 MUST DO（必須遵守）

| 規則 | 說明 | 違反後果 |
|------|------|----------|
| 遵循七階段順序 | 不可跳過任何階段 | 後續文件不一致 |
| spec.md 至少 3 個 Edge Cases | 邊界情況分析是必要的 | 上線後發現漏洞 |
| 避免模糊用語 | 禁止 "smart"、"fast"、"good UI" | 需求無法驗證 |
| 高風險模糊性必須在 clarify 解決 | 否則不能進入 readiness / plan | 前提不足下做出錯誤規劃 |
| 所有 AI 產出需人工審查 | AI 不能自動 git commit/push | 品質失控 |
| 使用 LLM-friendly 格式 | 表格、清單優先，禁止 ASCII art | AI 無法正確解析 |
| 專案完成後更新 learnings.md | 知識捕獲是強制性的 | 團隊無法學習 |

### 3.2 MUST NOT DO（禁止事項）

| 規則 | 說明 | 為何禁止 |
|------|------|----------|
| 不假設未寫明的需求 | 禁止幻覺 | 做出 stakeholder 不要的東西 |
| 不新增 spec 未包含的功能 | 範圍管控 | 範圍蔓延 |
| 不使用 ASCII art 或樹狀結構圖 | LLM 不友善 | AI 解析錯誤 |
| 不在 SDD 文件中使用 Emoji | 僅限人類可讀文件 | tokenization 問題 |
| Project Constitution 不可放寬 Studio 規則 | 只能新增更嚴格的規則 | 架構一致性 |

### 3.3 雙層憲章系統

| 層級 | 位置 | 說明 |
|------|------|------|
| Studio Constitution | `studio/constitution/constitution.md` | 所有專案都必須遵守的最高權限規則 |
| Project Constitution | `<project>/.specify/memory/constitution.md` | 專案層級補充規則，只能加嚴不能放寬 |
| Shared Claude Runtime | `.claude/agents/` | workspace 級 Claude shared runtime authority |
| Runtime Agent Adapters | `<project>/AGENTS.md`、`<project>/CLAUDE.md`、`<project>/.github/copilot-instructions.md` | AI 啟動 adapter，共用 generated governance bootstrap，不是 constitution |

**合併邏輯**：
- Project Constitution 可以：新增專案特定術語、定義更嚴格的編碼標準、新增額外的審查清單
- Project Constitution 不可以：跳過任何 SDD 階段、放寬品質要求、覆蓋 AI 協作原則

---

## 4. 階段 0：需求發掘 (Discover)

### 4.1 概述

| 項目 | 內容 |
|------|------|
| 觸發命令 | `/speckit.discover` |
| 狀態 | 可選（但強烈建議） |
| 前置條件 | 無 |
| 輸出 | `specs/_discovery/<short-name>-discovery.md` |

### 4.2 何時使用

| 情境 | 建議 |
|------|------|
| 只有模糊的想法 | 使用 discover |
| 需求來自非技術人員 | 使用 discover |
| 想確保不遺漏 edge cases | 使用 discover |
| 已有明確的需求文件 | 可跳過，直接 specify |

### 4.3 互動問答流程

Discover 採用兩階段問答，共 7 題：

**Phase 1：核心輪廓（4 題）**

| 順序 | 問題焦點 | 目的 | 追問策略 |
|------|----------|------|----------|
| 1 | 問題/目標 | 釐清「為什麼要做這個」 | 若回答過於抽象，追問「沒有這個功能會發生什麼問題」 |
| 2 | 使用者角色 | 識別 actors 與權限差異 | 若只提一種角色，追問「還有誰會受影響或需要知道」 |
| 3 | 主要流程 | 描繪 happy path | 若過於簡略，追問「使用者第一步做什麼、最後看到什麼」 |
| 4 | 成功標準 | 定義「怎樣算完成」 | 若不可量測，追問「你怎麼知道這個功能成功了」 |

**Phase 2：深化細節（3 題）**

| 順序 | 問題焦點 | 目的 | 追問策略 |
|------|----------|------|----------|
| 5 | 邊界情況 | 識別 edge cases | 提供常見 edge case 範例引導 |
| 6 | 範圍界定 | 明確 out of scope | 詢問「這次不做什麼」 |
| 7 | 非功能需求 | 識別效能/安全/可用性要求 | 提供選項引導 |

### 4.4 輸出格式：discovery.md

```markdown
# Discovery: [功能簡稱]

**建立時間**: YYYY-MM-DD HH:mm
**狀態**: Phase 1 完成 / Phase 2 完成 / 已轉入 Specify

## 問答紀錄

### Phase 1：核心輪廓

#### Q1: 問題/目標
- 問題：[原始問題]
- 回答：[使用者回答]
- 萃取：[關鍵概念]

[Q2-Q4 同上格式]

### Phase 2：深化細節

[Q5-Q7 同上格式]

## 萃取概念

| 類別 | 內容 |
|------|------|
| Actors | [識別出的角色] |
| Goals | [目標與動機] |
| Flows | [主要流程描述] |
| Constraints | [限制與邊界] |
| Edge Cases | [識別出的邊界情況] |
| Success Criteria | [成功標準] |
| Out of Scope | [明確排除項目] |

## 下一步建議

- [ ] 複製「萃取概念」區段作為 `/speckit.specify` 的輸入
```

### 4.5 完成後的選項

Phase 1 結束後會詢問：
- **(A) 繼續 Phase 2**：深化細節
- **(B) 新 Session 繼續**：複製摘要到新對話
- **(C) 進入 Specify**：直接產生正式規格

---

## 5. 階段 1：規格撰寫 (Specify)

### 5.1 概述

| 項目 | 內容 |
|------|------|
| 觸發命令 | `/speckit.specify <需求描述>` |
| 狀態 | 必要 |
| 前置條件 | 無（或 discovery.md） |
| 輸出 | Feature branch + `specs/<feature>/spec.md` |

### 5.2 自動化行為

執行 `/speckit.specify` 時，系統會自動：

1. 從需求描述萃取 2-4 字的功能簡稱
2. 檢查是否有同名 branch/spec 存在
3. 建立 feature branch（格式：`<number>-<short-name>`）
4. 建立 `specs/<feature>/` 資料夾
5. 產生 `spec.md`

### 5.3 spec.md 必要章節

| 章節 | 內容 | 範例 |
|------|------|------|
| Problem / Goal | 為什麼要做這個 | 「使用者無法註冊會員導致轉換率低」 |
| Actors | 誰會使用 | 訪客、會員、管理員 |
| User Scenarios | 使用者故事 + 優先級 | P1: 作為訪客，我想要註冊... |
| Edge Cases | 至少 3 個邊界情況 | 重複 email、密碼太弱、驗證碼過期 |
| Functional Requirements | FR-XXX 格式 | FR-001: 系統應驗證 email 格式 |
| Non-Functional Requirements | NFR-XXX 格式 | NFR-001: API 回應時間 < 500ms |
| Success Criteria | 可量測的成功標準 | 註冊成功率 > 95% |
| Out of Scope | 明確排除項目 | 本階段不做 OAuth 登入 |
| Document Version | 版本追蹤 | v1.0.0 |

### 5.4 User Scenario 格式

```markdown
### US-001: 會員註冊 [P1]

**作為** 訪客
**我想要** 使用 email 註冊會員
**以便於** 獲得會員專屬功能

**Acceptance Criteria**:
1. 輸入有效 email 和密碼後，點擊註冊按鈕
2. 系統發送驗證信到 email
3. 點擊驗證連結後，帳號啟用
4. 可以使用 email 和密碼登入

**Priority**: P1 (Must Have)
```

### 5.5 Edge Cases 要求

Constitution 要求至少 3 個 edge cases：

| Edge Case | 描述 | 預期行為 |
|-----------|------|----------|
| EC-001 | 重複 email 註冊 | 顯示「此 email 已被註冊」錯誤訊息 |
| EC-002 | 密碼強度不足 | 顯示密碼要求，禁止提交 |
| EC-003 | 驗證碼過期 | 提示重新發送驗證信 |
| EC-004 | 惡意大量註冊 | Rate limiting，暫時封鎖 IP |

### 5.6 禁止的模糊用語

| 模糊用語 | 問題 | 正確寫法 |
|----------|------|----------|
| 快速 | 多快？ | 「API 回應時間 < 500ms」 |
| 使用者友善 | 什麼是友善？ | 「操作步驟不超過 3 步」 |
| 聰明 | 什麼是聰明？ | 「根據歷史紀錄推薦前 5 項」 |
| 安全 | 什麼等級的安全？ | 「密碼需 bcrypt 加密，cost factor 12」 |
| 可擴展 | 擴展到什麼程度？ | 「支援 10,000 concurrent users」 |

---

## 6. 階段 2：需求釐清 (Clarify)

### 6.1 概述

| 項目 | 內容 |
|------|------|
| 觸發命令 | `/speckit.clarify` |
| 狀態 | 必要（除非明確跳過） |
| 前置條件 | `spec.md` 存在 |
| 輸出 | 更新後的 `spec.md` |

### 6.2 模糊性分類

| 風險等級 | 描述 | 範例 | 處理要求 |
|----------|------|------|----------|
| **Critical** | 無法理解需求核心 | 「快速」但未定義時間 | 必須釐清才能進入 readiness |
| **High** | 可能導致重大返工 | 「部分功能受限」但未列清單 | 強烈建議釐清 |
| **Medium** | 可能遺漏功能 | 缺少某個 edge case | 可在 plan 階段補充 |
| **Low** | 影響較小 | 格式不一致 | 可延後處理 |

### 6.3 Clarify 流程

```
1. Agent 載入 spec.md
2. 執行結構化模糊性掃描
3. 產出內部 coverage map（不顯示）
4. 選出最多 5 個高優先級問題
5. 逐題詢問使用者
6. 將答案編碼回 spec.md
```

### 6.4 掃描類別

| 類別 | 檢查項目 |
|------|----------|
| Functional Scope | 核心目標、out-of-scope 聲明、角色區分 |
| Domain & Data | 實體、唯一性規則、狀態轉換、資料量假設 |
| Interaction & UX | 關鍵流程、錯誤/空/載入狀態、無障礙 |
| Integration | 外部系統、API 格式、認證機制 |
| Non-Functional | 效能、安全、可用性、監控 |

### 6.5 為何不能跳過

> Constitution 規定：「高風險模糊性必須在 clarify 階段解決，否則不能進入 readiness / plan 流程」

**跳過 clarify 的後果**：
- plan 做到一半發現需求不清楚
- 實作完成後才發現做錯方向
- 返工成本是前期釐清的 10 倍以上

---

## 7. 階段 3：Implementation Readiness Triage (Readiness)

### 7.1 概述

| 項目 | 內容 |
|------|------|
| 觸發命令 | `/speckit.readiness` |
| 狀態 | 必要 |
| 前置條件 | `clarify` 已完成，且 `spec.md` 沒有高風險模糊性 |
| 輸出 | `readiness/readiness-assessment.md` + 視 status 而定的 remediation packet |

### 7.2 核心目的

`readiness` 不負責重寫 spec，也不負責直接產出 `plan.md`。

它要回答的是：

1. 目前 spec 是否已具備進入 `plan` 的前提。
2. 若尚未具備，主阻塞屬於哪一類。
3. 最小補救包是什麼。
4. 現在允許做什麼、不允許做什麼。
5. 若核心 spec 項目被代表、延後或放棄，這些 intent obligation 是否已被正式保留。

### 7.3 正式狀態

| Status | 意義 |
|--------|------|
| `READY_FOR_PLAN` | 可以安全進入 `/speckit.plan` |
| `ROUTE_TO_ECI` | 主阻塞是 external capability，需先寫 `eci-trigger.md`，再執行 `/speckit.eci` |
| `ROUTE_TO_REPO_CONTEXT` | 主阻塞是 repo-specific context 不足 |
| `ROUTE_TO_DECISION` | 主阻塞是關鍵 owner decision 尚未拍板 |
| `ROUTE_TO_VALIDATION` | 主阻塞是 done / evidence / evaluation 尚未定義 |
| `ROUTE_TO_ACCESS` | 主阻塞是 access / credential / runtime 條件未備妥 |
| `EXPLORATORY_ONLY` | 只允許 spike / sandbox，不得直接進 mainline 規劃 |
| `NOT_READY` | 存在高風險前提缺口，必須暫停往下 |

### 7.4 輸出與回流規則

- `READY_FOR_PLAN`：產出 `readiness-assessment.md`，然後進入 `/speckit.plan`
- 若核心 spec 項目被 `represented_by_substitute`、`deferred` 或 `dropped_with_owner_signoff`：必須另外建立或更新 `intent-ledger.md`；`READY_FOR_PLAN` 仍可成立，但 handoff 不完整前不得假裝原始 intent 已消失
- `ROUTE_TO_ECI`：額外產出 `eci-trigger.md`，執行 `/speckit.eci` 產出 `readiness/eci/*.md` dossier，補完後回跑 `/speckit.readiness`
- 若 ECI 的結果仍是 `READY_FOR_SANDBOX_ONLY` 或 `READY_FOR_SPIKE_ONLY`：回流 readiness 後應轉判成 `ROUTE_TO_VALIDATION`、`ROUTE_TO_ACCESS` 或 `ROUTE_TO_DECISION` 等次級 blocker，不得直接進 `/speckit.plan`
- `ROUTE_TO_REPO_CONTEXT`：額外產出 `repo-context-packet.md`，補讀後回跑 `/speckit.readiness`
- `ROUTE_TO_DECISION`：額外產出 `decision-record.md`，owner 拍板後回跑 `/speckit.readiness`
- `ROUTE_TO_VALIDATION`：額外產出 `validation-contract.md`，定義驗證方式後回跑 `/speckit.readiness`
- `ROUTE_TO_ACCESS`：額外產出 `access-setup-checklist.md`，補齊環境後回跑 `/speckit.readiness`
- `EXPLORATORY_ONLY` / `NOT_READY`：不得直接進入 `/speckit.plan`

### 7.5 為何不能跳過

- spec 清楚，不代表 implementation 前提已經充足
- readiness 的作用是阻止 LLM 在前提不足時仍產生看似合理的 plan
- 真正的 blocker 可能不是 ambiguity，而是 external capability、repo context、decision、validation 或 access
- readiness 要守的是 planability，不是替產品定義「這輪交付就算完整」；被壓縮掉的核心意圖必須留在 `intent-ledger.md`

---

## 8. 階段 4：技術規劃 (Plan)

### 8.1 概述

| 項目 | 內容 |
|------|------|
| 觸發命令 | `/speckit.plan` |
| 狀態 | 必要 |
| 前置條件 | `readiness/readiness-assessment.md` 存在，且主狀態為 `READY_FOR_PLAN` |
| 輸出 | `plan.md` + 可選的設計文件 |

### 8.2 plan.md 必要章節

| 章節 | 內容 | 說明 |
|------|------|------|
| Technical Context | 語言、框架、資料庫、測試框架 | 列出所有技術選擇 |
| Architecture Overview | 系統架構描述 | 用文字描述，不用圖 |
| Technology Decisions | 技術選型 + 理由 | 每個決策都要有 rationale |
| "Why Not" Decisions | 被拒絕的替代方案 | 記錄考慮過但不採用的方案 |
| Data Flow | 資料流向描述 | 從輸入到輸出的完整流程 |
| Intent Recovery Obligations | 從 `intent-ledger.md` 承接 represented / deferred 項目 | 寫明目前代表方式、這輪不做原因、重新進場條件、coverage disclosure |
| Project Structure | 資料夾結構 | 用表格呈現 |
| Constraints and Risks | 限制與風險 | 技術限制、時程風險等 |
| Estimated Timeline | 預估時程 | 各階段預估天數 |
| Changelog | 變更紀錄 | 追蹤 plan 的修改歷史 |

### 8.3 可選的設計文件

| 文件 | 路徑 | 用途 |
|------|------|------|
| research.md | `specs/<feature>/research.md` | 技術調研紀錄 |
| data-model.md | `specs/<feature>/data-model.md` | 資料模型設計 |
| contracts/ | `specs/<feature>/contracts/` | API 契約定義 |
| quickstart.md | `specs/<feature>/quickstart.md` | 快速開始指南 |

若 `intent-ledger.md` 存在，`plan.md` 必須固定加入 `Intent Recovery Obligations` 區段，至少摘要所有
`represented_by_substitute` 與 `deferred` 項目。不能只寫模糊的 `v1+`，必須交代具體 re-entry trigger。

如果 feature 名稱是 umbrella term，而本輪只做 representative subset，plan 還必須指定後續文件要怎麼揭露 coverage 與 known gaps。

### 8.4 Technology Decisions 格式

```markdown
### TD-001: 使用 PostgreSQL 作為主資料庫

**選擇**: PostgreSQL 15

**理由**:
1. 支援 JSONB，適合半結構化資料
2. 團隊熟悉度高
3. 免費且開源

**替代方案考量**:
- MySQL: 不支援 JSONB
- MongoDB: 團隊經驗不足
- SQLite: 不適合多使用者並發
```

### 8.5 "Why Not" 的重要性

**為何要記錄被拒絕的方案**：
- 未來維護者不用重複評估
- 記錄當時的決策脈絡
- 如果條件改變，可以快速回顧

---

## 9. 階段 5：任務分解 (Tasks)

### 9.1 概述

| 項目 | 內容 |
|------|------|
| 觸發命令 | `/speckit.tasks` |
| 狀態 | 必要 |
| 前置條件 | `spec.md` + `plan.md` |
| 輸出 | `specs/<feature>/tasks.md` |

### 9.2 任務粒度規則

| 粒度 | 狀態 | 處理方式 |
|------|------|----------|
| 0.5-2 天 | 合適 | 直接使用 |
| < 0.5 天 | 太細 | 合併相關任務 |
| > 2 天 | 太粗 | 拆分為子任務 |

### 9.3 tasks.md 結構

```markdown
# Tasks: [功能名稱]

**Feature**: [功能簡稱]
**Branch**: [branch name]
**Generated**: YYYY-MM-DD
**Plan Reference**: [plan.md 路徑]

## Task List

- [ ] T001 [P1] [Risk: Low] [Story: N/A] 初始化專案結構
  - Depends on: None
  - DoD: 專案可編譯；測試框架可執行；linter 無錯誤

- [ ] T002 [P1] [Risk: Medium] [Story: US-001] 實作使用者註冊 API
  - Depends on: T001
  - DoD: 註冊流程通過驗收；失敗案例有明確錯誤處理；相關測試通過

- [ ] T003 [P2] [Risk: Low] [Story: US-001] 補齊註冊流程文件與操作說明
  - Depends on: T002
  - DoD: README 或 quickstart 已更新；驗收步驟可重現
```

### 9.4 任務標記說明

| 標記 | 意義 |
|------|------|
| `T001` | 任務編號 |
| `[P1]` | 優先順序 |
| `[Story: US-001]` | 對應的 User Story |
| `[Risk: High]` | 風險等級 |
| `Depends on: T001, T002` | 前置相依 |

### 9.5 Definition of Done (DoD) 要求

每個 task 必須有明確的 DoD，且 DoD 必須：
- 可驗證（不是「做完了」）
- 具體（不是「程式碼品質好」）
- 與 spec 中的需求對應

---

## 10. 階段 6：一致性分析 (Analyze)

### 10.1 概述

| 項目 | 內容 |
|------|------|
| 觸發命令 | `/speckit.analyze` |
| 狀態 | 可選（但強烈建議） |
| 前置條件 | `spec.md` + `readiness/readiness-assessment.md` + `plan.md` + `tasks.md` |
| 輸出 | 分析報告（顯示在 chat，不修改檔案） |

### 10.2 分析項目

| 類別 | 檢查內容 | 範例問題 |
|------|----------|----------|
| **Coverage** | 每個 FR/NFR 是否都有對應 task | FR-003 沒有任何 task 實作 |
| **Governance Gate** | readiness assessment 是否仍允許目前的 plan/tasks 狀態 | readiness 是 `ROUTE_TO_ECI`，但已直接進入 plan/tasks |
| **Intent Drift Check** | represented / deferred / dropped 的核心項目是否有 ledger、plan handoff、與 truthfulness disclosure | readiness 備註提到 defer，但 `intent-ledger.md` 不存在；或 plan 沒承接 |
| **Consistency** | 三份文件的術語是否一致 | spec 說「使用者」，plan 說「會員」 |
| **Completeness** | 是否有遺漏的 edge case | EC-002 沒有對應的錯誤處理 task |
| **Contradiction** | 是否有衝突的描述 | spec 說 3 個例外，tasks 列 4 個 |
| **Constitution** | 是否違反憲章規則 | plan 用了被禁止的技術 |

### 10.3 分析報告格式

```markdown
## Analyze Report: [功能名稱]

**Generated**: YYYY-MM-DD HH:mm
**Status**: PASS / FAIL / WARNING

### Coverage Summary

| Source | Item | Covered By | Status |
|--------|------|------------|--------|
| spec.md | FR-001 | T002 | PASS |
| spec.md | FR-002 | T003, T004 | PASS |
| spec.md | FR-003 | - | FAIL |
| spec.md | EC-001 | T005 | PASS |
| spec.md | EC-002 | - | WARNING |

### Issues Found

#### CRITICAL
- FR-003 (使用者登出) 沒有對應的實作任務

#### WARNING
- EC-002 (密碼強度不足) 只有前端驗證，缺少後端驗證任務

### Recommendations

1. 新增 task 實作 FR-003
2. 在 T002 中加入後端密碼強度驗證
```

### 10.4 為何要做 Analyze

| 情境 | 沒有 Analyze 的後果 |
|------|---------------------|
| 術語不一致 | 團隊溝通混亂 |
| 遺漏 task | 上線後才發現功能沒做 |
| 文件衝突 | 不知道該信哪份 |
| 違反 Constitution | 架構審查不通過 |
| Representative MVP 被誤讀成完整能力 | shipped surface 與原始 intent 失真 |

`Intent Drift Check` 固定至少檢查三件事：

1. 所有被 represented / deferred / dropped 的核心 spec 項目都有 `intent-ledger.md` 記錄。
2. `dropped_with_owner_signoff` 項目保有可追溯的 owner signoff reference，且 `plan.md` 已承接 ledger，而不是把 defer 只留在 readiness 附註。
3. `README.md`、`quickstart.md`、analyze 結論沒有把 representative subset 偽裝成原始完整能力。

若這三項有任一項失敗，不一定表示 readiness 當時判錯，但 analyze 不應給出可以安心進 implement 的綠燈結論。

---

## 11. 階段 7：實作執行 (Implement)

### 11.1 概述

| 項目 | 內容 |
|------|------|
| 觸發命令 | `/speckit.implement` |
| 狀態 | 必要 |
| 前置條件 | 所有前置文件 + `tasks.md` |
| 輸出 | `src/` 程式碼 + `tests/` 測試 |

### 11.2 執行流程

1. 檢查 `checklists/` 狀態（如有）。
   - 全部 PASS：繼續。
   - 有 FAIL：先決定是否補文件或接受風險，再開始實作。
2. 載入 `tasks.md`。
3. 依序執行每個 task，包含讀取描述與 DoD、產生程式碼、等待人工審查、標記完成。
4. 每完成一個 task 後建議 commit。
5. 所有 task 完成後準備 PR。

### 11.3 Checklist 檢查

如果 `specs/<feature>/checklists/` 存在，implement 會先檢查：

```
| Checklist    | Total | Completed | Incomplete | Status |
|--------------|-------|-----------|------------|--------|
| ux.md        | 12    | 12        | 0          | PASS   |
| test.md      | 8     | 5         | 3          | FAIL   |
| security.md  | 6     | 6         | 0          | PASS   |
```

### 11.4 AI 協作規則（重要）

| AI 可以做 | AI 不可以做 |
|-----------|-------------|
| 產生程式碼 | 自動執行 git commit |
| 建議 commit message | 自動執行 git push |
| 解釋程式碼 | 自動合併 PR |
| 產生測試 | 跳過人工審查 |

**工作流程**：AI 產生程式碼草稿與說明，人工負責審查、執行 `git add/commit`，以及決定是否 push。

### 11.5 實作品質要求

| 項目 | 要求 |
|------|------|
| 程式碼風格 | 符合 linter 規則 |
| 測試覆蓋 | 每個 FR 至少一個測試 |
| 錯誤處理 | 每個 edge case 都要處理 |
| 文件 | 複雜邏輯需要註解 |

---

## 補充：可選的 Workflow Runtime（Wave 3）

七階段流程的 canonical 驅動方式仍然是 agent prompt + setup-*.ps1 entry gate。Wave 3 引入額外的可選編排層 `studio/workflows/sdd-pipeline/`，把這條鏈寫成單一可宣告 / 可驗證 / 可恢復的 yaml workflow。

它**不取代**七階段：

- 七階段語意仍由 constitution Section 2、agent prompt、stage-entry gate 強制。
- workflow runtime 只做 orchestration：順序、readiness 8 種 status 的 switch 路由、ECI 3 種 authorization outcome 的 nested switch、gate halt、agent halt 的 RunState persistence。

進階使用見 `studio/QUICKSTART.md` 的「Optional: Workflow Runtime」段、`studio/workflows/POLICY.md` 與 `studio/workflows/sdd-pipeline/docs/README.md`。

---

## 12. Git 工作流程

### 12.1 Branch Naming

格式：`<type>/<short-description>`

| Type | 用途 | 範例 |
|------|------|------|
| `feature/` | 新功能 | `feature/user-registration` |
| `fix/` | Bug 修復 | `fix/cart-calculation` |
| `docs/` | 文件更新 | `docs/api-documentation` |
| `refactor/` | 重構 | `refactor/payment-service` |
| `chore/` | 雜項 | `chore/update-dependencies` |

### 12.2 Commit Message Convention

格式（Conventional Commits + 繁體中文）：
```
<type>: <中文描述>

[optional body in zh-TW]
```

| Type | 用途 | 範例 |
|------|------|------|
| `feat` | 新功能 | `feat: 新增會員註冊 API` |
| `fix` | Bug 修復 | `fix: 修正驗證碼過期判斷` |
| `docs` | 文件 | `docs: 更新 API 文件` |
| `refactor` | 重構 | `refactor: 重構驗證邏輯` |
| `test` | 測試 | `test: 補充註冊失敗測試` |
| `chore` | 雜項 | `chore: 升級相依套件` |
| `style` | 格式 | `style: 修正縮排` |

### 12.3 Commit 頻率

| 情境 | 建議 |
|------|------|
| 完成一個 task | 立即 commit |
| 修改多個相關檔案 | 群組為一個邏輯 commit |
| 修復 typo | 可與下一個 commit 合併 |
| 大型重構 | 拆分為多個小 commit |

### 12.4 PR 流程

```
1. 完成所有 tasks
2. 執行 /speckit.analyze 確認一致性
3. 確保所有測試通過
4. 建立 PR
5. 填寫 PR template
6. 等待 review
```

---

## 13. 專案資料夾結構

### 13.1 標準結構

> **Canonical reference**: 憲章 §11 是 master table。本表為 informational 摘要，
> 若兩處衝突以 `studio/constitution/constitution.md` §11 為準。

| Path | Purpose |
|------|---------|
| `.specify/memory/constitution.md` | 專案憲章（可選） |
| `specs/<feature>/spec.md` | 功能規格 |
| `specs/<feature>/intent-ledger.md` | 核心意圖被 represented / deferred / dropped 時的 secondary artifact |
| `specs/<feature>/readiness/` | readiness assessment 與 remediation packet |
| `specs/<feature>/readiness/eci/` | ECI dossier |
| `specs/<feature>/plan.md` | 技術計畫 |
| `specs/<feature>/tasks.md` | 任務分解 |
| `specs/<feature>/research.md` | 技術調研（可選） |
| `specs/<feature>/data-model.md` | 資料模型（可選） |
| `specs/<feature>/contracts/` | API 契約（可選） |
| `specs/<feature>/checklists/` | 品質檢查清單（可選） |
| `specs/_discovery/` | Discovery 暫存區 |
| `src/` | 原始碼 |
| `tests/` | 測試 |
| `docs/` | 文件 |
| `README.md` | 專案說明 |

### 13.2 實際範例（參考 duotify-membership-v1）

| Path | Purpose |
|------|---------|
| `specs/001-member-registration/spec.md` | 會員註冊規格 |
| `specs/001-member-registration/plan.md` | 技術計畫 |
| `specs/001-member-registration/tasks.md` | 任務分解 |
| `specs/001-member-registration/analyze-02.md` | 第二次一致性分析 |
| `src/DuotifyMembership.Api/` | Web API 層 |
| `src/DuotifyMembership.Core/` | 核心業務邏輯 |
| `src/DuotifyMembership.Infrastructure/` | 資料存取層 |
| `tests/DuotifyMembership.UnitTests/` | 單元測試 |
| `tests/DuotifyMembership.IntegrationTests/` | 整合測試 |

### 13.3 多功能專案結構

```
project-root/
  .specify/
    memory/
      constitution.md        # 專案憲章
  specs/
    _discovery/              # Discovery 暫存
      user-auth-discovery.md
    001-user-registration/   # 第一個功能
      spec.md
      intent-ledger.md       # 只有在 scope compression 影響核心意圖時才建立
      readiness/
        readiness-assessment.md
        eci/
          eci-assessment.md
          source-manifest.md
          adoption-record.md
          authorization-record.md
      plan.md
      tasks.md
    002-payment-flow/        # 第二個功能
      spec.md
      intent-ledger.md       # 只有在 scope compression 影響核心意圖時才建立
      readiness/
        readiness-assessment.md
        eci/
          eci-assessment.md
          source-manifest.md
          adoption-record.md
          authorization-record.md
      plan.md
      tasks.md
  src/
    ...
  tests/
    ...
  README.md
```

---

## 14. 常見陷阱與解決方案

### 14.1 需求階段陷阱

| 陷阱 | 症狀 | 解決方案 |
|------|------|----------|
| 需求太模糊 | spec 中充滿「快速」「友善」 | 強制量化每個形容詞 |
| 跳過 discover | 做完才發現做錯方向 | 有模糊想法時先 discover |
| Edge cases 太少 | 上線後 bug 不斷 | 強制至少 3 個 edge cases |
| Out of scope 不明確 | 範圍蔓延 | 明確列出「不做什麼」 |

### 14.2 規劃階段陷阱

| 陷阱 | 症狀 | 解決方案 |
|------|------|----------|
| 過度設計 | plan 比 spec 還長 | plan 只寫「怎麼做」，不寫「做什麼」 |
| 技術選型無理由 | 被問「為什麼用這個」答不出來 | 每個決策都要有 rationale |
| 不記錄 Why Not | 重複評估被拒絕的方案 | 記錄考慮過但不採用的原因 |
| 忽略風險 | 專案延期 | 主動識別並記錄風險 |

### 14.3 實作階段陷阱

| 陷阱 | 症狀 | 解決方案 |
|------|------|----------|
| Task 太粗 | 一個 task 做 3 天還沒完成 | 拆分到 0.5-2 天粒度 |
| 不更新文件 | 實作與文件不一致 | 改 code 前先改 tasks.md |
| 跳過測試 | 上線後 bug | 每個 FR 至少一個測試 |
| 累積大量改動 | commit 太大無法 review | 每個 task 完成就 commit |

### 14.4 協作階段陷阱

| 陷阱 | 症狀 | 解決方案 |
|------|------|----------|
| 術語不一致 | spec 說「使用者」，plan 說「會員」 | 建立詞彙表，統一用語 |
| 文件衝突 | spec 和 plan 描述不同 | 執行 analyze 檢查一致性 |
| 不做 code review | 品質參差不齊 | 所有 PR 都要 review |
| 不更新 learnings | 重複犯相同錯誤 | 專案完成後立即更新 |

---

## 15. 給初階 AI 工程師的建議

### 15.1 心態調整

| 錯誤心態 | 正確心態 |
|----------|----------|
| 先寫 code，文件之後補 | 文件就是設計，code 只是執行 |
| AI 會幫我做完 | AI 是助手，我要審查每行程式碼 |
| 趕時間就跳過 clarify | clarify 的時間投資會省下 10 倍返工 |
| 文件寫越詳細越好 | 文件寫剛好夠用，太多反而是負擔 |

### 15.2 時間分配建議

| 階段 | 時間佔比 | 說明 |
|------|----------|------|
| Discover + Specify | 25% | 需求做對比做快重要 |
| Clarify + Readiness + Plan | 25% | 先確認前提充足，再做技術設計 |
| Tasks + Analyze | 10% | 規劃可平行執行 |
| Implement | 40% | 有好的前置工作，實作會很快 |

### 15.3 與 AI Agent 協作技巧

| 技巧 | 說明 |
|------|------|
| 給足夠的 context | 附上相關檔案，AI 才能做出好的判斷 |
| 分步驟執行 | 不要一次叫 AI 做完全部，一步一步確認 |
| 審查每個輸出 | AI 會幻覺，永遠要驗證 |
| 善用 handoffs | Agent 之間可以傳遞 context |
| 質疑不合理的建議 | 如果 AI 的建議看起來怪怪的，追問原因 |

### 15.4 持續改進

專案完成後：
1. 更新 `studio/knowledge-base/learnings.md`
2. 記錄「這次學到什麼」
3. 記錄「下次可以改進什麼」
4. 如果發現好的模式，考慮提取到 `studio/prompts/`

---

## 16. 快速啟動 Checklist

### 16.1 專案啟動前

```
[ ] VS Code 1.107+ 已安裝
[ ] GitHub Copilot Chat 已啟用
[ ] Custom Agents 已載入
[ ] settings.json 已配置 SDD 優化設定
[ ] 已閱讀 Studio Constitution
[ ] 已閱讀本指南
```

### 16.2 SDD 流程

```
[ ] 執行 /speckit.discover（可選）
    [ ] 完成 Phase 1（4 題）
    [ ] 完成 Phase 2（3 題）
    [ ] 確認 discovery.md 已產生

[ ] 執行 /speckit.specify
    [ ] 確認 feature branch 已建立
    [ ] 確認 spec.md 已產生
    [ ] 確認至少 3 個 edge cases
    [ ] 確認無模糊用語

[ ] 執行 /speckit.clarify
    [ ] 回答所有 Critical/High 問題
    [ ] 確認 spec.md 已更新

[ ] 執行 /speckit.readiness
    [ ] 確認 readiness/readiness-assessment.md 已產生
    [ ] 若 status = READY_FOR_PLAN，才進入 /speckit.plan
    [ ] 若核心 spec 項目被 represented / deferred / dropped，確認 `intent-ledger.md` 已建立或更新
    [ ] 若 status = ROUTE_TO_ECI，完成 eci-trigger.md、執行 /speckit.eci 產出 dossier 後回跑 /speckit.readiness
    [ ] 若 ECI 僅授權 sandbox / spike，補對應的 validation/access/decision packet 後再回跑 /speckit.readiness，不得直接進 /speckit.plan

[ ] 執行 /speckit.plan
    [ ] 確認 plan.md 已產生
    [ ] 確認所有技術決策有 rationale
    [ ] 若存在 `intent-ledger.md`，確認 `Intent Recovery Obligations` 已承接 represented / deferred 項目與 re-entry trigger
    [ ] 確認有 "Why Not" 章節

[ ] 執行 /speckit.tasks
    [ ] 確認 tasks.md 已產生
    [ ] 確認每個 task 有 DoD
    [ ] 確認任務粒度在 0.5-2 天

[ ] 執行 /speckit.analyze
    [ ] 確認無 CRITICAL 問題
    [ ] 確認 `Intent Drift Check` 通過
    [ ] 修復所有 WARNING（或記錄為已知風險）

[ ] 執行 /speckit.implement
    [ ] 審查每個 AI 產生的程式碼
    [ ] 每個 task 完成後 commit
    [ ] 所有測試通過
    [ ] 建立 PR
```

### 16.3 專案完成後

```
[ ] 更新 studio/knowledge-base/learnings.md
[ ] 記錄學到的經驗
[ ] 記錄可改進的地方
[ ] 考慮提取可重用的 prompt
```

---

## 17. 附錄：文件模板

除了本附錄中的三個主模板片段外，`studio/templates/sdd-docs/` 也提供
`intent-ledger`、`readiness-assessment`、`eci-trigger`、`eci-assessment`、`eci-source-manifest`、
`eci-adoption-record`、`eci-authorization-record`、`repo-context-packet`、`decision-record`、
`validation-contract`、`access-setup-checklist` 與 `exploration-boundary` 模板。

### 17.1 spec.md 模板

```markdown
# Specification: [功能名稱]

**Version**: 1.0.0
**Created**: YYYY-MM-DD
**Last Updated**: YYYY-MM-DD

## Problem / Goal

[描述為什麼要做這個功能，解決什麼問題]

## Actors

| Actor | Description |
|-------|-------------|
| [角色1] | [角色描述] |
| [角色2] | [角色描述] |

## User Scenarios

### US-001: [場景名稱] [P1]

**作為** [角色]
**我想要** [行為]
**以便於** [目的]

**Acceptance Criteria**:
1. [條件1]
2. [條件2]

**Priority**: P1 (Must Have) / P2 (Should Have) / P3 (Nice to Have)

## Edge Cases

| ID | Description | Expected Behavior |
|----|-------------|-------------------|
| EC-001 | [邊界情況描述] | [預期行為] |
| EC-002 | [邊界情況描述] | [預期行為] |
| EC-003 | [邊界情況描述] | [預期行為] |

## Functional Requirements

| ID | Requirement | Priority | Story |
|----|-------------|----------|-------|
| FR-001 | [需求描述] | P1 | US-001 |
| FR-002 | [需求描述] | P1 | US-001 |

## Non-Functional Requirements

| ID | Requirement | Metric |
|----|-------------|--------|
| NFR-001 | [需求描述] | [具體指標] |

## Success Criteria

- [可量測的成功標準1]
- [可量測的成功標準2]

## Out of Scope

- [明確排除項目1]
- [明確排除項目2]

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | YYYY-MM-DD | Initial version |
```

### 17.2 plan.md 模板

```markdown
# Implementation Plan: [功能名稱]

**Version**: 1.0.0
**Created**: YYYY-MM-DD
**Spec Reference**: [spec.md 路徑]

## Technical Context

| Category | Choice |
|----------|--------|
| Language | [語言] |
| Framework | [框架] |
| Database | [資料庫] |
| Testing | [測試框架] |

## Intent Recovery Obligations

| Source Intent Item | Current Representation | Why Not This Iteration | Re-entry Trigger | Coverage Disclosure Needed |
|--------------------|------------------------|------------------------|------------------|----------------------------|
| [項目或 `None`] | [目前代表方式 / `N/A`] | [原因] | [具體條件 / `N/A`] | [README / quickstart / analyze / `No`] |

## Architecture Overview

[用文字描述系統架構]

## Technology Decisions

### TD-001: [決策標題]

**選擇**: [選擇的技術/方案]

**理由**:
1. [理由1]
2. [理由2]

**替代方案考量**:
- [方案A]: [為什麼不選]
- [方案B]: [為什麼不選]

## Project Structure

| Path | Purpose |
|------|---------|
| `src/` | [用途說明] |
| `tests/` | [用途說明] |

## Data Flow

[描述資料從輸入到輸出的流程]

## Constraints and Risks

| Type | Description | Mitigation |
|------|-------------|------------|
| Constraint | [限制描述] | [應對方式] |
| Risk | [風險描述] | [緩解措施] |

## Estimated Timeline

| Phase | Tasks | Days |
|-------|-------|------|
| Setup | [概述] | X |
| Core | [概述] | X |
| Polish | [概述] | X |
| **Total** | | **X** |

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | YYYY-MM-DD | Initial version |
```

### 17.3 tasks.md 模板

```markdown
# Tasks: [功能名稱]

**Feature**: [功能簡稱]
**Branch**: [branch name]
**Generated**: YYYY-MM-DD
**Plan Reference**: [plan.md 路徑]

## Summary

| Metric | Value |
|--------|-------|
| Total tasks | X |
| Estimated duration | X days |
| Highest priority | P1 |
| Highest risk | High |

---

## Canonical Task List

- [ ] T001 [P1] [Risk: Low] [Story: N/A] [任務標題]
  - Depends on: None
  - DoD: [完成條件1]；[完成條件2]

- [ ] T002 [P1] [Risk: Medium] [Story: US-001] [任務標題]
  - Depends on: T001
  - DoD: [完成條件1]；[完成條件2]

- [ ] T003 [P2] [Risk: High] [Story: US-002] [任務標題]
  - Depends on: T001, T002
  - DoD: [完成條件1]；[完成條件2]

---

## Dependency Guide

| Task | Depends on | Notes |
|------|------------|-------|
| T001 | None | 基礎建設或前置準備 |
| T002 | T001 | 第一個功能任務 |
| T003 | T001, T002 | 需要前一批功能完成後再做 |
```

---

## 版本歷史

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-12-12 | Initial version |

---

> **注意**：本指南會隨著 SDD 實踐經驗持續更新。如有建議或發現問題，請更新 `studio/knowledge-base/learnings.md`。
