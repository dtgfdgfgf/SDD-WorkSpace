# github/spec-kit 變更研究（2025-10-01 至 2026-03-06）

## Executive Summary

在這段期間，[github/spec-kit](https://github.com/github/spec-kit) 從「以 `specify init` + 少量固定 slash commands 為核心的 bootstrap toolkit」演進成「帶有更多 agent、`version` 命令、AI skills、generic/BYO agent 支援，以及完整 extension 系統」的平台型工具。[^range][^1][^2][^3][^4][^5]

如果你是 2025 年 10 月的既有使用者，**最先感受到的變化**會是 slash commands 命名全面切到 `/speckit.*`，而不是舊的 `/constitution`、`/plan`、`/tasks`。[^1][^4][^5]

如果你是從產品能力角度看，**最大的新增功能**則是 2026-02-10 之後出現的 extension system：現在可以 `search / info / add / remove / enable / disable / update` extensions，還能用 `SPECKIT_CATALOG_URL` 切換組織 catalog。[^8][^9][^10]

## 研究方法與判準

我把 2025-10-01 到 2026-03-06 之間的主幹 commit 歷史、區間起點前後的 README 與 CLI 程式碼、目前的 extension 文件、以及關鍵功能 commit 交叉比對；下面只聚焦「使用者可感知」的變更，像是純 CI、lint、內部重構，只有在會影響安裝、命令、或輸出時才納入。[^range][^8][^12]

## 1. 使用方法有何區別

### 1.1 高層結論

最大差別不是「SDD 流程被推翻」，而是 **同一條流程被做成更完整、更 namespaced、也更可擴充**：核心流程還是 constitution/specify/plan/tasks/implement，但入口命名、CLI 參數、支援 agent、以及後續擴充方式都明顯升級了。[^1][^2][^4][^5]

### 1.2 舊版與新版的使用差異表

| 面向 | 2025-10-01 左右 | 2026-03-06 左右 | 對使用者的實際影響 |
| --- | --- | --- | --- |
| Slash commands | README 與 quickstart 使用 `/constitution`、`/specify`、`/plan`、`/tasks`、`/implement`。[^1][^2] | README 與 CLI 說明改成 `/speckit.constitution`、`/speckit.specify`、`/speckit.plan`、`/speckit.tasks`、`/speckit.implement`，並把 `/speckit.clarify`、`/speckit.analyze`、`/speckit.checklist` 列成 optional commands。[^4][^5] | 舊教學、舊 muscle memory、舊 prompt 範例都要跟著改；這是回鍋使用者最容易直接撞到的變化。[^1][^4] |
| `specify init` 的 agent 參數 | `--ai` 選項仍是較小的固定清單，README 寫的是 `cursor` 而不是 `cursor-agent`，也沒有 `--ai-commands-dir` 或 `--ai-skills`。[^2][^3] | `--ai` 清單擴大，並明確使用 `cursor-agent`、`qodercli`、`kiro-cli`（含 `kiro` alias）、`amp`、`shai`、`bob`、`agy`、`generic`；同時新增 `--ai-commands-dir` 與 `--ai-skills`。[^4][^5][^6][^7][^14] | 老腳本若還用 `--ai cursor` 會落後於現況；新版本則更適合多 agent 團隊與尚未被官方 first-class 支援的 agent。[^2][^4][^6] |
| CLI 命令面 | 起點時 CLI 實際上只有 `init` 與 `check` 兩個主命令。[^2][^3] | 現在除了 `init`/`check`，還有 `version`，以及整個 `specify extension ...` 子命令群。[^4][^5][^8] | spec-kit 不再只是「初始化模板」；它開始承擔版本查詢、擴充套件安裝與管理。[^5][^8][^12] |
| 擴充方式 | 核心 repo 沒有 extension lifecycle；使用者只能吃內建流程。[^3] | 現在有 extension catalog、extension manifest、install from catalog / URL / local dev、enable/disable、config layering、catalog override。[^8][^9][^10] | 產品從固定工具包變成平台；能力邊界不再只看 core repo 內建了什麼。[^8][^9] |
| 重新初始化（re-init）安全性 | 早期沒有「保留既有 constitution」這個明確保護層。[^3] | 2026-02 起改為從 `constitution-template` 初始化，且若 `.specify/memory/constitution.md` 已存在就保留。[^5][^11] | 對長期專案很重要：你可以為新 agent 重新 init，而不必那麼擔心自訂 constitution 被蓋掉。[^11] |
| 文件導引 | 舊版 README 主要是單一路徑說明。[^1][^2] | 新版 README 補了升級指引、更多 agent、community walkthroughs，以及更完整的 optional commands 說明。[^4][^17] | 上手體驗更像成熟 OSS 專案，而不是只有最小可行指南。[^4][^17] |

### 1.3 具體到命令層的差異

- **Slash 命令命名空間化**：起點 README 還是用裸命令 `/constitution`、`/specify`、`/plan`、`/tasks`、`/implement`；目前 README 與 CLI step summary 都已全面改為 `/speckit.*`。[^1][^4][^5]
- **`cursor` 變成 `cursor-agent`**：這是實際會影響 `specify init --ai ...` 的參數差異；舊 README 用 `cursor`，新 README 與目前 `AGENT_CONFIG` 用 `cursor-agent`。[^2][^4][^5]
- **`specify version` 是新命令**：它會顯示 CLI 版本、template 版本、release 日期與本機環境資訊；這在起點時不存在。[^5][^12]
- **`--ai-skills` 是新的安裝模式**：現在可以把 Prompt.MD 模板安裝成 agent skills，而且設計成 additive / idempotent，不會在重跑時把既有 skill 覆蓋掉。[^5][^7]
- **`--ai generic --ai-commands-dir <path>` 是新能力**：對沒有 first-class 支援的 agent，現在可以走 BYO-agent 路線；舊版沒有這條路。[^5][^6]

### 1.4 一個容易忽略、但很重要的差異

新版雖然有 `specify extension search`，但它**預設查的是組織自己的 `catalog.json`**，而不是自動把所有 community extensions 都攤給你看；若要切自訂 catalog，要用 `SPECKIT_CATALOG_URL`，而且自訂 URL 必須是 HTTPS（localhost 測試例外）。[^9][^10]

這代表新版的「擴充能力」同時也引入了新的治理模型：spec-kit 鼓勵組織先 curate catalog，再讓團隊安裝 extension，而不是把 community catalog 當作預設 app store。[^8][^9][^10]

## 2. 是否有新增功能

## 2.1 結論：有，而且是多條產品線一起長出來

從使用者角度，這段期間新增的不是零星小功能，而是幾條明確的新能力線：**更多 agent 支援、`version` 命令、AI skills、generic/BYO agent、constitution preservation、以及 extension platform**。[^5][^6][^7][^8][^11][^12][^14]

### 2.2 新增功能清單（按重要性排序）

| 新功能 | 何時出現 | 我對它的判讀 |
| --- | --- | --- |
| **Modular extension system** | 2026-02-10 | 這是最大的新功能。commit 直接引入 extension manager、catalog、manifest、hooks、template、開發/發布/使用者文件，且 CLI 現在真的有 `list/add/remove/search/info/update/enable/disable`。[^8][^5][^9][^10] |
| **AI skills 安裝** | 2026-02-19 | `--ai-skills` 讓 spec-kit command templates 可以同步安裝成 agent skills；這不只是文檔描述，程式碼還實作了 agent-specific skills 目錄解析、frontmatter 轉換、以及不覆蓋既有 skills 的保護。[^7][^5] |
| **Generic/BYO agent support** | 2026-02-20 | 這讓 spec-kit 不再被官方 agent matrix 綁死；只要指定 commands 目錄，就能讓 unsupported agent 也吃到 spec-kit workflow。[^6][^5] |
| **`specify version`** | 2025-10-21 | 這是比較早期、但明確的新 CLI 能力，讓使用者可以看到 CLI 版本、template 版本與 release 日期。[^12][^5] |
| **Constitution preservation on re-init** | 2026-02-09 | 這不是 flashy feature，但對實務使用很重要；它把 re-init 從「可能蓋掉專案治理檔」改成更安全的行為。[^11][^5] |
| **更廣的 agent 支援** | 2025-10 到 2026-03 持續增加 | Qoder CLI、IBM Bob、SHAI、Antigravity、Kiro CLI 等都是區間內加入；同時 Codex 從「有 named-args 限制」走到「fully supported」。[^13][^14] |
| **Community extension catalog 成長** | 2026-02 到 2026-03 | V-Model、Cleanup、Retrospective、Sync、Verify、Azure DevOps、Jira 等 extension 在這段期間陸續被加進 catalog，代表 extension system 很快從 framework 變成有內容的 ecosystem。[^16] |
| **Community walkthroughs** | 2026-03-05 | 這不是 runtime feature，但對使用者 onboarding 很有感，因為 README 開始直接給 greenfield / brownfield 真實 demo。[^17] |

### 2.3 有些新功能「已存在」，但成熟度不完全一樣

例如 `specify extension update` 現在已經是 CLI 介面的一部分，文件也把它寫成標準操作；但實作上它目前仍會提示你用 `remove --keep-config` 加 `add` 手動完成更新，而不是 fully automatic update。這代表 extension platform 已經形成，但某些管理能力仍在過渡期。[^5][^9]

另一個例子是 Copilot extension registration：extension system 雖然在 2026-02-10 就進 core，但對 GitHub Copilot 使用者來說，直到 2026-03-03 修正 `.agent.md` / `.prompt.md` 配對之後，extension command 在 Copilot 內的體驗才算真正穩定可用。[^8][^15]

## 3. 對使用者來說最明顯改變

### 3.1 如果你是回鍋使用者

**最明顯的單一變化是：slash commands 全部進入 `/speckit.*` 命名空間。** 你以前看到的 `/constitution`、`/plan`、`/implement`，現在 README、CLI step summary、extension command naming 都以 `speckit` 命名空間為中心。這是最容易讓舊筆記、舊 prompt、舊 demo 失效的地方。[^1][^4][^5][^10]

### 3.2 如果你是新使用者或評估者

**最明顯的產品層級改變是：spec-kit 已經從固定流程工具，變成可擴充的平台。** 你現在不只是在跑 core SDD commands，而是可以搜尋 catalog、安裝 extensions、掛 hooks、維護組織 catalog、替不同 agent 安裝 skills，甚至讓 unsupported agent 也接進來。[^6][^7][^8][^9][^10]

### 3.3 我會怎麼排序「使用者體感」

1. **第一名：`/speckit.*` 命名空間化** — 最直接、最容易讓舊習慣出錯。[^1][^4]
2. **第二名：extension system** — 這讓 spec-kit 的邊界從 core repo 一路擴到 catalog 與社群 ecosystem。[^8][^9][^10][^16]
3. **第三名：agent matrix 大幅擴充** — 尤其是 `cursor-agent` 命名、`generic`、`kiro-cli`、`qodercli`、`bob`、`shai` 等，代表它越來越像「agent-agnostic SDD shell」。[^4][^5][^6][^14]
4. **第四名：AI skills / safer re-init / version command** — 這些不是最炫，但會大幅改善日常使用的可維護性。[^5][^7][^11][^12]

## 如果你上次是在 2025 年 10 月使用，現在回來應該先重學什麼

1. **把裸 slash commands 全部換成 `/speckit.*`。**[^1][^4]
2. **檢查你的 `--ai` 名稱是不是還停留在舊版**，尤其 `cursor` 與新版 `cursor-agent` 的差異。[^2][^4][^5]
3. **學會三個新入口：`specify version`、`--ai-skills`、`specify extension ...`。**[^5][^7][^9][^12]
4. **如果你要接 unsupported agent，不要再等官方支援，直接用 `--ai generic --ai-commands-dir ...`。**[^6]
5. **如果你會 re-init 專案，知道 constitution 現在會被保留**，這比舊版安全很多。[^11]

## Confidence Assessment

### 我有高信心的部分

- 2025-10-01 起點附近與 2026-03-06 終點附近的**實際使用方法差異**，因為這些可以直接從 README 與 `src/specify_cli/__init__.py` 逐行比對。[^1][^2][^3][^4][^5]
- **extension system、AI skills、generic agent、version command、constitution preservation** 這幾個結論的「是否新增」與「何時出現」，因為都有對應 commit 與現行程式碼。[^6][^7][^8][^11][^12]
- **agent 支援擴張** 與 **community catalog 成長**，因為都有具體 commit 與目前 README / code 支撐。[^4][^5][^14][^16]

### 我刻意保留為判讀的部分

- 「**對使用者來說最明顯改變**」本質上是 judgment call；我把它拆成「回鍋使用者最明顯」與「產品能力最明顯」兩種角度，避免把主觀感受說成唯一客觀答案。[^1][^4][^8][^9]
- 我沒有逐一列出 309 個 commit 的每個小修小補，而是把它們壓成使用者可感知的 change buckets；這比較符合你的三個問題，也比較接近實際採用判斷。[^range]

## Footnotes

[^range]: GitHub REST API commit history for [github/spec-kit](https://github.com/github/spec-kit) with `since=2025-10-01T00:00:00Z` and `until=2026-03-06T23:59:59Z`, pages 1 to 4, inspected on 2026-03-06.
[^1]: [github/spec-kit](https://github.com/github/spec-kit) `README.md:74-114` at [`cc75a22`](https://github.com/github/spec-kit/commit/cc75a22e455ab5da9c95b97e62fe866cb85010f1).
[^2]: [github/spec-kit](https://github.com/github/spec-kit) `README.md:122-163` and `README.md:205-223` at [`cc75a22`](https://github.com/github/spec-kit/commit/cc75a22e455ab5da9c95b97e62fe866cb85010f1).
[^3]: [github/spec-kit](https://github.com/github/spec-kit) `src/specify_cli/__init__.py:68-80`, `src/specify_cli/__init__.py:750-792`, and `src/specify_cli/__init__.py:1102-1142` at [`cc75a22`](https://github.com/github/spec-kit/commit/cc75a22e455ab5da9c95b97e62fe866cb85010f1).
[^4]: [github/spec-kit](https://github.com/github/spec-kit) `README.md:45-76`, `README.md:93-133`, `README.md:143-176`, `README.md:189-205`, and `README.md:274-304` at [`71e6b4d`](https://github.com/github/spec-kit/commit/71e6b4da4a59073c04750f4ea86decaaa3b663c0).
[^5]: [github/spec-kit](https://github.com/github/spec-kit) `src/specify_cli/__init__.py:127-289`, `src/specify_cli/__init__.py:1014-1047`, `src/specify_cli/__init__.py:1055-1244`, `src/specify_cli/__init__.py:1247-1410`, `src/specify_cli/__init__.py:1606-1747`, and `src/specify_cli/__init__.py:1753-2350` at [`71e6b4d`](https://github.com/github/spec-kit/commit/71e6b4da4a59073c04750f4ea86decaaa3b663c0).
[^6]: [github/spec-kit](https://github.com/github/spec-kit) commit [`6150f1e`](https://github.com/github/spec-kit/commit/6150f1e31747a387119bf1456128b90a05fed15e) (“Add generic agent support with customizable command directories (#1639)”).
[^7]: [github/spec-kit](https://github.com/github/spec-kit) commit [`9402ebd`](https://github.com/github/spec-kit/commit/9402ebd00ae6470bf8cb862868a5b3cec1163398) (“Feat/ai skills (#1632)”).
[^8]: [github/spec-kit](https://github.com/github/spec-kit) commit [`f14a47e`](https://github.com/github/spec-kit/commit/f14a47ea7d163fc5923fbcddb0ee8d1a9ceb1206) (“Add modular extension system (#1551)”).
[^9]: [github/spec-kit](https://github.com/github/spec-kit) `extensions/EXTENSION-USER-GUIDE.md:39-188`, `extensions/EXTENSION-USER-GUIDE.md:250-320`, and `extensions/EXTENSION-USER-GUIDE.md:399-529` at [`71e6b4d`](https://github.com/github/spec-kit/commit/71e6b4da4a59073c04750f4ea86decaaa3b663c0).
[^10]: [github/spec-kit](https://github.com/github/spec-kit) `src/specify_cli/extensions.py:100-121`, `src/specify_cli/extensions.py:400-470`, `src/specify_cli/extensions.py:585-913`, `src/specify_cli/extensions.py:969-1035`, and `src/specify_cli/extensions.py:1192-1208` at [`71e6b4d`](https://github.com/github/spec-kit/commit/71e6b4da4a59073c04750f4ea86decaaa3b663c0).
[^11]: [github/spec-kit](https://github.com/github/spec-kit) commit [`4afbd87`](https://github.com/github/spec-kit/commit/4afbd87abb45744966bbeaaa71d20742cf778c48) (“fix: preserve constitution.md during reinitialization (#1541) (#1553)”).
[^12]: [github/spec-kit](https://github.com/github/spec-kit) commit [`e77d99a`](https://github.com/github/spec-kit/commit/e77d99abd2d4204b1df713e3b8693af788397119) (“Support for version command”).
[^13]: [github/spec-kit](https://github.com/github/spec-kit) commit [`b06f2b9`](https://github.com/github/spec-kit/commit/b06f2b9f8937537932a259e09af0fdd980ccfaf6) (“Codex CLI is now fully supported”); [github/spec-kit](https://github.com/github/spec-kit) `README.md:136-136` at [`cc75a22`](https://github.com/github/spec-kit/commit/cc75a22e455ab5da9c95b97e62fe866cb85010f1); [github/spec-kit](https://github.com/github/spec-kit) `README.md:153-176` at [`71e6b4d`](https://github.com/github/spec-kit/commit/71e6b4da4a59073c04750f4ea86decaaa3b663c0).
[^14]: [github/spec-kit](https://github.com/github/spec-kit) commits [`3110452`](https://github.com/github/spec-kit/commit/3110452c3f79c3cfe97dbae27a36fc170fe2e267) (“feat:support Qoder CLI”), [`f438a10`](https://github.com/github/spec-kit/commit/f438a10c7c74aeaffb6e9329c8cf439823eecc20) (“feat: add support for IBM Bob IDE”), [`e976080`](https://github.com/github/spec-kit/commit/e976080cbfc4d0c007663bd79af5a4e7cde675e6) (“feat: Add OVHcloud SHAI AI Agent”), [`76cca34`](https://github.com/github/spec-kit/commit/76cca342932d07a59abf1b766732f8097def55e8) (“Feat: add a new agent: Google Anti Gravity (#1220)”), and [`32c6e7f`](https://github.com/github/spec-kit/commit/32c6e7f40cc3b4fb7a5b24b27b663b3c87390b0d) (“feat: add kiro-cli and AGENT_CONFIG consistency coverage (#1690)”).
[^15]: [github/spec-kit](https://github.com/github/spec-kit) commit [`f6264d4`](https://github.com/github/spec-kit/commit/f6264d4ef44ebedb48f5178835e4cf9390c006d8) (“fix: correct Copilot extension command registration (#1724)”); [github/spec-kit](https://github.com/github/spec-kit) `src/specify_cli/extensions.py:445-462` and `src/specify_cli/extensions.py:589-607,880-912` at [`71e6b4d`](https://github.com/github/spec-kit/commit/71e6b4da4a59073c04750f4ea86decaaa3b663c0).
[^16]: [github/spec-kit](https://github.com/github/spec-kit) commits [`aeed11f`](https://github.com/github/spec-kit/commit/aeed11f735faf04bbd4548c95799081aa5615fe6) (“Add V-Model Extension Pack to catalog (#1640)”), [`f444ccb`](https://github.com/github/spec-kit/commit/f444ccba3a48dd1976fd5af1972f044712ac4749) (“Add Cleanup Extension to catalog (#1617)”), [`c7ecdfb`](https://github.com/github/spec-kit/commit/c7ecdfb998f2146eb9d62f2d67601512dd1b244c) (“Add retrospective extension to community catalog. (#1681)”), [`bf8fb12`](https://github.com/github/spec-kit/commit/bf8fb125ad7dd9a86bb0ac6d4dd98d93bd712949) (“Add sync extension to community catalog (#1728)”), [`9cf33e8`](https://github.com/github/spec-kit/commit/9cf33e81cc89509fa136a46549f7cc2323326eae) (“feat: add verify extension to community catalog (#1726)”), [`8c3982d`](https://github.com/github/spec-kit/commit/8c3982d65bce1ef576bf51dbaba3ffa38b8ea540) (“Add Azure DevOps Integration extension to community catalog (#1734)”), and [`ad74334`](https://github.com/github/spec-kit/commit/ad74334a85720d0735253bb0a5a34c8f36c4aced) (“feat(extensions): add Jira Integration to community catalog (#1764)”).
[^17]: [github/spec-kit](https://github.com/github/spec-kit) `README.md:143-151` at [`71e6b4d`](https://github.com/github/spec-kit/commit/71e6b4da4a59073c04750f4ea86decaaa3b663c0).
