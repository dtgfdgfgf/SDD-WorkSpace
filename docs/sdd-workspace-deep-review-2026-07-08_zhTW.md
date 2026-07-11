---
title: "SDD-WorkSpace 深度環境評估與長期維護策略(2026-07-08 Session 完整記錄)"
version: "1.0.0"
date: "2026-07-08"
language: "zh-TW"
owner: "元熙"
status: "session-record"
purpose: "完整記錄 2026-07-08 對整個 SDD-WorkSpace 的深度分析:環境評價、優缺點、與官方 spec-kit 的差異與同步策略、求職/面試視角評估、LLM 長期維護協議。供未來重做類似分析時直接取用,避免重複調查。"
session_context:
  branch: "feature/wave-3-security-and-workflows"
  head_commit: "b01c366 feat(studio): wave-3 selective alignment"
  last_commit_date: "2026-05-06"
  analysis_method: "3 個平行深度調查(共享層品質 / 官方差異盤點 / 上游動態查證)+ 本機實測 governance 測試套件"
source_basis:
  - "studio/constitution/constitution.md v1.8.0"
  - "studio/runtime/shared-runtime-contract.json"
  - "docs/yuanxi_sdd_pack_strategy_zhTW.md 及兩份 companion review"
  - "履歷/evidence-card_SDD治理工作區.md(2026-05-31 量測)"
  - "官方 spec-kit releases / README / CHANGELOG / community catalog,查證於 2026-07-08"
  - "本機實跑 run-governance-tests.ps1 於 2026-07-08"
related_documents:
  - "docs/yuanxi_sdd_pack_strategy_zhTW.md"
  - "docs/yuanxi_sdd_pack_strategy_implementation_review_zhTW.md"
  - "docs/yuanxi_sdd_pack_implementation_plan_zhTW.md"
  - "docs/yuanxi_sdd_pack_implementation_plan_obstacle_review_zhTW.md"
  - "docs/0308upstreams/spec-kit-upstream-alignment-matrix.md"
---

# SDD-WorkSpace 深度環境評估與長期維護策略(2026-07-08)

## 0. 本次 Session 的提問脈絡

使用者在同一個 session 依序問了四個問題,本文件依序完整記錄分析結果:

1. 深度分析整個 workspace 環境,給出評價:可以改善什麼、缺失什麼、優缺點、是否需要隨 spec-kit 更新、對公司面的價值、面試方會如何評價。
2. 近期沒有要面試,如何長期維護這個 workspace(且維護全靠 LLM)。
3. 官方 spec-kit 一直更新怎麼辦。
4. 要求把本 session 的分析鉅細靡遺記錄成檔案(即本文件)。

使用者背景(當時狀態):workspace 是求職的重要武器,目標職缺方向為 AI/LLM 應用工程師與平台/DevOps/工具鏈;履歷 evidence card 已存在於 `履歷/evidence-card_SDD治理工作區.md`。

## 1. 量化事實快照(2026-07-08 實測)

| 項目 | 數值 | 備註 |
|---|---|---|
| git commits(main 線) | 56 | 最後 commit 2026-05-06,分析當下已停更約 2 個月 |
| PowerShell 腳本 | 38 支,合計約 9,502 行 | `studio/scripts/powershell/` |
| 最大單檔 | `common.ps1` 1,393 行;`.githooks/pre-commit.ps1` 1,397 行 | 單檔體量集中風險 |
| Governance 測試 | 18 個 `.Tests.ps1`(2026-07-11 更正:初版誤計為 23) | `studio/tests/` |
| 測試實跑結果 | 245 total = 244 passed / 0 failed / 1 skipped,71.94 秒 | 本 session 實跑 `run-governance-tests.ps1` 驗證 |
| 重要更正 | `studio/tests/_artifacts/testResults.xml` 顯示 204 total / 23 failures,為過期產物 | 實跑證明目前全綠;該檔應清理並 gitignore |
| Copilot agents | 16 檔(`.github/agents/`) | 13 個 speckit 階段 agent + QA bot + python reviewer + instructions |
| Claude agents | 15 檔(`.claude/agents/`) | 由 `seed-claude-agents.ps1` 從 Copilot 側生成 |
| Prompt stubs | 13 個(`.github/prompts/`) | |
| 文件模板 | 28 個(`studio/templates/sdd-docs/`;2026-07-11 更正:初版誤計為 32) | |
| Ready 狀態 mainline note 帶 TBD | 18 份(共 21 份 note、19 份 Ready;2026-07-11 精確計數) | `docs/mainline-updates/` |
| Runtime 契約 | `shared-runtime-contract.json` 982 行 | 雙向鎖定(缺失與多餘都 fail) |
| 影響路由 | `impact-registry.json` 539 行 | generator 產生 + `-Compare` freshness gate |
| Mainline update notes | 21 份 | `docs/mainline-updates/` |
| CI | 無 | 根目錄無 `.github/workflows/`,唯一 yml 是 `studio/workflows/sdd-pipeline/workflow.yml` |
| 上游 baseline | 2026-03-06(日期式,無 semver 標記) | `get-speckit-version.ps1` 從 `https-github-com-github-spec-kit-repo-2025-10-01-2.md` 抽取 |
| 硬編碼路徑 | 共享層 grep `C:\Users` 為 0 命中 | 全部用 `$PSScriptRoot` + `Get-StudioSharedLayerPaths` |

## 2. 總體評價

### 2.1 一句話定位

把「規格驅動開發 + 多 AI 編碼代理協作」從口頭紀律升級成機器可驗證契約 + commit-time 閘門的個人 AI 工程治理平台。這個價值主張成立,且工程完成度遠超一般個人 side project。

### 2.2 治理閉環(最核心的資產)

憲章(579 行 prose)轉成 `shared-runtime-contract.json`(982 行內容契約),由 `check-speckit-runtime.ps1`(508 行,單一稽核入口,`-Json` 回傳結構化結果)雙向稽核,再由 `pre-commit.ps1`(1,397 行,對 staged snapshot 而非工作目錄稽核)在 commit 時強制,最後由 244 個 Pester 測試鎖定治理不變量。

特別值得肯定的資深級防腐設計:

- 命令契約雙向鎖定:缺少會 fail,多出未宣告的也會 fail。
- `impact-registry.json` 由 generator 產生並用 `-Compare` 做 freshness gate,防止中央索引自己變成 drift 來源。
- pre-commit hook 刻意自我封閉(不 dot-source 共用 helper),shared script 半損時仍擋得下 commit。
- 有 `path-traversal-hardening.Tests.ps1` 專門的安全回歸測試(8 個 call site 的 `Assert-PathInsideRoot`)。
- 憲章變更強制三 adapter(AGENTS.md / CLAUDE.md / copilot-instructions.md)同一 commit 同步。
- spec.md 驗證正則同時支援中英雙語標題;mainline-note 規則對自身豁免(self-locking exemption)。

### 2.3 結構性矛盾(最大的弱點)

花在「治理系統本身」的工程量遠大於被治理的交付量:

| 消費專案 | specs 完整度 | readiness |
|---|---|---|
| projects/Trading-002-decision-evidence-platform | 完整 | 有(002) |
| projects/Trading-003-stock-selection-backtest | 最完整(三個 feature 疊代) | 有(002、003) |
| projects/KMS(001-rag-kb-mvp) | spec/plan/tasks/data-model/research/quickstart | 無 |
| projects/japanese-learning | spec/plan/tasks/data-model/quickstart | 無 |
| projects/Trading(001) | spec/plan/tasks/analyze | 無 |
| projects/commercial-line-bot | 有 `.specify/` 骨架但零 spec 產出 | 無 |
| 其餘(codex-smoke 系列、learning/) | 冒煙/練習骨架 | 無 |

全 workspace 只有 Trading-002/003 真正走完含 readiness gate 的完整七階段;readiness artifact 全部僅 3 份。

### 2.4 知識回饋迴路空轉

- `studio/knowledge-base/learnings.md` 僅 322 bytes(約 22 行)。
- `studio/knowledge-base/pain-points/`、`studio/tools/`、`studio/prompts/` 下六個階段目錄全部為空。
- 憲章第 13 節把 knowledge capture 定為 mandatory,但實際沒有執行。這是「自己定的規則自己沒遵守」,比缺功能更傷。

## 3. 缺失與改善建議(按優先級)

| 優先級 | 項目 | 說明 |
|---|---|---|
| P0 | 加 CI | 無 `.github/workflows/`。一個 windows-latest Actions 跑 `check-speckit-runtime.ps1 -Json`(期望 ERROR_COUNT=0)+ Pester。半天工作量。CI 是唯一不經 LLM 之手的獨立驗證者,對 LLM 維護模式尤其關鍵。 |
| P0 | 清理過期產物與根目錄 | `studio/tests/_artifacts/testResults.xml`(過期 23 failures)、根目錄兩份舊 testResults.xml 應 gitignore;`bone.ini`、`https-github-com-...md`、散落 transition guide、`中文文件管理/`、`履歷/` 混雜在治理 repo,公開展示前須清理或搬走。 |
| P1 | 模組邊界宣稱與實際不符 | readiness/eci 語意已深度織入官方 agent prompt(speckit.plan 的 hard gate、speckit.analyze 的 Intent Drift Check)與 setup 腳本(`Assert-ReadyForPlan`、common.ps1 的 INTENT_LEDGER 路徑)。`studio/extensions/` 只有 extension-smoke,自創命令並非以 extension 形式存在。解法即 yuanxi-sdd-pack overlay 化。 |
| P1 | 回填 learnings.md | 把治理演進中的真實教訓回填 5 到 10 條(如:impact registry 為何需要 freshness gate、hook 為何自我封閉、testResults 過期事件本身)。 |
| P2 | 單檔巨量與平台綁定 | common.ps1 / pre-commit.ps1 各約 1,400 行;38 支腳本全為 PowerShell,hook 依賴 pwsh,非 Windows 不可用。至少在 README 明示此約束。 |
| P2 | 消費面證據太薄 | 挑一個非 Trading 專案(建議 KMS)補一次 readiness 流程,讓七階段流程有第二個獨立佐證。 |

## 4. 與官方 spec-kit 的差異盤點

### 4.1 命令集分層(權威來源:shared-runtime-contract.json)

- mandatoryStageCommands(7):specify、clarify、readiness、plan、tasks、analyze、implement。
- auxiliaryCommands(6):checklist、constitution、discover、eci、taskstoissues、version。
- 每個命令以四形態存在:Copilot agent、Copilot prompt、Claude agent、(部分)專案內 `.claude/commands/`。

### 4.2 官方原生 vs 自創

- 官方原生(9):specify、clarify、plan、tasks、analyze、implement、constitution、checklist、taskstoissues(注意:taskstoissues 是官方的,不是自創)。
- 自創(4)與解決的問題:
  - readiness:插入為第 3 個必經階段。解決「clarify 完就直接 plan,但其實不具規劃安全性」。輸出 8 種 primary status,產出 readiness-assessment.md,引入 intent-ledger.md(defer does not disappear)。
  - eci(External Capability Intake):治理外部能力(API/OAuth/SDK)採用的授權與邊界。dossier 四件套 + ECI Level + Authorization Outcome,完成後強制回 readiness。
  - discover:pre-spec 可選探索,把雜亂輸入轉成 spec-ready 結構。
  - version:studio-first 環境下自製的版本/契約回報命令。

### 4.3 版本痕跡

- 無 semver 化的上游標記;用日期 baseline 2026-03-06。
- workspace 根目錄刻意沒有 `.specify/`(`shared-layer-map.json` 把 `.specify`、`projects`、`learning` 列入 blockedRoots);`.specify/` 只存在於 consumer projects,各自帶官方模板拷貝(升級時 N 份都要處理)。

### 4.4 上游更新難度

- 合併困難(自訂語意已織入):官方 8 命令的 agent/prompt 全被改寫;setup-*.ps1 / common.ps1 / check-prerequisites.ps1 植入 gate;sdd-docs 模板擴充(plan-template 加 Intent Recovery Obligations)。
- 不受影響(獨立擴充):4 個自創命令檔本身、extension 註冊系統、workflow 引擎、匯出工具、治理基礎設施(contract / impact-registry / bootstrap sync / runtime check / pre-commit)。
- 總評:中偏高。實務上須逐檔手動三方合併;好消息是合併後有單一機器驗證入口可回歸。

## 5. 官方 spec-kit 上游現況(2026-07-08 查證)

### 5.1 版本與活躍度

- 最新 release:v0.12.6(2026-07-07)。近一週 5 個 release。累計 182 releases。約 119k stars / 10.5k forks。
- 版號軌跡:2025-11 仍在 0.0.8x;2026-02-20 從 0.0.102 跳 0.1.2;之後加速到 0.12.x。本 workspace fork 對應 0.0.x 時代。

### 5.2 重大結構性變更

| 版本 | 日期 | 變更 |
|---|---|---|
| 0.3.0 | 2026-03-13 | Preset 系統(可插拔模板覆蓋、catalog) |
| 0.5.0 | 2026-04-02 | Extension 架構 |
| 0.7.0 | 2026-04-14 | Workflow engine(catalog、步驟、gate 機制) |
| 0.7.1 | 2026-04-15 | `--ai` 棄用,改 `--integration` |
| 0.9.3 | 2026-06 | `specify self check` / `self upgrade` |
| 0.10.0 | 2026-06-09 | Breaking:移除 `--ai` / `--ai-commands-dir` / `--ai-skills` / `--no-git`;git 改 opt-in extension |
| 0.11.x | 2026-06 | `/speckit.converge` 新命令、`specify bundle`、`specify doctor` |
| 0.12.x | 2026-06 底至 07 | agent-context 改 opt-in extension、catalog HTTPS 驗證、退役 Windsurf 與 Roo Code |

查證注意:`/speckit.converge` 引入版本兩次查詢矛盾(0.7.2 或 0.11.1),確定為 2026 年 4 至 6 月間新增。

### 5.3 官方目前命令集

constitution、specify、clarify、plan、tasks、taskstoissues、analyze、checklist、implement、converge(新:對照 codebase 與 artifacts、補殘餘任務)。官方沒有 readiness / eci / discover / version。

### 5.4 社群生態(重要)

105+ 社群 extensions(60+ 作者)、22 presets、獨立 catalog 網站(speckit-community.github.io)。與本 workspace 概念重疊的社群 extension:

- Intake:PRD/設計/證據正規化為 SDD-ready intake artifacts(近似 discover/ECI intake)。
- Charter:模組化 constitution、跨專案治理規則(與雙層憲章高度重疊)。
- Plan Review Gate、Architecture Guard(drift 偵測)、Product Forge(release-readiness + human-in-the-loop gates)、Repository Governance、CI Guard。

含義:本 workspace 的獨特性正在被生態追上;但核心(core)層仍無 readiness 分類法 / intent-ledger 等價物。

### 5.5 既有 yuanxi-sdd-pack 文件已再度過期

docs/ 下三份 pack 文件(2026-05-05 至 05-08)以 v0.8.6/0.8.7 為基準,其中:

- 障礙檢查 B-003 說本機 CLI 用 `--ai`;上游 0.10.0 已移除 `--ai`,`--integration` 才是對的(修正方向反轉了)。
- B-001(本機 CLI 無 extension/preset subcommand)在 0.12.x 很可能已不成立,需重新驗證。
- 實作前必須先重驗 0.12.x 的 CLI 能力面,再更新 plan 的 compatibility baseline。

## 6. 是否隨 spec-kit 更新:結論

不整包跟版。正確策略是執行既有的 overlay 化方向:

1. 官方 spec-kit 當 base runtime,把 readiness / eci / discover / intent-ledger 封裝成正式 `yuanxi` extension + preset。
2. 建 compatibility matrix + smoke test;上游關係從「逐檔三方合併」降級為「跑一次 smoke test、matrix 加一行」。
3. 求職角度最高價值的一步:上架官方社群 extension catalog。被 catalog 收錄、一行可裝的治理 extension,比私人 workspace 有力一個量級。
4. 官方 workflow gate 可承載 stage-gate;`/speckit.converge` 剛好對應原規劃的 `/speckit.verify`(實作後對帳),可吸收概念。

## 7. 對公司的價值與面試方視角

### 7.1 價值定位

workspace 本身不是公司會買的產品;價值是能力證據。它證明的能力踩在 2026 年企業導入 AI coding 規模化的痛點上:多 agent drift、spec 與實作漂移、agent 行為不可稽核。對應職缺:平台工程、Developer Experience、AI Enablement、內部工具鏈。對純 AI/LLM 應用職缺是輔助證據,主證據仍是 Trading-003 這類真的呼叫 LLM 的專案。

### 7.2 面試官視角評分(本次分析的判斷)

| 維度 | 評分 | 依據 |
|---|---|---|
| 系統設計 | 8 至 9 / 10 | 雙向契約、staged-snapshot 稽核、freshness gate、hook 自我封閉 |
| 工程紀律 | 7 / 10 | 244 測試、安全硬化、Conventional Commits;扣分:缺 CI、過期 artifact |
| 產品/ROI 敘事 | 5 / 10 | 消費證據薄、知識庫空、無 before/after 故事 |
| 誠實文化 | 高 | Surface Truthfulness、defer does not disappear、evidence card 標明未灌水 |

### 7.3 面試官必問的三題與建議答法

1. 「這套治理讓交付變好了什麼?給 before/after。」需要至少一個具體故事:某個 drift 或 scope 被 gate 真實擋下、避免了什麼返工。沒有就會被讀成 process for process's sake。
2. 「一個人需要 1,400 行 pre-commit?over-engineering?」正確答法:刻意把單人環境當多 agent 團隊模擬;治理的不是人,是三套會漂移的 AI agent。這是整個專案最好的一句話 reframe。
3. 「為什麼不做成別人能用的東西?」若已完成 overlay 化 + 上架 catalog,此題從弱點變成最強敘事:發現 fork 模式的 drift 成本,主動重構成 official-first 可安裝 extension。

### 7.4 減分項

缺 CI(對平台職缺近乎紅牌)、Windows/PowerShell 單一棧、消費面證據薄、根目錄雜亂。皆可在 1 至 2 週修掉。

### 7.5 evidence card 數字更新提醒

2026-07-11 更正:本文件初版聲稱 evidence card 的「245 案例 / 18 檔」需更新為「244 passed / 23 檔」——經 learnings 回填工作流的對抗式驗證,這個更正本身是錯的。實況:testResults total = 245(244 passed + 1 skipped)、恰 18 個 `.Tests.ps1`,與 evidence card 原數字相符,無需更新。教訓已記入 learnings.md(重驗本身也會查錯對象)。

## 8. 長期維護策略(LLM 維護模式)

### 8.1 核心原則

讓維護成本跟「自己的使用量」成正比,而不是跟「上游速度」成正比。fork 式共享層讓成本掛鉤上游(一週 5 release),一個人加 LLM 永遠追不上,也不該追。結構解法 = overlay 化(第 6 節)。

### 8.2 LLM 維護的操作協議

- 每個 LLM session 收尾必須是機器驗證,不是 LLM 自我報告:`check-speckit-runtime.ps1 -Json` 期望 ERROR_COUNT=0 + Pester 全綠。可寫進 CLAUDE.md session 規則。
- CI 是唯一不經 LLM 之手的驗證者。testResults.xml 躺著 23 failures 兩個月沒人發現即是案例:本機閘門擋得住壞 commit,擋不住「沒人去看」。
- 善用 `docs/mainline-updates/` 作為 session 之間的 handoff 記憶:每次維護 session 產出一份 note,下次 session 先讀最近三份。

### 8.3 對抗 LLM 增生熵

- 憲章凍結預設:預設不改 constitution;同一痛點在 learnings.md 出現兩次以上才允許升級成規則(憲章 13.4 本有此意,須真的執行)。
- 每 N 次「增」配一次「刪」:定期 pruning session 只做刪除(過期 artifact、已完成使命的 docs 草稿、空目錄骨架)。三份 yuanxi 文件已過期兩輪,應收斂成一份 decision record。
- 治理跟著交付走:下一個新機制前,先讓現有機制多一個真實消費者。

### 8.4 知識回饋迴路

learnings.md 是純 LLM 維護模式下「系統的長期記憶體」。每次 session 結束寫 2 至 3 行(踩的坑、哪個 gate 真的擋下過什麼、哪個機制從未觸發);半年後即有「什麼該刪、什麼該留」的實證依據。

### 8.5 維護節奏表

| 頻率 | 動作 | 驗收 |
|---|---|---|
| 每次 session | 收尾跑 runtime audit + Pester;寫 mainline-update note;learnings 加 2 至 3 行 | ERROR_COUNT=0、測試全綠 |
| 每次 push(自動) | CI 跑同一套稽核 | 徽章綠 |
| 每季 | 上游三項檢查(命令集增減 / extension-preset 機制 breaking / 社群 catalog 重疊);pruning session | compatibility matrix 更新 |
| 每半年 | 回顧 learnings;決定憲章動不動、哪些從未觸發的機制降級 | 版本 bump 或明確「不變」記錄 |

## 9. 「官方一直更新怎麼辦」的完整回答

### 9.1 前提拆解

「官方一直更新」只在 fork 模式下是問題。要的是相容,不是跟上。已有實證:baseline 停在 2026-03-06,四個月沒同步、上游從 0.1.x 到 0.12.6,本地什麼都沒壞——因為 spec-kit 本質是「模板 + 初始化 CLI」,不是 runtime 依賴;專案 init 完成後上游變更碰不到既有專案(consumer projects 各自帶 `.specify/` 拷貝)。釘版本(pin)是正當的長期策略。

### 9.2 上游變更四分類與應對

| 類型 | 例子 | 反應 |
|---|---|---|
| 生態雜訊 | 第 31 個 agent 整合、退役 Windsurf、patch release | 完全忽略(占絕大多數) |
| CLI / init 變更 | 0.10.0 移除 `--ai` | 只在開新專案時處理,一次性 |
| Artifact 格式變更 | spec-template 改 heading,readiness gate 解析不到 | 唯一真正風險;用 artifact contract check 攔截 |
| 能力重疊 | converge、社群 Charter / Intake | 每季看一次,決定吸收或確認自己版本仍更好 |

### 9.3 防禦機制

- extension 命令開頭驗證 spec.md / plan.md 有需要的區段,沒有就明確報「不相容於此版本」,不默默產出錯誤結果(即 yuanxi strategy 第 9.3 節的 artifact contract check)。
- `smoke-test.ps1`:官方 init、裝 pack、跑 toy feature、驗產物;只在主動想升級基準時跑,過了就在 matrix 加一行。主導權在自己,不在上游 release 節奏。
- 唯一例外是安全修補(上游曾有 path-traversal 修補):每季掃描 release notes 的 security fix,LLM 十分鐘可掃完一季。

### 9.4 三句總結

1. 釘住一個測過的版本理直氣壯地用,新專案才碰 CLI 變更。
2. overlay 化之後,「升級」從三方合併降級成跑一次 smoke test,想升才升。
3. 每季一次十分鐘 LLM 掃描(breaking / 格式 / 安全 / 重疊),其餘 release 一律當雜訊。

## 10. 建議行動清單(彙總)

| 順序 | 行動 | 狀態(2026-07-08) |
|---|---|---|
| 1 | 加 GitHub Actions CI(runtime audit + Pester) | 未做 |
| 2 | 清理過期 testResults 與根目錄雜物,gitignore 測試產物 | 未做 |
| 3 | 回填 learnings.md(5 至 10 條真實教訓) | 已完成(2026-07-11,回填 9 個日期區段約 25 條,經 34 條對抗式驗證) |
| 4 | 重驗 spec-kit 0.12.x 的 extension/preset CLI 能力面 | 未做(既有障礙文件基於 0.8.7,已過期) |
| 5 | 更新三份 yuanxi-sdd-pack 文件基準,或收斂成 decision record | 未做 |
| 6 | 走自己的 SDD 流程做出 yuanxi-sdd-pack v0.1(可安裝 overlay) | 未做(specs/yuanxi-sdd-pack-v0.1/ 不存在) |
| 7 | 上架官方社群 extension catalog | 未做 |
| 8 | KMS 補一次 readiness 流程(第二個消費佐證) | 未做 |
| 9 | 更新 evidence card 測試數字 | 取消(2026-07-11 驗證:card 原數字 245 案例 / 18 檔正確,初版深評誤計) |
| 10 | 準備 10 分鐘 demo 腳本(稽核、違規 commit、hook 攔截) | 未做 |

## 11. 需求、痛點與改進優先序總整理(2026-07-11 補記)

### 11.1 底層需求(貫穿所有提問的主軸)

1. 可信的「完成」:機器說了算,不是 LLM 自我報告。
2. 維護成本掛鉤自用量,不被上游 release 節奏與模型換代追著跑。
3. 環境自我改進迴路:盲點暴露、記錄、畢業成機制、退役。
4. 約束放在結果驗證(gate),不堆過程指令(prompt);對 LLM 保留適度自由。
5. 環境本身是對外可驗證的職涯資產(暫緩但持續存在)。

一句話:建一個「以全 LLM 開發為前提、驗證不依賴 LLM 自我報告、能從自身盲點學習」的個人開發環境,同時作為職涯作品。

### 11.2 痛點六類(均有實證,詳見 learnings.md)

1. 假信心/靜默失敗(核心):真正收尾三度推翻、綠 audit 藏 48 缺口、testResults 說謊、18 誤計為 23。
2. 「要記得」機制必然失效:learnings 空轉七個月、Ready note 自我違反 TBD、mandatory 無 gate 執行率零。
3. 驗證自我指涉:治理工具曾零測試、無 CI、--no-verify 一鍵繞過。
4. Drift 無所不在:三鏡像、adapter 同步、上游基準、策略文件兩個月腐化兩輪。
5. 約束反噬與過度工程:mustContainAll 誤報、alert fatigue、extension 5 腳本管 1 筆、20KB stage prompt。
6. 治理與交付失衡:readiness artifact 僅 3 份、有專案掛骨架零 spec。

### 11.3 改進優先序(按槓桿)

1. CI:打斷「LLM 驗 LLM」自我指涉,是後續一切改進的可信度地基。半天。
2. 「記得做」改「被觸發做」:session 收尾固定觸發(實跑稽核 + learnings 追加);新 MUST 同批附 gate 否則不寫。
3. Overlay 化(yuanxi-sdd-pack):同時解 drift、上游錨點、職涯資產三件事。幾週。
4. 再平衡:一次減法(退役過期文件、空骨架、審視 20KB prompts)+ 一個非 Trading 消費專案走完全流程。

### 11.4 根因判斷

六類痛點是同一母題的變體:系統內驗證者與被驗證者長期是同一行動者。過去的建設(契約、hook、測試)本質是驗證外部化;上述四項改進的共同點是打斷最後的自我指涉環——CI 把驗證移出 LLM 之手、觸發機制把記憶移出腦袋、overlay 把維護錨點移出自家 fork、第二個消費專案把價值證明移出系統自身。

## 12. 未來重做類似分析時的方法備忘

> 2026-07-11 增補(源自外部分析對照的教訓):以下第 6-9 點為初版方法的缺口,任何自稱
> 「深度分析」的調查都必須包含,不待使用者明示。

6. 機器語義審計是獨立維度,不可用「audit 全綠 + 測試全綠」替代:逐檔追 agent handoff
   圖並對照憲章階段順序;逐行讀 engine/dispatch 類程式碼的成功判準;對每個 gate 問
   「什麼情況下它會被繞過或被預先滿足」。
7. 對每個強制階段問:「機器上如何區分『做過且通過』與『從未做過』?」答不出即是缺口
   (analyze 無產物即此類)。
8. 所有進入文件的計數一律以確定性指令(ls/grep + wc)輸出為準,LLM 讀後報數只當線索
   (初版三個計數全錯:23/18、32/28、10/18)。
9. 破壞性操作腳本(delete/overwrite 類)單獨過一輪路徑與驗證順序審計(驗證是否在
   mutation 之前、有無 containment、失敗是否 fail-loud)。

### 12.0 原方法備忘

本次分析的做法,重跑時可直接複用:

1. 平行派三個調查:共享層工程品質(結構、腳本、hook、測試、稽核範圍、消費面完整度)、與官方差異盤點(命令分層、版本痕跡、模組邊界、升級難度)、上游動態查證(releases / README / CHANGELOG / community catalog)。
2. 不要相信 repo 內的測試結果檔;一律本機實跑 `run-governance-tests.ps1` 取得當下真值。
3. 消費面完整度的判準:每個 `projects/` 與 `learning/` 專案的 specs/ 是否有 spec / plan / tasks / readiness;readiness artifact 數量是流程真實採用度的最誠實指標。
4. 上游查證重點固定四項:最新版本與日期、breaking changes、官方命令集、社群 catalog 與自有能力的重疊。
5. 先讀 `docs/yuanxi_sdd_pack_*` 系列與 `docs/0308upstreams/`,避免重複既有分析;注意這些文件的 compatibility baseline 可能已過期,結論方向通常仍有效但操作細節須重驗。
