---
title: "SDD-WorkSpace 共享層修復總清單與全面更新計畫（2026-07-12）"
version: "1.2.0"
date: "2026-07-12"
last_updated: "2026-07-13"
language: "zh-TW"
owner: "元熙"
status: "repair-in-progress"
authority: "informational"
branch: "feature/wave-3-security-and-workflows"
base_commit: "c6ee1f1 (main)"
head_commit: "60768f3"
scope: "Workspace 共享層（studio/、.github/、.claude/、.githooks/、根目錄 adapter 與文件、docs/ 治理文件、遠端設定）。原則上排除 projects/ 與 learning/ 內部 consumer drift；R-D12 為受控例外，只允許完成 shared agent 安全遷移所需的 project-local runtime 檢查。"
analysis_method: "兩輪多 agent 調查合併：第一輪 32 agents（10 個子系統深讀 + 機器語義稽核 + 18 條論斷對抗驗證，16 確認 2 推翻）；第二輪 4 agents（docs 逐檔盤點、根目錄與設定衛生、studio 層盤點、完整性批判）；第三輪於 2026-07-13 由 Codex 主代理加 3 個獨立驗證代理逐項複核 owner decisions、本機證據與官方外部來源。第三輪以 section-bounded parser 重算第 3 節 findings 與嚴重度，作為取代初版錯誤摘要的 canonical count。"
purpose: "以環境修復角度列出共享層全部已知問題（單一總帳），記錄 18 項 owner 裁定，並排定風險優先的分批更新順序。本檔同時作為 open-findings ledger 的起始版本。"
related_documents:
  - "docs/sdd-workspace-wave-3-governance-review-2026-07-12_zhTW.md"
  - "docs/sdd-workspace-deep-analysis-and-career-value-2026-07-12_zhTW.md"
  - "docs/sdd-workspace-deep-review-2026-07-08_zhTW.md"
---

# SDD-WorkSpace 共享層修復總清單與全面更新計畫（2026-07-12）

## 0. 執行摘要

第 3 節在 v1.1.0 逐列機器重算後共有 109 條 findings；R0 staged-snapshot 驗收再發現並新增 R-A14，因此目前為 110 條，編為 R-A01 至 R-A14、其餘區域至 R-J03。現況分佈：Critical 6、High 20、Medium 46、Low 38。初版摘要所寫 95 條與 7/17/40/31 分佈是計數錯誤，已在 v1.1.0 修正；R-A14 則是後續實作中有獨立回歸證據的新 finding。

2026-07-13 owner decision review 已完成。第 6 節以 18 個「邏輯決策」記錄裁定；原表實際為 17 列、19 個 finding ID，其中 R-F04/R-H15 是同一能力鏈，R-I07/R-I08 則拆成兩個獨立清理決策。所有裁定均已標明執行時序與驗收邊界。

四個結構性重點：

1. 最高風險不在本機而在遠端：main 分支無任何 branch protection，mainline-note 與 hook 治理只存在本機，`--no-verify` 或未裝 hook 的 clone 可直推 main 繞過全部治理（R-J01）。
2. 驗證層自身有兩個實 bug（`$warnings` 假綠、workflow registry invalid 不升格 failure）加一個環境地雷（PS 5.1 parser error），「唯一機器驗收面」需要先自我修復（R-A01、R-A02、R-A05）。
3. workflow engine 的 13 條 GOV findings 全部 open，catalog 卻仍標 approved/core/default-enabled；修復前先降級是一行可完成的止血（R-B09）。
4. 「很久沒更新」的實體是三群：docs/ 的 2026-03 至 05 執行基準文件（yuanxi pack、0308upstreams、governance-status 台帳）、上游對齊面（baseline 停 2026-03-06、上游已 v0.12.11），以及一批未實際採用或只有形式消費的閒置資產（0 份真實 change manifest、0 個已產出/安裝 skill pack、空 feature-packs/studio-tools/prompts 目錄）。

建議按第 5 節的 7 個風險優先批次執行。完整執行前四批 R0 至 R3 粗估 11 至 18 人天；目前 110 條完整收斂粗估仍為 21 至 35 人天。每批以 `check-speckit-runtime.ps1 -Json` ERROR_COUNT=0、Pester 全綠、該批新增 negative tests 與批次專屬驗收條件收尾，並依憲法補 mainline note。工期是重新估算區間，不是承諾值；R3 至 R6 在實作時仍須依當下證據調整。

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
| R6 Fresh-fixture 端到端驗收、重新 promotion 與合併 | 以全新 fixture 完整跑七階段含 ECI re-entry、非 READY routes、reject/recovery、implement completion；關閉 wave-3 review Gates；只有全部通過才重新 promotion workflow；回填 notes/ledger/commits；合併 main 後重跑同一套 | R-B09、R-E09、R-E11、R-J03 | 目前 110 條 ledger 各有 completed commit 或 owner-approved disposition；wave-3 9 個 P1 全關；fresh fixture e2e 有保存證據；main 合併後 audit/Pester/negative/e2e 全綠 | 2-4 天 |

依賴備註：

1. R0 必須先完成 R-H02，再加入 R-H01 的 MIT/NOTICE。
2. R1 的 CI status check 必須先存在且通過，才能在 GitHub 啟用要求該 check 的 protection/ruleset。
3. R-B09 的降級要維持到 R6；不得因 unit tests 綠就提前重新 promotion。
4. R-B16 的 gitignore 必須跟隨 R-B06 的最終 relocation，不在舊路徑先做永久政策。
5. R-G06 與 R-E05 必須原子處理：移除 manifest presence 面時，同批建立 mainline-note reconciliation 與 merge CI。
6. R-D12 在 R3 只可建立安全遷移前提；若 Copilot overlay 尚未完成，temporary allowlist 必須保留到 R5，不能先刪 shared agent。
7. 前四批 R0 至 R3 的完整工作量粗估 11 至 18 人天；目前 110 條全量收斂粗估仍為 21 至 35 人天。若只挑 Critical/High 子集，必須另做 scope cut，不得把各批完整工期直接相加後仍沿用較小數字。
8. R-E09 在 R5 處理既有 Ready/Draft notes 的歷史帳務與失真修復；R6 只做本輪 final commit/PR/merge hash 回填與合併後驗證。兩批不得把同一工作重複計為完成。

## 6. Owner 已裁定的 18 項決策

Owner 於 2026-07-13 完成裁定。以下是 18 個邏輯決策；原始盤點的合併列與 finding ID 數不等同於決策數。狀態 `DECIDED` 只代表方向已定，不代表修復已實作。

| # | ID | 最終裁定 | 執行邊界 / 驗收重點 | 狀態 |
|---:|---|---|---|---|
| 1 | R-H01 | 公開並採 MIT | 先完成 R-H02 與第三方來源盤點；再加 root LICENSE、README License 段、`THIRD_PARTY_NOTICES.md`，不得用 root MIT 覆蓋無權授權的內容 | IN_PROGRESS |
| 2 | R-H02 | 完整移除 vendored `github-copilot-configs` | 真正移除 tracked snapshot 與舊工作副本；未來只從具明確授權的來源選取、pin commit/hash、保留 LICENSE/manifest | IN_PROGRESS |
| 3 | R-H05 | 刪除 `bone.ini` 與空 `studio/tools/` | 不搬 archive；確認無其他 live structure references；Git history 保留史料 | IN_PROGRESS |
| 4 | R-H08 | 退役 `setup-copilot-agents.ps1` | 與 R-H02 同批移除 README 入口；不保留可對 user home 做無治理覆寫的舊 installer | IN_PROGRESS |
| 5 | R-H13 | 刪除空 `archive/` 預留結構 | 移除 README / WORKSPACE_STRUCTURE 宣稱；未來若重建，先以 README 定義保存規則 | IN_PROGRESS |
| 6 | R-H17 | 刪除漂移繁中 agent 目錄 | 不因非 ASCII 名稱而刪；理由是治理內容矛盾。未來翻譯需有來源 commit、banner 與 parity | IN_PROGRESS |
| 7 | R-G06 | 退役 change-manifest 鏈 | 將 impact reconciliation 併入 mainline note，並由 merge CI 強制；不補裝飾性首份 manifest | DECIDED |
| 8 | R-G10 | 直接刪除 `basic-prompt.txt` | 不把低資訊內容搬入 `studio/prompts/`；prompts 只從已驗證 candidates 提取 | IN_PROGRESS |
| 9 | R-F04 / R-H15 | 退役 agent-skills export/install capability | 連同 scripts、upgrade caller、audit、contract、tests、docs 與空輸出目錄一起收斂；未來需要時重新立 spec | DECIDED |
| 10 | R-B16 | RunState 為本機暫態 | 與 R-B06 同批 relocation 後再 ignore；修正 POLICY/README；跨機需求改走顯式 checkpoint export/import | DECIDED |
| 11 | R-D06 | 移除 blanket exact model pin，預設 inherit | 建 per-runtime 單一 policy；audit 驗 policy/parity，不鎖某一代 model literal；高風險 override 需有量測證據 | DECIDED |
| 12 | R-D07 | 以 artifact 類型明文化狹義 prompt 例外 | Runtime prompt source/mirror 可少量使用語義符號；SDD outputs 與治理文件仍禁止；裝飾性符號漸進清理 | DECIDED |
| 13 | R-D12 | 將專案 reviewer 移出 shared，但先解決 Copilot overlay | Claude project-local 已存在；Copilot junction 未解前不得破壞功能。完成 overlay 或裁定 Claude-only 後再刪 shared source/mirror/contract entry | DECIDED |
| 14 | R-I03 | 保留模板並接上 route-aware consumer | Readiness 每次只 scaffold 所選 route 的最小 packet；ECI scaffold 必需四件；validator 檢查 placeholders/必填欄 | DECIDED |
| 15 | R-I07 | 刪除本機空 `feature-packs/` | 無 repo 變更需求；未來需要先立 spec | IN_PROGRESS |
| 16 | R-I08 | 刪除本機空 `pain-points/`，保留 optional 定義 | 不加 `.gitkeep`；用到再建立 | IN_PROGRESS |
| 17 | R-E05 | 保留 `must_update`，在 merge/CI 才 blocking | Commit-time 保持 advisory；PR/merge 以 branch aggregate reconciliation 阻擋，避免逐 commit false positive | DECIDED |
| 18 | R-J02 | 未來公開工作使用 GitHub noreply，不重寫歷史 | 使用 workspace conditional include 或適當 global policy 涵蓋 nested repos；啟用 GitHub privacy / push blocking | IN_PROGRESS |

## 7. 已知限制

1. GitHub 側修復（R-J01 protection/ruleset、R-J02 account email privacy/push blocking）需在 GitHub UI 或以 gh api 帶權限執行；Git noreply conditional config 可在本地完成，但不能替代帳戶設定。
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

## 11. 2026-07-13 R0 執行增補

本節是第 3 節對應 findings 的日期化狀態記錄，不改寫原始問題證據。R0 實作已在工作樹
完成，尚待完整驗證與 implementation commit，因此本表先標 `IN_PROGRESS`；commit 後
必須以實際 hash 更新。

| ID | 目前狀態 | 已落地處置 | 驗收證據 / 尚待事項 |
|---|---|---|---|
| R-G13 | IN_PROGRESS | 四份 workspace 分析與索引已納入本批 | 待 commit hash |
| R-A14 | IN_PROGRESS | removed nested source root 不再被誤當成仍存在的 adapter project；project root 尚存在時仍照常驗證 | removed-root regression test 與 contract invariant 已加；待 staged hook 與 commit hash |
| R-B09 | IN_PROGRESS | catalog 已降為 experimental、非 approved、非 default-enabled，approval 欄位清空 | listing/schema negative test 已加；runner authorization 仍是 R-B05 的 R2 範圍，不在本 finding 冒充關閉 |
| R-H01 | IN_PROGRESS | root MIT、README License 段與 conservative `THIRD_PARTY_NOTICES.md` 已建立 | Spec Kit notice 保留完整 MIT；待 commit hash |
| R-H02 | IN_PROGRESS | 392-file tracked vendor snapshot 已完整移除，來源取證已留存，原路徑加入 external-intake ignore | 391/392 blobs 對應來源 commit `e5969f1cc89a60c931049bd41dce55eaa8e6037f`；唯一差異為來源工作設定檔；待 commit hash |
| R-H05 | IN_PROGRESS | `bone.ini` 與空 `studio/tools/` 已刪除 | 已確認無 live structure reference；待 commit hash |
| R-H08 | IN_PROGRESS | 舊 installer 與 README 入口已移除 | 待 commit hash |
| R-H11 | IN_PROGRESS | root 與 project template ignore 加固；pre-commit 對 active protected destinations fail-closed，且不列印檔名 | privacy suite 63/63；full governance 265 passed、0 failed、1 expected skip；待 commit hash |
| R-H12 | IN_PROGRESS | 只刪除 root ignored `testResults.xml` 殘留 | `studio/tests/_artifacts/` 保留；本機處置無 tracked deletion hash，隨批次 note 留證 |
| R-H13 | IN_PROGRESS | 本機空 `archive/` 已刪除，README 與 WORKSPACE_STRUCTURE 列項已移除 | 待 commit hash |
| R-H17 | IN_PROGRESS | 漂移的單一繁中 agent 與目錄已刪除 | canonical agents 未變；待 commit hash |
| R-G10 | IN_PROGRESS | `docs/basic-prompt.txt` 已刪除且未搬入 prompts | 待 commit hash |
| R-I07 | IN_PROGRESS | 本機空 `studio/templates/feature-packs/` 已刪除 | 無 tracked directory；隨批次 note 留證 |
| R-I08 | IN_PROGRESS | 本機空 `studio/knowledge-base/pain-points/` 已刪除 | 憲法 optional 定義保留；隨批次 note 留證 |
| R-J02 | IN_PROGRESS | workspace-scoped conditional include 已套用 GitHub noreply，7/7 discovered repos 驗證通過；未重寫歷史、未覆寫既有 global identity | GitHub account privacy 與 push-blocking toggle 尚需 owner 在帳戶設定完成 |

R0 mainline note：`docs/mainline-updates/2026-07-13-r0-containment-and-source-cleanup.md`。
