# Studio 基礎設施挑戰報告

**Date:** 2026-04-12
**Reviewer:** Claude Opus 4.6 (independent audit)
**Scope:** Studio infrastructure only (excluding project spaces)

---

## 挑戰維度

四個維度：**治理效益**、**工程實踐**、**回饋迴圈**、**架構風險**。

---

## 1. 治理投入與產出嚴重失衡

**觀察到的事實：**

| Asset | Size |
|-------|------|
| `studio/constitution/constitution.md` | 530 lines |
| `studio/runtime/shared-runtime-contract.json` | 629 lines |
| `.githooks/pre-commit.ps1` | 776 lines |
| `studio/runtime/impact-registry.json` | 367 lines |
| PowerShell scripts (24 files) | 200KB+ total |

- 運營時間：2025-12 至今約 4 個月
- 總 commits：47 筆
- 平均不到每天半筆 commit

**挑戰：** 用了企業級的治理重量來管理一個 solo practice。大量精力花在「建設治理基礎設施」本身，而不是「被治理基礎設施加速的交付」。

**核心問題：** 如何量化這套系統帶來的加速效果？有沒有一個 feature 是「因為有這套系統，所以從 spec 到 implement 比沒有系統時更快、更少返工」的具體案例？如果沒有，這套系統目前可能是一個自我證明的循環 -- 系統產生了需要被管理的複雜性，然後系統再來管理這些複雜性。

---

## 2. 知識回饋迴圈完全空轉

**觀察到的事實：**

| Path | Status |
|------|--------|
| `studio/knowledge-base/learnings.md` | Empty (template only) |
| `studio/knowledge-base/pain-points/` | Empty directory |
| `studio/prompts/analyze/` | Empty directory |
| `studio/prompts/clarify/` | Empty directory |
| `studio/prompts/specify/` | Empty directory |
| `studio/prompts/implement/` | Empty directory |
| `studio/prompts/plan/` | Empty directory |
| `studio/prompts/tasks/` | Empty directory |

6 個 stage prompt 目錄全部空的。

**挑戰：** Constitution Section 13 明確要求 Knowledge Capture 是 mandatory。已經有 5 個專案有 `retrospective.md`，但 studio 級的 learnings 和 reusable prompts 完全沒有沉澱。README 說「這個 workspace 和一般 repo 最大的差異是它同時是交付場域，也是方法論與 AI 協作資產的孵化場」。但事實上孵化場是空的。

**核心問題：** 回饋迴圈不運轉，是因為流程太重所以沒有剩餘精力做回饋，還是因為回饋機制本身設計得太理想化而不實用？

---

## 3. 治理工具鏈本身零測試

**觀察到的事實：**

| Script | Size | Test Coverage |
|--------|------|---------------|
| `check-speckit-runtime.ps1` | 23KB | None |
| `common.ps1` | 32KB | None |
| `generate-impact-registry.ps1` | 24KB | None |
| `pre-commit.ps1` | 776 lines | None |

找不到任何 Pester 測試或其他測試框架。

**挑戰：** 用 pre-commit hook 來驗證 SDD 文件的結構正確性，但驗證邏輯本身沒有測試。`Get-EdgeCaseCount` 用 regex 來計算 edge case 數量 -- 如果 regex 漏判，spec.md 可以帶著不合格的 edge cases 通過 hook，永遠不會知道。

**核心問題：** 誰來治理治理工具本身？一個 bug 在 `check-speckit-runtime.ps1` 裡可以讓整個 shared runtime audit 產生 false positive，而沒有任何機制能捕捉這件事。

---

## 4. 三份 Agent Mirror = 三倍維護負債

**觀察到的事實：**

| Path | Role | File Count |
|------|------|------------|
| `.github/agents/` | source of truth | 16 |
| `.claude/agents/` | dependent, seeded | 15 |
| `studio/templates/sdd-agents/` | mirror | mirrors of above |

每次修改一個 agent 行為，理論上需要更新三個地方。`seed-claude-agents.ps1` 存在但是手動執行。

**挑戰：** `impact-registry.json` 把 `agent_change` 標記為 `.claude/agents/` = `must_update`、`studio/templates/sdd-agents/` = `must_update`。但同步是手動的，沒有 CI、沒有自動化 diff check。git status 顯示 `.claude/agents/` 下有 14 個 modified files -- 這些到底是「刻意的更新等待 commit」還是「已經 drift 但還沒人發現」？

**核心問題：** 三份 copy 的設計決策是否值得重新評估？例如 Claude agents 是否可以在 runtime 直接讀取 `.github/agents/` 而不需要維護一個 seeded copy？

---

## 5. 沒有 CI/CD -- 全靠本地 Hook

**觀察到的事實：**

- 無 `.github/workflows/` 目錄
- 無 GitHub Actions
- 所有驗證都依賴 `git config core.hooksPath .githooks`
- Hook 可以被 `--no-verify` 繞過

**挑戰：** 一個 `--no-verify` 就能讓所有治理失效。在 solo dev 場景下，自己就是最可能繞過 hook 的人。更重要的是，沒有 CI 代表：

1. 別人 clone 這個 repo 後不配置 hook 就沒有任何防護
2. 在不同機器上工作時可能忘記配置
3. 沒有 contract 驗證的歷史紀錄 -- 只知道「最後一次 commit 通過了」，不知道之前的 commit 是否也通過

**核心問題：** 為什麼選擇不建立 CI？如果是「practice 階段還不需要」，那 practice 階段也不需要 630 行的 runtime contract。兩者的投資等級不一致。

---

## 6. Windows Junction 模型的脆弱性

**觀察到的事實：**

- 專案透過 Windows NTFS junction 連接到 workspace 的 `.github/agents/` 和 `.claude/agents/`
- Junction 不跟 git，需要 init script 或 worktree script 重建
- Junction 在 WSL、Docker、macOS 上行為不同或不存在

**挑戰：** 如果未來要把這套工作室帶到另一台機器、另一個 OS、或者 cloud dev environment，junction model 是第一個會壞的東西。而且 junction 的狀態對 git 是不可見的 -- `git status` 不會告訴你 junction 斷了。

**核心問題：** 有沒有考慮過 symlink（可以跨平台、git 可追蹤）或者直接用 script 在 agent 載入時 resolve path？

---

## 7. Constitution 的版本聲稱與現實不符

**觀察到的事實：**

- Constitution Section 1.1：`**Current Phase:** Practice (as of 2025-12)`
- 實際狀態：`projects/Trading`、`Trading-002`、`Trading-003` 都是 Internal 類型的正式專案
- 這些專案有 `retrospective.md`，表示已經執行了 SDD 流程

**挑戰：** Constitution 說還在 Practice 階段，但早就在做 Internal 專案了。Practice 和 Internal 的 rigor 不同（Practice 只需要 lightweight learnings，Internal 要求 `retrospective.md` required）。Phase 聲稱影響治理期望。

---

## 8. Drift Governance 停留在理論層

**觀察到的事實：**

| Artifact | Status |
|----------|--------|
| `docs/sdd-drift-governance-core-logic.md` | 216 lines, theoretical |
| `docs/sdd-drift-governance-solution.md` | 32KB, design doc |
| `studio/runtime/impact-registry.json` | Implemented but untracked |
| `docs/change-manifests/` | Directory exists but untracked |

**挑戰：** 設計了一套精密的 drift governance 方法論（govern changes not links、conditional impact、authority layers），impact registry 和 pre-commit hook 中的 advisory 都已經接上了。但 `change-manifests/` 還是 untracked，代表實際操作中可能還沒有人建過完整的 change manifest。

**核心問題：** 這套 drift governance 設計是從實際痛點倒推出來的，還是從方法論理想出發設計的？如果是前者，能說出是哪個具體場景讓你需要 impact routing 而不是直接人工判斷嗎？

---

## 9. Extension System 是空殼

**觀察到的事實：**

| Asset | Status |
|-------|--------|
| `studio/extensions/catalog.schema.json` | Exists |
| `studio/extensions/manifest.schema.json` | Exists |
| `studio/extensions/state.schema.json` | Exists |
| `studio/extensions/POLICY.md` | Exists |
| Management scripts (5 files) | Exist |
| Actual extensions | 1 (`extension-smoke`) |

**挑戰：** 為一個只有一筆 smoke test 資料的系統建了 5 支管理腳本和 3 個 JSON schema。這是 premature abstraction 的典型案例。

---

## 10. 缺少「逃生路徑」設計

**觀察到的事實：**

- Constitution 規定「All projects MUST follow the SDD sequence below without skipping steps」
- 無 fast-track 機制
- 無 "lightweight" 或 "expedited" 模式
- 唯一的彈性：Practice vs Internal 的 rigor 差異（但 SDD 七階段都是 mandatory）

**挑戰：** 如果需要在 30 分鐘內修一個 production bug（未來的 Client 專案），是否真的要先跑 specify, clarify, readiness, plan, tasks, analyze, implement？如果不是，那 constitution 就有一個不成文的例外，而不成文的例外是治理系統最大的敵人。

**核心問題：** 需要一個正式的 expedited path 或 hotfix protocol，否則在壓力下會直接 `--no-verify` 繞過所有東西，然後治理系統的可信度歸零。

---

## 總結：三個最根本的問題

1. **治理系統的 ROI 未被驗證**：投入巨大，但缺乏「沒有這套系統時的 baseline」做對照，也缺乏量化指標。
2. **回饋迴圈失靈**：learnings 空、prompts 空、pain-points 空 -- 系統設計了完美的回饋管道，但管道裡沒有水流。
3. **自我治理缺口**：治理工具本身（scripts、hooks、contracts）沒有測試、沒有 CI、沒有版本管理策略，是整個系統中最不受治理的部分。
