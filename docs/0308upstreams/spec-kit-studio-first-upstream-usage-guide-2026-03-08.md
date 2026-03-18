# Studio-First 與 Upstream Spec Kit 使用差異與新功能手冊（2026-03-08）

## 目的

這份文件說明三件事：

1. 原本舊版 / 早期本地 Spec Kit 的使用方式是什麼
2. 最新 upstream `github/spec-kit` 的使用方式多了哪些能力
3. 這個工作區目前的 **studio-first selective alignment** 版本，和前兩者的差異、正確用法、以及每個新功能的逐步操作流程

這份文件不是 upstream README 的中文翻譯，而是 **針對目前這個 workspace 的實際操作手冊**。

---

## 一句話先講清楚

### 原本的 Spec Kit

- 偏向 **repo-local**
- 以每個專案自己的 `.specify/` 為中心
- 常見心智模型是「進到某個 repo，跑 `specify init`，把能力裝進該 repo」

### 最新 upstream Spec Kit

- 仍然是 **repo-local** 為主
- 多了更完整的 agent matrix、`specify check`、`--ai-skills`、extension lifecycle、catalog 生態
- 官方操作重點仍是 `specify init`, `specify check`, `specify extension ...`

### 這個 workspace 的 studio-first 版本

- 是 **workspace-level centralized runtime / governance**
- canonical source 在 shared layer，不在每個 project
- 不是把 upstream 整套照搬，而是把 upstream 新能力改造成適合這個 workspace 的 shared-layer 工具鏈
- **不要對既有專案直接跑 upstream `specify init --here --force`**

---

## 核心差異總覽

| 面向 | 原本 / 舊版 Spec Kit | 最新 upstream Spec Kit | 本地 studio-first 對齊版 |
|------|----------------------|------------------------|---------------------------|
| 主要架構 | repo-local | repo-local | workspace-level shared runtime |
| canonical commands | `.specify/templates/commands` 或 repo 內命令資產 | 同 upstream repo / init 後的 project tree | root `.github/agents/` + `.github/prompts/` |
| canonical templates | project-local `.specify/templates/` | project-local `.specify/templates/` | `studio/templates/` 優先，project-local 僅 fallback |
| 對既有專案的處理 | 容易傾向覆寫 / 重建 repo-local 資產 | 官方仍以 project init / re-init 為主 | 明確避免批次改動 `projects/` / `learning/` |
| `version` 能力 | 舊版本地通常沒有 | upstream 已有 | 本地用 `get-speckit-version.ps1` + `/speckit.version` |
| generic/BYO agent 支援 | 較弱或沒有 | `--ai generic --ai-commands-dir` | `export-generic-agent-pack.ps1` |
| AI skills | 舊版通常沒有 | `--ai-skills` 正式支援 | `export-agent-skills.ps1` + `install-agent-skills.ps1` |
| extension system | 沒有或很早期 | 有 catalog / lifecycle / install/remove | `studio/extensions/` shared registry + validator + export mirror |
| tool / agent check | 較分散 | `specify check` | `check-speckit-runtime.ps1` |
| 升級方式 | 常是 project-by-project | 常是 repo-local re-init / extension flows | `upgrade-studio-runtime.ps1` 只動 shared layer |

---

## 這個 workspace 現在的 source of truth

### Shared runtime canonical sources

- `.github/agents/`
- `.github/prompts/`
- `studio/templates/`
- `studio/scripts/powershell/`
- `studio/extensions/<extension-id>/`

### Generated artifacts

- `resources/agent-skill-packs/<target>/`
- `resources/studio-runtime/merged/`

### 治理檔案

- `studio/extensions/catalog.json`
- `studio/extensions/state.json`
- `studio/extensions/manifest.schema.json`
- `studio/extensions/catalog.schema.json`
- `studio/extensions/state.schema.json`
- `studio/extensions/POLICY.md`
- `studio/upstream/shared-layer-map.json`

### 重要原則

- generated artifact 不是 source of truth
- 不要手改 generated runtime mirror
- 不要把 skills 當成新的 canonical source
- 不要把 extension 變成 project-local customization dump

---

## 使用前的共同檢查流程

所有新功能都建議先做這三步。

### Step 1: 確認目前 shared-layer 版本狀態

```powershell
.\studio\scripts\powershell\get-speckit-version.ps1
```

如果要機器可讀輸出：

```powershell
.\studio\scripts\powershell\get-speckit-version.ps1 -Json
```

你會看到：

- 目前 mode 是否為 `studio-first`
- runtime source mode 是 `core` 還是 `merged`
- runtime agents / prompts 數量
- extension registry 是否有效
- 已支援的 agent context
- 已吸收與 deferred 的 upstream capability 摘要

### Step 2: 檢查 runtime 健康度與工具可用性

```powershell
.\studio\scripts\powershell\check-speckit-runtime.ps1
```

如果要 JSON：

```powershell
.\studio\scripts\powershell\check-speckit-runtime.ps1 -Json
```

這一步會檢查：

- `git`
- `pwsh`
- `claude`
- `gemini`
- `code` / `code-insiders`
- `cursor-agent`
- `windsurf`
- `qwen`
- `opencode`
- `codex`
- `kiro-cli`
- `shai`
- `qodercli`
- extension registry validity
- skills pack / install readiness
- merged runtime 狀態

### Step 3: 如有 extension 變更，先決定 runtime source mode

如果你最近有：

- add extension
- remove extension
- enable / disable extension

請先重建 merged runtime：

```powershell
.\studio\scripts\powershell\export-extensions.ps1 -Force
```

原因：

- `export-agent-skills.ps1`
- `export-generic-agent-pack.ps1`
- `check-speckit-runtime.ps1`

都會優先吃 merged runtime；如果你改了 extension state 卻沒重建 mirror，後續 export 可能仍然使用舊的 merged runtime。

---

## 功能 1：`/speckit.*` command set 的用法

這部分和第一波對齊後基本相同，但要理解新的 shared-layer 模型。

### 你要知道的差異

- upstream 主要是把命令安裝進 project-local agent command tree
- 本地 studio-first 是把 shared runtime 維持在 workspace root，再由 agent 使用 shared source 或 generated artifact

### 目前可用的 shared `speckit.*` 命令

- `/speckit.specify`
- `/speckit.clarify`
- `/speckit.plan`
- `/speckit.tasks`
- `/speckit.analyze`
- `/speckit.checklist`
- `/speckit.implement`
- `/speckit.taskstoissues`
- `/speckit.constitution`
- `/speckit.version`
- `/speckit.discover`

### 基本使用步驟

1. 確認 `.github/agents/` 與 `.github/prompts/` 已存在
2. 進到你的 agent runtime
3. 直接呼叫對應 `/speckit.*` 命令
4. 如果你是 BYO / unsupported agent，先匯出 generic pack 或 skill pack 再使用

---

## 功能 2：本地 `speckit.version`

這是對 upstream `specify version` 的本地適配。

### 舊模型

- 舊版本地沒有一致的 version summary

### upstream

- 有正式 version 能力

### 本地 studio-first

- shell 入口：`get-speckit-version.ps1`
- agent 入口：`/speckit.version`

### 步驟

#### Shell 檢查

```powershell
.\studio\scripts\powershell\get-speckit-version.ps1
```

#### JSON 檢查

```powershell
.\studio\scripts\powershell\get-speckit-version.ps1 -Json
```

### 什麼時候用

- 升級 shared layer 前後
- 想確認目前 runtime source mode
- 想看這個 workspace 已吸收哪些 upstream capability
- 想確認 agent matrix 是否已更新

---

## 功能 3：generic / BYO agent pack export

這是本地對 upstream `--ai generic --ai-commands-dir ...` 的適配。

### 差異

#### upstream

- 通常在 `specify init` 當下把命令放進指定 agent commands dir

#### 本地 studio-first

- 不直接往未知 agent home 寫入
- 先輸出一個 generic pack 給 unsupported / BYO agent 環境使用

### 什麼時候用

- 你的 agent 不在本地正式 support matrix 裡
- 你要把 shared runtime 交給其他工具或團隊
- 你想先檢查 export 內容，再手動接入外部 agent

### 步驟

#### Step 1: 準備輸出資料夾

```powershell
$out = "C:\temp\my-generic-pack"
```

#### Step 2: 匯出 generic pack

```powershell
.\studio\scripts\powershell\export-generic-agent-pack.ps1 -OutputDir $out -Force
```

#### Step 3: 如果要看 JSON 結果

```powershell
.\studio\scripts\powershell\export-generic-agent-pack.ps1 -OutputDir $out -Force -Json
```

### 輸出內容

- `agents/`
- `prompts/`
- `manifest.json`
- `README.md`

### 重要注意事項

- 如果 merged runtime 存在，這支腳本會優先輸出 merged runtime
- 如果沒有 merged runtime，才退回 core shared sources
- 這個 pack 是 mirror，不是 source of truth

---

## 功能 4：AI skills export

這是本地對 upstream `--ai-skills` 的第一層適配。

### 差異

#### upstream

- `--ai-skills` 可在 init 流程中直接裝進 agent-specific skills directory

#### 本地 studio-first

- 先 export 成可檢查、可重建的 skill pack
- 再由 installer 決定是否裝進 agent home

### 目前支援 target

- `codex`
- `claude`

### 步驟

#### Step 1: 選定 target

```powershell
$target = "codex"
```

#### Step 2: 匯出 skill pack

```powershell
.\studio\scripts\powershell\export-agent-skills.ps1 -Target $target -Force
```

預設輸出到：

```text
resources/agent-skill-packs/<target>/
```

#### Step 3: 指定自訂輸出路徑

```powershell
$out = "C:\temp\skills-codex"
.\studio\scripts\powershell\export-agent-skills.ps1 -Target codex -OutputDir $out -Force
```

#### Step 4: 取得 JSON 結果

```powershell
.\studio\scripts\powershell\export-agent-skills.ps1 -Target codex -OutputDir $out -Force -Json
```

### 輸出內容

- `skills/<skill>/SKILL.md`
- `skills/<skill>/references/agent.md`
- `skills/<skill>/references/prompt.md`（如果有對應 prompt）
- `manifest.json`
- `README.md`

### 重要注意事項

- `skills` 是 generated artifact，不要手改
- 如果 extension 有進 merged runtime，skills export 會優先使用 merged runtime
- 若想讓 export 回到純 core 模式，請先重新整理 runtime mirror 或移除舊 mirror

---

## 功能 5：AI skills install / status / uninstall

這是本地對 upstream `--ai-skills` 的第二層適配，也是這次補上的完整安裝層。

### 支援 target

- `codex`
- `claude`

### 解析 install root 的順序

1. `-InstallRoot`
2. target 對應 env/config
3. fallback

目前 fallback：

- `codex` → `%USERPROFILE%\.codex\skills`
- `claude` → `%USERPROFILE%\.claude\skills`

### 管理方式

installer 只管理：

```text
<skills-root>\studio-first-speckit\
```

不會去碰使用者其他自訂 skills。

---

### 5.1 安裝 skills

#### Step 1: 建議先 refresh pack

```powershell
.\studio\scripts\powershell\install-agent-skills.ps1 -Target codex -Mode install -Refresh
```

這會先：

1. 重跑 `export-agent-skills.ps1`
2. 再把 pack 安裝到 agent skills root 下的 `studio-first-speckit/`

#### Step 2: 指定自訂 install root

```powershell
$skillsRoot = "C:\temp\codex-skills"
.\studio\scripts\powershell\install-agent-skills.ps1 -Target codex -Mode install -InstallRoot $skillsRoot -Refresh
```

#### Step 3: JSON 結果

```powershell
.\studio\scripts\powershell\install-agent-skills.ps1 -Target codex -Mode install -InstallRoot $skillsRoot -Refresh -Json
```

### 安裝成功後你會得到

- `studio-first-speckit/` managed namespace
- 其中包含各個 `speckit-*` skill 目錄
- `manifest.json`
- `README.md`

---

### 5.2 檢查 skills 安裝狀態

```powershell
.\studio\scripts\powershell\install-agent-skills.ps1 -Target codex -Mode status
```

或指定自訂 root：

```powershell
.\studio\scripts\powershell\install-agent-skills.ps1 -Target codex -Mode status -InstallRoot "C:\temp\codex-skills"
```

JSON：

```powershell
.\studio\scripts\powershell\install-agent-skills.ps1 -Target codex -Mode status -Json
```

你會看到：

- source pack 是否 ready
- install root 在哪
- managed namespace 路徑
- 是否已安裝
- skill 數量
- skills 名單

---

### 5.3 移除 managed skills

```powershell
.\studio\scripts\powershell\install-agent-skills.ps1 -Target codex -Mode uninstall
```

或指定自訂 root：

```powershell
.\studio\scripts\powershell\install-agent-skills.ps1 -Target codex -Mode uninstall -InstallRoot "C:\temp\codex-skills"
```

### 注意事項

- 只會移除 `studio-first-speckit/`
- 不會刪掉你自己的其他 skills

---

## 功能 6：extension registry 治理檢查

這是本地對 upstream extension 生態的 studio-first 版本。

### 差異

#### upstream

- 偏向 project-local extension lifecycle

#### 本地 studio-first

- extension canonical source 固定在 `studio/extensions/`
- 以 workspace-level catalog / state 管理
- 先做治理，再做 runtime export

### 先看治理檔案

- `studio/extensions/POLICY.md`
- `studio/extensions/catalog.json`
- `studio/extensions/state.json`
- `studio/extensions/manifest.schema.json`
- `studio/extensions/catalog.schema.json`
- `studio/extensions/state.schema.json`

### 檢查 registry 是否有效

```powershell
.\studio\scripts\powershell\validate-extension-registry.ps1
```

JSON：

```powershell
.\studio\scripts\powershell\validate-extension-registry.ps1 -Json
```

### 這支腳本會驗證什麼

- catalog 欄位完整性
- state 欄位完整性
- manifest 必填欄位
- `compatibility.mode=studio-first`
- `entryPoints` 必須位於 extension root 內
- path 不得 escape
- `defaultEnabled=true` 的治理規則
- catalog / manifest / state 三者一致性

---

## 功能 7：列出 extension 狀態

### 步驟

```powershell
.\studio\scripts\powershell\list-extensions.ps1
```

單看某一個：

```powershell
.\studio\scripts\powershell\list-extensions.ps1 -Id extension-smoke
```

JSON：

```powershell
.\studio\scripts\powershell\list-extensions.ps1 -Json
```

### 你會看到什麼

- id
- enabled
- reviewStatus
- trustLevel
- valid

### 注意事項

- `list-extensions.ps1` 現在是 validator-backed view
- 也就是說，list 結果已經帶有治理檢查語意，不只是單純列檔案

---

## 功能 7A：curated catalog / trust model 的操作

這是這次和原本 / repo-local Spec Kit 最大的治理差異之一。

### 原本常見做法

- 先裝功能，再看會不會出問題
- 或把 extension 當成可直接塞進 repo 的命令包

### 現在的 studio-first 做法

- 先進 catalog 治理
- 明確定 reviewStatus / trustLevel
- 通過治理後，才允許 enable / export

### catalog entry 的重點欄位

- `id`
- `version`
- `title`
- `sourcePath`
- `reviewStatus`
- `trustLevel`
- `defaultEnabled`
- `owner`
- `approvedBy`
- `approvedAt`
- `runtimeScopes`
- `capabilities`
- `notes`

### reviewStatus 的意義

- `draft`: 只代表已 intake，不能預設啟用
- `approved`: 可進入正式 curated rollout
- `experimental`: 可保留觀察，但不應預設啟用
- `deprecated`: 保留相容，但不建議新啟用
- `rejected`: 保留審核痕跡，但不應被啟用

### trustLevel 的意義

- `core`
- `curated`
- `experimental`

### `defaultEnabled` 規則

只有同時滿足下面兩條才合法：

1. `reviewStatus = approved`
2. `trustLevel = core` 或 `curated`

### 審核流程

#### Step 1: 先 intake extension

```powershell
.\studio\scripts\powershell\add-extension.ps1 -SourceDir <your-local-extension-dir>
```

#### Step 2: 打開 catalog

檔案位置：

```text
studio/extensions/catalog.json
```

#### Step 3: 找到對應 entry，做治理決策

新加入的 extension 預設通常是：

- `reviewStatus = draft`
- `trustLevel = experimental`
- `defaultEnabled = false`

如果你要讓它進正式 runtime rollout，必須手動調整，例如：

```json
{
  "id": "my-extension",
  "reviewStatus": "approved",
  "trustLevel": "curated",
  "defaultEnabled": false,
  "approvedBy": "studio",
  "approvedAt": "2026-03-08T00:00:00+08:00"
}
```

### 為什麼這一步目前是手動

因為這裡是治理決策，不是純技術操作。

目前本地刻意沒有做「一鍵 approve」腳本，原因是：

- 這會模糊 trust boundary
- 很容易把治理變成隨手改狀態
- 目前這個 workspace 要先保守，避免 catalog authority 失控

### Step 4: 驗證治理結果

```powershell
.\studio\scripts\powershell\validate-extension-registry.ps1
```

### Step 5: 再決定是否 enable

```powershell
.\studio\scripts\powershell\set-extension-state.ps1 -Id <extension-id> -State enabled
```

### 建議操作原則

- intake 和 approval 不要在同一步完成
- `defaultEnabled` 盡量少用
- 先 `approved + defaultEnabled=false`，觀察穩定後再考慮是否變成預設啟用候選

---

## 功能 8：新增本地 extension

本地版只支援 **workspace local source**，不支援網路下載。

### 最小 extension 結構

```text
my-extension/
  manifest.json
  scripts/
  prompts/
  agents/
  templates/
  docs/
```

你不一定需要所有子目錄，但 `manifest.json` 的 `entryPoints` 宣告的檔案必須真的存在。

### 最小 manifest 範例

```json
{
  "id": "my-extension",
  "version": "1.0.0",
  "title": "My Extension",
  "description": "Example studio-first extension.",
  "kind": "tooling",
  "status": "active",
  "owner": "studio",
  "capabilities": ["example-capability"],
  "runtimeScopes": ["scripts"],
  "compatibility": {
    "mode": "studio-first"
  },
  "entryPoints": {
    "scripts": [
      "scripts/example.ps1"
    ]
  },
  "notes": "Example only."
}
```

### 新增步驟

#### Step 1: 準備 extension source directory

例如：

```powershell
$src = "C:\Users\user\Workspace\resources\my-extension"
```

#### Step 2: 加入 shared registry

```powershell
.\studio\scripts\powershell\add-extension.ps1 -SourceDir $src
```

JSON：

```powershell
.\studio\scripts\powershell\add-extension.ps1 -SourceDir $src -Json
```

#### Step 3: 驗證 registry

```powershell
.\studio\scripts\powershell\validate-extension-registry.ps1
```

### 新加入後的預設狀態

- catalog entry 會自動建立
- `reviewStatus` 預設是 `draft`
- `trustLevel` 預設是 `experimental`
- `defaultEnabled` 預設是 `false`

這表示：

- extension 先進 governance
- 不是一加入就直接進 runtime
- 如果你要正式啟用它，先回到上一節做 catalog review / trust 決策

---

## 功能 9：啟用 / 停用 extension

### 啟用步驟

```powershell
.\studio\scripts\powershell\set-extension-state.ps1 -Id extension-smoke -State enabled
```

### 停用步驟

```powershell
.\studio\scripts\powershell\set-extension-state.ps1 -Id extension-smoke -State disabled
```

### JSON

```powershell
.\studio\scripts\powershell\set-extension-state.ps1 -Id extension-smoke -State enabled -Json
```

### 重要限制

- `reviewStatus` 必須允許啟用
- 不是任何 catalog item 都能被啟用

### 非常重要的下一步

啟用或停用後，請立刻重建 runtime mirror：

```powershell
.\studio\scripts\powershell\export-extensions.ps1 -Force
```

否則後續 generic pack / skill pack 可能仍然讀到舊 mirror。

---

## 功能 10：把 extension 匯出到 merged runtime

這是本地版的 runtime mirror。

### 差異

#### upstream

- extension 可能直接進 project-local command tree / hooks / config

#### 本地 studio-first

- extension 先經過治理
- 再匯出到 `resources/studio-runtime/merged/`
- 後續 export/check flow 優先消費這個 mirror

### 步驟

#### Step 1: 確保 registry valid

```powershell
.\studio\scripts\powershell\validate-extension-registry.ps1
```

#### Step 2: 匯出 merged runtime

```powershell
.\studio\scripts\powershell\export-extensions.ps1 -Force
```

#### Step 3: 指定自訂輸出位置

```powershell
$out = "C:\temp\studio-runtime-merged"
.\studio\scripts\powershell\export-extensions.ps1 -OutputDir $out -Force
```

#### Step 4: JSON 檢查

```powershell
.\studio\scripts\powershell\export-extensions.ps1 -OutputDir $out -Force -Json
```

### Merge 規則

1. 先放 core shared layer
2. 再放 enabled extensions
3. extension 只能新增，不能覆蓋 core
4. extension 也不能互相覆蓋
5. 發生 collision 直接 fail

### 匯出結果

- `agents/`
- `prompts/`
- `scripts/`
- `templates/`
- `docs/`
- `manifest.json`

### 重要注意事項

- `resources/studio-runtime/merged/` 是 generated mirror
- 不要手改
- 改了 extension state 後要重建它

---

## 功能 11：移除 extension

### 步驟

```powershell
.\studio\scripts\powershell\remove-extension.ps1 -Id my-extension
```

JSON：

```powershell
.\studio\scripts\powershell\remove-extension.ps1 -Id my-extension -Json
```

### 這支腳本會做什麼

- 移除 `studio/extensions/<id>/`
- 移除 `catalog.json` 裡對應 entry
- 移除 `state.json` 裡對應 state

### 移除後建議再做一次

```powershell
.\studio\scripts\powershell\export-extensions.ps1 -Force
```

讓 merged runtime 跟著更新。

---

## 功能 12：最新 agent matrix 對齊

這次本地 `update-agent-context.ps1` 已補上的新增 target：

- `qodercli`
- `kiro-cli`
- `kiro`
- `agy`
- `bob`
- `jules`

### 目前完整支援集

- `claude`
- `gemini`
- `copilot`
- `cursor-agent`
- `qwen`
- `opencode`
- `codex`
- `windsurf`
- `kilocode`
- `auggie`
- `roo`
- `codebuddy`
- `amp`
- `shai`
- `q`
- `qodercli`
- `kiro-cli`
- `kiro`
- `agy`
- `bob`
- `jules`

### 單一 agent 更新步驟

```powershell
.\studio\scripts\powershell\update-agent-context.ps1 -AgentType qodercli
```

例如：

```powershell
.\studio\scripts\powershell\update-agent-context.ps1 -AgentType kiro-cli
.\studio\scripts\powershell\update-agent-context.ps1 -AgentType bob
.\studio\scripts\powershell\update-agent-context.ps1 -AgentType jules
```

### 更新所有已存在 agent context 檔

```powershell
.\studio\scripts\powershell\update-agent-context.ps1
```

### 注意事項

- 這次是 additive parity，不是重構
- `update-agent-context.ps1` 仍維持既有結構
- 某些 agent 仍共用 `AGENTS.md` 類型路徑，這是目前本地兼容策略的一部分

---

## 功能 13：runtime / tool availability check parity

這是本地版的 `specify check` 對等入口。

### 步驟

```powershell
.\studio\scripts\powershell\check-speckit-runtime.ps1
```

JSON：

```powershell
.\studio\scripts\powershell\check-speckit-runtime.ps1 -Json
```

### 會回報哪些東西

- tools availability
- supported agent contexts
- runtime agent/prompt counts
- extension registry health
- catalog policy presence
- skills export/install readiness
- merged runtime 狀態

### 什麼時候一定要跑

- 升級 shared layer 前後
- 啟用 / 停用 extension 後
- 安裝 skills 前
- 新 agent parity 補完後

---

## 功能 14：workspace-level shared-layer sync

這是本地 studio-first 版本最重要的差異之一。

### upstream 的典型做法

- 對某個 repo 直接 `specify init --here --force ...`
- 或用 repo-local extension lifecycle

### 本地 studio-first 的做法

- 用 `upgrade-studio-runtime.ps1`
- 只更新 shared layer
- 不碰既有 project tree

### 同步白名單來源

`studio/upstream/shared-layer-map.json`

它列出允許更新的 shared-layer 路徑，例如：

- `.github/agents`
- `.github/prompts`
- `studio/scripts/powershell`
- `studio/templates`
- extension governance schema / policy

### blocked 路徑

- `projects/`
- `learning/`
- project-local `.specify`
- `studio/extensions/catalog.json`
- `studio/extensions/state.json`

也就是說：

- 升級 shared layer 時，不會覆寫你的本地治理狀態與 rollout 狀態

---

### 14.1 準備 snapshot

這支腳本吃的是 **local snapshot directory**，不是 live internet fetch。

你的 snapshot 應該是已整理成 shared-layer 形狀的本機資料夾，例如：

```text
<snapshot>/
  .github/agents/
  .github/prompts/
  studio/scripts/powershell/
  studio/templates/
  studio/extensions/manifest.schema.json
  studio/extensions/catalog.schema.json
  studio/extensions/state.schema.json
  studio/extensions/POLICY.md
```

### 14.2 Dry run

```powershell
$snapshot = "C:\temp\spec-kit-upstream-snapshot"
.\studio\scripts\powershell\upgrade-studio-runtime.ps1 -UpstreamSnapshotDir $snapshot -DryRun
```

JSON：

```powershell
.\studio\scripts\powershell\upgrade-studio-runtime.ps1 -UpstreamSnapshotDir $snapshot -DryRun -Json
```

### 14.3 Apply

```powershell
.\studio\scripts\powershell\upgrade-studio-runtime.ps1 -UpstreamSnapshotDir $snapshot -Apply
```

JSON：

```powershell
.\studio\scripts\powershell\upgrade-studio-runtime.ps1 -UpstreamSnapshotDir $snapshot -Apply -Json
```

### 14.4 Apply 後會自動做的驗證

- `get-speckit-version.ps1 -Json`
- `check-speckit-runtime.ps1 -Json`
- skills export smoke
- extension export smoke

並把結果寫到：

```text
resources/studio-runtime/upgrade-report.json
```

### 重要注意事項

- 這支腳本只保證 shared-layer allowlist
- 它不會幫你做 repo-local migration
- 它不會動 `projects/` 或 `learning/`
- 如果 snapshot 含 blocked path，腳本會直接 fail

---

## 功能 15：extension + skills 的完整實務流程

這一節用「你真的要引入一個新能力」來示範完整操作順序。

### 情境 A：我要新增一個 extension，讓它進入 shared runtime

#### Step 1

建立本地 extension source，包含合法 `manifest.json`

#### Step 2

加入 registry

```powershell
.\studio\scripts\powershell\add-extension.ps1 -SourceDir <your-local-extension-dir>
```

#### Step 3

驗證治理

```powershell
.\studio\scripts\powershell\validate-extension-registry.ps1
```

#### Step 4

如果 review / trust 狀態允許，再啟用

```powershell
.\studio\scripts\powershell\set-extension-state.ps1 -Id <extension-id> -State enabled
```

#### Step 5

重建 merged runtime

```powershell
.\studio\scripts\powershell\export-extensions.ps1 -Force
```

#### Step 6

確認 runtime 狀態

```powershell
.\studio\scripts\powershell\check-speckit-runtime.ps1
```

#### Step 7

如果你要把 extension 影響帶進 skill pack / generic pack，接著再跑：

```powershell
.\studio\scripts\powershell\export-agent-skills.ps1 -Target codex -Force
.\studio\scripts\powershell\export-generic-agent-pack.ps1 -OutputDir C:\temp\generic-pack -Force
```

---

### 情境 B：我要把現在的 shared runtime 裝成 Codex / Claude skills

#### Step 1

先確認 runtime 狀態

```powershell
.\studio\scripts\powershell\check-speckit-runtime.ps1
```

#### Step 2

如果你有 enabled extension，先重建 merged runtime

```powershell
.\studio\scripts\powershell\export-extensions.ps1 -Force
```

#### Step 3

安裝 skills

```powershell
.\studio\scripts\powershell\install-agent-skills.ps1 -Target codex -Mode install -Refresh
```

或：

```powershell
.\studio\scripts\powershell\install-agent-skills.ps1 -Target claude -Mode install -Refresh
```

#### Step 4

檢查狀態

```powershell
.\studio\scripts\powershell\install-agent-skills.ps1 -Target codex -Mode status
```

---

### 情境 C：我要升級 shared layer，但不能動既有專案

#### Step 1

準備 local snapshot

#### Step 2

先看差異

```powershell
.\studio\scripts\powershell\upgrade-studio-runtime.ps1 -UpstreamSnapshotDir <snapshot-dir> -DryRun
```

#### Step 3

確認只涉及 shared-layer allowlist

#### Step 4

套用升級

```powershell
.\studio\scripts\powershell\upgrade-studio-runtime.ps1 -UpstreamSnapshotDir <snapshot-dir> -Apply
```

#### Step 5

再次驗證

```powershell
.\studio\scripts\powershell\get-speckit-version.ps1
.\studio\scripts\powershell\check-speckit-runtime.ps1
```

---

## 原本工作習慣需要怎麼改

### 以前你可能會做的事

- 在某個 project 裡直接跑 upstream `specify init --here --force`
- 把 commands/templates 直接當 project-local 資產維護
- 想裝新 agent / 新能力時，直接往 project tree 塞檔案

### 現在應該改成

- 先看 shared layer，不先動 project tree
- 新能力先進 `studio/extensions/` 或 shared agents/prompts
- 先治理、再 enable、再 export runtime
- skills 先 export，再 install
- 升級先 dry-run，再 apply shared-layer sync

---

## 不建議的做法

### 1. 對既有專案直接跑 upstream repo-local migration

不建議原因：

- 會破壞 `studio-first` centralized runtime model
- 有覆蓋 `.specify/templates/` 與 constitution 相關檔案的風險

### 2. 把 generated skill pack 當成 source of truth

不建議原因：

- 你之後一 refresh 就會覆蓋它
- 真正 authority 應該仍是 `.github/agents/` + `.github/prompts/`

### 3. 手改 `resources/studio-runtime/merged/`

不建議原因：

- 它是 generated mirror
- 正確做法應該是改 extension source / state，然後重新 export

### 4. 把 extension 直接放進 project tree

不建議原因：

- 會把 centralized runtime 打散
- 長期難治理、難升級、難回滾

---

## 建議的日常操作順序

如果你每天都在這個 workspace 上工作，最穩的習慣是：

### 日常檢查

```powershell
.\studio\scripts\powershell\get-speckit-version.ps1
.\studio\scripts\powershell\check-speckit-runtime.ps1
```

### 有 extension 變更時

```powershell
.\studio\scripts\powershell\validate-extension-registry.ps1
.\studio\scripts\powershell\export-extensions.ps1 -Force
.\studio\scripts\powershell\check-speckit-runtime.ps1
```

### 有 skill 需求時

```powershell
.\studio\scripts\powershell\install-agent-skills.ps1 -Target codex -Mode install -Refresh
```

### 有 shared-layer 升級需求時

```powershell
.\studio\scripts\powershell\upgrade-studio-runtime.ps1 -UpstreamSnapshotDir <snapshot-dir> -DryRun
.\studio\scripts\powershell\upgrade-studio-runtime.ps1 -UpstreamSnapshotDir <snapshot-dir> -Apply
```

---

## 最後總結

### 如果你只記三件事

1. **不要把 upstream repo-local 使用方式直接套到這個 workspace。**
2. **shared layer 是 authority，generated artifacts 只是鏡像。**
3. **extension / skills / sync 的正確順序永遠是：先治理，再匯出，再消費。**

### 這個 workspace 目前對 upstream 的正確理解

不是「變回 upstream 原樣」，而是：

**在不動既有專案的前提下，把 upstream 的 `version`、generic export、AI skills、extension lifecycle、tool check、agent matrix、shared-layer sync 能力，改造成適合 `studio-first` centralized runtime 的本地操作模型。**
