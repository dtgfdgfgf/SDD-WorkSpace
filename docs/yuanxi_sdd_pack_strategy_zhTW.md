---
title: "Yuanxi SDD Pack：官方 Spec Kit 優先的可安裝 Overlay 策略"
version: "0.2.0"
date: "2026-05-05"
last_reviewed: "2026-07-22"
language: "zh-TW"
owner: "元熙"
status: "historical-unverified"
historical_status: "draft"
baseline_status: "historical-unverified"
baseline_spec_kit: "v0.8.5"
purpose: "將既有 SDD-WorkSpace 的個人化 SDD 治理、commands、templates、agents 與 workflow，重構為可安裝、可複製、可升級的 spec-kit overlay pack。"
source_context:
  - "使用者希望使用官方 github/spec-kit 作為 base，並將自己改過的內容以可複製方式接入，避免 upstream drift。"
  - "本文件整理前述對 SDD-WorkSpace 與官方 spec-kit 擴充機制的分析。"
---

# Yuanxi SDD Pack：官方 Spec Kit 優先的可安裝 Overlay 策略

> **Historical baseline notice (reviewed 2026-07-22).** This strategy was drafted against Spec Kit
> v0.8.5. Its compatibility matrix and command examples are historical design inputs, not current
> compatibility evidence or implementation authorization. Before reuse, follow
> `docs/yuanxi_sdd_pack_implementation_plan_obstacle_review_2026-07-22_zhTW.md` and resolve the
> independently open R-G02 and upstream alignment findings.

> Companion handoff：若要把本策略轉成實作，請先閱讀 `docs/yuanxi_sdd_pack_strategy_implementation_review_zhTW.md`。該文件整理 command namespace、v0.1 scope、readiness gate、installer safety、compatibility baseline 與下一個 agent 應先修正的問題。

## 1. 核心結論

你的方向應該從「維護一個自成一格的 SDD workspace runtime」轉成：

> 每個新專案都先是官方 spec-kit project；你的 SDD-WorkSpace 只提供一包可安裝的 personal SDD pack，把你打磨過的 commands、templates、governance、agent assets 接上去。

換句話說，預期順序是：

1. 建立 official spec-kit project。
2. 執行 `specify init <project> --integration <agent>`。
3. 安裝 Yuanxi SDD Pack。
4. 取得 discover、readiness、ECI、templates 與 governance rules。

這樣 upstream 更新時，你要維護的是「你的 pack 與官方 spec-kit 的相容性」，而不是每個專案的整套 runtime。

---

## 2. 新定位：官方 spec-kit 是 base，你的內容是 overlay

舊模型把 `SDD-WorkSpace` 當成所有專案共享 runtime 的母體。

新模型把 `SDD-WorkSpace` 定位成 `yuanxi-sdd-pack` 的 source repo、build repo 與 release
repo。

真正的使用方式包含三個角色：

| Role | Responsibility |
|---|---|
| `github/spec-kit` | Core runtime |
| Yuanxi repository | Overlay package source |
| Consumer project | Official Spec Kit plus installed overlay |

這個模型的優點：

1. upstream spec-kit 可以繼續更新，你不用 fork core。
2. 你的方法論可以被包裝成可安裝工具。
3. 新專案可以從官方流程啟動，再接上你的治理層。
4. 每次升級時只需要測試 pack compatibility，不需要逐一重構所有專案。

---

## 3. 建議建立的工具包：`yuanxi-sdd-pack`

建議建立乾淨的 `yuanxi-sdd-pack/` 可安裝工具包，或暫時放在現有 repo 的
`studio/packages/yuanxi-sdd-pack/`。

建議目錄結構：

| Path | Intended contents |
|---|---|
| `presets/yuanxi-governance/` | `preset.yml` and spec, plan, tasks and checklist templates |
| `extensions/yuanxi-discover/` | Extension manifest, discover command and discover template |
| `extensions/yuanxi-readiness/` | Extension manifest, readiness and ECI commands, and their evidence templates |
| `extensions/yuanxi-verify/` | Extension manifest plus verify and drift commands |
| `installer/` | PowerShell and shell installers |
| `catalog/` | Preset and extension catalogs |
| `docs/` | Installation, compatibility and upgrade guidance |

重點：這包東西不再假裝自己是 spec-kit core，也不直接維護官方 core command。

---

## 4. Extension 與 Preset 的分工

官方 spec-kit 的擴充模型可以對應成兩類：

- **Extension**：新增 command、workflow、quality gate、external integration。
- **Preset**：改變 spec、plan、tasks 等 artifacts 的格式、語氣、欄位與組織標準。

你的既有內容可以這樣拆：

| 你的內容 | 建議歸類 | 原因 |
|---|---|---|
| `/speckit.discover` | Extension | 新增 pre-spec discovery workflow |
| `/speckit.readiness` | Extension | 新增 `clarify` 與 `plan` 之間的 gate |
| `/speckit.eci` | Extension | 新增 External Capability Intake route |
| `intent-ledger.md` | Extension template | readiness 壓縮 scope 時產生的 secondary artifact |
| `readiness-assessment.md` | Extension template | 屬於 readiness workflow 產物 |
| spec / plan / tasks 的中文化、商家視角、KPI、風險欄位 | Preset | 改變 artifact 格式與語氣，不是新增 command |
| project constitution 標準 | Preset 或 installer seed | 屬於治理標準 |
| Copilot / Claude / Codex adapter | Installer / generated asset | agent-specific runtime adapter，不應是 core source |
| shared hooks | Installer optional step | 本質是本機或專案治理，不是 spec artifact |
| `WORKSPACE_STRUCTURE.md` 類 studio 文件 | 不放進每個專案 | 只留在 pack repo，作為 package 開發文件 |

---

## 5. 最重要原則：不要覆寫官方 core commands

官方 core commands 應盡量保留：

- `/speckit.constitution`
- `/speckit.specify`
- `/speckit.plan`
- `/speckit.tasks`
- `/speckit.taskstoissues`
- `/speckit.implement`

官方 optional commands 也建議保留：

- `/speckit.clarify`
- `/speckit.analyze`
- `/speckit.checklist`

不建議一開始覆寫 `/speckit.specify`、`/speckit.plan`、`/speckit.tasks` 或
`/speckit.implement`。

原因是這些 command 最容易隨 upstream 更新而改變。若你覆寫它們，每次 spec-kit 更新都要手工比對。

比較穩定的分工如下：

| Ownership | Commands |
|---|---|
| Retain from official Spec Kit | `/speckit.specify`, `/speckit.clarify`, `/speckit.plan`, `/speckit.tasks`, `/speckit.analyze`, `/speckit.implement` |
| Add through the Yuanxi pack | `/speckit.discover`, `/speckit.readiness`, `/speckit.eci`, `/speckit.verify`, `/speckit.drift` |

建議流程：

1. `/speckit.discover` performs Yuanxi pre-spec discovery.
2. `/speckit.specify` and `/speckit.clarify` remain official commands.
3. `/speckit.readiness` applies the Yuanxi gate; `/speckit.eci` runs only when routed.
4. `/speckit.plan`, `/speckit.tasks`, `/speckit.analyze` and `/speckit.implement` remain official
   commands.
5. `/speckit.verify` applies the Yuanxi post-implementation gate.

這樣 upstream 更新時，官方 command 可以照樣吃新版；你的 extension 只需要確保仍然讀得懂官方產出的 `spec.md`、`plan.md`、`tasks.md`。

---

## 6. Template override 要保守

Preset 可以覆寫官方 templates，但這也是 drift 風險最高的地方。

如果你的 preset 整份覆蓋 `spec-template.md`，而官方新版後來新增欄位，你的版本就可能錯過新欄位。

因此建議分成兩種 preset：

### 6.1 Safe preset：低 drift

只新增你的輔助模板，不覆寫官方 core template。

例如，可新增：

- `templates/yuanxi-business-risk-section.md`
- `templates/yuanxi-readiness-gate-section.md`
- `templates/yuanxi-merchant-perspective-checklist.md`

由 extension command 在需要時引用這些 section。

### 6.2 Opinionated preset：高控制、高 drift

高控制版本會直接覆寫 `spec-template.md`、`plan-template.md` 與 `tasks-template.md`。

這會更符合你的個人方法論，但每次 upstream 升級都要做 template diff。

建議順序：

1. 第一版先做 Safe preset。
2. 等官方 template 的欄位穩定後，再建立 `yuanxi-opinionated-governance` preset。
3. 若真的覆寫 core templates，必須建立 `check-template-drift.ps1`。

---

## 7. 安裝方式要做到一行或極少步驟

你要的是「可輕易複製」，所以最終使用體驗應該是：

```powershell
specify init my-project --integration copilot
cd my-project
..\SDD-WorkSpace\studio\packages\yuanxi-sdd-pack\installer\install-yuanxi-sdd-pack.ps1
```

或遠端版本：

```powershell
irm https://raw.githubusercontent.com/dtgfdgfgf/SDD-WorkSpace/main/studio/packages/yuanxi-sdd-pack/installer/install-yuanxi-sdd-pack.ps1 | iex
```

installer 概念上應該做：

```powershell
specify preset add --dev "../presets/yuanxi-governance" --priority 5
specify extension add --dev "../extensions/yuanxi-discover" --priority 5
specify extension add --dev "../extensions/yuanxi-readiness" --priority 5
specify extension add --dev "../extensions/yuanxi-verify" --priority 5
```

實際路徑要依照 repo 結構調整。

---

## 8. 是否要拆成兩個 repo

建議長期拆成兩個 repo。

保留現在的 `dtgfdgfgf/SDD-WorkSpace`。

作為：

- 開發場
- 測試場
- 方法論孵化場
- 個人 studio 文件
- learning / projects 實驗區

另開乾淨的 `dtgfdgfgf/yuanxi-sdd-pack` repo。

只放 `presets/`、`extensions/`、`installer/`、`catalog/`、`docs/` 與 `tests/` 等可安裝
內容。

好處：

1. 安裝者不會吃到 `learning/`、`projects/`、archive、歷史實驗。
2. package boundary 乾淨。
3. 任意官方 spec-kit project 都可以安裝這包。
4. drift check 可以只針對 pack，不需要掃整個 workspace。
5. 若未來公開，`yuanxi-sdd-pack` 比 `SDD-WorkSpace` 更像正式工具。

---

## 9. Upstream drift 的三種主要風險

### 9.1 Core command drift

官方 `/speckit.specify`、`/speckit.plan`、`/speckit.tasks` 改了，但你的東西仍假設舊格式。

解法：

- 不覆寫 core command。
- 只讀官方 artifacts。
- 在你的 extension 開頭做 artifact compatibility check。

### 9.2 Template drift

官方 `spec-template.md` 新增欄位，但你的 preset 整份覆蓋掉。

解法：

- 第一版少覆寫。
- 若要覆寫，建立 `check-template-drift.ps1`。
- 每次升級 spec-kit 後，比對 upstream template 與本地 preset template。

### 9.3 Artifact contract drift

你的 `/speckit.readiness` 假設 `spec.md` 有某些 heading，但官方新版改了。

解法：

建立 machine-verifiable artifact contract，例如：

```yaml
required_artifacts:
  - specs/*/spec.md
  - specs/*/plan.md
  - specs/*/tasks.md

accepted_sections:
  spec:
    - User Stories
    - Requirements
    - Success Criteria
```

並在 `/speckit.readiness`、`/speckit.eci`、`/speckit.verify` 開頭執行 compatibility check。

---

## 10. Compatibility Matrix

建議新增 `docs/COMPATIBILITY.md`。

下表只保留原始策略的歷史 matrix；它不是 current test evidence：

| yuanxi-sdd-pack | spec-kit version | status | notes |
|---|---:|---|---|
| 0.1.0 | v0.8.5 | historical-unverified | Initial extension/preset split proposed in the 2026-05-05 draft |
| 0.2.0 | v0.8.x | historical-plan | ECI and verify proposal; version range is stale and unverified |

每次 spec-kit 更新，依序測試 official init、pack installation、discover、specify、clarify、
readiness、plan、tasks、analyze、toy-project implement 與 verify。

通過後更新 compatibility matrix。

---

## 11. 最短可執行路線

### Step 1：停止把 workspace 當 runtime 母體

保留 `SDD-WorkSpace`，但新專案不再直接吃 junction / shared runtime。

### Step 2：建立 `yuanxi-sdd-pack`

第一版只放三個東西：

- `extensions/yuanxi-discover`
- `extensions/yuanxi-readiness`
- `presets/yuanxi-governance-lite`

不要一開始搬所有東西。

### Step 3：安裝流程改成 official-first

下列命令使用明示 placeholder，因為原稿的 v0.8.5 pin 已是歷史基準；R-G02 完成前不得
把 placeholder 換成未驗證版本並宣稱相容。

```powershell
$testedTag = 'vX.Y.Z'
uv tool install specify-cli --force --from "git+https://github.com/github/spec-kit.git@$testedTag"
specify version
specify check

specify init my-project --integration copilot
cd my-project
..\yuanxi-sdd-pack\installer\install.ps1
```

### Step 4：只新增，不覆寫

第一版只新增 `/speckit.discover`、`/speckit.readiness`、`/speckit.eci` 與
`/speckit.verify`。

先不要覆寫官方 `/speckit.specify`、`/speckit.plan`、`/speckit.tasks`。

### Step 5：做 smoke test project

每次更新 upstream，都跑：

```powershell
specify init smoke-test --integration copilot --ignore-agent-tools
cd smoke-test
..\yuanxi-sdd-pack\installer\install.ps1
specify extension list
specify preset list
```

然後人工或 agent 跑一次固定 toy feature。

---

## 12. 建議的 P0 / P1 / P2 任務

| 優先級 | 任務 | 目的 |
|---:|---|---|
| P0 | 建立 `yuanxi-sdd-pack` 目錄或 repo | 把可安裝內容從 workspace 拆出 |
| P0 | 決定第一版只包含 discover、readiness、governance-lite | 控制 scope，避免一次搬太多 |
| P0 | 寫 `INSTALL.md` | 明確定義 official-first 安裝流程 |
| P0 | 寫 `COMPATIBILITY.md` | 記錄支援的 spec-kit 版本 |
| P1 | 建立 installer script | 讓安裝可複製 |
| P1 | 建立 smoke-test project | 每次升級可驗證 |
| P1 | 建立 artifact contract check | 降低 spec.md / plan.md / tasks.md 格式漂移風險 |
| P1 | 建立 `check-template-drift.ps1` | 若未來覆寫 template，可追蹤 upstream drift |
| P2 | 拆 repo 成 `yuanxi-sdd-pack` | 讓 package 邊界乾淨 |
| P2 | 加入 `/speckit.eci` | 處理 external capability intake |
| P2 | 加入 `/speckit.verify`、`/speckit.drift` | 補 implementation 後的反查關卡 |

---

## 13. 建議的 v0.1 範圍

`yuanxi-sdd-pack v0.1` 不要太大。

建議只包含：

1. yuanxi-discover extension。
2. yuanxi-readiness extension。
3. yuanxi-governance-lite preset。
4. Install script。
5. Compatibility matrix。
6. Smoke test script。

暫時不包含大量 community extensions、全面覆寫官方 templates、多 agent 完整 adapter、
舊 projects migration、自動改寫既有專案或複雜 hooks。

v0.1 的成功標準：

1. Yuanxi pack 可安裝到任意受測的 official Spec Kit 專案。
2. 安裝後可使用 discover 與 readiness commands。
3. 安裝不破壞官方 specify、plan、tasks 與 implement commands。
4. 一個固定 toy feature 可以完成相容性 smoke test。

---

## 14. 建議的 repo policy

### 14.1 Pack source of truth

`presets/`、`extensions/`、`installer/`、`docs/` 與 `tests/` 才是可安裝 package 的 source
of truth。

### 14.2 Generated artifacts

以下不應手工維護：

- `resources/agent-skill-packs/`
- Project-local `.github/`
- Project-local `.claude/`
- Project-local generated commands

它們應該由 export / install script 產生。

### 14.3 不修改 upstream core

`yuanxi-sdd-pack` 不應修改或複製官方 spec-kit core。若需要相容，透過 extension / preset / installer 處理。

### 14.4 每次升級都要跑 compatibility smoke test

升級 spec-kit 前後，必須至少跑：

```text
specify version
specify check
specify init smoke-test
install yuanxi-sdd-pack
specify extension list
specify preset list
```

---

## 15. 最終決策建議

建議採用以下決策：

1. Adopt official Spec Kit as the base runtime.
2. Convert SDD-WorkSpace customizations into an installable overlay pack.
3. Do not fork or overwrite official core commands by default.
4. Use extensions for new workflows and presets for artifact formatting and governance
   conventions.
5. Keep SDD-WorkSpace as the development and studio repository.
6. Create a clean yuanxi-sdd-pack package boundary.

這會把你的系統從「容易被 upstream 變動追著跑」變成「可測試、可安裝、可升級的個人 SDD distribution」。

---

## Website Content Agent Spec

> 注意：本文件不是網站頁面內容，而是為了符合你長期偏好的 LLM-readable Markdown / agent-readable 文件格式，保留此章節作為 agent 使用規格。

### Agent Role

你是 `Yuanxi SDD Pack Migration Agent`，負責協助把既有 `SDD-WorkSpace` 的客製化內容，重構為可安裝的 official spec-kit overlay pack。

### Primary Goal

將使用者的 SDD 個人化治理、commands、templates、workflow gates 與 agent adapters，整理成
由 extensions、presets、installer 與 compatibility tests 組成的 `yuanxi-sdd-pack`。

而不是繼續維護一個會與 upstream spec-kit drift 的 fork-like workspace。

### Operating Principles

1. **Official-first**：任何新專案都先透過官方 `specify init` 建立。
2. **Overlay-only**：使用者的內容以 extension / preset / installer 接入，不改官方 core。
3. **No core command overwrite by default**：除非有明確理由，不覆寫 `/speckit.specify`、`/speckit.plan`、`/speckit.tasks`、`/speckit.implement`。
4. **Low drift first**：第一版先新增 commands 與輔助 templates，不直接覆寫 core templates。
5. **Compatibility is explicit**：每個 pack version 都要記錄支援的 spec-kit version。
6. **Generated artifacts are not source of truth**：agent skill packs、project-local generated commands 不應手工維護。
7. **Scope control**：v0.1 只做 discover、readiness、governance-lite、installer、smoke test。

### Required Outputs When Implementing

當 agent 協助建立此 pack 時，至少應產生：

- `presets/yuanxi-governance-lite/`
- `extensions/yuanxi-discover/`
- `extensions/yuanxi-readiness/`
- `installer/install.ps1`
- `installer/install.sh`
- `docs/INSTALL.md`
- `docs/COMPATIBILITY.md`
- `docs/UPGRADE.md`
- `tests/smoke-test.md`

### Validation Checklist

在宣稱完成前，必須確認：

- 可以在受測的 official Spec Kit 新專案中安裝。
- 安裝後官方 core commands 仍存在，且新增 commands 可見。
- 不需要手工複製 workspace 檔案，也沒有覆寫官方 core command。
- Generated artifacts 沒有被當成 source of truth。
- Compatibility matrix 與 smoke test 流程都有可重現證據。

### Non-goals

- 不重構所有舊 `projects/`。
- 不批次 migration `learning/`。
- 不直接把 SDD-WorkSpace root 變成普通 Spec Kit project。
- 不安裝未審查的 community extensions。
- 不先做完整多 agent adapter。
- 不一開始覆寫所有 official templates。

---

## 16. 參考來源

- Official Spec Kit Repository: https://github.com/github/spec-kit
- Official Spec Kit README: https://raw.githubusercontent.com/github/spec-kit/main/README.md
- Official Extensions Reference: https://raw.githubusercontent.com/github/spec-kit/main/docs/reference/extensions.md
- Official Presets Reference: https://raw.githubusercontent.com/github/spec-kit/main/docs/reference/presets.md
- User SDD-WorkSpace Repository: https://github.com/dtgfdgfgf/SDD-WorkSpace/tree/main
