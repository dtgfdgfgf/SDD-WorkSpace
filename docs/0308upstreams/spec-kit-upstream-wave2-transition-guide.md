# 第二波 Upstream 對齊過渡指南（2026-03-08）

**Status:** Active execution baseline  
**Scope:** `C:\Users\user\Workspace`  
**Goal:** 在不破壞 `studio-first` 架構的前提下，吸收最新版 `github/spec-kit` 的第二波可取能力。  
**Primary audience:** 你自己未來執行第二波對齊時的操作與決策依據。

## 1. 這份文件要解決什麼問題

第一波對齊已完成的事情，是把本地工作區先收斂成自洽的 `studio-first` 變體。

目前要進入的第二波，不是再做一次內部大掃除，而是回答下面這個更精確的問題：

**在不改變 `studio-first` 核心前提、不更動既有專案、不重構 `update-agent-context.ps1` 的情況下，最新版 upstream `spec-kit` 還有哪些能力值得吸收，以及應該怎麼吸收。**

這份文件的作用，就是把第二波對齊從「想法」整理成「可以分階段執行的過渡方案」。 

## 2. 第二波的硬限制（Hard Constraints）

這一節不是建議，而是必須固定的前提。後續所有設計與實作都必須建立在這些前提上。

| Constraint | 說明 | 結果 |
|------------|------|------|
| 維持 `studio-first template precedence` | `studio/templates/...` 仍是 shared baseline，project-local template 只作 fallback 或專案內部補充 | 不改模板優先序 |
| 不更動既有專案 | `projects/` 與 `learning/` 目前存在歷史差異，但第二波不做批次 migration | 不回填 legacy projects |
| 暫不重構 `update-agent-context.ps1` | 這支腳本現有設計問題先接受 | 不在本波整理其 agent target mapping |
| 不做 repo-local full `.specify` migration | 不把每個專案改造成 upstream 標準 repo-local clone | 保留中央治理與共享 runtime model |
| 不讓共享來源失去單一真相 | `.github/agents/`、`.github/prompts/`、`studio/templates/...` 仍需維持清楚的 authority 邊界 | 不新增 competing source |

## 3. 最新 upstream 基線（已於 2026-03-08 再確認）

我這次重查的官方基線，重點如下：

| Upstream capability | 官方現況 | 對本地第二波的意義 |
|---------------------|----------|----------------------|
| `/speckit.*` namespaced commands | 仍是官方標準入口 | 本地已完成第一波對齊 |
| `--ai generic --ai-commands-dir ...` | 仍是官方 generic/BYO agent 路徑 | 本地已在第一波以 export helper 形式吸收 |
| `--ai-skills` | 官方明確支援 | 本地已以 export-only 形式吸收，安裝層仍保留後續評估 |
| extension system | 官方已形成明確能力線 | 本地第二波的第二候選能力 |
| catalog / extension lifecycle | 官方 extension 生態的一部分 | 本地需要先做治理設計，再決定實作深度 |
| 更廣 agent matrix | 官方 agent 支援仍比本地更完整 | 本地可觀察，但本波不以 agent context 重構為主 |

目前 upstream 官方來源仍然可以從以下文件確認：

- README
- Upgrade Guide
- Releases 頁面
- 你自己的 upstream 研究檔：`https-github-com-github-spec-kit-repo-2025-10-01-2.md`

## 4. 本地目前的起始狀態

第二波開始前，本地已具備的基礎如下：

| 類別 | 現況 |
|------|------|
| 架構模式 | `studio-first` centralized governance |
| 治理基線 | `studio/constitution/constitution.md` v1.3.0 |
| 結構基線 | `WORKSPACE_STRUCTURE.md` v1.2.0 |
| 共享 agents | root `.github/agents/` |
| 共享 prompts | root `.github/prompts/` |
| 第一波已吸收能力 | `/speckit.*`、`clarify / analyze / checklist / taskstoissues`、本地 `speckit.version`、generic pack export |
| 第二波已吸收能力 | export-only `AI skills` 本地適配：`export-agent-skills.ps1` 產生 `resources/agent-skill-packs/<target>/`；extension registry foundation 已落地到 `studio/extensions/` |
| 本波明確非目標 | legacy 專案回填、`update-agent-context.ps1` 重構、template precedence 改動 |

第二波不需要再回頭解決第一波已經解掉的問題，例如：

- workflow 定義衝突
- checklist task format drift
- zh-TW hook false negative
- `contracts/` 規則與樣本不一致
- runtime source 路徑漂移

## 5. 第二波真正要對齊什麼

第二波不應該把 upstream 全部照搬，而應該把目標收斂成下面三條能力線。

### 5.1 能力線 A：AI Skills 本地適配

這條能力線現在已經以 **export-only** 形式落地，作為第二波的第一個已實作能力。

**目前已完成的事：**

- 新增 `studio/scripts/powershell/export-agent-skills.ps1`
- 從 root `.github/agents/` 與 `.github/prompts/` 產生 generated skill packs
- 預設輸出到 `resources/agent-skill-packs/<target>/`
- 目前先支援 `codex` 與 `claude`

**本地吸收的不是 upstream 原樣，而是它的能力模型：**

- shared prompts / agents 可以被轉成 agent-friendly skills
- skills 是 generated artifact，不是新的 canonical source
- skills 匯出不直接改寫既有專案或 agent home 目錄

**目前採用的本地模型：**

| 項目 | 採用結果 |
|------|----------|
| Canonical source | 仍是 `.github/agents/` + `.github/prompts/` |
| Skill source model | 從 shared sources 產生，不手工雙維護 |
| 匯出位置 | `resources/agent-skill-packs/<target>/` |
| 安裝策略 | 先 export，後 install；本波不做 direct install |
| 初始支援範圍 | `codex`、`claude` |

**這一條能力線的核心原則：**

> Skills 是 export artifact，不是新的 source of truth。

### 5.2 能力線 B：Extension System 的 studio-first 版本

這條能力線現在已先以 **registry foundation** 形式落地，但刻意停在 shared-layer registry，不往 lifecycle 與 distribution 繼續擴張。

**目前已完成的事：**

- 建立 `studio/extensions/` canonical shared registry
- 建立 `manifest.schema.json`
- 建立 `catalog.json` 與 `state.json`
- 實作 `list-extensions.ps1` 與 `set-extension-state.ps1`

**為什麼本地只做到這一層：**

- upstream 預設思維偏 repo-local
- 你的工作區是 centralized runtime model
- 如果直接照抄完整 lifecycle，很容易出現第二套 authority tree

因此本地先吸收的是「extension 的治理模型與 registry 基礎設施」，不是完整 CLI 管理功能。

**目前採用的本地模型：**

| 項目 | 採用結果 |
|------|----------|
| Canonical extension source | `studio/extensions/` |
| Runtime exposure | 尚未做 runtime export |
| Enable / disable state | `state.json` workspace-level 管理 |
| Manifest ownership | extension 自帶 manifest，catalog/state 由 workspace 控制 |
| Rollout strategy | 先 registry 與 state，後 catalog，再評估 lifecycle |

**這一條能力線的核心原則：**

> Extension 是 shared runtime capability，不是 project-local customization dump。

### 5.3 能力線 C：Catalog / Curated Distribution

這條能力線不能先於 extension registry 本身，但需要提前定義原則。

**本地不該做的事情：**

- 一開始就導入 community extension catalog
- 在沒有 trust policy 前就開放任意 extension install/update
- 把 catalog 做成自動影響所有專案的黑盒機制

**本地應該先做的事情：**

- 先定義 curated catalog policy
- 明確 catalog 只服務 workspace shared runtime
- catalog 的單位應該是「可審核 capability」，不是任何人都能直接注入的 script bundle

## 6. 第二波的建議目錄模型

這一節不是要求你立刻建立所有檔案，而是先固定一個不會破壞 `studio-first` 的目錄心智模型。

### 6.1 Skills 建議目錄

| Path | 角色 |
|------|------|
| `.github/agents/` | 仍是 canonical shared agent source |
| `.github/prompts/` | 仍是 canonical shared prompt source |
| `resources/agent-skill-packs/<agent>/` | 匯出的 skill pack（generated artifact） |
| `studio/scripts/powershell/export-agent-skills.ps1` | 將 shared runtime sources 轉成 skills 的 export script |
| `studio/templates/sdd-skills/` | 若之後需要 skill-specific template，可放這裡，但不能取代 canonical source |

### 6.2 Extensions 建議目錄

| Path | 角色 |
|------|------|
| `studio/extensions/<extension-id>/` | extension canonical source |
| `studio/extensions/catalog.json` | workspace curated catalog |
| `studio/extensions/state.json` | enable / disable state |
| `studio/scripts/powershell/list-extensions.ps1` | list/info 類指令 |
| `studio/scripts/powershell/set-extension-state.ps1` | enable / disable 類指令 |
| `studio/scripts/powershell/export-extensions.ps1` | 若 runtime 需要 mirror，再由這支 export |

### 6.3 不應新增的目錄模式

| 不建議模式 | 原因 |
|------------|------|
| `<project>/.specify/extensions/` | 會把 centralized runtime 重新打散回 repo-local |
| `<project>/.github/skills/` 作為 canonical source | 會讓 skills 變成新 authority，破壞單一真相 |
| 直接把 extension / skills 當成各 project 的手改資產 | 長期會失去可維護性 |

## 7. 第二波建議分階段執行

這一節是你未來真正要照著跑的順序。

### Phase 0：固定前提與凍結範圍

**目的：** 確保第二波不失控。

**這一階段要確認的事：**

- `studio-first template precedence` 明確視為既定前提
- existing projects 不動
- `update-agent-context.ps1` 不動
- 這一波只新增 shared layer 能力

**輸出：**

- 本文件
- `spec-kit-upstream-alignment-matrix.md`
- 明確 non-goals

### Phase 1：AI Skills 設計與匯出

**狀態：** 已完成第一版 export-only 實作。

**已完成的事：**

1. 決定 skills 的 export format 為 folder-based `SKILL.md` + `references/`
2. 決定先支援 `codex` 與 `claude`
3. 實作 `export-agent-skills.ps1`
4. 匯出 skill pack 到 `resources/agent-skill-packs/<target>/`
5. 驗證 exported artifact 可讀、可重跑，且不直接寫入 agent home 或 project tree

**完成標準：**

| 檢查項目 | 目前狀態 |
|----------|----------|
| Canonical source 未改變 | 已滿足 |
| Skills 可重建 | 已滿足 |
| Skills 不直接污染 project | 已滿足 |
| Skills 不要求 immediate install | 已滿足 |

### Phase 2：Extension Registry 基礎建設

**狀態：** 已完成第一版 registry foundation 實作。

**已完成的事：**

1. 定義 extension manifest schema
2. 建立 `studio/extensions/` canonical layout
3. 建立 `catalog.json` 與 `state.json`
4. 實作 read-only tooling：`list-extensions.ps1`
5. 實作最小 `enable/disable`：`set-extension-state.ps1`

**這一階段刻意沒有做的事：**

- 不做自動 install from internet
- 不做 community catalog sync
- 不做複雜 update lifecycle
- 不做 runtime export
- 不把 extension 自動注入所有 project

**完成標準：**

| 檢查項目 | 目前狀態 |
|----------|----------|
| Canonical source 明確 | 已滿足 |
| 狀態管理可追蹤 | 已滿足 |
| 不影響既有專案 | 已滿足 |
| 可觀察 | 已滿足 |

### Phase 3：Catalog 治理與分發策略

**目的：** 讓 extension 不只是檔案，而是可管理能力。

**要做的事：**

1. 定義 curated catalog policy
2. 決定 catalog metadata 欄位
3. 定義 extension trust / review 標準
4. 決定哪些 extension 可以進入「預設啟用候選」

**這一階段重點不是功能，而是治理。**

### Phase 4：後續擴張（可選）

這一階段不是第二波最前面要做的事，但可以先記錄：

- 擴充更多 agent-specific skill adapters
- 補更完整 extension lifecycle
- 補 curated internal catalog tooling
- 之後再評估是否更新 `update-agent-context.ps1`

## 8. 第二波的決策順序（不要顛倒）

如果你之後真的要動手，建議決策順序如下：

1. 先決定 canonical source 是什麼
2. 再決定 generated artifact 長什麼樣
3. 再決定 export / install / enable / disable 流程
4. 最後才決定要不要做 automation convenience

如果順序顛倒，很容易出現：

- 先做安裝腳本，後面才發現 source of truth 不清楚
- 先做 extension manager，後面才發現 governance model 和 `studio-first` 衝突
- 先改 project tree，後面才發現根本不該碰既有專案

## 9. 第二波的主要風險與對策

| 風險 | 描述 | 對策 |
|------|------|------|
| 新的 authority 漂移 | skills / extensions 變成新的真源 | 明確規定它們只能是 generated artifact 或 centralized source |
| 範圍失控 | 第二波從 upstream 對齊變成大規模內部重構 | 把 non-goals 寫死並在每階段驗證 |
| 影響既有專案 | 匯出或啟用流程誤寫入 project | 所有能力先作用於 shared layer 或 export dir |
| extension 模型過早複雜化 | 一開始就模仿 upstream 全套 lifecycle | 先 registry，再 state，再 catalog，再 lifecycle |
| skills 模型過早綁定單一 agent | 一開始就直接綁死某個 agent home 目錄 | 先 export 到 workspace 內，再決定安裝器 |
| 文件先於能力失真 | 文件畫太大，但實作沒有落地 | 每個 phase 都要有可執行驗證與最小 deliverable |

## 10. 第二波的驗證清單

這一節是給你之後每做完一小段就能自查的。

### 10.1 通用驗證

- [ ] 沒有修改任何 `projects/` 或 `learning/` 內既有專案內容
- [ ] 沒有更改 `studio-first template precedence`
- [ ] 沒有重構 `update-agent-context.ps1`
- [ ] 沒有新增 competing source of truth

### 10.2 Skills 驗證

- [ ] skills 來源可追溯到 shared runtime source
- [ ] 匯出結果可刪除並重建
- [ ] 匯出結果不需要手工雙維護
- [ ] 匯出流程不直接污染 agent home 或 project tree

### 10.3 Extension 驗證

- [ ] extension manifest schema 清楚
- [ ] catalog 與 state 分離
- [ ] enable / disable 行為可預測
- [ ] extension registry 不要求 repo-local 遷移

## 11. 我對第二波的建議優先序

如果只談從現在開始的實際執行順序，我會建議這樣排：

1. **先做 catalog / curated distribution 的治理模型**
   - 理由：registry foundation 已落地，下一步該補的是 trust 與 curated policy

2. **再做 extension runtime export / lifecycle 邊界**
   - 理由：先把治理定清楚，再決定 runtime mirror 與 lifecycle 到底做到哪裡

3. **最後才評估 skill install convenience**
   - 理由：skills 仍應維持 export-only 為主，安裝便利層不應先於治理與 lifecycle 邊界

## 12. 本文件與其他文件的關係

| 文件 | 用途 |
|------|------|
| `docs/0308upstreams/learning-project-spec-kit-sdd.md` | 2026-03-08 工作區狀態與第二波目標的歷史快照 |
| `spec-kit-upstream-alignment-matrix.md` | 對齊項目的決策表 |
| **本文件** | 第二波的詳細過渡與執行指南 |
| `https-github-com-github-spec-kit-repo-2025-10-01-2.md` | upstream 研究基線 |

## 13. 最終結論

第二波 upstream 對齊的正確方向，不是「把 upstream 最新 spec-kit 整套搬進來」，而是：

**在不動既有專案、不改變 `studio-first template precedence`、不重構 `update-agent-context.ps1` 的前提下，先吸收 `AI skills` 與 extension registry 基礎設施，再往 catalog 與 lifecycle 治理推進，並把這些能力設計成 shared-layer、可重建、可回滾的本地適配。**

## 14. 參考來源

- Official README: https://raw.githubusercontent.com/github/spec-kit/main/README.md
- Official Upgrade Guide: https://raw.githubusercontent.com/github/spec-kit/main/docs/upgrade.md
- Official Releases: https://github.com/github/spec-kit/releases
- Local upstream analysis: `https-github-com-github-spec-kit-repo-2025-10-01-2.md`
- Local workspace analysis: `docs/0308upstreams/learning-project-spec-kit-sdd.md`
- Local alignment matrix: `spec-kit-upstream-alignment-matrix.md`


