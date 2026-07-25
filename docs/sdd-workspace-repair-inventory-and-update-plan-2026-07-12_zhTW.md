---
title: "SDD-WorkSpace 共享層修復總清單與全面更新計畫（2026-07-12）"
version: "1.39.0"
date: "2026-07-12"
last_updated: "2026-07-26"
language: "zh-TW"
owner: "元熙"
status: "repair-in-progress"
authority: "informational"
finding_status_authority: "source_of_truth"
finding_status_selector: "finding-status-record-v1"
finding_status_schema: "studio/runtime/finding-status-record.schema.json"
finding_status_validator: "studio/scripts/powershell/validate-finding-status-ledger.ps1"
finding_status_index: "docs/README.md"
branch: "feature/wave-3-security-and-workflows"
base_commit: "c6ee1f1 (main)"
head_commit: "b63dff89fda341c3d291e48a57403458d5033deb"
scope: "Workspace 共享層（studio/、.github/、.claude/、.githooks/、根目錄 adapter 與文件、docs/ 治理文件、遠端設定）。原則上排除 projects/ 與 learning/ 內部 consumer drift；R-D12 為受控例外，只允許完成 shared agent 安全遷移所需的 project-local runtime 檢查。"
analysis_method: "兩輪多 agent 調查合併：第一輪 32 agents（10 個子系統深讀 + 機器語義稽核 + 18 條論斷對抗驗證，16 確認 2 推翻）；第二輪 4 agents（docs 逐檔盤點、根目錄與設定衛生、studio 層盤點、完整性批判）；第三輪於 2026-07-13 由 Codex 主代理加 3 個獨立驗證代理逐項複核 owner decisions、本機證據與官方外部來源。第三輪以 section-bounded parser 重算第 3 節 findings 與嚴重度，作為取代初版錯誤摘要的 canonical count。第四輪於 2026-07-13 由 Claude 主代理對 R2 partial 做唯讀獨立驗證（5 個對抗驗證代理 + 舊實作 mutation 實測 + 提交前 2 代理對抗 review），發現 R-A15、R-A16、R-B17、R-B18。"
purpose: "以環境修復角度列出共享層全部已知問題（單一總帳），記錄 18 項 owner 裁定，並排定風險優先的分批更新順序。本檔同時作為 open-findings ledger 的起始版本。"
related_documents:
  - "docs/sdd-workspace-wave-3-governance-review-2026-07-12_zhTW.md"
  - "docs/sdd-workspace-deep-analysis-and-career-value-2026-07-12_zhTW.md"
  - "docs/sdd-workspace-deep-review-2026-07-08_zhTW.md"
---

# SDD-WorkSpace 共享層修復總清單與全面更新計畫（2026-07-12）

## 0. 執行摘要

第 3 節在 v1.1.0 逐列機器重算後共有 109 條 findings；R0 staged-snapshot 驗收再發現並新增 R-A14；2026-07-13 R2 唯讀獨立驗證再發現 R-A15、R-A16、R-B17、R-B18 四條；2026-07-14 治理 re-review 的 12 條 RVR findings 再新增 9 條（R-A17/A18/A19、R-B19/B20/B21/B22、R-C08、R-F06）；2026-07-15 RB-1 獨立複核再新增 R-B23；2026-07-18 RB-2 對抗複核再新增 R-B24；2026-07-20 RB-3 新增 R-A20 與 R-A21；2026-07-20 RB-5 新增 High R-A22；2026-07-21 R6 residual audit 再新增 R-B25 與 R-B26；2026-07-22 R6-A1 preflight 再新增 R-H20；2026-07-23 R6-A5 preflight 再新增 Medium R-E13；2026-07-26 owner 於 canonical pwsh 7 終端（CP950 console）重現 elevated fixture 失敗後再新增 Medium R-A23。因此目前為 133 條，編為 R-A01 至 R-A23、R-B01 至 R-B26、其餘區域至 R-H20 與 R-J03。現況分佈：Critical 8、High 32、Medium 54、Low 39。初版摘要所寫 95 條與 7/17/40/31 分佈是計數錯誤，已在 v1.1.0 修正；R-A14 之後的新 findings 均附獨立回歸證據。

**2026-07-14 誠實性還原（R2.1）**：2026-07-14 re-review 以本地反例推翻兩項先前 `COMPLETED` 宣稱。R-B02（RVR-01：換掉 tasks.md 為非 task 文字仍 completed）與 R-B05（RVR-03：`[bool]'false'`=`True`、missing-state 沿用 default）改回 `IN_PROGRESS`，closure 分別移交 R-B19、R-B20。`docs/mainline-updates/2026-07-14-r2-workflow-engine-integrity.md` 依 note 狀態機降回 `Draft` 並加 Revalidation。12 條 RVR 的完整對映與批次見第 16 節與 `docs/sdd-workspace-wave-3-remediation-plan-2026-07-14_zhTW.md`。

**2026-07-15 RB-1 Critical 止血完成**：implementation commits `cb43de5`、`961df61` 關閉 RVR-01、RVR-02、RVR-03，完成 R-B19、R-D02、R-B08、R-B20，並以新的判別性證據恢復 R-B02、R-B05 的 `COMPLETED` 狀態。post-commit 獨立複核另辨識全面 RunState 與 sidecar 真偽邊界，依 ledger 規則新增 High finding R-B23；已修復的單獨 cache 縮減、sidecar 缺失、格式損壞與 identity mismatch 不重複列入 R-B23。詳見第 17 節。RB-1 完成後分支仍 `NOT READY TO MERGE`；RB-2 至 RB-5 與 R6 仍是必要批次，`sdd-pipeline` 維持 experimental 與 denied。

**2026-07-18 RB-1 誠實性再還原**：RB-2 對抗複核證明 listing 與 runner 並未使用同一完整授權判準。manifest version 與 catalog version 不符時，listing 仍回報 `executionAuthorized=true`，runner 才拒絕 identity mismatch。這項反例推翻 R-B20/R-B05 的完整 closure 宣稱，但不推翻已驗證的 strict Boolean、missing-state、wrong-type、null、scalar 與 schema-substitution 修復。依 ledger 與 note 狀態機，R-B20/R-B05 先回到 `IN_PROGRESS`，RB-1 note 降回 `Draft`；日期化證據與重新進入條件見第 18 節。

**2026-07-18 R-B10 誠實性還原**：RB-2 的 restart 對抗複核固定時鐘並連續執行兩次
`-Restart`，證明既有 archive 名稱只精確到秒且使用 `Move-Item -Force`；第二次 restart
覆寫第一份 archive，使第一個 run identity 與 state 證據遺失。這推翻 R-B10 的 archive
保留子宣稱，但不推翻顯式 `-Restart` 已能讓 terminal 與 in-flight run 重新開始的既有修復。
R-B10 先回到 `IN_PROGRESS`，並新增 Medium finding R-B24；日期化證據與重新進入條件見第
19 節。

**2026-07-18 RB-2 執行身分、ECI routing 與對抗修復完成**：implementation commit
`ec25c07` 完成 R-B21、R-B07、R-B22，並修復本批對抗複核揭露的共用 workflow 授權與
restart archive 缺口，使 R-B20/R-B05、R-B10/R-B24 恢復 `COMPLETED`。舊實作 overlay
在 R-B21、ECI validator、direct Plan、outcome/re-entry 判別組分別只有 1/13、0/25、
1/13、0/9 通過；現行 focused suite 353 passed / 0 failed、完整 governance suite
579 passed / 0 failed，runtime audit 為 `VALID=true`、0 errors、0 warnings。總數維持
125 條（Critical 8、High 29、Medium 50、Low 38），沒有新增 finding。R-B23、R-A17、
R-A18 仍 `OPEN`；PR #3 仍 `NOT READY TO MERGE`，RB-3 至 RB-5 與 R6 仍須完成，
`sdd-pipeline` 維持 experimental 與 execution-denied。完整範圍與殘留見第 20 節。

**2026-07-20 RB-3 合併證據完整性完成**：implementation commit `4f757e5` 關閉
R-A17、R-A18，並新增及完成 High R-A20，明確分開 coherent Batch closure 與 Aggregate
merge readiness。category-complete shared roots、rename old/new preservation、BaseRef
強制、Git commit 與 repository identity、truthful Markdown surface、governed non-note
shared-path coverage 與 canonical Aggregate anchor 均有判別性測試。舊版 34 個
discriminating negatives 通過 0 個，現行 focused suites 134 passed / 0 failed。另新增
Medium R-A21 記錄 middle `/**/` 無法匹配零層目錄的殘留；它不影響本批三個 suffix
`/**` shared roots，也不得被本批吸收。ledger 現為 127 條（Critical 8、High 30、
Medium 51、Low 38）。Batch 可 Ready，但 Aggregate 仍只因 Wave-3 umbrella note 為
Draft 而 fail-closed；PR #3 仍 `NOT READY TO MERGE`。詳見第 21 節。

**2026-07-20 RB-4 extension、consumer、upgrade 邊界完成**：implementation commit
`9819e30` 完成 R-C01、R-C02、R-C03、R-C05、R-C07、R-C08、R-A19 與 R-F06。
R-C03 是 owner 於 RB-4 preflight 明確核准的必要相依，因 schema-violation 批次閘門
無法在 schema 仍未執行時成立。Extension 使用 schema、實體路徑、content-bound
approval、交易 rollback 與 mirror invalidation 的同一 fail-closed 判準；worktree hook
改為 worktree-local，consumer junction 不進 Git intake；upgrade 只以 frozen trusted
authority 驗 passive candidate bytes，並使用完整 baseline、atomic promotion/rollback
與 durable recovery journal。舊版 extension 判別組通過 1/21、upgrade 0/17，
worktree/consumer 三項判別 assertion 全失敗；現行完整 governance suite 664 passed /
0 failed，runtime audit 為 `VALID=true`、0 errors、0 warnings。R-C04、R-C06 與 R-F04
保持 `OPEN`，不由本批吸收；ledger 維持 127 條與既有嚴重度分布。RB-5 與 R6 仍未完成，
PR #3 仍 `NOT READY TO MERGE`。詳見第 22 節。

**2026-07-20 RB-5 agent、authority、process 真實性完成**：implementation commit
`78c47eb0f3da7e75f3ba79943ea44f55984677a1` 完成 R-D01、R-D04、R-D05 與
R-E07，並建立新 High finding R-A22 的 fail-closed 歷史證據框架；migration commit
`26da9a7412d902f2dfff48df23d04662687f4a9d` 封存 18 份歷史 note 的精確 Git
證據，完成 R-A22。17 份 note 恢復為 `Merged`、`Closed`，一份因廣泛 closure
宣稱不實而保持 `Draft`、`Open`。R-E09 只有這 18 份歷史 note 子項完成，Wave-3
umbrella note 與最終 merge accounting 仍留 R6，因此 R-E09 維持 `IN_PROGRESS`。
ledger 現為 128 條（Critical 8、High 31、Medium 51、Low 38）。RB-5 使分支更接近
可合併，但 R6 仍未完成，PR #3 仍 `NOT READY TO MERGE`。詳見第 23 節。

**2026-07-20 RB-5 post-accounting 誠實性還原**：accounting commit
`64669c43d531d9dd699d60e163e7b1c755d64963` 後的必要閘門推翻 RB-5 Ready 與
R-A22 closure。完整 Pester 仍為 737 passed / 0 failed / 0 skipped，但 runtime audit
為 `VALID=false` 且有一個 `historical-evidence-sealed-snapshot-mismatch`；Batch 為
22 errors，Aggregate 為 19 errors。R-D01、R-D04、R-D05 與 R-E07 維持
`COMPLETED`，R-A22 還原為 `IN_PROGRESS`，R-E09 維持 `IN_PROGRESS`。ledger 總數與
嚴重度仍為 128 條及 Critical 8、High 31、Medium 51、Low 38。RB-5 修復完成前不得
進入 R6；詳見第 24 節。

**2026-07-20 RB-5 sealed baseline repair 完成**：repair commit
`3666c4e9a6553ff82774d4a06037f48846d8b0fd` 以 exact five-field production
metadata shape 修復 historical baseline reconstruction。Committed runtime audit 為
`VALID=true`、0 errors、0 warnings，historical sealed evidence 為 18/18；dedicated
validator file 為 91 passed / 0 failed。Production positive 通過，`TwoField`、
`ExtraField`、`SubstitutedField`、`WrongType` 與 `Null` 全部被拒絕，contract anchor
也阻擋舊 `Count=2` shortcut revert。R-A22 恢復 `COMPLETED`，R-E09 維持
`IN_PROGRESS`；ledger 總數與嚴重度仍為 128 條及 Critical 8、High 31、Medium 51、
Low 38。RB-5 完成，R6 是下一批；final accounting gates 尚待本次文件更新後重跑，
詳見第 25 節。

2026-07-13 owner decision review 已完成。第 6 節以 18 個「邏輯決策」記錄裁定；原表實際為 17 列、19 個 finding ID，其中 R-F04/R-H15 是同一能力鏈，R-I07/R-I08 則拆成兩個獨立清理決策。所有裁定均已標明執行時序與驗收邊界。

四個結構性重點：

1. 最高風險不在本機而在遠端：main 分支無任何 branch protection，mainline-note 與 hook 治理只存在本機，`--no-verify` 或未裝 hook 的 clone 可直推 main 繞過全部治理（R-J01；此為原始風險敘述，已於第 12 節關閉）。
2. 驗證層自身有兩個實 bug（`$warnings` 假綠、workflow registry invalid 不升格 failure）加一個環境地雷（PS 5.1 parser error），「唯一機器驗收面」需要先自我修復（R-A01、R-A02、R-A05）。
3. workflow engine 的 13 條 GOV findings 全部 open，catalog 卻仍標 approved/core/default-enabled；修復前先降級是一行可完成的止血（R-B09）。
4. 「很久沒更新」的實體是三群：docs/ 的 2026-03 至 05 執行基準文件（yuanxi pack、0308upstreams、governance-status 台帳）、上游對齊面（baseline 停 2026-03-06、上游已 v0.12.11），以及一批未實際採用或只有形式消費的閒置資產（0 份真實 change manifest、0 個已產出/安裝 skill pack、空 feature-packs/studio-tools/prompts 目錄）。

2026-07-13 R1 收尾已解除第一項風險：PR #3 的 hosted `audit-and-tests` 已在 head
`f601685` 成功，GitHub ruleset `18842326` 已 active 並使 `main.protected=true`；規則要求 PR、
strict `audit-and-tests`，且禁止刪除與 non-fast-forward 更新。第 2 節仍保留為原始日期快照，
目前狀態以第 11、12 節的執行增補為準。

2026-07-13 R2 已由 PR #3 的兩個 review threads 啟動。commit `29adc67` 修復 script child
process 的 ProjectRoot cwd，並把 plan prep、operator handoff 與 plan agent path discovery 綁定
至明確 workflow feature。這只關閉 R-B06 的兩個 dispatch/context 子問題；RunState relocation、
canonical feature-ID 分裂與其餘 R2 findings 仍待處理，因此 R-B06 與 R2 均保持 IN_PROGRESS。

2026-07-13 的唯讀獨立驗證（第四輪）確認上述兩項修復屬實、PR #3 兩個 review threads 可維持
resolved；驗證發現的 R-A15、R-B17、R-A16 已由 commit `df31106` 修復（見第 14 節），R-B18
保持 open。

建議按第 5 節的 7 個風險優先批次執行。完整執行前四批 R0 至 R3 粗估 11 至 18 人天；目前 131 條完整收斂粗估仍為 21 至 35 人天（此為原 backlog 估算；2026-07-14 RVR 新增 9 條與 RB-1 至 RB-5+R6 的追加工時見 remediation plan；R-B23、R-A21、R-B25、R-B26 與 R-H20 另依日期化增補處理）。每批以 `check-speckit-runtime.ps1 -Json` ERROR_COUNT=0、Pester 全綠、該批新增 negative tests 與批次專屬驗收條件收尾，並依憲法補 mainline note。工期是重新估算區間，不是承諾值；RB-4、RB-5、R6 與其他未完成 findings 在實作時仍須依當下證據調整。

## 1. 範圍與排除

納入：studio/（scripts、runtime、templates、tests、workflows、extensions、knowledge-base、prompts、upstream、tools）、.github/（agents、prompts、workflows、skills）、.claude/、.githooks/、根目錄檔案與 adapter、docs/ 治理與分析文件、.vscode/、.gitignore/.gitattributes、GitHub 遠端設定與 commit 身分。

排除（owner 裁定）：`projects/` 與 `learning/` 內部的 spec 產物、readiness 狀態、憲法副本等既有 consumer drift。兩個窄例外是：以全新 fixture 補 shared mechanism 驗收證據（R-J03）；以及為了安全移除 shared `async-python-reviewer` 而確認/補足 japanese-learning 的 project-local agent overlay（R-D12）。兩者都不得擴張成舊 consumer 的全面修復。

## 2. 驗證快照（2026-07-12）

| 檢查 | 結果 |
|---|---|
| `check-speckit-runtime.ps1 -Json`（pwsh 7.5.4） | VALID=true、0 errors、0 warnings、exit 0 |
| 同一腳本（Windows PowerShell 5.1） | ParserError（`??` 於 :309/:332/:336） |
| `run-governance-tests.ps1` | 254 tests：253 passed / 0 failed / 1 skipped |
| CI（governance.yml，feature 分支） | 5 次連續綠 run（2026-07-11） |
| `gh api .../branches/main/protection` | 404 Branch not protected |
| git 追蹤檔案 | 639（其中 resources/github-copilot-configs 392） |
| 帶 UTF-8 BOM 的 tracked 檔 | 29，全部在 .claude/ 下；.github/agents 源檔皆無 BOM |
| docs/mainline-updates | 25 note：Ready 24（其中 18 份 Related Commits 全 TBD）、Draft 1 |
| 上游 spec-kit | v0.12.11（2026-07-10）；本地 baseline 2026-03-06 |

### 2.1 2026-07-13 決策複核增補

| 檢查 | 結果 |
|---|---|
| `check-speckit-runtime.ps1 -Json`（pwsh 7） | 再驗 VALID=true、0 failures、0 warnings；因此只能證明現有 contract 通過，不能推翻 R-A01/R-A02 的 false-negative 缺口 |
| `run-governance-tests.ps1 -Output Minimal` | 254 tests：253 passed / 0 failed / 1 skipped；與 2026-07-12 快照一致 |
| Windows PowerShell 5.1 | 再驗於 `??` 語法處 ParserError；R-A05 成立 |
| GitHub repo | PUBLIC、licenseInfo=null、main branch protection 仍為 404；R-H01/R-J01 成立 |
| `resources/github-copilot-configs/` | 392 tracked files；來源 repo 無 root LICENSE，且 2026-06-01 已移除其同步 agents，現有 installer 不再有有效更新路徑 |
| agent model pin | 15 份 `.github` source 加 15 份 `.claude` mirror pin `claude-opus-4-7`；Opus 4.7 仍為 Active，故問題是模型政策與可攜性，不是迫近退役 |
| skills export/install chain | 並非零引用：`install-agent-skills.ps1` 呼叫 exporter，`upgrade-studio-runtime.ps1` 亦有 active caller；owner 仍裁定退役整條能力鏈 |
| change manifest chain | 憲法未要求；hook 只在 manifest 已 staged 時 advisory；owner 裁定退役並把 reconciliation 併入 mainline note / merge CI |

本增補只修正原盤點的事實前提與處置方向，不代表任何 runtime finding 已完成。

## 3. 修復總清單

嚴重度定義：Critical = 治理保證失效或有實際風險面；High = 明確錯誤或即將爆炸的時間炸彈；Medium = 一致性缺口與漂移源；Low = 衛生與收斂項。標記 `[OWNER DECIDED 2026-07-13]` 表示方向已由 owner 裁定，但仍須依第 5 節順序實作與驗收；它不等於 finding 已完成。

### A. 驗證層與稽核（audit、contract、hook、測試）

| ID | 嚴重度 | 問題 | 修復動作 |
|---|---|---|---|
| R-A01 | High | check-speckit-runtime.ps1 約 :151 對 `$warnings` 加入 powershell-yaml 缺失警告，約 :175 才 `$warnings = @()` 初始化，警告必然被清空（GOV-07 假綠成因之一） | 把 issue collections 初始化移到函式最前；補 missing-module negative test |
| R-A02 | High | overall VALID 只依 `$failures`：STUDIO_WORKFLOW_REGISTRY_VALID=false、catalog/state schema 未套用、workflow dependency 缺失都不會使 audit 變紅（GOV-07） | 把 required runtime dependency 與 registry/schema/cross-ledger invalid 升格為 failures；補 missing-state、invalid-catalog negative tests |
| R-A03 | Low | `$workflowSemanticChecks` 在缺 contract 分支未預先初始化（:192-201 清單漏掉），輸出會是 null 而非 [] | 補進預初始化清單 |
| R-A04 | Medium | .github/agents 封閉檢查只 filter `speckit.*.agent.md`（:206），非 speckit 檔案不受 contract 治理；.claude/agents 卻是全目錄封閉，同一治理意圖兩種強度 | 統一封閉語義：非 speckit 檔案改為顯式白名單申報，未申報即 unexpected failure |
| R-A05 | High | 38 支腳本 0 支有 `#Requires -Version 7`；PS 5.1 下得到亂碼 parser error 而非版本提示；README、QUICKSTART、憲法皆未宣告 pwsh 7 前置需求 | 全部腳本加 `#Requires -Version 7`（或入口統一版本守衛）；README 與兩份 QUICKSTART 加「環境需求」章節 |
| R-A06 | Medium | audit 主流程無端到端壞狀態 fixture 測試（check-speckit-runtime.Tests.ps1 只測 helper）；唯一 skipped 測試（powershell-yaml 缺席路徑）在本機與 CI 永不執行 | 建立壞狀態 fixture workspace（缺 agent、stale registry、invalid catalog），斷言 audit 正確變紅；以 PSModulePath 隔離讓 skipped 路徑可測 |
| R-A07 | Low | requiredCommands = mandatory 聯集 auxiliary 的不變量只在 Pester 驗，audit 本身不驗 | 在 audit 加同一斷言，使單跑 audit 也能抓到 |
| R-A08 | Low | run-governance-tests.ps1 未啟用 Pester code coverage，254 個測試對 9,647 行腳本的行覆蓋率未知 | 開啟 coverage 輸出（至少 CI 上），記錄基線 |
| R-A09 | Medium | mainline note 狀態機無機器驗證：template 明文「Ready 而全 TBD 即 invalid」，pre-commit（:968-984）只驗 note 存在不驗狀態，18 份違規長期綠燈 | pre-commit 或 audit 加「Status: Ready 或 Merged 的 note 不得 Related Commits 全 TBD」檢查 |
| R-A10 | Medium | 憲法 §10 對 agent-scoped subset adapter（.github/agents/copilot-instructions.md）的三條 MUST（Authority 註解、禁自帶 bootstrap block、不得矛盾）在 audit、hook、contract 全部零強制 | check-agent-bootstrap.ps1 加檢查：檔首 HTML comment 含 `Authority: dependent`、全文不含 `BEGIN GENERATED GOVERNANCE BOOTSTRAP` |
| R-A11 | Medium | BOM 問題有根因：seed-claude-agents.ps1:13 用 `UTF8Encoding($true)` 主動輸出 BOM，29 個 BOM tracked 檔全在 .claude/；另有兩個一次性備份目錄共 16 檔被 commit（.claude/.agent-no-bom-resave-backup/、.agent-seed-rebuild-backup/）。只清 BOM 不改腳本會在下次 reseed 復原 | 腳本改 `UTF8Encoding($false)`；重 seed 15 個鏡像；git rm 兩個備份目錄並在 .gitignore 加 `.claude/.agent-*-backup/`；加 BOM 斷言（檔首 3 bytes 不得為 EF BB BF）防回歸 |
| R-A12 | Medium | 無 .gitattributes：行尾一致性只靠本機 core.autocrlf=input，他機 clone（Windows 預設 autocrlf=true）工作樹會變 CRLF，影響 hash/parity 驗證與 hook 行為；BOM 政策亦無 repo 層宣告 | 新增 .gitattributes（`* text=auto`、ps1/md/yml/json 定 eol=lf、影像標 binary）；文件明文化「UTF-8 無 BOM、LF」政策；與 R-A11 同批 |
| R-A13 | Low | 377 條 mustContainAll 字串斷言防刪除不防矛盾，維護成本隨文件改寫成長；anchor 機制僅 7 個試點 | 策略項：訂 anchor 全面替換路線圖或明文接受字串斷言邊界（與 R-E06 敘述精確化呼應） |
| R-A14 | Medium | [R0 DISCOVERED 2026-07-13] pre-commit 對所有 staged-touched 的 nested `.github/copilot-instructions.md` 都推導 project root；整個 nested source tree 已刪除時仍對不存在目錄做 `Resolve-Path`，誤報三個 adapter 必須同步並阻擋合法清理 | 只對 commit 後仍存在的推導 project root 執行 adapter bootstrap 驗證；刪單一 adapter 而 project root 仍存在時繼續 fail；新增 removed-root regression test 與 contract invariant |
| R-A15 | High | [R2-VERIFY DISCOVERED 2026-07-13] pre-commit 個資 gate 在非 UTF-8 console（zh-TW CP950）下靜默放行 `履歷/`：git 原始 UTF-8 路徑 bytes 經 `[Console]::OutputEncoding` 錯解為確定性亂碼，regex 永不命中且 fail-closed 防線不觸發；CI 綠燈僅因 runner console 是 UTF-8，本機全套曾為 326 passed / 2 failed | hook 開頭強制 UTF-8 解碼並 fail closed；check-speckit-runtime 於輸出重導時對稱強制 UTF-8；新增 CP437 console 回歸測試與 contract token |
| R-A16 | Medium | [R2-VERIFY DISCOVERED 2026-07-13] `sdd-pipeline-plan-feature-context` 的 args token 在 workflow.yml 出現 6 次（5 次先於 R-B06 修復存在），單獨 revert stage-plan-prep 該行 audit 仍綠；能抓到 revert 的 Pester 斷言掛在 powershell-yaml 可用性 skip 上 | 以錨定 stage-plan-prep 區塊的多行 token 取代三個鬆散 token；以模擬 revert 驗證 token 會斷 |
| R-A17 | High | [RVR-05 2026-07-14] production `sharedGatePaths` 只列 39 支腳本中的 17 支（add/remove/export extension、init、setup-*、create-new-feature、validate-feature-structure、export-agent-skills 等不在），`.githooks/commit-msg.ps1` 與 `studio/extensions/` 亦無等同封閉集；branch diff 用 `git diff --name-only`，rename detection 只回 destination，governed source 可被 rename 到 gate 外而 validator 看不到舊路徑；測試 fixture 用理想化整層規則遮蔽 production drift | `sharedGatePaths` 改 category-complete path rules（`studio/scripts/powershell/**`、`.githooks/**`、`studio/extensions/**`）；branch diff 改 `--name-status` 保留 rename old+new；fixture 對齊 production contract；補漏列 script 與 rename-out negative tests |
| R-A18 | High | [RVR-06 2026-07-14] Ready-note validator 只驗字串 shape：任意 7-40 位 hex 算 commit evidence、任意 `#N` 算 PR、reconciliation 只需非空；不驗 commit object 是否存在、是否屬本次 branch diff、PR 是否屬正確 repo、required sections 是否齊備；不存在的 `deadbee` 可通過，fixture 自身用非 Git repo 的 `abcdef1`；主 Wave-3 note 仍 Draft/TBD 時只要其他小 note 是 Ready 整批 aggregate diff 就能通過 `-RequireReady` | validator 驗 commit 存在且在 branch diff、PR 屬正確 repo、required sections（scope/impact/validation）齊備、evidence 覆蓋 branch diff；主 Wave-3 note Draft/TBD 時不得由小 note 代替整批 readiness |
| R-A19 | High | [RVR-09 2026-07-14] `new-project-worktree.ps1` 在 target 執行一般 `git config core.hooksPath`，但 linked worktree 預設共用 repository config，且寫入值以 target 深度相對計算；不同深度的新 worktree 會改壞 source 與其他 worktree 的 hooks path。project init 建立的 `.github/agents`/`.claude/agents` junction 內容未被 template `.gitignore` 忽略，fresh consumer 一般 `git status` 會列出 shared agent files、`git add .` 可把 canonical agent vendoring 進 consumer——與 `WORKSPACE_STRUCTURE.md` 宣稱矛盾 | worktree 改 worktree-safe hooks 設定（per-worktree 或 extensions.worktreeConfig），不改寫 source/其他 worktree；fresh consumer `git status` 不展開 shared junction 內容；與 WORKSPACE_STRUCTURE 對齊；補不同深度 worktree 與 fresh-consumer status negative tests |

### B. Workflow engine 與 workflow registry

| ID | 嚴重度 | 問題 | 修復動作 |
|---|---|---|---|
| R-B01 | Critical | GOV-01：gate 被 reject 或在 pending 前預先 confirm 都回 Status=success 繼續執行；built-in gates 無 on_reject，「acknowledge and halt」並非 terminal halt | decision 只能作用於 current_step_id 指向的 pending gate；無 on_reject 時 reject 必須 halt 或進入明確 terminal state；補 reject/preconfirm negative tests |
| R-B02 | Critical | GOV-02：implement step 以整檔 tasks.md SHA-256 變更為完成證據，改一個 checkbox 即整條 pipeline completed；`-AcceptAgent` 可替代完成證據 | terminal implement step 加 postcondition validator（零 pending canonical task）；terminal step 禁用 generic -AcceptAgent |
| R-B03 | Critical | GOV-03：DryRun 寫入 completed_steps 並保存 RunState，下次正式 resume 將未執行步驟視為 skipped-completed | DryRun 使用 ephemeral state 或完全不寫 RunState |
| R-B04 | High | GOV-13：step ID 不驗全域唯一，重複 ID 的第二個 step 被 skipped-completed、gate 共用 decision | validator 執行前遞迴收集全部 step ID 拒絕碰撞；補 collision tests |
| R-B05 | Critical | GOV-06：run-workflow.ps1 完全不讀 catalog/state/manifest，disabled、rejected、uncataloged workflow 只要目錄存在就能執行；list-workflows 的 VALID 不套 schema、JSON 發現 errors 仍 exit 0；現有 engine 測試以 uncataloged fixture 為正常路徑 | 執行前 fail-closed 驗證 catalog、review/trust、effective enabled、version pin、manifest identity；補 rejected/disabled/uncataloged negative tests；測試 fixture 改走合法註冊路徑 |
| R-B06 | High | GOV-08：fresh run 先建 specs/<feature>/.workflow/ 目錄導致 Specify 編號分裂；script step 相對參數以 caller cwd 解析、與 ProjectRoot 可分歧（live 重現）；stage-plan-prep 不傳 -Feature | RunState 移至不佔用 canonical feature ID 的位置或讓 Specify 嚴格使用 preallocated ID；child scripts 一律在 ProjectRoot 執行並接收絕對 FeatureDir |
| R-B07 | High | GOV-09：pipeline 的 ECI step 只驗 authorization-record.md 非四件 dossier；READY_FOR_MAINLINE_IMPLEMENTATION 後的「re-run readiness」只是 gate prompt，前次 Readiness step 因 completed_steps 被跳過 | ECI step 驗 full dossier；成功後顯式回到新的 Readiness 評估並依最新 primary status 重新 routing |
| R-B08 | Medium | GOV-10：analyze agent 明定 strictly read-only，workflow 卻要求 analysis-checklist.md hash 改變才算完成，依賴未規格化的人工轉錄 | 定義單一 machine-readable analyze result artifact，或把 operator 轉錄/sign-off 建模為獨立 gate |
| R-B09 | High | GOV-11：catalog 標 sdd-pipeline reviewStatus=approved、trustLevel=core、defaultEnabled=true，但 GOV P1 未修、主 note 仍 Draft、promotion 前提（e2e consumer run）未完成 | 立即降級 experimental 且 defaultEnabled=false；Gate 2 至 6 完成後以新 approvedAt/approvedBy 重新 promotion |
| R-B10 | Medium | failed run 永久死亡：status=failed 直接 throw 不可 resume，連 analyze gate 合法攔截也把 run 打死，只能刪 state.json 喪失全部進度 | 新增可恢復語義（-Restart 或 governance-blocked 專屬狀態） |
| R-B11 | Low | run-workflow -Json 失敗時 payload 不帶 `$result.Error`，操作員只見 STATUS=failed | 失敗 payload 帶錯誤細節 |
| R-B12 | Low | replay-from-top 使 history 隨 resume 次數近似 O(n^2) 膨脹（live 驗證） | resume 不重複記錄 skipped 條目，或 history 去重 |
| R-B13 | Low | engine 測試把 fixture workflow 寫進真實 studio/workflows/ 樹，中斷會留垃圾目錄 | fixture 改用 temp 目錄（與其他測試的 TestDrive 做法一致） |
| R-B14 | Medium | POLICY.md 宣稱 runs/ 是 active run index 但程式碼零寫入；宣稱支援的 prompt/shell/while/fan-out/fan-in 全部 deferred | 實作 runs/ index 或從 POLICY 刪除宣稱；deferred 能力在 POLICY 明確標注現況（surface truthfulness） |
| R-B15 | Medium | sdd-pipeline/manifest.json 宣告 entryPoints `scripts/run-workflow.ps1` 但該路徑不存在（實際 runner 在 studio/scripts/powershell/）；validate-workflow 不檢查 entryPoints 存在性 | 修正 manifest；validate-workflow 加 entryPoints 存在性驗證與 negative test |
| R-B16 | Medium | RunState 政策不是未定義而是互相矛盾：POLICY 稱 generated/disposable，sdd-pipeline README 卻明文稱由 Git 追蹤以支援跨機 resume；兩份 .gitignore 皆無規則，state 又會保存本機絕對路徑、gate/history 與尚未安全的 DryRun 結果 | [OWNER DECIDED 2026-07-13] 定位為本機暫態；與 R-B06 同批把 state 移出 `specs/<feature>/`，對最終 runtime 位置加 gitignore，修正 POLICY/README；日後若需要跨機續跑，另設計 checkpoint export/import |
| R-B17 | Medium | [R2-VERIFY DISCOVERED 2026-07-13] `run-workflow -Inputs "feature=X"` 可覆蓋已驗證的 `-Feature`：RunState 錨在 A feature、所有 templated 步驟打 B feature，且覆蓋值繞過 feature-id regex；resume 路徑完全信任 saved state 的 `inputs.feature`，可被竄改或 pre-guard 殘留 state 重新綁定（live 重現） | fresh 與 resume 統一拒絕 feature 覆蓋；resume 驗證 state `inputs.feature` 與錨定 feature 一致，legacy 缺值回填；4 條回歸測試 + contract invariant |
| R-B18 | Medium | [R2-VERIFY DISCOVERED 2026-07-13] `-FeatureDir` 家族存在三種邊界等級：強（setup-plan/check-prerequisites：REPO_ROOT 基準 + specs 直接子目錄等值）、弱（setup-readiness/tasks/analyze/implement：cwd 基準 + 僅驗父目錄名為 `specs` 的形狀檢查，Assert 以候選路徑自身祖父為 root 恆真、任意 `*/specs/<x>` 可過且會寫檔）、無（setup-clarify：零邊界，唯讀）；且僅 plan 階段 operator handoff 帶 `-FeatureDir`，其餘階段 agent handoff 仍由 branch/SPECIFY_FEATURE 推導 | 收斂 sibling 腳本至 setup-plan 的強邊界語義；評估非 plan 階段 operator_message 與 agent 文件補 named option（R2/R3 批次） |
| R-B19 | Critical | [RVR-01 2026-07-14，重開 R-B02] terminal `no-pending-tasks` postcondition 只搜尋未勾選的 `T\d+`，不保存 Implement 開始前的 task-ID 集合、不要求完成後保留相同 inventory；本地已復現：進入 Implement 後把 `tasks.md` 換成任意非空非 task 文字，resume 即 `completed`。治理需要的是「原始 task IDs 全存且全勾」，非「找不到 pending regex」 | terminal step 首次抵達時保存 baseline canonical task-ID 集合，完成條件改為所有 baseline ID 仍存在且已勾選；補刪 task、改 ID、破壞 canonical line format、以非 task 文字取代、空白化 negative tests |
| R-B20 | Critical | [RVR-03 2026-07-14，重開 R-B05] runner 自行 parse catalog/state/manifest 但未套 `catalog.schema.json`/`state.schema.json`；`defaultEnabled`/`enabled` 直接 `[bool]` 轉型，PowerShell `[bool]'false'` = `True`（已復現）；`state.json` 不存在時直接沿用 `defaultEnabled` 而非 fail-closed。runner 與 `list-workflows.ps1`/canonical audit 形成兩套授權判準 | runner 共用 catalog/state schema 做 `Test-Json`；採嚴格布林解析拒絕字串 boolean；missing/wrong-type/null/scalar 全 fail-closed；補對應 negative tests |
| R-B21 | High | [RVR-04 2026-07-14] fresh execution 只驗 workflow id/version，同 id/version 的不同內容可執行；resume 只比對 `workflow_id` 再依舊 `completed_steps` 跳步，形成新舊 graph 混合的 hybrid run，無內容 digest 可證明跑的是哪份受審 YAML；built-in workflow.yml 已在 4 個 commit 改語義而版本始終 1.0.0 | approval 與 RunState 保存 workflow.yml content digest；resume 遇 graph-hash mismatch 拒絕或要求顯式 migration/restart；補同版內容變更後 resume 被擋的 negative test |
| R-B22 | High | [RVR-07 2026-07-14，R-B07 subcase] pipeline ECI step 只把 `authorization-record.md` 當 expected artifact，不驗其餘三件 dossier；`READY_FOR_MAINLINE_IMPLEMENTATION` 後只有 gate prompt 提醒 re-run readiness、graph 無第二個 Readiness step 即進 Plan；`validate-feature-structure.ps1` 只在 status 仍 `ROUTE_TO_ECI` 時要求四件 dossier，手改 `READY_FOR_PLAN` 可繞；shared field parser 只回第一個 match，矛盾 status 依行序授權而非 exactly-one fail-closed | ECI step 驗四件 dossier；成功後 graph 進真正第二次 Readiness 再依最新 status routing；validate-feature-structure 不論 status 缺 dossier 一律擋；parser 對重複/矛盾 status fail-closed |

### C. Extensions 系統

| ID | 嚴重度 | 問題 | 修復動作 |
|---|---|---|---|
| R-C01 | High | export-extensions.ps1 的 -OutputDir 可指向任意絕對路徑且 Ensure-DirectoryEmpty -Force 遞迴清空該目錄，無 workspace 邊界檢查（與 add/remove 已加固不對稱） | -OutputDir 加 Assert-PathInsideRoot（或至少拒絕清空 workspace 外非空目錄）；補 negative test 與 contract invariant |
| R-C02 | Medium | add-extension.ps1 先寫入目錄與 catalog（:116-118）才跑 validator（:120），失敗無 rollback（自家 note 已列 P1 follow-up） | 改 validate-before-mutate；mutation 多步寫入加失敗回復 |
| R-C03 | Medium | 三份 JSON Schema 零 Test-Json 執行；手寫 validator 對 kind/status 只驗非空不驗 enum，schema 與 validator 已實際漂移（fixture 用了 schema 不允許的 kind） | validator 加 Test-Json schema 驗證；修正 fixture；補 schema-violation negative test |
| R-C04 | Low | manifest 的 compatibility.minStudioConstitutionVersion 宣告了但零執行點（smoke 停在 1.3.0，憲法已 1.8.0） | 在 add/enable 路徑實作版本 gating，或從 schema 刪除該欄位（surface truthfulness） |
| R-C05 | Medium | GOV-12：Test-PathInsideRoot 只做 GetFullPath 字面前綴比對，不解析 junction/reparse（Windows probe 已證實可匯入外部內容）；add-extension -Force 替換內容仍保留原 approval 與 trust | mutation/execution 前解析每層 reparse target；-Force 替換內容必須使 approval 失效 |
| R-C06 | Low | set-extension-state 允許啟用 reviewStatus=deprecated（POLICY 說不應新啟用）；state source enum 的 sync 是死值（POLICY 明言無 remote sync） | enable 路徑區分新啟用與維持啟用並拒絕 deprecated 新啟用；刪除 sync 死值 |
| R-C07 | Low | extension-smoke 的 enable、export、merged mirror、disable 生命週期從未被自動化演練（merged 目錄不存在與 state 空一致，但也代表這條鏈零測試） | 補一條 e2e lifecycle 測試（隔離 fixture）；或把 manifest/catalog notes 的 lifecycle 宣稱改為 registry-shape 驗證 |
| R-C08 | High | [RVR-08 2026-07-14，C 系列新 failure mode] entry point 只做字串 prefix + extension-root containment，`scripts/../docs/x` 可在來源仍位於 extension root 時越過宣告 scope，export target 未再 assert 位於 `$scopeDir`；`add-extension -Force` 先刪/複製/更新 catalog 才 validation、失敗不 rollback；replacement 內容可沿用舊 `approvedBy`/`approvedAt`/trust/enabled，核准未綁 bytes；`export-extensions -OutputDir -Force` 可清空任意 output 無 workspace 邊界；disable/remove 後既有 merged mirror 不失效，selector 仍採 stale generated source——canonical registry、核准、實際 bytes、mirror 四個真相可分歧 | entry point 以 normalized full-path 驗仍位於宣告 scope，export target assert `$scopeDir`；validate-before-mutate + 失敗 rollback；approval 綁 content hash，replacement 使舊 approval 失效；`-OutputDir` 加 workspace boundary；extension state change 使 merged mirror 失效 |

### D. Agents 與 prompts

| ID | 嚴重度 | 問題 | 修復動作 |
|---|---|---|---|
| R-D01 | High | GOV-05：specify agent 內部矛盾——:88 規定不得對 material unknown 設標記上限，:163 LIMIT CHECK 仍要求超過 3 個 marker 就臆測補齊（違反憲法 §10 禁臆測）；:198 仍列 /speckit.readiness 為完成後選項（跳過 mandatory Clarify）；鏡像同步複製殘留 | 移除 LIMIT CHECK 臆測段與 readiness next-phase 文案；re-seed 鏡像；加 contract invariant 鎖定修正語句 |
| R-D02 | Critical | GOV-04：analyze completion gate 只在 setup-implement.ps1，真正的 /speckit.implement agent 只呼叫 check-prerequisites.ps1（不驗 readiness/ECI/analyze），直呼 slash command 完全繞過；Critical parser 只認四欄 `Critical` 表格，canonical analyze agent 輸出六欄 `CRITICAL`，格式互不相容 | implement agent 第一個 fail-closed 動作改為 setup-implement.ps1；analyze 判定輸出與 gate parser 共用同一 machine-readable schema |
| R-D03 | High | implement agent 仍以上游 `[P]` 平行標記為執行語義（:109/114/129），與 tasks agent 的 `[P#]`=priority 且禁行內平行標記直接衝突；且 implement 無任何 readiness/analyze/intent-ledger 治理 gate（僅有可 override 的 checklist gate） | 改由 Dependencies 與 Parallel with 行讀取平行資訊；接上 R-D02 的 gate；re-seed 鏡像 |
| R-D04 | Medium | 鏡像 parity 只驗檔名存在（audit :263-292 與 Pester 皆然），body drift 無機器檢查；F1 analyze-mirror drift 靠人工發現 | seed-claude-agents.ps1 加 -Verify 模式（正規化 diff），納入 audit 與 CI |
| R-D05 | Medium | Convert-ToClaudeTools 任一 tool 不在白名單即回傳空陣列，Claude 端 agent 省略 tools 欄位等於預設全工具：spec-kit-qa-bot 從 VS Code 端 17 個受限工具變 Claude 端無限制——映射失敗時放寬而非收緊權限 | 映射失敗改 fail-loud（報錯並中止 seed），或保底輸出最小工具集 |
| R-D06 | Medium | 30 個 tracked agent 檔（`.github` 15 + `.claude` 15）blanket pin `claude-opus-4-7`；該模型仍 Active，真正風險是同一 exact ID 跨兩個 runtime、方案/policy 可用性、成本與後續版本 churn；中文漂移副本另停在 4-5 | [OWNER DECIDED 2026-07-13] 不做 blanket 升版；canonical `.github` agents 預設省略 model，Claude mirror 映射為 `inherit` 或省略，讓 session 決定；若日後有量測證據，再由單一 per-runtime policy 對高風險 agent 做 override，audit 驗 policy/parity 而非鎖單一版本字串 |
| R-D07 | Low | agent prompt source 與 seeded mirror 大量使用箭頭與 emoji；憲法 §10.1 以不可機器判定的「AI-generated」描述範圍，造成 prompt source 是否受禁令約束的持續歧義 | [OWNER DECIDED 2026-07-13] 改成以 artifact path/type 定義：runtime prompt source 與 deterministic mirror 可少量使用具語義的符號，SDD outputs、constitution、adapters 與治理文件仍禁止；裝飾性符號隨實質修改漸進清理 |
| R-D08 | Low | implement agent 殘留 40 餘行上游 ignore-file 技術目錄（R/Swift/Helm 等）；readiness agent 495 行冗長；同一規則在憲法、agent、contract 三處重複維護 | 清除上游殘留段；長期評估規則單一來源化（contract 為準、agent 引用） |
| R-D09 | Low | discover agent 是 13 個 speckit agent 中唯一缺統一 Output Language 與 $ARGUMENTS 頭部者，且自帶獨立版本號 v2.1 與其他 agent 版本管理方式不一致 | 補統一頭部；版本標記對齊其他 agent 慣例 |
| R-D10 | Low | speckit.version.agent.md 的 fallback 指令引用 spec-kit-upstream-alignment-matrix.md 未給實際路徑（在 docs/0308upstreams/），不可直接執行 | 補完整路徑 |
| R-D11 | Low | .claude/ 無 commands/ 目錄；全部文件敘事以 /speckit.* 命令為中心，但 Claude Code 端實際觸發方式（subagent 委派）未文件化 | 在 README 或 QUICKSTART 補一段「兩個 runtime 的觸發面差異」說明；或補 .claude/commands 薄殼 |
| R-D12 | Medium | `async-python-reviewer.md` 明確是 japanese-learning 專用 agent，卻位於 shared source；Claude project-local 副本其實已存在且 tracked，shared contract 也早已列白名單，但該專案 `.github/agents` 是指向 shared source 的 junction，不能直接靠移檔建立 Copilot local agent | [OWNER DECIDED 2026-07-13] 目標仍是移出 shared source/mirror/contract；先設計 project-local Copilot overlay 或裁定該專案只保留 Claude reviewer，再移除 shared 副本。未完成 overlay 前不得以破壞 consumer 功能的方式硬刪 |

### E. 憲法、adapter 與治理帳務

| ID | 嚴重度 | 問題 | 修復動作 |
|---|---|---|---|
| R-E01 | Medium | 「auxiliary」分類三處不一致：憲法 §2 列 3 個（discover 是 optional aid、eci 是 specialized command）、§10 auxiliary roles 列 5 個（含 discover 不含 eci）、contract auxiliaryCommands 列 6 個（含 eci 與 discover）；測試只驗聯集不驗用語 | 憲法 patch 統一分類用語（建議以 contract 的 6 個為準並在 §2 修正措辭），bump 版本 |
| R-E02 | Medium | .github/copilot-instructions.md:49 的 Current Phase 停在「Practice (as of 2025-12)」，憲法 §1.1 已是「Practice + Internal (as of 2026-04)」；dependent adapter 手寫區段無任何 invariant 覆蓋 | 更新該行；為 adapter 手寫區關鍵句加 docInvariant（與 R-A10 同批） |
| R-E03 | Low | 憲法 Changelog 只列 1.7.0/1.8.0，git 歷史顯示 2025-12-09 初版已是 1.2.0，1.2.0 至 1.6.x 演進從表中消失 | 從 git log 考古回填 changelog 各版本一行摘要 |
| R-E04 | Low | impact-registry.json 在憲法 §12 與自身 documentAuthority 被列 source_of_truth，但 generator docstring 明言 derived artifact，authority 分類自我矛盾 | 憲法 patch 將其改列 dependent/derived（真 source 是腳本與 embedded metadata），或在 §12 加註生成語義 |
| R-E05 | Low | impact routing 的 `must_update` 在 pre-commit 僅 warning；這符合允許 incremental commits 的原設計，但 PR/merge reconciliation gate 未落地，導致真正的終點強制缺席 | [OWNER DECIDED 2026-07-13] 保留 `must_update` 語義與 commit-time advisory；在 branch diff / PR / merge CI 對整批 reconciliation 做 blocking。確實不要求更新的 route 個別降為 `must_review`/`maybe_review`，不把全域語意改名為 `should_update` |
| R-E06 | Low | CLAUDE.md bootstrap「If either required constitution is missing」與「.specify/memory/constitution.md when present」語義拉扯；root 無 .specify 靠 N/A 標記豁免但措辭含糊 | 修正 bootstrap 措辭（generator here-string 與三 adapter 同步改），精確化為「宣告為 required 的層缺失時才報 incomplete」 |
| R-E07 | Medium | workspace 治理 repo 自身豁免七階段（治理變更走 mainline notes 而非 SDD），此雙軌標準未在憲法明文化，「All projects MUST follow」與實際行為矛盾 | 憲法 patch 明文自我適用邊界：governance repo 的 shared-layer 變更以 mainline note + machine audit 為等效治理路徑 |
| R-E08 | Medium | phase freshness 測試（4 個月門檻，基準 2026-04）約 2026-08 底到期，屆時整條 CI 因文件時戳變紅 | 複審 §1.1 Current Phase 並更新日期（順帶檢討「文件時效與程式正確性綁同一 gate」的取捨，考慮拆為獨立 advisory） |
| R-E09 | High | 合併帳務斷鏈：18 份 Ready notes 的 Related Commits 全 TBD（違反 template 狀態機）；wave-3 主 note（2026-05-05-studio-workflows-runtime.md）仍 Draft/TBD，但描述的工作已落地（b01c366） | 用 git log 逐份回填 hash；主 note 收尾為 Ready、交叉引用 78893e2 的後續修復 note、誠實列 GOV open findings 為 known issues；同步 README 索引 |
| R-E10 | Medium | Ready note 狀態機無「宣稱被複驗推翻」的回滾語義：三份 2026-07-12 notes 標 Ready 當日即被 review 推翻關鍵宣稱，Ready 標籤成為新的 false confidence 來源 | note template 加狀態規則一段（被複驗推翻時降回 Draft 並記錄推翻來源）；與 R-A09 的機器檢查同批 |
| R-E11 | Medium | 缺 open-findings 單一總帳：GOV-01..13、extension follow-ups、adapter 漂移等散落三份分析與五份 notes | 以本文件第 3 節為起始 ledger；後續每批修復在對應 ID 標記完成狀態與 commit hash |
| R-E12 | Low | 憲法 §12 authority 分類只列 `.githooks/pre-commit.ps1`，commit-msg.ps1 未被任何層分類納管 | 憲法 patch 改寫為 `.githooks/*.ps1` 或補列 commit-msg.ps1 |

### F. 上游 spec-kit 同步

| ID | 嚴重度 | 問題 | 修復動作 |
|---|---|---|---|
| R-F01 | Medium | get-speckit-version.ps1 回報 UPSTREAM_BASELINE_DATE=2026-03-06（解析自研究文件檔名），未隨 Wave-3 吸收更新，機器可讀版本面與文件面不一致 | 建 studio/upstream/alignment-state.json 作為單一真相（baseline、adopted capabilities、last-evaluated release），get-speckit-version 與 wave notes 共同引用 |
| R-F02 | High | 上游 v0.9.0 至 v0.12.11 共 74 releases（含 v0.10.0 breaking 移除 --ai 改 --integration、v0.12.0 agent-context opt-in、/speckit.converge、py: 三語 script 支援）無任何本地評估文件 | 產出 Wave-4 決策矩陣（沿用 0308upstreams 的 adopt/defer/reject 格式），更新 R-F01 的 alignment-state |
| R-F03 | Medium | /speckit.converge（上游 2026-06-17）與本地 analyze completion gate 功能相鄰，未做 adopt/adapt/reject 決策 | 併入 Wave-4 矩陣做明確決策並記錄理由 |
| R-F04 | Medium | agent-skills 匯出鏈未被實際採用且無專屬測試，但並非零引用：installer 會呼叫 exporter，`upgrade-studio-runtime.ps1` 也有 active verification caller；目前 Codex/Claude pack 均未產出或安裝，舊文件的上游旗標基準已失效 | [OWNER DECIDED 2026-07-13] 退役整條能力鏈：3 支腳本、upgrade caller、audit `SKILL_TARGETS`、common `SKILL_PACKS_ROOT`、contract/docs/tests 與 `resources/agent-skill-packs/` 一致移除；若未來重新需要，先立 spec 並以當時的 plugin/skills surface 重建 |
| R-F05 | Medium | 上游 v0.12.x 的 workflow 修正清單（gate validate crash、fan-in wait_for、quote-aware pipe-filter）未與本地 engine 逐項比對——上游修的正是本地同類 bug | 併入 Wave-4：逐項比對並轉成本地迴歸測試候選 |
| R-F06 | High | [RVR-11 2026-07-14] `upgrade-studio-runtime.ps1` 逐檔覆寫 canonical runtime，完成 mutation 才跑 audit；snapshot 不完整或 audit 失敗時 command 非零結束但已覆寫 target 保留，無 staging/transaction/backup restore/rollback，「upgrade failed」不代表 runtime 保持原狀，重試以半更新狀態為起點——違反 fail-closed、可重複性與 authority update order | upgrade 改 staging + audit + atomic promote，或在 apply 失敗時可證明 rollback 完成；補 apply-failure rollback coverage |

### G. docs/ 文件時效

| ID | 嚴重度 | 問題 | 修復動作 |
|---|---|---|---|
| R-G01 | High | docs/project-governance-status.md 中央台帳停更 2026-03-23：只列 7 專案（缺 Trading-002/003 兩列）、Review Trigger 已多次觸發未執行；被 README、WORKSPACE_STRUCTURE、project-init 模板引用為權威 | 補齊台帳兩列、更新日期、補記 2026-03-18 後 stage/gate 重定義的影響；確認既有 7 列的 local notice 仍存在 |
| R-G02 | High | docs/yuanxi_sdd_pack_implementation_plan_zhTW.md 鎖 v0.8.6 基準：AC-8/D-016/T3.2/T5.2 的版本範圍與 tested target 全數失效，照做會以錯誤 CLI 假設開工 | 實測 0.12.x CLI 後做新一輪迭代更新 governance_basis 與各決策點；frontmatter 註記 re-verified 日期 |
| R-G03 | High | docs/yuanxi_sdd_pack_implementation_plan_obstacle_review_zhTW.md 的 B-003 建議改用 --ai，上游 0.10.0 已刪除 --ai（修正方向反轉）；B-001 在 0.12.x 很可能不成立 | 文首加 superseded/需重驗橫幅指向 07-08 深評 §5.5；重驗後產出新的日期化 obstacle review，不就地改寫 |
| R-G04 | Medium | docs/yuanxi_sdd_pack_strategy_zhTW.md 的 compatibility matrix 停在 v0.8.5，且內文用箭頭與 ASCII 流程圖違反憲法 §10.1 | 加 baseline 註記；matrix 更新或標示過期；格式違規在下次實質修訂一併清 |
| R-G05 | Low | docs/yuanxi_sdd_pack_strategy_implementation_review_zhTW.md 的 handoff 任務已被 implementation plan 吸收，交接身分已結束 | 文首加 superseded 橫幅保留為 decision record |
| R-G06 | Medium | `docs/change-manifests/` 只有 `.gitkeep`、0 份真實 manifest；所謂掛接並不完整：contract 驗 template/目錄，hook 只檢查已 staged manifest，analyze 只提示，憲法沒有 presence 義務，且與 mainline note 的 impact/validation 欄位重疊 | [OWNER DECIDED 2026-07-13] 退役整條 change-manifest 鏈；把必要的 impact reconciliation 表與 closed/deferred disposition 併入 mainline note template，並由 R-E05 的 merge CI 強制。不同步補一份裝飾性 wave-3 manifest |
| R-G07 | Medium | docs/sdd-drift-governance-solution.md 的缺口清單多已被實作填平但無狀態標註，且 :311/:582 引用已移除的 studio/templates/sdd-agents/（3355c7f） | 文首加實作狀態表逐條對映落地 artifact；失效引用加註 |
| R-G08 | Medium | docs/0308upstreams/ 四檔停在 2026-03-18：wave2-transition-guide 仍標 Active execution baseline；remaining-updates 全檔 15 條以上 C:/Users/user/... 機器綁定絕對路徑連結；usage-guide 操作路徑已過期；alignment-matrix 引用已移除鏡像 | 四檔各加 historical/superseded 橫幅；remaining-updates 整檔連結相對化；不就地重寫內容 |
| R-G09 | Low | docs/readiness_source/ 兩檔的「design reference、非 acceptance surface」定位只在外部文件宣告，檔內無橫幅，單獨餵 LLM 會誤讀為進行中設計 | 兩檔文首各加 HTML comment 定位橫幅 |
| R-G10 | Low | `docs/basic-prompt.txt` 零引用且只有六句泛用指示，缺 mandatory `specify`，內容不足以作為可驗證 prompt asset | [OWNER DECIDED 2026-07-13] 直接刪除，不併入 `studio/prompts/`；真正的 prompt assets 從 `learnings.md` 已驗證 candidates 提取 |
| R-G11 | Low | docs/sdd-drift-governance-core-logic.md 原則仍有效但無「已落地於何處」的狀態註記 | 文首加一行實作對映註記 |
| R-G12 | Low | docs/studio-infrastructure-challenge-2026-04-12.md 引述數據全面過期（contract 629 對 1023 行等五項），部分挑戰已被回應但無 disposition | 保留快照不改數字；文末加「後續處置」小節逐條標記回應狀態 |
| R-G13 | High | docs/README.md、wave-3 review、本輪兩份分析共 4 檔未 commit，README 索引引用的檔案存在遺失風險 | 確認內容後一起 commit（informational 層） |

### H. 根目錄、設定與呈現

| ID | 嚴重度 | 問題 | 修復動作 |
|---|---|---|---|
| R-H01 | High | 全 repo 無 LICENSE，repo 已公開；自有內容與 vendored/上游衍生內容混雜，root LICENSE 只能授權 owner 有權授權的部分，不能補正第三方來源缺口 | [OWNER DECIDED 2026-07-13] 公開並採 MIT；執行順序必須先完成 R-H02 與來源盤點，再加入 root MIT LICENSE、README License 段與 `THIRD_PARTY_NOTICES.md`/來源清單，保留第三方原授權 |
| R-H02 | High | `resources/github-copilot-configs/` 392 tracked 檔幾乎是 2025-11-19 第三方快照，內無 LICENSE/NOTICE；來源 repo 本身無 root LICENSE，且 2026-06-01 已移除同步 agents，現有 setup updater 已沒有有效更新來源 | [OWNER DECIDED 2026-07-13] 完整移除 tracked snapshot 與舊工作副本，不能只 `git rm --cached` 後留下無 nested `.git` 的內容；與 R-H08 同批退役 installer。日後若需要外部 agents，從具明確 MIT 的 `github/awesome-copilot` 選取、pin commit/hash 並保留 LICENSE/來源 manifest |
| R-H03 | High | README.md 三類錯誤：:238-239 兩條引用指向根目錄不存在的檔案（實在 docs/0308upstreams/）；全文零提及 studio/workflows/（wave-3 canonical runtime）與 workflow 腳本；:27/:166 宣稱 .claude/agents/ 是 source of truth，牴觸憲法 Dependent 分類 | 修引用路徑；補 workflows 至核心模型、目錄總覽、常用腳本表；.claude/agents 描述改為 seeded dependent mirror |
| R-H04 | Medium | WORKSPACE_STRUCTURE.md header 停在 Version 1.8.0 / Updated 2026-04-30，但 b01c366 與 60556ef 之後都改過內容，changelog 未記；:261 失效引用；Root Layout 缺 .githooks/ 與 .vscode/ 列 | 版本升 1.9.0 補 changelog；修引用；補兩列 |
| R-H05 | Medium | `bone.ini` 是 2025-12 過期結構草圖，描述不存在的 generator 與虛構專案，和 canonical 結構文件形成平行描述；`studio/tools/` 為未 tracked 空目錄。ASCII tree 本身不受只規範 AI-generated `.md` 的憲法 §10.1 約束，原報告此理由不成立 | [OWNER DECIDED 2026-07-13] 直接刪除 `bone.ini` 與本機空目錄，不搬 archive；Git history 已保留史料 |
| R-H06 | Medium | learning-project-spec-kit-sdd.md 留在根目錄且內文描述無 readiness 的六階段舊流程，與憲法 1.8.0 矛盾，易被誤當現況 | git mv 至 docs/0308upstreams/ 並加歷史快照註記；修正引用它的三份文件路徑 |
| R-H07 | Low | https-github-com-github-spec-kit-repo-2025-10-01-2.md 以 URL 當檔名滯留根目錄，屬 0308upstreams 同批研究產物 | git mv 至 docs/0308upstreams/ 並改可讀檔名；同步互相引用 |
| R-H08 | Medium | `setup-copilot-agents.ps1` 硬編碼本機路徑、只有 README 一個外部引用、會直接覆寫 `~/.copilot/agents`；來源 repo 已移除 agents，且現有非 nested Git snapshot 讓 `git pull` 可能落到錯誤父 repo | [OWNER DECIDED 2026-07-13] 與 R-H02 同批直接退役並移除 README 入口，不封存；未來若重建 installer，必須具備明確來源授權、commit pin、allowlist、確認提示與 rollback |
| R-H09 | Medium | .vscode/settings.json 殘留：:150-171 五條一次性 terminal autoApprove regex（安全異味）、:72 引用已不存在的 duotify 專案、:46 與 :58 的 markdown formatter 與 markdownlint.ignore 自相矛盾 | 移除 autoApprove 整段；刪 duotify 條目；formatter 與 ignore 二擇一 |
| R-H10 | Low | .vscode/extensions.json 推薦 editorconfig 擴充但 repo 無 .editorconfig | 與 R-A12 同批：加最小 .editorconfig 或移除推薦 |
| R-H11 | Medium | 履歷/ 個資目錄只靠 .gitignore:89 單條規則保護（已驗證全歷史從未入庫，現況安全但脆弱） | 首選移出 repo 樹；至少在 pre-commit 加 staged-path 拒絕規則作第二道防線 |
| R-H12 | Low | 根目錄 testResults.xml 為路徑遷移前的本機孤兒殘留（含機器名與使用者路徑；未入庫） | rm 本機檔案 |
| R-H13 | Low | `archive/` 三個子目錄全空、0 tracked、歷史也未曾承載內容；fresh clone 不會出現，README 與 WORKSPACE_STRUCTURE 的列項只是未落地的預留概念 | [OWNER DECIDED 2026-07-13] 刪除本機空目錄並移除兩份文件列項；未來若真的需要封存機制，以 `archive/README.md` 明定納入/保存規則後再建立 |
| R-H14 | Low | .github/skills/ 空目錄、0 tracked、不在結構文件內，來源不明 | 確認是否預留：是則 .gitkeep 加結構文件補列，否則刪除 |
| R-H15 | Low | `resources/agent-skill-packs/` 只有 `.gitkeep`，目前 Codex/Claude pack 均未產出或安裝；它是 R-F04 能力鏈的空輸出位置 | [OWNER DECIDED 2026-07-13] 隨 R-F04 退役刪除，並同步移除文件、audit 與 contract 描述 |
| R-H16 | Low | .gitignore：:29 `packages/` 全樹通配過寬（共享層無 .NET 內容）；:65 條目被 :7 `*.local` 涵蓋屬冗餘；缺 `.claude/.agent-*-backup/` 規則 | 收窄或移除 .NET 區塊；清冗餘加註解；補備份目錄規則（與 R-A11 同批） |
| R-H17 | Medium | `中文文件管理/` 只有一份零引用 discover 譯本，已與 canonical 英文及憲法矛盾（仍稱 discover 是唯一前置輸入）且 pin 4-5；問題是未治理的平行真相，不是非 ASCII 目錄名 | [OWNER DECIDED 2026-07-13] 刪除整目錄；未來若需要繁中 agents，先建立來源 commit、非權威 banner、自動 parity 與完整翻譯政策，不搬移此漂移副本 |
| R-H18 | Low | 入口文件語言策略不一致：README/QUICKSTART 全繁中、憲法與 WORKSPACE_STRUCTURE 英文、WORKSPACE_STRUCTURE :144-161 英文中夾雜中文整節 | 統一 WORKSPACE_STRUCTURE 為單一語言；README 補英文 TL;DR 段（修復角度為一致性，非行銷） |
| R-H19 | Medium | governance.yml：無 schedule（長期停更 repo 缺定期 drift 偵測）；push 無 branch 過濾與 pull_request 並存造成 PR 重複跑；actions 只 pin major tag；Pester 只設 MinimumVersion、powershell-yaml 完全未鎖版；README 無 badge | 加 weekly schedule；push 限 main；模組鎖 RequiredVersion；視需要 pin SHA；README 加 badge |

### I. studio 層資產與知識迴路

| ID | 嚴重度 | 問題 | 修復動作 |
|---|---|---|---|
| R-I01 | Medium | studio/upstream/shared-layer-map.json 自 2026-03-10 未動：8 條 mapping 未涵蓋 wave-3 的 studio/workflows 資產；blockedRoots 缺 workflows catalog/state；upgrade-studio-runtime 以它為唯一同步面，workflows 永不在升級範圍 | 增補 workflows mappings 與 blockedRoots，bump version；考慮在 audit 加 map 涵蓋面 freshness 檢查 |
| R-I02 | Medium | 三個 adapter 模板（agents-md/claude-md/copilot-instructions-template.md）無 runtime 消費者，實際 adapter 由 sync-agent-bootstrap.ps1 內嵌 here-string 產生——同一內容兩份來源，已知的漂移產生器模式 | 收斂單一來源：generator 改讀模板 render；或模板加「說明性快照」註記並以 invariant 同鎖兩邊 |
| R-I03 | Medium | 6 個 route packet 加 4 個 ECI templates 沒有 runtime scaffold consumer；contract 對部分模板已有語意檢查、WORKSPACE_STRUCTURE 也有索引，因此不只是存在性引用，但 agents 仍各自內嵌完整結構，形成雙重來源 | [OWNER DECIDED 2026-07-13] 保留並接上 route-aware scaffold：readiness 判定後只複製所選 route 的一份最小 packet，ECI 可一次 scaffold 必需四件 dossier；agents 改引用 template，validator 檢查必填欄與未替換 placeholder。不刪憲法要求的產物 |
| R-I04 | Medium | studio/prompts/ 六個 stage 目錄全空且未入 git（fresh clone 後路徑消失），但憲法 §13.3、QUICKSTART、WORKSPACE_STRUCTURE 都指向它；learnings 已累積 8 條帶 target 的 prompt candidates 待提取 | 提取 1 至 2 條已驗證 candidate 成實檔入 git；其餘目錄加 .gitkeep 或收斂文件指向 |
| R-I05 | Medium | learnings.md 檔頭承諾「session 收尾即時追加」無任何機制承接——檔內自己記載的教訓正是「mandatory 但無 enforcement 執行率為零」 | note template 加「learnings 追加了嗎」必填欄，由既有 pre-commit note 檢查連帶承接 |
| R-I06 | Low | QUICKSTART.md 有 7 處 `.\` 裸呼叫與 4 處 pwsh 前綴混用；SDD-QUICKSTART-GUIDE.md 全檔 0 處 pwsh——範例在預設 PS 5.1 環境不可跑 | 兩檔範例統一 `pwsh ./...` 形式；前置需求段標注 PowerShell 7（與 R-A05 同批） |
| R-I07 | Low | `studio/templates/feature-packs/` 三個子目錄 0 檔案、未入 Git；除過期 `bone.ini` 外無有效引用，因此本來就不是 clone 可見的 repo asset | [OWNER DECIDED 2026-07-13] 刪除本機空目錄；未來要做先立 spec |
| R-I08 | Low | `studio/knowledge-base/pain-points/` 空且未入 Git；憲法刻意把它列為 optional，沒有 `.gitkeep` 不構成治理缺陷 | [OWNER DECIDED 2026-07-13] 刪除本機空目錄、保留憲法 optional 路徑說明；用到再建，不加 `.gitkeep` |
| R-I09 | Low | list-extensions.ps1 功能正常但未被 extensions/POLICY.md 收編為正式操作面（workflows/POLICY 對 list-workflows 有對應寫法） | POLICY 補列，確立為受治理操作入口 |

### J. 遠端與身分

| ID | 嚴重度 | 問題 | 修復動作 |
|---|---|---|---|
| R-J01 | Critical | main 無 branch protection（gh api 實測 404）；mainline-note 與全部 hook 治理只在本機 pre-commit，CI 只跑 audit+Pester——direct push、--no-verify、未裝 hook 的 clone 都能繞過憲法 §12 全部合併治理且 CI 照綠 | GitHub 啟用 branch protection/ruleset（require PR、require status check audit-and-tests、禁 force-push）；把 mainline-note 驗證抽成獨立腳本加入 CI，使治理有伺服器端 enforcement |
| R-J02 | Low | 公開 repo 的 65 個 commit 曝露私人 email、3 個使用 noreply；目前 root 無 repo-local identity，而 global Git config 仍可能讓其他公開 repos 重演同一問題 | [OWNER DECIDED 2026-07-13] 未來公開工作使用 GitHub noreply；優先以 workspace-scoped conditional include 或合適的 global policy 覆蓋所有 nested repos，並啟用 GitHub email privacy / push blocking；既有歷史不重寫 |
| R-J03 | High | main 停在 2026-05-04、落後 13 commits、無 CI；wave-3 review 以 9 P1 為 merge 前提——「全面更新」的終點是把修復後的分支乾淨合回 main | 依第 5 節批次完成 R-B/R-D 的 P1 修復與 fresh fixture e2e 驗收（wave-3 review Gate 6）後合併；合併時 E09 帳務必須已收尾 |

## 4. 三輪對抗驗證與修正記錄

第一輪 18 條高重要性論斷：16 CONFIRMED、2 REFUTED 已修正（contract 斷言總數 377 非 440；implement agent「無 gate」精確化為「無治理 gate、有可 override 的 checklist gate」）。第二輪 critic 修正 2 條：model pin 檔數為 30 個 tracked（非 16），且 claude-opus-4-7 仍 Active 僅落後一代，屬更新項非緊急修復；remaining-updates 的失效連結為全檔 15 條以上非僅 2 條。

第三輪於 2026-07-13 針對 owner decisions 做獨立複核，並以 section-bounded parser 發現初版 95 條摘要實際應為 109 條（6 Critical、20 High、45 Medium、38 Low）。同輪修正以下處置前提：R-B16 是文件矛盾而非政策空白；R-D06 應裁定模型政策而非只選新版號；R-D12 已有 project-local Claude 副本且 contract 已白名單，但 Copilot junction 阻擋直接移檔；R-E05 應補 merge gate 而非把 `must_update` 全域降級；R-F04 並非零引用；R-G06 並未完整掛接且憲法無 presence 義務；R-H02 的來源 repo 已移除 agents；R-I03 的 contract 對部分模板有語意檢查。上述修正已直接反映在第 3、5、6 節，並由第 10 節保留版本紀錄。R0 實作後另新增 R-A14，故 current ledger 為 110 條。

## 5. 分批執行計畫

原則：每批只處理一個可獨立驗收的風險主題。每批收尾都必須跑 audit、Pester、該批 negative tests、`git diff --check`，並補一份 mainline note。批次順序固定為：先停止擴大風險，再修驗證器，再修被驗證的 runtime，最後才處理 drift、文件與重新 promotion。

| 批次 | 主題與主要內容 | 涵蓋 ID | 批次專屬完成閘門 | 粗估 |
|---|---|---|---|---|
| R0 決策基線、止血與公開來源清理 | 本報告等 4 份未追蹤文件定案/入庫；workflow catalog 降級；個資 staged-path 防線；移除本機測試殘留；完整移除無授權 vendor 與舊 installer；清理 bone/archive/漂移譯本/basic prompt/空目錄；完成來源盤點後才加 MIT/NOTICE；設定未來 noreply | R-G13、R-B09、R-H01、R-H02、R-H05、R-H08、R-H11 至 R-H13、R-H17、R-G10、R-I07、R-I08、R-J02、R-A14 | `resources/github-copilot-configs/` 不再 tracked 或殘留舊 snapshot；LICENSE 只涵蓋可授權內容；catalog 非 approved/default-enabled；個資路徑 negative test 會擋；removed nested source 不再觸發 adapter 假陽性；文件決策表 18/18 | 1-2 天 |
| R1 驗證可信度與遠端 merge enforcement | 修 audit collection/init、registry/schema failure 升格、封閉語義、e2e 壞狀態 fixtures、PS7 fail-fast、BOM/line ending；note 狀態機；原子退役 change-manifest 並把 reconciliation 併入 mainline note；保留 `must_update` 且在 branch/PR CI 阻擋；CI hardening 後啟用 main protection/ruleset | R-A01 至 R-A12、R-E05、R-E10、R-G06、R-H10、R-H16、R-H19、R-I06、R-J01 | missing module/state、invalid catalog/schema、stale mirror、invalid Ready note、未完成 `must_update` reconciliation 都使 CI 非零；一般 incremental commit 不被誤擋；main 要求 PR 與指定 status check | 3-5 天 |
| R2 Workflow engine 執行完整性 | reject/preconfirm fail-closed、terminal task postcondition、DryRun ephemeral、step ID unique、runner 授權消費、feature/RunState relocation、failed-run recovery、error/history/fixture/manifest 修正；RunState 最終位置設 local transient | R-B01 至 R-B06、R-B10 至 R-B16 | rejected/preconfirmed/disabled/rejected/uncataloged workflow、DryRun 後正式 run、duplicate ID、pending tasks 與 stale state 全有 negative tests；state 不進 Git且不預建 canonical feature ID | 4-6 天 |
| R3 SDD stage gates、routing 與 agent runtime | implement 首步接 fail-closed gate、analyze schema 單一化、specify/priority 語義修正、ECI full dossier 與 readiness re-entry、analyze artifact 收斂、mirror `-Verify`、tool mapping fail-loud；route-aware templates；模型預設 inherit；prompt 格式範圍明文化；D12 先維持 temporary allowlist，直到 Copilot overlay/Claude-only 決策可安全落地 | R-B07、R-B08、R-D01 至 R-D12、R-I03 | 直呼 `/speckit.implement` 不能繞 readiness/ECI/analyze；8 readiness statuses 與 4 ECI outcomes 都有 routing tests；source/mirror body parity；template 只產生 minimum packet；D12 無 consumer regression | 3-5 天 |
| R4 Extensions、registry 周邊與 skills 退役 | Extensions path/reparse/rollback/schema/version/state/lifecycle 補完；完整退役 skills export/install/generic chain、upgrade caller、audit/contract/docs/tests/empty output；更新 shared-layer map 與正式 operation surface | R-C01 至 R-C07、R-F04、R-H15、R-I01、R-I09 | workspace 外 export/reparse/force replacement/schema violation 全被擋；extension lifecycle e2e 綠；repo 對 skills chain 零可執行/文件/contract 孤兒引用；upgrade runtime 仍可驗收 | 3-5 天 |
| R5 Authority、文件、上游與知識迴路收斂 | 憲法/adapter authority patch、雙軌治理邊界、changelog/current phase；mainline 帳務；README/WORKSPACE_STRUCTURE/VS Code/語言清理；governance-status 與 historical banners；Wave-4 alignment-state、v0.9 至當下最新 release 決策矩陣、converge 與修正比對；adapter template 單一來源、prompt/learnings 機制；完成 D12 project-local overlay 或明示 Claude-only | R-A13、R-E01 至 R-E04、R-E06 至 R-E09、R-E12、R-F01 至 R-F03、R-F05、R-G01 至 R-G05、R-G07 至 R-G09、R-G11、R-G12、R-H03、R-H04、R-H06、R-H07、R-H09、R-H14、R-H18、R-I02、R-I04、R-I05、R-D12 | authority update order 無漂移；所有 stale docs 有 current/superseded/historical disposition；alignment-state 與決策矩陣指向同一 baseline；root docs 無失效連結/過度宣稱；D12 不再污染 shared source | 5-8 天 |
| R6 Fresh-fixture 端到端驗收、重新 promotion 與合併 | 以全新 fixture 完整跑七階段含 ECI re-entry、非 READY routes、reject/recovery、implement completion；關閉 wave-3 review Gates 與 2026-07-14 re-review 第 9.2 節 minimum gates；只有全部通過才重新 promotion workflow；回填 notes/ledger/commits；合併 main 後重跑同一套 | R-B09、R-E09、R-E11、R-J03 | 目前 127 條 ledger 各有 completed commit 或 owner-approved disposition；wave-3 9 個 P1 與 12 條 RVR 全關；fresh fixture e2e 有保存證據；main 合併後 audit/Pester/negative/e2e 全綠 | 2-4 天 |

依賴備註：

1. R0 必須先完成 R-H02，再加入 R-H01 的 MIT/NOTICE。
2. R1 的 CI status check 必須先存在且通過，才能在 GitHub 啟用要求該 check 的 protection/ruleset。
3. R-B09 的降級要維持到 R6；不得因 unit tests 綠就提前重新 promotion。
4. R-B16 的 gitignore 必須跟隨 R-B06 的最終 relocation，不在舊路徑先做永久政策。
5. R-G06 與 R-E05 必須原子處理：移除 manifest presence 面時，同批建立 mainline-note reconciliation 與 merge CI。
6. R-D12 在 R3 只可建立安全遷移前提；若 Copilot overlay 尚未完成，temporary allowlist 必須保留到 R5，不能先刪 shared agent。
7. 前四批 R0 至 R3 的完整工作量粗估 11 至 18 人天；目前 131 條全量收斂粗估仍為 21 至 35 人天（未含 2026-07-14 RVR 新增 9 條與 RB-1 至 RB-5+R6 的追加約 14 至 22.5 人天，見 remediation plan；R-B23、R-A21、R-B25、R-B26 與 R-H20 依日期化增補另行排程）。若只挑 Critical/High 子集，必須另做 scope cut，不得把各批完整工期直接相加後仍沿用較小數字。
8. R-E09 在 R5 處理既有 Ready/Draft notes 的歷史帳務與失真修復；R6 只做本輪 final commit/PR/merge hash 回填與合併後驗證。兩批不得把同一工作重複計為完成。

## 6. Owner 已裁定的 18 項決策

Owner 於 2026-07-13 完成裁定。以下是 18 個邏輯決策；原始盤點的合併列與 finding ID 數不等同於決策數。狀態 `DECIDED` 只代表方向已定，不代表修復已實作。

| # | ID | 最終裁定 | 執行邊界 / 驗收重點 | 狀態 |
|---:|---|---|---|---|
| 1 | R-H01 | 公開並採 MIT | 先完成 R-H02 與第三方來源盤點；再加 root LICENSE、README License 段、`THIRD_PARTY_NOTICES.md`，不得用 root MIT 覆蓋無權授權的內容 | COMPLETED |
| 2 | R-H02 | 完整移除 vendored `github-copilot-configs` | 真正移除 tracked snapshot 與舊工作副本；未來只從具明確授權的來源選取、pin commit/hash、保留 LICENSE/manifest | COMPLETED |
| 3 | R-H05 | 刪除 `bone.ini` 與空 `studio/tools/` | 不搬 archive；確認無其他 live structure references；Git history 保留史料 | COMPLETED |
| 4 | R-H08 | 退役 `setup-copilot-agents.ps1` | 與 R-H02 同批移除 README 入口；不保留可對 user home 做無治理覆寫的舊 installer | COMPLETED |
| 5 | R-H13 | 刪除空 `archive/` 預留結構 | 移除 README / WORKSPACE_STRUCTURE 宣稱；未來若重建，先以 README 定義保存規則 | COMPLETED |
| 6 | R-H17 | 刪除漂移繁中 agent 目錄 | 不因非 ASCII 名稱而刪；理由是治理內容矛盾。未來翻譯需有來源 commit、banner 與 parity | COMPLETED |
| 7 | R-G06 | 退役 change-manifest 鏈 | 將 impact reconciliation 併入 mainline note，並由 merge CI 強制；不補裝飾性首份 manifest | COMPLETED |
| 8 | R-G10 | 直接刪除 `basic-prompt.txt` | 不把低資訊內容搬入 `studio/prompts/`；prompts 只從已驗證 candidates 提取 | COMPLETED |
| 9 | R-F04 / R-H15 | 退役 agent-skills export/install capability | 連同 scripts、upgrade caller、audit、contract、tests、docs 與空輸出目錄一起收斂；未來需要時重新立 spec | DECIDED |
| 10 | R-B16 | RunState 為本機暫態 | 與 R-B06 同批 relocation 後再 ignore；修正 POLICY/README；跨機需求改走顯式 checkpoint export/import | DECIDED |
| 11 | R-D06 | 移除 blanket exact model pin，預設 inherit | 建 per-runtime 單一 policy；audit 驗 policy/parity，不鎖某一代 model literal；高風險 override 需有量測證據 | DECIDED |
| 12 | R-D07 | 以 artifact 類型明文化狹義 prompt 例外 | Runtime prompt source/mirror 可少量使用語義符號；SDD outputs 與治理文件仍禁止；裝飾性符號漸進清理 | DECIDED |
| 13 | R-D12 | 將專案 reviewer 移出 shared，但先解決 Copilot overlay | Claude project-local 已存在；Copilot junction 未解前不得破壞功能。完成 overlay 或裁定 Claude-only 後再刪 shared source/mirror/contract entry | DECIDED |
| 14 | R-I03 | 保留模板並接上 route-aware consumer | Readiness 每次只 scaffold 所選 route 的最小 packet；ECI scaffold 必需四件；validator 檢查 placeholders/必填欄 | DECIDED |
| 15 | R-I07 | 刪除本機空 `feature-packs/` | 無 repo 變更需求；未來需要先立 spec | COMPLETED |
| 16 | R-I08 | 刪除本機空 `pain-points/`，保留 optional 定義 | 不加 `.gitkeep`；用到再建立 | COMPLETED |
| 17 | R-E05 | 保留 `must_update`，在 merge/CI 才 blocking | Commit-time 保持 advisory；PR/merge 以 branch aggregate reconciliation 阻擋，避免逐 commit false positive | COMPLETED |
| 18 | R-J02 | 未來公開工作使用 GitHub noreply，不重寫歷史 | 使用 workspace conditional include 或適當 global policy 涵蓋 nested repos；啟用 GitHub privacy / push blocking | COMPLETED |

## 7. 已知限制

1. R-J02 的 GitHub account email privacy / push blocking 已由 owner 於 2026-07-13 確認完成；R-J01 亦已由 PR #3 hosted green 與 active ruleset `18842326` 完成。Classic branch-protection endpoint 不是 ruleset 的 canonical 證據；驗收以 ruleset detail、branch rules 與 `main.protected=true` 三者為準。
2. 行號以 head 60768f3 為準，修復過程會位移；以 ID 與 commit snapshot 追溯。
3. 上游與模型外部事實最後查證於 2026-07-13；Wave-4（R-F02）與模型 policy 實作時必須重新確認最新 release、client、plan 與組織 policy 可用性。
4. 本清單原則上排除 `projects/` 與 `learning/` 的 consumer drift；R-D12 是唯一已裁定的受控例外，因 shared agent 移除必須先確保 japanese-learning 的 project-local runtime 不退化。不得藉此擴張成舊 consumer 全面修復。
5. 前兩輪合計 36 個 agents 已調查/對抗驗證；第三輪另由 Codex 主代理與 3 個獨立驗證 agents 複核 owner decisions。未逐項三次驗證的 Medium/Low findings 仍須在各批開工時重新確認，不得只依 2026-07-12 行號施工。

## 8. Ledger 維護規則

本文件第 3 節是 open-findings 單一總帳的起始版本（R-E11 的落地）。維護規則：

1. Finding 狀態使用 `OPEN`、`DECIDED`、`IN_PROGRESS`、`COMPLETED`、`DISPOSITIONED`；`DECIDED` 不是完成。
2. 每批修復完成後，在對應 ID 加註完成日期、commit hash、mainline note 與驗收證據；若裁定不修則標 `DISPOSITIONED` 並記理由。
3. 第 6 節的 owner decisions 只有在對應 finding 全部 `COMPLETED` 或 `DISPOSITIONED` 時才可關閉；合併 ID 必須逐 ID 記錄。
4. 新發現的問題以新 ID 追加（依區域字母 + 流水號）。
5. 狀態變更走日期化增補，不靜默改寫既有判斷（沿 `docs/README.md` 慣例）。事實前提被推翻時，保留 revision history 並明示 superseding evidence。

## 9. 2026-07-13 決策複核的外部依據

| 主題 | 官方 / 第一方來源 | 本文件採用方式 |
|---|---|---|
| 公開 repo 與 LICENSE | [GitHub：Licensing a repository](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository) | 公開不等於開源；無 LICENSE 時預設著作權保留；root LICENSE 不能授權第三方內容 |
| Vendored 來源現況 | [doggy8088/github-copilot-configs](https://github.com/doggy8088/github-copilot-configs) | 來源 repo 無 root LICENSE，且現行 main 已移除同步 agents；不再作為 installer 的 floating source |
| 可治理的 agent 來源 | [github/awesome-copilot MIT LICENSE](https://github.com/github/awesome-copilot/blob/main/LICENSE) | 未來若重新引入，只挑選需要資產、固定來源 commit/hash 並保留授權與 manifest |
| Anthropic 模型生命週期 | [Anthropic：Model deprecations](https://platform.claude.com/docs/en/about-claude/model-deprecations) | Opus 4.7 仍 Active；R-D06 不以迫近退役為理由 |
| Copilot 模型可用性 | [GitHub：Supported AI models in Copilot](https://docs.github.com/en/copilot/reference/ai-models/supported-models) | 實際可用性仍受 plan、client 與組織 policy 影響，不 blanket pin 新版號 |
| Claude subagent model | [Claude Code：Create custom subagents](https://code.claude.com/docs/en/sub-agents) | model 可省略或使用 `inherit`；支持 R-D06 的低維護預設 |
| Commit email privacy | [GitHub：Setting your commit email](https://docs.github.com/en/account-and-profile/how-tos/email-preferences/setting-your-commit-email-address)、[Blocking exposing pushes](https://docs.github.com/en/account-and-profile/how-tos/email-preferences/blocking-command-line-pushes-that-expose-your-personal-email-address) | 未來使用 noreply 並啟用帳戶保護；既有歷史不重寫 |

## 10. Revision History

| Version | Date | Changes |
|---|---|---|
| 1.0.0 | 2026-07-12 | 初版宣稱 95 條 repair inventory（後由 v1.1.0 重算為 109 條）、9 批次草案與未裁定 owner decision 表。 |
| 1.1.0 | 2026-07-13 | 第三輪獨立複核；把初版錯算的 95 條修正為實際 109 條與正確嚴重度分布；修正 8 類錯誤/過時前提；記錄 18 項 owner decisions；改成 7 個風險優先批次；更新工期、依賴、限制、ledger 狀態與外部依據。 |
| 1.2.0 | 2026-07-13 | 啟動 R0：完成本機實作與驗證前置；staged hook 發現並修正 R-A14，current ledger 成為 110 條；新增日期化執行增補；待 implementation commit 存在後再把可關閉項目改為 COMPLETED 並回填 hash。 |
| 1.2.1 | 2026-07-13 | 以 implementation commit `bdd2780` 完成 R0 帳務：可關閉 findings 與 owner decisions 改為 COMPLETED；R-J02 保持 IN_PROGRESS，因 GitHub account privacy / push-blocking 仍需 owner 操作。 |
| 1.3.0 | 2026-07-13 | R1 本機與 CI implementation commit `e543f6a`：audit/registry/note gate fail-closed、PowerShell 7 與 UTF-8/LF、change-manifest 原子退役、branch reconciliation、CI hardening 與 320-test coverage baseline；R-J02 依 owner 確認完成，R-J01 等 hosted check 後啟用 ruleset。 |
| 1.3.1 | 2026-07-13 | 完成 R1 遠端驗收：PR #3 hosted run `29209698022` 在 head `f601685` 成功；active ruleset `18842326` 要求 PR 與 strict `audit-and-tests`，禁止 deletion/non-fast-forward，無 bypass actor，且 API 複驗 `main.protected=true`；同步修復 Ready-note fixture 的狀態依賴並升級 Node 24 action pins。 |
| 1.3.2 | 2026-07-13 | 啟動 R2 並以 commit `29adc67` 部分修復 R-B06：script dispatch 固定 ProjectRoot cwd；plan prep、operator handoff 與 plan agent path discovery 使用明確 feature context；新增 cross-feature、off-cwd、direct-child 與 path-boundary tests。RunState relocation 與 canonical feature-ID 分裂仍 open，R-B16 維持 DECIDED。 |
| 1.4.0 | 2026-07-14 | R2 唯讀獨立驗證（5 代理對抗驗證 + 舊實作 mutation 實測 8/8 discriminating）確認 R-B06 兩項修復屬實、PR #3 threads 維持 resolved；新增 R-A15/R-A16/R-B17/R-B18（總數 110 至 114）。commit `df31106` 修復前三條：hook UTF-8 fail-closed 解碼、engine feature rebind 防護（含 resume 竄改驗證）、contract 錨定多行 token；R-B18 保持 open。 |
| 1.5.0 | 2026-07-14 | R2 主批 workflow engine 執行完整性實作：關閉 R-B01 至 R-B06（剩餘）、R-B10 至 R-B16（見第 15 節）。提交前 3 代理對抗 review 發現並修復 5 缺陷。完整 governance suite 361 passed / 0 failed，audit VALID=true。sdd-pipeline 仍 experimental/denied，R-B07/B08 留 R3、R-B09 留 R6。 |
| 1.6.0 | 2026-07-14 | R2.1 誠實性還原：2026-07-14 治理 re-review 以本地反例推翻 R-B02（RVR-01）與 R-B05（RVR-03）的 COMPLETED，兩者改回 IN_PROGRESS 並移交 R-B19/R-B20；新增 9 條 RVR findings（R-A17/A18/A19、R-B19/B20/B21/B22、R-C08、R-F06），ledger 由 114 增至 123（機器重數 Critical 8/High 28/Medium 49/Low 38）；engine-integrity note 降回 Draft 加 Revalidation（見第 16 節）。本批不改 runtime 程式碼。 |
| 1.7.0 | 2026-07-15 | RB-1 implementation commits `cb43de5`、`961df61` 關閉 RVR-01/02/03 與 R-B19/R-D02/R-B08/R-B20，並以判別性回歸證據恢復 R-B02/R-B05 的 COMPLETED；post-commit 複核新增 High R-B23，ledger 由 123 增至 124（Critical 8/High 29/Medium 49/Low 38）。完整 suite 428 passed / 0 failed；audit VALID=true、0 errors、0 warnings。分支仍 NOT READY TO MERGE，見第 17 節。 |
| 1.8.0 | 2026-07-18 | RB-2 對抗複核發現 manifest version mismatch 時 listing 授權、runner 拒絕，推翻 R-B20/R-B05 的完整 shared-criterion closure；先將兩者還原為 IN_PROGRESS，RB-1 note 降為 Draft 且 reconciliation 改為 Open。本版只記錄 superseding evidence 與重新進入條件，不把尚未落地的 runtime 修補冒充完成，見第 18 節。 |
| 1.9.0 | 2026-07-18 | RB-2 restart 對抗複核以固定時鐘重現同秒 archive collision：第二次 `-Restart` 因秒級名稱與 `Move-Item -Force` 覆寫第一份 state。R-B10 的 archive 保留子宣稱還原為 IN_PROGRESS，新增 Medium R-B24，ledger 由 124 增至 125（Critical 8/High 29/Medium 50/Low 38）。本版只記錄 superseding evidence，不把尚未落地的 runtime 修補冒充完成，見第 19 節。 |
| 1.10.0 | 2026-07-18 | RB-2 implementation commit `ec25c07` 完成 R-B21、R-B07、R-B22；修復共用 manifest/reparse-point 授權與 restart archive no-overwrite，恢復 R-B20/R-B05、R-B10/R-B24 的 COMPLETED。現行 focused suite 353/0、完整 suite 579/0、audit 0/0；R-B23、R-A17、R-A18 保持 OPEN，ledger 維持 125 條，見第 20 節。 |
| 1.11.0 | 2026-07-20 | RB-3 implementation commit `4f757e5` 完成 R-A17/R-A18；新增並完成 High R-A20，新增且保留 Medium R-A21 為 OPEN。ledger 由 125 增至 127（Critical 8 / High 30 / Medium 51 / Low 38）。Batch gate 全綠；Aggregate gate 只因 Wave-3 umbrella note 仍 Draft 而如實失敗。分支仍 NOT READY TO MERGE，見第 21 節。 |
| 1.12.0 | 2026-07-20 | RB-4 implementation commit `9819e30` 完成 R-C01/R-C02/R-C03/R-C05/R-C07/R-C08、R-A19 與 R-F06；記錄 owner 核准 R-C03 為 schema gate 必要相依，並保留 R-C04/R-C06/R-F04 為 OPEN。完整 suite 664/0、audit 0/0；ledger 維持 127 條，分支仍 NOT READY TO MERGE，見第 22 節。 |
| 1.13.0 | 2026-07-20 | RB-5 implementation commit `78c47eb0f3da7e75f3ba79943ea44f55984677a1` 完成 R-D01/R-D04/R-D05/R-E07，新增 High R-A22；migration commit `26da9a7412d902f2dfff48df23d04662687f4a9d` 封存 18 份歷史 note 證據並完成 R-A22。R-E09 的歷史 note 子項完成但整項維持 IN_PROGRESS。ledger 增至 128（Critical 8 / High 31 / Medium 51 / Low 38）；分支仍 NOT READY TO MERGE，見第 23 節。 |
| 1.14.0 | 2026-07-20 | Post-accounting gates at head `64669c43d531d9dd699d60e163e7b1c755d64963` refute only RB-5 Ready and R-A22 closure: Pester remains 737/0/0, but runtime audit has one sealed-snapshot mismatch, Batch has 22 errors, and Aggregate has 19. R-A22 returns to IN_PROGRESS; R-D01/R-D04/R-D05/R-E07 remain COMPLETED and R-E09 remains IN_PROGRESS. Counts stay 128 and 8/31/51/38; see Section 24. |
| 1.15.0 | 2026-07-20 | Repair commit `3666c4e9a6553ff82774d4a06037f48846d8b0fd` restores exact production baseline reconstruction: committed audit is VALID with 18/18 sealed records, and the dedicated validator file is 91/91 with production-positive plus five shape/type/null negatives. R-A22 returns to COMPLETED; R-E09 remains IN_PROGRESS. Counts stay 128 and 8/31/51/38; final accounting gates remain pending; see Section 25. |
| 1.16.0 | 2026-07-20 | RB-5 final gates at accounting head `44f768a12316cdb008f1fee263e03ed7ce9a8191` are complete: full suite 742/0/0/0, runtime audit VALID 0/0 with historical sealed evidence 18/18, Batch VALID 0/0 from base `de61431ae8f50d66f59157e00e4d239e9b37efdb`, Aggregate has exactly the expected umbrella `aggregate-note-not-ready`, and diff/worktree hygiene is clean. R-A22 remains COMPLETED; R-E09 remains IN_PROGRESS. Counts stay 128 and 8/31/51/38; R6 owner decisions remain open; see Section 26. |
| 1.17.0 | 2026-07-21 | R6 evidence implementation `aef41b1bac2e56bf717d9ded5328c3c601fd7037` adds one isolated fresh-fixture journey and a contract-bound revert negative. Focused E2E is 1/0, the full suite is 744/0/0/0, and committed runtime audit is VALID 0/0 with historical evidence 18/18. The evidence sub-batch is completed, while R6 overall, R-E09, R-E11, residual dispositions, promotion, Aggregate, merge, and post-merge evidence remain open; see Section 27. |
| 1.18.0 | 2026-07-21 | R6 evidence accounting head `28fbc8280000124e15c9c4913f6c130af1df78bb` passes runtime audit and Batch with 0 errors and 0 warnings, validates historical evidence 18/18, and has clean diff/worktree hygiene. Aggregate returns exactly one expected `aggregate-note-not-ready` for the Draft Wave-3 umbrella. The evidence sub-batch remains COMPLETED; R6 overall and every retained blocker remain open. Counts stay 128 and 8/31/51/38; see Section 28. |
| 1.19.0 | 2026-07-21 | Owner-authorized accounting-only reconciliation records final tested head `f2df26e98300c034f7fa03c7831b8f00aa6c470a`: full suite 744/0/0/0, runtime and Batch VALID 0/0, historical evidence 18/18, and exactly one expected Aggregate umbrella blocker. The stale claim that fresh-fixture evidence remained pending is superseded without changing any finding disposition, promotion state, or merge authorization. Counts stay 128 and 8/31/51/38; see Section 29. |
| 1.20.0 | 2026-07-21 | Truth restoration for the R-D03 self-application entry defect. Attempt `8101f9a380eb27c5004bece9aad77d42b2cc8a51` passed its technical gates but cannot close R-D03 because no committed R-D03-only plan preceded implementation. This version restores the pre-R-D03 semantics, keeps the note Draft/Open, and records the owner's explicit 2026-07-21 authorization for a clean re-entry after this plan commit. Counts remain 128 and 8/31/51/38, with folded status unchanged at 75 COMPLETED / 46 OPEN / 6 DECIDED / 1 IN_PROGRESS; see Section 30. |
| 1.21.0 | 2026-07-21 | Authorized clean re-entry commit `2f941002009b1e05b33d790e7c6c8fc06e8daf3c`, whose parent contains reset and plan commit `687625af6a9df299c1037e1ba3ec29ef154dc6d3`, completes R-D03 without reusing refuted attempt `8101f9a` as closure evidence. Focused old semantics are 18/2, new semantics are 20/0, coordinated mutation is 1/0, the implementation-head full suite is 747/0/0/0, and runtime is VALID 0/0. R-D03 becomes COMPLETED; folded status is 76 COMPLETED / 45 OPEN / 6 DECIDED / 1 IN_PROGRESS. Accounting-head Batch and Aggregate gates remain pending; see Section 31. |
| 1.22.0 | 2026-07-21 | Final verification of accounting head `7ad8bb76eccccf91a7b87954ce19f97c3ff12951`: exact-tree full suite 747/0/0/0, runtime VALID 0/0 with historical evidence 18/18, Batch VALID 0/0 across 10 paths from `687625af6a9df299c1037e1ba3ec29ef154dc6d3`, exactly one expected Aggregate `aggregate-note-not-ready`, and clean diff/worktrees. This supersedes only the pending-gate text in Section 31; R-D03 remains COMPLETED and every other disposition is unchanged; see Section 32. |
| 1.23.0 | 2026-07-21 | During the owner-authorized read-only R6 residual audit, drift-stop found that the original owner decision and final folded counts treat R-F04 as DECIDED while later RB-4 records call it OPEN. The owner selected DECIDED on 2026-07-21, meaning the retirement direction remains authorized but unimplemented. This version commits only the prospective truth-restoration plan; it does not yet append a latest-status row, change a finding disposition, or resume the residual audit. See Section 33. |
| 1.24.0 | 2026-07-21 | After committed owner-authorized plan `bab1ce93aec28819a0c68a3ed7f6e85d3de53442`, this accounting-only implementation appends the authoritative R-F04 latest-status clarification: DECIDED means retirement is authorized but unimplemented. It supersedes only the later RB-4 OPEN label, preserves R-H15 as DECIDED and every other finding disposition, and reconciles the existing 128-item fold as 76 COMPLETED / 45 OPEN / 6 DECIDED / 1 IN_PROGRESS. Final committed-accounting gates remain pending; see Section 34. |
| 1.25.0 | 2026-07-21 | Final accounting for implementation `180abc05b8eaaa6fb32a753e81931f14e10ef726`. After a drift-stop proved the obsolete no-scope command incompatible with R-A20, the owner selected the current explicit-scope contract: Batch must be green and Aggregate may retain only the canonical umbrella blocker. The exact accounting tree passes the 747-test suite, runtime VALID 0/0 with historical evidence 18/18, Batch VALID 0/0 across 5 paths from `6b749a1`, and diff hygiene; Aggregate has exactly the expected umbrella blocker. R-F04/R-H15 remain DECIDED but unimplemented, the five umbrella coverage obligations remain under R-E09, and the fold stays 76/45/6/1. See Section 35. |
| 1.26.0 | 2026-07-21 | Owner Choice A authorizes a prospective conservative R6 convergence plan: keep `sdd-pipeline` non-promoted and denied, directly repair 17 bounded safety and truthfulness findings, and later disposition 35 non-critical items to Wave-4 with explicit re-entry triggers. Residual audit adds OPEN R-B25 and R-B26, raising the ledger to 130 findings with severity 8/31/52/39 and current fold 76 COMPLETED / 47 OPEN / 6 DECIDED / 1 IN_PROGRESS. This version is plan-only: no existing finding is completed or dispositioned, R-E09/R-J03 remain terminal blockers, and implementation may start only after this plan is committed. See Section 36. |
| 1.27.0 | 2026-07-22 | R6-A1 preflight found a material scope drift after plan commit `f669e3d`: the Constitution classifies `.claude/agents/*.md` as seeded dependent mirrors, while the generator, 15 generated mirrors, Copilot adapter, both quickstarts, WORKSPACE_STRUCTURE and runtime contract still call them source/runtime authority. Owner authorizes new High OPEN R-H20 and direct repair before implementation. Ledger becomes 131 findings with severity 8/32/52/39 and current fold 76 COMPLETED / 48 OPEN / 6 DECIDED / 1 IN_PROGRESS; the direct set becomes 18 including R-D07. No prior status changes. See Section 37. |
| 1.28.0 | 2026-07-22 | R6-A1 implementation preflight found that treating the whole `.github/agents/` directory as canonical would contradict its dependent `copilot-instructions.md` adapter and omit the non-`.agent.md` generator input `async-python-reviewer.md`. Owner Choice A refines R-H20 to an exact current partition: 14 `*.agent.md` files plus `async-python-reviewer.md` are canonical inputs, `copilot-instructions.md` remains dependent, and all 15 generated Claude files remain dependent mirrors. Counts and statuses do not change. See Section 38. |
| 1.29.0 | 2026-07-22 | Bootstraps the R-E11 machine-bounded `finding_status` authority after exact-partition plan `9b83f7a`. Revision 1 records all 131 IDs without changing any status: 76 COMPLETED / 48 OPEN / 6 DECIDED / 1 IN_PROGRESS / 0 DISPOSITIONED; R-E11 and R-H20 remain OPEN. The document as a whole remains informational, the R6 note remains Draft/Open/TBD, and closure requires a later accounting revision after committed implementation and exact-tree gates. See Section 39. |
| 1.30.0 | 2026-07-22 | Appends revision 2 after implementation `105a09c` and accounting-sequence plan `3e64e4e`. Only R-D07/R-E02/R-E08/R-E11/R-H03/R-H04/R-H20 become COMPLETED, producing 83 COMPLETED / 42 OPEN / 5 DECIDED / 1 IN_PROGRESS / 0 DISPOSITIONED across the unchanged 131 findings. The dedicated R6-A1 note remains Draft/Open until a later note-only finalization and exact-tree gates; R6-A2 through R6-A6 remain pending. See Section 40. |
| 1.31.0 | 2026-07-22 | Appends revision 3 after finalization head `8f0dd46` exposed a no-op hard-coded finding-status index mutation and stale note-state prose in `docs/README.md`. Only R-E11 returns from COMPLETED to IN_PROGRESS, producing 82 COMPLETED / 42 OPEN / 5 DECIDED / 2 IN_PROGRESS / 0 DISPOSITIONED; the dedicated R6-A1 note returns to Draft/Open. See Section 41. |
| 1.32.0 | 2026-07-22 | After fixture repair `ea78b64` and committed re-entry correction `483947a`, the clean repair-and-plan tree passes 878 governance tests with 0 failures, runtime `VALID=true` with 0 errors and 0 warnings, and valid three-revision history. Revision 4 changes only R-E11 from IN_PROGRESS to COMPLETED, producing 83 COMPLETED / 42 OPEN / 5 DECIDED / 1 IN_PROGRESS / 0 DISPOSITIONED across the unchanged 131 findings. The dedicated R6-A1 note remains Draft/Open pending final exact-tree gates and note-only finalization. See Section 42. |
| 1.33.0 | 2026-07-22 | Appends revision 5 after finalization head `f0f325b` failed explicit Batch readiness with `branch-evidence-coverage-missing` for `docs/README.md`: the Ready note could not cite that same commit's previously unknown hash as the path's last-touch evidence. Only R-E11 returns from COMPLETED to IN_PROGRESS, producing 82 COMPLETED / 42 OPEN / 5 DECIDED / 2 IN_PROGRESS / 0 DISPOSITIONED; the dedicated note returns to Draft/Open. The interrupted exact-tree suite is not closure evidence. See Section 43. |
| 1.34.0 | 2026-07-22 | After honesty demotion `4ce95a4ed2ce941ae2291dd1002b6c7f99bbb59a` and committed non-self-referential plan `f4ca59d274fffe8f1e49950d8bf796b95eda05d6`, the clean five-revision tree passes 878 governance tests with 0 failures, runtime `VALID=true` with 0 errors and 0 warnings, and valid history at fold 82/42/5/2/0. Revision 6 changes only R-E11 from IN_PROGRESS to COMPLETED, producing 83 COMPLETED / 42 OPEN / 5 DECIDED / 1 IN_PROGRESS / 0 DISPOSITIONED across 131 findings. The dedicated note remains Draft/Open/Batch until a later two-file finalization can cite this accounting commit's real hash. See Section 44. |
| 1.35.0 | 2026-07-23 | After committed plan `a45b7d33a59dd41d7765d29626bf43d2adb02cca`, revision 7 registers new Medium R-E13 as OPEN before trigger-authority implementation begins. Inventory becomes 132 with severity 8/32/53/39 and fold 83 COMPLETED / 43 OPEN / 5 DECIDED / 1 IN_PROGRESS / 0 DISPOSITIONED. Revisions 1 through 6 remain immutable, R-E11 remains COMPLETED, and no A2 through A4 finding is closed or Wave-4 item dispositioned. See Section 45. |
| 1.36.0 | 2026-07-23 | After committed R6-A2 implementation `814cc6169e6d1bf9167ce91249dbd58ac548674d`, R6-A3 implementation `be5fb24fd79a47d8f0db9f61be2a747d06b29088`, R6-A4 implementation `32a58e653cc4b541db88b23ad4b90fd7b81007a5` and trigger-contract implementation `5e99ad9569cc0212212a0191193702c25f6af052`, revision 8 changes exactly R-A21/R-B18/R-B25/R-B26/R-C04/R-C06/R-G01/R-G03/R-G04/R-H06/R-H09/R-E13 from OPEN to COMPLETED. The fold becomes 95/31/5/1/0 across 132 findings. See Section 46. |
| 1.37.0 | 2026-07-23 | Revision 9 changes exactly the thirty OPEN and five DECIDED findings authorized in Sections 36.2 and 37.1 to DISPOSITIONED, with the exact owner-approved `reentryTrigger` on every entry. Inventory and severity remain 132 and 8/32/53/39; the fold becomes 95 COMPLETED / 1 OPEN / 0 DECIDED / 1 IN_PROGRESS / 35 DISPOSITIONED. R-E09 remains IN_PROGRESS and R-J03 remains OPEN. See Section 46. |
| 1.38.0 | 2026-07-26 | After committed wave-3 plan Section 38 amendment `f428029467f3ba214ee6eef1eb6b4d5983f28aed`, the owner reproduces the elevated fixture failure in a directly executed canonical pwsh 7.5.4 terminal whose console code page is 950: `Invoke-RuntimeAuditFixture` decodes UTF-8 child audit output with the parent console encoding, corrupting non-ASCII contract text into unparseable JSON while the child audit itself reports the expected ten governed failures. Revision 10 registers new Medium R-A23 as OPEN before the fixture repair begins. Inventory becomes 133 with severity 8/32/54/39 and fold 95 COMPLETED / 2 OPEN / 0 DECIDED / 1 IN_PROGRESS / 35 DISPOSITIONED. Revisions 1 through 9 remain immutable. See Section 47. |
| 1.39.0 | 2026-07-26 | Repair `f8d064c81b592e1c42966a68db6325f1685db089` rewrites the fixture capture with an explicit UTF-8 process-output decoder and adds the discriminating test, which fails against the pre-repair helper grafted into a clean worktree and passes against the repaired helper. The owner then verifies both the previously failing bad-state test and the new test green in the same canonical CP950 pwsh 7.5.4 terminal that reproduced the defect. Revision 11 records R-A23 as COMPLETED; the fold becomes 96 COMPLETED / 1 OPEN / 0 DECIDED / 1 IN_PROGRESS / 35 DISPOSITIONED across 133 findings. CI calibration `742a7fba7cbf088195211f0e35432c4734858b78` and README truthfulness `b63dff89fda341c3d291e48a57403458d5033deb` land as batch-scoped delivery-surface repairs under plan Section 38 without changing any finding status. See Section 48. |

## 11. 2026-07-13 R0 執行增補

本節是第 3 節對應 findings 的日期化狀態記錄，不改寫原始問題證據。R0 本機實作與完整
驗證已由 implementation commit `bdd2780` 留證；能由本批關閉的項目標為 `COMPLETED`。
R-J02 的 workspace-scoped conditional include 與 GitHub account email privacy / push blocking 均已完成；既有歷史依裁定不重寫。

| ID | 目前狀態 | 已落地處置 | 驗收證據 / 尚待事項 |
|---|---|---|---|
| R-G13 | COMPLETED | 四份 workspace 分析與索引已納入本批 | commit `bdd2780` |
| R-A14 | COMPLETED | removed nested source root 不再被誤當成仍存在的 adapter project；project root 尚存在時仍照常驗證 | removed-root regression test、contract invariant 與 staged hook 全綠；commit `bdd2780` |
| R-B09 | COMPLETED | catalog 已降為 experimental、非 approved、非 default-enabled，approval 欄位清空 | listing/schema negative test 已加；runner authorization 仍是 R-B05 的 R2 範圍，不在本 finding 冒充關閉；commit `bdd2780` |
| R-H01 | COMPLETED | root MIT、README License 段與 conservative `THIRD_PARTY_NOTICES.md` 已建立 | Spec Kit notice 保留完整 MIT；commit `bdd2780` |
| R-H02 | COMPLETED | 392-file tracked vendor snapshot 已完整移除，來源取證已留存，原路徑加入 external-intake ignore | 391/392 blobs 對應來源 commit `e5969f1cc89a60c931049bd41dce55eaa8e6037f`；唯一差異為來源工作設定檔；commit `bdd2780` |
| R-H05 | COMPLETED | `bone.ini` 與空 `studio/tools/` 已刪除 | 已確認無 live structure reference；commit `bdd2780` |
| R-H08 | COMPLETED | 舊 installer 與 README 入口已移除 | commit `bdd2780` |
| R-H11 | COMPLETED | root 與 project template ignore 加固；pre-commit 對 active protected destinations fail-closed，且不列印檔名 | privacy suite 63/63；full governance 265 passed、0 failed、1 expected skip；staged hook 綠；commit `bdd2780` |
| R-H12 | COMPLETED | 只刪除 root ignored `testResults.xml` 殘留 | `studio/tests/_artifacts/` 保留；本機處置由 batch note 與 commit `bdd2780` 留證 |
| R-H13 | COMPLETED | 本機空 `archive/` 已刪除，README 與 WORKSPACE_STRUCTURE 列項已移除 | commit `bdd2780` |
| R-H17 | COMPLETED | 漂移的單一繁中 agent 與目錄已刪除 | canonical agents 未變；commit `bdd2780` |
| R-G10 | COMPLETED | `docs/basic-prompt.txt` 已刪除且未搬入 prompts | commit `bdd2780` |
| R-I07 | COMPLETED | 本機空 `studio/templates/feature-packs/` 已刪除 | 無 tracked directory；batch note 與 commit `bdd2780` 留證 |
| R-I08 | COMPLETED | 本機空 `studio/knowledge-base/pain-points/` 已刪除 | 憲法 optional 定義保留；batch note 與 commit `bdd2780` 留證 |
| R-J02 | COMPLETED | workspace-scoped conditional include 已套用 GitHub noreply，7/7 discovered repos 驗證通過；未重寫歷史、未覆寫既有 global identity；owner 已確認 GitHub account privacy 與 push-blocking | 本機與帳戶側均於 2026-07-13 完成；既有歷史依裁定不重寫 |

R0 mainline note：`docs/mainline-updates/2026-07-13-r0-containment-and-source-cleanup.md`。

## 12. 2026-07-13 R1 執行增補

R1 本機與 CI 實作由 commit `e543f6a` 留證，clean-runner fixture 修復由 `f601685` 留證。
下列 findings 均已完成；R-J01 另以 PR #3 hosted run `29209698022` 與 active
`main-governance` ruleset `18842326` 完成伺服器端驗收。

| ID | 目前狀態 | 已落地處置 | 驗收證據 / 尚待事項 |
|---|---|---|---|
| R-A01 | COMPLETED | issue collections 在首次使用前初始化，missing powershell-yaml 不再被清空 | isolated module negative fixture；commit `e543f6a` |
| R-A02 | COMPLETED | workflow catalog/state/schema、canonical schema shape、cross-ledger policy 與 dependency invalid 全部升格 failure | missing/null/scalar/permissive schema、invalid catalog、activation policy negative fixtures；commit `e543f6a` |
| R-A03 | COMPLETED | 所有 audit output collections 預設為穩定陣列 | missing-contract 與 empty workflow array shape tests；commit `e543f6a` |
| R-A04 | COMPLETED | `.github/agents/` 改為 contract 顯式封閉清單 | undeclared file negative fixture、3-file non-command allowlist；commit `e543f6a` |
| R-A05 | COMPLETED | 全部 non-test runtime PS1 宣告 PowerShell 7，文件與命令統一 `pwsh` | AST 掃描與 Windows PowerShell 5.1 fail-fast test；commit `e543f6a` |
| R-A06 | COMPLETED | audit 建立隔離壞狀態 workspace fixtures | missing module/state/agent、invalid registry、stale generated registry、invalid Ready note、CI disconnect 均非零；commit `e543f6a` |
| R-A07 | COMPLETED | audit 本身驗 requiredCommands 聯集與 disjoint | contract mutation negative fixture；commit `e543f6a` |
| R-A08 | COMPLETED | CI 產 NUnit 與 Cobertura artifact，runner/CI 固定 Pester 5.7.1 | 320 passed；command 0.71%，line 42/5,206（0.81%）；child-process 歸因限制已寫入 R1 note |
| R-A09 | COMPLETED | note 狀態機、index parity 與 hash-bound R5 migration ledger 進 audit | Ready/Merged、index、baseline mutation negative tests；18 份歷史債務未冒充修復 |
| R-A10 | COMPLETED | agent-scoped subset 強制 leading authority、禁獨立 bootstrap、要求 parent adapter reference | 4 個 bootstrap negative/positive tests；commit `e543f6a` |
| R-A11 | COMPLETED | seed writer 改 UTF-8 no-BOM/LF，重建 15 mirrors，刪除 16 個 backup 檔並加 ignore | deterministic seed 與 byte scan tests；commit `e543f6a` |
| R-A12 | COMPLETED | root/project-init `.gitattributes`、`.editorconfig` 與 LF writers 落地 | tracked text 0 BOM/CR/missing-final-LF；fresh project sync idempotent；commit `e543f6a` |
| R-E05 | COMPLETED | commit-time advisory 保留，PR/main aggregate diff 對 `must_update` blocking | 17 個 note/reconciliation tests含 hidden-comment/fence bypass；commit `e543f6a` |
| R-E10 | COMPLETED | template 加 Reopened 回滾語義，3 份被 GOV-02/04/05 推翻的 notes 降為 Draft | note/index parity validator；commit `e543f6a` |
| R-G06 | COMPLETED | change-manifest hook/template/fixture/目錄/contract/prompt 全鏈退役，reconciliation 併入 mainline note | active runtime references 0；CI wiring invariant；commit `e543f6a` |
| R-H10 | COMPLETED | root 與 project-init 加 `.editorconfig` | policy parity test；commit `e543f6a` |
| R-H16 | COMPLETED | root 移除過寬 .NET ignores，template 將 `/packages/` 錨定；保留實際必要的 settings.local 規則 | ignore behavior tests；commit `e543f6a` |
| R-H19 | COMPLETED | weekly、main-only push/PR、SHA-pinned Node 24 actions、模組固定版、coverage artifacts 與 badge | checkout v7.0.0 與 upload-artifact v7.0.1 固定 commit；官方 refs、YAML parse、contract/negative fixture 與 live PR required check 驗收 |
| R-I06 | COMPLETED | README 與兩份 quickstart 的 executable examples 統一 `pwsh ./...` | contract 與全文掃描；commit `e543f6a` |
| R-J01 | COMPLETED | PR/main CI 已接 branch reconciliation；active ruleset `18842326` 要求 PR、strict `audit-and-tests`，禁止 deletion/non-fast-forward 且無 bypass actor | PR #3 head `f601685` 的 run `29209698022` 成功；ruleset detail 與 branch rules API 一致，`main.protected=true` |

R1 mainline note：`docs/mainline-updates/2026-07-13-r1-validation-and-merge-enforcement.md`。

## 13. 2026-07-13 R2 部分執行增補

R2 由 PR #3 的兩個 R-B06 review threads 啟動。implementation commit `29adc67` 已完成本節
所列 dispatch/context 修正；本機 focused suite 61 passed，完整 governance suite 328 passed，
shared runtime audit 為 `VALID=true`、0 errors、0 warnings。本節不把部分處置冒充整項關閉。

| ID | 目前狀態 | 已落地處置 | 驗收證據 / 尚待事項 |
|---|---|---|---|
| R-B06 | IN_PROGRESS | script child `pwsh` 固定於 `ProjectRoot`；setup-plan 與 prerequisite path discovery 支援 project-bounded explicit `FeatureDir`；pipeline prep 與 `/speckit.plan` operator/agent handoff 使用同一 feature context | off-cwd、branch/feature mismatch、outside-project、nested-path、YAML shape 與 mirror/contract tests 全綠；commit `29adc67`。尚待 RunState 移出 `specs/<feature>/` 並消除 fresh-run 預建目錄造成的 canonical feature-ID 分裂。 |
| R-B16 | DECIDED | 本批未移動 RunState，也未提前對舊位置寫入永久政策 | 依 owner 決策等待 R-B06 final relocation，再把最終 state 位置設為 local transient、加 gitignore 並同步 POLICY/README；跨機 resume 另走顯式 checkpoint export/import。 |

R2 partial mainline note：`docs/mainline-updates/2026-07-13-r2-r-b06-dispatch-consistency.md`。

## 14. 2026-07-14 R2 驗證加固增補

2026-07-13 對 R2 partial（`e4fa153..ccb7738`）完成唯讀獨立驗證：兩個 PR #3 review threads
的修復屬實（以 git archive 舊樹疊加新測試實測，8/8 新測試在舊實作失敗、新實作全綠；單獨
revert `-WorkingDirectory` 亦使測試轉紅），同意 threads 維持 resolved。驗證發現四條新
findings（R-A15、R-A16、R-B17、R-B18），前三條由 implementation commit `df31106` 修復。
提交前的對抗 review（2 代理）另發現 resume 路徑的 feature rebind 缺口與 audit 子程序編碼
不對稱，均已併入同批修復。本節不把部分處置冒充整項關閉。

| ID | 目前狀態 | 已落地處置 | 驗收證據 / 尚待事項 |
|---|---|---|---|
| R-A15 | COMPLETED | hook 強制 UTF-8 解碼並 fail closed；check-speckit-runtime 於輸出重導時對稱強制 UTF-8；CP437 console 回歸測試；contract token | 先前在 CP950 本機失敗的 2 條個資測試轉綠；完整 suite 由同機 326/2 變 333/0；commit `df31106`。殘餘：audit 互動式（非重導）輸出仍依 console 編碼，僅影響非 ASCII 錯誤訊息可讀性且 fail-closed |
| R-B17 | COMPLETED | fresh/resume 統一拒絕 operator feature 覆蓋；resume 驗證 saved `inputs.feature` 與錨定 feature 一致，legacy 缺值回填 | override、redundant-equal、resume-tamper、resume-override 4 條回歸測試全綠；contract invariant `workflow-engine-feature-input-guard`；commit `df31106` |
| R-A16 | COMPLETED | stage-plan-prep 以錨定多行 token 取代三個鬆散 token | audit VALID=true 0/0；模擬 revert 確認 token 會斷；commit `df31106` |
| R-B18 | OPEN | 本批僅記錄，未動 sibling 腳本與非 plan handoff | 待 R2/R3：收斂三種邊界等級、決定非 plan 階段 handoff 是否帶 `-FeatureDir` |

R2 verification-hardening mainline note：`docs/mainline-updates/2026-07-14-r2-verification-hardening.md`。

## 15. 2026-07-14 R2 Workflow engine 執行完整性增補

R2 主批（engine 執行完整性）已實作，關閉 GOV-01 至 GOV-13 對應的 R-B01 至 R-B06（剩餘）、
R-B10 至 R-B16。提交前 3 代理對抗 review 另發現 5 個缺陷（terminal 已滿足即鎖死、if/switch
replay history 未去重、executed workflow.yml 未綁定授權身分、runner 未強制 POLICY default-enable
不變量、runtime script header 與 QUICKSTART 的 RunState 路徑過期），全部於同批修復並補回歸測試。
本機 audit VALID=true、0/0；完整 governance suite 361 passed / 0 failed（批前同機 333）。

| ID | 目前狀態 | 已落地處置 | 驗收證據 |
|---|---|---|---|
| R-B01 | COMPLETED | gate decision 只作用於已 halt 的 pending gate；無 on_reject 的 reject 進 terminal `rejected`（exit 44）而非 pass-through | pre-supplied confirm 被忽略、reject-terminal、on_reject routing 回歸測試全綠 |
| R-B02 | IN_PROGRESS | [2026-07-14 重開，見 RVR-01/R-B19] 已加 `no-pending-tasks` postcondition 與 terminal `-AcceptAgent` 鎖定，但 postcondition 只驗「找不到 pending regex」，未保存/比對 baseline task-ID inventory；本地復現：換掉 tasks.md 為非 task 文字仍 completed。closure 不成立，改由 R-B19 收斂 | 先前四條測試僅覆蓋部分/全部勾選，未覆蓋刪 task/改 ID/破格/換文字；待 R-B19 baseline-inventory 修復與 negative tests |
| R-B03 | COMPLETED | DryRun 寫入 `state.dryrun.json` sidecar，正式 resume 永不讀取 | DryRun 後 resume 報 No RunState、正式 state 不受污染測試 |
| R-B04 | COMPLETED | 執行前遞迴收集全 step ID（含 then/else/on_reject/cases/default）拒絕碰撞 | 巢狀 duplicate id 拒絕測試 |
| R-B05 | IN_PROGRESS | [2026-07-14 重開，見 RVR-03/R-B20] 已加 catalog/state/manifest 存在性與身分/授權檢查與八條 denied 測試，但未套 catalog/state schema `Test-Json`，`defaultEnabled`/`enabled` 用 `[bool]` 轉型（`[bool]'false'`=`True` 已復現），missing-state 沿用 default 非 fail-closed。fail-closed closure 不成立，改由 R-B20 收斂 | 待 R-B20：schema 驗證、嚴格布林、missing/wrong-type/null fail-closed negative tests |
| R-B06 | COMPLETED | dispatch/context（`29adc67`）+ RunState 移至 `<project>/.workflow/runs/<feature>/`、fresh run 不再預建 `specs/<feature>` | 不配置 canonical feature ID 測試；本批完成 relocation |
| R-B10 | COMPLETED | 新增 `-Restart`：completed/failed/rejected/in-flight 皆需顯式 restart，舊 state 以 timestamped `.restarted.json` 封存 | reject-terminal 後 -Restart 復原、無 -Restart 拒覆蓋既有 state 測試 |
| R-B11 | COMPLETED | failed/denied payload 於 JSON 與 text 兩模式帶 ERROR 細節 | 失敗 payload ERROR.ExitCode 測試 |
| R-B12 | COMPLETED | command/gate/if/switch replay 以 `Add-RunStateHistoryOnce` 去重 | gate skip 與 switch matched-case 各記一次測試 |
| R-B13 | COMPLETED | 測試 fixture 改用 TestDrive 隔離 mini studio root（含 catalog/state/manifest），不寫真實 `studio/workflows/` | git status 零殘留；workspace root 由腳本自身位置錨定 |
| R-B14 | COMPLETED | 刪除未實作的 `runs/` index placeholder 與 POLICY 宣稱；POLICY 補 exit code 與授權說明 | audit 綠；repo 無 `workflows/runs` 引用 |
| R-B15 | COMPLETED | validate-workflow 驗 manifest entryPoints 存在性；修正 sdd-pipeline manifest（移除不存在的 scripts entry） | 不存在 entryPoint 失敗、live manifest 通過測試 |
| R-B16 | COMPLETED | RunState 定位本機暫態；workspace 與 project-init `.gitignore` 加 `.workflow/`；POLICY/README 同步 | 既有 consumer repo 需自行加 ignore 已於 POLICY 誠實揭露 |

殘留（已記錄非吸收）：R-B07/R-B08 留 R3、R-B09 re-promotion 留 R6；DryRun sidecar lock 與既有
consumer repo 的 `.workflow/` ignore 為選擇性強化項。

R2 engine-integrity mainline note：`docs/mainline-updates/2026-07-14-r2-workflow-engine-integrity.md`。

## 16. 2026-07-14 R2.1 誠實性還原增補

2026-07-14 治理 re-review（`docs/sdd-workspace-wave-3-governance-review-2026-07-14_zhTW.md`）以唯讀
反例檢查 26-commit 分支，確認 12 條 Critical/High findings。其中兩條以本地反例直接推翻本 ledger
先前的 `COMPLETED` 宣稱；依憲法 Surface Truthfulness 與第 8 節 ledger 維護規則，本批（R2.1）先還原
帳務真相，不改任何 runtime 程式碼。完整分批修復計畫見
`docs/sdd-workspace-wave-3-remediation-plan-2026-07-14_zhTW.md`。

**被推翻並重開的項目：**

| ID | 先前宣稱 | 推翻證據 | 現況 |
|---|---|---|---|
| R-B02 | COMPLETED（terminal postcondition 關閉 false completion） | RVR-01：進入 Implement 後把 tasks.md 換成非 task 文字，resume 即 completed（本地復現） | IN_PROGRESS，closure 移交 R-B19 |
| R-B05 | COMPLETED（runner fail-closed 授權） | RVR-03：`[bool]'false'`=`True`（本地復現）、未套 catalog/state schema、missing-state 沿用 default | IN_PROGRESS，closure 移交 R-B20 |

**12 條 RVR 對映與批次（RB-1 至 RB-5 + R6 見修復計畫）：**

| RVR | 對映 ledger | 批次 |
|---|---|---|
| RVR-01 假完成 | 重開 R-B02 + R-B19 | RB-1 |
| RVR-02 direct Implement 跳 gate | R-D02、R-B08 | RB-1 |
| RVR-03 授權 fail-open | 重開 R-B05 + R-B20 | RB-1 |
| RVR-04 RunState 未綁 graph | R-B21 | RB-2 |
| RVR-05 mainline gate 漏 shared paths | R-A17 | RB-3 |
| RVR-06 Ready-note evidence 只驗字串 | R-A18 | RB-3 |
| RVR-07 ECI 無 full dossier/re-entry/exactly-one | R-B07 + R-B22 | RB-2 |
| RVR-08 extension trust/scope/mutation/mirror | R-C01/02/05/07 + R-C08 | RB-4 |
| RVR-09 worktree/junction isolation | R-A19 | RB-4 |
| RVR-10 agent source/mirror 漂移 | R-D01、R-D04、R-D05 | RB-5 |
| RVR-11 upgrade 非原子 | R-F06 | RB-4 |
| RVR-12 無 SDD evidence + 主 note Draft | R-E07、R-E09 | RB-5 + R6 |

**note 狀態變更：** `docs/mainline-updates/2026-07-14-r2-workflow-engine-integrity.md` 依 note 狀態機
（template Reopened 規則）由 Ready 降回 Draft 並加 Revalidation section，指明 R-B02/B05 closure 被
RVR-01/03 推翻、其餘 R-B01/B03/B04/B06/B10-B16 項目仍成立。`2026-07-14-r2-verification-hardening.md`
（R-A15/A16/B17）與 R1 note 的具體受測宣稱未被推翻，維持 Ready；其 coverage 完整性缺口以新 findings
R-A17/A18 記錄，不整份降級。

R2.1 mainline note：`docs/mainline-updates/2026-07-14-r2-1-truth-restoration.md`。

## 17. 2026-07-15 RB-1 Critical 止血增補

RB-1 依 `docs/sdd-workspace-wave-3-remediation-plan-2026-07-14_zhTW.md` 第 2 節執行。第一個
implementation commit `cb43de5` 完成三組 Critical 修復；post-commit 獨立複核再以兩個反例
發現 ECI 證據可整組刪除、RunState baseline cache 可縮減的 closure blocker。repair commit
`961df61` 把 ECI 要求與五個 artifact hash 寫入 Analyze machine result，並加入 engine-owned、
write-once、identity-bound baseline sidecar；兩個新反例均由舊版的 false completion 改為 fail-closed。

**RB-1 狀態：**

| ID | 目前狀態 | 已落地處置 | 驗收證據 |
|---|---|---|---|
| R-B19 | COMPLETED | terminal Implement 首次抵達時保存 canonical task-ID baseline；完成時要求 baseline ID 全部仍以 canonical 格式存在、唯一且勾選；RunState copy 僅為 sidecar 驗證過的 cache | 五個指定 tamper 反例在舊實作全數 false-completed，新實作全數 denied；current terminal inventory block 9 passed |
| R-B02 | COMPLETED | 2026-07-14 被 RVR-01 推翻的部分 closure 已由 R-B19 的 baseline inventory 與判別性測試取代 | 刪 task、改 ID、破壞 canonical line、整份換成非 task 文字、空白化均 fail-closed |
| R-D02 | COMPLETED | canonical Implement agent 與 Claude mirror 的第一個動作均為不可繞過的 `setup-implement.ps1`；共用 schema-governed Analyze result | 舊 direct-entry gate 0 of 17；新 gate 17 of 17；terminal completion revalidation 13 of 13 |
| R-B08 | COMPLETED | Analyze machine result 綁定 readiness、conditional ECI、current artifact hashes、Critical findings 與 exact intent obligations；feature validator 對 readiness/ECI 結構 fail-closed | 舊 terminal set 僅 positive control 通過且 12 個 negatives false-completed；新 set 13 of 13 |
| R-B20 | COMPLETED | run/list 共用 trusted-schema authorization；catalog/state 先經 `Test-Json`，布林只接受 JSON Boolean，missing state 與不可信 schema fail-closed | 原 13 個 authorization cases 舊實作 0 of 13、新實作 13 of 13；expanded current set 15 of 15 |
| R-B05 | COMPLETED | 2026-07-14 被 RVR-03 推翻的 fail-closed closure 已由 R-B20 的共用判準與 strict Boolean 解析取代 | string Boolean、missing state、wrong type、null、scalar、permissive schema substitution 均 denied |

本節的日期化狀態 supersede 第 15 節 R-B02/R-B05 的 `IN_PROGRESS`、第 15 節「R-B08 留 R3」
與第 16 節的重開現況；舊節保留為當時證據，不靜默改寫。既有
`docs/mainline-updates/2026-07-14-r2-workflow-engine-integrity.md` 仍維持 `Draft`，因 R-B21 等
廣義 engine-integrity 工作尚未關閉；本批不以 R-B02/R-B05 恢復完成為由重新 promotion 舊 note。

RVR-01、RVR-02、RVR-03 因上述對映 finding 全部有 implementation commits、判別性測試與
contract invariant 而關閉。

| 判別性證據 | 舊實作或第一版結果 | repair head 結果 |
|---|---|---|
| RVR-01 指定五種 task tampering | 5 個均 false-completed | 5 個均 denied；current terminal inventory block 9 passed |
| post-review baseline cache shrink | `cb43de5` resume exit 0，false-completed | `961df61` denied，targeted case 1 passed |
| RVR-02 direct Implement gate | 0 of 17 通過驗收 | 17 of 17 通過驗收 |
| RVR-02 terminal revalidation | 僅 positive control 通過，12 個 negatives false-completed | 13 of 13 通過驗收 |
| post-review ECI trigger 與 dossier 全刪 | `cb43de5` completion exit 0，false-completed | `961df61` denied，targeted case 1 passed |
| RVR-03 workflow authorization | 原 13 cases 為 0 of 13 | 原 13 cases 為 13 of 13；expanded current set 15 of 15 |

完整 governance suite 在 repair head 為 428 passed、0 failed、0 skipped；runtime audit 為
`VALID=true`、0 errors、0 warnings。accounting head 的 Ready-note validator 使用
`-BaseRef origin/main -HeadRef HEAD -RequireReady -Json` 並要求 `VALID=true`；`git diff --check`
無錯誤。

**新增 finding：**

| ID | Severity | Finding | Required closure | 狀態 |
|---|---|---|---|---|
| R-B23 | High | [2026-07-15 RB-1 獨立複核 follow-up] RB-1 已用 engine-owned sidecar 檢出單獨竄改 RunState baseline cache，但 RunState 與 sidecar 都是本機暫態檔；協同偽造 state 與 sidecar、直接注入 `completed_steps` 等 authority fields、run ID 或 path substitution 的全面真偽邊界尚未形成單一可驗證設計 | 與 RB-2 相鄰設計 RunState/sidecar authenticity，明確綁定 run identity、authority fields 與 path；補協同偽造、direct completed-step injection、run-ID/path substitution 的 negative tests。與只處理 reviewed workflow graph digest 的 R-B21 分開 | OPEN |

R-B23 不包含已由 `961df61` 修復的 isolated baseline cache shrink、sidecar missing、malformed、
identity mismatch；這些 cases 已有 fail-closed 回歸證據，不得重複當作 open remainder。

**未吸收殘留：**

- RB-2：R-B07、R-B21、R-B22；R-B23 排在相鄰 authenticity 工作，但不併入 R-B21。
- RB-3：R-A17、R-A18，以及 remediation plan 指定的其餘 stage-agent 與 contract 工作。
- RB-4：R-C01/R-C02/R-C05/R-C07/R-C08、R-F06、R-A19 與其批次相依項。
- RB-5：R-D01/R-D04/R-D05、R-E07、RVR-12 對映項與其批次相依項。
- R6：fresh-fixture 七階段驗收、minimum gates、重新 promotion 與 main 合併後複驗。
- 既有 R-B18 與其他未完成 ledger findings 維持原狀；本批未吸收或改寫其範圍。

RB-1 mainline note：`docs/mainline-updates/2026-07-15-rb-1-critical-governance-gates.md`。
RB-1 完成使分支更接近可合併，但 PR #3 仍 `NOT READY TO MERGE`；`sdd-pipeline` 在 R6 前維持
experimental 與 execution-denied。

## 18. 2026-07-18 RB-2 對抗複核的 RB-1 誠實性還原

RB-2 開工後的獨立對抗複核建立隔離 registry fixture：catalog、state、trusted schemas、
enablement 與 workflow raw-byte digest 均有效，catalog 宣告 workflow version `1.0.0`，
但 `manifest.json` 宣告同一 ID 的 version `9.9.9`。同一 fixture 得到以下相反判定：

| Surface | Exit | Machine result |
|---|---:|---|
| `list-workflows.ps1` | 0 | `VALID=true`、`executionAuthorized=true` |
| `run-workflow.ps1` | 1 | `STATUS=denied`、workflow identity mismatch |

根因是 common registry authorization 未驗 manifest identity；runner 在共用判定之後另做
manifest ID/version 檢查，listing 沒有該檢查。這直接反駁第 17 節「run/list 使用同一完整判準」
的 closure 宣稱。依 Surface Truthfulness 與第 8 節 ledger 規則，本節先記錄降級，不把後續
runtime 修補倒填成已完成。

| ID | 目前狀態 | 未被推翻的既有修復 | 被推翻範圍與重新進入條件 |
|---|---|---|---|
| R-B20 | IN_PROGRESS | catalog/state trusted-schema 驗證、strict JSON Boolean、missing-state、wrong-type、null、scalar、schema substitution 與 workflow content digest 均仍 fail-closed | common registry 必須納入 manifest existence、JSON shape、ID 與 version，runner/list 共同消費同一結果；補舊 listing 通過而 runner 拒絕、新實作兩者都拒絕的判別性測試，並重跑完整 gates |
| R-B05 | IN_PROGRESS | R-B20 已驗證的 strict Boolean 與 fail-closed registry 輸入處置仍成立 | 其「runner/list 完整共同判準」依賴 R-B20，因此同步重開；只有 R-B20 的 manifest identity closure 重新成立後才可恢復 COMPLETED |

`docs/mainline-updates/2026-07-15-rb-1-critical-governance-gates.md` 已由 `Ready` 降回
`Draft`，Reconciliation Status 由 `Closed` 改為 `Open`，並加入同一反例與重新進入條件。
R-B19、R-B02、R-D02、R-B08 的具體 closure 未被本反例推翻，維持第 17 節狀態。
R-B21 只處理 reviewed workflow raw-byte graph identity；R-B23 處理 RunState/sidecar
authenticity，兩者都不得吸收此 manifest shared-criterion 修補。

## 19. 2026-07-18 RB-2 對抗複核的 restart archive 誠實性還原

RB-2 的獨立 RunState 對抗複核固定 `Get-Date`，對同一 feature 連續執行兩次
`-Restart`。既有 engine 以秒級時間戳組成固定 archive 名稱，並用 `Move-Item -Force`
搬移 `state.json`。兩次 restart 落在同一秒時只剩一份 archive，第二次覆寫第一份，
使第一個 run identity 與 state 證據不可恢復。這項反例推翻第 15 節 R-B10
「舊 state 以 timestamped `.restarted.json` 封存」的完整性宣稱。

依 Surface Truthfulness 與第 8 節 ledger 規則，本節先記錄降級，不把後續 runtime
修補倒填成已完成。R-B10 的顯式 restart 與 terminal/in-flight recovery 能力仍成立；
被推翻的是重複 restart 時每一份舊 state 都被保留的 archive 子保證。

| ID | Severity | 目前狀態 | 未被推翻的既有修復 | 被推翻範圍與重新進入條件 |
|---|---|---|---|---|
| R-B10 | Medium | IN_PROGRESS | completed、failed、rejected 與 in-flight run 可用顯式 `-Restart` 重新開始；沒有 `-Restart` 時仍拒絕覆蓋既有 state | archive 名稱必須具碰撞抗性，建立時不得覆寫既有檔案；固定同一時間連續 restart 的判別性測試必須保存兩份 archive，且各自保留不同 run identity |
| R-B24 | Medium | IN_PROGRESS | N/A，新 finding | [2026-07-18 RB-2 對抗複核] 秒級 archive 名稱與 `Move-Item -Force` 允許後一次 restart 覆寫前一次 restart 證據。closure 要求 collision-resistant 名稱、atomic no-overwrite 搬移，以及固定時鐘重複 restart 的 negative test；不得吸收到只處理 graph digest 的 R-B21 或本機 checkpoint authenticity 的 R-B23 |

`docs/mainline-updates/2026-07-14-r2-workflow-engine-integrity.md` 原已因 RVR-01/03
維持 `Draft`；本反例使其 Reconciliation Status 回到 `Open`，並新增日期化 Revalidation。
R-B24 是獨立 correctness finding；R-B23 仍只處理 RunState/sidecar authority 與 authenticity，
兩者不得互相吸收。

## 20. 2026-07-18 RB-2 執行身分、ECI routing 與對抗修復完成增補

RB-2 由 implementation commit `ec25c07` 留證。本批把 catalog approval、實際執行的
`workflow.yml` raw bytes 與 RunState 綁定同一 SHA-256 graph identity；實際 bytes 未符合
approval 時，fresh、resume 與 restart 均 fail-closed；graph 經明確重新核准後，resume
仍拒絕混用舊 state，只有 restart 可封存舊 identity 並開始新 run。ECI routing 現在要求
八種 readiness status 與四種 Authorization Outcome 各自 exactly one，並把
`eci-trigger.md` 與四份 dossier 組成五件 canonical evidence、以明確 framing 計算 digest。
`setup-eci.ps1` 是 ECI agent 與 pipeline 的不可繞過入口，且 project-local
`.workflow/runs/<feature>/eci-requirement.json` requirement marker 使已觸發的 ECI 義務
不能只靠刪除 canonical evidence 或把 readiness 改成 `NOT_REQUIRED` 消失。

本批對抗複核另揭露兩項先前 closure 缺口，均在同一 implementation commit 修復：

1. workflow listing 與 runner 現在共用 manifest existence、object shape、ID/version、
   catalog `sourcePath` 與實體路徑邊界判準；每一層 reparse point 都解析後確認仍在
   workflows root 內，不能以 junction 或 symlink 逃逸。
2. restart archive 使用具碰撞抗性的名稱與 atomic no-overwrite move；固定同一時刻連續
   restart 會保存兩份不同 run identity，既有 archive collision 時拒絕覆寫。

**日期化狀態：**

| ID | 目前狀態 | 本批 closure | 判別性證據 |
|---|---|---|---|
| R-B21 | COMPLETED | approval、執行 snapshot 與 RunState 共用 lowercase SHA-256 graph digest；未核准 bytes 均拒絕，重新核准後 resume 拒絕 hybrid run，restart 封存舊 identity 後才可開始新 run | 舊 implementation overlay 只通過 1/13，新實作相關 cases 納入 353/0 focused suite |
| R-B07 | COMPLETED | ECI trigger、四份 dossier、evidence digest、re-entry 與第二次 readiness assessment 已形成完整 routing | 舊 ECI validator overlay 0/25；現行 validator、setup 與 pipeline cases 全綠 |
| R-B22 | COMPLETED | 八種 readiness status、四種 outcome exactly-one；requirement marker 保存已觸發義務，direct Plan 及 fresh/restart routing 均 fail-closed | 舊 direct Plan overlay 1/13、outcome/re-entry overlay 0/9；現行 cases 納入 353/0 focused suite |
| R-B20 | COMPLETED | 2026-07-18 第 18 節重開的 manifest shared-criterion 缺口已修復；run/list 共用完整 identity、schema、enablement、sourcePath 與實體邊界判準 | 舊 listing 對 manifest version mismatch false-authorized；舊 junction fixture 可把來源逃逸到 root 外；新 run/list 均拒絕 |
| R-B05 | COMPLETED | R-B20 的共用授權判準恢復成立，且 RB-1 strict Boolean、missing-state 與 schema fail-closed 修復未退步 | manifest identity 與 reparse-point negatives 加入 authorization suite；完整 suite 579/0 |
| R-B10 | COMPLETED | 2026-07-18 第 19 節重開的 archive 保留子保證已由 collision-resistant、atomic no-overwrite archive 恢復 | 舊同秒 restart 覆寫第一份 archive；新實作保存兩份不同 run identity，collision 時保留 source 與既有 archive |
| R-B24 | COMPLETED | 秒級名稱與 `Move-Item -Force` 根因已移除；archive collision 不再破壞較早證據 | fixed-time consecutive restart 與 exact-collision negative tests 全綠 |
| R-B23 | OPEN | 本批 requirement marker 與 graph digest 只關閉 isolated evidence deletion 和 reviewed graph identity，不宣稱本機暫態狀態具 authenticity | coordinated marker、readiness、trigger 與 dossier deletion/forgery；RunState/sidecar co-forgery；`completed_steps`、routing 或 gate injection；run-ID/path substitution 仍待單一 authority 設計 |

本節 supersede 第 18 節 R-B20/R-B05 與第 19 節 R-B10/R-B24 的 `IN_PROGRESS`；
歷史降級段落保留為 superseding evidence 的時間線。R-B23 不新增或拆分 ID；本批沒有新增
finding，因此 ledger 總數維持 125 條，嚴重度分布維持 Critical 8、High 29、Medium 50、
Low 38。

**驗收證據：**

| 驗收面 | 結果 |
|---|---|
| RB-2 focused suites | 353 passed / 0 failed |
| 完整 `run-governance-tests.ps1` | 579 passed / 0 failed |
| `check-speckit-runtime.ps1 -Json` | `VALID=true`、0 errors、0 warnings |
| 舊實作 overlay，R-B21 | 1/13 通過 |
| 舊實作 overlay，ECI validator | 0/25 通過 |
| 舊實作 overlay，direct Plan | 1/13 通過 |
| 舊實作 overlay，outcome/re-entry | 0/9 通過 |
| accounting integration gates | `validate-mainline-notes.ps1 -BaseRef origin/main -HeadRef HEAD -RequireReady -Json` 為 `VALID=true`、0 errors、0 warnings；branch-wide `git diff --check` 通過 |

**未吸收殘留：**

- R-B23 維持 `OPEN`，範圍以狀態表所列 coordinated forgery 與 authority injection 為準。
- R-A17、R-A18 維持 `OPEN`，由 RB-3 修復 shared path coverage 與 Ready-note evidence
  authenticity；RB-2 的批次證據不冒充兩項 closure。
- RB-3、RB-4、RB-5 與 R6 仍為必要批次；既有其他 open findings 不因本批被吸收或省略。
- `sdd-pipeline` 在 R6 前維持 experimental 與 execution-denied，不重新 promotion。

RB-2 完成使分支更接近可合併，但 PR #3 仍 `NOT READY TO MERGE`。

## 21. 2026-07-20 RB-3 合併證據完整性完成增補

RB-3 開工前的 immutable batch base 為 `8bf9f0e`。前置複核確認，R-A18 的正確
closure 會使 `origin/main...HEAD` Aggregate gate 因 Wave-3 umbrella note 仍為
`Draft` 且 Related Commits 仍為 `TBD` 而失敗；原批次規則卻要求同一 Aggregate
gate 在每批收尾全綠。依 drift-stop 與 Surface Truthfulness，本節新增 R-A20 保存
該矛盾，不把它吸收到 R-A18，也不以較小 Ready note 製造 Aggregate 假綠。

Owner 於 2026-07-20 選擇 Choice A：

1. `Batch` scope 驗證一個 coherent incremental batch，並綁定 immutable pre-batch
   BaseRef、本批 commit evidence 與 governed non-note shared-path last-touch coverage。
2. `Aggregate` scope 驗證完整分支 merge readiness，並要求 machine-designated
   Wave-3 umbrella note 在 HeadRef 本身為可接受狀態。
3. `-RequireReady` 必須同時具有 `-BaseRef` 與明確 `-ReadinessScope`；顯式
   ChangedPaths、現存歷史 commit 或較小 Ready note 都不能代替 Git range 證據。
4. RB-3 Batch 綠燈與 Aggregate 因 umbrella note 尚未完成而紅燈可以同時成立。

**新增 findings：**

| ID | Severity | Finding | Required closure | 2026-07-20 狀態 |
|---|---|---|---|---|
| R-A20 | High | [2026-07-20 RB-3 preflight] `-RequireReady` 未區分 coherent Batch closure 與 `origin/main...HEAD` Aggregate merge readiness，形成假綠或過早 promotion 誘因 | 提供明確且 fail-closed 的 Batch、Aggregate scope；Batch 綁定 immutable base 與本批 evidence，Aggregate 綁定完整 main diff 與 machine-designated umbrella note；缺 BaseRef 或 scope 必須拒絕 | COMPLETED by `4f757e5` |
| R-A21 | Medium | [2026-07-20 RB-3 adversarial review] `Test-PathPattern` 對 middle `/**/` 宣稱零層或多層目錄，但 `specs/<feature>/readiness/**/*.md` 無法匹配直接位於 `readiness/` 下的 `readiness-assessment.md`。現行 exact readiness route 與本批 suffix `/**` shared roots 使此缺陷不阻塞 RB-3，但 generic matcher 語義不實 | 修正 middle `/**/` 為零層或多層均可匹配；補 direct child、nested child、near-prefix negatives，並複核所有 impact-registry consumers | OPEN |

Implementation commit `4f757e5` 完成日期化 closure：

| ID | 目前狀態 | 本批 closure | 判別性證據 |
|---|---|---|---|
| R-A17 | COMPLETED | `sharedGatePaths` 使用 category-complete roots 覆蓋 `studio/scripts/powershell/**`、`.githooks/**`、`studio/extensions/**`；Git name-status parser 保存 rename old 與 new path；runtime audit 錨定三個必要類別及 canonical Aggregate policy | 舊版單獨變更 add-extension、刪除 setup-eci、漏列 hook 或 nested extension、rename governed source 到 gate 外可通過；現行 branch validator、hook matcher 與 audit mutation tests 均 fail-closed |
| R-A18 | COMPLETED | blocking `-RequireReady` 驗 commit object、merge-base 至 HeadRef membership、contract-bound repository PR、visible exactly-one metadata、visible required sections、governed non-note shared-path last-touch coverage，以及所有 configured Aggregate anchors | 舊版接受 deadbee、blob、range 外 commit、錯 repo PR、mutable wrong origin、無 BaseRef、hidden 或 duplicate metadata、comment/fence/indented-code/raw-HTML sections、unrelated commit 與小 note Aggregate bypass；現行逐項拒絕 |
| R-A20 | COMPLETED | `-RequireReady` 使用明確 Batch 或 Aggregate scope 且必須有 BaseRef；CI 使用 Aggregate，本批 accounting 使用 Batch；所有 configured anchors 即使未變更也在 HeadRef 受驗 | 舊版無法同時表達 truthful Batch green 與 Aggregate red；現行 Batch 可獨立閉合，Aggregate 只回報 canonical Draft umbrella blocker |

非阻塞 global validation 在沒有 Git 的 isolated audit fixtures 中仍刻意保留 shape-only
commit fallback；該路徑沒有 `-RequireReady`，不能授權 Batch 或 Aggregate。R-A18 的
closure 宣稱只涵蓋 blocking acceptance，不把 nonblocking structural scan 冒充 Git
證據驗證。

**驗收證據：**

| 驗收面 | 結果 |
|---|---|
| RB-3 focused suites | 134 passed / 0 failed |
| 舊實作 overlay | 34 個 discriminating negatives 為 0/34 passed；5 個 positive/regression controls 為 5/5 passed；無參數綁定或 fixture setup 遮蔽 |
| 完整 `run-governance-tests.ps1` | 616 passed / 0 failed |
| `check-speckit-runtime.ps1 -Json` | `VALID=true`、0 errors、0 warnings |
| Batch mainline gate | BaseRef `8bf9f0e`、`ReadinessScope Batch`，`VALID=true`、0 errors、0 warnings |
| Aggregate mainline gate | BaseRef `origin/main`、`ReadinessScope Aggregate`，nonzero；唯一 error 為 `docs/mainline-updates/2026-05-05-studio-workflows-runtime.md` 的 `aggregate-note-not-ready` |
| branch diff hygiene | `git diff --check` 通過 |

本節使 ledger 由 125 增至 127 條，分布為 Critical 8、High 30、Medium 51、Low 38。
R-A17、R-A18、R-A20 為 `COMPLETED`；R-A21 為 `OPEN`，不由本批吸收。R-B23 與
其他既有 findings 狀態不變。`sdd-pipeline` 維持 experimental、default-disabled 與
execution-denied；RB-4、RB-5、R6 仍未完成。RB-3 使分支更接近可合併，但 PR #3
仍 `NOT READY TO MERGE`，本批 accounting 後停止。

## 22. 2026-07-20 RB-4 extension、consumer、upgrade 邊界完成增補

RB-4 開工前的 immutable batch base 為 `02f12cb`。Preflight 發現原 remediation
mapping 沒有列 R-C03，但批次驗收明定 schema violation 必須被拒絕；在三份
extension schema 仍無 `Test-Json` 執行點時，該閘門不可能成立。依 drift-stop 規則先
停下，owner 於 2026-07-20 明確核准把 R-C03 納入 RB-4 必要相依。這項裁定只擴充
schema gate 所需 finding，不吸收 R-C04、R-C06 或其他 extension backlog。

Implementation commit `9819e30` 完成以下日期化狀態：

| ID | 2026-07-20 狀態 | 本批 closure | 判別性證據 |
|---|---|---|---|
| R-C01 | COMPLETED | `-OutputDir` 必須位於 workspace 實體邊界內且不得與 extension、agent、prompt、script 或 template authority 重疊；既有 output 含 reparse point 時拒絕，輸出先 staging 再 promotion | 舊版可對 workspace 外目錄使用 `-Force`；現行 outside、alias overlap 與 output reparse negatives 均拒絕且不碰 sentinel |
| R-C02 | COMPLETED | add、replace、state 與 remove 在 mutation 前驗 schema 與 prospective state；catalog、state、target 與 mirror 使用 transaction baseline，rollback 子步失敗時保留 recovery evidence | 舊版 post-validation failure 會留下 mutation；現行 second-write、state-write、target 與 mirror failure fixtures 驗完整回復或明確保留證據 |
| R-C03 | COMPLETED | catalog、state、manifest 三份 JSON 都以 canonical schema 執行 `Test-Json`，並保留必要 cross-ledger 檢查 | 舊版接受 schema 不允許的 enum 或 shape；現行 schema substitution、wrong shape 與三 schema enforcement tests fail-closed |
| R-C05 | COMPLETED | intake、registry、entry point 與 export 均驗 lexical 及 physical containment；extension tree 拒絕 reparse point；replacement 一律清除 approval、trust、default enablement 與 explicit state | 舊版 junction escape 與 approval carry-forward 可通過；現行 extension-root junction、content reparse、byte replacement 與 force-replacement tests 均拒絕或降級 |
| R-C07 | COMPLETED | 隔離 fixture 自動演練 add、approve、enable、export、disable、re-enable、再次 export 與 remove，並驗 generated mirror lifecycle | 舊版沒有該生命週期驗收；現行完整 lifecycle 與 collision/cleanup controls 全綠 |
| R-C08 | COMPLETED | entry point normalized path 必須留在 declared scope；approval 綁 current bytes；多檔 mutation 可回復；state 或 registry mutation 使 merged mirror 失效；recovery journal、baseline 與 restore 均 hash-bound 且原子發布 | Exact `02f12cb` extension overlay 只有 1 個 positive control 通過，20 個 discriminating negatives 全失敗；現行 21/21 |
| R-A19 | COMPLETED | 啟用 `extensions.worktreeConfig` 並以 `git config --worktree` 保存 depth-specific hooks；project template 以 rooted ignore 保留 junction 可用性但排除 shared bytes 的 Git intake | 舊版三項判別 assertion 對 source/sibling hooks mutation、junction status 或 staging、缺 rooted ignores 全失敗；現行 common/init/feature suites 114/114 |
| R-F06 | COMPLETED | 在任何 audit 前保存完整 canonical baseline；以 transaction 開始前凍結且 hash-manifested 的 trusted checker、dependency closure 與 schemas 驗 staged 與 promoted runtime；candidate checker、version、skills 與 extension export scripts 不執行；promotion、journal 與 rollback 使用 hash 驗證及 atomic replacement | Exact `02f12cb` upgrade overlay 0/17；現行 17/17，多輪 reviewer rerun 全綠。Corrupted backup 在 canonical overwrite 前由 baseline hash 拒絕，target 不會被壞 evidence 覆寫，rollback-failed journal 保留 |

Extension catalog 同步執行 Surface Truthfulness 修正。既有 `extension-smoke` 的 approval
日期早於現行 bytes 的 Git 變更，沒有證據能把舊核准延伸到新內容；因此 catalog
1.2.0 將它降回 `draft`、`experimental`、default-disabled，並清除 approval fields。
這是 R-C05/R-C08 的必要 migration，不是重新核准。

對抗複核在 freeze 前先後發現 extension rollback evidence 可能被 cleanup 刪除、
baseline restore 直接覆寫 canonical、upgrade 可能執行 candidate verifier、trusted
authority 與 baseline sibling 可被改寫、journal 非原子，以及 corrupted upgrade
backup 可能在驗 hash 前覆寫 canonical。所有反例都在 implementation commit 前修復，
並加入舊版失敗、現行通過的 behavioral tests 與 shared contract anchors；因此沒有把
中途部分處置冒充 closure，也沒有留下需要新增 ledger ID 的未處理子項。

**驗收證據：**

| 驗收面 | 結果 |
|---|---|
| Extension lifecycle | 現行 21 passed / 0 failed；exact `02f12cb` 為 1/21，唯一通過是 positive compatibility control |
| Worktree 與 consumer | 現行 common/init/feature suites 114 passed / 0 failed；舊版三個 discriminating assertions 為 0/3 |
| Upgrade transaction | 現行 17 passed / 0 failed；deterministic corrupted-baseline targeted 連續 5/5；exact `02f12cb` 為 0/17 |
| Production-map isolated Apply | exit 0、zero changes、trusted staging 與 canonical audits 均為 Boolean `true`、Int64 0 errors / 0 warnings |
| Contract mutation 與 path hardening | `check-speckit-runtime.Tests.ps1` 31/31；`path-traversal-hardening.Tests.ps1` 14/14 |
| 完整 `run-governance-tests.ps1` | 664 passed / 0 failed |
| `check-speckit-runtime.ps1 -Json` | `VALID=true`、0 errors、0 warnings |
| Batch mainline gate | BaseRef `02f12cb`、`ReadinessScope Batch`，`VALID=true`、0 errors、0 warnings |
| Aggregate mainline gate | BaseRef `origin/main`、`ReadinessScope Aggregate`，nonzero；唯一 error 為 canonical Wave-3 umbrella note 的 `aggregate-note-not-ready` |
| branch diff hygiene | `git diff --check` 通過 |

**未吸收殘留：**

- R-C04 維持 `OPEN`：`compatibility.minStudioConstitutionVersion` 仍需真正 enforcement
  或移除不實 surface。
- R-C06 維持 `OPEN`：deprecated 新啟用與 dead `sync` state source 尚未收斂。
- R-F04 維持 `OPEN`：upgrade transaction 已移除 skills 與 extension export caller，
  但 scripts、audit、contract、docs、tests 與輸出目錄的整條退役尚未完成；本批只記錄
  partial alignment，不宣稱 closure。
- R-A21、R-B23 與其他既有 findings 狀態不變；沒有被 RB-4 吸收。
- `sdd-pipeline` 在 R6 前維持 experimental、default-disabled 與 execution-denied。

本節不新增 finding，ledger 維持 127 條，分布維持 Critical 8、High 30、Medium 51、
Low 38。RB-4 使分支更接近可合併，但 RB-5 與 R6 仍未完成；Wave-3 umbrella note
維持 `Draft`，PR #3 仍 `NOT READY TO MERGE`。

## 23. 2026-07-20 RB-5 agent、authority、process 真實性完成增補

RB-5 的 immutable batch base 為
`de61431ae8f50d66f59157e00e4d239e9b37efdb`。Implementation commit
`78c47eb0f3da7e75f3ba79943ea44f55984677a1` 修復 agent source、Claude mirror
authority 與 workspace governance self-application 邊界；migration commit
`26da9a7412d902f2dfff48df23d04662687f4a9d` 完成一次性的歷史 note 證據遷移。

RB-5 preflight 發現，R-E09 的 18 份歷史 notes 都有真實但位於目前 Batch range 外的
introducing commits。直接回填會與 R-A18 的 current in-range evidence 規則衝突；
沿用或刷新 legacy hash baseline 又會重新建立可變的例外。Owner 於 2026-07-20 核准
新增 High R-A22，範圍只限建立一次性、Git-bound、不能授權 current Batch 或 Aggregate
的歷史證據遷移，不吸收 R-E09 的 Wave-3 umbrella note 與 R6 義務。

**新增 finding：**

| ID | Severity | Finding | Required closure | 2026-07-20 狀態 |
|---|---|---|---|---|
| R-A22 | High | [2026-07-20 RB-5 preflight] 18 份歷史 `Ready`、`TBD` notes 的真實 commits 位於 current Batch range 外；直接回填會被 R-A18 正確拒絕，而可刷新 legacy hash baseline 不能作為可信的永久例外 | 以固定 batch base、schema、first-add framework commit、first sealed snapshot、record digest、exact note bytes、exact historical commits 與 legacy baseline removal 建立一次性 migration；歷史 refs 不得進入 current evidence、path coverage、`must_update` 或 Aggregate authorization | COMPLETED by `78c47eb0f3da7e75f3ba79943ea44f55984677a1` and `26da9a7412d902f2dfff48df23d04662687f4a9d` |

**日期化狀態：**

| ID | 目前狀態 | 本批 closure | 判別性證據 |
|---|---|---|---|
| R-D01 | COMPLETED | Specify 保存所有 material clarification markers，不再超過三項就臆測；唯一 next-stage handoff 為 Clarify，source 與 generated mirror 同步 | Exact pre-batch overlay 對 10 個 source/mirror truthfulness assertions 為 0/10；現行 source、mirror 與 contract anchors 鎖定無 marker cap、無猜測、無 direct Readiness |
| R-D04 | COMPLETED | `seed-claude-agents.ps1 -Verify` 以 normalized deterministic rendering 驗完整 frontmatter 與 body；canonical audit 拒絕 blank、body/frontmatter drift、missing、extra 與 nested mirror | 舊 audit 對 blank/body tampering 兩項都未攔截；現行 verifier 與 audit 逐項 fail-closed，child `VALID`、`ERROR_COUNT`、`ERRORS` 也要求原生 Boolean、Int64 與 array shape |
| R-D05 | COMPLETED | 未知 Copilot tool、非法 explicit Claude tool、permission broadening 與 malformed list 全部在任何 mirror write 前 fail-loud；明示 `tools: []` 保持空權限 | 舊 conversion 對未知 tool 回空陣列並省略 `tools`；現行 unknown、numeric/malformed list、empty-source grant 與 broadened mapping negatives 均拒絕 |
| R-E07 | COMPLETED | Studio Constitution 1.9.0 第 2.1 節以 contract repository identity、shared-only scope、實作前 owner plan/ledger 與實作後 closure evidence 界定 canonical workspace self-application；明確排除 consumer、一般 feature、Aggregate、promotion 與 R6 fresh fixture | Pre-batch constitution 沒有此 bounded route；現行 24 個 constitution contract cases、同步 root adapters、templates 與 explanatory docs 鎖定 entry/closure 分離及不得擴權 |
| R-A22 | COMPLETED | A commit 建立固定 `de61431ae8f50d66f59157e00e4d239e9b37efdb` pending framework；M commit 封存 18 records、綁定 A commit 與 evidence SHA-256、刪除 legacy baseline，並保存 immutable first-add/first-seal history | Historical focused suite 37 passed / 0 failed；shifted base、schema spoof、delete/re-add、pending reset、reseal、dirty authority、note rewrite、mixed refs、no-Git blocking authorization 與 historical current-coverage bypass 均被拒絕 |
| R-E09 | IN_PROGRESS | 18 份歷史 notes 的 exact commit recovery 與 truth review 已完成：17 份為 `Merged`、`Closed`，`2026-04-10-shared-layer-consistency-fix.md` 因不實 parity、`-Fix` 與 complete-MUST claims 保持 `Draft`、`Open` | Historical records 18/18 與 note bytes、status、commit anchors 一致；但 Wave-3 umbrella note 仍須在 R6 以 fresh-fixture、Aggregate、promotion decision、merge 與 post-merge evidence 收尾，因此不得把歷史子項冒充整項 closure |

RB-5 implementation acceptance 的完整 governance suite 為 737 passed、0 failed、
0 skipped（1029.06 秒）；runtime audit 為 `VALID=true`、0 errors、0 warnings。這兩項是
本批 implementation acceptance 證據；本次 accounting edits 完成後仍須在批次收尾重跑
完整 suite、runtime audit、Batch 與 Aggregate gates，本節不預先宣稱該次最終結果。

R-A22 的 sealed policy 使用 record digest
`1cbb98f6edea8e096501112fac7196f84524ffdd9e6b69e63dc5b859d29d7a5e`，
`migrationCommit` 指向 A commit，18 records 中 17 個 expected status 為 `Merged`、一個
為 `Draft`，legacy baseline 已移除。歷史 refs 明確排除 current Batch、Aggregate、
shared-path coverage 與 `must_update` evidence；notes 後續再變更時必須離開 historical
special mode，改用正常 in-range evidence。

**未吸收殘留：**

- R-E09 維持 `IN_PROGRESS`。已完成部分只有 18 份歷史 notes；Wave-3 umbrella note 的
  最終 status、commit accounting、known issues、fresh-fixture 與 merge evidence 留給 R6。
- README 的 ECI Authorization Outcome 數量由三修正為四只是既有真相同步，不關閉
  R-E01。
- R-A13、R-A21、R-B23、R-C04、R-C06、R-E02、R-E03、R-E04、R-E06、R-E08、
  R-E12、R-F04、R-I02 與其他既有 open findings 狀態不變，沒有被 R-E07 或 R-A22
  吸收。
- `sdd-pipeline` 在 R6 前維持 experimental、default-disabled 與 execution-denied。

本節新增一個 High finding，ledger 由 127 增至 128 條，分布由 Critical 8、High 30、
Medium 51、Low 38 更新為 Critical 8、High 31、Medium 51、Low 38。RB-5 批次完成使
分支更接近可合併，但不使分支 merge-ready。Wave-3 remediation sequence 的下一批為
R6；整體 open-findings ledger 的其他 backlog 仍各自保留。PR #3 仍
`NOT READY TO MERGE`。

## 24. 2026-07-20 RB-5 post-accounting 誠實性還原增補

本節依 note 狀態機與 append-only ledger 規則，取代第 23 節中 RB-5 已完成及 R-A22
`COMPLETED` 的宣稱，不改寫第 23 節的歷史證據。Accounting commit
`64669c43d531d9dd699d60e163e7b1c755d64963` 是本次 revalidation 的 committed head；
implementation commit `78c47eb0f3da7e75f3ba79943ea44f55984677a1` 與 migration commit
`26da9a7412d902f2dfff48df23d04662687f4a9d` 仍保留為已落地變更證據。

Post-accounting 機器結果如下：

| 驗收面 | 結果 |
|---|---|
| Full governance suite | 737 passed / 0 failed / 0 skipped |
| Runtime audit | `VALID=false`；一個 `historical-evidence-sealed-snapshot-mismatch` |
| Batch gate | 22 errors；同一 sealed-snapshot blocker、17 個衍生 historical out-of-range errors、四個 `must-update-reconciliation-open` |
| Aggregate gate | 19 errors |

目前診斷根因是 `Read-ExactLegacyBaselineAtCommit` 拒絕 production legacy baseline metadata
shape，因此 `HISTORICAL_EVIDENCE_VALID=0`。這個反例推翻 R-A22 的 sealed historical
evidence closure，也使 RB-5 note 必須由 `Ready`、`Closed` 降為 `Draft`、`Open`。RB-5
note 中 `.claude/agents/*.md`、`AGENTS.md`、`CLAUDE.md` 與
`.github/copilot-instructions.md` 的 impact 已依 route 從 `must_review` 修正為
`must_update`，Disposition 保持 `pending`，直到 repaired final Batch gate 成功。

**日期化狀態：**

| ID | 2026-07-20 post-accounting 狀態 | 本次 superseding disposition |
|---|---|---|
| R-D01 | COMPLETED | Specify truthfulness closure 未被 sealed historical evidence 反例推翻 |
| R-D04 | COMPLETED | Claude mirror deterministic parity closure 未被 sealed historical evidence 反例推翻 |
| R-D05 | COMPLETED | Least-privilege tool mapping closure 未被 sealed historical evidence 反例推翻 |
| R-E07 | COMPLETED | Constitution 1.9.0 self-application boundary 未被 sealed historical evidence 反例推翻 |
| R-A22 | IN_PROGRESS | Production legacy baseline metadata shape 無法由 current reader 重建，sealed snapshot 尚非有效 canonical evidence |
| R-E09 | IN_PROGRESS | 歷史 note 子項受 R-A22 blocker 影響，Wave-3 Aggregate、merge accounting 與 R6 義務也仍未完成 |

R-A22 的重新進入條件是：以 production metadata shape 建立會在舊 reader 失敗、修復後
通過的判別性測試；修復 exact legacy baseline reconstruction；runtime audit 回到 0 errors、
0 warnings；完整 suite 不低於 737 且 0 failed；Batch gate 全綠。Aggregate 在 R6 前仍應
因 umbrella note 為 `Draft` 而 fail-closed，但不得再包含 R-A22 或 RB-5 reconciliation
錯誤。

本節不新增 finding，也不重開未被反例推翻的 R-D01、R-D04、R-D05 或 R-E07。ledger
總數維持 128，嚴重度維持 Critical 8、High 31、Medium 51、Low 38。R-A22 與 R-E09
均為 `IN_PROGRESS`，RB-5 修復是下一步；R6 不是目前下一個可執行批次。PR #3 維持
`NOT READY TO MERGE`，`sdd-pipeline` 維持 experimental、default-disabled 與
execution-denied。

## 25. 2026-07-20 RB-5 sealed baseline repair closure 增補

本節 supersede 第 24 節的 R-A22 `IN_PROGRESS` 與「R6 尚非下一批」結論，並保留該節
作為 post-accounting 反例的歷史記錄。Repair commit
`3666c4e9a6553ff82774d4a06037f48846d8b0fd` 修復
`Read-ExactLegacyBaselineAtCommit`：immutable framework parent 現在必須精確包含
`schemaVersion`、`purpose`、`created`、`removalBatch` 與 `entries` 五個 production
metadata fields，並保留既有 path、blob hash、first-add 與 first-seal checks。

Committed repair evidence 如下：

| 驗收面 | 已觀察結果 |
|---|---|
| Runtime audit | `VALID=true`、0 errors、0 warnings |
| Historical sealed evidence | 18/18 valid |
| Dedicated mainline-note validator file | 91 passed / 0 failed |
| Discriminating metadata matrix | Production positive 通過；`TwoField`、`ExtraField`、`SubstitutedField`、`WrongType`、`Null` 全部拒絕 |
| Revert anchor | Shared runtime contract 拒絕舊 `Count=2` shortcut |

Repair 後的 diagnostic Batch 已顯示 historical evidence 18/18，且沒有
`historical-evidence-sealed-snapshot-mismatch`。該次 33 errors 全部源於 RB-5 note
仍為 `Draft`，以及由此產生的 coverage、not-ready 與 reconciliation-missing errors；
它不是 final Batch 結果。完整 governance suite、final Batch 與 Aggregate 必須在本次
accounting edits 完成後重跑，本節不預先宣稱其結果。

**日期化狀態：**

| ID | 2026-07-20 repair closure 狀態 | Superseding disposition |
|---|---|---|
| R-D01 | COMPLETED | 狀態不變；Specify truthfulness closure 未被本次修復改動 |
| R-D04 | COMPLETED | 狀態不變；Claude mirror parity closure 未被本次修復改動 |
| R-D05 | COMPLETED | 狀態不變；least-privilege tool mapping closure 未被本次修復改動 |
| R-E07 | COMPLETED | 狀態不變；Constitution 1.9.0 self-application boundary 未被本次修復改動 |
| R-A22 | COMPLETED | Exact production baseline reconstruction、18/18 committed audit 與判別 matrix 完成 closure |
| R-E09 | IN_PROGRESS | 18-note historical portion 已完成；Wave-3 umbrella、R6、merge accounting 與 post-merge evidence 仍未完成 |

本節不新增 finding，不吸收 R-A13、R-A21、R-B23、R-C04、R-C06、R-E01、R-E02、
R-E03、R-E04、R-E06、R-E08、R-E12、R-F04、R-I02 或其他 open IDs。ledger
總數維持 128，嚴重度維持 Critical 8、High 31、Medium 51、Low 38。RB-5 已完成，
R6 是下一個 remediation batch；但本次 accounting 後的 full suite、runtime audit、
Batch、Aggregate 與 diff hygiene 仍須依實際結果收尾。PR #3 仍
`NOT READY TO MERGE`，`sdd-pipeline` 維持 experimental、default-disabled 與
execution-denied。

## 26. 2026-07-20 RB-5 final accounting gates 與 R6 preflight 增補

本節 supersede 第 25 節中 final accounting gates 尚待重跑的句子，並保留第 25 節作為
repair closure 在 accounting 前的歷史記錄。Accounting commit
`44f768a12316cdb008f1fee263e03ed7ce9a8191` 的 RB-5 final gates 已觀察到以下結果：

| 驗收面 | Final result |
|---|---|
| Full governance suite | 742 passed / 0 failed / 0 skipped / 0 not run，1115.2 秒 |
| Runtime audit | `VALID=true`、0 errors、0 warnings |
| Historical sealed evidence | 18/18 valid |
| Batch gate | Base `de61431ae8f50d66f59157e00e4d239e9b37efdb`；`VALID=true`、0 errors、0 warnings |
| Aggregate gate | Exactly one expected error：canonical umbrella note 的 `aggregate-note-not-ready` |
| Diff and worktree hygiene | `git diff --check` 通過；committed head worktree clean |

這些結果完成 RB-5 final accounting acceptance。R-A22 維持 `COMPLETED`；R-E09 維持
`IN_PROGRESS`，因 canonical umbrella note、R6 evidence、final merge accounting 與
post-merge verification 仍未完成。Aggregate 的單一 expected error 是 R6 前的正確
fail-closed 結果，不是 merge authorization。

### R6 Preflight Owner Decisions

以下事項尚未獲 owner 裁定，agent 不得自行關閉 finding、接受 residual risk、promotion
workflow 或授權 merge：

| Decision area | 未裁定事項 | R6 前限制 |
|---|---|---|
| Residual merge dispositions | R-A21、R-B23、R-C04、R-C06、R-F04 與其他仍 open ledger IDs 應在 R6 修復、明確 defer，或採取何種 owner-approved disposition | 未有逐項 owner 決定與帳務前，不得把 residuals 視為已關閉或已接受 |
| R-E11 | Ledger 已存在不自動完成 R-E11；仍需 R6 明確 disposition | 不標示 `COMPLETED`，不以 RB-5 gate 綠燈吸收 |
| Workflow promotion | `sdd-pipeline` 應 promotion 或維持 non-promotion | Owner 決定與 fresh-fixture evidence 前維持 experimental、default-disabled、execution-denied |
| Merge and post-merge accounting | Merge authorization、final PR/commit/merge references、mainline note closure與 post-merge validation 記錄 | 決定與證據完成前不得 merge，也不得預填 post-merge closure |

本節不新增 finding，不改變任何未列為 RB-5 closure 的狀態。Ledger 維持 128 條，
嚴重度維持 Critical 8、High 31、Medium 51、Low 38。RB-5 已完成，R6 是下一個
remediation batch；但在上述 owner decisions 與 R6 evidence 完成前，PR #3 維持
`NOT READY TO MERGE`，不得 promotion 或 merge。

## 27. 2026-07-21 R6 fresh-fixture evidence 子批增補

本節只記錄 R6 的可重播 fresh-fixture evidence 子批，不 supersede 第 26 節的 owner
decision blockers，也不把「證據已可重播」冒充成 R6、Aggregate、promotion、merge 或
post-merge closure。Implementation commit
`aef41b1bac2e56bf717d9ded5328c3c601fd7037` 新增隔離的
`studio/tests/r6-fresh-fixture-e2e.Tests.ps1`，fixture 使用 canonical
`sdd-pipeline` version 1.1.0 的 exact workflow 與 manifest bytes，但只在 `$TestDrive`
registry 設定 approved、curated 與 enabled。Canonical catalog、state 與 workflow
沒有 promotion 或 mutation。

### 已觀察的 evidence

| 驗收面 | 已觀察結果 |
|---|---|
| Fresh-fixture E2E | 1 passed / 0 failed / 0 skipped，80.25 秒 |
| Canonical registry | Canonical runner denied；catalog 仍 experimental、default-disabled，state 無 enabled entry |
| DryRun | 只建立 `state.dryrun.json`；不存在可供真實 `-Resume` 使用的 `state.json` |
| Workflow identity | Halt 後變更 fixture workflow bytes 會因 approval digest mismatch 被拒絕；恢復 exact bytes 才可續跑 |
| Non-ready recovery | `NOT_READY` gate 可 Reject 為 exit 44；rejected run 不可 Resume，必須 Restart |
| ECI | `ROUTE_TO_ECI` 建立 requirement latch；五檔 framed digest 完成後以 `READY_FOR_MAINLINE_IMPLEMENTATION` re-enter Readiness |
| Analyze | Schema-valid `OPEN` Critical 使 Implement fail-closed；修復後且 artifact hashes 一致才可續跑 |
| Terminal completion | Baseline `T001`、`T002` 保存於 RunState 與 sidecar；只完成 `T001` 仍 halted，兩項全完成才 terminal success |
| Restart evidence | 兩次 restart 保留兩份不同 run ID archive，新 live run ID 不重用舊 identity |
| Contract revert negative | 移除 `R6_FRESH_FIXTURE_TERMINAL_SUCCESS` 使 audit failure ID 為 `r6-fresh-fixture-e2e` |
| Committed runtime audit | Implementation head 為 `VALID=true`、0 errors、0 warnings；historical sealed evidence 18/18 |

九個 contract-bound evidence markers 為：

1. `R6_FRESH_FIXTURE_CANONICAL_REGISTRY_DENIED`
2. `R6_FRESH_FIXTURE_DRYRUN_ISOLATED`
3. `R6_FRESH_FIXTURE_WORKFLOW_MUTATION_DENIED`
4. `R6_FRESH_FIXTURE_NON_READY_REJECTED`
5. `R6_FRESH_FIXTURE_RESTART_ARCHIVED`
6. `R6_FRESH_FIXTURE_ECI_REENTRY_COMPLETE`
7. `R6_FRESH_FIXTURE_ANALYZE_CRITICAL_BLOCKED`
8. `R6_FRESH_FIXTURE_PARTIAL_IMPLEMENT_BLOCKED`
9. `R6_FRESH_FIXTURE_TERMINAL_SUCCESS`

### 日期化狀態與未完成邊界

| ID 或範圍 | 2026-07-21 狀態 | 本子批 disposition |
|---|---|---|
| R6 fresh-fixture evidence 子批 | COMPLETED | 可重播 E2E、revert anchor、744/0/0/0 full suite 與 committed runtime audit 已落地；Ready/Closed 只涵蓋此證據子批 |
| R6 overall | IN_PROGRESS | Residual dispositions、R-E11、promotion、Aggregate、merge 與 post-merge evidence 尚未完成 |
| R-E09 | IN_PROGRESS | Fresh-fixture evidence 子項已新增；umbrella、promotion decision、merge accounting 與 post-merge evidence 仍未完成 |
| R-E11 | OPEN | Ledger 已存在不等於 finding 自動完成；仍需 owner 明確 disposition |
| R-J03 | OPEN | 本子批不 merge `main`，因此 mainline convergence 終點未完成 |
| R-D03 | OPEN | Implement agent 的 `[P]` 語義 drift 仍存在，未被本 E2E 吸收 |
| 其他 residuals | 狀態不變 | R-A21、R-B23、R-C04、R-C06、R-F04 與其他 open IDs 未修復、未接受、未 defer |
| Workflow promotion | 未裁定 | Canonical `sdd-pipeline` 維持 experimental、default-disabled 與 execution-denied |
| Merge | 未授權 | PR #3 維持 `NOT READY TO MERGE`；不 push、不 merge、不填 post-merge success |

Owner 於 2026-07-21 只授權把 `docs/README.md` 中仍寫
`v1.10.0`、125 條與 RB-2 狀態的 ledger 索引漂移，更新為本版 v1.17.0、128 條與
R6 evidence 子批現況。這項授權不是 residual acceptance、promotion 或 merge 決定。

本節不新增 finding，ledger 總數維持 128，嚴重度維持 Critical 8、High 31、
Medium 51、Low 38。Full governance suite 已在 accounting worktree 以
744 passed、0 failed、0 skipped、0 not run 完成；implementation head 的 runtime audit
為 `VALID=true`、0 errors、0 warnings，historical sealed evidence 18/18。日期化 R6
evidence note 只對此 bounded 子批標為 `Ready`、`Closed`；staged snapshot 與 committed
accounting head 的 Batch、Aggregate 及 final diff/worktree hygiene 仍須實測，任何反證
都必須依狀態機重新開啟本子批。

## 28. 2026-07-21 R6 evidence post-accounting 驗證增補

本節保留第 27 節的 pre-commit 時間線，並以 accounting commit
`28fbc8280000124e15c9c4913f6c130af1df78bb` 的實際 committed-head 結果取代其中
尚待驗證的閘門敘述：

| 驗收面 | Committed-head 結果 |
|---|---|
| Canonical runtime audit | `VALID=true`、0 errors、0 warnings |
| Historical sealed evidence | 18 of 18 records valid |
| Batch mainline gate | BaseRef `f8e3fe0bd9d62b7f8e0110bc2a13e73548311c3f`；`VALID=true`、0 errors、0 warnings；8 changed paths |
| Aggregate mainline gate | 預期 exit 1；唯一 error 為 `docs/mainline-updates/2026-05-05-studio-workflows-runtime.md` 的 `aggregate-note-not-ready` |
| Diff 與 worktree hygiene | `git diff --check` passed；worktree clean |

上述結果維持 R6 fresh-fixture evidence 子批為 `COMPLETED`，日期化 note 為
`Ready`、`Closed`、`Batch`。Aggregate 的單一 error 是正確的 fail-closed merge
blocker，不是本子批失敗，也不得改寫成 branch green。

R6 overall、R-E09、R-E11、R-J03、R-D03、R-A21、R-B23、R-C04、R-C06、R-F04
及其他 residual dispositions 全部維持原狀。Canonical `sdd-pipeline` 仍為
experimental、default-disabled、execution-denied；PR #3 仍 `NOT READY TO MERGE`。
本節不新增 finding，ledger 維持 128 條與 Critical 8、High 31、Medium 51、Low 38。

## 29. 2026-07-21 R6 umbrella evidence drift reconciliation 增補

Owner 授權本次只做 accounting drift reconciliation。唯讀 preflight 發現 canonical
Wave-3 umbrella note 的 current-status 文字仍寫 fresh-fixture evidence 尚待執行，與
implementation commit `aef41b1bac2e56bf717d9ded5328c3c601fd7037`、accounting commit
`28fbc8280000124e15c9c4913f6c130af1df78bb` 及最終已測 head
`f2df26e98300c034f7fa03c7831b8f00aa6c470a` 的證據矛盾。

本節與 umbrella note 的 2026-07-21 reconciliation 只 supersede「fresh-fixture 尚待
執行」這項 stale statement，不改寫先前歷史：

| 驗收面 | `f2df26e98300c034f7fa03c7831b8f00aa6c470a` 已觀察結果 |
|---|---|
| Full governance suite | 744 passed、0 failed、0 skipped、0 not run，1251.1 秒 |
| Canonical runtime audit | `VALID=true`、0 errors、0 warnings |
| Historical sealed evidence | 18 of 18 records valid |
| R6 evidence Batch gate | BaseRef `f8e3fe0bd9d62b7f8e0110bc2a13e73548311c3f`；`VALID=true`、0 errors、0 warnings；8 changed paths |
| Aggregate gate | 預期 exit 1；唯一 error 為 canonical umbrella note 的 `aggregate-note-not-ready` |
| Diff 與 worktree hygiene | `git diff --check` passed；worktree clean |

本版 metadata 的 `head_commit` 指向上述已完整驗證的 evidence head，不預先宣稱承載本節的
accounting commit hash。R6 fresh-fixture evidence 子批維持 `COMPLETED`，但 R6 overall
與 R-E09 維持 `IN_PROGRESS`；R-E11、R-J03、R-D03、R-A21、R-B23、R-C04、R-C06、
R-F04 及其他 residual 狀態全部不變。R-F04 先前的退役方向不等於本批已執行或已完成
merge disposition。

Canonical umbrella note 維持 `Draft`、`Related Commits: TBD`、reconciliation `Open`、
validation scope `Aggregate`。Workflow promotion 仍未裁定；`sdd-pipeline` 維持
experimental、default-disabled、execution-denied。本批不新增 finding、不 promotion、
不 push、不 merge，也不記錄 post-merge success；PR #3 維持 `NOT READY TO MERGE`。

## 30. 2026-07-21 R-D03 self-application entry truth restoration 與 clean re-entry authorization 增補

Implementation attempt `8101f9a380eb27c5004bece9aad77d42b2cc8a51` 在技術面完成
20/20 focused parity、1/0 coordinated mutation、747/0/0/0 full suite 與 runtime
`VALID=true`、0 errors、0 warnings，但其 parent commit 尚無 committed、日期化且
owner-authorized 的 R-D03-only remediation plan。Constitution Section 2.1 把這項要求
定義為 implementation 前的 entry prerequisite，不能由 post-implementation accounting
回填。因此上述證據不具 R-D03 closure 資格。

本節保留第 29 節的歷史，並 supersede 任何把 `8101f9a` 當成 closing implementation
的敘述。本 truth-restoration batch 將 canonical source、Claude mirror、兩個 R-D03
contract invariants 與三個新增 tests 恢復到 pre-R-D03 語義基線；為通過 diff hygiene，
兩份 agent 的既有行尾空白同時正規化，不改變舊語義。

Owner 在 entry defect 被回報後，於 2026-07-21 明確授權 clean re-entry。授權範圍只含
R-D03 剩餘的 task priority 與 parallelism 語義；R-D02 已完成的 mandatory Implement
first-action gate 不重複計算。R-G03 的 CLI、template 與 upstream docs 版本事實另案
reconcile，其他 residual、`projects/`、`learning/`、promotion、Aggregate、merge、
post-merge、push 與 PR thread resolution 全部排除。

| ID 或範圍 | 2026-07-21 truth-restoration 狀態 | Disposition |
|---|---|---|
| Attempt `8101f9a` | NOT ACCEPTED FOR CLOSURE | 技術證據保留於 Git history，但缺失 pre-implementation plan |
| R-D03 | OPEN | 恢復 pre-R-D03 語義；只能由本 plan commit 之後的新 implementation 與完整 gates 關閉 |
| R-D02 | COMPLETED，狀態不變 | Mandatory first-action gate 不由本批重複計算 |
| R-G03 | OPEN，狀態不變 | 不裁定版本事實、不修改 obstacle review、不接受或 defer |
| R6 overall / R-E09 | IN_PROGRESS，狀態不變 | Residuals、R-E11、promotion、Aggregate、merge 與 post-merge evidence 仍未完成 |
| 其他 residuals | 狀態不變 | 未修復、未接受、未 defer |

Clean re-entry 只有在本節與 remediation plan Section 18 已 committed，且五個
implementation surfaces 已回復基線後才可開始。新 implementation 必須重新產生
old-fails/new-passes evidence、contract revert anchors、Claude deterministic parity、
runtime 0/0、完整 suite、Batch、Aggregate expected blocker 與 diff/worktree hygiene。
任何失敗都維持 note `Draft`、reconciliation `Open`、R-D03 `OPEN`。

Ledger 總數維持 128，嚴重度維持 Critical 8、High 31、Medium 51、Low 38；
latest-record-wins 維持 75 COMPLETED / 46 OPEN / 6 DECIDED / 1 IN_PROGRESS。
High 維持 22 COMPLETED / 8 OPEN / 1 IN_PROGRESS，未關閉 High 仍為 9 條：
R-B23、R-D03、R-E09、R-F02、R-G01、R-G02、R-G03、R-H03、R-J03。

Metadata `head_commit` 指向被本節判定不具 closure 資格的 attempt，作為 drift
evidence，而非 Ready head；本 truth-restoration commit 不預填自身 hash。Canonical
umbrella note 維持 `Draft`、`TBD`、`Open`、`Aggregate`；`sdd-pipeline` 維持
experimental、default-disabled、execution-denied。PR #3 維持
`NOT READY TO MERGE`。

## 31. 2026-07-21 R-D03 clean re-entry implementation 完成增補

本節保留第 30 節的 invalid-entry 與 truth-restoration 時間線。Commit
`687625af6a9df299c1037e1ba3ec29ef154dc6d3` 先把五個 implementation surfaces
恢復為 pre-R-D03 語義，並在 parent history 中提交日期化 owner authorization；其後的
clean re-entry implementation commit
`2f941002009b1e05b33d790e7c6c8fc06e8daf3c` 才重新套用 R-D03 修復。因此本節不把
`8101f9a380eb27c5004bece9aad77d42b2cc8a51` 回填成 closing evidence，也不改寫其
不具 closure 資格的歷史判定。

R-D03 原 finding 的 mandatory Implement first-action gate 部分已由 R-D02 完成，本次
只結算剩餘的 task priority 與 parallelism 語義。Canonical 與 Claude Implement agents
現在把 `[P#]` 限定為 delivery priority，不從 `[P]` 或 `[P#]` checklist token 推導
平行執行，並只從 `Dependencies`、`Parallel Execution Examples` 或 `Parallel with:`
metadata 取得平行資訊。

| 驗收面 | Implementation head `2f941002009b1e05b33d790e7c6c8fc06e8daf3c` 已觀察結果 |
|---|---|
| Pre-repair focused assertions | 18 passed / 2 failed |
| Post-repair focused parity | 20 passed / 0 failed |
| Coordinated source-and-mirror legacy mutation | 1 passed / 0 failed；Claude parity 維持 valid，兩個 R-D03 contract invariants 同時拒絕舊語義 |
| Canonical runtime audit | `VALID=true`、0 errors、0 warnings |
| Full governance suite | 747 passed、0 failed、0 skipped、0 not run |

| ID 或範圍 | 2026-07-21 latest-record-wins 狀態 | Disposition |
|---|---|---|
| R-D03 | COMPLETED | Clean re-entry commit `2f941002009b1e05b33d790e7c6c8fc06e8daf3c` 完成 source、generated mirror、contract anchors 與判別性 tests；R-D02 不重複計算 |
| R-G03 | OPEN，狀態不變 | CLI、template 與 upstream docs 版本事實維持獨立 finding；本批不修復、接受或 defer |
| R6 overall | IN_PROGRESS | R-E11、其餘 residual dispositions、promotion、Aggregate、merge 與 post-merge evidence 尚未完成 |
| R-E09 | IN_PROGRESS | Umbrella、promotion decision、merge accounting 與 post-merge evidence 尚未完成 |
| 其他 residuals | 狀態不變 | 未由 R-D03 clean re-entry 吸收 |

Ledger 總數維持 128，嚴重度維持 Critical 8、High 31、Medium 51、Low 38。
Latest-record-wins 折疊狀態由 75 COMPLETED / 46 OPEN / 6 DECIDED / 1 IN_PROGRESS
改為 76 COMPLETED / 45 OPEN / 6 DECIDED / 1 IN_PROGRESS。High 狀態改為
23 COMPLETED / 7 OPEN / 1 IN_PROGRESS；未完成 High 維持 8 條：R-B23、R-E09、
R-F02、R-G01、R-G02、R-G03、R-H03、R-J03。

本 accounting worktree 將 R-D03 note 更新為 `Ready`、reconciliation `Closed`，並只以
`2f941002009b1e05b33d790e7c6c8fc06e8daf3c` 作 Related Commit。Accounting commit
尚未存在，因此 committed accounting-head 的 runtime、完整 suite、Batch、Aggregate
與 diff/worktree hygiene 尚未執行，不得把本節寫成 final Batch 或 Aggregate green。
這項順序只修正第 30 節把 blocking Batch gate 放在 Ready accounting commit 之前的
不可執行排列：validator 必須先看到 committed Ready note 才能評估該 note。它不豁免
任何 gate，也不把目前狀態當作不可撤回的 final acceptance。
若任何 post-accounting gate 推翻本節證據，必須立即依 note 狀態機把 note 降回
`Draft`、reconciliation 改回 `Open`，並把 R-D03 還原為 `OPEN`。

Metadata `head_commit` 指向已完成上述 implementation-head 技術驗證的 clean re-entry
commit，不預填本 accounting commit hash。Canonical umbrella note 維持 `Draft`、
`TBD`、`Open`、`Aggregate`；`sdd-pipeline` 維持 experimental、default-disabled、
execution-denied。PR #3 維持 `NOT READY TO MERGE`；本批不 promotion、不 push、
不 merge、不 resolve PR threads，也不記錄 post-merge success。

## 32. 2026-07-21 R-D03 accounting-head final gates 增補

本節只回填第 31 節明列為 pending 的 committed accounting-head gates，不改寫 reset、
authorization、invalid attempt 或 clean re-entry implementation 的歷史。Accounting commit
`7ad8bb76eccccf91a7b87954ce19f97c3ff12951` 與先行 detached candidate 使用相同 tree、
parent、message 與 commit metadata，因此完整 suite 與 runtime 證據精確綁定正式 branch
commit，而不是以相似內容推論。

| 驗收面 | Accounting head `7ad8bb76eccccf91a7b87954ce19f97c3ff12951` 已觀察結果 |
|---|---|
| Full governance suite | 747 passed、0 failed、0 skipped、0 not run，1041.44 秒 |
| Canonical runtime audit | `VALID=true`、0 errors、0 warnings |
| Historical sealed evidence | 18 of 18 records valid |
| Batch gate | BaseRef `687625af6a9df299c1037e1ba3ec29ef154dc6d3`；`VALID=true`、0 errors、0 warnings；10 changed paths |
| Aggregate gate | 預期 exit 1；唯一 error 是 canonical umbrella note 的 `aggregate-note-not-ready` |
| Diff 與 worktree hygiene | `git diff --check` passed；正式與隔離 candidate worktree 均 clean |

R-D03 維持 `COMPLETED`；ledger 維持 128 條、Critical 8 / High 31 / Medium 51 /
Low 38，以及 76 COMPLETED / 45 OPEN / 6 DECIDED / 1 IN_PROGRESS。High 維持
23 COMPLETED / 7 OPEN / 1 IN_PROGRESS；8 個未完成 High 仍為 R-B23、R-E09、
R-F02、R-G01、R-G02、R-G03、R-H03、R-J03。R-G03 未被接受、defer 或修復。

Metadata `head_commit` 指向已完整驗證的 accounting head，不預填本 addendum commit 的
自我參照 hash。Canonical umbrella note 維持 `Draft`、`TBD`、`Open`、`Aggregate`；
`sdd-pipeline` 維持 experimental、default-disabled、execution-denied。R6 overall 與
R-E09 維持 `IN_PROGRESS`；R-E11、其他 residual dispositions、promotion、merge 與
post-merge evidence 仍未完成。PR #3 維持 `NOT READY TO MERGE`；本批不 push、不 merge、
不 resolve PR threads。

## 33. 2026-07-21 R-F04 status drift-stop 與 prospective truth-restoration plan

R6 residual disposition audit 以唯讀方式重建 128 條 finding 的 latest-record-wins 狀態時，
發現 R-F04 有兩個互斥的 current-surface 解讀：

| Evidence | Recorded meaning |
|---|---|
| 第 3 節 R-F04 與第 6 節 owner decision | `DECIDED`；退役 agent-skills export/install 能力鏈的方向已裁定，但尚未實作 |
| 第 22 節 RB-4 residual record 與 remediation plan 第 11 節 | `OPEN`；只移除 upgrade caller，不把 partial alignment 冒充完整退役 |
| 第 31、32 節 folded summary | 76 COMPLETED / 45 OPEN / 6 DECIDED / 1 IN_PROGRESS；此數字只有把 R-F04 計為 `DECIDED` 才成立 |

若採較晚 RB-4 的 `OPEN` 字面狀態，精確折疊應為 76 COMPLETED / 46 OPEN /
5 DECIDED / 1 IN_PROGRESS。文件同時保留該字面狀態與另一組計數，構成不能由 agent
自行選邊的 ledger drift。

Owner 於 2026-07-21 明確裁定，R-F04 的 authoritative status 應為 `DECIDED`。此裁定只表示
退役方向仍有效，不表示三支 scripts、audit、contract、docs、tests 或
`resources/agent-skill-packs/` 已完成移除。R-H15 維持原有 `DECIDED`；任何
`COMPLETED` 或 `DISPOSITIONED` 宣稱仍須另有實作與驗收證據。

本節是 implementation 前的 prospective plan，不新增 R-F04 latest-status row，也不宣稱
上述矛盾已在本 commit 修復。Required sequence 如下：

1. 先提交本日期化 owner-authorized plan，以及 `Draft`、`Open`、`TBD` 的 dedicated
   mainline note。
2. 只在該 plan commit 之後，以新的 accounting-only implementation commit 追加
   R-F04 `DECIDED` clarification；不改寫第 22 節歷史記錄。
3. 以 section-bounded parser 對 pre-implementation parent 與 proposed tree 做判別：舊樹
   必須回報 R-F04 status/count ambiguity，新樹必須唯一折疊為 128 條以及
   76 COMPLETED / 45 OPEN / 6 DECIDED / 1 IN_PROGRESS。
4. 驗證 R-F04 與 R-H15 都沒有被誤標 `COMPLETED` 或 `DISPOSITIONED`，且所有其他 finding
   狀態不變。
5. 另以 accounting commit 將 dedicated note 更新為 `Ready`、reconciliation `Closed`，
   並引用真實 implementation commit；其 exact tree 必須通過 runtime、完整 governance
   suite、Batch、預期 Aggregate blocker 與 diff hygiene。
6. 只有上述順序全數成立後，才從一致的 ledger 恢復唯讀 R6 residual disposition audit。

本批只處理 R-F04 status/count truth restoration，不執行 R-F04 retirement，不處理 R-H15，
不變更 R-E11、workflow promotion、Aggregate、merge 或其他 residual disposition。
Canonical `sdd-pipeline` 維持 experimental、default-disabled、execution-denied；PR #3
維持 `NOT READY TO MERGE`。

## 34. 2026-07-21 R-F04 authoritative status clarification implementation

Committed entry-plan parent `bab1ce93aec28819a0c68a3ed7f6e85d3de53442` 已保存第 33 節的
owner authorization、drift-stop 與驗收順序。本節只實作該 plan 的 append-only 帳務校正；
第 22 節 RB-4 `OPEN` 記錄保留為當時的 partial-alignment 歷史，不被靜默改寫。

| ID 或範圍 | 2026-07-21 authoritative latest 狀態 | Disposition |
|---|---|---|
| R-F04 | DECIDED | Supersedes 第 22 節的 `OPEN` label；退役方向已由 owner 裁定，但 scripts、audit、contract、docs、tests 與 output surface 仍未完整移除，所以不是 `COMPLETED`、`DISPOSITIONED`、defer 或 risk acceptance |
| R-H15 | DECIDED，狀態不變 | 維持與 R-F04 相同能力鏈的原 owner decision；本批未執行 output directory retirement |
| R6 overall / R-E09 | IN_PROGRESS，狀態不變 | Residual dispositions、promotion、Aggregate、merge 與 post-merge evidence 仍未完成 |
| 其他 126 條 findings | 狀態不變 | 本批沒有修復、關閉、接受、defer 或重新分類其他 finding |

Canonical inventory 維持 128 條，嚴重度維持 Critical 8、High 31、Medium 51、Low 38。
Authoritative latest-record-wins fold 唯一為 76 COMPLETED / 45 OPEN / 6 DECIDED /
1 IN_PROGRESS。R-F04 與 R-H15 均計為 `DECIDED` 且尚未實作；上述 clarification 不改變
既有 folded counts，只消除 status label 與 counts 互相矛盾的解讀。

Section-bounded 判別檢查已將 finding inventory、第 22 節歷史 R-F04 record、最新 status
section 與 folded summary 分開解析：

| 判別面 | Pre-implementation parent `bab1ce9` | Proposed tree |
|---|---|---|
| Hardened fold | `VALID=false`；R-F04 structured status 為 `DECIDED`，但之後有 `OPEN` direct-status records | `VALID=true`；0 ambiguities；R-F04 與 R-H15 均為 `DECIDED` |
| Inventory 與 severity | 128；8 / 31 / 51 / 38 | 128；8 / 31 / 51 / 38 |
| Inventory parity | Baseline | 與 parent 完全相同 |
| 第 22 節歷史 | Baseline | 與 parent 完全相同 |
| Deleted finding rows | 不適用 | 0 |

新 section 恰有一個 R-F04 `DECIDED` row、一個 R-H15 `DECIDED` row，且沒有其他具體
finding ID status row；fold 維持 76 / 45 / 6 / 1。既有 ledger 內容除 metadata、revision
history 與本日期化 append-only section 外不改寫，因此其他 126 條 finding disposition
保持不變。

Dedicated note 在 implementation commit 仍維持 `Draft`、`TBD`、reconciliation `Open`、
scope `Batch`；它只能在 implementation commit 存在且 final exact-tree gates 完成後，另以
accounting commit 改為 `Ready`、`Closed` 並引用真實 hash。Canonical umbrella note 維持
`Draft`、`TBD`、`Open`、`Aggregate`；`sdd-pipeline` 維持 experimental、default-disabled、
execution-denied。R6 audit 仍暫停，PR #3 仍 `NOT READY TO MERGE`；本批不執行 retirement、
promotion、push、merge 或 PR thread resolution。

## 35. 2026-07-21 R-F04 truth-restoration final accounting 與 scope-aware gate 裁定

Implementation `180abc05b8eaaa6fb32a753e81931f14e10ef726` follows committed entry plan
`bab1ce93aec28819a0c68a3ed7f6e85d3de53442` and contains the Section 34 authoritative
status row. Before accounting, the handoff's no-scope `-RequireReady` command returned nonzero:
one `arguments` error because current R-A20 requires an explicit scope, plus five
`branch-evidence-coverage-missing` records. The repository template already prescribes
`-ReadinessScope Batch`, while CI and merge readiness use `-ReadinessScope Aggregate`.

This conflict triggered drift-stop. Owner then selected Choice A on 2026-07-21: this bounded
accounting uses explicit Batch as its blocking green gate and separately requires Aggregate to
return only the canonical umbrella blocker. The failed no-scope command remains diagnostic
evidence and is not relabeled green. No validator behavior or runtime contract changed.

| Final gate | Exact accounting-tree result |
|---|---|
| Hardened ledger fold | `VALID=true`、0 ambiguities；128 findings；Critical 8 / High 31 / Medium 51 / Low 38；76 COMPLETED / 45 OPEN / 6 DECIDED / 1 IN_PROGRESS |
| Full governance suite | 747 passed、0 failed、0 skipped、0 not run |
| Canonical runtime audit | `VALID=true`、0 errors、0 warnings；historical evidence 18/18 |
| Explicit Batch | BaseRef `6b749a1f153dc88412714db0ed6d8708170c5936`；`VALID=true`、0 errors、0 warnings；5 changed paths |
| Explicit Aggregate | Expected exit 1；唯一 error 是 canonical umbrella note 的 `aggregate-note-not-ready` |
| No-scope drift diagnostic | Expected exit 1；1 個 `arguments` 與 5 個 `branch-evidence-coverage-missing`；依 owner Choice A 不具 acceptance authority |
| Diff 與 worktree hygiene | `git diff --check` passed；detached candidate 與正式 branch tree 相同 |

No-scope diagnostic 的五個 coverage paths 是 `.github/agents/speckit.clarify.agent.md`、
`.github/agents/speckit.tasks.agent.md`、`studio/runtime/impact-registry.json`、
`studio/workflows/state.json`、`studio/workflows/state.schema.json`。它們是 canonical umbrella
與 R-E09 既有未完成 Aggregate reconciliation 的具體義務；本 Batch 不修復、不 defer、
不接受風險，也不另把它們吸收為 R-F04 closure evidence。

Dedicated note now cites implementation `180abc05b8eaaa6fb32a753e81931f14e10ef726` and is
`Ready` / `Closed` / `Batch`. R-F04 and R-H15 remain `DECIDED` with retirement unimplemented;
the other 126 finding dispositions are unchanged. R6 overall and R-E09 remain `IN_PROGRESS`.
The read-only residual audit may resume from the consistent fold, but Aggregate acceptance,
promotion, merge, and post-merge evidence remain blocked.

Metadata `head_commit` points to the implementation and does not self-reference this accounting
commit. The canonical umbrella note remains `Draft` / `TBD` / `Open` / `Aggregate`;
`sdd-pipeline` remains experimental, default-disabled, and execution-denied. PR #3 remains
`NOT READY TO MERGE`; this batch does not retire skills, promote, push, merge, record post-merge
success, or resolve PR threads.

## 36. 2026-07-21 R6 conservative non-promotion convergence entry plan

Owner selected Choice A on 2026-07-21 after the reconciled 128-item fold was re-audited. The
authorized direction is conservative convergence: repair bounded safety and current-surface
truthfulness defects that remain reachable, keep the canonical workflow non-promoted, and move
non-critical backlog to Wave-4 only through explicit `DISPOSITIONED` records with re-entry
triggers. `DISPOSITIONED` in this plan means owner-approved deferral under a named condition; it
does not mean implemented, harmless, or accepted without conditions.

The same residual audit found two workflow analogues that cannot be silently absorbed into the
extension findings:

| ID | Severity | 2026-07-21 finding | Required disposition | Current status |
|---|---|---|---|---|
| R-B25 | Low | `studio/workflows/sdd-pipeline/manifest.json` declares `compatibility.minStudioConstitutionVersion=1.8.0`, but workflow validation, listing, authorization and runtime audit never compare or enforce it; the Studio Constitution is already newer, so the field is an outdated, unenforced compatibility claim | Retire the workflow field, add an absence invariant and a discriminating re-add mutation; field removal must not be described as workflow promotion | OPEN |
| R-B26 | Medium | Workflow policy says deprecated workflows are not newly enabled and remote sync is unsupported, but `set-workflow-state.ps1` and shared authorization allow a deprecated workflow to be enabled, while workflow catalog/state schemas still accept the producerless `sync` source | Deny absent, disabled or stale-pin deprecated enablement; permit only an already-enabled same-pin deprecated no-op; remove `sync` from schemas, catalog, policy and shared parsing; add strict negatives and revert anchors | OPEN |

These two rows raise the inventory from 128 to 130. Severity becomes Critical 8, High 31,
Medium 52 and Low 39. No prior finding status changes in this entry-plan commit. The current fold
is therefore 76 `COMPLETED`, 47 `OPEN`, 6 `DECIDED`, 1 `IN_PROGRESS` and 0
`DISPOSITIONED`.

### 36.1 Prospective per-finding disposition matrix

The following matrix is exhaustive for the 54 findings that are not `COMPLETED` after R-B25 and
R-B26 are registered. It is authorization for future work, not a status update in this commit.

| Prospective disposition | Finding IDs | Count | Closure boundary |
|---|---|---:|---|
| Direct repair from `OPEN` | R-A21, R-B18, R-B25, R-B26, R-C04, R-C06, R-E02, R-E08, R-E11, R-G01, R-G03, R-G04, R-H03, R-H04, R-H06, R-H09 | 16 | May become `COMPLETED` only after implementation, old-fails/new-passes evidence, contract anchors and exact-tree gates |
| Implement existing owner decision | R-D07 | 1 | May move from `DECIDED` to `COMPLETED` only after path/type scope is machine-anchored and governed documents remain Section 10.1 compliant |
| Wave-4 disposition from `OPEN` | R-A13, R-B23, R-D08, R-D09, R-D10, R-D11, R-E01, R-E03, R-E04, R-E06, R-E12, R-F01, R-F02, R-F03, R-F05, R-G02, R-G05, R-G07, R-G08, R-G09, R-G11, R-G12, R-H07, R-H14, R-H18, R-I01, R-I02, R-I04, R-I05, R-I09 | 30 | May become `DISPOSITIONED` only in a later accounting record that preserves the re-entry trigger |
| Wave-4 disposition from `DECIDED` | R-D06, R-D12, R-F04, R-H15, R-I03 | 5 | Owner direction remains valid, but implementation is deferred and must not be called complete |
| Terminal blocker | R-E09, R-J03 | 2 | Both retain their current status until real umbrella, merge and post-merge evidence exist |

If all authorized direct repairs and Wave-4 dispositions later pass their gates, the pre-merge
fold will be 93 `COMPLETED`, 1 `OPEN`, 1 `IN_PROGRESS`, 35 `DISPOSITIONED` and 0
`DECIDED`. Only actual merge and post-merge validation may produce the terminal 95
`COMPLETED` / 35 `DISPOSITIONED` fold. Neither target fold is asserted by this plan commit.

### 36.2 Wave-4 re-entry triggers

| Finding IDs | Mandatory re-entry trigger |
|---|---|
| R-A13 | Before adding or materially expanding `mustContainAll` literal assertions, or before the next contract-invariant refactor |
| R-B23 | Before any workflow promotion, execution authorization, or use of RunState/sidecar data as trusted evidence; deferral is valid only while `sdd-pipeline` stays experimental, default-disabled and execution-denied |
| R-F01, R-F02, R-F03, R-F05, R-G02 | Before upstream adoption, Yuanxi pack implementation, or any renewed current-baseline claim; upstream release and CLI facts must be re-verified at that time |
| R-D08, R-D09, R-D10, R-D11 | Before the next change to agent source, Claude invocation guidance, discovery/version-agent surfaces or their generated mirrors |
| R-E01, R-E03, R-E04, R-E06, R-E12 | Before the corresponding constitution classification, authority taxonomy, bootstrap wording or hook classification is changed again |
| R-G05, R-G07, R-G08, R-G09, R-G11, R-G12 | Before the affected document is reused as current guidance, supplied to an LLM for execution, or materially revised |
| R-H07, R-H14, R-H18 | Before the affected root asset, reserved directory or language policy is presented as a current supported surface |
| R-I01 | Before the shared-runtime upgrade scope is expanded or changed |
| R-I02 | Before adapter templates or the bootstrap generator are changed |
| R-I04, R-I05 | Before a project claims complete prompt or knowledge-capture closure |
| R-I09 | Before the extension operator surface is documented or used externally |
| R-D06 | Before agent reseed or a model lifecycle, availability, cost or policy change |
| R-D12 | Only after a separate owner-authorized consumer exception and a decision between project-local Copilot overlay and Claude-only support; current `projects/` and `learning/` exclusion prevents implementation |
| R-F04, R-H15 | Before agent-skill export/install is reused, advertised or repopulated |
| R-I03 | Before route-aware auto-scaffold work or workflow promotion |

R-E04 remains independent authority drift. R-E11 may use the current generator-first operation
during its bounded implementation, but must not claim that `impact-registry.json` authority is
fully reconciled. R-E11 also cannot partially edit README authority wording and absorb R-H03;
R-H03 requires its complete direct-repair contract.

### 36.3 Authorized implementation sequence

1. Governance authority and current entry surfaces: R-E11, R-D07, R-E02, R-E08, R-H03 and
   R-H04. Keep the ledger document default `informational`; create only a machine-bounded
   `finding_status` scope with `source_of_truth` authority. The exact selector is
   `finding-status-record-v1`; `studio/runtime/finding-status-record.schema.json` defines record
   shape, `studio/scripts/powershell/validate-finding-status-ledger.ps1` owns fold validation, and
   `shared-runtime-contract.json` references structure but never duplicates the current counts.
   Add append-only JSON delta records, deterministic fold/index parity, BaseRef history
   preservation and runtime fail-closed integration. Revision 1 must contain the complete 130-ID
   snapshot with R-E11 still `OPEN`, and its IDs must match the independently parsed first
   severity-definition occurrence for each finding ID; later historical status tables do not create
   duplicate definitions. Revisions must be unique, appear in strict consecutive order beginning at
   1, and reject a delta before the full snapshot. Later revisions contain deltas plus the complete
   resulting count/fold. Only a later accounting record may complete R-E11. Constitution moves to 1.10.0 and the three generated
   root adapters move with it. Full R-H03 and R-H04 repairs are required if their surfaces are
   touched.
2. Shared feature binding and mainline matcher: R-A21 and R-B18. Use one repository-root based
   feature resolver in every setup/check entrypoint, pass named `-FeatureDir` through canonical
   agents, deterministic Claude mirrors and workflow handoffs, and correct middle `/**/` matching
   so zero, one and multiple directory levels work without near-prefix leakage.
3. Extension and workflow lifecycle truthfulness: R-C04, R-C06, R-B25 and R-B26. Remove both
   unenforced extension compatibility fields and the workflow analogue; remove dead `sync`
   provenance; deny new deprecated enablement while preserving only an already-enabled same-pin
   no-op. Extension and workflow findings remain separate in tests and accounting.
4. Shared documentation and configuration truthfulness: R-G01, R-G03, R-G04, R-H06 and R-H09.
   Update the shared governance status surface without changing consumer repositories; quarantine
   superseded upstream guidance; make the strategy document Section 10.1 compliant; relocate the
   historical six-stage file and repair references; remove stale or unsafe VS Code settings.
5. In a separate accounting change, append exact per-ID `COMPLETED` records only for repairs whose
   implementation and evidence exist. Then append the 35 owner-approved Wave-4
   `DISPOSITIONED` records with the triggers in Section 36.2. Do not convert R-E09 or R-J03.
6. Reconcile the canonical Wave-3 umbrella under permanent non-promotion and stop at a merge
   authorization checkpoint. Do not merge, push, promote, claim post-merge success or resolve PR
   threads without separate authority.

Implementation commits and accounting commits must remain separate. A failure in any sub-batch
does not permit partial closure of its multi-part finding, and a green focused test does not replace
the final exact-tree gates.

### 36.4 Discriminating acceptance contract

| Surface | Required old-fails/new-passes evidence |
|---|---|
| R-E11 | Missing ledger; missing scoped authority; missing revision 1; duplicate, out-of-order or non-consecutive revisions; duplicate or ambiguous IDs; invalid enum, null or wrong type; count/fold/index mismatch; rewritten BaseRef records; and reverted audit invocation must all fail closed. Historical Markdown prose is not a status source. |
| R-A21 | Direct, one-level and multi-level governed paths must match; near-prefix, sibling and normalized backslash counterexamples must not match. Reverting the matcher must break the contract. |
| R-B18 | Foreign repository, sibling `specs`, nested feature, traversal, branch or environment rebind, and omitted named handoff must be rejected; repository-owned direct and normalized relative feature paths remain positive controls. |
| R-C04 and R-B25 | Reintroducing any retired compatibility field must fail a schema or contract absence invariant. Removal cannot change workflow promotion state. |
| R-C06 and R-B26 | Missing, disabled and stale-pin deprecated enablement plus `sync`, wrong-type and null provenance must be denied; an already-enabled same-pin deprecated no-op is the bounded positive control. |
| R-D07, R-E02, R-E08 | Mutating the path/type scope, current phase, review date or adapter parity must break constitution/adapter contract tests; governed SDD and governance documents remain free of prohibited emoji, arrow and tree syntax. |
| R-G01, R-G03, R-G04, R-H03, R-H04, R-H06, R-H09 | Removing status/superseded/authority/workflow/relocation/configuration anchors or restoring stale references and settings must fail dedicated document/configuration tests. Each finding requires its own revert-sensitive invariant. |

Every closing accounting tree must run:

- `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json`, expecting `VALID=true`,
  0 errors and 0 warnings.
- `pwsh ./studio/scripts/powershell/run-governance-tests.ps1`, expecting no regression below the
  current 747 passed baseline and 0 failed.
- `pwsh ./studio/scripts/powershell/validate-mainline-notes.ps1 -BaseRef <committed-entry-plan> -HeadRef HEAD -RequireReady -ReadinessScope Batch -Json`, expecting `VALID=true`, 0 errors and 0 warnings.
- The same validator with `-ReadinessScope Aggregate`, expecting nonzero only for the canonical
  Wave-3 umbrella while it remains Draft; no additional error is permitted.
- `git diff --check` and clean exact-tree worktree verification.

Choice A preserves explicit Batch/Aggregate scope. The obsolete no-scope invocation is not an
acceptance gate and must not be relabeled green. This plan itself changes no finding beyond adding
R-B25/R-B26 as `OPEN`; the dedicated note remains `Draft`, `TBD` and reconciliation `Open`.
PR #3 remains `NOT READY TO MERGE`, and `sdd-pipeline` remains experimental, default-disabled
and execution-denied.

## 37. 2026-07-22 R6-A1 Claude mirror authority drift-stop 與 owner-authorized plan correction

Entry-plan commit `f669e3dcd116ed8ff612b9a8875167bd5b3a3881` passed staged audit and
post-commit runtime with 0 errors and 0 warnings. Before implementation, read-only R6-A1 preflight
found that the planned R-H03 repair is too narrow for the actual Claude authority drift:

| Evidence surface | Current contradictory claim |
|---|---|
| `studio/constitution/constitution.md` | `.claude/agents/*.md` are seeded `dependent` mirrors of `.github/agents/` |
| `studio/scripts/powershell/seed-claude-agents.ps1` and all 15 generated mirrors | Generated header calls `.claude/agents/` the Claude shared runtime authority after generation |
| `.github/copilot-instructions.md` | Canonical-source table and manual guidance call `.claude/agents/` runtime source/authority |
| `WORKSPACE_STRUCTURE.md`, both Studio quickstarts | Current guidance repeats source-of-truth or authority wording |
| `studio/runtime/shared-runtime-contract.json` | Multiple invariants actively require the contradictory authority wording |

R-H03 explicitly covers three README defects. Expanding it to generator, generated mirrors,
adapter, quickstarts, structure documentation and contract would silently absorb an independently
enforced failure mode. Owner therefore authorized the following new finding on 2026-07-22:

| ID | Severity | 2026-07-22 finding | Required disposition | Current status |
|---|---|---|---|---|
| R-H20 | High | Constitution 1.9.0 classifies `.claude/agents/*.md` as seeded dependent mirrors, but current generator, all generated mirrors, Copilot adapter, quickstarts, WORKSPACE_STRUCTURE and runtime contract describe the same directory as source/runtime authority and lock the contradiction with machine invariants | Preserve `.github/agents/` as canonical agent source; describe `.claude/agents/` consistently as the deterministic Claude-consumable seeded dependent mirror; repair generator, reseed all mirrors, update current guidance/contract and add direction-sensitive mutation tests | OPEN |

Historical mainline notes remain historical evidence and are not rewritten. README wording remains
part of R-H03 so both IDs retain independently testable boundaries. R-H20 does not change
R-D04's completed deterministic parity implementation; it corrects the authority semantics emitted
by that generator. No `projects/` or `learning/` consumer is changed.

### 37.1 Superseding counts and exhaustive matrix

R-H20 raises the inventory to 131 and severity to Critical 8, High 32, Medium 52 and Low 39.
Because it enters `OPEN`, current status becomes 76 `COMPLETED`, 48 `OPEN`, 6 `DECIDED`,
1 `IN_PROGRESS` and 0 `DISPOSITIONED`. This section supersedes only the prospective counts and
matrix in Section 36; all Section 36.2 Wave-4 triggers remain unchanged.

| Prospective disposition | Finding IDs | Count | Closure boundary |
|---|---|---:|---|
| Direct repair from `OPEN` | R-A21, R-B18, R-B25, R-B26, R-C04, R-C06, R-E02, R-E08, R-E11, R-G01, R-G03, R-G04, R-H03, R-H04, R-H06, R-H09, R-H20 | 17 | May become `COMPLETED` only after implementation, old-fails/new-passes evidence, contract anchors and exact-tree gates |
| Implement existing owner decision | R-D07 | 1 | May move from `DECIDED` to `COMPLETED` only after path/type scope is machine-anchored and governed documents remain Section 10.1 compliant |
| Wave-4 disposition from `OPEN` | R-A13, R-B23, R-D08, R-D09, R-D10, R-D11, R-E01, R-E03, R-E04, R-E06, R-E12, R-F01, R-F02, R-F03, R-F05, R-G02, R-G05, R-G07, R-G08, R-G09, R-G11, R-G12, R-H07, R-H14, R-H18, R-I01, R-I02, R-I04, R-I05, R-I09 | 30 | May become `DISPOSITIONED` only in a later accounting record that preserves its Section 36.2 trigger |
| Wave-4 disposition from `DECIDED` | R-D06, R-D12, R-F04, R-H15, R-I03 | 5 | Owner direction remains valid, but implementation is deferred and must not be called complete |
| Terminal blocker | R-E09, R-J03 | 2 | Both retain their current status until real umbrella, merge and post-merge evidence exist |

All 55 non-completed findings appear exactly once. If the 18 authorized direct repairs and 35
Wave-4 dispositions later pass, the only permitted pre-merge fold is 94 `COMPLETED`, 1 `OPEN`,
1 `IN_PROGRESS`, 35 `DISPOSITIONED` and 0 `DECIDED`. Only actual merge and post-merge
validation may produce 96 `COMPLETED` / 35 `DISPOSITIONED`. This plan correction asserts
neither future fold.

### 37.2 Corrected R6-A1 implementation boundary

R6-A1 now contains R-E11, R-D07, R-E02, R-E08, R-H03, R-H04 and R-H20. R-H20 implementation
must follow Constitution Section 12 authority order: first reconcile all affected source-of-truth
surfaces, including Constitution semantics, the generator and runtime contract; then regenerate all
15 dependent mirrors and synchronize dependent adapters; finally update informational quickstarts
and structure documentation. The wording must preserve both facts: `.github/agents/` is the
canonical agent source, while `.claude/agents/` is the deterministic seeded dependent mirror used
by Claude at runtime and is not edited as an authority source.

Required R-H20 discrimination includes:

- Restoring `Claude shared runtime authority after generation` in the generator and reseeding must
  fail the contract/parity suite.
- Reversing `.github/agents/` source and `.claude/agents/` dependent direction must fail.
- Restoring authority wording in the Copilot adapter, either quickstart or WORKSPACE_STRUCTURE
  must fail a path-specific invariant.
- Removing the dependent-mirror header from any generated Claude agent must fail deterministic
  parity or a closed-set header invariant.
- The positive control must prove Claude still consumes the generated runtime mirror and that
  workflow promotion state is unchanged.

R-E11 revision 1 must now contain the complete 131-ID snapshot with R-H20 and R-E11 both `OPEN`.
R-H20 may become `COMPLETED` only in a later accounting record after the implementation commit
and exact-tree gates exist. The dedicated R6 note remains `Draft`, Related Commits `TBD`,
reconciliation `Open` and scope `Batch`.

This correction is still pre-implementation. It does not complete or disposition any existing
finding, change R-E09/R-J03, promote a workflow, push, merge, record post-merge success or resolve
PR threads. PR #3 remains `NOT READY TO MERGE`; `sdd-pipeline` remains experimental,
default-disabled and execution-denied.

## 38. 2026-07-22 R6-A1 canonical agent input partition correction

After committed R-H20 scope correction `997757efec1208023b9ada76e5a32de62b31fc4a`, a
read-only implementation preflight found that the phrase "`.github/agents/` is the canonical agent
source" is still too broad. The current directory contains 16 Markdown files. The generator reads
all `*.md` files and skips only `copilot-instructions.md`, producing 15 Claude mirrors.

| Current source class | Files | Authority |
|---|---:|---|
| Command and agent definitions | 14 `*.agent.md` files | `source_of_truth` generator inputs |
| Shared reviewer definition | `async-python-reviewer.md` | `source_of_truth` generator input while R-D12 remains unimplemented |
| Agent-scoped Copilot adapter | `copilot-instructions.md` | `dependent`; excluded by the generator |
| Generated Claude files | 15 `.claude/agents/*.md` files | deterministic `dependent` mirrors |

Owner selected Choice A: refine R-H20 rather than register another finding because this is the
same source/dependent direction failure and leaves no independent residual after the partition is
enforced. R-H20 implementation MUST name the exact canonical input set instead of assigning one
authority to the whole directory. Constitution and impact-registry generation MUST classify
`async-python-reviewer.md` explicitly while retaining `copilot-instructions.md` as dependent.
R-D12 remains `DECIDED`; this correction neither relocates the reviewer nor changes any consumer.
R-E04 remains independent and is not absorbed.

Discriminating tests MUST fail if the generator consumes the dependent adapter, omits a declared
canonical input, reverses the GitHub-source and Claude-mirror direction, or permits any generated
mirror to lose its dependent header. The positive control MUST retain 15 current source-to-mirror
mappings and preserve `sdd-pipeline` as experimental, default-disabled and execution-denied.

This amendment is plan-only. The inventory remains 131 with severity 8 Critical / 32 High / 52
Medium / 39 Low and fold 76 `COMPLETED` / 48 `OPEN` / 6 `DECIDED` / 1 `IN_PROGRESS`.
R-H20 and R-E11 remain `OPEN`; the dedicated R6 note remains `Draft`, Related Commits `TBD`,
reconciliation `Open` and validation scope `Batch`.

## 39. 2026-07-22 R-E11 scoped finding-status authority bootstrap

The ledger document remains `informational`. Only the visible fenced JSON record below, opened by
exactly three backticks followed immediately by the exact `finding-status-record-v1` info string,
is authoritative for `finding_status`. A visible longer-backtick or tilde fence using that selector
is an invalid authority envelope and fails closed; the same text inside a hidden Markdown surface
has no authority. Historical prose, Markdown status tables and differently selected code blocks are
not status sources. Revision 1 is a complete snapshot; later revisions must be append-only deltas
with unique, strictly consecutive revision numbers and committed BaseRef history preservation.

This bootstrap changes no finding status. In particular, R-E11 and R-H20 remain `OPEN`, R-E09
remains `IN_PROGRESS`, and R-J03 remains `OPEN`. The dedicated R6 note remains `Draft`, Related
Commits `TBD`, reconciliation `Open` and validation scope `Batch`.

```finding-status-record-v1
{
  "schemaVersion": 1,
  "revision": 1,
  "recordType": "snapshot",
  "recordedDate": "2026-07-22",
  "ledgerVersion": "1.29.0",
  "statuses": [{"id":"R-A01","status":"COMPLETED"},{"id":"R-A02","status":"COMPLETED"},{"id":"R-A03","status":"COMPLETED"},{"id":"R-A04","status":"COMPLETED"},{"id":"R-A05","status":"COMPLETED"},{"id":"R-A06","status":"COMPLETED"},{"id":"R-A07","status":"COMPLETED"},{"id":"R-A08","status":"COMPLETED"},{"id":"R-A09","status":"COMPLETED"},{"id":"R-A10","status":"COMPLETED"},{"id":"R-A11","status":"COMPLETED"},{"id":"R-A12","status":"COMPLETED"},{"id":"R-A13","status":"OPEN"},{"id":"R-A14","status":"COMPLETED"},{"id":"R-A15","status":"COMPLETED"},{"id":"R-A16","status":"COMPLETED"},{"id":"R-A17","status":"COMPLETED"},{"id":"R-A18","status":"COMPLETED"},{"id":"R-A19","status":"COMPLETED"},{"id":"R-A20","status":"COMPLETED"},{"id":"R-A21","status":"OPEN"},{"id":"R-A22","status":"COMPLETED"},{"id":"R-B01","status":"COMPLETED"},{"id":"R-B02","status":"COMPLETED"},{"id":"R-B03","status":"COMPLETED"},{"id":"R-B04","status":"COMPLETED"},{"id":"R-B05","status":"COMPLETED"},{"id":"R-B06","status":"COMPLETED"},{"id":"R-B07","status":"COMPLETED"},{"id":"R-B08","status":"COMPLETED"},{"id":"R-B09","status":"COMPLETED"},{"id":"R-B10","status":"COMPLETED"},{"id":"R-B11","status":"COMPLETED"},{"id":"R-B12","status":"COMPLETED"},{"id":"R-B13","status":"COMPLETED"},{"id":"R-B14","status":"COMPLETED"},{"id":"R-B15","status":"COMPLETED"},{"id":"R-B16","status":"COMPLETED"},{"id":"R-B17","status":"COMPLETED"},{"id":"R-B18","status":"OPEN"},{"id":"R-B19","status":"COMPLETED"},{"id":"R-B20","status":"COMPLETED"},{"id":"R-B21","status":"COMPLETED"},{"id":"R-B22","status":"COMPLETED"},{"id":"R-B23","status":"OPEN"},{"id":"R-B24","status":"COMPLETED"},{"id":"R-B25","status":"OPEN"},{"id":"R-B26","status":"OPEN"},{"id":"R-C01","status":"COMPLETED"},{"id":"R-C02","status":"COMPLETED"},{"id":"R-C03","status":"COMPLETED"},{"id":"R-C04","status":"OPEN"},{"id":"R-C05","status":"COMPLETED"},{"id":"R-C06","status":"OPEN"},{"id":"R-C07","status":"COMPLETED"},{"id":"R-C08","status":"COMPLETED"},{"id":"R-D01","status":"COMPLETED"},{"id":"R-D02","status":"COMPLETED"},{"id":"R-D03","status":"COMPLETED"},{"id":"R-D04","status":"COMPLETED"},{"id":"R-D05","status":"COMPLETED"},{"id":"R-D06","status":"DECIDED"},{"id":"R-D07","status":"DECIDED"},{"id":"R-D08","status":"OPEN"},{"id":"R-D09","status":"OPEN"},{"id":"R-D10","status":"OPEN"},{"id":"R-D11","status":"OPEN"},{"id":"R-D12","status":"DECIDED"},{"id":"R-E01","status":"OPEN"},{"id":"R-E02","status":"OPEN"},{"id":"R-E03","status":"OPEN"},{"id":"R-E04","status":"OPEN"},{"id":"R-E05","status":"COMPLETED"},{"id":"R-E06","status":"OPEN"},{"id":"R-E07","status":"COMPLETED"},{"id":"R-E08","status":"OPEN"},{"id":"R-E09","status":"IN_PROGRESS"},{"id":"R-E10","status":"COMPLETED"},{"id":"R-E11","status":"OPEN"},{"id":"R-E12","status":"OPEN"},{"id":"R-F01","status":"OPEN"},{"id":"R-F02","status":"OPEN"},{"id":"R-F03","status":"OPEN"},{"id":"R-F04","status":"DECIDED"},{"id":"R-F05","status":"OPEN"},{"id":"R-F06","status":"COMPLETED"},{"id":"R-G01","status":"OPEN"},{"id":"R-G02","status":"OPEN"},{"id":"R-G03","status":"OPEN"},{"id":"R-G04","status":"OPEN"},{"id":"R-G05","status":"OPEN"},{"id":"R-G06","status":"COMPLETED"},{"id":"R-G07","status":"OPEN"},{"id":"R-G08","status":"OPEN"},{"id":"R-G09","status":"OPEN"},{"id":"R-G10","status":"COMPLETED"},{"id":"R-G11","status":"OPEN"},{"id":"R-G12","status":"OPEN"},{"id":"R-G13","status":"COMPLETED"},{"id":"R-H01","status":"COMPLETED"},{"id":"R-H02","status":"COMPLETED"},{"id":"R-H03","status":"OPEN"},{"id":"R-H04","status":"OPEN"},{"id":"R-H05","status":"COMPLETED"},{"id":"R-H06","status":"OPEN"},{"id":"R-H07","status":"OPEN"},{"id":"R-H08","status":"COMPLETED"},{"id":"R-H09","status":"OPEN"},{"id":"R-H10","status":"COMPLETED"},{"id":"R-H11","status":"COMPLETED"},{"id":"R-H12","status":"COMPLETED"},{"id":"R-H13","status":"COMPLETED"},{"id":"R-H14","status":"OPEN"},{"id":"R-H15","status":"DECIDED"},{"id":"R-H16","status":"COMPLETED"},{"id":"R-H17","status":"COMPLETED"},{"id":"R-H18","status":"OPEN"},{"id":"R-H19","status":"COMPLETED"},{"id":"R-H20","status":"OPEN"},{"id":"R-I01","status":"OPEN"},{"id":"R-I02","status":"OPEN"},{"id":"R-I03","status":"DECIDED"},{"id":"R-I04","status":"OPEN"},{"id":"R-I05","status":"OPEN"},{"id":"R-I06","status":"COMPLETED"},{"id":"R-I07","status":"COMPLETED"},{"id":"R-I08","status":"COMPLETED"},{"id":"R-I09","status":"OPEN"},{"id":"R-J01","status":"COMPLETED"},{"id":"R-J02","status":"COMPLETED"},{"id":"R-J03","status":"OPEN"}],
  "inventoryCount": 131,
  "severityCounts": {
    "Critical": 8,
    "High": 32,
    "Medium": 52,
    "Low": 39
  },
  "statusCounts": {
    "COMPLETED": 76,
    "OPEN": 48,
    "DECIDED": 6,
    "IN_PROGRESS": 1,
    "DISPOSITIONED": 0
  }
}
```

## 40. 2026-07-22 R6-A1 scoped status accounting

Implementation `105a09cd02f7d8b4765e49859390908e55bd97d1` follows the committed R6 entry
plan and exact agent-partition correction. Plan-correction commit
`3e64e4e785496d604e16975752392d7bc2b6c50e` authorizes this A1-only checkpoint before
the later R6-A5 Wave-4 and cross-batch accounting.

The implementation tree passed 878 governance tests with 0 failures, the staged-snapshot hook,
and committed runtime, mainline, finding-history, bootstrap, Claude parity and impact-registry
checks with 0 errors and 0 warnings. Revision 2 therefore changes only the seven R6-A1 findings
whose implementation and discriminating evidence exist: R-D07, R-E02, R-E08, R-E11, R-H03,
R-H04 and R-H20.

This record does not account for A2 through A4, append a Wave-4 disposition, or complete R-E09 or
R-J03. The dedicated R6-A1 note remains `Draft`, reconciliation `Open` and validation scope
`Batch` until a later note-only finalization commit records this accounting identity and the exact
tree gates. The broad R6 convergence note and canonical Wave-3 umbrella note remain Draft and
non-authorizing. `sdd-pipeline` remains experimental, default-disabled and execution-denied;
PR #3 remains `NOT READY TO MERGE`.

```finding-status-record-v1
{
  "schemaVersion": 1,
  "revision": 2,
  "recordType": "delta",
  "recordedDate": "2026-07-22",
  "ledgerVersion": "1.30.0",
  "statuses": [
    {"id":"R-D07","status":"COMPLETED"},
    {"id":"R-E02","status":"COMPLETED"},
    {"id":"R-E08","status":"COMPLETED"},
    {"id":"R-E11","status":"COMPLETED"},
    {"id":"R-H03","status":"COMPLETED"},
    {"id":"R-H04","status":"COMPLETED"},
    {"id":"R-H20","status":"COMPLETED"}
  ],
  "inventoryCount": 131,
  "severityCounts": {
    "Critical": 8,
    "High": 32,
    "Medium": 52,
    "Low": 39
  },
  "statusCounts": {
    "COMPLETED": 83,
    "OPEN": 42,
    "DECIDED": 5,
    "IN_PROGRESS": 1,
    "DISPOSITIONED": 0
  }
}
```

## 41. 2026-07-22 R6-A1 finalization failure and R-E11 re-entry

The exact-tree governance suite at finalization head
`8f0dd46b3002626892d02bdf1808e68f21828005` discovered 878 tests but failed the
`promotes finding-status index tampering into a runtime audit failure` case. The fixture still
replaced revision-1 counts `COMPLETED:76,OPEN:48`; revision 2 contains
`COMPLETED:83,OPEN:42`, so the replacement was a no-op and the runtime audit correctly returned
success for unchanged bytes. The same inspection found that `docs/README.md` still described the
dedicated A1 note as Draft/Open after the note-only finalization commit changed it to Ready/Closed.

This evidence refutes the R-E11 discriminating-test closure and the dedicated Batch Ready claim.
It does not refute the implementation or tests for R-D07, R-E02, R-E08, R-H03, R-H04 or R-H20;
those six remain `COMPLETED`. Revision 3 therefore returns only R-E11 to `IN_PROGRESS`, and the
dedicated note returns to Draft with reconciliation Open. R-E09 remains `IN_PROGRESS`, R-J03
remains `OPEN`, and the broad R6 and canonical Wave-3 notes remain Draft and non-authorizing.

R-E11 may re-enter completion only after the negative fixture derives and visibly changes the
current machine index marker, includes an assertion that the mutation occurred, and the dependent
docs index matches the current note state. The repaired exact tree must then pass at least 878
governance tests with 0 failures, runtime and Batch validation with 0 errors and 0 warnings,
two-sided append-only history, the single expected Aggregate umbrella blocker, diff hygiene and a
clean worktree. This correction does not authorize R6-A2 through R6-A6, consumer edits, workflow
promotion, push, merge or PR-thread resolution. `sdd-pipeline` remains experimental,
default-disabled and execution-denied; PR #3 remains `NOT READY TO MERGE`.

```finding-status-record-v1
{
  "schemaVersion": 1,
  "revision": 3,
  "recordType": "delta",
  "recordedDate": "2026-07-22",
  "ledgerVersion": "1.31.0",
  "statuses": [
    {"id":"R-E11","status":"IN_PROGRESS"}
  ],
  "inventoryCount": 131,
  "severityCounts": {
    "Critical": 8,
    "High": 32,
    "Medium": 52,
    "Low": 39
  },
  "statusCounts": {
    "COMPLETED": 82,
    "OPEN": 42,
    "DECIDED": 5,
    "IN_PROGRESS": 2,
    "DISPOSITIONED": 0
  }
}
```

## 42. 2026-07-22 R6-A1 R-E11 fixture repair and revision 4 accounting

Repair commit `ea78b64fec17ee074018b9dc17abea31404f8f16` removes the no-op fixture path
that refuted the earlier R-E11 closure. The runtime and mainline-note fixtures now derive the
current `finding-status-index-v1` marker, assert that each intended mutation actually changes the
fixture, and make the isolated ledger unit fixture explicitly represent revision 1. Plan amendment
`483947a19cc4790785ae710bd7cf5e9ab9fff335` preserves revision 3 and authorizes this separate,
append-only revision 4 re-entry sequence.

On the clean repair-and-plan tree, the complete governance suite reports 878 passed, 0 failed,
0 skipped, 0 inconclusive and 0 not run. Runtime reports `VALID=true`, 0 errors and 0 warnings.
BaseRef history validation from `9b83f7a5d2e8630955efdb458f0e0e9a1c367839` through plan head
`483947a19cc4790785ae710bd7cf5e9ab9fff335` reports three valid records, revision 3, 131 findings,
fold 82/42/5/2/0 and `HISTORY_VALID=true`. These gates support restoring only R-E11 to
`COMPLETED`; R-D07, R-E02, R-E08, R-H03, R-H04 and R-H20 remain `COMPLETED` on their unaffected
evidence.

The dedicated R6-A1 note remains Draft with reconciliation Open and validation scope Batch. Its
Ready/Closed transition still requires a later note-only finalization commit followed by the full
exact-tree gate set. R6-A2 through R6-A6, Wave-4 dispositions, R-E09, R-J03, workflow promotion,
Aggregate acceptance, merge and post-merge evidence remain unchanged. This accounting does not
authorize edits under `projects/` or `learning/`, push, merge or PR-thread resolution.
`sdd-pipeline` remains experimental, default-disabled and execution-denied; PR #3 remains
`NOT READY TO MERGE`.

```finding-status-record-v1
{
  "schemaVersion": 1,
  "revision": 4,
  "recordType": "delta",
  "recordedDate": "2026-07-22",
  "ledgerVersion": "1.32.0",
  "statuses": [
    {"id":"R-E11","status":"COMPLETED"}
  ],
  "inventoryCount": 131,
  "severityCounts": {
    "Critical": 8,
    "High": 32,
    "Medium": 52,
    "Low": 39
  },
  "statusCounts": {
    "COMPLETED": 83,
    "OPEN": 42,
    "DECIDED": 5,
    "IN_PROGRESS": 1,
    "DISPOSITIONED": 0
  }
}
```

## 43. 2026-07-22 R6-A1 finalization evidence-coverage failure and second R-E11 re-entry

Surface-set correction `4d8bbe23a2e0bca39bc1e786780866af06227d7c` truthfully authorized
finalization head `f0f325b41563dea5cfa5d53582fbc0c316938f02` to synchronize the dedicated
note, its mainline index row and the dependent note-state prose in `docs/README.md`. The committed
tree preserved the revision-4 machine marker and passed its staged-snapshot audit.

Explicit Batch readiness from `9b83f7a5d2e8630955efdb458f0e0e9a1c367839` through `f0f325b` then failed
with exactly one `branch-evidence-coverage-missing` error for `docs/README.md`. That path's
last-touch commit was `f0f325b`, but a Ready note inside the same commit cannot cite the commit's
hash before it exists. Aggregate readiness still returned only the expected
`aggregate-note-not-ready` blocker, and finding-status history remained valid with four revisions,
131 findings and fold 83/42/5/1/0. Those passing partial results do not override the failed
mandatory Batch gate. The concurrently started runtime and complete governance suite were stopped
after the deterministic Batch failure and provide no finalization-tree result.

This evidence refutes only the R-E11 completion and dedicated Ready/Closed claim. R-D07, R-E02,
R-E08, R-H03, R-H04 and R-H20 remain `COMPLETED`. Revision 5 therefore returns only R-E11 to
`IN_PROGRESS`, and the dedicated note returns to Draft with reconciliation Open. The failure is an
R-E11 evidence-sequencing condition rather than an unrelated residual finding; it remains visible
under R-E11 and may not be treated as closed until a committed re-entry plan avoids the
self-referential last-touch requirement and the resulting exact tree passes every gate.

R6-A2 through R6-A6, Wave-4 dispositions, R-E09, R-J03, workflow promotion, Aggregate acceptance,
merge and post-merge evidence remain unchanged. This demotion does not authorize edits under
`projects/`, `learning/` or `studio/workflows/`, push, merge or PR-thread resolution.
`sdd-pipeline` remains experimental, default-disabled and execution-denied; PR #3 remains
`NOT READY TO MERGE`.

```finding-status-record-v1
{
  "schemaVersion": 1,
  "revision": 5,
  "recordType": "delta",
  "recordedDate": "2026-07-22",
  "ledgerVersion": "1.33.0",
  "statuses": [
    {"id":"R-E11","status":"IN_PROGRESS"}
  ],
  "inventoryCount": 131,
  "severityCounts": {
    "Critical": 8,
    "High": 32,
    "Medium": 52,
    "Low": 39
  },
  "statusCounts": {
    "COMPLETED": 82,
    "OPEN": 42,
    "DECIDED": 5,
    "IN_PROGRESS": 2,
    "DISPOSITIONED": 0
  }
}
```

## 44. 2026-07-22 R6-A1 non-self-referential R-E11 revision 6 accounting

Honesty demotion `4ce95a4ed2ce941ae2291dd1002b6c7f99bbb59a` preserved the failed
evidence-coverage attempt as revision 5 and returned only R-E11 to `IN_PROGRESS`. Committed plan
`f4ca59d274fffe8f1e49950d8bf796b95eda05d6` then defined a non-self-referential sequence without
weakening the mainline validator or exempting `docs/README.md` from branch evidence coverage.

On the clean demotion-and-plan tree, the complete governance suite reports 878 passed and 0 failed,
runtime reports `VALID=true` with 0 errors and 0 warnings, and BaseRef validation reports exactly
five consecutive valid revisions, 131 findings, fold 82/42/5/2/0 and `HISTORY_VALID=true`. These
results satisfy the pre-accounting gate in the committed plan. Revision 6 therefore changes only
R-E11 from `IN_PROGRESS` to `COMPLETED`; R-D07, R-E02, R-E08, R-H03, R-H04 and R-H20 remain
`COMPLETED`, and every other finding status remains unchanged.

This accounting commit keeps the dedicated R6-A1 note Draft with reconciliation Open and validation
scope Batch, and keeps its mainline index row Draft. The `docs/README.md` marker records revision 6
and fold 83/42/5/1/0 while its prose remains state-neutral. A later finalization may modify only the
dedicated note and its matching index row after this accounting commit's real hash exists. Every
exact-tree gate remains mandatory; any failure requires an immediate append-only demotion before
other work continues.

R6-A2 through R6-A6, Wave-4 dispositions, R-E09, R-J03, workflow promotion, Aggregate acceptance,
merge and post-merge evidence remain unchanged. This accounting does not authorize edits under
`projects/`, `learning/` or `studio/workflows/`, push, merge or PR-thread resolution.
`sdd-pipeline` remains experimental, default-disabled and execution-denied; PR #3 remains
`NOT READY TO MERGE`.

```finding-status-record-v1
{
  "schemaVersion": 1,
  "revision": 6,
  "recordType": "delta",
  "recordedDate": "2026-07-22",
  "ledgerVersion": "1.34.0",
  "statuses": [
    {"id":"R-E11","status":"COMPLETED"}
  ],
  "inventoryCount": 131,
  "severityCounts": {
    "Critical": 8,
    "High": 32,
    "Medium": 52,
    "Low": 39
  },
  "statusCounts": {
    "COMPLETED": 83,
    "OPEN": 42,
    "DECIDED": 5,
    "IN_PROGRESS": 1,
    "DISPOSITIONED": 0
  }
}
```

## 45. 2026-07-23 R6-A5 R-E13 trigger-authority registration

Committed remediation amendment `a45b7d33a59dd41d7765d29626bf43d2adb02cca` records the
owner-selected Choice A after R6-A5 preflight proved that the closed status-entry schema cannot
represent the exact re-entry trigger required by Sections 36.2 and 36.3. Treating an adjacent
Markdown table as sufficient would leave that condition outside the canonical `finding_status`
authority. The owner classifies the independent future-transition failure as new Medium R-E13
rather than reopening R-E11: revisions 1 through 6 contain no `DISPOSITIONED` entry, and their
existing schema, fold, index and history claims remain valid.

| ID | Severity | 2026-07-23 finding | Required disposition | Current status |
|---|---|---|---|---|
| R-E13 | Medium | The canonical finding-status entry contract permits only `id` and `status`, so it cannot carry or fail-closed validate the mandatory per-ID re-entry trigger for a `DISPOSITIONED` finding; a generic, missing or mismatched trigger cannot be rejected inside the authoritative record | Before the first Wave-4 disposition, add a conditionally required `reentryTrigger`, exact 35-ID Section 36.2 mapping validation, discriminating type/content/swap mutations and a revert-sensitive shared-runtime anchor while preserving revisions 1 through 7 | OPEN |

R-E13 raises the inventory to 132 and severity to Critical 8, High 32, Medium 53 and Low 39.
Revision 7 registers only R-E13 as `OPEN`; every prior status remains unchanged. The fold is
therefore 83 `COMPLETED`, 43 `OPEN`, 5 `DECIDED`, 1 `IN_PROGRESS` and 0 `DISPOSITIONED`.
Revisions 1 through 6 remain an immutable prefix.

This registration precedes implementation. It creates and indexes the dedicated A2-A5 Batch note
as Draft/Open and records R-E13 in the broad R6 note without promoting that note. It does not
implement or complete R-E13, account for the eleven A2 through A4 candidates, disposition a
Wave-4 item, complete R-E09 or R-J03, promote a workflow, edit a consumer, push, merge or resolve
PR threads. `sdd-pipeline` remains experimental, default-disabled and execution-denied; PR #3
remains `NOT READY TO MERGE`.

```finding-status-record-v1
{
  "schemaVersion": 1,
  "revision": 7,
  "recordType": "delta",
  "recordedDate": "2026-07-23",
  "ledgerVersion": "1.35.0",
  "statuses": [
    {"id":"R-E13","status":"OPEN"}
  ],
  "inventoryCount": 132,
  "severityCounts": {
    "Critical": 8,
    "High": 32,
    "Medium": 53,
    "Low": 39
  },
  "statusCounts": {
    "COMPLETED": 83,
    "OPEN": 43,
    "DECIDED": 5,
    "IN_PROGRESS": 1,
    "DISPOSITIONED": 0
  }
}
```

## 46. 2026-07-23 R6-A2 through A5 completion and trigger-bearing disposition accounting

Committed implementations now exist for R6-A2 at
`814cc6169e6d1bf9167ce91249dbd58ac548674d`, R6-A3 at
`be5fb24fd79a47d8f0db9f61be2a747d06b29088`, R6-A4 at
`32a58e653cc4b541db88b23ad4b90fd7b81007a5` and the R-E13 trigger contract at
`5e99ad9569cc0212212a0191193702c25f6af052`. The clean trigger-contract implementation tree
reports 986 governance tests passed with 0 failed and canonical runtime `VALID=true` with 0 errors
and 0 warnings. Revision-7 history validation is also valid with 132 findings and fold 83/43/5/1/0.

Revision 8 records only the twelve evidence-backed completions authorized by remediation-plan
Section 31. R-A21 and R-B18 are backed by R6-A2; R-B25, R-B26, R-C04 and R-C06 are backed by
R6-A3; R-G01, R-G03, R-G04, R-H06 and R-H09 are backed by R6-A4; R-E13 is backed by the
trigger-contract implementation. The resulting fold is 95 `COMPLETED`, 31 `OPEN`, 5 `DECIDED`,
1 `IN_PROGRESS` and 0 `DISPOSITIONED`.

Revision 9 then records exactly the thirty `OPEN` and five `DECIDED` Wave-4 findings authorized by
Sections 36.2 and 37.1 as `DISPOSITIONED`. Every entry carries its exact owner-approved
`reentryTrigger` inside the canonical machine record. `DISPOSITIONED` remains a conditional
deferral, not an implementation or risk-acceptance claim. Inventory and severity remain 132 and
Critical 8, High 32, Medium 53 and Low 39. The resulting fold is 95 `COMPLETED`, 1 `OPEN`,
0 `DECIDED`, 1 `IN_PROGRESS` and 35 `DISPOSITIONED`; R-E09 remains `IN_PROGRESS` and R-J03
remains `OPEN`.

The dedicated R6-A2 through A5 note remains Draft with reconciliation Open and validation scope
Batch until the accounting commit has a real hash and the later note-only finalization passes every
exact-tree gate. The broad R6 convergence note and canonical Wave-3 umbrella remain Draft/Open.
This accounting does not authorize workflow promotion, consumer edits, push, merge, post-merge
claims or PR-thread resolution. `sdd-pipeline` remains experimental, default-disabled and
execution-denied; PR #3 remains `NOT READY TO MERGE`.

```finding-status-record-v1
{
  "schemaVersion": 1,
  "revision": 8,
  "recordType": "delta",
  "recordedDate": "2026-07-23",
  "ledgerVersion": "1.36.0",
  "statuses": [
    {"id":"R-A21","status":"COMPLETED"},
    {"id":"R-B18","status":"COMPLETED"},
    {"id":"R-B25","status":"COMPLETED"},
    {"id":"R-B26","status":"COMPLETED"},
    {"id":"R-C04","status":"COMPLETED"},
    {"id":"R-C06","status":"COMPLETED"},
    {"id":"R-G01","status":"COMPLETED"},
    {"id":"R-G03","status":"COMPLETED"},
    {"id":"R-G04","status":"COMPLETED"},
    {"id":"R-H06","status":"COMPLETED"},
    {"id":"R-H09","status":"COMPLETED"},
    {"id":"R-E13","status":"COMPLETED"}
  ],
  "inventoryCount": 132,
  "severityCounts": {
    "Critical": 8,
    "High": 32,
    "Medium": 53,
    "Low": 39
  },
  "statusCounts": {
    "COMPLETED": 95,
    "OPEN": 31,
    "DECIDED": 5,
    "IN_PROGRESS": 1,
    "DISPOSITIONED": 0
  }
}
```

```finding-status-record-v1
{
  "schemaVersion": 1,
  "revision": 9,
  "recordType": "delta",
  "recordedDate": "2026-07-23",
  "ledgerVersion": "1.37.0",
  "statuses": [
    {"id":"R-A13","status":"DISPOSITIONED","reentryTrigger":"Before adding or materially expanding `mustContainAll` literal assertions, or before the next contract-invariant refactor"},
    {"id":"R-B23","status":"DISPOSITIONED","reentryTrigger":"Before any workflow promotion, execution authorization, or use of RunState/sidecar data as trusted evidence; deferral is valid only while `sdd-pipeline` stays experimental, default-disabled and execution-denied"},
    {"id":"R-F01","status":"DISPOSITIONED","reentryTrigger":"Before upstream adoption, Yuanxi pack implementation, or any renewed current-baseline claim; upstream release and CLI facts must be re-verified at that time"},
    {"id":"R-F02","status":"DISPOSITIONED","reentryTrigger":"Before upstream adoption, Yuanxi pack implementation, or any renewed current-baseline claim; upstream release and CLI facts must be re-verified at that time"},
    {"id":"R-F03","status":"DISPOSITIONED","reentryTrigger":"Before upstream adoption, Yuanxi pack implementation, or any renewed current-baseline claim; upstream release and CLI facts must be re-verified at that time"},
    {"id":"R-F05","status":"DISPOSITIONED","reentryTrigger":"Before upstream adoption, Yuanxi pack implementation, or any renewed current-baseline claim; upstream release and CLI facts must be re-verified at that time"},
    {"id":"R-G02","status":"DISPOSITIONED","reentryTrigger":"Before upstream adoption, Yuanxi pack implementation, or any renewed current-baseline claim; upstream release and CLI facts must be re-verified at that time"},
    {"id":"R-D08","status":"DISPOSITIONED","reentryTrigger":"Before the next change to agent source, Claude invocation guidance, discovery/version-agent surfaces or their generated mirrors"},
    {"id":"R-D09","status":"DISPOSITIONED","reentryTrigger":"Before the next change to agent source, Claude invocation guidance, discovery/version-agent surfaces or their generated mirrors"},
    {"id":"R-D10","status":"DISPOSITIONED","reentryTrigger":"Before the next change to agent source, Claude invocation guidance, discovery/version-agent surfaces or their generated mirrors"},
    {"id":"R-D11","status":"DISPOSITIONED","reentryTrigger":"Before the next change to agent source, Claude invocation guidance, discovery/version-agent surfaces or their generated mirrors"},
    {"id":"R-E01","status":"DISPOSITIONED","reentryTrigger":"Before the corresponding constitution classification, authority taxonomy, bootstrap wording or hook classification is changed again"},
    {"id":"R-E03","status":"DISPOSITIONED","reentryTrigger":"Before the corresponding constitution classification, authority taxonomy, bootstrap wording or hook classification is changed again"},
    {"id":"R-E04","status":"DISPOSITIONED","reentryTrigger":"Before the corresponding constitution classification, authority taxonomy, bootstrap wording or hook classification is changed again"},
    {"id":"R-E06","status":"DISPOSITIONED","reentryTrigger":"Before the corresponding constitution classification, authority taxonomy, bootstrap wording or hook classification is changed again"},
    {"id":"R-E12","status":"DISPOSITIONED","reentryTrigger":"Before the corresponding constitution classification, authority taxonomy, bootstrap wording or hook classification is changed again"},
    {"id":"R-G05","status":"DISPOSITIONED","reentryTrigger":"Before the affected document is reused as current guidance, supplied to an LLM for execution, or materially revised"},
    {"id":"R-G07","status":"DISPOSITIONED","reentryTrigger":"Before the affected document is reused as current guidance, supplied to an LLM for execution, or materially revised"},
    {"id":"R-G08","status":"DISPOSITIONED","reentryTrigger":"Before the affected document is reused as current guidance, supplied to an LLM for execution, or materially revised"},
    {"id":"R-G09","status":"DISPOSITIONED","reentryTrigger":"Before the affected document is reused as current guidance, supplied to an LLM for execution, or materially revised"},
    {"id":"R-G11","status":"DISPOSITIONED","reentryTrigger":"Before the affected document is reused as current guidance, supplied to an LLM for execution, or materially revised"},
    {"id":"R-G12","status":"DISPOSITIONED","reentryTrigger":"Before the affected document is reused as current guidance, supplied to an LLM for execution, or materially revised"},
    {"id":"R-H07","status":"DISPOSITIONED","reentryTrigger":"Before the affected root asset, reserved directory or language policy is presented as a current supported surface"},
    {"id":"R-H14","status":"DISPOSITIONED","reentryTrigger":"Before the affected root asset, reserved directory or language policy is presented as a current supported surface"},
    {"id":"R-H18","status":"DISPOSITIONED","reentryTrigger":"Before the affected root asset, reserved directory or language policy is presented as a current supported surface"},
    {"id":"R-I01","status":"DISPOSITIONED","reentryTrigger":"Before the shared-runtime upgrade scope is expanded or changed"},
    {"id":"R-I02","status":"DISPOSITIONED","reentryTrigger":"Before adapter templates or the bootstrap generator are changed"},
    {"id":"R-I04","status":"DISPOSITIONED","reentryTrigger":"Before a project claims complete prompt or knowledge-capture closure"},
    {"id":"R-I05","status":"DISPOSITIONED","reentryTrigger":"Before a project claims complete prompt or knowledge-capture closure"},
    {"id":"R-I09","status":"DISPOSITIONED","reentryTrigger":"Before the extension operator surface is documented or used externally"},
    {"id":"R-D06","status":"DISPOSITIONED","reentryTrigger":"Before agent reseed or a model lifecycle, availability, cost or policy change"},
    {"id":"R-D12","status":"DISPOSITIONED","reentryTrigger":"Only after a separate owner-authorized consumer exception and a decision between project-local Copilot overlay and Claude-only support; current `projects/` and `learning/` exclusion prevents implementation"},
    {"id":"R-F04","status":"DISPOSITIONED","reentryTrigger":"Before agent-skill export/install is reused, advertised or repopulated"},
    {"id":"R-H15","status":"DISPOSITIONED","reentryTrigger":"Before agent-skill export/install is reused, advertised or repopulated"},
    {"id":"R-I03","status":"DISPOSITIONED","reentryTrigger":"Before route-aware auto-scaffold work or workflow promotion"}
  ],
  "inventoryCount": 132,
  "severityCounts": {
    "Critical": 8,
    "High": 32,
    "Medium": 53,
    "Low": 39
  },
  "statusCounts": {
    "COMPLETED": 95,
    "OPEN": 1,
    "DECIDED": 0,
    "IN_PROGRESS": 1,
    "DISPOSITIONED": 35
  }
}
```

## 47. 2026-07-26 R-A23 fixture output decoding registration

Committed wave-3 remediation-plan Section 38 amendment
`f428029467f3ba214ee6eef1eb6b4d5983f28aed` authorizes one new finding ID only if the elevated
fixture failure reproduces in a canonical environment. On 2026-07-26 the owner reproduced it in a
directly executed pwsh 7.5.4 terminal whose console code page is 950 (Big5): the bad-state test
`rejects additive stale phase path metadata and Claude authority guidance` fails because
`Invoke-RuntimeAuditFixture` decodes captured child-audit stdout with the parent console encoding
while the child pwsh writes UTF-8. Non-ASCII contract text corrupts, and one corrupted sequence
yields an unescaped quote that makes the captured JSON unparseable. The child audit itself
behaves correctly, reporting the expected ten governed failures with exit 1. This is therefore a
real fixture defect, not a sandbox artifact.

| ID | Severity | 2026-07-26 finding | Required disposition | Current status |
|---|---|---|---|---|
| R-A23 | Medium | `Invoke-RuntimeAuditFixture` in `studio/tests/check-speckit-runtime.Tests.ps1` captures child audit output through the parent console code page, so on a CP950/Big5 host the child's UTF-8 JSON corrupts and can fail `ConvertFrom-Json` entirely, breaking an otherwise-correct bad-state test | Decode fixture-captured child output as UTF-8 independent of the host console code page, with an old-fails/new-passes discriminating test that forces a CP950 parent console against non-ASCII child JSON, while preserving revisions 1 through 9 | OPEN |

R-A23 raises the inventory to 133 and severity to Critical 8, High 32, Medium 54 and Low 39.
Revision 10 registers only R-A23 as `OPEN`; every prior status remains unchanged. The fold is
therefore 95 `COMPLETED`, 2 `OPEN`, 0 `DECIDED`, 1 `IN_PROGRESS` and 35 `DISPOSITIONED`.
Revisions 1 through 9 remain an immutable prefix.

This registration precedes implementation. It does not repair the fixture, complete R-A23,
change R-E09 or R-J03, disposition or reopen any Wave-4 item, promote a workflow, edit a
consumer, push, merge or resolve PR threads. `sdd-pipeline` remains experimental,
default-disabled and execution-denied; PR #3 remains `NOT READY TO MERGE`.

```finding-status-record-v1
{
  "schemaVersion": 1,
  "revision": 10,
  "recordType": "delta",
  "recordedDate": "2026-07-26",
  "ledgerVersion": "1.38.0",
  "statuses": [
    {"id":"R-A23","status":"OPEN"}
  ],
  "inventoryCount": 133,
  "severityCounts": {
    "Critical": 8,
    "High": 32,
    "Medium": 54,
    "Low": 39
  },
  "statusCounts": {
    "COMPLETED": 95,
    "OPEN": 2,
    "DECIDED": 0,
    "IN_PROGRESS": 1,
    "DISPOSITIONED": 35
  }
}
```

## 48. 2026-07-26 R-A23 completion accounting

Repair commit `f8d064c81b592e1c42966a68db6325f1685db089` replaces the console-encoding capture in
`Invoke-RuntimeAuditFixture` with a process-level UTF-8 decoder and adds the discriminating test
`preserves non-ASCII child audit output when the parent console uses code page 950`. The
discriminating evidence is complete in both directions: the new test grafted onto the pre-repair
helper in a clean worktree at registration commit `3393d9bb5784d9a4e0a2812bde2efbc264b31446`
fails with the same UTF-8-as-Big5 corruption signature observed in the canonical reproduction,
and the same test passes against the repaired helper. The owner then re-ran both the previously
failing bad-state test and the new test in the same directly executed canonical pwsh 7.5.4
terminal with a CP950 console; both pass with 98 tests discovered and zero failures.

Revision 11 records only R-A23 as `COMPLETED`. The fold becomes 96 `COMPLETED`, 1 `OPEN`,
0 `DECIDED`, 1 `IN_PROGRESS` and 35 `DISPOSITIONED` across 133 findings; the remaining `OPEN`
finding is R-J03 and the remaining `IN_PROGRESS` finding is R-E09, both terminal merge items.

The same Section 38 batch also lands CI calibration
`742a7fba7cbf088195211f0e35432c4734858b78` (coverage limited to schedule and dispatch, timeout
calibrated to 120 minutes, with a revert-sensitive workflow assertion) and README truthfulness
`b63dff89fda341c3d291e48a57403458d5033deb` (consumer-directory disclosure with a revert-sensitive
assertion). Per the owner ruling in plan Section 38, these are batch-scoped delivery-surface
repairs and change no finding status.

This accounting does not complete R-E09 or R-J03, does not make any note Ready, and does not
authorize push, merge, workflow promotion or PR-thread resolution. `sdd-pipeline` remains
experimental, default-disabled and execution-denied; PR #3 remains `NOT READY TO MERGE`.

```finding-status-record-v1
{
  "schemaVersion": 1,
  "revision": 11,
  "recordType": "delta",
  "recordedDate": "2026-07-26",
  "ledgerVersion": "1.39.0",
  "statuses": [
    {"id":"R-A23","status":"COMPLETED"}
  ],
  "inventoryCount": 133,
  "severityCounts": {
    "Critical": 8,
    "High": 32,
    "Medium": 54,
    "Low": 39
  },
  "statusCounts": {
    "COMPLETED": 96,
    "OPEN": 1,
    "DECIDED": 0,
    "IN_PROGRESS": 1,
    "DISPOSITIONED": 35
  }
}
```
