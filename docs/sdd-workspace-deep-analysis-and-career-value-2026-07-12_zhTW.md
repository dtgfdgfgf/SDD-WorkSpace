---
title: "SDD-WorkSpace 深度環境分析與求職價值評估（2026-07-12）"
version: "1.0.0"
date: "2026-07-12"
language: "zh-TW"
owner: "元熙"
status: "analysis"
authority: "informational"
branch: "feature/wave-3-security-and-workflows"
base_commit: "c6ee1f1 (main)"
head_commit: "60768f3"
scope: "整體 workspace 環境評價、優缺點與缺失、上游 spec-kit 同步策略、公司價值與面試方視角、優先序改善路線圖"
analysis_method: "10 個平行子系統深度讀取（治理核心、runtime contract、agents/prompts、workflow engine、extensions、既有分析整合、上游查證、使用證據、對外呈現、機器語義稽核）+ 3 個面試官 persona 評估 + 改善路線圖設計 + 18 條高重要性論斷對抗驗證（16 確認 / 2 推翻並修正）。所有計數以確定性指令取得。"
source_basis:
  - "studio/constitution/constitution.md v1.8.0"
  - "studio/runtime/shared-runtime-contract.json（1,023 行）"
  - "本機實跑 check-speckit-runtime.ps1 -Json 與 run-governance-tests.ps1（2026-07-12）"
  - "gh api 查證官方 spec-kit releases（2026-07-12）"
  - "docs/sdd-workspace-deep-review-2026-07-08_zhTW.md 及 2026-07-11 增補"
  - "docs/sdd-workspace-purpose-governance-maintenance-usage-analysis-2026-07-11_zhTW.md"
  - "docs/sdd-workspace-wave-3-governance-review-2026-07-12_zhTW.md"
related_documents:
  - "docs/sdd-workspace-deep-review-2026-07-08_zhTW.md"
  - "docs/sdd-workspace-wave-3-governance-review-2026-07-12_zhTW.md"
  - "docs/0308upstreams/spec-kit-upstream-alignment-matrix.md"
---

# SDD-WorkSpace 深度環境分析與求職價值評估（2026-07-12）

## 0. 執行摘要

一句話結論：這是一個「機器驗證層真實且罕見、但治理超前於使用、門面存在多處立即扣分硬傷」的個人 AI 工程治理平台。三位模擬面試官（AI 新創主管、平台/DevOps 主管、懷疑派 staff engineer）一致給出 hire signal = moderate，且一致認為：修掉 P0 四項門面與證據硬傷（約 4 人天）之後，這份作品集才能自洽支撐「治理工程 + 平台工程」的敘事，並有機會把 signal 推向 strong。

三個核心判斷：

1. 工程實質存在，可複驗。runtime contract、稽核、hook、測試、CI 五層機器驗證鏈在本次分析中全部實跑通過，不是 AI 生成的空殼。
2. 最大結構矛盾未變且更清晰：治理機器建在使用停止之後。消費專案活動止於 2026-04-26，而 workflow engine、extensions 強化、CI、wave-3 security 全部建於其後；去重後全 workspace 實際只有 2 份獨立 readiness assessment、1 套獨立 ECI dossier、0 份 intent-ledger、0 次 workflow engine 真實執行。
3. 不需要「跟上」spec-kit，需要的是有紀律的選擇性吸收。上游已到 v0.12.11（2026-07-10），自本地最後對齊點以來 74 個 release、兩次 breaking；既有 wave 決策矩陣模式已被證明有效，缺的是 Wave-4 評估文件與機器可讀 baseline 更新。

## 1. 治理基準與分析範圍

本分析依下列 authority order 執行：

1. `studio/constitution/constitution.md` v1.8.0
2. `.specify/memory/constitution.md`（workspace root 不存在，N/A）
3. Runtime adapters 與 informational documents

範圍：整體 workspace（治理核心、runtime contract 與稽核、agents 與 prompts、workflow engine、extensions、消費端使用證據、對外呈現、上游 spec-kit 對比），時點為 branch `feature/wave-3-security-and-workflows` head `60768f3`（領先 main 13 commits）。本分析為 read-only，未修改任何 runtime、agent、workflow 或 test。

## 2. 量化事實快照（2026-07-12 實測，全部指令取值）

| 項目 | 數值 | 備註 |
|---|---|---|
| git 追蹤檔案總數 | 639 | 其中 392（61%）為 vendored 第三方教材（`resources/github-copilot-configs`） |
| git commits | 68 | 2025-12-09 至 2026-07-12，單一貢獻者，91% conventional |
| PowerShell 腳本 | 38 支，共 9,647 行 | 最大三支：common.ps1 1,393 行、workflow-engine.ps1 677 行、check-speckit-runtime.ps1 508 行 |
| Runtime contract | 1,023 行 JSON | 81 個語義 invariant 條目 + 2 hook invariants，共 377 條 mustContainAll/anchor 斷言（經對抗驗證修正，先前 440 為誤計） |
| Governance 測試 | 18 個 .Tests.ps1、254 個 It | 實跑 253 passed / 0 failed / 1 skipped |
| Runtime 稽核 | VALID=true、0 errors、0 warnings | pwsh 7.5.4 實跑 exit 0；Windows PowerShell 5.1 下 parser error（`??` 運算子） |
| CI | 1 個 workflow（governance.yml） | feature 分支 5 次連續綠 run；main 分支完全沒有 CI |
| Copilot agents | 14 個 `*.agent.md`（目錄共 16 檔） | 全綁 model claude-opus-4-7 |
| Claude agents | 15 檔 | seeded 派生屬實：13 對鏡像正規化後 body 差異 0 行 |
| Prompt stubs | 13 個 | |
| 模板 | 35 個（sdd-docs 28 + project-init 7） | |
| docs/mainline-updates | 25 篇 note + README 索引 | 18 份 Ready notes 仍 Related Commits: TBD |
| readiness assessment | 去重後 2 份獨立（第 3 份為跨專案拷貝） | |
| ECI dossier | 去重後 1 套獨立（另 1 套為 byte-identical 複本） | |
| intent-ledger.md | 0 份 | 憲法 4 個 section 圍繞它建規則，從未被使用 |
| workflow engine 真實執行 | 0 次 | runs/ 只有 .gitkeep、state.json states 為空 |
| extensions | 1 個（extension-smoke），0 enabled | 唯一登錄項自述為煙霧測試件 |
| 上游 spec-kit 最新版 | v0.12.11（2026-07-10） | 自本地最後對齊點 v0.2.0（2026-03-09）以來 74 個 release |

## 3. 總體評價

### 3.1 定位

把「規格驅動開發 + 多 AI 編碼代理協作」從口頭紀律升級成機器可驗證契約 + commit-time 閘門 + CI 的個人 AI 工程治理平台。此價值主張成立，工程完成度遠超一般個人 side project，且本次全部核心宣稱經實跑複驗。

### 3.2 優點（經對抗驗證確認）

1. 五層機器驗證鏈真實且同構：憲法（579 行）翻成 runtime contract（1,023 行、81 invariant 條目、377 條斷言），由 check-speckit-runtime.ps1 單一入口稽核（實跑 VALID=true、exit 0），pre-commit（1,397 行）用 `git checkout-index` 對 staged snapshot 稽核，254 個 Pester 測試鎖定不變量，CI 在 windows-latest 跑同一套（本地驗收面等於 CI 驗收面）。
2. 三個 adapter 的 GENERATED GOVERNANCE BOOTSTRAP 區塊逐位元一致（三檔 md5 相同），且 check-agent-bootstrap.ps1 會核對憲法版本字串。
3. Prompt 被當成受治理的 artifact：agentInvariants 把 readiness/eci/plan/analyze 四個 agent 的關鍵語句納入機器合約。個人 repo 罕見。
4. 自創 readiness agent（495 行）是全 repo 最強 prompt：8 個互斥 primary status、11 條 precedence 規則、route-specific minimum packets；eci agent 雙軸分類（ECI Level 與 Authorization Outcome）設計成熟。
5. workflow engine 是真的可跑的 halt/resume 狀態機：exit 42/43 協定、SHA-256 artifact 指紋防 false-completion、resume 冪等、沙箱化表達式 parser；live 冒煙測試把整條 sdd-pipeline 走通並被 analyze gate 正確攔截。
6. 安全工程閉環完整：6e858d4 path-traversal 加固走完「外部發現、修復置於 mutation 前、負向回歸測試、contract invariant 鎖定、文件化 non-goals/follow-ups」全鏈。
7. 上游治理成熟：非隱性 fork，wave 決策矩陣逐項 adopt/defer/reject，選擇性吸收上游安全修正（PR #1809、#2229/#2296）並轉譯為 PowerShell 重實作加迴歸測試。
8. 自我對抗審查紀律罕見：07-11 分析（編號 claims）、五個修復 commits 逐一引用、07-12 review 再以 file:line 與 negative probe 推翻部分 Ready 宣稱。三位面試官都把這條鏈列為最強可信度資產。
9. 真實交付證據存在但公開不可見：Trading-003 有 git 追蹤 574 個 src .cs + 210 個 test .cs、tasks 57/57 全勾且 100% 符合 canonical 格式；japanese-learning 76 commits（98.7% conventional）。

### 3.3 弱點與缺失（依嚴重度排序）

| 嚴重度 | 發現 | 證據 |
|---|---|---|
| Critical | 治理機器零消費者且建在使用停止之後：消費專案活動止於 2026-04-26，workflow engine（05-05）、extensions 強化、CI、wave-3 全建於其後；0 個 feature 依序走完七階段、intent-ledger 0 份、engine 0 次真實執行 | runs/ 僅 .gitkeep；state.json states 空；find 實測 |
| Critical | 主要賣點不在預設視圖：main 停在 2026-05-04（c6ee1f1）、無 CI、落後 13 commits；CI 綠燈、workflow engine、安全強化全部只在 feature 分支 | `git ls-tree main .github/workflows/` 為空 |
| Critical | 公開 repo 61%（392/639）tracked 檔案是整包 vendored 第三方課程教材且無授權聲明；根目錄亦無 LICENSE | git ls-files 實測；ls 零命中 LICENSE |
| High | 治理管不住自己人：Trading-003 readiness 使用非法狀態 `IMPLEMENTED_AFTER_REMEDIATION`（不在憲法八狀態內）且為實作後補寫；Trading-002 plan.md v0.1（03-14）早於 READY_FOR_PLAN（03-24）；KMS 177 個已勾任務、72 個 py 檔完全未進版控 | readiness-assessment.md:4；plan.md changelog；git ls-files 僅 8 檔 |
| High | 「唯一機器驗收入口」在 Windows PowerShell 5.1 下 parser error（`??` 運算子，:309/:332/:336），38 支腳本 0 支有 `#Requires -Version 7`，入口文件未聲明 pwsh 7 需求 | 實測重現；grep 零命中 |
| High | 稽核腳本自身有假綠 bug：check-speckit-runtime.ps1 約 :151 對 `$warnings` 加入 powershell-yaml 缺失警告，約 :175 才初始化為空陣列，警告必然被清空（對應 GOV-07） | 實碼確認 |
| High | 「Ready」宣稱被同日推翻的模式：三份 2026-07-12 mainline notes 標 Ready，關鍵宣稱（non-bypassable、acceptance signal、stop guessing）被同日 review 推翻；specify agent :163 仍殘留 make informed guesses、:198 仍列 readiness 為 next phase；Ready 狀態機無回滾語義 | 07-12 review GOV-04/05；實測確認 |
| High | implement agent 是最弱一環：仍解析已廢止的 `[P]` 平行標記（與 tasks agent 的 `[P#]`=priority 定義衝突），且無任何 readiness/analyze/intent-ledger gate（有 checklist gate 但可 override）；憲法 Section 8「Critical findings must be fixed before implementation」在 direct slash-command 路徑無執行點 | 經對抗驗證修正後的精確表述 |
| High | wave-3 review 的 9 P1 + 4 P2（GOV-01..13）仍全部 open：reject gate 回 success、DryRun 污染正式狀態、runner 不消費 catalog/state、junction 繞過 lexical containment 等 | docs/sdd-workspace-wave-3-governance-review-2026-07-12_zhTW.md |
| Medium | 鏡像 parity 只驗檔名不驗內容；seed 腳本工具白名單失敗時放寬權限（spec-kit-qa-bot 在 Claude 端變成預設全工具）；缺 -Verify 模式 | check-speckit-runtime.ps1:263-292 |
| Medium | 語言與門面：入口文件全繁中無英文 TL;DR、無 CI badge、README 引用失效檔名、根目錄雜物（bone.ini、網址亂碼檔名、硬編碼路徑腳本、中文文件管理/ 平行副本）、docs/ 兩檔 untracked | 實測 |
| Medium | mustContainAll 的實際強度是防刪除/防漂移，不是防矛盾；dependent adapter 手寫區段無 invariant 覆蓋（copilot-instructions.md:49 的 Current Phase 已漂移至 2025-12 舊值）；「auxiliary」分類在憲法 Section 2、Section 10、contract 三處用語不一致 | 實測 |
| Medium | 缺 open findings 單一總帳：GOV-01..13、E5、F3、18 份 TBD notes、extension P1 follow-ups 散落多處，重建現狀需重讀全部文件 | prior-analyses 整合結果 |
| Low | 流程稅與用量失衡：ECI 四文件 + intent-ledger 九欄 + change manifest + mainline note 的儀式，對應實際使用為 2 份獨立 readiness、1 套獨立 ECI、0 份 ledger | find 實測與去重 |
| Low | studio/prompts/ 六個階段目錄全空；phase freshness 測試將於 2026-08 底左右到期使 CI 變紅 | find 計 0 檔 |

## 4. 是否隨 spec-kit 更新：結論不變、動作更新

### 4.1 上游現況（2026-07-12 gh api 查證）

- 最新 release：v0.12.11（2026-07-10）。自本地最後完整對齊點 v0.2.0（2026-03-09）以來 74 個 release。
- 重大變化：v0.5.0 breaking（不再發布 template zip bundles）、v0.7.0 workflow engine + catalog、v0.9.0 agent-context 抽成 bundled extension、v0.10.0 雙重 breaking（移除 `--ai` 系列改 `--integration`、git 改 opt-in）、2026-06-17 新增 `/speckit.converge`、2026-07-09 起命令模板加入 py: 三語 script 支援。
- 官方命令集無 readiness / eci / discover / version；本地四個自創階段為永久分岔點，且分岔方向是「更嚴」（clarify/analyze 在上游是 optional，本地升為 mandatory）。

### 4.2 判斷

不整包跟版（維持 07-08 結論）。全面同步不可行：上游 breaking 改版圍繞其 CLI/integration 模型，與 studio-first PowerShell 架構正交，且會摧毀 readiness/ECI 原創價值。宣告永久分岔也不對：會放棄上游持續產出的 security/validation 修正（Wave-3 已證明此類吸收有直接收益）。

正確策略是維持既有 wave 選擇性吸收模型，並補齊三個具體缺口：

1. Wave-4 評估文件：對 v0.9.0 至 v0.12.11（含兩次 breaking 與 converge）產出決策矩陣；上游 v0.12.x 的 workflow 修正清單（gate validate crash、fan-in wait_for、quote-aware pipe-filter）與本地 workflow-engine.ps1 逐項比對，可直接當迴歸測試靈感。
2. 更新機器可讀 baseline：get-speckit-version.ps1 回報的 UPSTREAM_BASELINE_DATE=2026-03-06 已 stale；建議改為獨立對齊紀錄檔（如 `studio/upstream/alignment-state.json`），讓版本腳本與 wave notes 共用單一真相。
3. `/speckit.converge` 明確 adopt/adapt/reject 決策：它與本地 analyze completion gate 功能相鄰，放著不決策就是新的 drift 來源。另需修正文件中仍以已刪除的 `--ai*` 旗標描述上游能力之處（export-agent-skills.ps1 等的概念錨點已死）。

求職角度最高槓桿的一步仍是 07-08 已提出的：overlay 化（yuanxi-sdd-pack）並上架官方社群 extension catalog。被 catalog 收錄、一行可裝的治理 extension，比私人 workspace 有力一個量級。此項至今未動。

## 5. 對公司的價值與面試方視角

### 5.1 價值定位

workspace 本身不是公司會買的產品；價值是能力證據，且踩在 2026 年企業導入 AI coding 規模化的真實痛點上：LLM 宣稱完成不等於真的完成、多 agent drift、驗證者與被驗證者同為一個 LLM 的自我指涉。可遷移的核心資產是：

- governance-as-code 四層鏈（contract、audit、hook、CI 同構）
- false-completion 的一線工程解法（SHA-256 指紋 baseline、negative probe、對抗式複驗）
- prompt 作為受治理 artifact 的管理方式
- 成熟的 upstream/fork 治理（wave 決策矩陣）

對應職缺：平台工程、Developer Experience、AI Enablement、內部工具鏈。對純 AI/LLM 應用職缺是輔助證據（缺 eval harness、engine 不呼叫 LLM），主證據仍是 Trading-003 這類真的呼叫 LLM 的專案。

### 5.2 三位模擬面試官的評語（皆為 moderate hire signal）

| Persona | 一句話評語 | 最在意的 red flag |
|---|---|---|
| AI 新創工程主管 | 「近期看過最矛盾的作品集：驗證層品質真實罕見，交付敘事幾乎不可見」 | 缺 prompt eval harness；engine 不呼叫任何 LLM，multi-agent 敘事一講就破 |
| 平台/DevOps 主管 | 「腳本工程與流程即程式碼能力遠高於個人 repo 平均，但產品判斷與收尾紀律有疑慮」 | 蓋了一座沒有住戶的治理大樓；第一次 clone 就撞牆（PS 5.1 parser error） |
| 懷疑派 staff engineer | 「實質存在，但被自己的敘事拖累；一台從未載過客的高鐵」 | 宣稱與實測落差成模式（Ready 被同日推翻、audit 自帶假綠 bug、非法 readiness 狀態） |

### 5.3 面試官會追問的代表性問題（面試準備清單）

1. workflow engine 從未在真實 feature 上執行過，為什麼建完不用？現在跑會先踩到什麼坑？（誠實答案應觸及 script step cwd 分歧與 failed-run 死路）
2. intent-ledger 九欄零實例，而 Trading retrospective 明寫有 evidence-gated partial，正是它該記錄的情境。機制設計哪裡錯了？
3. Trading-003 的 readiness 用了憲法不允許的狀態且實作後補寫。你的 gate 為什麼擋不住你自己？團隊環境下 enforcement 放哪一層？
4. mainline note 宣稱 non-bypassable，同日你自己的 review 就推翻它。這種 LLM 宣稱與實際的落差要怎麼系統性防？（好答案：驗證者獨立性、negative probe、不能用生成者自己的 grep 當驗收）
5. mustContainAll 驗不了行為。給一個最小 eval harness 設計：資料集哪來、判分怎麼做、CI 成本多少？
6. 如果明天要砍一半機制，砍哪些、留哪些、依據是什麼？（測 product sense；期待用自己的使用數據辯護）
7. 上游 74 個 release、兩次 breaking、converge 與你的 analyze gate 相鄰，你的 adopt/reject 決策？
8. 2026-02 與 2026-06 兩整月零 commit、消費專案 4 月後全停，時間怎麼分配的？

### 5.4 呈現建議（三位面試官共識）

1. 敘事定位：說「governed human-in-the-loop SDD pipeline runtime / 帶機器強制閘門的狀態機」，絕不說 multi-agent orchestration engine（engine 不呼叫 LLM，過度宣稱一次毀掉全部可信度）。
2. 開場 demo 三十秒見效：先跑 `pwsh check-speckit-runtime.ps1 -Json` 秀綠燈，再現場改壞一個 invariant 秀紅燈——「閘門會咬人」勝過任何架構圖。demo 指令一律寫 pwsh 前綴。
3. 用 false-completion 故事開場而不是憲法架構：「agent step 原本只做 Test-Path 但 prep script 會預建 artifact，所以 pipeline 假完成」到 SHA-256 指紋修復到迴歸測試到 contract 鎖定。任何 AI infra 團隊秒懂。
4. 主動承認「治理超前使用」，把 07-12 對抗式 review 拿出來當證據：「我會用機器證據推翻自己的 Ready 宣稱」是資深工程師才有的敘事；被面試官先挖出來和自己先講，評價差一個檔次。
5. 避開的話題:不要主動展開 ECI 四文件與 intent-ledger 九欄細節（用量太低，只會引來成本效益追問）;不要提 KMS（無版控證據）;不要使用 non-bypassable、machine-verifiable acceptance 這類絕對詞，改用「防刪除防漂移的字串合約，語義驗證是已知邊界」。
6. 按職位切面：AI/LLM 職位主打 readiness agent 的封閉枚舉與 precedence 設計、prompt 納入機器合約、eval harness roadmap；平台/DevOps 職位主打 contract-driven audit、staged-snapshot pre-commit、本地=CI 同構、path-traversal 加固鏈。

## 6. 改善路線圖（12 項，合計約 13-14 人天）

P0 = 面試前必做（約 4 人天）：

| # | 項目 | 工作量 | 理由 |
|---|---|---|---|
| 1 | 補 LICENSE 並處理 vendored 第三方教材（移除、submodule 化、或補授權聲明三選一） | 0.5 天 | 61% repo 是別人的教材且授權不明，稀釋貢獻、統計失真、授權風險三重硬傷 |
| 2 | 收尾 wave-3 並合併回 main（commit 兩個 untracked docs、主 note 從 Draft 補 Ready 填 commit hashes、誠實列 GOV open findings 為 known issues） | 1 天 | 預設分支看不到 CI、engine、安全強化三大賣點 |
| 3 | PowerShell 7 fail-fast（#Requires 或版本守衛）+ README 環境需求章節 + 修 $warnings 重置假綠 bug | 0.5 天 | 面試官照 README 第一條指令就撞牆；假綠 bug 直傷 verification 敘事 |
| 4 | 建一個公開可見的端到端示範 feature：sdd-pipeline 完整跑 specify 到 analyze、readiness 先於 plan、含一筆真實 intent-ledger、留下 .workflow/state.json 執行證據 | 2 天 | 一個 demo 同時填補「零使用」三大缺口，所有分析組共同指向的最高槓桿項 |

P1 = 明顯提升價值（約 4.5 人天）：

| # | 項目 | 工作量 |
|---|---|---|
| 5 | 修 agent 語義殘留：specify 內部矛盾（:163 informed guesses、:198 readiness next-phase）、implement 的 [P]/[P#] 漂移與缺 gate；re-seed 鏡像並補 contract invariant | 1 天 |
| 6 | README 門面：英文 TL;DR、CI badge、失效引用修正、根目錄雜物清理（bone.ini、亂碼檔名、硬編碼路徑腳本、中文文件管理/） | 1 天 |
| 7 | 補完 extension 安全敘事：export-extensions -OutputDir 邊界檢查、validate-before-mutate + rollback、Test-Json schema 強制（自家 note 已列 P1 follow-up） | 1 天 |
| 8 | 建 open-findings 單一總帳 + 定義 Ready note 被複驗推翻時的回滾規則 | 0.5 天 |
| 9 | 鏡像內容 parity 機器檢查：seed-claude-agents.ps1 加 -Verify 模式納入 audit/CI；修 Convert-ToClaudeTools 失敗時放寬權限的缺陷 | 1 天 |

P2 = 有空再做（約 5-6 人天）：

| # | 項目 | 工作量 |
|---|---|---|
| 10 | workflow engine 恢復語義與 runtime 治理消費（failed-run 可恢復、runner 讀 catalog/state、script step cwd 綁定 ProjectRoot，對應 GOV-01/02/06） | 2 天 |
| 11 | Wave-4 上游評估文件（v0.9.0 至 v0.12.11）+ 機器可讀 baseline 更新 + converge 決策 | 1 天 |
| 12 | 最小 prompt eval harness（固定 spec fixture、跑 agent、assert 輸出結構）——P2 中最值得提前的一項，對 AI/LLM 職缺可能直接把 signal 從 moderate 推向 strong | 2-3 天 |

## 7. 對抗驗證結果

18 條高重要性論斷送對抗驗證：16 條 CONFIRMED、2 條 REFUTED 並修正、0 條 UNCERTAIN。被推翻並已在本文修正的兩條：

1. contract 斷言總數：宣稱 440 條，實測 377 條（多報約 17%）。81 個 invariant 條目與其他規模數字正確。
2. 「implement agent 無任何 gate 且是唯一無 gate 的階段」：精確表述為 implement 無 readiness/analyze/intent-ledger 治理 gate（但有可 override 的 checklist gate 與 -RequireTasks 檔案檢查）；tasks agent 的 agent 層 gate 同樣為零；plan agent 的 readiness gate 區段為 7 條 ERROR（全檔 12 行含 ERROR），非 9 條。

另有兩條 CONFIRMED 但補充精確化：readiness/ECI 使用量去重後更低（2 份獨立 readiness、1 套獨立 ECI dossier）；pwsh 依賴為「未正式宣告、未強制」（shebang 與部分文件有 pwsh 意圖，但無 #Requires 與 fail-fast）。

## 8. 已知限制

1. 未驗證 GitHub 外部狀態（branch protection、hosted Actions 完整歷史）；CI 綠燈證據來自 gh run list（feature 分支 5 次成功 run，2026-07-11）。
2. 行號以 head commit 60768f3 為準，後續修復可能位移。
3. 面試官評估為模擬 persona 判斷，供準備參考，非真實市場回饋。
4. 上游查證時點為 2026-07-12，spec-kit 每週多個 release，細節會快速過期；結論層（wave 選擇性吸收）預期穩定。

## 9. 與既有分析的關係

本文是 07-08 深評、07-11 目的分析、07-12 wave-3 review 之後的第四份 workspace 級記錄，定位為「求職視角的全景重整」。相對既有分析的增量：

1. 全部核心數字重新以指令取值並經對抗驗證（修正 440 條斷言為 377 條、readiness/ECI 去重計數）。
2. 新確認 CI 已存在且 feature 分支 5 次綠 run（07-08 時點 CI 尚不存在）、learnings 已回填。
3. 新聚焦門面硬傷的量化：61% vendored 檔案、main 無 CI、PS 5.1 parser error 均為此前分析未量化或未強調的第一印象殺手。
4. 上游知識水位從 v0.12.6（07-08 查證）推進到 v0.12.11，並確認 py: 三語 script 支援等新變化。
5. 三 persona 面試官模擬與 12 項優先序路線圖為本文新增，直接服務求職準備。

既有分析的結論（治理閉環是核心資產、治理與交付失衡、overlay 化是最高槓桿、wave-3 暫不 merge）全部維持有效，本文未推翻任何舊結論。
