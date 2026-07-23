---
title: "SDD-WorkSpace Wave 3 Re-review 後續修復計畫（2026-07-14）"
version: "1.30.0"
date: "2026-07-14"
last_updated: "2026-07-23"
language: "zh-TW"
status: "plan"
authority: "informational"
branch: "feature/wave-3-security-and-workflows"
base_commit: "c6ee1f1 (main)"
head_commit: "d8dbdf275858d445087a39b35839566bf87697c7"
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
| 1.8.0 | 2026-07-20 | RB-5 final gates at accounting head `44f768a12316cdb008f1fee263e03ed7ce9a8191` complete with full suite 742/0/0/0, runtime audit VALID 0/0 and historical sealed 18/18, Batch VALID 0/0 from base `de61431ae8f50d66f59157e00e4d239e9b37efdb`, exactly one expected Aggregate umbrella error, and clean diff/worktree hygiene. RB-5 is complete and R6 is next, but owner decisions and R6 evidence still block promotion and merge; see Section 14. |
| 1.9.0 | 2026-07-21 | R6 evidence implementation `aef41b1bac2e56bf717d9ded5328c3c601fd7037` adds a reproducible isolated canonical-workflow journey and audit revert anchor. Focused E2E is 1/0, the full suite is 744/0/0/0, and committed runtime audit is VALID 0/0 with historical evidence 18/18. The bounded evidence sub-batch is complete; R6 overall remains IN_PROGRESS and residual, R-E11, promotion, merge, Aggregate, and post-merge decisions remain open; see Section 15. |
| 1.10.0 | 2026-07-21 | R6 evidence accounting head `28fbc8280000124e15c9c4913f6c130af1df78bb` passes runtime and Batch with 0 errors and 0 warnings, historical evidence 18/18, and clean diff/worktree hygiene. Aggregate returns exactly the expected Draft-umbrella blocker. The evidence sub-batch remains complete, while R6 overall remains IN_PROGRESS; see Section 16. |
| 1.11.0 | 2026-07-21 | Owner-authorized accounting-only reconciliation supersedes the stale umbrella statement that fresh-fixture evidence remained pending. Final tested head `f2df26e98300c034f7fa03c7831b8f00aa6c470a` has full suite 744/0/0/0, runtime and Batch VALID 0/0, historical evidence 18/18, and exactly one expected Aggregate umbrella blocker. No residual, promotion, Aggregate, merge, or post-merge disposition changes; see Section 17. |
| 1.12.0 | 2026-07-21 | Truth restoration rejects `8101f9a380eb27c5004bece9aad77d42b2cc8a51` as R-D03 closure evidence because no committed R-D03-only plan preceded it, while preserving its technically green diagnostics. After that defect was reported, the owner explicitly authorized a prospective clean re-entry limited to R-D03. This version restores the five implementation surfaces before the new implementation begins; R-D03 remains OPEN and every other residual remains unchanged; see Section 18. |
| 1.13.0 | 2026-07-21 | Clean re-entry implementation `2f941002009b1e05b33d790e7c6c8fc06e8daf3c` follows committed reset and authorization parent `687625af6a9df299c1037e1ba3ec29ef154dc6d3`, completes the remaining R-D03 task-priority and parallelism semantics, and leaves the refuted `8101f9a` attempt non-closing. Focused old/new evidence is 18/2 and 20/0, coordinated mutation is 1/0, full suite is 747/0/0/0, and runtime is VALID 0/0. Accounting-head Batch and Aggregate gates remain pending; see Section 19. |
| 1.14.0 | 2026-07-21 | Accounting head `7ad8bb76eccccf91a7b87954ce19f97c3ff12951` completes the pending R-D03 final gates: exact-tree full suite 747/0/0/0, runtime VALID 0/0 with historical evidence 18/18, Batch VALID 0/0 across 10 paths, exactly one expected Aggregate umbrella blocker, and clean hygiene. R-D03 remains COMPLETED, while R6 overall and all other residuals retain their prior states; see Section 20. |
| 1.15.0 | 2026-07-21 | Records the owner-authorized prospective plan for the R-F04 status/count truth restoration. The owner preserves R-F04 as DECIDED, meaning the retirement direction remains authorized but unimplemented. This entry does not yet supersede the later RB-4 OPEN record, change folded counts, or resume the R6 residual audit; implementation must begin only after this plan commit. See Section 21. |
| 1.16.0 | 2026-07-21 | Implements the append-only R-F04 status clarification after entry-plan commit `bab1ce93aec28819a0c68a3ed7f6e85d3de53442`. R-F04 is authoritatively DECIDED, meaning retirement is authorized but unimplemented; R-H15 remains DECIDED, every other finding is unchanged, and the 128-item fold remains 76/45/6/1. The dedicated Batch note remains Draft/Open/TBD until a later accounting commit and exact-tree gates; see Section 22. |
| 1.17.0 | 2026-07-21 | Final accounting records owner Choice A after no-scope gate drift-stop: R-A20's explicit Batch/Aggregate contract is authoritative. Exact-tree results are full suite 747/0/0/0, runtime VALID 0/0 with 18/18 historical evidence, Batch VALID 0/0 across 5 paths from `6b749a1`, and exactly the expected Aggregate umbrella blocker. Implementation `180abc0` is cited by the Ready/Closed Batch note; R-F04/R-H15 remain DECIDED but unimplemented, R-E09 retains the five umbrella coverage obligations, and R6 remains IN_PROGRESS. See Section 23. |
| 1.18.0 | 2026-07-21 | Owner Choice A establishes the prospective conservative R6 convergence plan. Residual audit adds OPEN R-B25/R-B26, producing 130 findings and current fold 76 COMPLETED / 47 OPEN / 6 DECIDED / 1 IN_PROGRESS. Seventeen bounded safety/truthfulness findings are authorized for direct repair; 35 non-critical findings may later become DISPOSITIONED only with exact Wave-4 re-entry triggers; R-E09/R-J03 remain terminal blockers. `sdd-pipeline` stays experimental, default-disabled and execution-denied. This version is plan-only and must be committed before implementation; see Section 24. |
| 1.19.0 | 2026-07-22 | R6-A1 preflight after committed plan `f669e3d` finds that R-H03 cannot absorb the cross-surface contradiction between constitutional dependent-mirror classification and generator/contract/current-doc claims that `.claude/agents/` is runtime authority. Owner authorizes new High OPEN R-H20 and direct repair. Ledger becomes 131 with severity 8/32/52/39 and fold 76 COMPLETED / 48 OPEN / 6 DECIDED / 1 IN_PROGRESS; direct repairs become 18 including R-D07. This is still pre-implementation; see Section 25. |
| 1.20.0 | 2026-07-22 | A second R6-A1 drift-stop refines R-H20 after the source directory proves mixed-authority: 14 `*.agent.md` files and `async-python-reviewer.md` are the 15 canonical generator inputs, while `copilot-instructions.md` is a dependent adapter and all 15 Claude outputs are dependent mirrors. Owner Choice A keeps this within R-H20, changes no counts or statuses, and requires exact partition tests before implementation continues; see Section 26. |
| 1.21.0 | 2026-07-22 | Corrects the accounting sequence after implementation `105a09cd02f7d8b4765e49859390908e55bd97d1`: R6-A1 may receive its own evidence-backed revision-2 status delta and dedicated Batch note before A2 through A4, while R6-A5 remains the later Wave-4 and multi-batch accounting point. This timing correction changes no status by itself and preserves non-promotion, consumer exclusions, R-E09/R-J03 terminal boundaries and PR #3 NOT READY state; see Section 27. |
| 1.22.0 | 2026-07-22 | Owner Choice A resolves the R6-A1 re-entry plan drift discovered after repair `ea78b64fec17ee074018b9dc17abea31404f8f16`. The append-only history must preserve revisions 1 through 3 and may append revision 4 only for R-E11 after the repaired clean tree passes its pre-accounting gates. A later note-only finalization must validate exactly four consecutive revisions on the re-entry final tree. No status changes in this plan-only amendment; see Section 28. |
| 1.23.0 | 2026-07-22 | Owner Choice A resolves the finalization surface-set contradiction found after revision-4 accounting `a74a08a191b8ec1bd67b2f2b9112e2810f10959c`. Because `docs/README.md` contains current note-state prose, changing the dedicated note to Ready/Closed without synchronizing that prose would recreate the stale-truth defect recorded in Section 41. The finalization commit may therefore update exactly the dedicated note, its mainline index row and the `docs/README.md` note-state prose while preserving the revision-4 machine marker and every finding status. No readiness or status changes occur in this plan-only amendment; see Section 29. |
| 1.24.0 | 2026-07-22 | Owner Choice A defines a non-self-referential R-E11 re-entry after finalization `f0f325b` failed Batch last-touch coverage and honesty demotion `4ce95a4` appended revision 5. Revision 6 accounting will make `docs/README.md` prose state-neutral while the note remains Draft/Open; a later two-file finalization can cite the revision-6 accounting commit that last touched the ledger and docs index. The validator is not weakened, and no status changes occur in this plan-only amendment; see Section 30. |
| 1.25.0 | 2026-07-23 | Owner Choice A resolves the R6-A5 trigger-authority contradiction before the first `DISPOSITIONED` record. New Medium R-E13 records the independent fail-open representation gap without reopening R-E11. A registration revision must precede a separate backward-compatible schema and validator implementation; only later accounting may complete the evidence-backed A2 through A4 repairs and R-E13, and disposition the 35 owner-approved Wave-4 items with exact per-ID triggers. No status changes occur in this plan-only amendment; see Section 31. |
| 1.26.0 | 2026-07-23 | Owner-authorized reconciliation-row re-entry records the missing `.claude/agents/*.md` `must_update` row after the first A2-A5 finalization failed its committed-tree Batch gate. The bounded two-file finalization may restore only the dedicated A2-A5 note and matching index row after every exact-tree gate passes; see Section 32. |
| 1.27.0 | 2026-07-23 | Owner-authorized process-scoped validation re-entry records that Windows PowerShell 5.1 must inherit `PSExecutionPolicyPreference=Bypass` only for the official suite process so the existing version-guard test reaches `ScriptRequiresUnmatchedPSVersion`. No persistent execution policy, runtime, test or finding status may change; see Section 33. |
| 1.28.0 | 2026-07-23 | The owner instruction to continue authorizes the prospective R6-A6 umbrella checkpoint after A2-A5 finalization `501f4d7`. Preflight proves runtime and Batch valid, finding revision 9 at fold 95/1/0/1/35, and exactly one Aggregate Draft-umbrella blocker from `main`. R6-A6 may finalize the two umbrellas under permanent Wave-3 non-promotion, but must stop before push or merge; R-E09 and R-J03 remain non-terminal until real merge and post-merge evidence exists. See Section 34. |
| 1.29.0 | 2026-07-23 | Aggregate finalization `0470fc5` passed runtime, ledger history and Batch but failed with exactly 80 coverage errors because its Related Commits omitted twelve exact last-touch commits. Honesty demotion `c16f2fa` restored only the Aggregate note and index row to Draft/Open. This re-entry plan authorizes complete commit coverage without changing runtime, tests, ledger, R6 Batch readiness or workflow authorization; see Section 35. |
| 1.30.0 | 2026-07-23 | Complete-coverage finalization `0ee547d` passes runtime, ledger history, Batch and Aggregate with 0 errors and 0 warnings. The official suite discovers exactly 986 tests and completes multiple large green files, but the 2400-second tool limit expires before Pester emits a final summary; honesty demotion `d8dbdf2` restores the Aggregate note and index row to Draft/Open. This suite-only re-entry raises only the bounded validation timeout to 4500 seconds, not the test or acceptance standard. See Section 36. |

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

## 14. 2026-07-20 RB-5 final gates 與 R6 preflight 增補

本節 supersede 第 13 節中 accounting 後 final gates 尚待重跑的句子，並保留第 13 節
作為 repair closure 的歷史記錄。Accounting commit
`44f768a12316cdb008f1fee263e03ed7ce9a8191` 已完成 RB-5 final acceptance：

| 驗收面 | Final result |
|---|---|
| Full governance suite | 742 passed / 0 failed / 0 skipped / 0 not run，1115.2 秒 |
| Runtime audit | `VALID=true`、0 errors、0 warnings |
| Historical sealed evidence | 18/18 valid |
| Batch gate | Base `de61431ae8f50d66f59157e00e4d239e9b37efdb`；`VALID=true`、0 errors、0 warnings |
| Aggregate gate | Exactly one expected error：canonical umbrella note 的 `aggregate-note-not-ready` |
| Diff and worktree hygiene | `git diff --check` 通過；committed head worktree clean |

RB-5 維持完成，R-A22 維持 `COMPLETED`，R-E09 維持 `IN_PROGRESS`。Aggregate 的單一
expected error 正確保留 R6 merge boundary，不授權 promotion 或 merge。

### R6 Preflight Decision Blockers

| Decision area | Owner 尚未裁定 | 執行限制 |
|---|---|---|
| Residual merge dispositions | R-A21、R-B23、R-C04、R-C06、R-F04 與其他 open findings 的修復、defer 或 owner-approved disposition | Agent 不得自行關閉或接受；逐項裁定前不得宣稱 merge-ready |
| R-E11 | R6 必須給出明確 disposition；現有 ledger 不自動完成 R-E11 | 不標示 `COMPLETED`，不由 RB-5 吸收 |
| Workflow promotion | Promotion `sdd-pipeline` 或維持 non-promotion | Owner 決定與 fresh-fixture evidence 前維持 experimental、default-disabled、execution-denied |
| Merge and post-merge accounting | Merge authorization、final PR/commit/merge references、umbrella closure 與 post-merge validation | 決定及 evidence 完成前不得 merge，也不得預先記錄 post-merge success |

RB-5 已完成，R6 是下一個 remediation batch，但 R6 不得在未完成上述 owner decisions
與 fresh-fixture、minimum gates、Aggregate、promotion disposition、merge accounting
evidence 的情況下 promotion 或 merge。Ledger 維持 128 條，分布維持 Critical 8、
High 31、Medium 51、Low 38；PR #3 維持 `NOT READY TO MERGE`。

## 15. 2026-07-21 R6 fresh-fixture evidence 子批增補

Implementation commit `aef41b1bac2e56bf717d9ded5328c3c601fd7037` 已把
canonical `sdd-pipeline` version 1.1.0 exact bytes 複製到 `$TestDrive` 的隔離 Studio
registry，並以 fixture-only approval 與 state 執行一個 coherent journey。Canonical
registry 仍 denied，沒有 promotion。

| R6 evidence stage | 結果 |
|---|---|
| Canonical denial 與 isolation | Canonical runner denied；DryRun 不留下 resumable `state.json`；canonical workflow inventory 與 `projects/`、`learning/` Git surface 前後一致 |
| Non-ready 與 restart | `NOT_READY` reject 為 exit 44，rejected resume denied；兩次 restart 各自保留不同 run archive |
| ECI re-entry | `ROUTE_TO_ECI` requirement latch、五檔 dossier、framed digest、`READY_FOR_MAINLINE_IMPLEMENTATION` 與 COMPLETE Readiness re-entry 全部通過 |
| Analyze | `OPEN` Critical 被 Implement gate 拒絕；修復後 machine result 與 current artifact hashes 一致 |
| Terminal | `T001` partial completion 仍 halted；baseline `T001`、`T002` 都存在且完成後才成功 |
| Workflow identity | Halt 後 fixture workflow byte mutation denied；恢復 exact authorized bytes 才能繼續 |
| Revert anchor | 九個 evidence markers 受 shared runtime contract 約束；移除 terminal marker 時 audit 必紅 |
| Focused results | Fresh-fixture 1/0；contract negative 1/0；full suite 744/0/0/0 in 1249.12 秒；committed runtime audit VALID 0/0，historical evidence 18/18 |
| Evidence note | 日期化 note 只對 bounded fresh-fixture 子批標為 `Ready`、`Closed`、`Batch` |

這些結果滿足 R6 fresh-fixture 證據蒐集子項，但不完成 remediation plan 第 2 節 R6
終點。第 14 節 decision blockers 全部保留：

- R-A21、R-B23、R-C04、R-C06、R-D03、R-F04 與其他 residual 未修復或獲 owner
  disposition。
- R-E11 未獲明確 disposition；R-E09 維持 `IN_PROGRESS`。
- Canonical `sdd-pipeline` 維持 experimental、default-disabled、execution-denied。
- Wave-3 umbrella note 維持 `Draft`、`Open`、`TBD`、`Aggregate`。
- PR #3 維持 `NOT READY TO MERGE`；不 push、不 merge、不預填 post-merge evidence。

Owner 只授權本批同步修正 `docs/README.md` 的 ledger 索引漂移；該文件先前仍寫
v1.10.0、125 條與 RB-2 現況，現應對齊 ledger v1.17.0、128 條與 R6 evidence 子批。
這不是 residual acceptance 或 merge authorization。

Full governance suite 已在 accounting worktree 以 744 passed、0 failed、0 skipped、
0 not run 完成。Staged snapshot 與 committed accounting head 的 runtime、Batch、
Aggregate 及 final diff/worktree hygiene 仍須實際驗證；任何反證都必須重新開啟
evidence 子批。即使這些閘門符合 bounded 子批預期，R6 overall 仍維持
`IN_PROGRESS`。

## 16. 2026-07-21 R6 evidence post-accounting 驗證增補

Accounting commit `28fbc8280000124e15c9c4913f6c130af1df78bb` 已完成第 15 節保留的
committed-head 驗證：

| 驗收閘門 | 結果 |
|---|---|
| Canonical runtime audit | `VALID=true`、0 errors、0 warnings |
| Historical sealed evidence | 18 of 18 records valid |
| Batch | BaseRef `f8e3fe0bd9d62b7f8e0110bc2a13e73548311c3f`；`VALID=true`、0 errors、0 warnings；8 changed paths |
| Aggregate | 預期 exit 1；只有 canonical Wave-3 umbrella note 的 `aggregate-note-not-ready` |
| Diff 與 worktree | `git diff --check` passed；worktree clean |

因此 R6 fresh-fixture evidence 子批維持完成，其日期化 note 維持 `Ready`、`Closed`、
`Batch`。Aggregate 的單一 blocker 保留 remediation plan 第 2 節 R6 終點，不授權
promotion 或 merge。

R6 overall、R-E09、R-E11、residual dispositions、workflow promotion、Aggregate
acceptance、merge accounting 與 post-merge evidence 仍未完成。Canonical
`sdd-pipeline` 維持 experimental、default-disabled、execution-denied；PR #3 維持
`NOT READY TO MERGE`。

## 17. 2026-07-21 R6 umbrella evidence drift reconciliation 增補

Owner 授權本批只做 accounting drift reconciliation。Canonical Wave-3 umbrella note 仍把
fresh-fixture evidence 寫成待辦，已與 `aef41b1bac2e56bf717d9ded5328c3c601fd7037`
完成的 bounded evidence 及最終已測 head
`f2df26e98300c034f7fa03c7831b8f00aa6c470a` 矛盾。本節只日期化修正該 current-status
drift，不刪除第 15、16 節或 umbrella note 的歷史時間線。

| 驗收閘門 | `f2df26e98300c034f7fa03c7831b8f00aa6c470a` 結果 |
|---|---|
| Full governance suite | 744 passed、0 failed、0 skipped、0 not run，1251.1 秒 |
| Canonical runtime audit | `VALID=true`、0 errors、0 warnings |
| Historical sealed evidence | 18 of 18 records valid |
| Batch | BaseRef `f8e3fe0bd9d62b7f8e0110bc2a13e73548311c3f`；`VALID=true`、0 errors、0 warnings；8 changed paths |
| Aggregate | 預期 exit 1；只有 canonical umbrella note 的 `aggregate-note-not-ready` |
| Diff 與 worktree | `git diff --check` passed；worktree clean |

Metadata `head_commit` 表示已完整驗證的 evidence head，不預先填入本 accounting 增補的
自我參照 hash。Fresh-fixture evidence 子批維持完成，但 R6 overall 與 R-E09 維持
`IN_PROGRESS`；R-E11、residual dispositions、workflow promotion、Aggregate acceptance、
merge accounting 與 post-merge evidence 仍未完成。

Umbrella note 必須維持 `Draft`、`TBD`、`Open`、`Aggregate`；`sdd-pipeline` 必須維持
experimental、default-disabled、execution-denied。本批不改 runtime、workflow、tests 或
finding status，不 promotion、不 push、不 merge；PR #3 維持 `NOT READY TO MERGE`。

## 18. 2026-07-21 R-D03 invalid-entry truth restoration 與 prospective clean re-entry authorization 增補

第 17 節只記錄前一個 accounting-only reconciliation，沒有識別 R-D03-only
implementation scope。Attempt `8101f9a380eb27c5004bece9aad77d42b2cc8a51` 因此在
缺少 Constitution Section 2.1 pre-implementation plan 的狀態下產生。其技術結果保持
可稽核，但 closure eligibility 被否決；R-D03 從未合法離開 `OPEN`。

Entry defect 回報後，owner 於 2026-07-21 明確授權 clean re-entry。這項授權只向後
生效，不溯及 `8101f9a`。本節與本次 truth-restoration commit 構成新 implementation
的日期化 owner-authorized plan；只有在它們已 committed 且五個 implementation
surfaces 已回復基線後，後續 implementation 才可開始。

### Authorized Scope

In scope:

- R-D03 剩餘的 `[P]`、`[P#]`、task priority 與 parallelism 語義漂移。
- `.github/agents/speckit.implement.agent.md` 與 deterministic Claude mirror。
- `studio/runtime/shared-runtime-contract.json` 的 source/mirror revert anchors。
- `studio/tests/claude-agent-parity.Tests.ps1` 與
  `studio/tests/check-speckit-runtime.Tests.ps1` 的判別性 evidence。

Out of scope:

- R-D02 已完成的 mandatory Implement first-action gate；不得重複結算。
- R-G03 version facts 與任何其他 residual finding。
- `projects/`、`learning/`、workflow promotion、Aggregate acceptance、push、merge、
  post-merge evidence 與 PR thread resolution。

### Required Sequence

1. 以普通 commit 保留 `8101f9a`、Draft note 與 index 歷史，同時把五個
   implementation surfaces 恢復到 pre-R-D03 語義；不得 history rewrite。
2. Commit 本節與 ledger Section 30，使新的 implementation parent 已含日期化授權。
3. 在新的 commit 重新套用 R-D03 修復，且不得引用 `8101f9a` 作 closing implementation。
4. 重建舊語義失敗、新語義通過、coordinated source-and-mirror revert、Claude parity
   與兩個 contract invariant 的判別性證據。
5. 跑 canonical runtime 0 errors / 0 warnings、完整 governance suite、Batch、
   expected Aggregate blocker、pre-commit 與 diff/worktree hygiene。
6. 只有全部通過，才在另一個 accounting commit 將 note 改為 `Ready`、reconciliation
   `Closed` 並把 R-D03 改為 `COMPLETED`。

| ID 或範圍 | Re-entry 前狀態 |
|---|---|
| R-D03 | OPEN；new implementation 與 closure evidence pending |
| R-D02 | COMPLETED；不重複計算 |
| R-G03 | OPEN；版本 drift 另案處理 |
| R6 overall / R-E09 | IN_PROGRESS |
| 其他 residuals | 狀態不變 |

Ledger 維持 128 條與 Critical 8、High 31、Medium 51、Low 38；折疊狀態維持
75 COMPLETED / 46 OPEN / 6 DECIDED / 1 IN_PROGRESS。Canonical `sdd-pipeline`
維持 experimental、default-disabled、execution-denied；umbrella note 維持
`Draft`、`TBD`、`Open`、`Aggregate`。PR #3 維持 `NOT READY TO MERGE`。

## 19. 2026-07-21 R-D03 clean re-entry implementation 與 pending accounting gates 增補

本節保留第 18 節的 owner authorization、reset chronology 與 `8101f9a` invalid-entry
判定。Truth-restoration commit
`687625af6a9df299c1037e1ba3ec29ef154dc6d3` 已先提交日期化 plan 並恢復五個
implementation surfaces；clean re-entry commit
`2f941002009b1e05b33d790e7c6c8fc06e8daf3c` 以該 commit 為 parent，符合第 18 節
Required Sequence 的 implementation 邊界。

本批只處理 R-D03 剩餘的 `[P]`、`[P#]`、task priority 與 parallelism 語義；R-D02
mandatory Implement first-action gate 維持既有 `COMPLETED`，不重複結算。R-G03、
其他 residuals、`projects/`、`learning/`、workflow promotion、Aggregate acceptance、
push、merge、post-merge evidence 與 PR thread resolution 均不在範圍內。

| 驗收面 | Implementation head 結果 |
|---|---|
| Pre-repair focused assertions | 18 passed / 2 failed |
| Post-repair focused parity | 20 passed / 0 failed |
| Coordinated source-and-mirror mutation | 1 passed / 0 failed；legacy semantics 被兩個 contract invariants 拒絕 |
| Canonical runtime audit | `VALID=true`、0 errors、0 warnings |
| Full governance suite | 747 passed、0 failed、0 skipped、0 not run |

上述證據完成 R-D03 clean re-entry implementation，R-D03 最新狀態改為 `COMPLETED`。
Ledger 折疊狀態為 76 COMPLETED / 45 OPEN / 6 DECIDED / 1 IN_PROGRESS；High 為
23 COMPLETED / 7 OPEN / 1 IN_PROGRESS。未完成 High 維持 8 條：R-B23、R-E09、
R-F02、R-G01、R-G02、R-G03、R-H03、R-J03。R6 overall 與 R-E09 維持
`IN_PROGRESS`，其他 finding 狀態不變。

本 accounting worktree 將 R-D03 note 改為 `Ready`、reconciliation `Closed`，並將
Related Commit 設為 `2f941002009b1e05b33d790e7c6c8fc06e8daf3c`。但 accounting
commit 尚未建立，所以下列 final gates 仍為 pending：

1. committed accounting-head canonical runtime audit 與完整 governance suite；
2. `-ReadinessScope Batch` validation；
3. `-ReadinessScope Aggregate` 的預期 canonical umbrella blocker；
4. `git diff --check` 與 clean worktree hygiene。

本節只調整第 18 節 Required Sequence 第 5、6 步的機器可執行順序：blocking Batch
validator 必須先讀到 committed Ready note，因此先建立可被驗證的 accounting commit，
再跑 final gates；所有 closure prerequisites 仍完整保留，狀態也仍受失敗時立即降級的
規則約束。

本節不預先宣稱 Batch 或 Aggregate final result。任何 post-accounting failure 都必須
立即依狀態機把 note 降回 `Draft`、reconciliation 改回 `Open`，並把 R-D03 還原為
`OPEN`。在 final gates 與其日期化回填完成前，canonical `sdd-pipeline` 維持
experimental、default-disabled、execution-denied，umbrella note 維持 `Draft`、
`TBD`、`Open`、`Aggregate`，PR #3 維持 `NOT READY TO MERGE`；不得 promotion、push、
merge 或填寫 post-merge success。

## 20. 2026-07-21 R-D03 accounting-head final gates 增補

第 19 節先建立 blocking validator 可讀取的 Ready accounting commit，再要求立即執行
final gates。Accounting head `7ad8bb76eccccf91a7b87954ce19f97c3ff12951` 現已完成該
順序；detached candidate 與正式 branch commit 的 tree、parent、message 及 commit
metadata 相同，所以完整 suite 證據精確屬於同一 commit。

| Final gate | Result |
|---|---|
| Full governance suite | 747 passed、0 failed、0 skipped、0 not run，1041.44 秒 |
| Canonical runtime audit | `VALID=true`、0 errors、0 warnings；historical evidence 18/18 |
| Batch | BaseRef `687625af6a9df299c1037e1ba3ec29ef154dc6d3`；`VALID=true`、0 errors、0 warnings；10 paths |
| Aggregate | 預期 exit 1；只有 canonical umbrella note 的 `aggregate-note-not-ready` |
| Diff/worktree | `git diff --check` passed；正式與 candidate worktree clean |

R-D03 closure 因此維持有效。Ledger 維持 76 COMPLETED / 45 OPEN / 6 DECIDED /
1 IN_PROGRESS；High 維持 23 COMPLETED / 7 OPEN / 1 IN_PROGRESS。R-B23、R-E09、
R-F02、R-G01、R-G02、R-G03、R-H03、R-J03 仍是 8 個未完成 High，沒有被本批吸收。

R6 overall 與 R-E09 維持 `IN_PROGRESS`；R-E11、其他 residual dispositions、workflow
promotion、Aggregate acceptance、merge 與 post-merge evidence 仍未完成。Canonical
umbrella note 維持 `Draft`、`TBD`、`Open`、`Aggregate`；`sdd-pipeline` 維持
experimental、default-disabled、execution-denied。PR #3 維持 `NOT READY TO MERGE`；
本批不 push、不 merge、不 resolve PR threads。

## 21. 2026-07-21 R-F04 status drift-stop 與 owner-authorized entry plan

唯讀 R6 residual audit 發現 R-F04 的 status 與 final folded counts 不可同時成立。原 owner
decision 將 R-F04/R-H15 退役方向標為 `DECIDED`；較晚 RB-4 記錄把 R-F04 寫成
`OPEN`；最新 folded summary 仍為 76 COMPLETED / 45 OPEN / 6 DECIDED /
1 IN_PROGRESS，且只有把 R-F04 計為 `DECIDED` 才能得到該數字。若採後來的 `OPEN`，
則應為 76 / 46 / 5 / 1。

Owner 於 2026-07-21 裁定保留 R-F04 `DECIDED`。其精確語意是「退役方向已裁定、實作尚未
完成」，不是 closure、risk acceptance 或 defer。R-H15 維持 `DECIDED`；R-F04 仍須在
後續授權批次移除剩餘 scripts、audit、contract、docs、tests 與 output surface，才可考慮
`COMPLETED` 或 `DISPOSITIONED`。

本節只建立 Constitution Section 2.1 要求的 committed entry plan。實作與驗收邊界為：

1. implementation parent 必須包含本節；
2. 只以日期化增補 supersede R-F04 的 RB-4 `OPEN` 字面狀態，不改寫歷史段落；
3. section-bounded old/new parser 必須在舊樹辨識 status/count ambiguity，並在新樹唯一得到
   128 條與 76 COMPLETED / 45 OPEN / 6 DECIDED / 1 IN_PROGRESS；
4. R-F04、R-H15 都維持未完成，其他 126 條 finding disposition 不變；
5. dedicated Batch note 在實作前維持 `Draft`、`TBD`、reconciliation `Open`；
6. final accounting tree 必須通過 runtime、完整 governance suite、Batch、預期 Aggregate
   umbrella blocker 與 diff hygiene，才可標記本 truth-restoration Batch 為 Ready。

本 entry plan 不執行 skills 退役、不 promotion、不 push、不 merge，也不恢復 residual audit。
`sdd-pipeline` 與 canonical umbrella note 的狀態保持不變，PR #3 仍
`NOT READY TO MERGE`。

## 22. 2026-07-21 R-F04 status clarification implementation

Entry-plan commit `bab1ce93aec28819a0c68a3ed7f6e85d3de53442` 先保存 owner authorization
與 Section 2.1 chronology，本節才開始 accounting-only implementation。Ledger 以新的
日期化 latest-status row 將 R-F04 明定為 `DECIDED`，並只 supersede 第 11 節 RB-4 表中的
`OPEN` label；歷史內容本身不改寫。

`DECIDED` 的精確語意仍是「退役方向已裁定、實作尚未完成」。因此 R-F04 與 R-H15 都不
是 `COMPLETED` 或 `DISPOSITIONED`，也沒有被 defer 或接受風險。R-H15 與其他 126 條
finding disposition 均不變；ledger 維持 128 條、Critical 8 / High 31 / Medium 51 /
Low 38，以及 76 COMPLETED / 45 OPEN / 6 DECIDED / 1 IN_PROGRESS。

Focused discrimination 已以 section-bounded inventory、結構化 latest-record-wins 與晚出
direct-status ambiguity scan 比較 pre-implementation parent 與 proposed tree。舊樹為
`VALID=false`：R-F04 structured status 是 `DECIDED`，但後續 direct records 又宣稱
`OPEN`；新樹為 `VALID=true`、0 ambiguities，且只有一個較新的 authoritative R-F04
`DECIDED` row 與一個 R-H15 `DECIDED` row。兩樹都解析為 128 條以及 8 / 31 / 51 / 38，
inventory 完全相同，第 22 節完全相同，deleted finding rows 為 0；新樹 fold 為
76 / 45 / 6 / 1。此檢查只校正帳務真相，不替代日後 R-F04 retirement 所需的 runtime
contract 與 negative tests。

本 implementation commit 不預填自我 hash。Dedicated note 維持 `Draft`、`TBD`、`Open`、
`Batch`，直到後續 accounting commit 引用真實 implementation hash，並使 exact accounting
tree 通過完整 governance suite、runtime、Batch、預期 Aggregate blocker 與 diff/worktree
hygiene。只有完成該 accounting sequence 後才恢復 R6 residual audit。Canonical
`sdd-pipeline` 仍 experimental、default-disabled、execution-denied；PR #3 仍
`NOT READY TO MERGE`，且本批不 retirement、不 promotion、不 push、不 merge、不 resolve
PR threads。

## 23. 2026-07-21 R-F04 final accounting 與 gate drift resolution

Implementation `180abc05b8eaaa6fb32a753e81931f14e10ef726` has the required committed-plan parent
and append-only R-F04 `DECIDED` row. Accounting preflight proved that the handoff's no-scope
`-RequireReady` command conflicts with completed R-A20: current validation rejects missing
`ReadinessScope`, while the canonical template specifies explicit Batch and CI uses Aggregate.

Owner selected Choice A on 2026-07-21. Therefore the blocking accounting contract is explicit
Batch green from immutable base `6b749a1f153dc88412714db0ed6d8708170c5936`, plus an explicit
Aggregate run whose only permitted error is the canonical `aggregate-note-not-ready`. The
no-scope command remains an expected-failing diagnostic with one `arguments` error and five
`branch-evidence-coverage-missing` records; it is not accepted as green and does not change code.

The exact accounting tree reports 747 passed / 0 failed / 0 skipped / 0 not run, runtime
`VALID=true` with 0 errors, 0 warnings, and 18/18 historical evidence, and Batch `VALID=true`
with 0 errors, 0 warnings, and 5 paths. Aggregate returns exactly the expected umbrella blocker;
diff hygiene passes. The dedicated note cites `180abc05b8eaaa6fb32a753e81931f14e10ef726`, is
`Ready` / `Closed`, and keeps validation scope `Batch`.

The five no-scope coverage paths remain concrete R-E09/Aggregate obligations and are not closed,
deferred, accepted, or absorbed by this batch. R-F04 and R-H15 remain `DECIDED` but unimplemented;
all other finding dispositions are unchanged, inventory stays 128, and the fold stays
76 COMPLETED / 45 OPEN / 6 DECIDED / 1 IN_PROGRESS. This completes only bounded status/count
truth restoration and allows the read-only residual audit to resume. `sdd-pipeline` stays
experimental, default-disabled, and execution-denied; PR #3 stays `NOT READY TO MERGE`.

## 24. 2026-07-21 R6 conservative non-promotion convergence entry plan

The owner selected Choice A after the read-only residual audit resumed from the reconciled R-F04
fold. R6 will make the branch progressively mergeable without promoting the workflow: directly
repair reachable safety and current-surface truthfulness defects, then use explicit Wave-4
dispositions for the remaining non-critical backlog. A disposition is a conditional deferral, not
implementation or unconditional risk acceptance.

The audit found two independent workflow defects, registered in ledger Section 36 as R-B25 Low
and R-B26 Medium. R-B25 is the unenforced workflow
`minStudioConstitutionVersion` compatibility field. R-B26 is the mismatch between deprecated
enablement and `sync` policy versus the workflow mutator, shared authorization and schemas. They
are not extension subcases and begin `OPEN`. The ledger is now 130 findings with severity
8 Critical / 31 High / 52 Medium / 39 Low and current fold 76 `COMPLETED` / 47 `OPEN` /
6 `DECIDED` / 1 `IN_PROGRESS` / 0 `DISPOSITIONED`.

### Authorized disposition matrix

| Destination after future evidence | IDs | Count |
|---|---|---:|
| Direct repair from OPEN | R-A21, R-B18, R-B25, R-B26, R-C04, R-C06, R-E02, R-E08, R-E11, R-G01, R-G03, R-G04, R-H03, R-H04, R-H06, R-H09 | 16 |
| Implement DECIDED item | R-D07 | 1 |
| Wave-4 disposition from OPEN | R-A13, R-B23, R-D08, R-D09, R-D10, R-D11, R-E01, R-E03, R-E04, R-E06, R-E12, R-F01, R-F02, R-F03, R-F05, R-G02, R-G05, R-G07, R-G08, R-G09, R-G11, R-G12, R-H07, R-H14, R-H18, R-I01, R-I02, R-I04, R-I05, R-I09 | 30 |
| Wave-4 disposition from DECIDED | R-D06, R-D12, R-F04, R-H15, R-I03 | 5 |
| Terminal blockers, unchanged | R-E09, R-J03 | 2 |

All 54 non-completed findings appear exactly once. No destination status is applied by this entry
plan. After future direct repairs and dispositions, but before merge, the only permitted fold is
93 `COMPLETED` / 1 `OPEN` / 1 `IN_PROGRESS` / 35 `DISPOSITIONED`. R-E09 and R-J03 may
be completed only by real umbrella, merge and post-merge evidence.

### Execution batches

1. R6-A1 governance authority and entry truth: implement R-E11, R-D07, R-E02, R-E08, R-H03
   and R-H04 together so Constitution, adapters, README and structure surfaces do not receive
   partial closure. Ledger default authority remains `informational`; only the exact
   `finding_status` selector `finding-status-record-v1` becomes `source_of_truth`. Add the dedicated
   schema and validator, a complete 130-ID revision-1 snapshot with R-E11 still OPEN, delta-only
   later revisions with unique strictly consecutive numbering, fold/index parity, BaseRef history preservation, audit integration and
   discriminating tamper tests. The runtime contract stores structural policy rather than current
   counts. Constitution moves to 1.10.0 with all three generated root adapters. R-E04 remains
   independent and is not absorbed.
2. R6-A2 feature binding: complete R-A21 and R-B18 with one repository-root resolver, explicit
   `-FeatureDir` handoffs across canonical agents, Claude mirrors and workflow messages, and a
   matcher that handles zero through multiple middle directories without near-prefix leakage.
3. R6-A3 lifecycle truthfulness: complete R-C04/R-B25 field retirement and R-C06/R-B26
   deprecated/source hardening. Extension and workflow behavior, tests and accounting remain
   independently identifiable. No change may promote `sdd-pipeline`.
4. R6-A4 documentation/configuration truth: complete R-G01, R-G03, R-G04, R-H06 and R-H09
   without editing consumer repositories. Quarantine stale guidance, restore current shared-surface
   truth, comply with Constitution Section 10.1, relocate the historical six-stage document and
   remove unsafe or stale VS Code settings.
5. R6-A5 accounting: after the implementation commits exist, append status records only for
   evidence-backed completions, then append all 35 owner-approved Wave-4 dispositions with the
   exact trigger table in ledger Section 36.2. R-B23 can be deferred only while the workflow is
   experimental, default-disabled and execution-denied; R-D12 cannot be implemented within the
   current no-consumer-drift boundary.
6. R6-A6 umbrella checkpoint: reconcile R-E09 only as far as actual evidence permits under
   permanent non-promotion, and stop for separate merge authorization. R-J03 and post-merge
   portions of R-E09 remain open before an actual merge.

Each closing finding requires a test that fails against the pre-repair implementation, passes on
the repaired implementation and is protected by a revert-sensitive runtime or document contract
invariant. R-E11 must reject missing/scopeless/ambiguous/schema-invalid/count-mismatched,
missing-revision-1, duplicate/out-of-order/non-consecutive-revision, fold-mismatched,
index-mismatched and history-rewritten ledgers. R-A21/R-B18 must reject path and
feature-boundary counterexamples. R-C04/R-B25 must reject field reintroduction. R-C06/R-B26
must reject new or stale-pin deprecated enablement and all `sync`, null and wrong-type variants.
Each direct document/configuration closure needs its own mutation that restores the stale surface
and proves the contract fails.

Implementation and accounting commits remain separate. Final accounting must pass the complete
governance suite without reducing the current 747-pass baseline, canonical runtime with
`VALID=true` and 0 errors/0 warnings, explicit Batch validation from the committed entry-plan
base, Aggregate validation with only the canonical umbrella blocker, and `git diff --check` plus
clean exact-tree worktree verification. Choice A retains explicit scopes; the obsolete no-scope
diagnostic has no acceptance authority.

The Wave-4 re-entry triggers in ledger Section 36.2 are part of this authorization and must be
copied into the status accounting records rather than replaced with a generic backlog label. The
dedicated note stays `Draft`, `TBD` and reconciliation `Open` until implementation and exact-tree
accounting evidence exist. This plan does not push, merge, promote, record post-merge success or
resolve PR threads. PR #3 remains `NOT READY TO MERGE`.

## 25. 2026-07-22 R6-A1 Claude mirror authority scope correction

Plan commit `f669e3dcd116ed8ff612b9a8875167bd5b3a3881` is the valid Constitution Section 2.1
entry plan, but R6-A1 implementation preflight found a material scope omission. Constitution 1.9.0
classifies `.claude/agents/*.md` as seeded `dependent` mirrors. The generator, 15 generated files,
Copilot adapter, both Studio quickstarts, WORKSPACE_STRUCTURE and runtime contract instead call
that directory source/runtime authority. Contract invariants actively preserve the contradiction.

R-H03 is README-specific and cannot absorb this cross-surface generator failure. Owner authorized
new High R-H20 on 2026-07-22. It begins `OPEN` and joins the direct-repair set. Historical notes are
not rewritten, R-D04 deterministic parity remains completed, and consumer repositories remain out
of scope.

| Destination after future evidence | IDs | Count |
|---|---|---:|
| Direct repair from OPEN | R-A21, R-B18, R-B25, R-B26, R-C04, R-C06, R-E02, R-E08, R-E11, R-G01, R-G03, R-G04, R-H03, R-H04, R-H06, R-H09, R-H20 | 17 |
| Implement DECIDED item | R-D07 | 1 |
| Wave-4 disposition from OPEN | R-A13, R-B23, R-D08, R-D09, R-D10, R-D11, R-E01, R-E03, R-E04, R-E06, R-E12, R-F01, R-F02, R-F03, R-F05, R-G02, R-G05, R-G07, R-G08, R-G09, R-G11, R-G12, R-H07, R-H14, R-H18, R-I01, R-I02, R-I04, R-I05, R-I09 | 30 |
| Wave-4 disposition from DECIDED | R-D06, R-D12, R-F04, R-H15, R-I03 | 5 |
| Terminal blockers | R-E09, R-J03 | 2 |

The corrected inventory is 131 findings with severity 8 Critical / 32 High / 52 Medium / 39 Low
and current fold 76 `COMPLETED` / 48 `OPEN` / 6 `DECIDED` / 1 `IN_PROGRESS`. All 55
non-completed IDs appear once. The prospective pre-merge fold becomes 94 `COMPLETED` / 35
`DISPOSITIONED` / 1 `OPEN` / 1 `IN_PROGRESS`; actual merge and post-merge evidence are required
before any 96 / 35 terminal fold.

R6-A1 now implements R-E11, R-D07, R-E02, R-E08, R-H03, R-H04 and R-H20. R-H20 must follow
authority order: reconcile Constitution semantics, generator and runtime contract source-of-truth
surfaces first; reseed all 15 mirrors and synchronize dependent adapters second; update current
informational guidance last. Machine tests must fail when authority wording is restored in the generator,
when source/dependent direction is reversed, when any current guidance reintroduces authority
wording, or when a generated mirror loses its dependent header. A positive control must retain
Claude runtime consumption and unchanged workflow denial.

R-E11 revision 1 uses the corrected 131-ID snapshot. This amendment remains plan-only: no status
other than registering R-H20 as `OPEN` changes, and the dedicated note remains Draft/Open/TBD.
Implementation and accounting commits remain separate. Final exact-tree gates, non-promotion,
consumer exclusions and R-E09/R-J03 terminal boundaries remain exactly as Section 24 defines.

## 26. 2026-07-22 R6-A1 canonical agent input partition correction

Read-only implementation preflight found 16 Markdown files under `.github/agents/`. The generator
consumes 14 `*.agent.md` files plus `async-python-reviewer.md`, skips the dependent
`copilot-instructions.md` adapter, and produces 15 `.claude/agents/*.md` mirrors. Therefore R-H20
MUST NOT describe the whole source directory with one authority classification.

Owner selected Choice A. R-H20 now requires the exact 15-source/1-dependent partition in the
Constitution, impact-registry generator and generated registry, runtime contract, current guidance
and mutation tests. The generator MUST continue excluding the adapter; every output MUST retain a
dependent-mirror header. R-D12 remains `DECIDED` and R-E04 remains independent. No consumer file,
workflow promotion state, finding count or finding status changes.

This correction is plan-only and must be committed before R6-A1 implementation resumes. The
inventory remains 131 with fold 76 `COMPLETED` / 48 `OPEN` / 6 `DECIDED` / 1 `IN_PROGRESS`.
The R6 note remains Draft/Open/TBD, and PR #3 remains `NOT READY TO MERGE`.

## 27. 2026-07-22 R6-A1 scoped accounting sequence correction

Implementation `105a09cd02f7d8b4765e49859390908e55bd97d1` now exists after the committed
R6 entry plan and both R6-A1 scope corrections. Its exact candidate tree passed 878 governance
tests with 0 failures, the staged-snapshot hook, and the committed runtime, mainline, ledger-history,
bootstrap, Claude parity and impact-registry checks with 0 errors and 0 warnings.

A sequencing drift remains in Section 24 batch A5 and the ledger narrative Section 36.3 item 5:
both defer all status accounting until A1 through A4 implementations exist. That broad final
accounting point remains correct for Wave-4 dispositions and cross-batch convergence, but it would
leave the completed R6-A1 repair and its dependent current surfaces knowingly stale while A2 through
A4 proceed. Owner Choice A authorizes a narrower A1-only accounting checkpoint now. This section
supersedes only the timing of evidence-backed R6-A1 closure; it does not weaken or pre-execute A5.

The authorized sequence is:

1. Commit this plan correction without changing a finding status.
2. In a separate accounting commit, append revision 2 to the machine finding-status ledger. Only
   R-D07, R-E02, R-E08, R-E11, R-H03, R-H04 and R-H20 may change to `COMPLETED`. The resulting
   131-item fold must be 83 `COMPLETED`, 42 `OPEN`, 5 `DECIDED`, 1 `IN_PROGRESS` and
   0 `DISPOSITIONED`; severity remains 8 Critical, 32 High, 52 Medium and 39 Low.
3. The same accounting commit must update the dependent docs index and create
   `docs/mainline-updates/2026-07-22-r6-a1-governance-authority-and-entry-truth.md` as a dedicated
   `Draft`, reconciliation `Open`, validation-scope `Batch` note. The broad R6 convergence note and
   canonical Wave-3 umbrella note remain `Draft`, `Open` and non-authorizing.
4. In a later note-only finalization commit, set only the dedicated R6-A1 note to `Ready` and
   reconciliation `Closed`, citing the real implementation, plan-correction and accounting commits.
5. Validate the final tree from base `9b83f7a5d2e8630955efdb458f0e0e9a1c367839`: runtime must be
   `VALID=true` with 0 errors and 0 warnings; the governance suite must not fall below 878 passes;
   finding-status history must contain exactly two valid revisions and the 131-item fold above;
   explicit Batch readiness must be valid with 0 errors and 0 warnings; explicit Aggregate
   readiness must fail only with the canonical `aggregate-note-not-ready` umbrella blocker; and
   diff/worktree hygiene must pass.

This correction does not account for A2 through A4, append any Wave-4 disposition, complete R-E09
or R-J03, promote `sdd-pipeline`, edit a consumer, push, merge or resolve PR threads. R6-A2 through
R6-A6 remain pending, and PR #3 remains `NOT READY TO MERGE`.

## 28. 2026-07-22 R6-A1 R-E11 re-entry revision correction

The finalization tree at `8f0dd46b3002626892d02bdf1808e68f21828005` refuted the R-E11
discriminating-test closure because its index-tampering fixture still targeted revision-1 counts and
therefore performed no mutation against revision 2. Honesty-demotion commit
`13d6b282321cf06309b02779f93fbf3a93411649` consequently appended revision 3, returned only R-E11
to `IN_PROGRESS`, and restored the dedicated R6-A1 note to `Draft` with reconciliation `Open`.

Repair commit `ea78b64fec17ee074018b9dc17abea31404f8f16` makes the affected fixtures derive the
current index marker, assert that every mutation changes the fixture, and normalize the isolated
ledger fixture to its revision-1 snapshot. Observed repair evidence is 69 ledger tests with 0
failures, 102 mainline-note tests with 0 failures, three focused runtime/mainline integration cases
with 0 failures, runtime `VALID=true` with 0 errors and 0 warnings, and valid three-revision history
for 131 findings with fold 82/42/5/2/0. A post-repair 878-test run was intentionally stopped when
this plan contradiction was discovered, so it is not closure evidence.

Section 27 items 2 and 5 describe the original two-revision path and are now historical. Owner
Choice A supersedes only their revision count and the R-E11 re-entry accounting/finalization
sequence as follows:

The dedicated R6-A1 note and its mainline index row still say that fixture repair is pending. That
prose became stale when `ea78b64fec17ee074018b9dc17abea31404f8f16` was committed. Both surfaces
remain non-authorizing because their machine states are still `Draft` and `Open`; this amendment
records the drift explicitly, and item 4 requires the revision-4 accounting commit to reconcile the
stale prose without prematurely changing either state.

1. Commit this plan-only amendment without changing a finding status or note readiness.
2. On the clean repair-and-plan tree, run the complete governance suite with at least 878 passes and
   0 failures, plus runtime, finding-history and discriminating negative checks. Revision 3 must
   remain the latest authority with 131 findings and fold 82/42/5/2/0 until those gates pass.
3. In a separate accounting commit, append revision 4. It may change only R-E11 from
   `IN_PROGRESS` to `COMPLETED`; the resulting fold must be 83 `COMPLETED`, 42 `OPEN`, 5
   `DECIDED`, 1 `IN_PROGRESS` and 0 `DISPOSITIONED`, with severity 8 Critical, 32 High, 52 Medium
   and 39 Low. Revisions 1 through 3 are immutable and must remain an exact prefix.
4. The revision-4 accounting commit must synchronize `docs/README.md`, the dedicated R6-A1 note
   and its mainline index row. The dedicated note remains `Draft`, reconciliation `Open` and
   validation scope `Batch`; the accounting commit does not itself authorize readiness.
5. A later note-only finalization commit may set the dedicated R6-A1 note to `Ready` with
   reconciliation `Closed` and its matching mainline index row to `Ready`, citing the real
   implementation, demotion, repair, plan-correction and revision-4 accounting commits. Every other
   note and index row remains unchanged.
6. Validate that finalization tree from base
   `9b83f7a5d2e8630955efdb458f0e0e9a1c367839`. Runtime must be `VALID=true` with 0 errors and
   0 warnings; the governance suite must have at least 878 passes and 0 failures; finding-status
   history must contain exactly four consecutive valid revisions, 131 findings and fold
   83/42/5/1/0; explicit Batch readiness must be valid with 0 errors and 0 warnings; explicit
   Aggregate readiness must fail only with the canonical `aggregate-note-not-ready` blocker; and
   diff/worktree hygiene must pass. Any deviation immediately returns the note to Draft and the
   affected finding to its truthful non-complete state.

Later accounting trees must preserve these four revisions plus every subsequent consecutive valid
revision; the exact-four condition applies only to the R-E11 re-entry accounting/finalization tree.
This amendment does not reopen or absorb R-D07, R-E02, R-E08, R-H03, R-H04 or R-H20, and it does
not authorize R6-A2 through R6-A6, Wave-4 dispositions, R-E09, R-J03, consumer edits, workflow
promotion, push, merge or PR-thread resolution. `sdd-pipeline` remains experimental,
default-disabled and execution-denied; PR #3 remains `NOT READY TO MERGE`.

## 29. 2026-07-22 R6-A1 finalization surface-set correction

Revision-4 accounting commit `a74a08a191b8ec1bd67b2f2b9112e2810f10959c` passes its
staged-snapshot audit and committed BaseRef history validation with exactly four consecutive valid
revisions, 131 findings, fold 83/42/5/1/0 and `HISTORY_VALID=true`. It truthfully keeps the
dedicated R6-A1 note Draft/Open, and `docs/README.md` records that current state in its dependent
human-readable prose while its machine index records revision 4.

The independent pre-finalization review then found a contradiction in Section 28 item 5. That item
allowed the finalization commit to change only the dedicated note and its matching mainline index
row. Once those surfaces become Ready/Closed, the current note-state prose in `docs/README.md`
would still say Draft/Open. That would recreate the same stale Surface Truthfulness defect recorded
in Section 41. Leaving the prose stale and silently adding a third path are both prohibited.

Owner Choice A supersedes only the Section 28 item 5 finalization file set and establishes this
sequence:

1. Commit this plan-only amendment without changing note readiness, reconciliation or finding
   status.
2. In a separate documentation-only finalization commit, modify exactly these three paths:
   `docs/mainline-updates/2026-07-22-r6-a1-governance-authority-and-entry-truth.md`,
   `docs/mainline-updates/README.md` and `docs/README.md`.
3. Set the dedicated Batch note to Ready with reconciliation Closed, set only its matching mainline
   index row to Ready, and synchronize only the dependent note-state prose in `docs/README.md` to
   Ready/Closed. The exact `finding-status-index-v1` marker must remain revision 4 with 131 findings
   and fold 83/42/5/1/0.
4. Preserve every ledger byte, all four finding-status revisions, every finding disposition, all
   other notes and all other mainline index rows. The finalization commit may cite accounting
   `a74a08a191b8ec1bd67b2f2b9112e2810f10959c` but may not claim completion of R6-A2 through R6-A6,
   R-E09, R-J03, Aggregate acceptance, promotion, merge or post-merge evidence.
5. Run the complete Section 28 item 6 exact-tree gates against the committed finalization head. Any
   deviation requires immediate Draft/Open demotion and synchronization of all three note-state
   surfaces before other work continues.

This correction changes no finding status, ledger record, workflow authorization or merge state.
`projects/`, `learning/` and `studio/workflows/` remain outside the finalization diff.
`sdd-pipeline` remains experimental, default-disabled and execution-denied; PR #3 remains
`NOT READY TO MERGE`.

## 30. 2026-07-22 R6-A1 non-self-referential R-E11 re-entry

Finalization `f0f325b41563dea5cfa5d53582fbc0c316938f02` synchronized the three paths authorized by
Section 29, but explicit Batch readiness failed with one `branch-evidence-coverage-missing` error
for `docs/README.md`. Because the same commit last touched that path and made the note Ready, its
hash could not already appear in the note's `Related Commits`. Honesty demotion
`4ce95a4ed2ce941ae2291dd1002b6c7f99bbb59a` therefore appended revision 5, returned only R-E11
to `IN_PROGRESS`, restored the dedicated note to Draft/Open and produced fold 82/42/5/2/0 across
the unchanged 131 findings.

Owner Choice A does not exempt any path or weaken `validate-mainline-notes.ps1`. Sections 28 and 29
remain historical records of the refuted four-revision sequence. This section supersedes their
terminal revision count and re-entry ordering as follows:

1. Commit this plan-only amendment without changing a finding status, note readiness or
   reconciliation state.
2. On the clean demotion-and-plan tree, run the complete governance suite with at least 878 passes
   and 0 failures, runtime with `VALID=true`, 0 errors and 0 warnings, and BaseRef history with
   exactly five consecutive valid revisions, 131 findings, fold 82/42/5/2/0 and
   `HISTORY_VALID=true`. R-E11 remains `IN_PROGRESS` until all pre-accounting gates pass.
3. In a separate revision-6 accounting commit, modify exactly the ledger, `docs/README.md`, the
   dedicated R6-A1 note and its mainline index. Revision 6 may change only R-E11 from
   `IN_PROGRESS` to `COMPLETED`, producing fold 83/42/5/1/0 with severity 8/32/52/39. Revisions 1
   through 5 must remain an exact immutable prefix.
4. The revision-6 accounting commit keeps the dedicated note Draft/Open/Batch and its mainline row
   Draft. The exact `finding-status-index-v1` marker in `docs/README.md` must record revision 6,
   131 findings and fold 83/42/5/1/0. The prose in that same row must be state-neutral: it may direct
   readers to the dedicated note and its mainline row for current readiness and retain the
   fail-and-demote boundary, but it must not assert Draft/Open, Ready/Closed or that a named
   finalization transition is still pending.
5. After committing revision 6 and obtaining its real hash, create a separate finalization commit
   that modifies exactly the dedicated note and its matching mainline index row. Set the note to
   Ready with reconciliation Closed, set that one row to Ready, and add the real revision-6
   accounting hash, this plan commit and honesty demotion
   `4ce95a4ed2ce941ae2291dd1002b6c7f99bbb59a` to `Related Commits`. All three newly added
   references must use their complete 40-character lowercase commit hashes. `docs/README.md`, the
   ledger, every other note and every other index row must remain unchanged in finalization.
6. Validate the committed finalization tree from base
   `9b83f7a5d2e8630955efdb458f0e0e9a1c367839`. The Ready note must cover the real last-touch commits
   for every non-note shared path, including the revision-6 accounting commit for the ledger and
   `docs/README.md` and this plan commit for the remediation plan. Explicit Batch readiness must
   report `VALID=true`, 0 errors, 0 warnings and no `branch-evidence-coverage-missing` result.
   Runtime must report `VALID=true`, 0 errors and 0 warnings; the complete suite must have at least
   878 passes and 0 failures; history must contain exactly six consecutive valid revisions, 131
   findings and fold 83/42/5/1/0; Aggregate must fail only with the canonical umbrella blocker;
   Claude mirrors, impact registry, bootstrap, workflow denial and diff/worktree hygiene must pass.
7. Any deviation immediately returns the note to Draft/Open and R-E11 to its truthful non-complete
   state through a new append-only revision before other work continues.

This re-entry remains wholly within R-E11 because it repairs the evidence sequence required for
that finding's completion; it does not hide an unrelated residual. R-D07, R-E02, R-E08, R-H03,
R-H04 and R-H20 remain `COMPLETED`. R6-A2 through R6-A6, Wave-4 dispositions, R-E09, R-J03,
Aggregate acceptance, workflow promotion, merge and post-merge evidence remain unchanged.
`projects/`, `learning/` and `studio/workflows/` are excluded. `sdd-pipeline` remains experimental,
default-disabled and execution-denied; PR #3 remains `NOT READY TO MERGE`.

## 31. 2026-07-23 R6-A5 trigger-bearing disposition authority and accounting sequence

R6-A2 implementation `814cc6169e6d1bf9167ce91249dbd58ac548674d`, R6-A3 implementation
`be5fb24fd79a47d8f0db9f61be2a747d06b29088` and R6-A4 implementation
`32a58e653cc4b541db88b23ad4b90fd7b81007a5` now exist. The six-record authoritative fold remains
83 `COMPLETED`, 42 `OPEN`, 5 `DECIDED`, 1 `IN_PROGRESS` and 0 `DISPOSITIONED` across 131
findings. All eleven A2 through A4 direct-repair candidates remain `OPEN`; the Wave-4 set remains
exactly 30 `OPEN` and 5 `DECIDED`.

Read-only A5 preflight found a material representation contradiction. Section 24 requires the exact
Section 36.2 re-entry triggers to be copied into status accounting records, but
`studio/runtime/finding-status-record.schema.json` permits each status entry to contain only `id`
and `status`, and `validate-finding-status-ledger.ps1` rejects every third field. The current
validator therefore accepts a triggerless `DISPOSITIONED` delta while rejecting the trigger-bearing
record required by the owner authorization. An adjacent Markdown table cannot resolve the defect:
ledger narrative is `informational`, while only canonical `finding-status-record-v1` blocks have
`source_of_truth` authority for `finding_status`.

This failure mode is not the R-E11 defect that created a single status ledger and protected its
append-only fold, index and Git history. It is an independently enforced conditional-metadata gap
discovered before the first disposition. Owner Choice A on 2026-07-23 therefore authorizes new
Medium R-E13: a `DISPOSITIONED` status can currently omit its exact owner-approved re-entry trigger,
and the authority schema cannot carry the required trigger. R-E13 requires conditional record shape,
an exact 35-ID trigger map, fail-closed validation and discriminating mutations. Revisions 1 through
6 contain no `DISPOSITIONED` entry and remain valid; R-E11 remains `COMPLETED`. R-E13 does not
become an authoritative finding until the registration record below is committed.

After registration, the all-R6 direct-repair authorization contains 19 findings: the 18 in corrected
Section 37 plus R-E13. Only 12 remain for A5 completion accounting because the seven A1 findings
are already `COMPLETED`. This section supersedes Section 37 only for inventory, severity, direct-set
count and prospective folds; every Section 36.2 trigger remains unchanged. The permitted pre-merge
fold becomes 95 `COMPLETED` / 1 `OPEN` / 1 `IN_PROGRESS` / 35 `DISPOSITIONED`; only actual
merge and post-merge evidence may produce 97 `COMPLETED` / 35 `DISPOSITIONED` across 132
findings.

The authorized sequence is:

1. Commit this plan-only amendment. It may modify only this remediation-plan file and must not
   change the ledger, a finding status, note readiness, runtime or test bytes, workflow authorization
   or merge state.
2. In a separate registration accounting commit, append revision 7 with ledger version 1.35.0 and
   register only R-E13 as Medium `OPEN`. Preserve revisions 1 through 6 as an immutable prefix. The
   resulting inventory is 132, severity is 8 Critical / 32 High / 53 Medium / 39 Low, and the fold is
   83 `COMPLETED` / 43 `OPEN` / 5 `DECIDED` / 1 `IN_PROGRESS` / 0 `DISPOSITIONED`. Synchronize
   the `docs/README.md` marker and create and index
   `docs/mainline-updates/2026-07-23-r6-a2-a5-direct-repairs-and-wave-4-dispositions.md` as a
   dedicated Draft/Open/Batch note. This registration may not change schema, validator or tests.
3. In a separate implementation commit, extend the version-1 status-entry schema and its exact
   PowerShell contract so `reentryTrigger` is required as a non-empty, non-whitespace string when
   and only when `status` is `DISPOSITIONED`. Non-disposition entries retain the exact two-key
   `id`/`status` shape. Revisions 1 through 7 remain valid without byte rewriting. The validator
   must expand the fifteen grouped Section 36.2 rows into an exact 35-ID ordinal mapping; runtime
   must not parse the informational Markdown table as authority.
4. The implementation must reject a missing, null, Boolean, numeric, array, object, empty,
   whitespace-only, generic, mismatched, swapped, duplicate or unauthorized trigger. It must also
   reject any trigger on `COMPLETED`, `OPEN`, `DECIDED` or `IN_PROGRESS`. Focused tests and a
   shared-runtime contract invariant must fail if the conditional schema, exact mapping, ordinal
   comparison or rejection logic is removed. The implementation may update only the schema,
   validator, shared runtime contract, runtime and mainline integration needed to enforce that
   contract, and their tests; it may not append a status revision.
5. Before completion accounting, run the focused trigger mutations, the complete governance suite
   with at least 958 passes and 0 failures, canonical runtime with `VALID=true` and 0 errors or
   warnings, revision-7 history with 132 findings and fold 83/43/5/1/0, and diff/worktree hygiene.
   R-B23 may be dispositioned only if the exact tree still proves `sdd-pipeline` experimental,
   default-disabled and execution-denied.
6. In one later accounting commit, append two semantically separate consecutive records. Revision 8,
   ledger version 1.36.0, changes R-A21, R-B18, R-B25, R-B26, R-C04, R-C06, R-G01, R-G03,
   R-G04, R-H06, R-H09 and R-E13 from `OPEN` to `COMPLETED`, producing fold 95/31/5/1/0.
   Revision 9, ledger version 1.37.0, changes exactly the thirty `OPEN` and five `DECIDED` IDs in
   Sections 36.2 and 37.1 to `DISPOSITIONED`, with one byte-exact `reentryTrigger` on every entry.
   The resulting fold is 95 `COMPLETED` / 1 `OPEN` / 0 `DECIDED` / 1 `IN_PROGRESS` /
   35 `DISPOSITIONED`; inventory and severity remain 132 and 8/32/53/39. R-E09 remains
   `IN_PROGRESS`; R-J03 remains `OPEN`.
7. The accounting commit must synchronize the state-neutral `docs/README.md` revision-9 marker,
   reconcile the dedicated note while keeping it Draft/Open/Batch, and keep the broad R6 convergence
   note plus the canonical Wave-3 umbrella Draft/Open. A later note-only finalization commit may
   modify only the dedicated A2-A5 note and its matching mainline index row, set only that note and
   row to Ready with reconciliation Closed, and cite complete 40-character lowercase hashes for
   this plan, registration, A2, A3, A4, trigger-contract implementation and revision-8/revision-9
   accounting commit.
8. Validate the committed finalization tree from
   `b3e7c15c2e70aebf3bd40b5a73f24285de507476`: runtime must be `VALID=true` with 0 errors and
   0 warnings; the complete suite must have at least 958 passes and 0 failures; finding history must
   contain exactly nine consecutive valid records and fold 95/1/0/1/35; explicit Batch readiness
   must be valid with 0 errors and 0 warnings; Aggregate readiness may fail only on the canonical
   umbrella; exact trigger mutations, workflow denial, `git diff --check` and clean-worktree checks
   must pass. A failed gate requires a truthful per-ID reversal in a later append-only revision for
   every claim that the evidence refutes; unaffected findings require explicit independent evidence.

This amendment authorizes no consumer edit, workflow promotion, push, merge, PR-thread resolution
or post-merge claim. `sdd-pipeline` remains experimental, default-disabled and execution-denied.
R6-A6, R-E09 and R-J03 remain pending; PR #3 remains `NOT READY TO MERGE`.

## 32. 2026-07-23 R6-A2 through A5 reconciliation-row re-entry

Note-only finalization `34c2a02d788a26cd6a1f8757e999484c76408c54` changed the dedicated
R6-A2 through A5 Batch note and its matching index row to Ready. The mandatory committed-tree
Batch gate from `b3e7c15c2e70aebf3bd40b5a73f24285de507476` then reported one
`must-update-reconciliation-missing` error for `.claude/agents/*.md`. Aggregate consequently
reported that same error plus the expected canonical `aggregate-note-not-ready` blocker.

Canonical runtime and the nine-record finding history remained valid. The R6-A2 implementation
did update the dependent Claude mirrors and the exact-tree Claude parity checks remained green.
The failed gate therefore refuted the dedicated Ready/Closed reconciliation claim, but did not
refute any revision-8 or revision-9 finding completion or disposition. Honesty demotion
`958a10233da6e5f3024d4ac851dc192f3271d137e` returned only the dedicated note and its index row
to Draft/Open before repair.

The owner explicitly authorized this bounded re-entry on 2026-07-23. The authorized sequence is:

1. Commit this plan-only amendment. It may modify only this remediation-plan file, record the
   authorization and exact re-entry gates, and must not change a finding status, note readiness,
   reconciliation state, runtime byte, test, workflow authorization or merge state.
2. In a separate documentation-only finalization commit, modify exactly
   `docs/mainline-updates/2026-07-23-r6-a2-a5-direct-repairs-and-wave-4-dispositions.md` and
   `docs/mainline-updates/README.md`.
3. Add the missing exact `.claude/agents/*.md` `must_update` reconciliation row. Its evidence must
   identify R6-A2 implementation `814cc6169e6d1bf9167ce91249dbd58ac548674d` as the commit that
   reseeded the governed dependent mirrors from the canonical GitHub agent inputs, and must retain
   Claude parity plus runtime validation as the exact-tree proof. Add this plan commit's complete
   40-character lowercase hash to `Related Commits`.
4. Set only the dedicated note to Ready with reconciliation Closed and only its matching mainline
   index row to Ready. Preserve all nine finding-status records, `docs/README.md`, the broad R6
   note, the canonical Wave-3 umbrella, every other note and every other index row byte-for-byte.
5. Validate the committed finalization tree from
   `b3e7c15c2e70aebf3bd40b5a73f24285de507476`. The complete governance suite must report at
   least 958 passes and 0 failures; canonical runtime must report `VALID=true`, 0 errors and
   0 warnings; finding history must contain exactly nine consecutive valid records, 132 findings,
   severity 8/32/53/39 and fold 95/1/0/1/35; explicit Batch readiness must report `VALID=true`,
   0 errors and 0 warnings; Aggregate readiness must fail only with the canonical Wave-3 umbrella
   `aggregate-note-not-ready` blocker. Claude parity, impact-registry validation, bootstrap
   validation, workflow execution denial, trigger mutations, `git diff --check` and exact-tree
   clean-worktree verification must also pass.
6. Any finalization-tree deviation immediately returns the dedicated note and index row to
   Draft/Open before other work continues. A failed reconciliation-only gate does not alter a
   finding status unless its evidence independently refutes that finding; any refuted per-ID claim
   still requires a later append-only status revision.
7. Only after this bounded Batch is truthfully Ready/Closed may R6-A6 begin as its separate
   checkpoint. This amendment does not authorize R6-A6 implementation, Aggregate acceptance,
   completion of R-E09 or R-J03, workflow promotion, consumer edits, push, merge, PR-thread
   resolution or post-merge claims.

`sdd-pipeline` remains experimental, default-disabled and execution-denied. PR #3 remains
`NOT READY TO MERGE`.

## 33. 2026-07-23 R6-A2 through A5 process-scoped validation re-entry

Finalization `c1ec860554a8606d3a78441e0f825449dc6cae57` repaired the missing
`.claude/agents/*.md` reconciliation row and passed the staged-snapshot audit. Its exact committed
tree also passed canonical runtime, Claude parity, agent authority partition, impact-registry
freshness and the nine-record finding history at fold 95/1/0/1/35.

The complete governance suite discovered 986 tests and returned 985 passed and 1 failed. The
single failure was
`Repository text hygiene.fails fast with the version requirement under Windows PowerShell 5.1`.
The test expected `ScriptRequiresUnmatchedPSVersion`, but this host's Windows PowerShell 5.1 has
no effective execution policy and rejected all script loading first with `UnauthorizedAccess`.
Honesty demotion `0e9574574737a578e55f01bb51f52782c96db5da` therefore returned the dedicated
note and index row to Draft/Open without changing a finding status.

Read-only diagnosis proved that an inherited process-scoped
`PSExecutionPolicyPreference=Bypass` leaves MachinePolicy, UserPolicy, CurrentUser and LocalMachine
unchanged, while the same Windows PowerShell 5.1 command reaches the intended version guard and
returns nonzero with `ScriptRequiresUnmatchedPSVersion`. This is a validation-environment
precondition, not a runtime, test or finding implementation change. No new ledger ID is introduced;
revision 8, revision 9, R-E09 and R-J03 remain unchanged.

The owner explicitly authorized this bounded process-scoped re-entry on 2026-07-23. The authorized
sequence is:

1. Commit this plan-only amendment. It may modify only this remediation-plan file and must not
   change a finding status, note readiness, runtime, test, workflow authorization, persistent
   execution policy or merge state.
2. In a separate documentation-only finalization commit, modify exactly
   `docs/mainline-updates/2026-07-23-r6-a2-a5-direct-repairs-and-wave-4-dispositions.md` and
   `docs/mainline-updates/README.md`. Add this plan commit's complete 40-character lowercase hash
   to `Related Commits`, preserve the repaired `.claude/agents/*.md` row, and set only the dedicated
   note and matching index row to Ready/Closed.
3. Preserve all nine finding-status records, `docs/README.md`, the broad R6 note, the canonical
   Wave-3 umbrella, every other note and every other index row byte-for-byte. Do not edit the
   failing test or any runtime source.
4. Run the official complete governance entrypoint on the committed finalization tree with
   `PSExecutionPolicyPreference=Bypass` set only in that test process and inherited by its child
   Windows PowerShell 5.1 process. Do not call `Set-ExecutionPolicy` for MachinePolicy, UserPolicy,
   CurrentUser or LocalMachine. The suite must discover exactly 986 tests and report 986 passed,
   0 failed, 0 skipped, 0 inconclusive and 0 not run.
5. Validate the same committed tree from
   `b3e7c15c2e70aebf3bd40b5a73f24285de507476`: canonical runtime must report `VALID=true`,
   0 errors and 0 warnings; finding history must contain exactly nine consecutive valid records,
   132 findings, severity 8/32/53/39 and fold 95/1/0/1/35; explicit Batch readiness must report
   `VALID=true`, 0 errors and 0 warnings; Aggregate readiness must fail only with the canonical
   Wave-3 umbrella `aggregate-note-not-ready` blocker. Claude parity, agent authority partition,
   impact-registry freshness, bootstrap validation, workflow execution denial, exact trigger
   mutations, `git diff --check` and clean-worktree verification must also pass.
6. Any deviation immediately returns the dedicated note and index row to Draft/Open before other
   work continues. A validation-environment failure does not alter a finding status unless
   independent evidence refutes that finding.
7. Only after this bounded Batch is truthfully Ready/Closed may R6-A6 begin as a separate
   checkpoint. This amendment does not authorize R6-A6 implementation, Aggregate acceptance,
   completion of R-E09 or R-J03, workflow promotion, consumer edits, push, merge, PR-thread
   resolution or post-merge claims.

`sdd-pipeline` remains experimental, default-disabled and execution-denied. PR #3 remains
`NOT READY TO MERGE`.

## 34. 2026-07-23 R6-A6 umbrella checkpoint and merge-authorization boundary

The owner instruction to continue work authorizes the prospective R6-A6 checkpoint defined by
Section 24 after bounded A2-A5 finalization
`501f4d7e02d17dcf7a9663a5ad60ff5d0d880cdf`. It does not authorize push, merge, force-push,
history rewrite, PR-thread resolution or post-merge accounting.

Read-only preflight at that exact head produced the following current evidence:

| Validation surface | Result |
|---|---|
| Worktree | Clean; local branch is 61 commits ahead of its remote tracking branch |
| Canonical runtime | `VALID=true`, 0 errors, 0 warnings |
| Finding-status ledger | 9 valid records, 132 findings, severity 8/32/53/39 and fold 95/1/0/1/35 |
| Batch readiness from `b3e7c15c2e70aebf3bd40b5a73f24285de507476` | `VALID=true`, 0 errors, 0 warnings |
| Aggregate readiness from `main` | Exactly one `aggregate-note-not-ready` error for `docs/mainline-updates/2026-05-05-studio-workflows-runtime.md` |
| Workflow authorization | `sdd-pipeline` remains experimental, default-disabled and execution-denied |

The Aggregate failure is therefore a single truthful umbrella-accounting blocker. No runtime,
test, finding-status or consumer change is authorized for R6-A6. The Wave-3 decision is permanent
non-promotion within this branch: `sdd-pipeline` remains unavailable for execution, and any future
promotion requires a separately governed re-entry after the applicable disposition trigger is met.

This preflight also found that the plan header had advanced to version 1.27.0 while the visible
Version History stopped at 1.25.0. The 1.26.0 and 1.27.0 rows added by this plan-only amendment
restore the already committed Section 32 and Section 33 history; they do not create a new finding
or change an existing status.

The authorized sequence is:

1. Commit this version-1.28.0 plan-only amendment as the dated R6-A6 entry evidence. This commit may
   modify only this remediation plan. It must not change an umbrella state, note index, finding
   record, runtime, test, workflow authorization or consumer path.
2. In a separate accounting-candidate commit, modify only:
   `docs/mainline-updates/2026-07-21-r6-conservative-non-promotion-convergence.md`,
   `docs/mainline-updates/2026-05-05-studio-workflows-runtime.md`,
   `docs/mainline-updates/README.md` and `docs/README.md`.
3. Keep both umbrellas Draft/Open in that accounting candidate. Add a current R6-A6 reconciliation
   section to each note, replace stale A2-A5 candidate statements with committed evidence, record
   the permanent Wave-3 non-promotion decision, and make the `docs/README.md` prose state-neutral
   while preserving the revision-9 `finding-status-index-v1` marker byte-for-byte.
4. The Aggregate note must reconcile every `main`-to-head `must_update` target: `README.md`,
   `studio/QUICKSTART.md`, `studio/SDD-QUICKSTART-GUIDE.md`, `.claude/agents/*.md`, `AGENTS.md`,
   `CLAUDE.md`, `.github/copilot-instructions.md` and `docs/README.md`. Evidence must cite the
   existing changed paths and the Ready/Closed Batch notes that already prove their exact repairs.
5. The candidate must keep R-E09 `IN_PROGRESS` and R-J03 `OPEN`. It may account only for the
   pre-merge R-E09 obligations that now have real evidence: historical note recovery,
   fresh-fixture E2E, permanent non-promotion decision, complete Batch convergence and an
   Aggregate-ready candidate. Actual merge accounting and post-merge verification remain absent.
6. After the candidate commit has a real hash, create a separate note-only finalization commit that
   modifies exactly the two umbrella notes and `docs/mainline-updates/README.md`. Set both notes and
   their matching index rows to Ready with reconciliation Closed. Replace `TBD` with complete
   40-character lowercase hashes for this plan, the accounting candidate and the material batch
   evidence. Do not edit `docs/README.md`, the finding ledger, runtime, tests or any consumer path.
7. Ready/Closed at this checkpoint means the branch evidence is coherent for owner merge review. It
   does not mark R-E09 or R-J03 complete, does not claim `Merged`, and does not itself authorize
   push, merge, promotion, PR-thread resolution or post-merge accounting.
8. On the committed finalization tree, run the official complete governance suite with
   `PSExecutionPolicyPreference=Bypass` inherited only by that suite process. It must discover
   exactly 986 tests and report 986 passed, 0 failed, 0 skipped, 0 inconclusive and 0 not run.
   Persistent MachinePolicy, UserPolicy, CurrentUser and LocalMachine execution policies must not
   change.
9. The same exact tree must pass canonical runtime with 0 errors and 0 warnings, finding history
   with exactly nine consecutive records and fold 95/1/0/1/35, Batch readiness and Aggregate
   readiness from `main` with 0 errors and 0 warnings, Claude parity, agent-authority partition,
   impact-registry freshness, bootstrap validation, workflow execution denial, trigger mutations,
   `git diff --check` and clean-worktree verification.
10. Any finalization-tree deviation immediately returns the affected umbrella note and matching
    index row to Draft/Open before other work continues. A documentation reconciliation failure
    does not change a finding status unless independent evidence refutes that finding.
11. After every gate passes, stop at the merge-authorization checkpoint and report the exact commit,
    validation results, remaining R-E09/R-J03 states and the fact that the branch has not been
    pushed or merged. Merge and post-merge closure require a separate owner instruction.

This checkpoint remains inside the canonical workspace Section 2.1 shared-only route. It excludes
`projects/`, `learning/`, workflow promotion and all external mutations. Until the finalization
tree passes every gate, both umbrellas remain Draft/Open and PR #3 remains `NOT READY TO MERGE`.

## 35. 2026-07-23 R6-A6 complete Aggregate coverage re-entry

Finalization `0470fc528a93e51160b03c0f19a340ac89582db9` passed its staged runtime
audit. Its exact committed tree then passed canonical runtime, nine-record finding history and
Batch readiness from `main`, all with 0 errors and 0 warnings. Aggregate readiness failed with
exactly 80 `branch-evidence-coverage-missing` errors and no other category.

Honesty demotion `c16f2fa02b362569de21e51692a6b9e8d0592f05` returned only the configured
Aggregate note and matching index row to Draft/Open. The R6 Batch umbrella remains Ready/Closed
because its exact Batch gate passed. No finding status, runtime behavior, test result or workflow
authorization was refuted.

An isolated diagnostic clone at the failed finalization commit reproduced all 80 errors and
resolved them to exactly twelve omitted last-touch commits:

| Missing commit | Path count | Evidence boundary |
|---|---:|---|
| `05fe6f16ec334263bc1432e18ecb4a648a6dc38b` | 1 | R6-A5 finding-status accounting |
| `105a09cd02f7d8b4765e49859390908e55bd97d1` | 16 | R6-A1 authority, adapters, current guides and shared registry truth |
| `26da9a7412d902f2dfff48df23d04662687f4a9d` | 1 | RB-5 sealed historical evidence |
| `32a58e653cc4b541db88b23ad4b90fd7b81007a5` | 1 | R6-A4 current documentation audit surface |
| `5e99ad9569cc0212212a0191193702c25f6af052` | 3 | R6-A5 trigger-bearing disposition contract |
| `6a53f6601510b58e0907ce14f3a015f6b03aea43` | 1 | R2 workflow validation implementation |
| `78c47eb0f3da7e75f3ba79943ea44f55984677a1` | 6 | RB-5 agent, authority and template implementation |
| `814cc6169e6d1bf9167ce91249dbd58ac548674d` | 32 | R6-A2 feature binding across agents, setup scripts and workflow |
| `961df61ceb42dff8f6e9b9e5dc4253e9a6bfb374` | 1 | RB-1 terminal analysis-result schema |
| `bdd27809d82a9f99fc66db0a0db3fe325d53c226` | 2 | R0 containment, license and provenance cleanup |
| `be5fb24fd79a47d8f0db9f61be2a747d06b29088` | 15 | R6-A3 extension and workflow lifecycle truthfulness |
| `cb43de50385838888eedd94b48e6c4446e255e5a` | 1 | RB-1 critical gate template boundary |

The path counts total exactly 80. The failure is an Aggregate evidence-reference omission, not a
new implementation defect: the validator rejected the incomplete Ready claim as designed. No new
finding ID is required.

The authorized re-entry sequence is:

1. Commit this version-1.29.0 plan-only amendment. It may modify only this remediation plan and
   must not change a note state, index row, finding status, runtime, test, workflow authorization or
   consumer path.
2. In a separate documentation candidate, modify only
   `docs/mainline-updates/2026-05-05-studio-workflows-runtime.md` and
   `docs/mainline-updates/README.md`. Keep the note and index row Draft/Open.
3. Add all twelve full hashes above to the Aggregate note's Related Commits field. Also cite this
   plan commit, failed finalization `0470fc528a93e51160b03c0f19a340ac89582db9`, honesty demotion
   `c16f2fa02b362569de21e51692a6b9e8d0592f05` and the candidate commit once it exists. Preserve
   every already cited valid commit.
4. Add an exact twelve-row coverage table to the Aggregate honesty-demotion section and state that
   the set was reproduced at `0470fc528a93e51160b03c0f19a340ac89582db9`. Do not weaken,
   bypass or modify `validate-mainline-notes.ps1`.
5. Validate the committed Draft candidate from `main`. Runtime, finding history and Batch must
   remain valid with 0 errors and 0 warnings. Aggregate must fail only with the canonical
   `aggregate-note-not-ready` error and must report no coverage error.
6. In a later note-only finalization, modify only the Aggregate note and its mainline index row.
   Set only that note and row to Ready with reconciliation Closed, and cite the candidate's complete
   hash. Preserve the Ready/Closed R6 Batch umbrella, `docs/README.md`, all nine finding records and
   every runtime or test byte.
7. On the exact committed finalization tree, runtime, nine-record finding history, Batch readiness
   and Aggregate readiness from `main` must all report `VALID=true`, 0 errors and 0 warnings.
   Claude parity, agent-authority partition, impact-registry freshness, bootstrap validation,
   workflow execution denial, trigger mutations, `git diff --check` and clean-worktree verification
   must pass.
8. Only after those gates pass may the official 986-test suite run with process-scoped inherited
   `PSExecutionPolicyPreference=Bypass`. It must report 986 passed, 0 failed, 0 skipped,
   0 inconclusive and 0 not run without changing a persistent execution policy.
9. Any failure immediately returns the Aggregate note and index row to Draft/Open. R-E09 remains
   `IN_PROGRESS`, R-J03 remains `OPEN`, and no push, merge, workflow promotion, PR-thread
   resolution or post-merge accounting is authorized.
10. After every gate passes, stop at the owner merge-authorization checkpoint required by
    Section 34.

This re-entry is documentation-only and remains inside Constitution Section 2.1. `projects/`,
`learning/`, consumers, workflow runtime behavior and external state remain outside scope.

## 36. 2026-07-23 R6-A6 bounded full-suite timeout re-entry

Complete-coverage finalization `0ee547da6ecc85c848fa9f647dcc548ff66dcd33` passes canonical
runtime, nine-record finding history, Batch readiness and Aggregate readiness from `main`, all with
0 errors and 0 warnings. The official governance suite discovers exactly 986 tests in 27 files
and starts with process-scoped inherited `PSExecutionPolicyPreference=Bypass`.

The validation command reaches its 2400-second tool limit before Pester emits a final summary.
Partial output proves completed green runs for multiple files, including the 1669-second
`check-speckit-runtime.Tests.ps1`, the 337-second `mainline-note-validation.Tests.ps1` and the
fresh-fixture E2E, but it cannot prove the required final counts. Honesty demotion
`d8dbdf275858d445087a39b35839566bf87697c7` returns only the Aggregate note and index row to
Draft/Open.

Post-timeout checks find no new test result XML, no residual validation process and no worktree
change. Persistent execution-policy state remains MachinePolicy `Undefined`, UserPolicy
`Undefined`, Process `Undefined`, CurrentUser `Undefined` and LocalMachine `RemoteSigned`. The
timeout does not reveal a test defect and does not justify a finding ID or acceptance relaxation.

The authorized suite-only re-entry is:

1. Commit this version-1.30.0 plan-only amendment. It may modify only this remediation plan. No
   note state, test, runtime, ledger, workflow authorization, consumer or persistent policy may
   change.
2. In a separate note-only finalization, modify only
   `docs/mainline-updates/2026-05-05-studio-workflows-runtime.md` and
   `docs/mainline-updates/README.md`. Add this plan commit and honesty demotion
   `d8dbdf275858d445087a39b35839566bf87697c7` to Related Commits, then restore only the
   Aggregate note and matching index row to Ready/Closed.
3. Run the official unchanged entrypoint
   `pwsh ./studio/scripts/powershell/run-governance-tests.ps1 -Output Minimal` on that exact
   committed tree with a bounded 4500-second tool timeout. The only process environment override
   is inherited `PSExecutionPolicyPreference=Bypass`.
4. Do not call `Set-ExecutionPolicy`. Capture all five persistent execution-policy scopes before
   and after the suite, remove the process environment override after the child exits, and require
   the before and after values to match exactly.
5. The suite must discover exactly 986 tests and emit a complete final result of 986 passed,
   0 failed, 0 skipped, 0 inconclusive and 0 not run. A partial output, timeout, missing summary or
   different count is not acceptable.
6. After the suite completes, re-run canonical runtime, nine-record finding history, Batch
   readiness and Aggregate readiness from `main`; each must report `VALID=true`, 0 errors and
   0 warnings. Historical evidence must remain 18 of 18 valid.
7. Claude parity, agent-authority partition, impact-registry freshness, bootstrap validation,
   workflow execution denial, trigger mutations, `git diff --check`, ignored-artifact containment
   and clean-worktree verification must pass on the same exact tree.
8. Any failure immediately returns the Aggregate note and index row to Draft/Open without changing
   a finding status. R-E09 remains `IN_PROGRESS`, R-J03 remains `OPEN`, and no push, merge,
   workflow promotion, PR-thread resolution or post-merge accounting is authorized.
9. After every gate passes, stop at the owner merge-authorization checkpoint required by
   Section 34.

This re-entry changes only the validation time allowance needed by the observed environment. It
does not weaken, skip or modify any governance test or acceptance count.
