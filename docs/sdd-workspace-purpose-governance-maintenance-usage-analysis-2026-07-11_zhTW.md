---
title: "SDD-WorkSpace 目的、治理、維護與使用理念分析"
version: "1.0.0"
date: "2026-07-11"
language: "zh-TW"
status: "analysis"
authority: "informational"
scope: "Workspace shared governance layer, runtime, maintenance mechanisms, user entry points, consumer adoption, and current working-tree state"
---

# SDD-WorkSpace 目的、治理、維護與使用理念分析

## 0. 執行摘要

本 workspace 不是單一產品 repo，也不只是 Spec Kit 文件模板，而是一個面向單人 AI
工程實踐的治理控制平面。

其核心目的可以濃縮為：

> 讓 AI 有生成自由，但不讓 AI 自己定義產品意圖、事實與完成；把產品意圖保留給
> owner，把完成判定移到可重跑的外部證據，並把失敗經驗轉成環境能力。

因此，這套系統真正治理的不是「人有沒有照流程填文件」，而是：

- LLM 是否在前提不足時仍繼續產生看似完整的規格、計畫或程式碼。
- 原始需求是否在 MVP、替代方案、延期或正式放棄的過程中靜默消失。
- 多工具、多 agent、多 worktree 與跨 session 維護時，治理語意是否漂移。
- 驗證者與被驗證者是否長期為同一個 LLM，形成自我指涉與假信心。
- 每次交付暴露的盲點，是否能沉澱成可重用且可退役的環境能力。

目前最準確的成熟度判斷是：

| 面向 | 成熟度 | 判斷 |
|---|---|---|
| Shared governance core | 內部 beta 後期 | 權威分層、contract、hook、stage gate、測試與 drift routing 已相當完整。 |
| Consumer adoption | Early alpha | 現行 readiness 流程主要只在 Trading lineage 出現，且仍有事後補救與狀態不合規。 |
| Independent verification | 尚未完成 | CI 已在 working tree 草擬，但尚未進版控與 GitHub 實際執行。 |
| Workflow orchestration | 實驗性 | Wave 3 workflow primitives 有測試，但 built-in pipeline 尚不能證明 agent 真正執行。 |
| Extension and skill distribution | 基礎階段 | Registry、schema、管理腳本存在，但真實 extension、skill pack 與 consumer 證據很薄。 |
| Knowledge feedback | 修復初期 | `learnings.md` 已開始回填，但多數候選尚未畢業成 gate、prompt 或測試。 |
| Installable overlay | 策略階段 | `yuanxi-sdd-pack` 有策略與 meta plan，尚未建立正式 SDD feature packet。 |

一句話總評：

> 治理引擎的成熟度已明顯高於真實交付採用與營運成熟度。

## 1. 分析範圍與方法

### 1.1 分析範圍

本次分析涵蓋：

| 範圍 | 主要路徑 |
|---|---|
| Studio governance | `studio/constitution/constitution.md` |
| Runtime contract and impact routing | `studio/runtime/` |
| Runtime agents and prompts | `.github/agents/`、`.github/prompts/`、`.claude/agents/` |
| Automation and hooks | `studio/scripts/powershell/`、`.githooks/` |
| Templates | `studio/templates/` |
| Workflow and extension runtime | `studio/workflows/`、`studio/extensions/` |
| Tests and audit | `studio/tests/`、`check-speckit-runtime.ps1` |
| User-facing documentation | `README.md`、`WORKSPACE_STRUCTURE.md`、Quickstart 文件 |
| Knowledge capture | `studio/knowledge-base/`、mainline update notes |
| Consumer adoption | `projects/`、`learning/` 的治理 artifacts、Git 與 hook 狀態 |
| Evolution history | Git history、歷史稽核、deep review 與 overlay 策略文件 |

### 1.2 分析順序

依 workspace 治理要求，本次先讀最高權威的 Studio Constitution，再進行其他唯讀檢查。

分析方法包括：

1. 盤點 authority、dependent 與 informational 文件。
2. 檢查七階段 SDD、readiness、ECI 與 intent ledger 的宣告語意。
3. 比對 agent handoff、setup gate、pre-commit、workflow engine 與實際執行圖。
4. 執行 shared runtime audit。
5. 讀取目前 Pester 結果與測試覆蓋面。
6. 檢查 consumer project 的 Git root、adapter、junction、hook 與 readiness artifacts。
7. 對照 Git 歷史、mainline notes、learnings 與未提交策略文件。
8. 區分已證實事實、設計意圖與未落地未來方向。

### 1.3 本次驗證快照

| 項目 | 結果 |
|---|---|
| Shared runtime audit | `VALID=true`、0 errors、0 warnings |
| Pester 結果 | 245 total、244 passed、0 failed、1 skipped |
| PowerShell scripts | 38 檔，約 9,502 行 |
| Pester test files | 18 檔，約 3,115 行 |
| Copilot `*.agent.md` files | 14 檔，約 2,972 行 |
| Claude agent files | 15 檔，約 3,040 行 |
| SDD document templates | 28 檔，約 1,682 行 |
| Runtime prompt stubs | 13 檔 |
| Extension registry | 1 個 smoke extension，0 個 enabled |
| Workflow registry | 1 個 built-in `sdd-pipeline` |

這些數字只能證明目前檔案、選定 contract 與測試基線的狀態，不能自動證明整條治理
語意與 agent execution graph 正確。

## 2. 專案目的

### 2.1 主要目的：單人 AI 工程工作室的控制平面

`README.md` 已明確指出這不是單一產品，而是整個 SDD 工作室的基礎設施。

它集中管理：

- Studio Constitution。
- Shared runtime agents 與 prompts。
- 專案初始化與 worktree bootstrap。
- SDD artifact templates。
- Git hooks 與 machine-verifiable audit。
- Extensions、workflow runtime 與 generated exports。
- Practice、Internal 與未來 Client 專案的共同治理。
- 跨專案 learnings 與方法論演進。

因此，`studio/` 比較接近 control plane，`projects/` 與 `learning/` 則是 consumer
spaces。

### 2.2 底層需求

綜合憲章、歷史稽核與最新 learnings，可歸納出五個底層需求：

| 底層需求 | 說明 |
|---|---|
| 可信的完成 | 完成由可重跑 evidence 判定，不由 LLM 自我報告。 |
| 意圖不被洗掉 | MVP、替代、defer 與 drop 不得讓原始承諾靜默消失。 |
| 低記憶負擔 | 能由 gate 驗證的規則，不依賴 session prompt 或 LLM 記憶。 |
| 可維護的 drift | 暫時 drift 可以存在，但必須可見、可路由、可在 merge 前 reconciliation。 |
| 可自我改進 | 盲點經過記錄、驗證後，應畢業成 gate、test、template 或 prompt。 |

### 2.3 次要目的：方法論與職涯 evidence

最新 deep review 與履歷 evidence 資料顯示，workspace 同時是能力證據：

- 證明能設計 AI coding governance。
- 證明能處理 multi-agent drift、artifact traceability 與 staged validation。
- 證明能將方法論轉成可執行工具鏈，而不只停留在 prose。
- 未來希望抽成可安裝的 `yuanxi-sdd-pack`，降低使用門檻並形成更清楚的產品邊界。

此目的目前是次要且未完成的方向，不應誤報成已公開或可安裝的產品能力。

## 3. 治理理念

### 3.1 Authority first

所有 governed documents 分成三層：

| Authority | 定義 | 更新順序 |
|---|---|---|
| `source_of_truth` | 正式定義規則、需求或行為的來源 | 第一 |
| `dependent` | 由 source 衍生或受其約束 | 第二 |
| `informational` | 說明、索引、導覽與歷史紀錄 | 第三 |

這個模型的意義是：

- 不能從 README 的舊敘述反向修改 Constitution。
- 不能讓 generated mirror 變成第二個 source of truth。
- 變更必須先確立 authoritative state，再傳播到 dependent，最後修正說明面。
- 發生衝突時應回報 drift，而不是靜默挑選對自己方便的文件。

### 3.2 Dual-layer constitutions

治理順序是：

1. `studio/constitution/constitution.md`。
2. `<project>/.specify/memory/constitution.md`。
3. `AGENTS.md`、`CLAUDE.md`、`.github/copilot-instructions.md` 等 runtime adapters。

Project Constitution 可以增加：

- 專案術語。
- 更嚴格的 testing 或 review 規則。
- Domain-specific constraints。
- Client-specific obligations。

Project Constitution 不可以：

- 跳過或縮減 Studio mandatory stages。
- 移除必要 artifacts。
- 放寬 AI collaboration rules。
- 把 adapter 升格為 constitution。

### 3.3 SDD 是承諾與授權鏈

正式七階段為：

1. `/speckit.specify`
2. `/speckit.clarify`
3. `/speckit.readiness`
4. `/speckit.plan`
5. `/speckit.tasks`
6. `/speckit.analyze`
7. `/speckit.implement`

各階段角色不是單純文件生成：

| 階段 | 治理角色 |
|---|---|
| Specify | 定義產品承諾、actors、flows、FR、NFR、edge cases、success criteria 與 out of scope。 |
| Clarify | 移除高風險 ambiguity，補齊邊界、格式與 business logic。 |
| Readiness | 判斷目前 evidence 是否足以安全進入規劃，並只指出一個 primary blocker。 |
| Plan | 在已授權的範圍內決定架構、技術、integration、data flow、risks 與 alternatives。 |
| Tasks | 把計畫轉成可追溯、具依賴與 DoD 的工作單位。 |
| Analyze | 檢查 coverage、contradiction、readiness、ECI、intent 與 outward-facing truthfulness。 |
| Implement | 嚴格依 tasks 執行，不自行增加未授權功能。 |

### 3.4 Planability 與 intent obligation 分離

Readiness 的核心創新是把兩個問題分開：

1. 現在是否安全進入技術規劃。
2. 原始產品意圖是否已完整保留或交付。

因此：

- `READY_FOR_PLAN` 不代表所有原始需求已完成。
- 代表性替代、延期或正式 drop 的核心項目仍可能存在。
- 若這些項目影響 core intent，就必須建立 `intent-ledger.md`。
- Ledger 不增加新 stage，但會成為 readiness 到 plan 的正式 handoff input。

### 3.5 Defer does not disappear

`intent-ledger.md` 只允許三種 classification：

- `represented_by_substitute`
- `deferred`
- `dropped_with_owner_signoff`

其治理意義是：

- Substitute 必須說明目前由什麼能力代表。
- Deferred 必須有具體 re-entry trigger。
- Dropped 必須保留 owner signoff。
- Plan 必須承接 Intent Recovery Obligations。
- Analyze 必須檢查 outward-facing docs 是否過度宣稱。

這避免 AI 把「這一版先不做」逐步改寫成「原本就沒有這個需求」。

### 3.6 External Capability Intake

ECI 將外部能力採用分成：

- Source basis。
- Capability boundary。
- Adoption record。
- Authorization outcome。

正式 dossier 包括：

- `eci-assessment.md`
- `source-manifest.md`
- `adoption-record.md`
- `authorization-record.md`

ECI 完成後仍必須回到 readiness。Sandbox 或 spike authorization 不能直接提升為
mainline implementation authorization。

### 3.7 Surface truthfulness

若 umbrella feature 名稱比本次實際交付範圍更大，以下表面必須揭露 current coverage
與 known gaps：

- README。
- Quickstart。
- Analyze conclusion。
- 必要時的 plan disclosure。

這表明治理不只關心 code 是否通過，也關心使用者會不會被名稱與文件誤導。

### 3.8 Drift 是 routing 問題，不是全文同步問題

`docs/sdd-drift-governance-core-logic.md` 的核心思想是：

- Govern changes，而不是 raw document relationships。
- Related 不代表每次都必須同步。
- 使用 `reference`、`maybe_review`、`must_review`、`must_update` 分級。
- 控制每一步的 cognitive load，而不是要求一次讀完整文件圖。
- 大型 cascading change 應被視為正式 propagation work。
- 暫時 drift 可以存在，但未知 drift 不可以。
- Merge 或 PR 是正式 reconciliation point。

## 4. 維護理念

### 4.1 Studio-first 與 consumer isolation

Shared governance、agents、templates、scripts、extensions 與 workflows 集中在 workspace。

Consumer project 則應：

- 擁有獨立 Git repo。
- 擁有 project constitution。
- 透過 junction 或 documented equivalent 使用 shared agents。
- 透過 workspace hooks 接受 staged governance。
- 保有自己的 source、specs、docs 與 release history。

`projects/` 與 `learning/` 不作為 shared-layer convergence 的預設驗收面，這可避免某個
歷史專案的 local state 阻止 control plane 演進。

此隔離同時帶來一個義務：consumer compatibility 必須由 ledger、bootstrap check 或
migration process 另外維護。

### 4.2 Generated assets 不應手工維護

維護偏好是：

- Authoring source 明確。
- Generated mirror 可重建。
- 中央索引由 generator 產生。
- Freshness gate 驗證 index 未過期。
- Generated skill pack 不成為新權威。

這是因為手工 mirror 與手工 index 都會讓「尚未提交的刻意變更」和「未發現 drift」
變得無法區分。

### 4.3 Machine gate 優先於 prompt rule

最新 `learnings.md` 將長期維護原則進一步收斂為：

- 能由 machine gate 攔截的，不升級成 session prompt。
- Gate 必須有 negative-path test，證明破壞後真的會失敗。
- Validation tool 自身必須被測試。
- Fail-loud 優先於 warn-and-continue。
- 過多過程約束會增加 context cost、繞過率與 alert fatigue。

### 4.4 Knowledge 是中繼站，不是博物館

Learning 的生命週期應為：

1. 發現當時未察覺的盲點。
2. 記錄具體事件與 evidence。
3. 確認是否可重現。
4. 判斷應畢業成 gate、test、template、prompt 或 constitution rule。
5. 定期檢查是否因模型或環境演進而失效。
6. 將過時條目移至 Retired 區並保留原因。

### 4.5 不追逐上游速度

長期維護方向不是整包追隨每個 Spec Kit release，而是：

- Pin 一個經過測試的 base。
- 只主動處理 security、breaking artifact contract 與高價值重疊能力。
- 以 compatibility smoke test 決定是否升級。
- 將 readiness、ECI、discover 與 intent ledger 抽成 namespaced overlay。
- 不覆寫 official core command，降低三方 merge 成本。

這可讓維護成本與自身使用量相關，而不是與上游發布頻率相關。

### 4.6 歷史真實性優先於補造合規

Legacy feature 不應事後補造 readiness 或 ECI 以假裝當時走過流程。

正確做法是：

- 保留歷史 artifacts。
- 由 governance status 說明舊基線。
- 新 governed feature 開始時再進現行流程。
- Project 狀態依實際情況標為 Legacy、Mixed 或 Current。

## 5. 使用理念

### 5.1 最短操作模式

預期使用方式是：

1. 先讀 Studio Constitution。
2. 由 init script 建立 Practice、Internal 或 Client project。
3. 以產生的 multi-root `.code-workspace` 開啟。
4. 依序執行七個 slash commands。
5. 在每一階段審查 artifact 與 next action。
6. 實作後執行測試與治理驗證。
7. 完成 project retrospective 或 learnings。

### 5.2 Project classification 不改變七階段嚴謹度

| 類型 | 主要差異 |
|---|---|
| Practice | 完成後更新 shared learnings，retrospective 可選。 |
| Internal | `retrospective.md` 必要，重要 learning 回收至 studio。 |
| Client | 在完整流程之外增加 stakeholder review gates。 |

三種類型都必須走完整七階段；差異主要在 knowledge capture 與 review obligation。

### 5.3 Operator-in-the-loop

AI 可以：

- 產生 spec、plan、tasks、code 與 tests。
- 提出風險、替代方案與 commit message。
- 執行獲授權的 validation。

AI 不應自行：

- 決定未寫明的產品需求。
- 跳過 mandatory stage。
- 將 sandbox authorization 升級成 mainline authorization。
- 自動 commit、push 或 merge。
- 把自己產生的文字當成完成 evidence。

Wave 3 workflow 的設計也是 operator-in-the-loop；agent dispatch 應停下來等待操作者在
agent IDE 執行 slash command，再 resume。

### 5.4 語言與文件格式

人類閱讀面預設使用繁體中文，以下內容保留英文：

- Code identifiers。
- Tool、protocol、framework 與 standards 名稱。
- FR、NFR、T### 等 IDs。
- MUST、SHOULD、MAY 等 normative keywords。

AI 生成 Markdown 應使用：

- Tables。
- Numbered 或 bullet lists。
- Inline code。
- Plain-text relationship descriptions。

不使用 ASCII art、tree diagram、箭頭式流程符號或 SDD 文件 emoji。

## 6. 目前架構

| Layer | Canonical paths | 角色 |
|---|---|---|
| Governance | `studio/constitution/constitution.md` | Studio 最高權威 |
| Runtime verification | `studio/runtime/shared-runtime-contract.json` | Selected invariants 與 required surfaces |
| Change routing | `studio/runtime/impact-registry.json` | Change type 與 propagation rules |
| Copilot authoring runtime | `.github/agents/`、`.github/prompts/` | Shared commands 與 agent definitions |
| Claude runtime | `.claude/agents/` | Seeded dependent runtime |
| Adapters | `AGENTS.md`、`CLAUDE.md`、`.github/copilot-instructions.md` | Tool startup context |
| Templates | `studio/templates/` | Project bootstrap 與 SDD artifact baseline |
| Automation | `studio/scripts/powershell/` | Init、validation、sync、export、workflow、extension management |
| Commit gates | `.githooks/` | Staged snapshot audit 與 artifact validation |
| Workflow runtime | `studio/workflows/` | Optional declarative orchestration |
| Extension registry | `studio/extensions/` | Shared extension catalog、state 與 manifests |
| Consumer projects | `projects/`、`learning/` | 實際產品與練習空間 |
| Knowledge | `studio/knowledge-base/` | 跨專案 learnings |

## 7. 已落實的強項

### 7.1 Readiness、ECI 與 intent governance

這是整個 workspace 最具辨識度的治理資產：

- Readiness 不做無限 checklist，而是只選 primary blocker。
- ECI 把外部能力採用的來源、邊界與授權拆開。
- Intent ledger 避免 scope compression 抹除原始意圖。
- Analyze 把 outward-facing over-claim 視為 Critical。

### 7.2 Staged snapshot audit

Pre-commit 不是直接驗證 working tree，而是使用 Git index 建立 staged snapshot，再於
snapshot 中執行 shared runtime audit。

這能避免：

- Unstaged 修正掩蓋 staged 問題。
- Hook 誤驗工作目錄而不是即將 commit 的內容。
- Runtime contract 與 commit 實際內容不一致。

### 7.3 Planning gate

Staged `plan.md` 或 `tasks.md` 會檢查：

- `readiness-assessment.md` 存在。
- Primary Status 為 `READY_FOR_PLAN`。
- Required intent ledger 存在。
- ECI authorization 為 `READY_FOR_MAINLINE_IMPLEMENTATION`。

### 7.4 Adapter bootstrap

三個 workspace adapters 的 generated governance bootstrap block 目前一致，並能檢查：

- Studio Constitution path。
- Constitution version。
- Project constitution reference。
- Claude direct imports。

### 7.5 Self-verification 已開始形成

目前已有 18 個 Pester test files，涵蓋：

- Runtime contract。
- Pre-commit 與 commit-msg。
- Adapter bootstrap。
- Impact registry generation。
- Stage-entry gates。
- Path traversal call sites。
- Workflow schema、expression、run state 與 engine primitives。

這已明顯改善早期「治理工具本身沒有測試」的問題。

## 8. 已證實的關鍵落差

### 8.1 Critical：direct agent graph 可跳過 mandatory stages

目前有三條明確捷徑：

1. `speckit.specify.agent.md` 可直接 handoff 至 readiness，跳過 clarify。
2. `speckit.clarify.agent.md` 明文允許使用者要求跳過 clarify。
3. `speckit.tasks.agent.md` 同時提供 analyze 與 implement handoff。

Implement agent 也沒有補上完整硬門：

- 沒有要求驗證最新 readiness。
- 沒有要求讀取 ECI authorization。
- 沒有要求 intent ledger。
- 沒有可信的 analyze completion requirement。

因此目前是「七階段檔案與命令 inventory 完整」，但不是「七階段執行圖完整」。

### 8.2 Critical：Analyze 沒有可信的完成 artifact

`speckit.analyze.agent.md` 明定輸出 report 但不寫檔。

`setup-implement.ps1` 則只在 `analysis-checklist.md` 存在時檢查 unresolved Critical。
當檔案不存在時，它不會判定 analyze 尚未執行。

這造成：

- Analyze 可以完全缺席。
- Implement 仍可能被判為 READY。
- Machine gate 無法區分「沒有 Critical」和「從未分析」。

### 8.3 Critical：Wave 3 pipeline 可產生假完成

`workflow-engine.ps1` 的 agent dispatch 只檢查 `expected_artifact` 是否存在。

但多個 prep scripts 會先建立對應檔案：

- Readiness prep 建立 readiness artifact。
- Plan prep 建立或覆寫 plan。
- Tasks prep 建立 tasks。
- Analyze prep 建立 analysis checklist。

結果是 engine 看到檔案已存在後，直接把 agent step 記為 success。

其他已證實問題：

- Workflow switch 讀取 `vars.readiness_primary_status` 與
  `vars.eci_authorization_outcome`，engine 實際只保存
  `vars.steps.<id>.json`，兩個值沒有被賦值。
- Implement step 把早已存在的 `tasks.md` 當作 expected artifact。
- Resume 會從 workflow 開頭重跑。
- `setup-plan.ps1` 可能在 resume 時覆寫既有 plan。

因此 `sdd-pipeline` 目前不能作為七階段真正執行的 acceptance evidence。

### 8.4 High：Specify assumption policy 與治理核心衝突

Studio Constitution 禁止 AI assume missing requirements。

但 Specify agent 目前要求：

- 對不明項目作 informed guesses。
- 使用 industry defaults 補入 retention、performance、authentication 與 integration 等內容。

若這些內容明確標成 provisional assumption，且強制進 clarify，仍可能是可控推論。
但目前 Specify 又能直接 handoff 到 readiness，推論可能被誤當成 owner-approved intent。

### 8.5 High：綠 audit 是 selected invariant audit，不是 semantic proof

`check-speckit-runtime.ps1` 目前主要檢查：

- File existence。
- Contract membership。
- Substring。
- Regex。
- Governance anchors。

它尚不能證明：

- Agent handoff graph 合憲。
- Analyze 真正完成。
- GitHub 與 Claude agent body convergence。
- Agent 內部沒有互相矛盾。
- Adapter manual sections 語意一致。
- Workflow step 真正執行而不是 artifact 已存在。

所以正確解讀是：

> 綠 audit 證明 selected contract checks 通過，不代表整個 runtime semantics 已收斂。

### 8.6 High：GitHub 與 Claude analyze agent 已漂移

Copilot source 的 Analyze agent 有 mainline shared-layer change manifest 與 update-note 提醒。

Claude seeded mirror 缺少該段 substantive body。

目前 audit 對 Claude agents 主要只驗證：

- Required filename。
- Contract membership。

沒有 normalized body comparison 或 source hash，因此 drift 仍會回報全綠。

### 8.7 High：Spec Kit QA agent 對 repository authority 的描述錯誤

`.github/agents/spec-kit.agent.md` 與 Claude QA mirror 開頭宣稱：

- Repository 沒有 checked-in `studio/` governance tree。
- `studio/*` 是 historical placeholder。
- 應優先讀 local `.specify/memory/constitution.md`。

但 workspace 實際情況是：

- `studio/constitution/constitution.md` 存在且為最高權威。
- Workspace root 沒有 project constitution。
- 該 agent 後段又宣告 Studio Constitution 最高。

這是 authority drift 與 agent 內部自相矛盾。

### 8.8 High：Consumer adoption 遠落後於 shared control plane

Consumer inventory 顯示：

- 六個實際 repo 或 worktree 都沒有 `AGENTS.md`。
- 六個都沒有設定 shared `core.hooksPath`。
- Japanese、KMS 與個人網站等多為 pre-baseline legacy projects。
- Trading 002、003 是 stacked worktrees。

Readiness adoption：

- Workspace 共有 3 份 `readiness-assessment.md`。
- 其中 Trading 002 的檔案在 003 worktree 中重複。
- 真正 unique readiness feature 只有 Trading 002 與 003。
- Trading 003 Primary Status 為 Constitution 未允許的
  `IMPLEMENTED_AFTER_REMEDIATION`。
- 003 明確是 implementation 後補救，不是 planning 前 gate。

因此真正可視為 current readiness gate 證據的 feature，可能只有 Trading 002。

### 8.9 High：Project governance status 已過期

`docs/project-governance-status.md` 停在 2026-03-23：

- 只把 Trading 視為 001 Legacy snapshot。
- 未反映 Trading 002 與 003 的 post-baseline work。
- Derived worktrees 自己仍宣稱 Legacy。

依 ledger 自身規則，新 governed feature 出現時應重新判斷是否為 `Mixed`。

另外，Trading Project Constitution 仍寫 mandatory six-stage workflow，直接放寬 Studio
Constitution 的七階段規則。

### 8.10 High：Extension lifecycle 有 path-boundary 與 destructive risk

`add-extension.ps1`：

- 直接以 manifest `id` Join-Path。
- 未驗證 ID 格式。
- 未確認 resolved target 仍在 `studio/extensions/`。
- `-Force` 時會遞迴刪除 target。

`remove-extension.ps1`：

- 未驗證 `Id`。
- 未執行 path containment check。
- 找到 target manifest 後會遞迴刪除目標。

這違反 `studio/extensions/POLICY.md` 宣告的 escaping path rejection。

在修正前，不應對非完全可信的 manifest 或 extension ID 執行 add/remove。

### 8.11 High：Extension registry 宣稱強於執行

目前 validator：

- 未實際使用三個 JSON schemas 做完整 `Test-Json`。
- 主要是手寫部分欄位驗證。
- JSON mode 在 invalid 時仍可能 exit 0。

Add/remove：

- 先修改 filesystem、catalog 與 state，再驗證。
- 沒有 rollback。
- 驗證 invalid 時可能仍 exit 0。

Workflow registry 也存在類似問題：

- `run-workflow.ps1` 主要依 ID 組路徑執行。
- 未以 catalog、state 作為 execution authorization。
- Disabled 或 uncataloged workflow 只要目錄與 YAML 存在仍可能執行。

### 8.12 Medium：Change propagation 尚有盲區

目前 `sharedGatePaths` 與 impact registry 未完整涵蓋：

- `studio/extensions/`。
- Extension lifecycle scripts。
- `.github/workflows/`。

Impact routing 的 `must_update` 在 hook 中主要是 warning。

Mainline note gate 只檢查是否有任一 note staged，沒有完整驗證：

- Note metadata。
- Ready status 與 commit hash。
- Index 是否同步。
- Note 是否真的對應本次變更。

### 8.13 Medium：Adapter bootstrap 同步不等於完整語意同步

目前三個 generated bootstrap blocks 一致。

但：

- `AGENTS.md` manual section 幾乎為空。
- `CLAUDE.md` manual section 幾乎為空。
- `.github/copilot-instructions.md` 在 generated block 外複製大量共享治理內容。
- Copilot adapter 仍顯示 `Practice (as of 2025-12)`。
- Studio Constitution 已是 `Practice + Internal (as of 2026-04)`。

因此目前保證的是 bootstrap block parity，不是完整 operational semantics parity。

### 8.14 Medium：文件與 runtime 使用舊模型

已證實的例子：

- Full guide 將 Analyze 標為 optional。
- Full guide 又宣稱七階段不可跳過。
- README 與 WORKSPACE_STRUCTURE 仍列出已刪除的 `features.txt`。
- 18 份 `Status: Ready` mainline notes 仍使用 `Related Commits: TBD`。
- Checklist agent 宣稱使用 readiness 與 ECI，實際主要載入 spec、plan、tasks。
- Implement agent 仍解析舊的 `[P]` parallel marker。
- Tasks canonical format 已移除該 marker。
- Generic agent template 宣稱可生成三種 root adapters，卻沒有 generated governance bootstrap。

### 8.15 Medium：新機制先存在、後找 consumer

目前低採用或空資產包括：

| 資產 | 現況 |
|---|---|
| Extension registry | 僅一個 disabled smoke extension |
| Workflow runtime | 一個 built-in pipeline，consumer 中沒有 run state evidence |
| Agent skill packs | 只有 `.gitkeep`，尚未產生 pack |
| Stage prompt directories | 多數為空 |
| Pain points directory | 空 |
| Change manifests | 只有 scaffold 或 `.gitkeep` |
| Prompt candidates | 已記於 learnings，但尚未畢業成正式資產 |

這印證最新 learning：

> Artifact 存在不等於已接上流程。

### 8.16 Medium：獨立 CI 尚未真正生效

`.github/workflows/governance.yml` 的設計方向正確：

- Windows runner。
- Minimal `contents: read`。
- Shared runtime audit。
- Full Pester suite。
- Test result artifact。

但目前：

- Workflow 尚未被 Git 追蹤。
- GitHub 不會執行它。
- 尚無第一次 hosted runner 綠燈。
- Pester 與 `powershell-yaml` 只設 minimum 或 latest，沒有精確 pin。
- Actions 使用 major tag，沒有 commit SHA pin。

因此它目前是待驗證設計，不是已生效的 independent verifier。

## 9. Working tree 與發布狀態

分析當下：

- Branch 為 `feature/wave-3-security-and-workflows`。
- 本地較 `origin/main` 多一個 commit。
- Branch 沒有 upstream。
- Wave 3 workflow runtime 位於本地 feature commit。
- CI、learnings、deep review、yuanxi pack 文件與個人資料目錄仍有未提交內容。
- Git 沒有正式 tags。

這表示目前至少存在四種不同狀態：

| 狀態 | 代表內容 |
|---|---|
| Published mainline | `origin/main` 的 v1.8.0 remediation baseline |
| Local committed experiment | Wave 3 workflow 與 security hardening |
| Working-tree draft | CI、learnings 回填、deep review 與策略文件 |
| Future intent | `yuanxi-sdd-pack` overlay 與公開 distribution |

後續分析與說明必須明確區分這四層，不能把 local draft 或 future intent 說成已發布能力。

## 10. Root hygiene 與資訊邊界

`resources/github-copilot-configs/` 是大型外部參考鏡像，約佔 workspace 檔案數的大部分，
但不是 runtime authority。

Root 也存在：

- 歷史 upstream snapshot。
- 舊 test result。
- 個人資料與履歷 working directory。
- 多份過期或互相承接的策略文件。

主要風險不是它們一定有錯，而是：

- 公開 repo 的核心敘事被稀釋。
- 未追蹤個人資料只差一次誤操作就可能進入 Git。
- 舊測試結果會被誤當成當下真值。
- 未標示 verified-on 的外部策略文件會快速腐化。

## 11. 對治理理念的最終理解

### 11.1 這不是 process for process's sake

建立者想解決的真實問題是：

- LLM 會用完整語氣掩蓋未知。
- 多 agent 會各自複製治理語意。
- 長 session 與 worktree 會讓「記得做」失效。
- Defer、stub 與 TODO 會讓原始產品 intent 消失。
- 本地綠燈可能只是驗證者自我報告。

因此治理系統的正當性應由「實際擋下多少錯誤與返工」證明，而不是由規則數量證明。

### 11.2 嚴格不代表沒有彈性

設計中的正確彈性包括：

- Readiness 的八種 primary statuses。
- ECI 的 sandbox、spike 與 mainline authorization。
- Optional intent ledger。
- Legacy 不補造歷史。
- Temporary but known drift。
- Operator decision gates。

目前缺少的是正式 expedited 或 hotfix path，而不是更多非正式跳過方式。

### 11.3 最重要的維護原則

未來增加新治理規則前，應逐項回答：

1. 這個規則來自哪個已發生且可證明的盲點。
2. 它是 source rule、dependent behavior 還是 informational guidance。
3. 哪個 runtime mechanism 會執行它。
4. 哪個 negative-path test 證明它真的會擋。
5. 哪個 consumer 會實際使用它。
6. 它是否增加過多 context cost 或繞過誘因。
7. 什麼條件下可以退役。

## 12. 建議處理優先序

### 12.1 P0：先修 correctness 與 destructive safety

1. 為 add/remove extension 加入 ID validation 與 resolved path containment。
2. 移除 Specify 到 Readiness、Tasks 到 Implement 等不合憲 handoffs。
3. 移除 Clarify 的 informal skip path，或另行設計正式 expedited protocol。
4. 定義 persisted Analyze completion artifact。
5. Implement 必須驗證 Analyze artifact 存在且沒有 unresolved Critical。
6. 修正 `sdd-pipeline` 的 artifact freshness、state variable mapping、resume 與 overwrite 行為。

### 12.2 P1：修 acceptance oracle

1. 為 agent transition graph 建立 machine-verifiable contract。
2. 對 GitHub source 與 Claude generated body 做 normalized parity 或 hash check。
3. 修正 Spec Kit QA 的 repository authority 描述。
4. 讓 extension validator 真正套用 schemas 並在 invalid 時 non-zero exit。
5. 讓 workflow catalog/state 真正控制 execution authorization。
6. 補 built-in `sdd-pipeline` end-to-end negative-path tests。

### 12.3 P1：完成 independent verification

1. 將 governance CI 納入版控。
2. 在 GitHub hosted runner 完成第一次綠燈。
3. Pin 或清楚管理 action 與 module versions。
4. 視需要加入 branch protection。

### 12.4 P1：讓 consumer 進入現行治理

1. 不補造 Legacy history。
2. 更新 Trading status 至符合實際狀態。
3. 修正 Trading Project Constitution 的六階段衝突。
4. 補齊 active consumer 的 `AGENTS.md`、bootstrap 與 shared hooks。
5. 選一個非 Trading project 真正走完七階段，形成第二條獨立證據。

### 12.5 P2：收斂資訊與資產

1. 修正 Full Guide、README、WORKSPACE_STRUCTURE 與 adapter drift。
2. 回填 Ready mainline note 的 concrete commits。
3. 整理過期策略文件與 test artifacts。
4. 將成熟 learnings 抽成 prompt、test 或 gate。
5. 在增加新 registry 或 schema 前，先證明現有機制有真實 consumer。

### 12.6 P2：正式啟動 overlay

`yuanxi-sdd-pack` 若要實作，應先：

1. 重新驗證當下 official Spec Kit capability surface。
2. 更新過期 compatibility assumptions。
3. 建立正式 `specs/yuanxi-sdd-pack-v0.1/` feature packet。
4. 完成 specify、clarify、readiness、plan、tasks 與 analyze。
5. 再開始 package scaffold。

## 13. 後續 agent 工作準則

後續維護本 workspace 時，agent 應：

1. 先讀 Studio Constitution。
2. 進入 consumer project 前再讀 Project Constitution。
3. 區分 mainline、local commit、working-tree draft 與 future intent。
4. 發現衝突時明確回報 drift。
5. 不因 shared audit 綠燈就宣稱完整語意收斂。
6. 同時檢查 execution path、negative path 與 consumer evidence。
7. 依 source、dependent、informational 的順序更新。
8. 不補造 Legacy 歷史。
9. 不對未授權 scope 進行實作。
10. 優先讓既有治理被使用，再增加新治理機制。
11. 維護目標是降低記憶負擔與維護熵，不是增加更多長 prompt。

## 14. 結論

這個 workspace 最有價值的部分不是文件數量，也不是 PowerShell 行數，而是它提出了一套
清楚的 AI engineering governance worldview：

- Spec 定義承諾。
- Clarify 清除高風險未知。
- Readiness 判斷規劃安全。
- ECI 治理外部能力。
- Intent ledger 保存被壓縮的原始意圖。
- Plan 與 tasks 建立可追溯執行鏈。
- Analyze 防止 artifact 與 outward-facing truth 漂移。
- Machine gate、tests 與 CI 判斷可重跑 evidence。
- Learnings 把失敗轉成可演進且可退役的環境能力。

這套理念已高度成熟。

目前真正的瓶頸不是缺少更多治理文字，而是：

- Execution graph 尚未完整落實七階段。
- Acceptance oracle 仍以存在與字串作為部分行為的替代證據。
- Consumer adoption 與 shared control plane 不對稱。
- Independent CI 尚未正式生效。
- Experimental workflow 與 extension lifecycle 尚有 correctness 及 safety 缺口。

因此，下一階段最有槓桿的方向是：

> 修正執行圖與驗收 oracle，完成獨立 CI，讓第二個真實 consumer 完整使用既有治理，再
> 決定哪些能力值得抽成可安裝 overlay。

## 15. 主要證據索引

| 主題 | 主要來源 |
|---|---|
| Workspace purpose | `README.md` |
| Highest governance | `studio/constitution/constitution.md` |
| Structure and authority | `WORKSPACE_STRUCTURE.md` |
| Quickstart and usage | `studio/QUICKSTART.md`、`studio/SDD-QUICKSTART-GUIDE.md` |
| Runtime contract | `studio/runtime/shared-runtime-contract.json` |
| Impact routing | `studio/runtime/impact-registry.json` |
| Drift philosophy | `docs/sdd-drift-governance-core-logic.md` |
| Drift implementation design | `docs/sdd-drift-governance-solution.md` |
| Consumer status | `docs/project-governance-status.md` |
| Worktree parity | `docs/project-worktree-parity-governance.md` |
| Knowledge feedback | `studio/knowledge-base/learnings.md` |
| Runtime audit | `studio/scripts/powershell/check-speckit-runtime.ps1` |
| Commit gates | `.githooks/pre-commit.ps1` |
| Stage gates | `studio/scripts/powershell/setup-*.ps1` |
| Workflow runtime | `studio/workflows/`、`studio/scripts/powershell/workflow-engine.ps1` |
| Extension runtime | `studio/extensions/`、`studio/scripts/powershell/*-extension.ps1` |
| Governance tests | `studio/tests/` |
| Overlay direction | `docs/yuanxi_sdd_pack_strategy_zhTW.md` |
| Current deep review | `docs/sdd-workspace-deep-review-2026-07-08_zhTW.md` |
