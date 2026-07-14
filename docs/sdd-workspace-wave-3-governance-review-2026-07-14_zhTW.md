---
title: "SDD-WorkSpace Wave 3 分支治理導向 Re-review"
version: "1.0.0"
date: "2026-07-14"
language: "zh-TW"
status: "review-record"
authority: "informational"
branch: "feature/wave-3-security-and-workflows"
target_branch: "main"
base_commit: "c6ee1f1fcf2eda0b517e1e8d1518d0332563ffb6"
head_commit: "04e4287"
review_range: "main...HEAD"
commit_count: 26
changed_files: 551
insertions: 13369
deletions: 81362
review_mode: "read-only evidence-based governance re-review; this record was written after the reviewed snapshot"
related_records:
  - "docs/sdd-workspace-wave-3-governance-review-2026-07-12_zhTW.md"
  - "docs/sdd-workspace-repair-inventory-and-update-plan-2026-07-12_zhTW.md"
---

# SDD-WorkSpace Wave 3 分支治理導向 Re-review

## 1. 結論

目前不建議將 `feature/wave-3-security-and-workflows` 合併到 `main`。

使用者原先描述分支領先 24 commits；實際檢查本地 `main`、`origin/main` 與 `HEAD` 後，
review 範圍是 26 commits、551 個 changed paths、13,369 行新增與 81,362 行刪除。
大量刪除主要來自第三方快照、備份與過時資產清理；本次已將這些刪除納入來源權威、
授權邊界與可稽核性檢查，而不是只檢查新增程式。

現有機器驗證全部通過：

- Shared runtime audit：`VALID=true`、`ERROR_COUNT=0`、`WARNING_COUNT=0`
- Branch mainline-note reconciliation：`VALID=true`、`ERROR_COUNT=0`
- Pester：361 passed、0 failed、0 skipped
- `git diff --check main...HEAD`：通過
- Review 完成時工作樹：乾淨

但針對完成證據、entrypoint 真實路徑、registry authorization、resume identity、mainline
changed-path closure、Ready-note evidence、ECI re-entry、extension trust、worktree isolation 與
agent mirror parity 的反例驗證，仍確認多個 Critical / High findings。部分 findings 是 repair
ledger 已誠實保留到 R3 至 R6 的已知事項；另有多項是本輪新發現，會推翻 R1 / R2 部分
`Ready` 或 `Completed` 宣稱。

因此目前綠燈只能證明既有測試契約通過，不能證明此分支已滿足專案治理目的：

- mandatory stages 無法被直接入口繞過
- `completed` 等於原始 task inventory 逐項完成
- execution authorization 與 canonical registry 使用同一判準
- RunState 對應同一份受審 workflow graph
- 每一個 shared-layer merge 都有真實、可追溯的帳務與 evidence
- generated / dependent artifacts 不會壓過 source of truth
- consumer 專案與 worktree 不會互相改變治理狀態

## 2. Authority 與治理基準

本次 review 依下列 authority order 執行：

1. `studio/constitution/constitution.md`，版本 1.8.0
2. `.specify/memory/constitution.md`，workspace root 不存在
3. `AGENTS.md` 與其他 runtime adapters

主要判斷基準如下：

| Constitution Area | Review 判準 |
|---|---|
| Section 2 | 七階段必須依序完成，不得跳階 |
| Sections 5、5.1 | Readiness exactly-one status、ECI 四件 dossier、readiness re-entry |
| Section 8 | Critical findings 與 Intent Drift Check 必須阻擋 implement-ready outcome |
| Section 9 | Implementation 必須依 `tasks.md` exactly 執行 |
| Section 10 | Agent 不得臆測 material unknowns 或建議跳過 mandatory stage |
| Section 12 | Authority chain、surface truthfulness、mainline notes、shared-layer acceptance |
| Section 13 | Knowledge capture 與 reusable asset extraction |

本記錄的 authority 是 `informational`。它保存 review evidence 與判斷，不取代 constitution、
runtime contract、script、schema、agent source 或 tests。

## 3. Review 範圍與方法

| Area | Reviewed Surface |
|---|---|
| Git scope | `main...HEAD` 的 26 commits 與 551 changed paths |
| Workflow runtime | engine、runner、catalog/state、schemas、manifest、RunState、built-in pipeline |
| SDD gates | Specify、Clarify、Readiness、ECI、Plan、Tasks、Analyze、Implement entrypoints |
| Governance enforcement | contract、impact registry、pre-commit、mainline-note validator、GitHub Actions |
| Agent authority | `.github/agents/` source、`.claude/agents/` seeded mirror、bootstrap/parity |
| Extensions | add/remove/enable/export、manifest scope、approval continuity、merged mirror |
| Consumer isolation | init、worktree、hooksPath、junction、project template ignore policy |
| Upgrade path | snapshot apply、audit sequencing、rollback semantics |
| Documentation | mainline notes、repair ledger、README、QUICKSTART、workspace structure |
| Verification | Canonical audit、361 Pester tests、diff check、targeted negative probes |

方法不是只搜尋 bug；每一項變更同時從以下問題檢查：

1. 它是否提高可重複、可預測、可維護的交付能力。
2. 它是否忠實反映 source-of-truth 與 dependent artifact 關係。
3. 它是否 fail-closed，或只是依賴使用者先執行另一支 validator。
4. 它保存的 evidence 能否證明宣稱，而不是只通過字串或 shape 檢查。
5. 它是否讓 consumer、worktree、extension 或 generated mirror 反向污染 canonical runtime。
6. 文件與 mainline note 是否誠實揭露現有 coverage、disabled 狀態與未完成義務。

## 4. 驗證證據

### 4.1 Git scope

| Check | Result |
|---|---|
| Current branch | `feature/wave-3-security-and-workflows` |
| Local `main` | `c6ee1f1fcf2eda0b517e1e8d1518d0332563ffb6` |
| `origin/main` | 與 local `main` 相同 |
| Reviewed HEAD | `04e4287` |
| Ahead count | 26 |
| Changed files | 551 |
| Insertions / deletions | 13,369 / 81,362 |

### 4.2 Canonical and hosted-equivalent checks

| Command / Surface | Result |
|---|---|
| `check-speckit-runtime.ps1 -Json` | `VALID=true`，0 errors，0 warnings |
| `validate-mainline-notes.ps1 -BaseRef main -HeadRef HEAD -RequireReady -Json` | `VALID=true`，551 changed paths |
| `run-governance-tests.ps1 -Output Normal` | 361 passed，0 failed，0 skipped |
| `git diff --check main...HEAD` | Pass |

### 4.3 Targeted counterexamples

| Probe | Observed Result |
|---|---|
| 以非 task 文件執行 `no-pending-tasks` postcondition | 回傳 satisfied |
| PowerShell `[bool]'false'` | `True` |
| 只變更未列入 `sharedGatePaths` 的 `add-extension.ps1`，不加 note | `-RequireReady` 仍 `VALID=true` |
| Rename governed workflow doc 到非 governed path，不加 note | Branch validator 仍 `VALID=true` |
| Ready note 使用不存在的 `deadbee` commit | Validator 仍接受 concrete evidence |
| 清空一份 `.claude/agents` mirror 內容 | Canonical audit 仍 `VALID=true` |
| Extension entry point 使用 normalized cross-scope path | Validator 接受，export 落到另一 scope |
| 建立不同深度的新 worktree | Source repository 共用 `core.hooksPath` 被改寫 |

這些 probe 說明目前測試的主要盲點不是執行環境偶發失敗，而是測試沒有詢問治理宣稱所需
的反例。

## 5. Findings Summary

| ID | Severity | Novelty | Area | Summary |
|---|---|---|---|---|
| RVR-01 | Critical | New | Workflow completion | 刪除 task inventory 仍能讓 terminal Implement 完成 |
| RVR-02 | Critical | Known + independently confirmed | Mandatory gates | Direct Implement 仍可跳 readiness、ECI、Analyze |
| RVR-03 | Critical | New | Workflow authorization | Runner 未驗 schema，registry 可 fail-open |
| RVR-04 | High | New | Run identity | Resume 與 fresh execution 未綁定受審 workflow graph |
| RVR-05 | High | New | Mainline enforcement | 多數 shared scripts/hooks 與 rename source 不在 aggregate gate |
| RVR-06 | High | New | Merge evidence | Ready note evidence 只有字串 shape，未驗真實來源與必要 sections |
| RVR-07 | High | Known + new subcase | Readiness / ECI | 無 full dossier、無 readiness re-entry、exactly-one 未強制 |
| RVR-08 | High | Known + new subcases | Extensions | Scope、approval、mutation、mirror 與 canonical registry 未可靠綁定 |
| RVR-09 | High | New | Consumer isolation | Worktree hooks 與 agent junction 可污染其他執行面 |
| RVR-10 | High | Known + independently confirmed | Agent runtime | Specify 規則矛盾，Claude mirror parity / authority 未實質驗證 |
| RVR-11 | High | New | Runtime upgrade | Upgrade 先覆寫後 audit，失敗不 rollback |
| RVR-12 | High | Known governance gap | Delivery process | 26 commits 無 canonical SDD evidence，主 note 仍 Draft/TBD |

## 6. Critical Findings

### RVR-01：刪除 task inventory 仍可讓 workflow 假完成

**位置**：

- `studio/scripts/powershell/workflow-engine.ps1:385-393`
- `studio/scripts/powershell/workflow-engine.ps1:524-539`
- `studio/scripts/powershell/workflow-engine.ps1:668-674`
- `studio/workflows/sdd-pipeline/workflow.yml:181-189`

`no-pending-tasks` 只搜尋尚未勾選的 `T\d+`。它不保存 Implement 開始前的 task-ID set，
也不要求完成後仍保留相同 task inventory。因此只要 `tasks.md` 是非空檔案、hash 有改變，
且內容不再含未勾選 task，terminal step 就能成功。

可重現情境：

1. 進入 Implement 時 `tasks.md` 有合法 pending tasks。
2. Agent halt 後，把檔案改為只有標題或任意非空說明。
3. Resume 時 artifact hash 已改變。
4. Pending regex 回傳 0。
5. Postcondition satisfied，`stage-implement` 加入 `completed_steps`。
6. 先前完成的 prep step 被 replay idempotency 跳過，run 最後標為 completed。

這重新打開 repair ledger 的 R-B02，並推翻
`docs/mainline-updates/2026-07-14-r2-workflow-engine-integrity.md` 對 false completion closure 的
宣稱。治理上需要的是「原始 task IDs 全部仍存在且已完成」，不是「檔案內找不到 pending
regex」。

現有 `workflow-engine.Tests.ps1` 只測部分勾選與全部勾選，未測刪 task、改 ID、破壞
canonical line format 或以非 task 文字取代整份文件。

### RVR-02：Direct Implement 仍可跳過 mandatory gates

**位置**：

- `.github/agents/speckit.implement.agent.md:21`
- `.claude/agents/speckit-implement.md:24`
- `studio/scripts/powershell/setup-implement.ps1:158-162`
- `studio/scripts/powershell/validate-feature-structure.ps1:108-159`
- `studio/tests/stage-entry-gates.Tests.ps1:282-295`

Canonical Implement agent 的第一步仍是一般 `check-prerequisites.ps1`，不是
`setup-implement.ps1`。因此直接呼叫 `/speckit.implement` 不會經過 branch 新增的 Analyze
completion gate。

即使手動呼叫 `setup-implement.ps1`，required artifacts 也只有 `spec.md`、`plan.md`、
`tasks.md`，沒有 readiness assessment 或 ECI authorization。`validate-feature-structure.ps1`
只有在 `readiness/` 已存在時才驗 readiness；整個目錄缺失時不報錯。Positive test 甚至以
沒有 readiness fixture 的 feature 期待 `READY=true`。

Analyze 契約也沒有閉合：

- Analyze agent 明定 strictly read-only，輸出六欄 report table。
- Workflow 要求操作者把 finding 轉錄到四欄 `analysis-checklist.md`。
- Implement gate parser 只解析特定四欄 shape。
- 沒有 machine-readable artifact 或 deterministic conversion 將 agent output 綁到 gate input。

這是 repair ledger 已知的 R-D02 / R-B08；本分支的
`2026-07-12-analyze-completion-gate.md` 也已降回 Draft，但 direct entrypoint 仍是 active
runtime surface，所以是 merge blocker，不只是 future workflow follow-up。

### RVR-03：Workflow runner 的 registry authorization 可 fail-open

**位置**：

- `studio/scripts/powershell/run-workflow.ps1:125-178`
- `studio/scripts/powershell/list-workflows.ps1:59-122`
- `studio/workflows/POLICY.md:26-36`

Runner 自行 parse catalog/state/manifest，但沒有套用 `catalog.schema.json` 或
`state.schema.json`。`defaultEnabled` 與 `enabled` 直接轉為 `[bool]`；PowerShell 對非空字串
`"false"` 的 cast 結果是 `True`。此外 `state.json` 不存在時，runner 直接使用
`defaultEnabled`，沒有依 fail-closed policy 拒絕。

因此存在兩套 authority 判準：

| Surface | Missing / invalid state 行為 |
|---|---|
| `list-workflows.ps1`、canonical audit | Invalid / failure |
| `run-workflow.ps1` | 可能沿用 default 或將錯誤字串轉成 enabled |

這推翻 R-B05 對「runner execution 前 fail-closed 驗 catalog/state/manifest」的完整 closure
宣稱。`sdd-pipeline` 目前 experimental/default-disabled 是暫時 mitigation；它不能證明 runner
對未來 approved workflow 的授權正確。

## 7. High Findings

### RVR-04：RunState 與 execution 未綁定受審 workflow graph

**位置**：

- `studio/scripts/powershell/run-workflow.ps1:147-149`
- `studio/scripts/powershell/workflow-engine.ps1:325-329`
- `studio/scripts/powershell/workflow-engine.ps1:744-752`
- `studio/scripts/powershell/workflow-engine.ps1:775-780`

Fresh execution 只驗 workflow id/version；同 id/version 的不同內容可以被執行。Resume 雖然
在 RunState 保存 `workflow_version`，實際上只比對 `workflow_id`，然後依舊的
`completed_steps` 跳過 step。

合法升版或同版內容變更後 resume，會形成 hybrid run：

- 已完成部分來自舊 graph
- 未完成部分來自新 graph
- state 仍可能宣稱舊 version
- 無內容 digest 可證明操作者跑的是哪份受審 YAML

本分支的 built-in `workflow.yml` 已在 4 個 commits 修改執行語義，版本始終是 `1.0.0`，
證明同版 graph mutation 已經實際發生。

### RVR-05：Mainline aggregate gate 沒有封閉 shared-layer changed paths

**位置**：

- `studio/runtime/shared-runtime-contract.json:1372-1418`
- `studio/scripts/powershell/validate-mainline-notes.ps1:340-355`
- `studio/scripts/powershell/validate-mainline-notes.ps1:476-498`
- `studio/tests/mainline-note-validation.Tests.ps1:79-81`

Production `sharedGatePaths` 只列少數 PowerShell 單檔，沒有 `studio/scripts/powershell/` 整層；
本分支有 22 個 changed scripts 不在 gate 內，包括 add/remove extension、init、setup、export、
test runner 與 feature validator。`.githooks/commit-msg.ps1` 與 `studio/extensions/` 也未形成同等
封閉集合。

另一個獨立缺口是 branch diff 使用 `git diff --name-only`。Git rename detection 對
`--name-only` 只回傳 destination，因此 governed source 可以被 rename 到 gate 外，而 validator
看不到舊路徑。

重現結果：

- 單獨變更 `add-extension.ps1` 且不加 note：`VALID=true`
- 刪除另一支漏列 shared script 且不加 note：local hook、branch validator、canonical audit
  全部成功
- Rename `studio/workflows/.../README.md` 到 `scratch/` 且不加 note：`VALID=true`

測試 fixture 使用理想化的 `studio/scripts/powershell/` 整層規則，與 production contract 不同，
所以 361 tests 綠燈反而隱藏了 production drift。

### RVR-06：Ready note evidence 只驗字串，不驗事實

**位置**：

- `studio/scripts/powershell/validate-mainline-notes.ps1:236-275`
- `studio/scripts/powershell/validate-mainline-notes.ps1:392-403`
- `studio/scripts/powershell/validate-mainline-notes.ps1:520-529`
- `studio/scripts/powershell/validate-mainline-notes.ps1:587-590`
- `studio/constitution/constitution.md:420-430`

任意 7 至 40 位 hex 都算 commit evidence，任意 `#N` 都算 PR evidence，reconciliation evidence
只需非空且不等於幾個 placeholder。Validator 不驗：

- commit object 是否存在
- commit 是否屬於這次 branch diff
- PR reference 是否屬於正確 repository
- evidence 路徑、hash 或測試結果是否可重現
- note 是否包含 constitution 要求的 scope、impact、validation sections

不存在的 `deadbee` 可通過；測試 fixture 本身也使用非 Git repo 的 `abcdef1` 當 concrete
evidence。Branch 現況更顯示語義缺口：Wave-3 主 note 仍是 Draft/TBD，但只要其他 repair note
是 Ready，整個 551-path aggregate diff 就可通過 `-RequireReady`。

### RVR-07：ECI 沒有 full dossier、readiness re-entry 與 exactly-one enforcement

**位置**：

- `studio/workflows/sdd-pipeline/workflow.yml:70-98`
- `studio/workflows/sdd-pipeline/workflow.yml:128-141`
- `studio/scripts/powershell/setup-plan.ps1:49-68`
- `studio/scripts/powershell/validate-feature-structure.ps1:127-137`
- `studio/scripts/powershell/common.ps1:885-902`

Pipeline 的 ECI step 只把 `authorization-record.md` 當 expected artifact，沒有驗
`eci-assessment.md`、`source-manifest.md` 與 `adoption-record.md`。當 outcome 是
`READY_FOR_MAINLINE_IMPLEMENTATION` 時，只有 gate prompt 提醒 re-run readiness，graph 中沒有
第二個 Readiness step；之後直接進 Plan。

`validate-feature-structure.ps1` 也只有在現有 readiness status 仍是 `ROUTE_TO_ECI` 時要求四件
dossier。若 readiness 被手動改成 `READY_FOR_PLAN`，缺三件 dossier 仍可能通過。

此外 shared Markdown field parser 只回傳第一個 match。同一份 readiness 或 authorization
文件若同時有兩個矛盾 status，行序會決定授權，而不是依 constitution 的 exactly-one 規則
fail-closed。

### RVR-08：Extension trust、scope、mutation 與 mirror authority 未閉合

**位置**：

- `studio/scripts/powershell/validate-extension-registry.ps1:130-149`
- `studio/scripts/powershell/add-extension.ps1:71-82`
- `studio/scripts/powershell/add-extension.ps1:101-138`
- `studio/scripts/powershell/export-extensions.ps1:40-80`
- `studio/scripts/powershell/common.ps1:1303-1321`
- `studio/scripts/powershell/set-extension-state.ps1:68-77`

確認的行為包括：

1. Entry point 只做字串 prefix 與 extension-root containment。`scripts/../docs/x` 可在來源仍
   位於 extension root 的情況下越過宣告 scope；export target 未再 assert 位於 `$scopeDir`。
2. `add-extension.ps1 -Force` 先刪除/複製並更新 catalog，之後才 validation；失敗不 rollback。
3. Replacement 內容可以沿用舊的 `approvedBy`、`approvedAt`、trust 與 enabled state，核准證據
   沒有綁定實際 bytes。
4. `export-extensions.ps1 -OutputDir ... -Force` 可清空任意指定 output，沒有 workspace boundary。
5. Disable 或 remove extension 後，既有 merged mirror 不會失效；runtime selector 只看 mirror
   manifest 是否存在，仍可能採用 stale generated source。

這使 canonical registry、核准紀錄、實際 extension bytes 與 generated mirror 成為四個可能
互相分歧的真相來源。R-C01、R-C02、R-C05、R-C07 已涵蓋部分問題，但 cross-scope 與 stale
mirror 是本輪新增的具體 failure mode。

### RVR-09：Worktree 與 consumer agent junction 破壞 isolation

**位置**：

- `studio/scripts/powershell/new-project-worktree.ps1:71-80`
- `studio/scripts/powershell/common.ps1:755-781`
- `studio/scripts/powershell/common.ps1:1124-1131`
- `studio/templates/project-init/.gitignore:81-85`
- `WORKSPACE_STRUCTURE.md:216-228`

`new-project-worktree.ps1` 在 target 執行一般 `git config core.hooksPath`，但 linked worktrees
預設共用 repository config。寫入值又是相對於 target 深度計算；當 target 與 source 深度不同，
建立新 worktree 會改壞 source 與其他 worktree 的 hooks path。

Project initialization 另建立 `.github/agents` 與 `.claude/agents` junction，但 template
`.gitignore` 明確不忽略 junction 內容。Fresh consumer repo 的一般 `git status` 會列出 shared
agent files，`git add .` 可把 workspace canonical agent vendoring 進 consumer。這與
`WORKSPACE_STRUCTURE.md` 宣稱 junction content 已被排除直接矛盾。

### RVR-10：Agent source、seeded mirror 與文字規則仍漂移

**位置**：

- `.github/agents/speckit.specify.agent.md:163`
- `.github/agents/speckit.specify.agent.md:198`
- `studio/scripts/powershell/check-speckit-runtime.ps1:335-365`
- `studio/scripts/powershell/seed-claude-agents.ps1:153-183`

Specify agent 前段已新增「不得臆測 material unknowns、不得限制 marker 數量」，後段仍要求
超過三個 marker 時只保留三個並猜測其餘內容；完成訊息仍允許直接進
`/speckit.readiness`。同一 agent source 因此同時包含互斥指示。

Claude mirror audit 只驗檔名存在與 directory closure，不比對 source-derived body。把
`.claude/agents/speckit-analyze.md` 清空後，canonical audit 仍 `VALID=true`。此外 tool mapping
遇到任一未知 tool 時回傳空陣列，seeded file 省略 tools 欄，可能把 mapping failure 轉成較寬
的預設工具權限。

這表示 `.claude/agents` 雖在 constitution 被分類為 seeded dependent，機器驗收仍無法證明
其內容來自 `.github/agents` source。

### RVR-11：Runtime upgrade 不是原子操作

**位置**：

- `studio/scripts/powershell/upgrade-studio-runtime.ps1:118-168`
- `studio/scripts/powershell/upgrade-studio-runtime.ps1:173-224`

Upgrade 逐檔覆寫 canonical runtime，完成 mutation 後才執行 audit。若 snapshot 不完整或 audit
失敗，command 會非零結束，但已覆寫的 target 保留，沒有 staging、transaction、backup restore
或 rollback。

因此「upgrade failed」不代表 canonical runtime 保持原狀；下次重試會以半更新狀態為起點，
違反 fail-closed、可重複性與 authority update order。現有測試主要驗參數與 help，沒有
apply-failure rollback coverage。

### RVR-12：Branch 沒有 canonical SDD delivery evidence，且自己的 merge ledger 尚未完成

**位置**：

- `studio/constitution/constitution.md:72-84`
- `studio/constitution/constitution.md:259-266`
- `docs/mainline-updates/2026-05-05-studio-workflows-runtime.md:6-8`
- `docs/sdd-workspace-repair-inventory-and-update-plan-2026-07-12_zhTW.md:175-177`
- `docs/sdd-workspace-repair-inventory-and-update-plan-2026-07-12_zhTW.md:254`
- `docs/sdd-workspace-repair-inventory-and-update-plan-2026-07-12_zhTW.md:274`

Workspace root 沒有 `specs/`；`main...HEAD` 也沒有任何 canonical feature artifacts。這 26
commits 新增或修改正式 workflow runtime、CI、hooks、agents 與 shared scripts，但沒有可證明
依序完成 Specify、Clarify、Readiness、Plan、Tasks、Analyze、Implement 的 artifacts。

Repair ledger 已記錄 R-E07：workspace governance repo 實際上用 mainline notes + audit 走另一條
路徑，但這個 self-application exception 尚未在 constitution 明文化。因此目前存在兩個都未
閉合的選項：

1. Workspace governance delivery 仍受七階段約束，本分支缺 canonical evidence。
2. Workspace governance delivery 有等效雙軌治理，但 constitution 尚未授權該例外。

同時 Wave-3 主 note 仍是 Draft、Related Commits 仍 TBD；repair plan 明定 R3、R5、R6，尤其
fresh-fixture 七階段 E2E、全部 P1 closure 與 final promotion 後才 merge。HEAD 的 ledger 只記錄
完成到 R2。

## 8. 為什麼 361 Tests 與 Audit 仍會綠

本次 findings 不是否定現有 tests 的價值。361 tests 已可靠驗證許多局部機制，包括：

- gate pending/reject 基本路徑
- DryRun sidecar isolation
- duplicate step IDs
- RunState relocation 與 restart
- workflow schema happy/negative shapes
- UTF-8、BOM、line endings
- mainline note index 與部分 reconciliation shape
- extension id lexical traversal
- agent bootstrap block presence

問題在於多數測試的 acceptance question 比治理宣稱窄：

| Existing Test Question | Governance 仍需要回答的問題 |
|---|---|
| 是否沒有 pending task regex | 原始 task IDs 是否全數保留並逐項完成 |
| catalog/state JSON 是否可被 listing 驗證 | runner 是否使用同一份 schema 與 fail-closed 判準 |
| workflow id/version 是否一致 | 實際 graph bytes 是否就是受審內容 |
| changed note 是否有非空 evidence | evidence 是否真實存在且涵蓋 branch diff |
| fixture sharedGatePaths 是否能擋 script | production contract 是否覆蓋所有 shared scripts |
| Claude mirror 檔名是否存在 | mirror body 是否 deterministic derivation 自 source |
| extension source 是否在 extension root | exported target 是否仍在宣告 runtime scope |
| worktree target hooks 是否正確 | source 與其他 worktrees 是否保持不變 |

Canonical audit 的 contract invariants 也大量使用 `mustContainAll` token。這能防止關鍵字被意外
刪除，但不能證明 token 所在的控制流程會被 active entrypoint 執行，也不能防止同檔同時存在
互相矛盾的語句。

## 9. Merge 判定

### 9.1 Current disposition

| Question | Judgment |
|---|---|
| 是否可把 R0 source cleanup 視為完成 | 可，現有刪除與 provenance 大致一致 |
| 是否可把 R1 hosted enforcement 視為完整 closure | 不可，RVR-05、RVR-06 重新打開 closure |
| 是否可把 R2 workflow integrity 視為完整 closure | 不可，RVR-01、RVR-03、RVR-04 推翻部分宣稱 |
| Experimental/default-disabled 是否降低即時風險 | 是，但不是 merge acceptance 或 future promotion 證據 |
| 是否已滿足 direct slash-command governance | 否，RVR-02、RVR-10 仍 active |
| 是否已滿足 ECI/full SDD flow | 否，RVR-07 與缺 fresh-fixture E2E |
| 是否可合併到 `main` | 否 |

### 9.2 Minimum merge gates

至少完成以下條件後才適合重新 review：

1. Terminal Implement 保存並驗證 baseline task-ID inventory，新增 deletion / rename / malformed
   task negative tests。
2. `/speckit.implement` 第一個動作接上不可繞過的 setup gate；gate 必須要求 readiness、必要
   ECI authorization、Analyze machine result 與 intent obligations。
3. Runner 共用 catalog/state/manifest schema validator，missing、wrong-type、null、scalar、string
   boolean 全部 fail-closed。
4. Workflow approval 與 RunState 保存 version + content digest；resume 遇 graph mismatch 必須拒絕
   或顯式 migration/restart。
5. Mainline branch diff 改用 name-status 並保留 rename old/new；shared gate 以 category-complete
   path rules 覆蓋 scripts、hooks、extensions，不再維護不完整單檔 allowlist。
6. Ready-note validator 驗 commit/PR 真實性、required sections 與 branch coverage；主 Wave-3 note
   不得在 Draft/TBD 時由其他小 note 代替整批 readiness。
7. ECI graph 驗四件 dossier、實際 re-run readiness，並對重複/矛盾 status fail-closed。
8. Extension validate-before-mutate、失敗 rollback、content-bound approval、normalized scope target
   containment、state change invalidates merged mirror。
9. Worktree hooks 改為 worktree-safe 設定；fresh consumer `git status` 不得展開 shared junction。
10. Source/mirror parity 使用 deterministic regeneration 或 normalized body diff 納入 canonical audit。
11. Upgrade 採 staging + audit + atomic promote，或至少在失敗時可證明 rollback 完成。
12. 完成 repair plan R3 至 R6，保存 fresh-fixture 七階段與非 READY / ECI / reject / restart / terminal
    completion evidence，再更新主 note、ledger 與 commit references。

## 10. 建議修復順序

| Order | Batch | Reason |
|---|---|---|
| 1 | RVR-01、RVR-02、RVR-03 | 先阻止假完成、mandatory gate bypass 與授權 fail-open |
| 2 | RVR-04、RVR-07 | 讓 workflow execution identity 與 SDD routing 可稽核 |
| 3 | RVR-05、RVR-06 | 修復 hosted merge evidence，避免修復本身再以假綠合併 |
| 4 | RVR-08、RVR-09、RVR-11 | 收斂 extension、consumer 與 upgrade mutation boundary |
| 5 | RVR-10、RVR-12 | 完成 agent/authority/process truthfulness 與 R3 至 R6 帳務 |

每批應包含：

- 能在舊實作失敗、新實作通過的 negative tests
- Canonical audit 與完整 Pester suite
- `git diff --check`
- Branch-level mainline reconciliation
- 對應 Ready note 的真實 commit evidence
- 若後續證據推翻 Ready claim，依 template 將 note 降回 Draft

## 11. 已知限制

1. 本次 review 以 local `main` / `origin/main` 的共同 commit `c6ee1f1` 為 base，沒有重新 fetch
   remote；兩者在 review 時一致。
2. `sdd-pipeline` 目前 experimental/default-disabled，因此部分 workflow findings 不會在正常
   catalog authorization 下立即執行；本次仍把它們視為 merge findings，因為 runtime source、
   tests、contract 與 R2 Ready notes 已將其描述成可驗證的治理能力。
3. 未修改 runtime、agent、workflow、schema 或 tests。本文件與 `docs/README.md` 是在完成乾淨
   HEAD snapshot review 後，依使用者要求新增的 informational records。
4. 本記錄聚焦 merge safety 與 governance purpose，不替代 repair ledger 的全部 114 條長期
   maintenance backlog。

## 12. Final Decision

**Decision：NOT READY TO MERGE**

原因不是測試失敗，而是現有綠燈無法排除：

- completed 與 tasks 真實完成分離
- active entrypoint 與 mandatory gates 分離
- runner authorization 與 registry validation 分離
- RunState 與受審 graph 分離
- Ready evidence 與真實 Git / PR evidence 分離
- generated mirror / dependent agent 與 canonical source 分離
- consumer worktree 與 repository-wide hook state 互相污染

下一次 promotion 或 merge review 應以第 9.2 節的 minimum gates 與 fresh-fixture evidence 為
輸入，不應只重跑目前的 361 tests 後沿用既有 Ready 結論。

## 13. Version History

| Version | Date | Change |
|---|---|---|
| 1.0.0 | 2026-07-14 | Review 26-commit branch snapshot at `04e4287`; record Critical/High governance findings and merge disposition |
