# SDD 工作室快速開始指南

本指南說明 studio-first Spec Kit 工作區的最短上手路徑。

## 建立新專案

### Practice

```powershell
.\studio\scripts\powershell\init-practice.ps1 -Name "my-demo"
.\studio\scripts\powershell\init-practice.ps1 -Name "chatbot-demo" -Description "LINE Bot 聊天機器人練習"
```

### Internal / Client

```powershell
.\studio\scripts\powershell\init-project.ps1 -Name "studio-automation" -Type Internal
.\studio\scripts\powershell\init-project.ps1 -Name "2025-client-x" -Type Client -Description "電商平台開發"
```

### 開啟方式

建立專案後，使用產生的 `.code-workspace` 檔案開啟：

```powershell
code learning/my-demo/my-demo.code-workspace
code projects/studio-automation/studio-automation.code-workspace
```

`.code-workspace` 會掛入以下資料夾：

| 資料夾 | 存取權限 | 用途 |
|--------|----------|------|
| `<project-name>` | 可編輯 | 專案程式碼與文件 |
| `studio (read-only)` | 唯讀 | constitution、templates、scripts |
| `agents (read-only)` | 唯讀 | workspace runtime agents |
| `claude agents (read-only)` | 唯讀 | workspace Claude runtime agents |

每個專案也會建立 `.github/agents/` junction，來源是 workspace 根目錄的
`.github/agents/`。這是 runtime source。
每個專案也會建立 `.claude/agents/` junction，來源是 workspace 根目錄的 `.claude/agents/`。
`/.claude/agents/` 是 Claude shared runtime source of truth。Claude skills 與 shared agents runtime 是不同層。

### 專案類型

| 類型 | 目標目錄 | SDD 嚴謹度 | 知識記錄 |
|------|----------|------------|----------|
| `Practice` | `learning/` | 完整七階段 | 更新 `studio/knowledge-base/learnings.md` |
| `Internal` | `projects/` | 完整七階段 | `retrospective.md` 必要 |
| `Client` | `projects/` | 完整七階段加審核門檻 | `retrospective.md` 必要 |

## 七階段工作流程

所有交付工作都必須依序執行：

1. `/speckit.specify`
2. `/speckit.clarify`
3. `/speckit.readiness`
4. `/speckit.plan`
5. `/speckit.tasks`
6. `/speckit.analyze`
7. `/speckit.implement`

補充規則：

- `/speckit.discover` 是可選的 pre-spec 輔助步驟。
- `/speckit.checklist`、`/speckit.constitution`、`/speckit.taskstoissues` 是輔助命令。
- `/speckit.eci` 是 `ROUTE_TO_ECI` 的專用 shared runtime command，不是固定主流程階段。
- `/speckit.readiness` 是 plan 前的治理閘門；沒有 `READY_FOR_PLAN` 就不得進入 `/speckit.plan`。
- 若核心 spec 項目因 representative subset、defer 或正式 drop 而被壓縮，`/speckit.readiness` 必須要求建立或更新 `specs/<feature>/intent-ledger.md`；這是 secondary artifact，不是新的 stage。
- external capability 問題在 `ROUTE_TO_ECI` 時必須透過 `/speckit.eci` 處理，`eci-trigger.md` 是 intake seed，正式 dossier 會寫入 `readiness/eci/`。
- `/speckit.eci` 完成後仍必須回到 `/speckit.readiness`；只有最新 readiness 狀態是 `READY_FOR_PLAN` 才能進 `/speckit.plan`。
- 若 ECI 只授權 sandbox / spike，readiness 應轉判成 `ROUTE_TO_VALIDATION`、`ROUTE_TO_ACCESS` 或 `ROUTE_TO_DECISION` 等次級 blocker，而不是重複 `ROUTE_TO_ECI`。
- 若存在 `intent-ledger.md`，`plan.md` 必須承接 `Intent Recovery Obligations`，`/speckit.analyze` 必須檢查是否出現 intent drift 與對外 coverage 誤導。

各階段主要產物：

| 階段 | 主要產物 | 重點 |
|------|----------|------|
| `specify` | `spec.md` | 需求、邊界、edge cases、success criteria |
| `clarify` | 更新後的 `spec.md` | 消除模糊與缺口 |
| `readiness` | `readiness/readiness-assessment.md` | 判斷是否可安全進入規劃，必要時輸出 remediation packet |
| `plan` | `plan.md` | 技術決策、風險、contracts、data flow |
| `tasks` | `tasks.md` | checklist-first 任務分解 |
| `analyze` | 分析結果 | 驗證 spec、intent-ledger、plan、tasks 與對外說明是否一致 |
| `implement` | `src/`, `tests/` | 嚴格依 tasks 實作 |

補充：`intent-ledger.md` 不是新的流程階段；它只在核心 spec 項目被 represented、deferred 或 dropped 時作為 secondary artifact 出現。

`tasks.md` 的 canonical task line 格式如下：

```text
- [ ] T001 [P1] [Risk: Low] [Story: Foundation] 建立專案基礎結構
```

## 常用指令

| 類別 | 指令 | 用途 |
|------|------|------|
| 初始化 | `init-practice.ps1 -Name <name>` | 建立 Practice 專案 |
| 初始化 | `init-project.ps1 -Name <name> -Type Internal` | 建立 Internal 專案 |
| 初始化 | `init-project.ps1 -Name <name> -Type Client` | 建立 Client 專案 |
| 主流程 | `/speckit.specify <描述>` | 建立規格 |
| 主流程 | `/speckit.clarify` | 釐清需求 |
| 主流程 | `/speckit.readiness` | 進行前規劃 readiness triage |
| 支線 | `/speckit.eci` | 處理 `ROUTE_TO_ECI` 的 external capability governance |
| 主流程 | `/speckit.plan` | 產生技術計畫 |
| 主流程 | `/speckit.tasks` | 產生任務分解 |
| 主流程 | `/speckit.analyze` | 一致性分析 |
| 主流程 | `/speckit.implement` | 開始實作 |
| 輔助 | `/speckit.discover` | 前置 discovery |
| 輔助 | `/speckit.checklist <domain>` | 產生檢查清單 |
| 輔助 | `/speckit.constitution` | 更新專案憲章 |
| 輔助 | `/speckit.taskstoissues` | 轉 GitHub Issues |

## 專案結構

| Path | Purpose |
|------|---------|
| `.specify/memory/constitution.md` | 專案層級 canonical constitution |
| `.claude/agents/` | Claude shared runtime junction |
| `.github/copilot-instructions.md` | GitHub Copilot 專案 context，不是 constitution |
| `CLAUDE.md` | Claude 專案 context，不是 constitution |
| `specs/<feature>/spec.md` | 規格文件 |
| `specs/<feature>/intent-ledger.md` | 僅在核心意圖被 represented / deferred / dropped 時建立的 secondary artifact |
| `specs/<feature>/readiness/` | readiness assessment 與 route packet |
| `specs/<feature>/readiness/eci/` | ECI dossier |
| `specs/<feature>/plan.md` | 技術計畫 |
| `specs/<feature>/tasks.md` | 任務分解 |
| `specs/<feature>/contracts/` | Markdown 或 machine-readable contracts |
| `src/` | 原始碼 |
| `docs/` | 文件 |
| `README.md` | 專案說明與 project type 宣告 |
| `retrospective.md` | Internal / Client 專案回顧 |

## 雙層憲章

優先順序如下：

1. `studio/constitution/constitution.md`
2. `<project>/.specify/memory/constitution.md`
3. 專案 agent context 檔案，例如 `.github/copilot-instructions.md` 與 `CLAUDE.md`

Project Constitution 可以：

- 新增專案術語與限制
- 定義更嚴格的測試或文件要求

Project Constitution 不可以：

- 跳過任何 SDD 階段
- 放寬 Studio Constitution 規則

## 知識管理

Practice 專案完成後，更新 `studio/knowledge-base/learnings.md`：

```markdown
## [2025-12-08] Project: my-demo
### Learned
- 學到的重點
### Pain Points
- 遇到的問題
### Prompt Candidates
- [ ] <描述> (target: `studio/prompts/<stage>/`)
```

Internal / Client 專案完成後：

1. 完成 `retrospective.md`
2. 將重要學習同步到 `studio/knowledge-base/learnings.md`
3. 評估是否需要提取 prompt、template 或 workflow 規則

完成每個專案後檢查：

- [ ] 有可重用的 prompt，提取到 `studio/prompts/<stage>/`
- [ ] 有可重用的 template 段落，提取到 `studio/templates/`
- [ ] 有值得記錄的 pattern，寫入 `learnings.md`

## 常見問題

### 我可以跳過某個 SDD 階段嗎？

不行。七階段是強制流程。

### 如果需求中途變更怎麼辦？

依序更新 `spec.md`、`intent-ledger.md`（若受影響）、`readiness/*.md`、`readiness/eci/*.md`、`plan.md`、`tasks.md`，並在受影響文件上遞增版本號。

若 feature 名稱比當前交付能力更寬，而本輪只做 representative subset，`README.md`、`quickstart.md` 與 analyze 結論必須揭露目前 coverage 與 known gaps。

### 如何啟用 Git hooks？

```powershell
git config core.hooksPath .githooks
```

### 如何驗證 shared runtime？

使用 `check-speckit-runtime.ps1` 作為 shared-layer 的主要驗證腳本：

```powershell
.\studio\scripts\powershell\check-speckit-runtime.ps1 -Json
```

shared-layer convergence 的主要驗收方式是 studio runtime audit，不是要求同步治理 consumer project artifacts。

## 下一步

1. 建立一個新專案。
2. 準備 feature 描述。
3. 從 `/speckit.specify` 開始。
4. 完成 `/speckit.clarify` 後執行 `/speckit.readiness`。
5. 完成後更新 learnings 或 retrospective。
