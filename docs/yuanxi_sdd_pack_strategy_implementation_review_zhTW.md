---
title: "Yuanxi SDD Pack Strategy：實作問題與改善交接"
version: "0.1.0"
date: "2026-05-07"
language: "zh-TW"
owner: "元熙"
status: "handoff-draft"
parent_document: "docs/yuanxi_sdd_pack_strategy_zhTW.md"
purpose: "銜接 Yuanxi SDD Pack overlay 策略草案，整理實作前必須修正的問題、決策點與建議 v0.1 落地範圍，供下一個 agent 改善原文件或啟動正式 SDD 流程。"
source_basis:
  - "docs/yuanxi_sdd_pack_strategy_zhTW.md"
  - "studio/constitution/constitution.md v1.8.0"
  - "Official Spec Kit v0.8.6 release metadata, verified on 2026-05-07 Asia/Taipei"
  - "Official Spec Kit extension, preset, and workflow references, verified on 2026-05-07 Asia/Taipei"
---

# Yuanxi SDD Pack Strategy：實作問題與改善交接

## 1. 文件使用方式

本文件是 `docs/yuanxi_sdd_pack_strategy_zhTW.md` 的 companion handoff，不取代原策略文件。

建議下一個 agent 依序讀取：

1. `docs/yuanxi_sdd_pack_strategy_zhTW.md`
2. 本文件
3. Official Spec Kit extension / preset / workflow reference
4. `studio/constitution/constitution.md`

本文件的重點不是否定原策略，而是把「可以當方向」與「可以直接實作」之間的落差列清楚。若要真正開始實作，仍應先建立正式 feature artifacts，並依 Studio Constitution 執行 `specify`、`clarify`、`readiness`、`plan`、`tasks`、`analyze`、`implement` 的治理順序。

## 2. 總體判斷

原策略的核心方向成立：

- Official Spec Kit 應作為 base runtime。
- Yuanxi 的治理、readiness、ECI、templates、agent assets 應轉成 overlay pack。
- 第一版應降低 drift，不覆寫 official core commands。
- SDD-WorkSpace 應保留為 studio / build / release repo，而不是所有新專案的 runtime 母體。

但原文件目前仍是 strategy draft，不是 implementation-ready spec。若直接照文件開工，最容易卡在 command namespace、v0.1 scope、readiness gate 強制性、installer 安全性、既有資產抽取方式與 official Spec Kit 相容性。

## 3. P0 實作阻礙

| 編號 | 問題 | 影響 | 建議處理 |
|---|---|---|---|
| P0-1 | Extension command 命名不相容 | 原文件多處使用 `/speckit.readiness`、`/speckit.discover` 這種頂層命令；official extension command 需要符合 `speckit.<extension-id>.<command>` 格式 | v0.1 改用 `speckit.yuanxi.readiness`、`speckit.yuanxi.discover`、`speckit.yuanxi.eci`；若堅持頂層命令，需把它標成 installer-generated adapter，而非純 extension command |
| P0-2 | v0.1 scope 對 ECI 的說法矛盾 | 文件一邊把 ECI 放進流程，一邊又說 v0.1 暫緩 ECI；依 Studio Constitution，readiness 若 route 到 ECI，就必須有 ECI dossier 流程 | 二選一：v0.1 包含 minimal ECI，或 v0.1 明確禁用 `ROUTE_TO_ECI` 並把外部能力 blocker route 成 `NOT_READY` 或 decision packet |
| P0-3 | 不覆寫 core command 會弱化 readiness gate | 若保留 official `/speckit.plan`，使用者仍可跳過 readiness 直接 plan | v0.1 不要覆寫 `/speckit.plan`，但應提供 workflow 或 `before_plan` hook；文件要明確說明這是 guardrail，不是硬性 runtime lock |
| P0-4 | 尚未轉成正式 SDD feature spec | 原文件缺少 actors、FR、NFR、edge cases、success criteria、out of scope 等正式 spec 欄位 | 先建立 `specs/yuanxi-sdd-pack-v0.1/spec.md`，再走治理流程 |
| P0-5 | 版本基準需更新 | 原文件示例使用 `v0.8.5`；官方 latest release 已是 `v0.8.6` | `COMPATIBILITY.md` 應以 `v0.8.6` 為第一個 tested target，或明確設定 `>=0.8.5,<0.9.0` 並實測 |

## 4. P1 設計缺口

| 編號 | 缺口 | 風險 | 建議處理 |
|---|---|---|---|
| P1-1 | Artifact contract 太抽象 | readiness 若依賴固定 heading，official template drift 會破壞讀取 | 建立 machine-verifiable compatibility check，至少檢查 feature path、spec existence、required sections 與 readiness output path |
| P1-2 | Template override 邊界不明 | 如果 preset 直接覆寫 core templates，會吃到 upstream drift | v0.1 僅新增 supplemental templates，不覆寫 official `spec-template.md`、`plan-template.md`、`tasks-template.md` |
| P1-3 | Existing assets 不是 package 形態 | `.github/agents/*`、`.github/prompts/*`、`studio/scripts/*` 不能原封不動搬成 extension | 建立 extraction map，逐一轉成 `commands/*.md`、`templates/*`、`scripts/*`、docs |
| P1-4 | Installer 安全性不足 | `irm .../main/... | iex` 依賴 mutable main branch | v0.1 文件中允許 local dev install；remote install 必須使用 tag URL，並在後續加入 checksum 或 release asset |
| P1-5 | Multi-agent 支援範圍未定 | Copilot、Claude、Codex 的 command registration surface 不同 | v0.1 明確宣告 primary integration，例如 `copilot`；其他 integration 先列為 tested later |
| P1-6 | Smoke test 不夠可重跑 | 文件描述人工 toy project，但沒有固定 fixture 和 expected output | 新增 `tests/smoke-test.md` 與 `tests/smoke-test.ps1`，先驗證 install、list、command files、no core overwrite |

## 5. 建議的 v0.1 實作契約

v0.1 應以「可安裝、可看見、可 smoke test」為目標，不追求完整替代現有 workspace runtime。

| 類別 | v0.1 建議 |
|---|---|
| Package location | 先放在 `studio/packages/yuanxi-sdd-pack/`，待穩定後再拆 repo |
| Extension layout | 使用一個 extension：`extensions/yuanxi/extension.yml` |
| Extension id | `yuanxi` |
| Command names | `speckit.yuanxi.discover`、`speckit.yuanxi.readiness`、`speckit.yuanxi.eci` |
| Preset layout | `presets/yuanxi-governance-lite/preset.yml` |
| Template policy | 只新增 supplemental templates，不覆寫 official core templates |
| Installer | `installer/install.ps1` 與 `installer/install.sh` |
| Compatibility target | Official Spec Kit `v0.8.6` first |
| Primary integration | 建議先鎖定 Copilot 或 Claude 其中一個；不要同時承諾所有 agent |
| ECI policy | 若 readiness 保留 `ROUTE_TO_ECI`，v0.1 必須包含 minimal ECI command 與 dossier templates |

## 6. Command Surface 修正建議

| 原策略中的 command | Official extension-compatible command | v0.1 建議狀態 |
|---|---|---|
| `/speckit.discover` | `/speckit.yuanxi.discover` | Include |
| `/speckit.readiness` | `/speckit.yuanxi.readiness` | Include |
| `/speckit.eci` | `/speckit.yuanxi.eci` | Include only if readiness can route to ECI |
| `/speckit.verify` | `/speckit.yuanxi.verify` | Defer |
| `/speckit.drift` | `/speckit.yuanxi.drift` | Defer |

若下一個 agent 想保留 `/speckit.readiness` 這種短命令，必須在文件中明確區分：

- `extension command`：official-compatible，使用 namespaced command。
- `generated adapter alias`：由 installer 寫入特定 agent 的本地 command 檔，可能不屬於 official extension manifest。

建議 v0.1 不做 alias，以降低 drift 與 debugging 成本。

## 7. 現有資產抽取對照

| 現有來源 | 建議目的地 | 注意事項 |
|---|---|---|
| `.github/agents/speckit.discover.agent.md` | `extensions/yuanxi/commands/discover.md` | 移除 workspace-only 語句；改用 extension command name |
| `.github/agents/speckit.readiness.agent.md` | `extensions/yuanxi/commands/readiness.md` | 保留 classification 與 output contract；調整 command references |
| `.github/agents/speckit.eci.agent.md` | `extensions/yuanxi/commands/eci.md` | 若 v0.1 包含 ECI，必須一起轉入 |
| `.github/prompts/speckit.*.prompt.md` | 視需要合併進 command body | 不要把 prompt stub 當獨立 source of truth |
| `studio/templates/sdd-docs/readiness-assessment-template.md` | `extensions/yuanxi/templates/readiness-assessment-template.md` | 路徑與 output contract 需與 command 內容一致 |
| `studio/templates/sdd-docs/intent-ledger-template.md` | `extensions/yuanxi/templates/intent-ledger-template.md` | 只在 represented、deferred、dropped scope compression 時要求 |
| `studio/templates/sdd-docs/eci-*.md` | `extensions/yuanxi/templates/eci-*.md` | 只有 ECI included 時放入 v0.1 |
| `studio/scripts/powershell/setup-readiness.ps1` | `extensions/yuanxi/scripts/powershell/setup-readiness.ps1` | 需要驗證 extension script path rewriting |
| `studio/runtime/shared-runtime-contract.json` | 測試參考，不安裝到專案 | 不應成為 pack runtime source of truth |

## 8. Installer 設計提醒

v0.1 installer 應先服務 local dev install，不要一開始承諾公開遠端安裝。

建議行為：

1. 檢查目前目錄是否已由 `specify init` 初始化。
2. 檢查 `specify version` 是否落在支援範圍。
3. 執行 `specify extension add --dev <pack>/extensions/yuanxi`。
4. 執行 `specify preset add --dev <pack>/presets/yuanxi-governance-lite --priority 5`。
5. 顯示 `specify extension list` 與 `specify preset list` 的下一步驗證指令。
6. 不修改 official core commands。
7. 不自動覆寫 project-local agent adapters，除非使用者明確傳入 opt-in flag。

遠端 installer 若要加入，應使用 release tag URL，不使用 mutable `main` URL。

## 9. 最小 Smoke Test

v0.1 宣稱完成前，至少驗證以下事項。

| 檢查 | 預期 |
|---|---|
| `specify init smoke-test --integration copilot` | 能建立官方 spec-kit project |
| `installer/install.ps1` | 能在 project root 執行 |
| `specify extension list` | 看得到 Yuanxi extension |
| `specify preset list` | 看得到 Yuanxi governance-lite preset |
| Generated command files | 看得到 namespaced Yuanxi command |
| Core command files | official core command 未被覆寫 |
| Readiness command | 能產出或指示 `specs/<feature>/readiness/readiness-assessment.md` |
| ECI route | 若 readiness 可產生 `ROUTE_TO_ECI`，ECI command 與 templates 必須可用 |
| Uninstall path | `specify extension remove yuanxi` 後不殘留破壞性 state |

## 10. 建議回寫到原文件的修改

下一個 agent 改善 `docs/yuanxi_sdd_pack_strategy_zhTW.md` 時，建議直接修正下列內容：

| 原文件區段 | 建議修改 |
|---|---|
| Section 3 | 把多 extension 初版改為單一 `yuanxi` extension，或明確說明為何要拆多個 extension |
| Section 5 | 將 `/speckit.readiness` 等頂層新增命令改成 namespaced command，並補 alias policy |
| Section 7 | 把 remote `irm ... main ... | iex` 標成 experimental，正式文件改用 tagged release |
| Section 9 | 在 artifact contract drift 補上 machine-verifiable check 的最小欄位 |
| Section 10 | 將 compatibility matrix 更新到 `v0.8.6` |
| Section 12 | 把 ECI 從 P2 移到 v0.1 required，或明確說 v0.1 readiness 不輸出 `ROUTE_TO_ECI` |
| Section 13 | 把 v0.1 success criteria 改成可執行 acceptance checks |
| Website Content Agent Spec | 改名為 `Agent Handoff Spec` 或移出網站語境，避免下一個 agent 誤判這是網站需求 |

## 11. 下一步建議

建議下一個 agent 不要直接建立 package scaffold，而是先產生正式 feature：

| Artifact | 建議路徑 | 目的 |
|---|---|---|
| Spec | `specs/yuanxi-sdd-pack-v0.1/spec.md` | 把本策略轉成可治理需求 |
| Clarification notes | `specs/yuanxi-sdd-pack-v0.1/clarifications.md` 或 spec 內 clarification section | 解決 command namespace、ECI scope、primary integration |
| Readiness | `specs/yuanxi-sdd-pack-v0.1/readiness/readiness-assessment.md` | 判定是否可進入 planning |
| Plan | `specs/yuanxi-sdd-pack-v0.1/plan.md` | 定義 package architecture |
| Tasks | `specs/yuanxi-sdd-pack-v0.1/tasks.md` | 切成可執行 task |

若使用者只想先做 spike，可以建立 `studio/packages/yuanxi-sdd-pack-spike/`，但必須在文件中標示 exploratory，不要把 spike 當成正式 pack source of truth。

## 12. 參考來源

| 來源 | URL | 用途 |
|---|---|---|
| Official Spec Kit release v0.8.6 | https://github.com/github/spec-kit/releases/tag/v0.8.6 | 確認目前建議 compatibility baseline |
| Extension Development Guide | https://raw.githubusercontent.com/github/spec-kit/main/extensions/EXTENSION-DEVELOPMENT-GUIDE.md | 確認 extension manifest、command naming、hooks、script rewriting |
| Presets Reference | https://raw.githubusercontent.com/github/spec-kit/main/docs/reference/presets.md | 確認 preset 安裝與 catalog model |
| Workflows Reference | https://raw.githubusercontent.com/github/spec-kit/main/docs/reference/workflows.md | 評估是否用 workflow 補 readiness gate |
| Studio Constitution | `studio/constitution/constitution.md` | 確認 governed SDD sequence 與 readiness / ECI 規則 |
