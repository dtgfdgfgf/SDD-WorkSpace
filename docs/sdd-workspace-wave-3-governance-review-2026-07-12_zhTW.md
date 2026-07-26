---
title: "SDD-WorkSpace Wave 3 分支治理導向 Review"
version: "1.0.0"
date: "2026-07-12"
language: "zh-TW"
status: "review-record"
authority: "informational"
branch: "feature/wave-3-security-and-workflows"
target_branch: "main"
base_commit: "c6ee1f1"
head_commit: "60768f3"
review_range: "main...HEAD"
commit_count: 13
changed_files: 66
review_mode: "read-only evidence-based governance review"
---

# SDD-WorkSpace Wave 3 分支治理導向 Review

## 1. 結論

目前不建議將 `feature/wave-3-security-and-workflows` 合併到 `main`。

本分支相對 `main` 領先 13 commits，變更 66 個檔案，約新增 6,840 行、刪除 89 行。
官方 shared runtime audit、Pester suite、workflow schema validator 與 workflow registry list
目前都回報綠燈；但針對否決、重播、最終完成證據、catalog 授權、slash-command 真實
entrypoint 與 fresh consumer flow 的 negative-path review，確認仍有 9 個 P1 與 4 個 P2。

主要問題不是單純缺少更多 unit tests，而是目前 contract 與測試多半驗證：

- token 或必要字串存在
- JSON/YAML schema shape
- isolated mechanism 的 happy path
- artifact 是否存在或 hash 是否改變

它們尚未可靠證明：

- operator 的否決真的能阻止下一階段
- DryRun 不會成為正式完成證據
- pipeline 的 `completed` 等於所有 tasks 與治理義務完成
- direct slash command 必定經過 stage gate
- workflow catalog/state/manifest 真的控制執行授權
- ECI full dossier 與 readiness re-entry 已完成
- fresh feature 能從 Specify 一路走到 Implement

## 2. 治理基準

本次 review 依下列 authority order 執行：

1. `studio/constitution/constitution.md`，版本 1.8.0
2. `.specify/memory/constitution.md`（workspace root 不存在）
3. Runtime adapters 與其他 dependent/informational documents

核心判斷特別對照：

- Constitution Section 2：七階段 mandatory sequence
- Section 5 與 5.1：Readiness、ECI dossier 與 re-entry
- Section 8：Critical findings 與 Intent Drift Check 必須阻擋 implement-ready outcome
- Section 9：Implementation 必須依 tasks exactly 執行
- Section 10：AI 不得假設缺漏需求或跳過 SDD stages
- Section 12：authority chain、surface truthfulness、mainline update notes 與 shared-layer acceptance

## 3. Review 範圍

| Area | Reviewed Surface |
|------|------------------|
| Commit scope | `main...HEAD` 的 13 commits |
| Workflow runtime | engine、runner、catalog/state、schemas、built-in pipeline、RunState |
| SDD gates | setup scripts、Specify/Clarify/Analyze/Implement agent entrypoints |
| Governance contract | shared runtime contract、impact registry、authority classification |
| CI | `.github/workflows/governance.yml` 與其文件宣稱 |
| Security | extension path hardening、workflow script/artifact path boundary |
| Documentation | mainline update notes、QUICKSTART、SDD guide、analysis records |
| Verification | runtime audit、Pester、workflow validation、targeted negative probes |

本次沒有修改 runtime、agent、workflow 或 test；review 完成後才依使用者要求新增本記錄與
`docs/README.md`。

## 4. Findings Summary

| ID | Severity | Area | Summary |
|----|----------|------|---------|
| GOV-01 | P1 | Gate semantics | `RejectGate` 與尚未 pending 的預先批准都會回 success |
| GOV-02 | P1 | Completion integrity | Implement 只需 `tasks.md` 任意變更即可讓整條 pipeline completed |
| GOV-03 | P1 | Dry-run isolation | DryRun 會寫入 `completed_steps` 並污染正式 resume |
| GOV-04 | P1 | Analyze to Implement | 新 Analyze gate 沒接到 direct `/speckit.implement` entrypoint，Critical parser 也與 agent output 不相容 |
| GOV-05 | P1 | Specify to Clarify | Specify 仍會猜測 material unknowns，且仍建議可直接進 Readiness |
| GOV-06 | P1 | Workflow authorization | Runner 完全不消費 catalog/state/manifest 的批准與 enablement |
| GOV-07 | P1 | Shared acceptance | 缺少 workflow dependency 或 registry invalid 時 audit 仍可能假綠 |
| GOV-08 | P1 | Feature identity | Fresh pipeline 會先建立 feature directory，導致 Specify 產生另一個 feature number；script gates 也未完整綁定 ProjectRoot/Feature |
| GOV-09 | P1 | ECI governance | Pipeline 只驗 authorization record，沒有 full dossier 與真正 readiness re-entry |
| GOV-10 | P2 | Analyze contract | Analyze agent read-only contract 與 workflow 要求修改 artifact 不一致 |
| GOV-11 | P2 | Authority and rollout | CI/workflow authority coverage 不完整，但 workflow 已標 core、approved、default enabled；主 note 仍為 Draft/TBD |
| GOV-12 | P2 | Path boundary | `GetFullPath` lexical prefix 無法解析 Windows junction/reparse target |
| GOV-13 | P2 | Workflow identity | Step ID 不要求全域唯一，後續同 ID command/gate 可能被略過或共用決策 |

## 5. Detailed Findings

### GOV-01 [P1] Gate 否決仍會繼續執行

**Locations:**

- `studio/scripts/powershell/workflow-engine.ps1:501-520`
- `studio/workflows/sdd-pipeline/workflow.yml:65-128`

`Invoke-GateStep` 在 action 為 `confirm` 或 `reject` 時，沒有先要求該 gate 已是目前 pending
gate。這代表呼叫者可在 gate 第一次出現前預先提供 decision。

更嚴重的是，當 action 為 `reject` 且 step 沒有 `on_reject` 時，engine 仍回傳
`Status=success`。Built-in pipeline 的 gates 都沒有 `on_reject`，因此：

- `READY_FOR_PLAN` gate 被明確拒絕後仍會執行 Plan prep
- 非 READY gate 被 confirm/reject 後仍會落到 Plan prep，再由下游 script 失敗
- 標示「acknowledge and halt」的 sandbox/spike gate 並不是 terminal halt

針對性 in-memory probe 結果：

```json
{
  "RejectResult": "success",
  "RejectGateStatus": "rejected",
  "RejectEverHalted": false,
  "PreconfirmResult": "success",
  "PreconfirmGateStatus": "confirmed",
  "PreconfirmEverHalted": false
}
```

**Governance impact:** operator decision 無法形成 fail-closed 授權邊界，mandatory sequence
只能依賴後續 script 偶然阻擋。

**Required remediation:** decision 只能套用到 `RunState.current_step_id` 所指向、狀態為
pending 的 gate；沒有 `on_reject` 時 reject 必須保持 halt 或進入明確 failed/cancelled
terminal state。

### GOV-02 [P1] Implement 只改一個 task 就會 completed

**Locations:**

- `studio/scripts/powershell/workflow-engine.ps1:459-474`
- `studio/scripts/powershell/workflow-engine.ps1:670-673`
- `studio/workflows/sdd-pipeline/workflow.yml:181-186`

Implement step 把整份 `tasks.md` 當作唯一 expected artifact。Engine 只比較整檔 SHA-256；
只要任何 byte 改變，或 operator 使用 `-AcceptAgent stage-implement` 接受未變但非空的
檔案，step 就回 success。因為 Implement 是最後一個 step，RunState 隨即標為 completed。

例如十個 pending tasks 中只把 T001 改成 `[x]`，就足以完成整條 pipeline。這不能證明：

- 所有 canonical tasks 已完成
- Definition of Done 已滿足
- 最終驗證、文件與 knowledge capture tasks 已執行
- Implement 確實依 task list exactly 執行

**Governance impact:** `completed` 是檔案變更信號，不是 delivery acceptance signal，與
mainline note 所稱的 real acceptance signal 不一致。

**Required remediation:** terminal implement step 需要 postcondition validator，確認沒有
pending canonical task、必要驗證已執行，且 terminal delivery step 不應允許以單純
`-AcceptAgent` 取代完成證據。

### GOV-03 [P1] DryRun 會污染正式完成狀態

**Locations:**

- `studio/scripts/powershell/workflow-engine.ps1:422-424`
- `studio/scripts/powershell/workflow-engine.ps1:452-454`
- `studio/scripts/powershell/workflow-engine.ps1:582-590`
- `studio/scripts/powershell/workflow-engine.ps1:658-673`

DryRun command/agent step 會回 success，之後 `Invoke-Step` 仍把 step ID 加入
`completed_steps`，`Invoke-Workflow` 也仍保存 RunState。下一次非 DryRun resume 會把這些
從未真正執行的步驟視為 `skipped-completed`。

針對性 probe 已重現 history 先出現 `dry-run-skipped`，下一次正式執行再出現
`skipped-completed`。

**Governance impact:** 模擬執行可以變成正式完成證據，也違反 CLI 對 DryRun「skip side
effects」的說明。

**Required remediation:** DryRun 使用 ephemeral state 或完全不寫 RunState；至少不得更新
`completed_steps`、gate decisions 或 terminal status。

### GOV-04 [P1] Analyze gate 沒有接到真正的 Implement entrypoint

**Locations:**

- `.github/agents/speckit.implement.agent.md:21-48`
- `studio/scripts/powershell/check-prerequisites.ps1:103-120`
- `studio/scripts/powershell/setup-implement.ps1:106-133`
- `studio/scripts/powershell/setup-implement.ps1:156-195`
- `.github/agents/speckit.analyze.agent.md:246-257`

新增的 analyze-completion gate 位於 `setup-implement.ps1`，但真正的
`/speckit.implement` agent 仍只呼叫：

```text
check-prerequisites.ps1 -Json -RequireTasks -IncludeTasks
```

該 script 只硬檢查 `plan.md` 與 `tasks.md`，不要求 readiness、ECI 或 analyze completion。
因此直接呼叫 slash command 可以完全繞過新 gate。

即使 operator 手動呼叫 `setup-implement.ps1`，Critical parser 也只接受固定四欄、大小寫為
`Critical` 的 table row；canonical Analyze agent 則輸出六欄、severity 為 `CRITICAL`。
`Analysis Status: COMPLETE` token 因而可能在尚有 Critical/Intent Drift 問題時放行。

**Governance impact:** 「machine-enforce analyze before implement」只存在於 optional script
與 workflow path，不是 slash-command 的 authoritative entry gate。

**Required remediation:** Implement agent 的第一個 fail-closed 動作必須是
`setup-implement.ps1`；Critical/Intent Drift output 需要共用 machine-readable schema，不能
依賴兩份互不相容的 Markdown regex。

### GOV-05 [P1] Specify 仍會猜測需求並建議跳過 Clarify

**Locations:**

- `.github/agents/speckit.specify.agent.md:81-88`
- `.github/agents/speckit.specify.agent.md:161-164`
- `.github/agents/speckit.specify.agent.md:198`
- `.claude/agents/speckit-specify.md:79-86`
- `.claude/agents/speckit-specify.md:159-162`
- `.claude/agents/speckit-specify.md:196`

本分支新增「不得 invent requirements」與「material markers 不設上限」，但同一份 prompt
後段仍要求：

- 超過三個 markers 時只保留最重要三個
- 對其餘問題 make informed guesses
- 完成後可進 `/speckit.clarify` 或 `/speckit.readiness`

兩套 agent mirror 彼此同步，但同步地保留相同矛盾。

**Governance impact:** agent 仍可自行吸收 scope/security material unknowns，且明示可跳過
mandatory Clarify；agent-conformance mainline note 的修復宣稱尚未成立。

**Required remediation:** 移除 marker cap、guess-the-rest 與 Readiness next-phase 文案；增加
machine-parsed agent handoff/next-stage contract test。

### GOV-06 [P1] Workflow registry 沒有控制 execution authorization

**Locations:**

- `studio/scripts/powershell/run-workflow.ps1:82-113`
- `studio/scripts/powershell/list-workflows.ps1:51-119`
- `studio/workflows/POLICY.md:25-38`
- `studio/workflows/catalog.json:26-40`
- `studio/workflows/state.json`
- `studio/workflows/sdd-pipeline/manifest.json:20-23`

Runner 驗證 ID 格式後，直接組出 `studio/workflows/<id>/workflow.yml` 並執行，完全不讀：

- catalog registration
- review status 與 trust level
- effective enabled/disabled state
- pinned version
- package manifest identity 與 entry points

因此 disabled、rejected、draft、experimental 或 uncataloged workflow，只要目錄存在就能
執行 workspace 內 PowerShell。現有 workflow-engine tests 正是建立 uncataloged fixture
workflow 後成功執行，等同把 bypass 寫進綠燈基線。

`list-workflows.ps1` 的 `VALID` 也只檢查 catalog/state 兩個檔案是否存在，沒有套用新增的
`catalog.schema.json` 或 `state.schema.json`，JSON mode 發現 errors 後仍固定 exit 0。

另有 manifest drift：`sdd-pipeline/manifest.json` 宣告 `scripts/run-workflow.ps1`，但實際
entrypoint 位於 `studio/scripts/powershell/run-workflow.ps1`，也沒有 consumer 交叉驗證。

**Governance impact:** review、trust、activation、pinning 與 manifest 都是裝飾性 ledger，
無法提供 POLICY 所宣告的 managed rollout。

**Required remediation:** execution 前 fail-closed 驗證 catalog/state/manifest/YAML identity、
review/trust、effective enabled state 與 version pin；新增 rejected/disabled/uncataloged
negative tests。

### GOV-07 [P1] Shared runtime audit 對不可執行 runtime 仍可能綠燈

**Locations:**

- `studio/scripts/powershell/check-speckit-runtime.ps1:145-175`
- `studio/scripts/powershell/check-speckit-runtime.ps1:452-456`

缺少 `powershell-yaml` 時，script 在 line 151 加入 warning，卻在 line 175 重新把
`$warnings` 初始化為空陣列。針對性隔離 `PSModulePath` 的 probe 結果：

```json
{
  "ExitCode": 0,
  "YamlAvailable": false,
  "WarningCount": 0,
  "Warnings": []
}
```

此外，overall `VALID` 只依 `$failures` 計算。`STUDIO_WORKFLOW_REGISTRY_VALID=false`、schema
未套用或 workflow dependency 缺失都沒有升格成 shared acceptance failure。

**Governance impact:** Constitution 指定的唯一 machine-verifiable shared-layer acceptance
source 可能在 runtime 不可執行時仍假綠；pre-commit 與 CI 都會繼承該假陽性。

**Required remediation:** 先初始化 issue collections；把 required runtime dependency、
registry/schema/cross-ledger invalid 納入 failures，並新增 missing-module、missing-state、
invalid-catalog negative tests。

### GOV-08 [P1] Fresh pipeline 的 feature identity 會分裂

**Locations:**

- `studio/scripts/powershell/workflow-engine.ps1:262-275`
- `studio/scripts/powershell/workflow-engine.ps1:630-653`
- `studio/workflows/sdd-pipeline/workflow.yml:19-39`
- `.github/agents/speckit.specify.agent.md:49-65`
- `studio/scripts/powershell/create-new-feature.ps1:164-187`
- `studio/scripts/powershell/workflow-engine.ps1:416-426`
- `studio/workflows/sdd-pipeline/workflow.yml:129-179`

新 run 在執行第一個 step 前，就建立
`specs/<feature>/.workflow/state.json` 的父目錄。若 operator 以 `-Feature 001-foo` 啟動，
接著依 workflow 指示執行 `/speckit.specify`，Specify 的 numbering policy 會把既有
`specs/001-foo/` 視為已使用，建立 `002-foo`；workflow 卻固定等待
`specs/001-foo/spec.md`。

另一個 identity gap 是 script dispatch 沒把 child cwd 設為 `ProjectRoot`。Pipeline 傳給
多個 setup script 的是相對 `specs/<feature>`；在 external consumer 或非 project-root cwd
執行時，RunState/agent artifact 與 prep gate 可能落在不同 repo。`stage-plan-prep` 更只傳
`-Json`，由 branch 或 `SPECIFY_FEATURE` 自行選 feature，沒有綁定 runner 的 `-Feature`。

**Governance impact:** 預設啟用、標為 core 的七階段 pipeline 無法可靠從 fresh feature
起跑，也可能用另一個 feature 的 evidence 做 gate 判斷。

**Required remediation:** 在 feature 建立前把 RunState 放到不佔用 canonical feature ID 的
位置，或讓 Specify 接受並嚴格使用 preallocated ID；所有 child scripts 必須在
`ProjectRoot` 執行並接收 absolute FeatureDir。

### GOV-09 [P1] ECI 沒有 full dossier 與真正 readiness re-entry

**Locations:**

- `studio/workflows/sdd-pipeline/workflow.yml:69-100`
- `studio/scripts/powershell/setup-plan.ps1:43-52`
- `studio/scripts/powershell/validate-feature-structure.ps1:125-137`
- `.github/agents/speckit.eci.agent.md:48-132`

Pipeline 的 ECI agent step 只把 `authorization-record.md` 當作 expected artifact。它沒有在
workflow level 驗證：

- `eci-assessment.md`
- `source-manifest.md`
- `adoption-record.md`
- `authorization-record.md`

`READY_FOR_MAINLINE_IMPLEMENTATION` branch 的「re-run readiness」只是 gate prompt，沒有第二個
Readiness command、artifact baseline 或 status extraction。先前 completed 的 Readiness step
也會因 `completed_steps` 被略過。

**Governance impact:** external capability 的 source basis、adoption boundary、prohibitions 與
re-entry evidence 可被壓縮成一個 authorization token，違反 Constitution Section 5.1。

**Required remediation:** ECI step 必須驗證完整 dossier；成功後 workflow 應顯式回到新的
Readiness evaluation，並依最新 primary status 重新 routing，而不是直接落到 Plan prep。

### GOV-10 [P2] Analyze output contract 與 workflow 不相容

**Locations:**

- `.github/agents/speckit.analyze.agent.md:18-20`
- `.github/agents/speckit.analyze.agent.md:253-331`
- `studio/workflows/sdd-pipeline/workflow.yml:160-170`
- `studio/templates/sdd-docs/checklist-template.md:73-83`

Analyze agent 明定 strictly read-only、output chat report、never modify files；workflow 卻要求
`analysis-checklist.md` hash 改變才能完成 agent step，Implement gate 又要求 operator 手動把
status 從 PENDING 改為 COMPLETE。

**Governance impact:** mandatory Analyze stage 依賴未規格化的人工複製與 sign-off 動作，
normal slash-command execution 不會自動解除 halt，且難以重現與稽核。

**Recommended remediation:** 定義單一 machine-readable Analyze result artifact，或明確把
operator transcription/sign-off 建模成獨立 gate，而不是把 read-only agent 當成 file writer。

### GOV-11 [P2] Authority、CI 與 rollout maturity 不一致

**Locations:**

- `studio/runtime/shared-runtime-contract.json:985-1021`
- `studio/scripts/powershell/generate-impact-registry.ps1:73-95`
- `studio/scripts/powershell/generate-impact-registry.ps1:169-190`
- `studio/constitution/constitution.md:471-510`
- `studio/workflows/catalog.json:32-34`
- `docs/mainline-updates/2026-05-05-studio-workflows-runtime.md:6-7`
- `docs/mainline-updates/2026-05-05-studio-workflows-runtime.md:107`

`.github/workflows/` 不在 sharedGatePaths、document authority 或專用 impact route。刪除 CI、
移除 PR trigger 或把 audit/test 改成 no-op，不會得到與其治理角色相稱的 staged audit 與
impact advisory。

`studio/workflows/` 雖有 `workflow_change` route，卻沒有正式 document authority
classification；workflow runtime scripts 也只命中 generic `script_change`，其 test advisory
錯指 path-traversal suite。

同時，catalog 已把 `sdd-pipeline` 標為：

- `reviewStatus=approved`
- `trustLevel=core`
- `defaultEnabled=true`

但主 update note 仍是 `Draft`、`Related Commits=TBD`，並表示要等真實 consumer end-to-end
使用後才 promotion。

**Governance impact:** 實驗性能力已進 core rollout，但 authority、change propagation 與
merge record 尚未完成。

**Recommended remediation:** 修復 P1 前先降為 experimental/default-disabled；為 workflow
constituents 與 CI 建立 authority、sharedGate、impact route、contract invariant 與 negative
tests；最後再把主 note 升為 Ready 並填入 commit hashes。

### GOV-12 [P2] Path hardening 無法解析 Windows junction

**Locations:**

- `studio/scripts/powershell/common.ps1:568-578`
- `studio/scripts/powershell/add-extension.ps1:33-79`
- `studio/scripts/powershell/add-extension.ps1:99-113`

`Test-PathInsideRoot` 只對 `GetFullPath` 結果做字串 prefix comparison，不解析 symlink、junction
或其他 reparse point 的最終 target。

Windows temp probe 建立 `inside/source` junction 指向 sibling `outside` 後：

- lexical containment check 回 true
- `Copy-Item -LiteralPath junction -Recurse` 確實複製 outside 內容

此外，同 ID 使用 `add-extension -Force` 時會保留原有 approved/trust/defaultEnabled 與
approvedBy/At，代表替換內容不會自動重新 review。

**Governance impact:** path boundary 與 curated approval 可同時被繞過；本分支新增測試只涵蓋
`../../...` lexical traversal。

**Recommended remediation:** mutation/execution 前解析並驗證每一層 reparse target；內容替換
必須使 approval 失效或要求新的 review/signoff。

### GOV-13 [P2] Step ID 不要求全域唯一

**Locations:**

- `studio/workflows/manifest.schema.json:66-82`
- `studio/workflows/manifest.schema.json:84-86`
- `studio/scripts/powershell/workflow-engine.ps1:577-590`

Schema 只驗證單一 step ID 格式，沒有遞迴檢查整份 workflow 內的 ID uniqueness。Engine 的
`completed_steps` 與 gates 都只以 ID 當 key。

針對性 probe 放入兩個不同 command、相同 ID 後，第二個 step 直接得到
`skipped-completed`；重複 gate 也會共用 decision。

**Governance impact:** schema-valid workflow 可以宣告兩個 mandatory steps，但第二個永不
執行，破壞 deterministic execution 與 fail-closed。

**Recommended remediation:** validator 在執行前遞迴收集所有 step IDs 並拒絕任何 top-level
或 nested collision；補 command、gate 與 branch collision tests。

## 6. Validation Evidence

### 6.1 Branch Scope

```text
git rev-list --count main..HEAD
13
```

```text
git diff --stat main...HEAD
66 files changed, 6840 insertions(+), 89 deletions(-)
```

### 6.2 Standard Acceptance Entrypoints

| Check | Result |
|-------|--------|
| `git diff --check main...HEAD` | Pass |
| `check-speckit-runtime.ps1 -Json` | `VALID=true`, 0 errors, 0 warnings |
| `run-governance-tests.ps1 -Output Normal` | 254 discovered, 253 passed, 0 failed, 1 skipped |
| `validate-workflow.ps1 -Id sdd-pipeline -Json` | `VALID=true`, `SCHEMA_VALID=true` |
| `list-workflows.ps1 -Json` | `VALID=true`, 1 workflow, `sdd-pipeline` effective enabled |

### 6.3 Targeted Negative Evidence

| Probe | Result |
|-------|--------|
| Reject gate without `on_reject` | `Status=success`，未 halt |
| Preconfirm gate before pending | `Status=success`，未 halt |
| DryRun command/agent | 寫入 `completed_steps` |
| Resume after DryRun | 未執行真實 step，回 `skipped-completed` |
| Missing `powershell-yaml` | Audit exit 0、`VALID=true`、0 warnings |
| Uncataloged workflow | Runner 可執行；現有 tests 以此為正常 fixture |
| One task checkbox changed | Implement agent step 可 success，無 zero-pending postcondition |
| Junction source outside root | Lexical containment true，外部內容可被 Copy-Item 匯入 |
| Duplicate command ID | 第二個 step `skipped-completed` |

## 7. Why the Green Suite Missed These Findings

| Gap | Current Coverage | Missing Coverage |
|-----|------------------|------------------|
| Gate behavior | Confirm happy path | Reject、preconfirm、terminal halt |
| Completion | Artifact changed/not changed | All tasks complete、terminal postconditions |
| DryRun | Single dry run returns completed | DryRun followed by real resume |
| Agent gates | Standalone setup script fixtures | Actual slash-command entrypoint |
| Registry | File/field shape | Catalog/state/manifest execution authorization |
| ECI | Status strings present | Full dossier and second readiness pass |
| Pipeline | Static stage/status coverage | Fresh feature end-to-end consumer run |
| Path security | `../` lexical traversal | Junction/reparse resolution |
| Workflow identity | ID pattern | Global recursive uniqueness |
| Shared audit | Current installed environment | Missing dependency and invalid registry negative paths |

Contract 的 `mustContainAll` 能鎖住關鍵 token 不被刪除，但不能證明 token 所在 control flow
真的 fail-closed。對 gate、authorization 與 completion 類 requirement，必須以 behavioral
negative tests 作為主要 acceptance evidence。

## 8. Merge Gates and Recommended Order

### Gate 1: Stop Promotion

- 將 `sdd-pipeline` 暫時降為 `experimental`
- 設定 `defaultEnabled=false`
- 在 mainline note 清楚揭露目前不可作為 delivery acceptance signal

### Gate 2: Repair State Machine Integrity

- Reject 必須 fail-closed
- Gate decision 必須只作用於目前 pending gate
- DryRun 不得寫正式 RunState
- Failed/halted/cancelled state 必須有明確且可恢復的語意
- Step IDs 必須全域唯一

### Gate 3: Repair Completion Evidence

- Implement terminal validator 要求零 pending tasks
- 移除 terminal step 的 generic `-AcceptAgent` bypass
- Persist artifact completion hash 與 workflow content/version identity

### Gate 4: Wire Mandatory Stages to Real Entrypoints

- Direct Implement 必須先通過 `setup-implement`
- Specify 只能 hand off Clarify，且不得猜 material unknowns
- Analyze report、Critical/Intent Drift verdict 與 Implement gate 使用同一 schema
- ECI 驗證 full dossier 並顯式 re-enter Readiness

### Gate 5: Enforce Registry and Shared Acceptance

- Runner 消費 catalog/state/manifest
- Audit 套用 catalog/state schemas 與 cross-ledger policy
- Missing required dependencies 與 invalid registry 必須 non-zero
- CI 與 workflow surfaces 納入 authority、sharedGate 與 impact routing

### Gate 6: Add End-to-End Acceptance

至少新增一個 fresh consumer project fixture，實際走過：

1. Specify
2. Clarify
3. Readiness non-ready remediation
4. ECI full dossier 與 readiness re-entry
5. Plan
6. Tasks
7. Analyze Critical failure 與修復
8. Implement partial progress 不得完成
9. Implement all tasks complete 才得到 terminal success
10. Reject、DryRun、resume 與 workflow update negative paths

### Gate 7: Close Merge Records

- 主 Wave-3 note 從 Draft 更新為 Ready
- `Related Commits` 填入實際 hashes
- 更新 validation snapshot
- 明確列出 residual risks 與已接受的 follow-ups

## 9. Review Limitations

- 本次沒有確認 GitHub branch protection 或 hosted Actions run 的外部狀態。
- 本次主要審查 `main...HEAD` 與本分支宣稱修復的控制面；未把所有 main 既有 debt 都列為
  branch finding。
- Local RunState 的惡意手改、non-atomic lock、failed run recovery 與 error payload
  observability 仍有額外改善空間，但未全部升格為本次 primary finding。
- 行號以 head commit `60768f3` 為準；後續修復可能使行號位移，應以 finding ID 與 commit
  snapshot 追溯。

## 10. Final Recommendation

這個分支的方向正確：把 stage order、readiness routing、ECI、independent CI 與 path
hardening 從 prompt-side intention 推向 machine-side verification，符合 workspace 的核心
治理目的。

但目前多個新增機制仍把「有檔案、有 token、有 hash change」當成「已授權、已執行、已
完成」。若現在合併，會提高治理表面成熟度，卻同時增加 false confidence。

因此最合適的決策是：

> 阻擋目前 merge，先完成 P1 修復、negative-path tests 與 fresh consumer end-to-end；在此
> 之前將 workflow runtime 保持 experimental/default-disabled，並避免把 pipeline completed
> 對外描述為 delivery acceptance signal。
