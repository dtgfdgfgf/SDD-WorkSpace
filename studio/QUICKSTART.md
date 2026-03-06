# SDD 工作室快速開始指南

本指南幫助你快速上手 Specification-Driven Development (SDD) 工作流程。

## 目錄

- [建立新專案](#建立新專案)
- [SDD 六階段工作流程](#sdd-六階段工作流程)
- [常用指令速查](#常用指令速查)
- [專案結構說明](#專案結構說明)
- [知識管理](#知識管理)

---

## 建立新專案

### Practice 專案（學習/練習）

```powershell
# 建立 Practice 專案到 learning/ 目錄
.\studio\scripts\powershell\init-practice.ps1 -Name "my-demo"

# 含描述
.\studio\scripts\powershell\init-practice.ps1 -Name "chatbot-demo" -Description "LINE Bot 聊天機器人練習"
```

### Internal/Client 專案

```powershell
# 建立 Internal 專案（工作室內部工具）
.\studio\scripts\powershell\init-project.ps1 -Name "studio-automation" -Type Internal

# 建立 Client 專案（付費客戶專案）
.\studio\scripts\powershell\init-project.ps1 -Name "2025-client-x" -Type Client -Description "電商平台開發"
```

### 開啟專案（Multi-Root Workspace）

建立專案後，使用產生的 `.code-workspace` 檔案開啟：

```powershell
# 開啟 Internal/Client 專案
code projects/studio-automation/studio-automation.code-workspace

# 開啟 Practice 專案
code learning/my-demo/my-demo.code-workspace
```

**為什麼用 .code-workspace？**

| 資料夾 | 存取權限 | 用途 |
|--------|----------|------|
| `<project-name>` | 可編輯 | 專案程式碼和文件 |
| `studio (read-only)` | 唯讀 | Constitution、templates、prompts |
| `agents (read-only)` | 唯讀 | GitHub Copilot agents（參考用） |

**Junction 機制**

每個專案會自動建立 `.github/agents/` Junction（指向 workspace），讓 VS Code 能正常發現所有 agents：

```
<project>/.github/agents/  →  Junction  →  workspace/.github/agents/
```

所有 SDD agents（speckit.specify, clarify, plan 等）都集中在 `workspace/.github/agents/`，專案可直接使用 `/speckit.*` 指令。

### 專案類型比較

| 類型 | 目標目錄 | SDD 嚴謹度 | 知識記錄 |
|------|----------|------------|----------|
| **Practice** | `learning/` | 完整 SDD 流程 | `learnings.md` (輕量) |
| **Internal** | `projects/` | 完整 SDD 流程 | `retrospective.md` (必要) |
| **Client** | `projects/` | 完整 SDD + 客戶審核門檻 | `retrospective.md` (必要) |

---

## SDD 六階段工作流程

SDD 流程必須依序執行：

1. **specify** — Create initial specification
2. **clarify** — Resolve ambiguities
3. **plan** — Produce technical plan
4. **tasks** — Create task decomposition
5. **analyze** — Validate cross-document consistency
6. **implement** — Execute implementation

### ① Specify（規格撰寫）

```
/speckit.specify 我想建立一個使用者登入系統，支援 Email 和 Google OAuth
```

**產出**：`specs/<feature>/spec.md`

**必要章節**：Problem/Goal、Actors、Scenarios、FR、NFR、Edge Cases (≥3)、Success Criteria、Out of Scope

### ② Clarify（釐清模糊）

```
/speckit.clarify
```

**目的**：移除模糊定義、確認邊界、補充遺漏細節

**產出**：更新後的 `spec.md`（標註 Clarified 章節）

### ③ Plan（技術規劃）

```
/speckit.plan
```

**產出**：`specs/<feature>/plan.md`

**必要章節**：Architecture、Tech Decisions (含 Why Not)、Integration Points、Data Flow、Risks、Timeline

### ④ Tasks（任務分解）

```
/speckit.tasks
```

**產出**：`specs/<feature>/tasks.md`

**格式要求**：
- 粒度：0.5-2 天/任務
- 必須有 Definition of Done
- 明確依賴關係
- Risk Level (Low/Medium/High)
- Priority (P1/P2/P3)

### ⑤ Analyze（一致性檢查）

```
/speckit.analyze
```

**目的**：驗證 spec ↔ plan ↔ tasks 之間的一致性

**結果分類**：
- Critical → **必須** 修正才能繼續
- Major → **應該** 修正
- Minor → 可選

### ⑥ Implement（實作）

```
/speckit.implement
```

**規則**：
- 嚴格依照 tasks.md 執行
- 不得新增 spec 未定義的功能
- 任何變更必須更新 spec/plan/tasks 並遞增版本號

---

## 常用指令速查

### 專案初始化

| 指令 | 說明 |
|------|------|
| `init-practice.ps1 -Name <name>` | 建立 Practice 專案 |
| `init-project.ps1 -Name <name> -Type Internal` | 建立 Internal 專案 |
| `init-project.ps1 -Name <name> -Type Client` | 建立 Client 專案 |

### SDD 階段

| 指令 | 說明 |
|------|------|
| `/speckit.specify <描述>` | 建立新功能規格 |
| `/speckit.clarify` | 釐清模糊需求 |
| `/speckit.plan` | 產生技術計畫 |
| `/speckit.tasks` | 產生任務分解 |
| `/speckit.analyze` | 跨文件一致性檢查 |
| `/speckit.implement` | 開始實作 |

### 輔助指令

| 指令 | 說明 |
|------|------|
| `/speckit.checklist <domain>` | 產生領域檢查清單 |
| `/speckit.constitution` | 更新專案層級憲章 |
| `/speckit.taskstoissues` | 將 tasks 轉為 GitHub Issues |

---

## 專案結構說明

| Path | Purpose |
|------|--------|
| `.specify/memory/constitution.md` | 專案層級憲章（選用，只能比 Studio 更嚴格） |
| `specs/<feature>/spec.md` | 規格文件 |
| `specs/<feature>/plan.md` | 技術計畫 |
| `specs/<feature>/tasks.md` | 任務分解 |
| `src/` | 原始碼 |
| `docs/` | 文件 |
| `README.md` | 專案說明（含專案類型宣告） |
| `retrospective.md` | 回顧文件（Internal/Client 必要） |

---

## 知識管理

### Practice 專案完成後

更新 `studio/knowledge-base/learnings.md`：

```markdown
## [2025-12-08] Project: my-demo
### Learned
- 學到的重點...
### Pain Points
- 遇到的問題...
### Prompt Candidates
- [ ] <描述> → target: studio/prompts/<stage>/
```

### Internal/Client 專案完成後

1. 完成 `retrospective.md`
2. 重要學習同步到 `studio/knowledge-base/learnings.md`
3. 評估是否有可提取的 prompt 或 template

### 資產提取檢查

每個專案完成後問自己：

- [ ] 有可重用的 prompt？→ 提取到 `studio/prompts/<stage>/`
- [ ] 有可重用的範本段落？→ 提取到 `studio/templates/`
- [ ] 有值得記錄的 pattern？→ 已在 `learnings.md`

---

## 雙層憲章系統

**優先順序**：Studio Constitution (最高權限) > Project Constitution (選用，只能更嚴格)

- **Studio Constitution**：`studio/constitution/constitution.md`
- **Project Constitution**：`<project>/.specify/memory/constitution.md`

Project Constitution **可以**：
- 新增專案特定術語
- 定義更嚴格的規則

Project Constitution **不可以**：
- 跳過任何 SDD 階段
- 放寬 Studio Constitution 規則

---

## 常見問題

### Q: 我可以跳過某個 SDD 階段嗎？

**不行。** 所有階段必須依序完成，這是 Constitution 的強制規定。

### Q: 如果需求中途變更怎麼辦？

更新 spec.md → plan.md → tasks.md，並遞增版本號（如 v1.0.0 → v1.1.0）。

### Q: Practice 和 Internal 專案有什麼差別？

- **Practice**：學習用，知識記錄輕量
- **Internal**：正式工具，需要完整 retrospective

### Q: 如何啟用 Git Hooks 驗證？

```powershell
git config core.hooksPath .githooks
```

---

## 下一步

1. 建立你的第一個 Practice 專案
2. 用自然語言描述你想建立的功能
3. 跟隨 SDD 六階段完成開發
4. 完成後更新 `learnings.md`


