---
title: "SDD-WorkSpace Wave 3 Re-review 後續修復計畫（2026-07-14）"
version: "1.1.0"
date: "2026-07-14"
last_updated: "2026-07-18"
language: "zh-TW"
status: "plan"
authority: "informational"
branch: "feature/wave-3-security-and-workflows"
base_commit: "c6ee1f1 (main)"
head_commit: "04e4287"
source_review: "docs/sdd-workspace-wave-3-governance-review-2026-07-14_zhTW.md"
open_findings_ledger: "docs/sdd-workspace-repair-inventory-and-update-plan-2026-07-12_zhTW.md"
scope: "以 2026-07-14 治理 re-review 的 12 條 RVR findings 為輸入，制定可合併回 main 的修復批次。排除 projects/ 與 learning/ consumer 內部 drift；worktree/init/template 等 shared-layer 腳本行為在範圍內。"
purpose: "把 12 條 RVR findings 對映到單一 open-findings ledger、標出哪些推翻既有 Ready/Completed 宣稱，並排定可稽核、fail-closed、最終能乾淨合併 main 的批次順序。"
---

# SDD-WorkSpace Wave 3 Re-review 後續修復計畫（2026-07-14）

## 0. 與原始目的的對齊

原始目的有兩層：(1) 這個 workspace 是求職武器，要能對面試方展示「機器驗證的 SDD 治理閉環」；
(2) 希望共享層有一次全面、乾淨、最新最好的更新，最終乾淨合併回 `main`。

本次 re-review 的結論「NOT READY TO MERGE」與這個目的一致，而不是相反：一個宣稱以治理閉環
為賣點的 repo，如果 `completed` 不等於真正完成、綠燈可被假證據通過，對面試方反而是負分。
因此修復方向就是把 12 條 findings 收斂到「綠燈能證明治理宣稱」，讓分支能誠實合併 `main`
（ledger 的 R-J03 / 批次 R8 終點）。

**必須先處理的誠實性問題**：本計畫作者在 2026-07-14 的 R2 批次把 R-B02、R-B05 標為
`COMPLETED`，並把兩份 mainline note 標為 `Ready`。RVR-01 與 RVR-03 經本地反例復現，證明這兩項
closure 不完整。依憲法 Surface Truthfulness 與 ledger 維護規則（第 8 節），這些宣稱必須先降級
還原，才能繼續。這是本計畫的第一批（R2.1），不是可選項。

## 1. Findings 三聯表（RVR to Ledger to 批次）

| RVR | 嚴重度 | 新/已知 | 復現狀態 | 對映 ledger | 是否推翻既有宣稱 | 排入批次 |
|---|---|---|---|---|---|---|
| RVR-01 假完成：刪 task inventory 仍完成 | Critical | 新（R-B02 subcase） | 本地已復現（gut tasks.md 後 completed） | 重開 R-B02，新增 R-B19 | 是，推翻 R2 note 的 false-completion closure | R2.1 + RB-1 |
| RVR-02 direct Implement 跳 mandatory gates | Critical | 已知 | 報告確認；結構已核（agent 首步為 check-prerequisites） | R-D02、R-B08 | 部分（analyze-gate note 已為 Draft，但入口仍 active） | RB-1 |
| RVR-03 runner authorization fail-open | Critical | 新（R-B05 subcase） | `[bool]'false'`=`True` 已復現；missing-state 走 default 已核 | 重開 R-B05，新增 R-B20 | 是，推翻 R2 note 的 runner fail-closed closure | R2.1 + RB-1 |
| RVR-04 RunState 未綁定受審 graph | High | 新 | 結構已核（同版 graph 已被改 4 次） | 新增 R-B21 | 部分（R-B05 只綁 id/version，非內容） | RB-2 |
| RVR-05 mainline gate 未封閉 shared paths | High | 新 | 已核（17/39 腳本入 gate；validator 用 --name-only） | 新增 R-A17 | 是，推翻 R1 hosted-enforcement 完整 closure | RB-3 |
| RVR-06 Ready-note evidence 只驗字串 | High | 新 | 報告確認（deadbee 可通過） | 新增 R-A18（與 R-A09 相鄰） | 是，弱化所有 Ready 帳務可信度 | RB-3 |
| RVR-07 ECI 無 full dossier / re-entry / exactly-one | High | 已知+新 subcase | 報告確認 | R-B07 + 新增 R-B22 | 否（R-B07 本就 open 留 R3） | RB-2 |
| RVR-08 extension trust/scope/mutation/mirror | High | 已知+新 subcase | 報告確認 | R-C01/02/05/07 + 新增 R-C08 | 否（C 系列本就留 R4） | RB-4 |
| RVR-09 worktree/junction isolation | High | 新 | 結構已核（worktree 共用 repo config；template 不忽略 junction 內容） | 新增 R-A19 | 是，與 WORKSPACE_STRUCTURE 宣稱矛盾 | RB-4 |
| RVR-10 agent source/mirror/文字規則漂移 | High | 已知+獨立確認 | 報告確認（清空 mirror 仍 VALID） | R-D01、R-D04、R-D05 | 否（D 系列本就留 R3） | RB-5 |
| RVR-11 upgrade 非原子 | High | 新 | 報告確認 | 新增 R-F06 | 否 | RB-4 |
| RVR-12 無 canonical SDD evidence + 主 note Draft/TBD | High | 已知治理缺口 | 事實陳述 | R-E07、R-E09 | 否（本就是 R5/R6 終點條件） | RB-5 + R6 |

新增 ledger IDs：R-A17、R-A18、R-A19、R-B19、R-B20、R-B21、R-B22、R-C08、R-F06（共 9 條，
ledger 由 114 增至 123）。R-B02、R-B05 由 COMPLETED 改回 IN_PROGRESS 並附 subcase 說明。

## 2. 批次計畫

原則不變：每批只處理一個可獨立驗收的風險主題；每批以「舊實作會失敗、新實作通過」的 negative
tests、canonical audit `ERROR_COUNT=0`、完整 Pester 全綠、`git diff --check`、branch mainline
reconciliation、對應 Ready note 的真實 commit evidence 收尾；若後續證據推翻 Ready，依 template
降回 Draft。批次順序遵循 re-review 第 10 節：先止血假完成/繞道/授權，再修執行身分與 routing，
再修合併證據本身，最後才收斂邊界與帳務。

### R2.1 誠實性還原（約 0.5 天，先做）

| 動作 | 內容 |
|---|---|
| 降級 note | `2026-07-14-r2-workflow-engine-integrity.md` 與 `2026-07-14-r2-verification-hardening.md` 中被 RVR-01/03 推翻的 closure 宣稱改回 Draft 或加「partial, reopened by RVR-01/03」限定 |
| 重開 ledger | R-B02、R-B05 改 IN_PROGRESS；新增 R-B19、R-B20 記錄具體 subcase 與反例 |
| 登錄 findings | 把 RVR-01 至 RVR-12 對映列入 ledger 第 3 節與新的執行增補節 |
| 補 mainline note | 一份 note 記錄本次降級與重開，維持帳務可追溯 |
| 驗收 | audit 綠、notes validator 綠、docs 索引更新；不動任何 runtime 程式碼 |

此批只還原真相、不修 bug，確保後續每一批都是在誠實基線上前進。

### RB-1 止血：假完成、mandatory bypass、授權 fail-open（Critical，約 2.5 至 3.5 天）

涵蓋 RVR-01/R-B19、RVR-02/R-D02+R-B08、RVR-03/R-B20。

- 終端 Implement step 於首次抵達時保存 baseline canonical task-ID 集合，完成條件改為「所有
  baseline task ID 仍存在且全部勾選」，而非「檔案內找不到 pending regex」。新增 negative tests：
  刪 task、改 task ID、破壞 canonical line format、以非 task 文字取代整份文件、空白化。
- `/speckit.implement` 第一個動作改為呼叫不可繞過的 `setup-implement.ps1` gate；gate 必須要求
  readiness assessment、必要時 ECI authorization、Analyze 的 machine-readable result 與 intent
  obligations。`validate-feature-structure.ps1` 在 readiness/ECI 目錄缺失時 fail-closed，不再只在
  已存在時才驗。定義單一 machine-readable analyze artifact 或 deterministic 轉錄，把 agent output
  綁到 gate input。
- runner 共用 `catalog.schema.json` / `state.schema.json` 做 `Test-Json`；`defaultEnabled` /
  `enabled` 採嚴格布林解析（拒絕字串 `"false"` 被 cast 成 `True`）；`state.json` 缺失時依
  fail-closed policy 拒絕而非沿用 default。與 `list-workflows.ps1` 使用同一判準。

批次專屬閘門：上述五類 tampering 在舊碼通過、新碼被擋；direct `/speckit.implement` 無法繞
readiness/ECI/Analyze；string-boolean、missing-state、wrong-type、null 全部 denied。

### RB-2 執行身分與 SDD routing 可稽核（High，約 2 至 3 天）

涵蓋 RVR-04/R-B21、RVR-07/R-B07+R-B22。

- workflow approval 與 RunState 同時保存 workflow.yml 的 content digest；resume 遇 graph-hash
  mismatch 必須拒絕或要求顯式 migration/restart，不再形成新舊 graph 混合的 hybrid run。
- pipeline ECI step 驗四件 dossier（`eci-assessment.md`、`source-manifest.md`、`adoption-record.md`、
  `authorization-record.md`）；`READY_FOR_MAINLINE_IMPLEMENTATION` 後 graph 進入真正的第二個
  Readiness 評估再依最新 primary status routing。field parser 對同一文件多個矛盾 status 依 exactly-one
  規則 fail-closed，而非取行序第一個。`validate-feature-structure.ps1` 不論 status 是否被手改，缺
  dossier 一律擋。

批次專屬閘門：同版 graph 內容變更後 resume 被擋；八種 readiness status 與三種 ECI outcome 都有
routing tests；矛盾 status fixture 被拒。

### RB-3 合併證據完整性（High，約 1.5 至 2.5 天，需先於後續任何 Ready 宣稱）

涵蓋 RVR-05/R-A17、RVR-06/R-A18。此批刻意排在前段，避免「修復本身再以假綠合併」。

- `sharedGatePaths` 由不完整單檔 allowlist 改為 category-complete path rules，覆蓋
  `studio/scripts/powershell/**`、`.githooks/**`、`studio/extensions/**`。branch diff 改用
  `--name-status` 並保留 rename 的 old + new 路徑，使 governed source 被 rename 到 gate 外也會被
  偵測。測試 fixture 對齊 production contract，不再用理想化整層規則遮蔽 production drift。
- Ready-note validator 驗：commit object 存在且屬於本次 branch diff、PR reference 屬於正確
  repository、required sections（scope、impact、validation）齊備、evidence 覆蓋 branch diff。主
  Wave-3 note 若仍 Draft/TBD，不得由其他小 note 讓整批 aggregate diff 通過 `-RequireReady`。

批次專屬閘門：單獨改 add-extension / 漏列 shared script / rename governed doc 到 gate 外，
不加 note 都會被擋；deadbee 等不存在 commit、跨 repo PR、缺 section 的 note 被拒。

### RB-4 extension、consumer、upgrade 邊界收斂（High，約 3 至 4 天）

涵蓋 RVR-08/R-C08、RVR-09/R-A19、RVR-11/R-F06。

- extension entry point 以 normalized full-path 驗證仍位於宣告 scope，export target 再 assert 位於
  `$scopeDir`；`add-extension.ps1` 改 validate-before-mutate、失敗 rollback；approval 綁定實際 bytes
  （content hash），replacement 不沿用舊 approvedBy/trust；`export-extensions.ps1 -OutputDir` 加
  workspace boundary；disable/remove extension 使既有 merged mirror 失效。
- `new-project-worktree.ps1` 改用 worktree-safe hooks 設定，不改寫 source 與其他 worktree 的
  `core.hooksPath`；fresh consumer `git status` 不得展開 shared junction 內容（template ignore 或
  等效機制），並與 `WORKSPACE_STRUCTURE.md` 宣稱一致。此為 shared-layer 腳本行為，不涉入具體
  consumer 專案內部 drift。
- `upgrade-studio-runtime.ps1` 改 staging + audit + atomic promote，或在 apply 失敗時可證明 rollback
  完成，恢復 fail-closed 與 authority update order。

批次專屬閘門：cross-scope target、force replacement、schema violation、workspace 外 export 全被擋；
extension state change 使 mirror 失效；不同深度 worktree 建立後 source hooks 不變；upgrade apply
失敗後 canonical runtime 可證明保持原狀或完成 rollback。

### RB-5 agent/authority/process 真實性（High，約 2 至 3 天）

涵蓋 RVR-10/R-D01+R-D04+R-D05、RVR-12/R-E07+R-E09。

- 修 Specify agent 前後矛盾（marker 數量與臆測規則、完成後可直接進 readiness）；Claude mirror
  parity 改 deterministic regeneration 或 normalized body diff 納入 canonical audit（清空 mirror 內容
  必須變紅）；tool mapping 遇未知 tool 改 fail-loud，不再回空陣列造成較寬預設權限。
- 在憲法明文化 workspace governance repo 的 self-application 雙軌例外（R-E07），或為本分支補
  canonical SDD evidence；主 Wave-3 note 在 fresh-fixture E2E 完成前維持 Draft；R-E09 帳務對齊。

批次專屬閘門：mirror 內容審計會抓到 body 漂移；tool mapping 失敗顯式報錯；憲法或 evidence
擇一閉合且無 authority 矛盾。

### R6 終點：fresh-fixture E2E + 合併 main（沿用原 ledger R6，約 2 至 4 天）

以全新 fixture 完整跑七階段（含 ECI re-entry、非 READY routes、reject/restart、terminal completion），
保存 evidence；關閉 re-review 第 9.2 節全部 12 項 minimum gates 與 wave-3 review Gates；只有全部
通過才重新 promotion `sdd-pipeline`（R-B09），回填主 note / ledger / commit references；合併 `main`
後以同一套 audit + Pester + negative + E2E 重跑驗收。

## 3. 相對舊計畫的變化

- 原 R3（SDD stage gates）吸收 RVR-02、RVR-07、RVR-10，並升級為 RB-1 的一部分 + RB-2 + RB-5。
- 原 R4（extensions）吸收 RVR-08、RVR-11，成為 RB-4。
- 新增 RB-3（合併證據完整性）是舊計畫沒有的獨立批次，因為 RVR-05/06 證明「驗證器本身」會漏，
  必須先修好才能信任後續每批的 Ready 帳務。
- 新增 R2.1（誠實性還原）為第 0 步。
- 終點 R6 的 minimum gates 由 re-review 第 9.2 節取代先前較粗的描述。

## 4. 粗估與排序

| 順序 | 批次 | 粗估 | 阻擋合併 |
|---|---|---|---|
| 0 | R2.1 誠實性還原 | 0.5 天 | 帳務前置 |
| 1 | RB-1 假完成/bypass/授權 | 2.5 至 3.5 天 | 是（Critical） |
| 2 | RB-2 執行身分與 routing | 2 至 3 天 | 是 |
| 3 | RB-3 合併證據完整性 | 1.5 至 2.5 天 | 是（且需先於後續 Ready） |
| 4 | RB-4 extension/consumer/upgrade | 3 至 4 天 | 是 |
| 5 | RB-5 agent/authority/process | 2 至 3 天 | 是 |
| 6 | R6 E2E + 合併 main | 2 至 4 天 | 終點 |

全量粗估約 14 至 22.5 人天。工期是重新估算區間，不是承諾值；每批實作時依當下證據調整。若時間
壓力大，最小可展示子集是 R2.1 + RB-1 + RB-3（止血 + 讓綠燈可信），約 4.5 至 6.5 天，足以對面試方
誠實說明「發現、承認、修復、驗證」的完整治理迴圈。

## 5. 已知限制與範圍

1. 依使用者指示，排除 `projects/` 與 `learning/` consumer 內部 drift；但 shared-layer 的
   worktree/init/template 腳本行為（RVR-09）在範圍內。
2. 本計畫是 forward-looking plan，authority 為 informational；真正的 open-findings 單一真相仍是
   repair ledger，R2.1 會把 RVR findings 併入該 ledger，避免平行真相。
3. 本文件不修改任何 runtime、agent、workflow、schema 或 tests；執行需另行批准後逐批進行。
4. 每批完成後回填本表與 ledger 的 commit hash 與 Ready note，維持與 re-review 判準一致。

## 6. Version History

| Version | Date | Change |
|---|---|---|
| 1.0.0 | 2026-07-14 | 依 2026-07-14 治理 re-review 的 12 條 RVR findings 制定分批修復計畫，對映 ledger 並標出被推翻的 Ready/Completed 宣稱 |
| 1.1.0 | 2026-07-18 | 日期化記錄 RB-2 開工前發現的 ECI outcome 數量 drift、owner 四值裁定與 R-B23 scope 邊界；原始 v1.0.0 文字保留為歷史證據 |

## 7. 2026-07-18 RB-2 ECI Outcome 裁定增補

RB-2 開工前複核發現，本文件第 2 節的批次專屬閘門寫「三種 ECI outcome」，但 canonical
`.github/agents/speckit.eci.agent.md`、ECI assessment template 與 authorization-record template
一致定義四個 Authorization Outcome。憲法第 5.1 節要求 exactly-one，但沒有另行縮減 enum。
依 drift-stop 規則先停止實作，並由 owner 於 2026-07-18 裁定採用以下四值：

1. `READY_FOR_MAINLINE_IMPLEMENTATION`
2. `READY_FOR_SPIKE_ONLY`
3. `READY_FOR_SANDBOX_ONLY`
4. `NOT_READY`

`NOT_READY` 是明確的第四種 fail-closed 結果，不授權 Plan 或 Implement。缺失、未知、重複或矛盾
outcome 同樣 fail-closed，不能把 default branch 當成有效的 `NOT_READY` 證據。第 2 節原始
「三種 ECI outcome」保留為當時的 drift 證據；本增補 supersede 該數量，RB-2 驗收必須覆蓋八種
readiness statuses 與四種 ECI outcomes。

RB-2 closure 範圍仍是 R-B07、R-B21、R-B22。R-B23 是 RB-1 獨立複核新增的 RunState/sidecar
authenticity finding，只排在 RB-2 相鄰工作，不併入 R-B21，也不得由 workflow graph digest
冒充關閉。`sdd-pipeline` 在 R6 前仍維持 experimental 與 execution-denied。
