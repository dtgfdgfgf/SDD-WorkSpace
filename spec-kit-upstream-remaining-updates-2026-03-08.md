# Studio-First 專案相對最新 Spec Kit 的剩餘更新清單（2026-03-08）

## 目的

這份文件用來銜接下一個 session，作為「目前這個 studio-first 分叉，對最新 upstream `github/spec-kit` 還缺哪些更新」的基準清單。

這不是在要求把 upstream 整套重抄進來，而是要辨識：

1. 目前本地已經吸收了哪些新能力
2. 還有哪些 upstream 能力值得補
3. 哪些能力不應直接照搬

## 背景定位

目前這個工作區已不是單純的舊版 Spec Kit 專案，而是：

- 以舊版 Spec Kit 為起點
- 經過大量本地化修改
- 已經特化為 `studio-first` centralized runtime / governance 模型
- 已完成第一波內部收斂
- 已開始第二波 upstream selective alignment

因此，真正需要做的不是「回到 upstream 原樣」，而是：

**在不破壞 `studio-first` 架構、不動既有專案的前提下，選擇性引進 upstream 新功能。**

## 本次判斷依據

### 官方 upstream 來源

- [README](https://raw.githubusercontent.com/github/spec-kit/main/README.md)
- [CHANGELOG](https://raw.githubusercontent.com/github/spec-kit/main/CHANGELOG.md)
- [Upgrade Guide](https://raw.githubusercontent.com/github/spec-kit/main/docs/upgrade.md)

### 本地基線文件

- [spec-kit-upstream-alignment-matrix.md](C:/Users/user/Workspace/spec-kit-upstream-alignment-matrix.md)
- [spec-kit-upstream-wave2-transition-guide.md](C:/Users/user/Workspace/spec-kit-upstream-wave2-transition-guide.md)
- [learning-project-spec-kit-sdd.md](C:/Users/user/Workspace/learning-project-spec-kit-sdd.md)
- [get-speckit-version.ps1](C:/Users/user/Workspace/studio/scripts/powershell/get-speckit-version.ps1)

## 先講結論

以 **2026-03-08** 重新對照後，目前相對最新 upstream `spec-kit`，你這個專案**還缺的更新**主要集中在下面幾條能力線：

1. `AI skills` 的完整安裝層
2. extension system 的 runtime export / lifecycle
3. curated catalog / trust model
4. 更完整的最新 agent matrix 對齊
5. tool / agent availability check parity
6. workspace-level 的 shared-layer upstream sync 機制

反過來說，以下能力你已經不是「缺少」，而是**已部分或已大致吸收**：

- `/speckit.*` namespaced commands
- `clarify / analyze / checklist / taskstoissues`
- `speckit.version`
- generic/BYO agent pack export
- export-only `AI skills`
- extension registry foundation
- 多 agent 本地化支援

## 已吸收或已部分吸收的 upstream 能力

### 1. `specify version`

你目前已經有本地適配版本：

- [get-speckit-version.ps1](C:/Users/user/Workspace/studio/scripts/powershell/get-speckit-version.ps1)
- [speckit.version.agent.md](C:/Users/user/Workspace/.github/agents/speckit.version.agent.md)
- [speckit.version.prompt.md](C:/Users/user/Workspace/.github/prompts/speckit.version.prompt.md)

所以這一項不再是缺口。

### 2. `--ai generic --ai-commands-dir ...`

你目前已經有本地等價適配：

- [export-generic-agent-pack.ps1](C:/Users/user/Workspace/studio/scripts/powershell/export-generic-agent-pack.ps1)

它不是 upstream CLI 原樣，但能力上已經對齊到「把 shared runtime agents/prompts 匯出給 unsupported / BYO agent 環境」。

### 3. `--ai-skills`

你目前不是完全沒有，而是已做出 **export-only** 版本：

- [export-agent-skills.ps1](C:/Users/user/Workspace/studio/scripts/powershell/export-agent-skills.ps1)
- [resources/agent-skill-packs](C:/Users/user/Workspace/resources/agent-skill-packs)

這表示你已吸收「skills 作為可生成 artifact」這個模型，但還沒做到 upstream 那種完整 install 層。

### 4. extension system

你目前不是完全沒有，而是已經有 **registry foundation**：

- [studio/extensions](C:/Users/user/Workspace/studio/extensions)
- [manifest.schema.json](C:/Users/user/Workspace/studio/extensions/manifest.schema.json)
- [catalog.json](C:/Users/user/Workspace/studio/extensions/catalog.json)
- [state.json](C:/Users/user/Workspace/studio/extensions/state.json)
- [list-extensions.ps1](C:/Users/user/Workspace/studio/scripts/powershell/list-extensions.ps1)
- [set-extension-state.ps1](C:/Users/user/Workspace/studio/scripts/powershell/set-extension-state.ps1)

這表示你已吸收 extension 的 shared registry 基礎，但 هنوز沒有完整 lifecycle。

## 目前還缺少的 upstream 更新清單

下面這些才是「對最新 spec-kit 來說，現在仍值得補」的項目。

### 1. `AI skills` 的完整安裝層

**目前狀態：** 只做到 export-only。  
**缺少的部分：** 還沒有做 direct install / agent-home install。

官方 README 已把 `--ai-skills` 當成正式 init 能力。CHANGELOG 也顯示官方後續還修過不同 agent 的 skills install 路徑問題。

你現在的狀態是：

- 已能產生 skills
- 但還不能把它們安全、可控地安裝到 agent-specific skills location

**這是最明確的「只做了一半」的 upstream 功能。**

### 2. extension 的 runtime export / lifecycle

**目前狀態：** 已有 registry foundation。  
**缺少的部分：** 還沒有真正讓 extension 進入 runtime。

你現在有：

- manifest schema
- catalog
- state
- list/info
- enable/disable

但還沒有：

- runtime export
- runtime mirror
- add/remove lifecycle
- dev/prod style workflow

換句話說，你現在的 extension 還是「可登記、可管理狀態」，但還不是「可交付到 runtime source」。

### 3. curated catalog / trust model

**目前狀態：** `catalog.json` 只有骨架。  
**缺少的部分：** 還沒有真正的 catalog governance。

最新 upstream 已經不是只有「extension 檔案」而已，而是逐步形成 extension ecosystem。這代表你如果要真的吸收這條能力線，不能只停在 registry；還要補：

- curated catalog policy
- review / approval model
- trust boundary
- default-enabled 候選規則
- lifecycle 與 catalog 的關係

這一項非常重要，因為它決定你之後的 extension 會不會失控。

### 4. 最新 agent matrix 的完整對齊

**目前狀態：** 你本地已支援很多 agent。  
**缺少的部分：** 還沒有完全跟上最新 upstream agent matrix。

你目前 [update-agent-context.ps1](C:/Users/user/Workspace/studio/scripts/powershell/update-agent-context.ps1#L28) 支援：

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

但相對最新 upstream README，仍還沒完整補到像：

- `qodercli`
- `kiro-cli` / `kiro`
- `agy`
- `bob`
- `jules`

這表示你雖然已經是「廣泛支援」，但還不是 full parity。

### 5. tool / agent availability check parity

**目前狀態：** 你有很多 workflow scripts。  
**缺少的部分：** 還沒有 upstream 那種明確的 `specify check` 對等能力。

最新 upstream README 會把 agent/tool availability check 當正式命令與操作路徑。你目前仍偏向：

- workflow scripts
- init scripts
- export scripts

但還缺一層統一的 availability / compatibility check。這不是最急，但如果你要持續引進 upstream agent / extension / skills 能力，這層最後一定要補。

### 6. CLI 級參數驗證與相容性保護

**目前狀態：** 你有本地化 PowerShell 自動化。  
**缺少的部分：** 還沒有完整等價於 upstream CLI 的參數保護層。

CHANGELOG 顯示 upstream 後續修了很多像：

- `--ai`
- `--ai-commands-dir`
- `--ai-skills`

這些參數的驗證、錯誤提示、錯誤吃值問題。

你目前因為不是直接跑 upstream CLI，所以這類保護並沒有自然繼承。長期來看，如果本地 shared-layer 能力越多，這層就越值得補。

### 7. workspace-level 的 shared-layer upstream sync 能力

**目前狀態：** 你有自己的 shared-layer，但缺少一支專門的同步入口。  
**缺少的部分：** 還沒有一個「只更新 studio/shared layer、不碰既有 project」的同步機制。

這一項很關鍵，因為你現在的專案形態已經不是 upstream 預設 repo-local 模型，所以官方的：

- `specify init --here --force --ai ...`

不能直接照抄到你整個 workspace。

你真正需要的，是一個類似：

- `sync-upstream-shared-layer.ps1`
- 或 `upgrade-studio-runtime.ps1`

這種只處理：

- shared agents
- shared prompts
- shared scripts
- shared templates
- extension / skill shared capability

而**不去改任何既有專案**的本地升級入口。

這一項不是 upstream 直接給你的東西，但對你這種 studio-first 分叉來說，反而是最實際的長期能力缺口。

## 不建議直接跟 upstream 的部分

下面這些雖然 upstream 有，但不建議直接採用。

### 1. repo-local full `.specify` migration

這會直接破壞你現在的 studio-first centralized runtime model。

### 2. 對既有專案直接跑 `specify init --here --force`

官方 Upgrade Guide 已明確提到：

- `.specify/memory/constitution.md`
- `.specify/templates/`

在某些情況下會被覆蓋。

對你目前這種 heavily customized workspace，這風險太高。

### 3. 直接導入 community extension catalog

在 catalog trust / review policy 還沒定好之前，這會讓 shared-layer authority 失控。

## 建議優先順序

如果要把這份清單轉成下一個 session 的實作順序，我建議這樣排：

1. **先做 curated catalog / trust model**
2. **再做 extension runtime export / lifecycle**
3. **再做 `AI skills` install layer**
4. **再補最新 agent matrix 與 tool check parity**
5. **最後做 workspace-level upstream sync command**

## 一句話總結

**你現在真正缺的，不是重新變回 upstream spec-kit，而是把 upstream 新能力補進你這個已經成熟的 studio-first 分叉，尤其是 `AI skills` 完整安裝層、extension lifecycle、catalog trust model、以及 shared-layer 的長期升級入口。**

## 備註

這份文件對應的本地現況日期為 **2026-03-08**。

如果下一個 session 要直接進入實作，最建議從：

- `catalog / trust model`
- `extension runtime export / lifecycle`

這兩項開始。
