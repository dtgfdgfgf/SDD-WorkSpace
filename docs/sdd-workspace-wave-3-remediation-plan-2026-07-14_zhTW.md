---
title: "SDD-WorkSpace Wave 3 Re-review 後續修復計畫（2026-07-14）"
version: "1.7.0"
date: "2026-07-14"
last_updated: "2026-07-20"
language: "zh-TW"
status: "plan"
authority: "informational"
branch: "feature/wave-3-security-and-workflows"
base_commit: "c6ee1f1 (main)"
head_commit: "3666c4e9a6553ff82774d4a06037f48846d8b0fd"
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
| 1.2.0 | 2026-07-18 | implementation commit `ec25c07` 完成 RB-2 的 graph identity、完整 ECI dossier/re-entry/exactly-one routing，並修復對抗複核揭露的共用 workflow 授權與 restart archive 缺口；記錄 R-B23、R-A17、R-A18 仍 OPEN，分支仍 NOT READY TO MERGE |
| 1.3.0 | 2026-07-20 | 記錄 owner Choice A，明確區分 Batch closure 與 Aggregate merge readiness；implementation commit `4f757e5` 關閉 R-A17/R-A18 並完成新 finding R-A20。另以 R-A21 保存 middle `/**/` zero-level matcher 殘留。Batch gate 全綠；Aggregate gate 只因 Wave-3 umbrella note 仍 Draft 而如實 fail-closed；分支仍 NOT READY TO MERGE。 |
| 1.4.0 | 2026-07-20 | 記錄 owner 核准把 R-C03 納入 RB-4 schema gate 必要相依；implementation commit `9819e30` 完成 R-C01/R-C02/R-C03/R-C05/R-C07/R-C08、R-A19 與 R-F06。R-C04/R-C06/R-F04 保持 OPEN；完整 suite 664/0、audit 0/0，分支仍 NOT READY TO MERGE。 |
| 1.5.0 | 2026-07-20 | RB-5 implementation commit `78c47eb0f3da7e75f3ba79943ea44f55984677a1` 完成 R-D01/R-D04/R-D05/R-E07 並建立新 High R-A22；migration commit `26da9a7412d902f2dfff48df23d04662687f4a9d` 封存 18 份歷史 note 證據並完成 R-A22。R-E09 只完成歷史 note 子項，整項維持 IN_PROGRESS；R6 是下一批，分支仍 NOT READY TO MERGE。 |
| 1.6.0 | 2026-07-20 | Post-accounting gates at head `64669c43d531d9dd699d60e163e7b1c755d64963` reopen RB-5 and R-A22: Pester remains 737/0/0, while runtime audit has one sealed-snapshot mismatch, Batch has 22 errors, and Aggregate has 19. R-D01/R-D04/R-D05/R-E07 remain COMPLETED; R-E09 remains IN_PROGRESS. R-A22 repair must precede R6; see Section 12. |
| 1.7.0 | 2026-07-20 | Repair commit `3666c4e9a6553ff82774d4a06037f48846d8b0fd` restores RB-5 closure: committed audit is VALID with 18/18 sealed records; the dedicated validator file is 91/91; production-positive plus five shape/type/null negatives and the contract revert anchor close R-A22. R-E09 remains IN_PROGRESS; final accounting gates remain pending; R6 is next. |

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

## 8. 2026-07-18 RB-2 完成增補

implementation commit `ec25c07` 已完成 RB-2。workflow approval、執行 snapshot 與
RunState 現在綁定同一 raw-byte SHA-256 graph digest；未核准的同 ID/version graph 在
fresh、resume 與 restart 都被拒絕，明確重新核准後仍須用 restart 封存舊 identity 才能
開始新 run。ECI 路徑要求八種 readiness status 與第 7 節裁定的四種 outcome 各自
exactly one；canonical evidence 是 `eci-trigger.md` 加四份 dossier，以 framed digest
綁定。`setup-eci.ps1` 與 project-local requirement marker 保存已觸發義務，direct Plan、
isolated canonical evidence deletion 與竄改 re-entry 均 fail-closed；已完成 dossier 的
fresh/restart 則依最新 readiness 跳過 ECI，不再誤入。

對抗複核同時修復兩個相鄰 closure blocker。run/list 改共用 manifest identity、
catalog `sourcePath` 與所有 reparse-point 實體邊界判準，恢復 R-B20/R-B05；restart
archive 改為 collision-resistant、atomic no-overwrite，恢復 R-B10/R-B24。這些相鄰修復
不改變 RB-2 的 canonical closure 範圍，也不把 R-B23 吸收到 R-B21。

| ID | 2026-07-18 狀態 | 結論 |
|---|---|---|
| R-B21 | COMPLETED | reviewed graph digest 綁定 approval、執行 bytes 與 RunState；未核准 bytes 均拒絕，重新核准後 resume 拒絕 hybrid run、restart 才能開始新 run |
| R-B07 | COMPLETED | 五件 ECI evidence、digest、re-entry 與第二次 readiness routing 已閉合 |
| R-B22 | COMPLETED | 八種 readiness status、四種 outcome exactly-one；requirement marker 與 mandatory setup gate 防止 isolated deletion 或 direct Plan bypass |
| R-B20、R-B05 | COMPLETED | ledger 第 18 節 manifest/list-run divergence 與 junction escape 已修復，共用授權判準恢復成立 |
| R-B10、R-B24 | COMPLETED | ledger 第 19 節同秒 archive overwrite 已修復，每次 restart 證據以 no-overwrite 保存 |
| R-B23 | OPEN | coordinated marker、readiness、trigger、dossier deletion/forgery；RunState/sidecar co-forgery；`completed_steps`、routing、gate injection；run-ID/path substitution 仍待 authority 設計 |

**判別性與機器驗收：**

| 驗收面 | 舊實作或現行結果 |
|---|---|
| R-B21 overlay | 舊實作 1/13 通過 |
| ECI validator overlay | 舊實作 0/25 通過 |
| direct Plan overlay | 舊實作 1/13 通過 |
| outcome/re-entry overlay | 舊實作 0/9 通過 |
| manifest counterexample | 舊 listing false-authorized manifest mismatch；新 run/list 共用判準並拒絕 |
| junction counterexample | 舊來源可經 reparse point 逃逸；新 run/list 均拒絕 root 外實體路徑 |
| archive counterexamples | 舊同秒 restart 覆寫第一份 archive；新實作保存兩份 identity，exact collision 拒絕覆寫 |
| RB-2 focused suites | 現行 353 passed / 0 failed |
| 完整 governance suite | 現行 579 passed / 0 failed |
| runtime audit | 現行 `VALID=true`、0 errors、0 warnings |
| accounting integration gates | `validate-mainline-notes.ps1 -BaseRef origin/main -HeadRef HEAD -RequireReady -Json` 為 `VALID=true`、0 errors、0 warnings；branch-wide `git diff --check` 通過 |

本次沒有新增 finding。ledger 維持 125 條，分布維持 Critical 8、High 29、Medium 50、
Low 38。R-B23 仍 `OPEN`；R-A17、R-A18 仍 `OPEN` 並留給 RB-3。RB-3 標題中的
「需先於後續任何 Ready 宣稱」是指 RB-3 之後各批的 Ready 宣稱；RB-2 note 可標為
`Ready`，只代表本批 implementation、判別性測試與帳務 evidence 彼此一致，不代表
aggregate branch 已可合併，也不宣稱 R-A18 已關閉。

RB-3、RB-4、RB-5 與 R6 仍須完成；`sdd-pipeline` 在 R6 前維持 experimental 與
execution-denied。RB-2 完成使分支更接近可合併，但 PR #3 仍 `NOT READY TO MERGE`。

## 9. 2026-07-20 RB-3 Batch 與 Aggregate 驗收語義裁定及完成增補

RB-3 開工前的 immutable batch base 為 `8bf9f0e`。開工前複核發現，原驗收文字把
同一個 `-RequireReady` 同時用於 coherent incremental Batch closure 與整個
`origin/main...HEAD` Aggregate merge readiness。R-A18 正確修復後，Wave-3 umbrella
note `docs/mainline-updates/2026-05-05-studio-workflows-runtime.md` 的 `Draft`、`TBD`
狀態必須使 Aggregate gate 維持紅燈直到 R6；舊批次規則卻要求同一 Aggregate 指令
在 RB-3 收尾全綠。兩者不能同時成立。

Owner 於 2026-07-20 選擇 Choice A，將兩種驗收面明確分開：

1. `Batch` scope 驗 coherent incremental batch。本批固定以 `8bf9f0e` 為 BaseRef，
   要求 RB-3 Ready note、真實且屬於該 batch range 的 commit evidence、visible
   exactly-one metadata、required sections、impact reconciliation 與 governed
   non-note shared-path last-touch coverage 全部閉合。
2. `Aggregate` scope 驗整個分支是否可合併。它固定以 `origin/main` 為 BaseRef；
   Wave-3 umbrella note 在 `Draft` 或仍含 `TBD` 時必須 fail-closed，其他較小
   Ready note 不得代替整體 readiness。configured anchor 即使未在 diff 變更也須
   以 HeadRef 狀態受驗。
3. `-RequireReady` 必須搭配 `-BaseRef` 與明確 `-ReadinessScope`；不得依 ChangedPaths、
   note 數量、檔名或歷史 commit 猜測，也不得退回 nonblocking shape-only 判準。
4. RB-3 的 Batch gate 綠燈與 Aggregate gate 因 umbrella note 尚未完成而紅燈可以
   同時成立。後者是真實 merge disposition，不是 RB-3 implementation failure。
5. Wave-3 umbrella note 在 fresh-fixture E2E 完成前維持 `Draft` 與 `TBD`；本批
   不提前執行 RB-4、RB-5、R6，不重新 promotion `sdd-pipeline`，不合併 main。

Implementation commit `4f757e5` 完成下列狀態：

| ID | 2026-07-20 狀態 | 結論 |
|---|---|---|
| R-A17 | COMPLETED | `sharedGatePaths` 使用 category-complete roots 覆蓋 `studio/scripts/powershell/**`、`.githooks/**`、`studio/extensions/**`；NUL-safe name-status parser 保存 rename old 與 new path；production-contract fixtures 能抓到漏列 script、hook、nested extension 與 rename-out |
| R-A18 | COMPLETED | blocking Ready evidence 驗 commit object、batch membership、contract-bound repository PR、visible metadata/sections 與 governed non-note shared-path coverage；Aggregate 不接受較小 Ready note 取代 Draft/TBD umbrella note |
| R-A20 | COMPLETED | Batch closure 與 Aggregate merge readiness 為明確、fail-closed、machine-readable 的兩種 scope；缺 BaseRef 或 scope 被拒絕，CI 使用 Aggregate，本批 accounting 使用 Batch |
| R-A21 | OPEN | middle `/**/` 目前無法匹配零層目錄；現行 exact readiness route 與本批 suffix `/**` roots 避免此殘留阻塞 RB-3，但 generic matcher 仍須獨立修復 |

**判別性與機器驗收：**

| 驗收面 | 結果 |
|---|---|
| Current RB-3 focused suites | 134 passed / 0 failed |
| Old implementation overlay | 34 個 discriminating negatives 為 0/34 passed；5 個 positive/regression controls 為 5/5 passed |
| 完整 governance suite | 616 passed / 0 failed |
| Runtime audit | `VALID=true`、0 errors、0 warnings |
| Batch gate | `-BaseRef 8bf9f0e -HeadRef HEAD -RequireReady -ReadinessScope Batch -Json` 為 `VALID=true`、0 errors、0 warnings |
| Aggregate gate | `-BaseRef origin/main -HeadRef HEAD -RequireReady -ReadinessScope Aggregate -Json` 為 nonzero，唯一 error 是 canonical umbrella note 的 `aggregate-note-not-ready` |
| Diff hygiene | `git diff --check` 通過 |

RB-3 Ready note 為
`docs/mainline-updates/2026-07-20-rb-3-mainline-evidence-integrity.md`。RB-3 使驗證
結果恢復可信並使分支更接近可合併，但不使分支可合併。PR #3 仍
`NOT READY TO MERGE`，`sdd-pipeline` 維持 experimental、default-disabled 與
execution-denied。工作在 RB-3 accounting 完成後停止，RB-4、RB-5、R6 留待後續
明確授權。

## 10. 2026-07-20 RB-4 scope 裁定與完成增補

RB-4 的 immutable batch base 為 `02f12cb`。開工前比對第 2 節與 ledger 發現 scope
drift：批次專屬閘門明定 schema violation 必須拒絕，但原 RB-4 對映沒有列 R-C03，
而三份 extension schema 當時沒有執行點。若不處理 R-C03，該 gate 只能是假綠或無法
完成。Owner 於 2026-07-20 核准把 R-C03 納入 RB-4 必要相依；這不授權吸收 R-C04、
R-C06 或 R-F04 的其餘工作。

Implementation commit `9819e30` 完成下列狀態：

| ID | 2026-07-20 狀態 | 結論 |
|---|---|---|
| R-C01 | COMPLETED | Extension export 受 workspace lexical/physical boundary 與 protected authority overlap 限制；staging 後才 promotion，unsafe output 不被清空 |
| R-C02 | COMPLETED | Add、replace、state、remove 先驗 schema 與 prospective state，再以 catalog/state/target/mirror transaction mutation；rollback failure 保留 recovery evidence |
| R-C03 | COMPLETED | Catalog、state、manifest 三 schema 由 `Test-Json` fail-closed 執行，並保留 cross-ledger validation |
| R-C05 | COMPLETED | Extension tree、registry、entry point 與 export 驗 reparse/physical boundary；replacement 清除 approval、trust、default 與 explicit state |
| R-C07 | COMPLETED | 隔離 fixture 完整演練 add、approve、enable、export、disable、re-enable、export、remove |
| R-C08 | COMPLETED | Declared scope、content-bound approval、transaction rollback、mirror invalidation、hash-bound recovery journal 與 atomic restore 收斂為同一判準 |
| R-A19 | COMPLETED | Linked worktree 使用 worktree-local hooks；source 與 sibling 不被改寫；consumer rooted ignores 防止 shared junction bytes 進入 status 或 staging |
| R-F06 | COMPLETED | Passive candidate bytes 只由 frozen trusted authority 驗證；baseline 在 audit 前建立；promotion、journal 與 rollback hash-bound 且原子；candidate checker/version/export 不執行 |
| R-C04 | OPEN | Extension compatibility version surface 尚未 enforce 或退役 |
| R-C06 | OPEN | Deprecated 新啟用與 `sync` state source 尚未收斂 |
| R-F04 | OPEN | Upgrade caller removal只是退役鏈的 partial alignment；其餘 scripts、audit、contract、docs、tests 與 output 尚待完整移除 |

既有 `extension-smoke` approval 不能證明現行 bytes 已受審；catalog 1.2.0 因而將它降為
draft、experimental、default-disabled，並清除 approval fields。這是誠實 migration，
不是本批重新核准 extension。

**判別性與機器驗收：**

| 驗收面 | 結果 |
|---|---|
| Extension | 現行 21/21；exact `02f12cb` 只有 1 個 positive control 通過，20 個 negatives 全失敗 |
| Worktree/consumer | 現行 common/init/feature suites 114/114；舊版三個判別 assertions 0/3 |
| Upgrade | 現行 17/17；corrupted-baseline targeted 連續 5/5；exact `02f12cb` 0/17 |
| Production-map Apply | exit 0、zero changes、trusted staging/canonical 均 Boolean `true` 與 Int64 0/0 |
| Contract/path focused | 31/31 與 14/14 |
| 完整 governance suite | 664 passed / 0 failed |
| Runtime audit | `VALID=true`、0 errors、0 warnings |
| Batch gate | `-BaseRef 02f12cb -HeadRef HEAD -RequireReady -ReadinessScope Batch -Json` 為 `VALID=true`、0 errors、0 warnings |
| Aggregate gate | `-BaseRef origin/main -HeadRef HEAD -RequireReady -ReadinessScope Aggregate -Json` 為 nonzero，唯一 error 是 canonical umbrella note 的 `aggregate-note-not-ready` |
| Diff hygiene | `git diff --check` 通過 |

本批沒有新增 finding；ledger 維持 127 條。R-A21、R-B23、R-C04、R-C06、R-F04 與
其他既有 open findings 均未被吸收。`sdd-pipeline` 維持 experimental、
default-disabled 與 execution-denied。RB-4 完成使分支更接近可合併，但 RB-5 與 R6
仍是必要批次，PR #3 仍 `NOT READY TO MERGE`。

## 11. 2026-07-20 RB-5 agent、authority、process 真實性完成增補

RB-5 的 immutable batch base 為
`de61431ae8f50d66f59157e00e4d239e9b37efdb`。Implementation commit
`78c47eb0f3da7e75f3ba79943ea44f55984677a1` 完成 agent truthfulness、Claude
mirror authority 與 constitutional self-application boundary；migration commit
`26da9a7412d902f2dfff48df23d04662687f4a9d` 完成歷史 note 證據遷移。

Preflight 發現，R-E09 的 18 份歷史 notes 所需 commits 都在 current Batch range 外。
直接回填會與 R-A18 的 in-range evidence 規則衝突，而刷新 legacy hash baseline 會留下
可變例外。Owner 於 2026-07-20 核准新增 High R-A22 作為 RB-5 必要相依：只允許一次性、
固定 base、Git-bound 且不授權 current readiness 的 migration。這不擴充到
`projects/`、`learning/`、runtime promotion 或 R6。

| ID | 2026-07-20 狀態 | 結論 |
|---|---|---|
| R-D01 | COMPLETED | Specify 不再限制 material markers、臆測剩餘需求或 direct handoff 至 Readiness；唯一 next-stage handoff 為 Clarify，source 與 mirror 同步 |
| R-D04 | COMPLETED | Claude mirrors 以 deterministic normalized content 驗證；blank、frontmatter/body drift、missing、extra、nested 與 child-result type tampering 全 fail-closed |
| R-D05 | COMPLETED | 未知或 broadened tool mapping、malformed list、empty-source permission grant 在任何 write 前 fail-loud；明示 `tools: []` 保持 |
| R-E07 | COMPLETED | Constitution 1.9.0 第 2.1 節只允許 contract-designated canonical workspace 的 shared-only self-application，分離 entry 與 closure prerequisites，且不能替代 consumer 七階段、Aggregate、promotion 或 R6 |
| R-A22 | COMPLETED | A commit 建立 pending framework；M commit 封存 18 records、固定 first-add/first-seal history、綁 evidence digest 並刪除 legacy baseline；歷史 refs 不進 current evidence |
| R-E09 | IN_PROGRESS | 18 份歷史 notes 已完成 exact commit recovery 與 truth review；17 份 `Merged`、`Closed`，一份 `Draft`、`Open`。Wave-3 umbrella note 與 R6 final evidence 尚未完成 |

**判別性與機器證據：**

| 驗收面 | 結果 |
|---|---|
| Specify exact pre-batch overlay | 10 個 source/mirror truthfulness assertions 為 0/10 |
| Claude mirror 舊 audit | blank 與 body tampering 兩項都未攔截；現行 parity/audit 均拒絕 |
| Constitution contract | 現行 24 passed / 0 failed，鎖定 identity、shared-only、entry/closure、consumer、Aggregate、promotion 與 fresh-fixture boundaries |
| Historical migration focused suite | 37 passed / 0 failed；shifted base、schema spoof、delete/re-add、pending reset、reseal、note/record rewrite、mixed refs 與 current authorization bypass 均拒絕 |
| Sealed evidence | 18 records；17 `Merged`、一個 `Draft`；policy digest `1cbb98f6edea8e096501112fac7196f84524ffdd9e6b69e63dc5b859d29d7a5e`；legacy baseline 不再存在 |
| Implementation full governance suite | 737 passed / 0 failed / 0 skipped（1029.06 秒） |
| Implementation runtime audit | `VALID=true`、0 errors、0 warnings |
| Implementation evidence | `78c47eb0f3da7e75f3ba79943ea44f55984677a1` |
| Migration evidence | `26da9a7412d902f2dfff48df23d04662687f4a9d` |

完整 governance suite 與 runtime audit 是本批 implementation acceptance 證據。本次
accounting edits 完成後仍須在批次收尾重跑完整 suite、runtime audit、Batch 與
Aggregate gates；本節不預先宣稱該次最終結果。

R-E09 維持 `IN_PROGRESS`，不能用 18 份歷史 notes 的完成狀態取代 Wave-3 umbrella
note、fresh-fixture E2E、Aggregate acceptance、promotion decision、merge authorization
或 post-merge verification。R-A13、R-A21、R-B23、R-C04、R-C06、R-E02、R-E03、
R-E04、R-E06、R-E08、R-E12、R-F04、R-I02 與其他 open findings 均未被吸收。
README 的四種 ECI outcome 修正不關閉 R-E01。

RB-5 已完成，Wave-3 remediation sequence 下一批為 R6。R6 必須執行 fresh fixture
完整七階段與 ECI re-entry、滿足 governance review minimum gates、完成 Wave-3
umbrella note 與 Aggregate acceptance、作出 `sdd-pipeline` promotion decision，並在
獲授權後才可 merge 和執行 post-merge verification。`sdd-pipeline` 在此之前維持
experimental、default-disabled 與 execution-denied。RB-5 使分支更接近可合併，但
PR #3 仍 `NOT READY TO MERGE`。

## 12. 2026-07-20 RB-5 post-accounting 誠實性還原增補

Accounting commit `64669c43d531d9dd699d60e163e7b1c755d64963` 後的必要最終閘門
推翻第 11 節的 RB-5 完成與「R6 是下一批」結論。完整 governance suite 仍為
737 passed / 0 failed / 0 skipped；但 runtime audit 為 `VALID=false`，唯一 error 是
`historical-evidence-sealed-snapshot-mismatch`。Batch gate 有 22 errors，包括同一
blocker、17 個衍生 historical out-of-range errors 與四個
`must-update-reconciliation-open`；Aggregate gate 有 19 errors。

目前診斷根因是 `Read-ExactLegacyBaselineAtCommit` 拒絕 production legacy baseline metadata
shape，使 `HISTORICAL_EVIDENCE_VALID=0`。RB-5 note 因而降為 `Draft`、`Open`。這項新
證據只推翻 R-A22 closure 與 RB-5 Batch readiness，不推翻 agent truthfulness、mirror
parity、least-privilege mapping 或 constitutional self-application boundary。

| ID | 目前狀態 | 修復前 disposition |
|---|---|---|
| R-D01 | COMPLETED | 維持完成 |
| R-D04 | COMPLETED | 維持完成 |
| R-D05 | COMPLETED | 維持完成 |
| R-E07 | COMPLETED | 維持完成 |
| R-A22 | IN_PROGRESS | 修復 production legacy baseline shape reconstruction，補判別性測試並重跑全部 final gates |
| R-E09 | IN_PROGRESS | 歷史子項與 Aggregate、merge accounting、R6 義務都不得冒充整項 closure |

下一步是修復 R-A22，並要求 runtime audit 0 errors / 0 warnings、完整 suite 至少
737 passed / 0 failed、Batch gate 全綠及 diff hygiene 通過。Aggregate 在 R6 前仍應只因
canonical umbrella note 為 `Draft` 而 fail-closed，不得保留 R-A22 或 RB-5 reconciliation
錯誤。修復完成並把 RB-5 note 恢復為 `Ready`、`Closed` 前，不得進入 R6。

本節不新增 finding，不改變 128 條 ledger 總數與 Critical 8、High 31、Medium 51、
Low 38 的分布。`sdd-pipeline` 繼續維持 experimental、default-disabled 與
execution-denied；PR #3 繼續維持 `NOT READY TO MERGE`。

## 13. 2026-07-20 RB-5 sealed baseline repair closure 增補

本節 supersede 第 12 節的 RB-5 reopened 與 R-A22 `IN_PROGRESS` disposition，但保留
第 12 節作為 post-accounting gate 正確揭露反例的歷史記錄。Repair commit
`3666c4e9a6553ff82774d4a06037f48846d8b0fd` 要求 immutable framework parent
精確符合 production five-field metadata shape，拒絕原本造成假綠測試與 production
失配的 two-field shortcut。

| 驗收面 | 已觀察結果 |
|---|---|
| Committed runtime audit | `VALID=true`、0 errors、0 warnings |
| Historical sealed evidence | 18/18 valid |
| Dedicated mainline-note validator file | 91 passed / 0 failed |
| Discriminating matrix | Production positive 通過；`TwoField`、`ExtraField`、`SubstitutedField`、`WrongType`、`Null` 全部拒絕 |
| Revert protection | Shared runtime contract anchor 拒絕舊 `Count=2` shortcut |

Repair 後 diagnostic Batch 的 historical evidence 已為 18/18，且沒有 sealed snapshot
mismatch。其 33 errors 僅來自 RB-5 note 當時仍為 `Draft`，以及對應的 coverage、
not-ready 與 reconciliation-missing derivatives。因此該 diagnostic 不能冒充 final
Batch；完整 governance suite、Batch 與 Aggregate 必須在 accounting edits 完成後重跑，
本節不預先宣稱尚未觀察的結果。

| ID | Repair closure 狀態 | 結論 |
|---|---|---|
| R-D01 | COMPLETED | 維持既有 closure |
| R-D04 | COMPLETED | 維持既有 closure |
| R-D05 | COMPLETED | 維持既有 closure |
| R-E07 | COMPLETED | 維持既有 closure |
| R-A22 | COMPLETED | Exact production metadata、committed 18/18 audit、判別 matrix 與 revert anchor 完成 closure |
| R-E09 | IN_PROGRESS | 18-note historical portion 已完成；umbrella、R6、merge accounting 與 post-merge evidence 尚未完成 |

RB-5 已完成，R6 是下一個 remediation batch。R6 必須執行 fresh-fixture 七階段與 ECI
re-entry、minimum gates、Aggregate acceptance、promotion decision、final merge
accounting 及 post-merge verification。本次 accounting 後仍須先依實際結果完成 full
suite、runtime audit、Batch、Aggregate 與 diff hygiene 收尾。

本節不新增 finding，也不吸收任何其他 open ID；ledger 維持 128 條，分布維持
Critical 8、High 31、Medium 51、Low 38。`sdd-pipeline` 在 R6 決策前維持
experimental、default-disabled 與 execution-denied，PR #3 維持
`NOT READY TO MERGE`。
