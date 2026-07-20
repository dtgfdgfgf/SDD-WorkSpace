# SDD-WorkSpace

[![Governance CI](https://github.com/dtgfdgfgf/SDD-WorkSpace/actions/workflows/governance.yml/badge.svg?branch=main)](https://github.com/dtgfdgfgf/SDD-WorkSpace/actions/workflows/governance.yml)

一個以 Specification-Driven Development (SDD) 為核心的 studio-first 工作區，目標是把個人 AI 工程實踐、共享治理、專案初始化、知識回饋與 AI agent runtime 集中在同一個 workspace 內管理。

這個 repo 不是單一產品專案，而是整個 SDD 工作室的基礎設施。`studio/` 放 canonical sources，`.github/` 放 Copilot runtime assets，`.claude/` 放 Claude runtime assets，`learning/` 與 `projects/` 放實際練習和交付專案。

## 環境需求

- PowerShell 7 或更新版本，命令名稱為 `pwsh`
- `powershell-yaml` 0.4.12（shared runtime audit 與 workflow YAML 驗證）
- Pester 5.7.1（governance test suite）
- Git
- VS Code 與 GitHub Copilot Chat（使用互動式 agent workflow 時）

Governed text files use UTF-8 without BOM and LF line endings. `.gitattributes` defines the Git
normalization boundary, while `.editorconfig` keeps compatible editors aligned before commit.

可用 `pwsh --version` 確認版本。本 repo 的 shared PowerShell 腳本不支援 Windows PowerShell 5.1；請以 `pwsh ./studio/scripts/powershell/<script>.ps1` 形式執行。

```powershell
pwsh -NoProfile -Command "Install-Module powershell-yaml -RequiredVersion 0.4.12 -Scope CurrentUser -Force"
pwsh -NoProfile -Command "Install-Module Pester -RequiredVersion 5.7.1 -Scope CurrentUser -Force"
```

## 為什麼有這個 repo

這個 workspace 的設計重點是：

- 用一套固定的 SDD 七階段流程管理所有專案
- 將 studio-level 規則與 project-level 規則拆成雙層憲章
- 把共享 agent、prompt、template、extension 與初始化腳本集中管理
- 讓練習專案與正式專案都能吃到同一套 studio 能力
- 保留知識回饋機制，把實作痛點沉澱成 learnings、templates、prompts 或 governance 規則

目前這個工作區仍偏向練習與方法論建立階段，重點不是大量接案，而是先把 SDD workflow、專案骨架與 AI 協作流程打穩。

## 核心模型

### 1. Studio-first

共享能力集中在 workspace 根層與 `studio/`：

- `studio/constitution/constitution.md` 是最高權限治理文件
- `.github/agents/` 與 `.github/prompts/` 是 Copilot runtime source of truth
- `.claude/agents/` 是 Claude shared runtime source of truth
- `studio/templates/` 提供專案初始化與 SDD 文件模板
- `studio/scripts/powershell/` 提供初始化、同步、匯出與維護腳本
- `studio/extensions/` 是共享 extension registry

### 2. Dual-layer constitutions

規則分兩層：

- Studio Constitution: `studio/constitution/constitution.md`
- Project Constitution: `<project>/.specify/memory/constitution.md`

專案憲章只能加嚴，不能放寬 studio 規則。

### 3. Shared runtime, local projects

專案本身放在 `learning/` 或 `projects/`，但會透過 shared runtime 吃到工作區的共享資產，例如：

- `.github/agents/` junction
- `<project>/.claude/agents` junction
- workspace-level Copilot instructions
- studio templates
- shared extension registry

新建的 consumer project 預設是獨立 Git repo；初始化腳本會在 project root 執行 `git init -b main`，並將 `core.hooksPath` 設為指向 workspace `.githooks` 的相對路徑。這讓 project repo 可以套用同一套 machine-enforced governance gates，而不需要把 shared runtime 複製進專案。

目前 workspace 採 direct junction 模型提供 Claude shared agents，不支援 project-local Claude agents。

從 consumer project 派生出的 feature worktree，也必須保留這個 project 的同級操作語境，
不能只剩 Git tracked files。對 worktree parity 的正式規則，請以
`docs/project-worktree-parity-governance.md` 為準。

## 目錄總覽

| Path | Purpose |
|------|---------|
| `.github/agents/` | 共享 SDD runtime agents |
| `.claude/agents/` | 共享 Claude runtime agents |
| `.github/prompts/` | 共享 prompt 資產 |
| `studio/constitution/` | studio 級治理與方法論 |
| `studio/templates/` | 專案初始化與 SDD 文件模板 |
| `studio/scripts/powershell/` | 初始化、同步與維護腳本 |
| `studio/extensions/` | workspace 級 extension registry |
| `learning/` | Practice projects |
| `projects/` | Internal / Client / sample projects |
| `docs/project-governance-status.md` | 專案治理相容性中央台帳 |
| `resources/` | 共享資源與匯出產物 |
| `WORKSPACE_STRUCTURE.md` | 工作區結構設計說明 |

## 專案分類

| Type | Location | Purpose |
|------|----------|---------|
| Practice | `learning/` | 練習、示範、方法驗證 |
| Internal | `projects/` | studio tooling、內部工具、自用專案 |
| Client | `projects/` | 未來正式客戶專案 |

每個專案都應該有自己的 `README.md`、`specs/`、`src/`、`docs/`，以及必要時的 project constitution。
新專案也應有自己的 `.git/`，且 Git root 必須等於 project root；`/speckit.specify` 不會在 `projects/` 或 `learning/` 的 consumer project 中 silently fallback 成 non-git flow。
同一個專案派生出的 feature worktree 也應維持 project-equivalent operating surface，而不是 reduced checkout。

## SDD 工作流程

所有 project 與 consumer feature 的正式交付都遵循固定順序：

1. `/speckit.specify`
2. `/speckit.clarify`
3. `/speckit.readiness`
4. `/speckit.plan`
5. `/speckit.tasks`
6. `/speckit.analyze`
7. `/speckit.implement`

補充：

- 只有 contract 指定的 canonical workspace governance repo，且交付內容只限 shared-layer
  維護時，才可在實作前以 owner 授權的日期化計畫與 ledger IDs 進入 Studio Constitution
  2.1 的等效證據路徑。這不是跳階權限，也不適用 `projects/`、`learning/`、外部 repo 或
  一般 feature。
- 進入後必須維持 `Draft` 與 `NOT READY`，直到舊版失敗而新版通過的 negative tests、
  canonical audit、完整 governance suite，以及 `Ready`、`Closed` 的 Batch note 全部成立。
  Batch 完成不代表 Aggregate 可合併，也不能取代 R6 fresh-fixture E2E。
- `/speckit.discover` 是可選的 pre-spec discovery 階段
- `/speckit.checklist`、`/speckit.constitution`、`/speckit.taskstoissues` 是輔助命令
- `/speckit.eci` 是 `ROUTE_TO_ECI` 的專用 shared runtime command，不是固定主流程階段
- `/speckit.readiness` 是 `clarify` 與 `plan` 之間的前置治理閘門；只有 `READY_FOR_PLAN` 才能進入 `/speckit.plan`
- 當 readiness 因 representative subset、defer 或正式 drop 而壓縮核心 spec scope 時，必須建立或更新 `specs/<feature>/intent-ledger.md`；這是 secondary artifact，不是新的 stage
- 當 readiness 判為 `ROUTE_TO_ECI` 時，必須先執行 `/speckit.eci`，由 `eci-trigger.md` 啟動並在 `readiness/eci/` 產出正式 dossier，之後再回跑 `/speckit.readiness`
- 完成 `/speckit.eci` 不等於可以直接進 `/speckit.plan`；只有最新的 `readiness-assessment.md` 明確變成 `READY_FOR_PLAN` 才能進入規劃
- 若 ECI 的授權結果仍是 `READY_FOR_SANDBOX_ONLY` 或 `READY_FOR_SPIKE_ONLY`，下一步應由 `/speckit.readiness` 轉判成 `ROUTE_TO_VALIDATION`、`ROUTE_TO_ACCESS` 或 `ROUTE_TO_DECISION` 等次級 blocker，而不是機械式重做 ECI
- `plan.md` 若承接到 `intent-ledger.md`，必須有固定的 `Intent Recovery Obligations` 區段；`/speckit.analyze` 也必須做 `Intent Drift Check`
- 凡是準備合回 `main` 的 shared-layer 更新，必須在 `docs/mainline-updates/` 留下一份專門說明檔，並更新 `docs/mainline-updates/README.md` 索引

這個 repo 的治理假設是：spec 決定行為邊界、readiness 判斷前提是否足夠、`defer != disappear`、plan 決定技術方向、tasks 決定落地順序，implement 不應跳過前置文件直接做事。

## 快速開始

### 1. 先讀這些文件

- `studio/constitution/constitution.md`
- `WORKSPACE_STRUCTURE.md`
- `docs/mainline-updates/README.md`
- `studio/QUICKSTART.md`
- `studio/SDD-QUICKSTART-GUIDE.md`
- `AGENTS.md`
- `CLAUDE.md`
- `.github/copilot-instructions.md`

### 2. 啟用 Git hooks

```powershell
pwsh ./studio/scripts/powershell/setup-hooks.ps1
```

Workspace repo 使用上列命令。新建 consumer project 會由初始化腳本自動設定 hooks；既有 project repo 可用 `pwsh ./studio/scripts/powershell/setup-hooks.ps1 -ProjectRoot <project-root>` 補設定。

### 3. 建立新專案

Practice:

```powershell
pwsh ./studio/scripts/powershell/init-practice.ps1 -Name "my-demo"
```

Internal / Client:

```powershell
pwsh ./studio/scripts/powershell/init-project.ps1 -Name "studio-automation" -Type Internal
pwsh ./studio/scripts/powershell/init-project.ps1 -Name "2025-client-x" -Type Client
```

上述初始化腳本會建立 project-local Git repo、設定 workspace hooks、產生 runtime adapters，並建立 shared agent junction；不會自動建立 initial commit。

### 4. 使用產生的 `.code-workspace` 開啟專案

```powershell
code learning/my-demo/my-demo.code-workspace
code projects/studio-automation/studio-automation.code-workspace
```

## 共享資產與來源權威

以下是這個 workspace 內比較重要的 authority 邊界：

- Runtime source of truth: `.github/agents/`、`.github/prompts/`
- `.claude/agents/` 是 Claude shared runtime source of truth
- Canonical governance source: `studio/constitution/constitution.md`
- Canonical extension registry: `studio/extensions/`
- Generated skill pack exports: `resources/agent-skill-packs/`

Claude skills 與 `resources/agent-skill-packs/` 都屬於 install/export layer，不是 `/.claude/agents/` 的權威來源。

## Shared-Layer Convergence

- shared-layer convergence 的主要驗收方式是 `check-speckit-runtime.ps1`
- shared-layer convergence 的 DOD 只看 studio runtime、templates、docs、hooks 與 shared scripts
- `projects/` 與 `learning/` 是 consumer spaces，不是 shared-layer acceptance surface
- `readiness / eci` 的最終 shared-layer 收斂，以 `check-speckit-runtime.ps1 -Json` 為唯一 machine-verifiable acceptance source
- `docs/readiness_source/` 保留為 design reference，不屬於 canonical runtime acceptance surface
- studio runtime 變更的主要驗收方式是 studio runtime audit，而不是要求同步治理 consumer project artifacts

## 常用腳本

| Script | Purpose |
|--------|---------|
| `studio/scripts/powershell/init-practice.ps1` | 建立 Practice 專案、初始化 project-local Git repo 並設定 workspace hooks |
| `studio/scripts/powershell/init-project.ps1` | 建立 Internal / Client 專案、初始化 project-local Git repo 並設定 workspace hooks |
| `studio/scripts/powershell/setup-hooks.ps1` | 設定 workspace repo 或指定 project repo 的 `core.hooksPath` |
| `studio/scripts/powershell/create-new-feature.ps1` | 建立新 feature 工作區與文件骨架 |
| `studio/scripts/powershell/new-project-worktree.ps1` | 建立 consumer project derived worktree 並補齊 shared agent junction parity |
| `studio/scripts/powershell/check-speckit-runtime.ps1` | 驗證 shared runtime contract、mirror parity、templates、hooks 與 canonical docs |
| `studio/scripts/powershell/seed-claude-agents.ps1` | 從現有 Copilot shared agent surface seed workspace Claude shared agents |
| `studio/scripts/powershell/update-agent-context.ps1` | 更新 agent context / runtime 對齊 |

## 這個 workspace 期待的專案結構

每個專案至少應包含以下內容：

| Path | Purpose |
|------|---------|
| `.specify/memory/constitution.md` | 專案層級憲章 |
| `AGENTS.md` | Codex / Copilot CLI runtime adapter |
| `CLAUDE.md` | Claude Code runtime adapter |
| `.github/copilot-instructions.md` | Copilot runtime adapter |
| `specs/<feature>/spec.md` | 規格 |
| `specs/<feature>/intent-ledger.md` | 僅在核心意圖被 represented / deferred / dropped 時建立的 secondary artifact |
| `specs/<feature>/readiness/` | readiness assessment 與 route packet |
| `specs/<feature>/readiness/eci/` | ECI dossier |
| `specs/<feature>/plan.md` | 技術計畫 |
| `specs/<feature>/tasks.md` | 任務分解 |
| `src/` | 原始碼 |
| `docs/` | 文件 |
| `README.md` | 專案說明 |

若 feature 使用 umbrella 名稱，但本輪只交付 representative subset，`README.md`、`quickstart.md`、
以及 analyze 結論都必須揭露目前 coverage 與 known gaps，避免把已交付表面誤讀成原始完整意圖。

## 知識回饋

這個 repo 不只管理專案，也管理方法論演進。每做完一個專案，應該回看：

- 哪些痛點值得寫進 `learnings.md`
- 哪些 prompt 可以抽成共享資產
- 哪些模板段落可以提取到 `studio/templates/`
- 哪些 recurring friction 應該反映到 constitution 或 Copilot instructions

這也是這個 workspace 和一般單一產品 repo 最大的差異：它同時是交付場域，也是方法論與 AI 協作資產的孵化場。

## 延伸閱讀

- `WORKSPACE_STRUCTURE.md`
- `docs/project-governance-status.md`
- `docs/project-worktree-parity-governance.md`
- `studio/QUICKSTART.md`
- `studio/SDD-QUICKSTART-GUIDE.md`
- `studio/constitution/constitution.md`
- `spec-kit-upstream-wave2-transition-guide.md`
- `spec-kit-studio-first-upstream-usage-guide-2026-03-08.md`

## 授權 / License

除 `THIRD_PARTY_NOTICES.md` 所列第三方材料，以及另帶獨立授權或 notice 的檔案外，本
repository 的原創內容依 `LICENSE` 中的 MIT License 授權。第三方材料仍受其各自條款
約束；repository-level MIT License 不授予外部 runtime dependencies 或只存在於舊 Git
history 之第三方材料的權利。

Except for third-party materials identified in `THIRD_PARTY_NOTICES.md` and files that carry a
separate license or notice, the original content of this repository is licensed under the MIT
License. Third-party materials remain subject to their respective terms. The repository-level MIT
License does not grant rights in external runtime dependencies or in third-party material that
exists only in older Git history.
