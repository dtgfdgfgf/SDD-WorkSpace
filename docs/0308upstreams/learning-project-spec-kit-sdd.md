> **Historical snapshot (2026-03-08).** This file preserves the former six-stage assessment and
> is not current execution guidance. Current project and consumer delivery uses the seven-stage
> sequence governed by `studio/constitution/constitution.md`. Do not use this snapshot to bypass
> Readiness, conditional ECI re-entry, Analyze or the mandatory Implement gate.

# 本工作區 Spec Kit / SDD 流程研究報告（2026-03-08 更新版）

## 範圍

- 研究對象：`C:\Users\user\Workspace`
- 納入：
  - `studio/`
  - root `.github/`
  - `.githooks/`
  - `WORKSPACE_STRUCTURE.md`
  - 代表性回歸樣本 `projects/japanese-learning/`
  - 既有專案結構盤點（僅作環境觀察，不作本階段改動目標）
- 排除：
  - 各商業或練習專案的功能程式碼深度審查
  - upstream `github/spec-kit` 原始碼本身的再次研究（另見 `https-github-com-github-spec-kit-repo-2025-10-01-2.md`）

## 一句話結論

這個工作區在第一波 studio-first 收斂後，核心 baseline 已經形成單一真相，並已開始落地第二波 upstream 對齊；重點不應再是大規模內部重整，而是 **在不破壞 studio-first 架構、不更動既有專案的前提下，選擇性吸收最新版 spec-kit 能力**。

## 1. 目前狀態總覽

### 1.1 已明確成為 studio-first 中央治理變體

- `studio/constitution/constitution.md` 已把六階段工作流、project constitution 定位、task canonical format、auxiliary commands 等核心規則正式寫死。
- root `.github/copilot-instructions.md` 已從泛用長篇說明書，收斂成 studio-first 的 runtime / governance 操作契約。
- `WORKSPACE_STRUCTURE.md` 已與實際 runtime source 對齊，明確定義 `.github/agents/`、`.github/prompts/`、`studio/templates/sdd-docs/`、`studio/templates/sdd-agents/` 的角色分工。

結論：這不是落後的舊版 Spec Kit，而是 **有意識地保留 upstream 核心 SDD 精神、但不採 repo-local full clone 的 studio-first 分叉**。

### 1.2 主流程已形成單一真相

目前主流程已明確固定為：

1. `/speckit.specify`
2. `/speckit.clarify`
3. `/speckit.plan`
4. `/speckit.tasks`
5. `/speckit.analyze`
6. `/speckit.implement`

補充命令也已明確降階：

- `/speckit.discover`：optional pre-spec aid
- `/speckit.checklist`
- `/speckit.constitution`
- `/speckit.taskstoissues`

這表示先前最嚴重的「主流程版本不一致」問題，目前已大致解掉。

### 1.3 專案初始化與 feature 流程已能穩定落地

目前的 PowerShell 腳本鏈已具備完整工作流能力：

- `init-practice.ps1` / `init-project.ps1`
  - 會建立 `.specify/memory/constitution.md`
  - 會建立 `.code-workspace`
  - 會建立 `.github/agents` junction
- `create-new-feature.ps1`
  - 已支援 nested non-git project 的 repo root fallback
- `setup-plan.ps1`
  - 能建立 `plan.md`
  - JSON 輸出已帶上 constitution paths
- `check-prerequisites.ps1`
  - 可同時支援 `-Json`、`-PathsOnly`、`-RequireTasks`、`-IncludeTasks`
- `update-agent-context.ps1`
  - 已改成把 Copilot context 寫到 `.github/copilot-instructions.md`

就「新建專案」與「新建 feature」來看，骨架已經是可運作狀態。

## 2. 已完成收斂的部分

這一節是相對上一版分析最重要的更新：先前列出的多數核心 drift，現在已不再是主問題。

### 2.1 Workflow 定義不一致：大致已解

上一版最大問題是 Constitution、Quickstart、Guide、Discover Agent 對 mandatory stages 的說法彼此不一致。

目前狀態：

- Constitution 已固定六階段為 mandatory
- root Copilot instructions 已固定相同順序
- `QUICKSTART.md` 已與相同定義對齊
- `speckit.discover.agent.md` 已不再主張自己是 `/speckit.specify` 的唯一合法輸入來源

判斷：**此項已從核心治理缺口，下降為已收斂狀態。**

### 2.2 Markdown / tree / arrow 規範自我違反：代表性樣本已修正

上一版指出：

- 治理文件禁止 tree / ASCII / arrow
- 但 guide、sample docs、generated artifacts 卻自己在用

目前狀態：

- `constitution.md` 和 root `copilot-instructions.md` 本身已自洽
- `projects/japanese-learning/specs/001-line-jp-learning/quickstart.md`
- `projects/japanese-learning/specs/001-line-jp-learning/data-model.md`
- `projects/japanese-learning/.github/copilot-instructions.md`
- `projects/japanese-learning/CLAUDE.md`

這些代表性樣本都已改成表格與純文字敘述，不再依賴樹狀圖或箭頭表示法。

判斷：**規範公信力已明顯提升。**

### 2.3 `tasks.md` canonical format 不一致：已解

上一版指出 template、guide、agent、hook 對 `tasks.md` 格式各說各話。

目前狀態：

- Constitution 已明文定義 canonical checklist line format
- `studio/templates/sdd-docs/tasks-template.md` 已改成 checklist-first
- `pre-commit` 仍以 checklist format 驗證
- `projects/japanese-learning/specs/001-line-jp-learning/tasks.md` 也符合相同格式

判斷：**agent、template、hook、sample 現在已站到同一邊。**

### 2.4 zh-TW 文件與 hook 驗證不對齊：已解

上一版指出 `pre-commit` 的 edge-case 判斷偏英文，會對中文 spec 造成 false negative。

目前狀態：

- `pre-commit` 已改成 section-aware edge case 計數
- 支援中文與英文 section naming
- 若 section 抽不到，fallback regex 也已包含中文詞彙

判斷：**中文 SDD 文件被誤擋的主要風險已被移除。**

### 2.5 `WORKSPACE_STRUCTURE.md` 與實際 runtime source 漂移：已解

上一版指出設計文件還在寫 `agents/[agent-name].md` 之類的舊概念。

目前狀態：

- `WORKSPACE_STRUCTURE.md` 已明確指向 `.github/agents/`
- 並把 `studio/templates/sdd-agents/` 定位為 mirrored templates，而非 runtime 真源

判斷：**高層結構文件已與真實 runtime source 對齊。**

### 2.6 `/contracts/` 的格式承諾與實際產物不一致：已解

上一版指出 plan agent 說 `contracts/` 要放 OpenAPI/GraphQL schema，但實際產物是 Markdown service contracts。

目前狀態：

- 規則已改成 `contracts/` 可容納 Markdown service contracts 或 machine-readable schema
- 只有對外 API 或需機械驗證時，才強制更嚴格 schema

判斷：**這個落差已從規範衝突，轉成刻意允許的多型輸出策略。**

## 3. 本階段應明確固定的邊界

這一節不是在列 bug，而是在固定下一階段的決策邊界，避免分析又回到「什麼都想修」的狀態。

### 3.1 `studio-first template precedence` 應明確視為既定架構決策

目前 `setup-plan.ps1`、`update-agent-context.ps1` 等關鍵腳本，都是：

1. 先找 `studio/templates/...`
2. 找不到才 fallback 到 `<project>/.specify/templates/...`

這與你目前的 studio-first 架構完全一致。

因此正確判讀應該是：

- 這不是待修問題
- 這不是需要重新評估的灰色區域
- 這是目前系統刻意維持的 precedence model

也就是說，**本階段應強調「確定維持 studio-first template precedence」**，而不是把它寫成要不要改的 open question。

### 3.2 既有專案的 heterogeneous 狀態只作環境觀察，不作本階段更動目標

目前 `projects/` 與 `learning/` 內的專案狀態並不一致，這是事實；但在你剛明確限制後，正確的分析方式應該改成：

- 這些專案是歷史快照與既有環境
- 這些差異不代表本階段必須啟動 migration
- 本階段不應對既有專案做批次回填或結構調整

所以這個現象應被記錄，但不應再列為下一步主動作。

### 3.3 `update-agent-context.ps1` 的已知結構問題暫不處理

目前 `update-agent-context.ps1` 仍把 `opencode`、`codex`、`amp`、`q` 對映到同一份 `AGENTS.md`。

這件事在結構上確實還不夠乾淨，但如果依你的決策：

- 暫時不需要重構 `update-agent-context.ps1`
- 也不把這件事列為近期主修項

那麼它現在在分析中的角色應該是：

- 已知限制
- 暫時接受
- 不納入本階段實作清單

### 3.4 對齊最新版 spec-kit 仍然是主目標，但必須是 selective alignment

你一開始的目標不是只做內部清理，而是：

- 參考最新版 spec-kit
- 對照自己的 studio-first 工作區
- 在保留本地架構選擇的前提下進行更新

因此第二階段最合理的主軸不是「再做一輪內部大掃除」，而是：

**建立一份 selective alignment matrix，判斷最新版 spec-kit 的能力中，哪些應吸收、哪些應延後、哪些應明確不採用。**

## 4. 相對最新版 spec-kit 的定位

對照 `https-github-com-github-spec-kit-repo-2025-10-01-2.md`，目前工作區的定位應更精確地描述為：

### 4.1 已經對齊或部分對齊的部分

- `/speckit.*` namespaced commands
- `clarify / analyze / checklist / taskstoissues` 進入本地工作流
- 多 agent support 的本地化實踐
- constitution preservation 的治理精神
- `contracts/` 接受 Markdown service contracts 的實務策略

### 4.2 已在本波吸收或已進入本地適配的部分

- `specify version` 已以本地適配方式吸收：
  - `studio/scripts/powershell/get-speckit-version.ps1`
  - `/speckit.version`
- `--ai generic --ai-commands-dir ...` 已以本地適配方式吸收：
  - `studio/scripts/powershell/export-generic-agent-pack.ps1`
- `--ai-skills` 已以 export-only 本地適配方式吸收：
  - `studio/scripts/powershell/export-agent-skills.ps1`
  - `resources/agent-skill-packs/<target>/`
- extension system 已以 registry foundation 形式吸收：
  - `studio/extensions/`
  - `manifest.schema.json` / `catalog.json` / `state.json`
  - `list-extensions.ps1` / `set-extension-state.ps1`
- 多 agent support 已持續沿用本地化實踐

### 4.3 尚未對齊，但應進入下一階段評估的部分

- catalog / extension lifecycle
- extension 對 Copilot / agent runtime 的整合模式
- community extension adoption
- skill install convenience layer（若未來真的需要）

### 4.4 明確不應直接照搬的部分

- upstream repo-local full `.specify` migration
- 任何會破壞 studio-first centralized runtime model 的做法
- 任何要求先批次重寫既有專案結構的做法

所以現在的判讀不應只是「我們故意不跟 upstream 一樣」，而應該更精確地寫成：

**我們的目標是對齊最新版 spec-kit 的可取能力，但採取 selective alignment，而不是 wholesale adoption。**

## 5. 既有專案環境觀察（非本階段改動目標）

下表只用來說明現況，不代表本階段需要立即回填：

| 專案 | Project Constitution | Copilot Context | Claude Context | `.github/agents` | `.code-workspace` | `retrospective.md` |
|------|----------------------|----------------|----------------|------------------|-------------------|--------------------|
| `projects/japanese-learning` | Yes | Yes | Yes | Yes | Yes | Yes |
| `projects/aierp` | No | No | No | Yes | Yes | Yes |
| `projects/KMS` | Yes | No | Yes | Yes | No | No |
| `projects/duotify-membership-v1` | Yes | No | No | Yes | No | No |
| `projects/invest` | No | No | No | No | No | No |
| `learning/codex-smoke-practice-20260307` | Yes | Yes | No | Yes | Yes | N/A |
| `projects/codex-smoke-internal-20260307` | Yes | No | No | Yes | Yes | Yes |

這張表的作用是說明：

- 目前工作區內仍存在不同歷史代際的專案結構
- 但這不代表現在就要對它們全部啟動 migration

## 6. 綜合評價

| 面向 | 目前評價 | 說明 |
|------|----------|------|
| 建立完整度 | 高 | 治理、模板、腳本、agent、hooks、樣本均已具備 |
| 可操作性 | 高 | 新專案初始化與 feature 建立鏈已可穩定運作 |
| 一致性 | 中高 | 核心 drift 已大幅收斂 |
| 架構清晰度 | 高 | studio-first precedence 與 runtime source 已明確 |
| 對 upstream 對齊潛力 | 高 | 已完成第一波收斂，適合進入 selective alignment |
| 對既有專案改動需求 | 低 | 目前不應主動展開 batch migration |

## 7. 下一步最值得做的三件事

1. **驗證本波已吸收的 upstream 功能**  
   驗證 `get-speckit-version.ps1 -Json`、`/speckit.version`、`export-generic-agent-pack.ps1 -OutputDir <workspace-local-path> -Json`、`export-agent-skills.ps1 -Target codex -OutputDir <workspace-local-path> -Json`、`list-extensions.ps1 -Json`。

2. **定義 catalog / extension lifecycle 的 studio-first 邊界**  
   既然 registry 已落地，下一步應先補 curated catalog、trust model、runtime export 與 lifecycle 的治理邊界。

3. **保留 skills install convenience 為後續選項**  
   先維持 export-only 模型，等 shared-layer 能力穩定後，再評估是否要補 install convenience。

## 8. 最終判斷

如果用一句話概括目前狀態：

**這個工作區已經完成第一波 studio-first 內部收斂，並落地了第二波的 `AI skills` 與 extension registry foundation；下一階段應聚焦於 catalog 與 lifecycle 的 shared-layer 治理，而不是回頭動既有專案。**



