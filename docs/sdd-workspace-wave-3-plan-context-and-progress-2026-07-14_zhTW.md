---
title: "SDD-WorkSpace Wave 3 計畫脈絡與進度總覽（2026-07-14）"
version: "1.0.0"
date: "2026-07-14"
language: "zh-TW"
status: "context record"
authority: "informational"
branch: "feature/wave-3-security-and-workflows"
base_commit: "c6ee1f1 (main)"
head_commit: "50ce886"
open_findings_ledger: "docs/sdd-workspace-repair-inventory-and-update-plan-2026-07-12_zhTW.md"
remediation_plan: "docs/sdd-workspace-wave-3-remediation-plan-2026-07-14_zhTW.md"
scope: "彙整 2026-07-08 至 2026-07-14 的 wave-3 修復戰役完整脈絡：原始目的、事件時間線、已完成批次與 commit 對照、被推翻重開的宣稱、未完成批次與估算、目前狀態快照與決策點。"
purpose: "讓任何後續 session（人或 agent）不需重讀全部歷史文件即可接手：知道為什麼做、做到哪裡、哪些宣稱曾被推翻、下一步等待什麼決策。"
---

# SDD-WorkSpace Wave 3 計畫脈絡與進度總覽（2026-07-14）

## 0. 本文件定位（單一真相聲明）

本文件 authority 為 `informational`，是 head `50ce886` 時間點的脈絡快照。它彙整脈絡、
不產生新事實，也不得作為驗收來源。正式來源如下：

| 主題 | 單一真相 |
|---|---|
| Open findings 與各項狀態 | `docs/sdd-workspace-repair-inventory-and-update-plan-2026-07-12_zhTW.md`（repair ledger，現為 v1.6.0） |
| 後續批次計畫（RB-1 至 R6） | `docs/sdd-workspace-wave-3-remediation-plan-2026-07-14_zhTW.md` |
| Re-review findings（12 條 RVR） | `docs/sdd-workspace-wave-3-governance-review-2026-07-14_zhTW.md` |
| 各批次驗收與影響 | `docs/mainline-updates/` 對應 note |
| 機器驗收 | `pwsh ./studio/scripts/powershell/check-speckit-runtime.ps1 -Json` 與 governance Pester suite |

若本文件與上述來源不一致，以上述來源為準。後續狀態變化依 `docs/README.md` 慣例以日期化
增補或新記錄呈現，不靜默改寫本文件。

## 1. 原始目的

原始目的有兩層，全部批次的取捨都以此為準：

1. **治理閉環展示**：本 workspace 是單人 AI 工程工作室的治理 monorepo（studio-first 深度
   客製的 spec-kit），賣點是「機器驗證的 SDD 治理閉環」——憲法、runtime contract、
   canonical audit、pre-commit hook、Pester suite、CI 形成一條可稽核的鏈。
2. **求職 portfolio**：這個 repo 是 owner 求職（AI/LLM 與平台/DevOps 方向）最重要的展示
   武器。目標是共享層有一次「全面、乾淨、最新最好」的更新，最終乾淨合併回 `main`。

因此 2026-07-14 re-review 的「NOT READY TO MERGE」判定與目的一致而非相反：宣稱以治理閉環
為賣點的 repo，若 `completed` 不等於真正完成、綠燈可被假證據通過，對面試方反而是負分。
修復方向是把 findings 收斂到「綠燈能證明治理宣稱」，而不是儘快讓燈變綠。

## 2. 事件時間線（2026-07-08 至 2026-07-14）

| 日期 | 事件 | 證據 / 產物 |
|---|---|---|
| 07-08 | 全面深度評估 session | `docs/sdd-workspace-deep-review-2026-07-08_zhTW.md` |
| 07-11 | 目的/治理/維護分析；wave-3 原始修復進行中（extension 加固、governance CI 等） | `docs/sdd-workspace-purpose-governance-maintenance-usage-analysis-2026-07-11_zhTW.md`；notes `extension-lifecycle-hardening`、`governance-ci` |
| 07-12 | wave-3 原始 13 commits（`b01c366` 至 `60768f3`）接受第一次治理 review；求職視角深度分析 | `docs/sdd-workspace-wave-3-governance-review-2026-07-12_zhTW.md`；`docs/sdd-workspace-deep-analysis-and-career-value-2026-07-12_zhTW.md` |
| 07-12 | 建立 repair ledger（初版 95 條，後重算 109 條），兼作 open-findings 單一總帳 | ledger v1.0.0 至 v1.1.0 |
| 07-13 | Owner 裁定 18 項決策；R0 止血批（vendored 移除、LICENSE、catalog 降級、個資防線） | ledger 第 6、11 節；commits `bdd2780` + `41ac498` |
| 07-13 | R1 驗證可信度 + 遠端 merge enforcement（audit fail-closed、note 狀態機、CI、main ruleset） | commits `e543f6a`、`f601685`、`e4fa153`（docs `e738b41`、`1129b7e`）；ruleset `18842326` |
| 07-13 | R2 啟動：R-B06 dispatch/context 部分修復（PR #3 兩個 review threads） | commits `29adc67` + `ccb7738` |
| 07-13 | 對 R-B06 修復做唯讀獨立驗證（第四輪）：修復屬實、threads 可維持 resolved；發現 4 條新 findings | ledger v1.4.0、第 14 節（R-A15/A16/B17/B18） |
| 07-14 | R2 驗證加固批：hook UTF-8 fail-closed、feature rebind 防護、contract 多行 token | commits `df31106` + `b672911` |
| 07-14 | R2 主批：workflow engine 執行完整性（13 條 R-B findings 的剩餘部分） | commits `6a53f66` + `04e4287`；ledger v1.5.0 |
| 07-14 | 第三方治理 re-review：26 commits、551 檔案、12 條 RVR findings，判定 NOT READY TO MERGE；其中兩條以本地反例推翻先前 COMPLETED 宣稱 | `docs/sdd-workspace-wave-3-governance-review-2026-07-14_zhTW.md` |
| 07-14 | 制定後續修復計畫（R2.1 + RB-1 至 RB-5 + R6） | `docs/sdd-workspace-wave-3-remediation-plan-2026-07-14_zhTW.md` |
| 07-14 | 執行 R2.1 誠實性還原（docs-only）：重開 R-B02/R-B05、登錄 9 條新 findings、note 降級 | commits `2b7681d` + `50ce886`；ledger v1.6.0 |

## 3. 已完成批次（commit 對照）

| 批次 | 主要內容 | implementation / accounting commits | 關閉項 | mainline note 現況 |
|---|---|---|---|---|
| Wave-3 原始修復（review 前 13 commits） | selective alignment（path-traversal 加固 + workflow runtime）、governance CI、extension 加固、analyze gate、agent conformance、workflow engine 首輪修復 | `b01c366`、`6e80ed0`、`6e858d4`、`6e8df83`、`60556ef`、`78893e2` 等 | 屬 ledger 建立前的工作 | `extension-lifecycle-hardening`、`governance-ci` 為 Ready；`workflow-engine-completion-integrity`、`agent-conformance-and-doc-drift`、`analyze-completion-gate` 三份被 GOV-02/04/05 推翻，R1 時降為 Draft |
| R0 決策基線與止血 | 移除 392 檔無授權 vendored snapshot、root MIT + THIRD_PARTY_NOTICES、workflow catalog 降級 experimental、staged-path 個資防線、閒置資產清理、noreply 身分 | `bdd2780` + `41ac498` | 15 條 COMPLETED（R-G13、R-A14、R-B09、R-H01/H02/H05/H08/H11/H12/H13/H17、R-G10、R-I07/I08、R-J02） | Ready |
| R1 驗證可信度與 merge enforcement | audit `$warnings` 假綠與 registry 升格 fail-closed、`.github/agents` 封閉清單、PS7 fail-fast、BOM/LF 收斂、note 狀態機、change-manifest 退役、CI hardening、main ruleset `18842326`（要求 PR + strict `audit-and-tests`） | `e543f6a`、`f601685`、`e4fa153`（docs `e738b41`、`1129b7e`） | 20 條 COMPLETED（R-A01 至 A12、R-E05、R-E10、R-G06、R-H10/H16/H19、R-I06、R-J01） | Ready |
| R2 部分：R-B06 dispatch/context | script child `pwsh` 固定 ProjectRoot cwd；setup-plan / prerequisites 支援 explicit `FeatureDir`；pipeline 與 handoff 綁定同一 feature context | `29adc67` + `ccb7738` | R-B06 部分（獨立驗證確認，PR threads 維持 resolved） | Ready |
| R2 驗證加固 | pre-commit 強制 UTF-8 解碼 fail-closed（修 CP950 console 個資 gate 靜默 fail-open）、engine 拒絕 `-Inputs` feature 覆蓋 + resume 竄改驗證、contract 錨定多行 token | `df31106` + `b672911` | R-A15、R-A16、R-B17 COMPLETED；R-B18 保持 OPEN | Ready |
| R2 主批：engine 執行完整性 | RunState 移至 `<project>/.workflow/runs/<feature>/` 並 git-ignore、DryRun sidecar、duplicate step-id 拒絕、gate fail-closed + terminal rejected（exit 44）+ `-Restart`、replay history 去重、runner 授權消費 + executed workflow.yml 身分綁定、fixture 隔離；提交前 3 代理對抗 review 抓到 5 缺陷同批修復；suite 361 passed / 0 failed | `6a53f66` + `04e4287` | 11 條 COMPLETED（R-B01/B03/B04/B06/B10 至 B16）；R-B02/B05 後被推翻重開（見第 4 節） | Draft（被 RVR-01/03 重開，含 Revalidation） |
| R2.1 誠實性還原（docs-only） | 重開 R-B02/R-B05 為 IN_PROGRESS、登錄 12 條 RVR 為 9 條新 findings（ledger 114 增至 123）、engine-integrity note 降 Draft、建立 R2.1 note 與索引；提交前另由 2 個獨立代理做 session 內對抗驗證，抓到殘留 over-claim（3 處過期「110 條」計數、note Impact 兩句現在式 closure 保證）並於提交前修正——此驗證過程僅在本脈絡記錄留痕、未另行入 ledger，與 `df31106` 批次記錄的 2 代理 review 是不同事件；不改任何 runtime 位元組 | `2b7681d` + `50ce886` | 無 closure（純帳務還原） | Ready |

## 4. 曾被推翻並重開的宣稱

依憲法 Surface Truthfulness 與 note 狀態機 Reopened 規則，被後續證據推翻的 Ready/COMPLETED
宣稱必須降級還原，這在本戰役發生過兩輪：

1. **2026-07-12 review 推翻 wave-3 原始三份 notes（GOV-02/04/05）**：部分改動 `tasks.md`
   仍可 completed、direct Implement 可繞 setup gate、Specify 臆測 material unknowns。三份
   notes 於 R1 降為 Draft，修復排入 R2/R3 範圍。
2. **2026-07-14 re-review 推翻 R2 主批兩項 closure**：

| 項目 | 先前宣稱 | 反例（本地復現） | 現況 |
|---|---|---|---|
| R-B02 假完成防護 | COMPLETED（terminal `no-pending-tasks` postcondition） | RVR-01：進入 Implement 後把 `tasks.md` 換成任意非 task 文字，resume 仍 `completed`；postcondition 只驗「找不到 pending regex」，未保存/比對 baseline task-ID inventory | IN_PROGRESS，closure 移交 R-B19（RB-1） |
| R-B05 runner fail-closed 授權 | COMPLETED（catalog/state/manifest 授權檢查） | RVR-03：`[bool]'false'` 為 `True`、未套 catalog/state schema、`state.json` 缺失沿用 default 而非拒絕 | IN_PROGRESS，closure 移交 R-B20（RB-1） |

教訓已入帳：後續每批的 Ready 宣稱都必須以「舊實作會失敗」的 negative tests 佐證，且
RB-3 會先修「驗證器本身會漏」的問題（RVR-05/06），避免修復再以假綠合併。

## 5. 未完成批次（等待授權，逐批執行）

以下依 `docs/sdd-workspace-wave-3-remediation-plan-2026-07-14_zhTW.md` 排序；截至 head
`50ce886` 全部未開始，且每批需 owner 授權後才動工。

| 順序 | 批次 | 涵蓋（RVR 對映 ledger） | 主要修復內容 | 粗估 |
|---|---|---|---|---|
| 1 | RB-1 止血（Critical） | RVR-01（R-B19）、RVR-02（R-D02 + R-B08）、RVR-03（R-B20） | terminal Implement 保存 baseline canonical task-ID 集合、完成條件改「baseline 全存在且全勾選」；`/speckit.implement` 首步接不可繞過的 gate（readiness/ECI/analyze machine-readable result）；runner 套 schema `Test-Json` + 嚴格布林解析 + missing-state fail-closed | 2.5 至 3.5 天 |
| 2 | RB-2 執行身分與 routing | RVR-04（R-B21）、RVR-07（R-B07 + R-B22） | workflow.yml content digest 綁定 approval 與 RunState、graph mismatch 拒絕 resume；ECI 驗四件 dossier、re-entry 後真正二次 readiness routing、矛盾 status 依 exactly-one fail-closed | 2 至 3 天 |
| 3 | RB-3 合併證據完整性 | RVR-05（R-A17）、RVR-06（R-A18） | `sharedGatePaths` 改 category-complete 路徑規則 + `--name-status` 保留 rename 舊新路徑；Ready-note validator 驗 commit 真實存在且屬本次 diff、PR 屬正確 repo、required sections 齊備 | 1.5 至 2.5 天 |
| 4 | RB-4 extension / consumer / upgrade 邊界 | RVR-08（R-C01/02/05/07 + R-C08）、RVR-09（R-A19）、RVR-11（R-F06） | extension scope 全路徑驗證、approval 綁 content hash、validate-before-mutate + rollback、state change 使 mirror 失效；worktree-safe hooks、junction 內容不入 fresh consumer `git status`；upgrade 改 staging + atomic promote | 3 至 4 天 |
| 5 | RB-5 agent / authority / process 真實性 | RVR-10（R-D01/D04/D05）、RVR-12（R-E07 + R-E09） | Specify agent 矛盾修正、Claude mirror parity 進 canonical audit、tool mapping fail-loud；憲法明文化 self-application 例外或補 canonical SDD evidence；主 note 帳務對齊 | 2 至 3 天 |
| 6 | R6 終點 | R-B09、R-E09、R-E11、R-J03 + re-review 第 9.2 節 12 項 minimum gates | fresh fixture 完整跑七階段（含 ECI re-entry、非 READY routes、reject/restart、terminal completion）並保存證據；全部通過才重新 promotion `sdd-pipeline`；合併 `main` 後以同一套 audit + Pester + negative + E2E 重跑 | 2 至 4 天 |

RB 批次之外，原 ledger 仍有未被吸收的 backlog：

- **R-B18**（sibling `-FeatureDir` 邊界等級與非 plan handoff）保持 OPEN，屬原 R2/R3 範圍。
- **原 R5 主題**（authority/文件/上游 Wave-4 對齊/知識迴路，含 R-E、R-F、R-G、R-H、R-I 各區
  剩餘 Medium/Low 與 R-D12 等 DECIDED 未實作項）除 R-E07/R-E09 已由 RB-5 + R6（RVR-12）吸收
  外，未被 RB 批次吸收，仍照 ledger 第 5 節排程。
- 估算關係：RB-1 至 R6 粗估約 14 至 22.5 人天；原 ledger 全量收斂粗估 21 至 35 人天。RB 批次
  吸收了原 R3/R4 的部分範圍，兩組估算區間部分重疊，不可直接相加；工期均為重新估算區間，
  不是承諾值。
- 若時間壓力大，最小可展示子集為 **R2.1 + RB-1 + RB-3**：子集全量估 4.5 至 6.5 天，其中
  R2.1（0.5 天）已完成，剩約 4 至 6 天，足以對面試方誠實展示「發現、承認、修復、驗證」的
  完整治理迴圈。

## 6. 目前狀態快照（head `50ce886`）

| 面向 | 狀態 |
|---|---|
| 分支 | `feature/wave-3-security-and-workflows` 領先 `main`（`c6ee1f1`）28 commits，與 origin 同步；本文件與其 `docs/README.md` 索引列在此快照之後同批提交，除此之外工作樹乾淨 |
| 合併判定 | **NOT READY TO MERGE**（2026-07-14 re-review 判定；RB-1 至 R6 關閉前維持） |
| Ledger | v1.6.0，共 123 條 findings：Critical 8 / High 28 / Medium 49 / Low 38（機器重數） |
| 機器閘門 | canonical audit `VALID=true` 0 errors / 0 warnings；notes validator `VALID`；governance suite 361 passed / 0 failed（R2 主批基準，R2.1 未動 runtime）；PR #3 hosted CI 於已推 commits 綠 |
| main 保護 | active ruleset `18842326`：要求 PR + strict `audit-and-tests`，禁止 deletion / non-fast-forward |
| sdd-pipeline | 維持 `experimental` / 非 approved / default-disabled，runner 決定性拒絕，直到 R6 重新 promotion |
| Wave-3 notes | Ready：`r2-1-truth-restoration`、`r2-verification-hardening`、`r2-r-b06-dispatch-consistency`、`r1-validation-and-merge-enforcement`、`r0-containment-and-source-cleanup`、`extension-lifecycle-hardening`、`governance-ci`；Draft：`r2-workflow-engine-integrity`（被 RVR-01/03 重開）、2026-07-12 的三份歷史 notes（被 GOV-02/04/05 重開），以及 wave-3 主 note `2026-05-05-studio-workflows-runtime`（建立以來即 Draft/TBD，closure 綁 R6 / R-E09，即 RVR-12 的錨點） |

## 7. 決策點與下一步

1. 目前唯一等待的是 owner 對下一批的授權。計畫順位是 **RB-1**（Critical：假完成、mandatory
   gate 繞道、授權 fail-open），完成後依序 RB-2 至 RB-5、R6。
2. 替代路徑：先做 RB-3（讓驗證器與 Ready 帳務可信）再回 RB-1，或採最小子集
   R2.1 + RB-1 + RB-3。計畫建議仍以 RB-1 優先，因其三條都是 Critical。
3. 每批完成的固定收尾：negative tests（舊實作失敗、新實作通過）、audit 0/0、Pester 全綠、
   `git diff --check`、mainline note 與 ledger 回填 commit hash；若後續證據推翻 Ready，依
   狀態機降級，不靜默維持。

## 8. 已知限制

1. 本文件是 head `50ce886` 的時間點快照；數字與狀態出自 ledger v1.6.0 與 remediation plan
   v1.0.0，後續變化以那兩份文件為準。
2. 所有工期為粗估區間，實作時依當下證據調整。
3. 範圍延續 owner 裁定：排除 `projects/` 與 `learning/` consumer 內部 drift（R-D12 與 R-J03
   fresh-fixture 為受控例外）。
4. 本文件不改變任何 finding 狀態、note 狀態或 runtime 行為。
5. 本文件及其 `docs/README.md` 索引列在 `50ce886` 之後才提交入庫；第 6 節快照描述的是截至
   `50ce886` 的已提交狀態。第 3 節 R2.1 列所述的 session 內對抗驗證是本脈絡記錄的留痕，
   未另行入 ledger。

## 9. Version History

| Version | Date | Change |
|---|---|---|
| 1.0.0 | 2026-07-14 | 初版：彙整 2026-07-08 至 07-14 wave-3 戰役完整脈絡，含已完成批次 commit 對照、被推翻宣稱、未完成批次估算與決策點 |
