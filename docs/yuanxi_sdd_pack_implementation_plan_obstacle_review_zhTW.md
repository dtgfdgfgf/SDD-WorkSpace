---
title: "Yuanxi SDD Pack Implementation Plan：實作障礙檢查"
version: "0.1.0"
date: "2026-05-08"
language: "zh-TW"
owner: "元熙"
status: "superseded"
historical_status: "handoff-draft"
superseded_on: "2026-07-22"
revalidation_status: "required-before-reuse"
parent_document: "docs/yuanxi_sdd_pack_implementation_plan_zhTW.md"
purpose: "記錄針對 Yuanxi SDD Pack meta plan 的實作前障礙檢查結果，供下一個 agent 修正 plan 或啟動 Phase 0 前使用。"
source_basis:
  - "docs/yuanxi_sdd_pack_implementation_plan_zhTW.md"
  - "studio/constitution/constitution.md v1.8.0"
  - "Local specify CLI output on 2026-05-08 Asia/Taipei"
  - "Official Spec Kit v0.8.7 release metadata verified on 2026-05-08 Asia/Taipei"
---

> **Historical snapshot; superseded for current execution (2026-07-22).** This document preserves
> the 2026-05-08 local observation and must not be used to select a current Spec Kit CLI flag,
> capability or version. In particular, B-001 and B-003 require current upstream revalidation.
> See `docs/sdd-workspace-deep-review-2026-07-08_zhTW.md` Section 5.5 and the bounded
> `docs/yuanxi_sdd_pack_implementation_plan_obstacle_review_2026-07-22_zhTW.md` revalidation.
> The implementation plan itself remains stale under R-G02 and is not authorized for execution.

# Yuanxi SDD Pack Implementation Plan：實作障礙檢查

## 1. 文件使用方式

本文件是 `docs/yuanxi_sdd_pack_implementation_plan_zhTW.md` 的 companion review，不取代原 plan。

建議下一個 agent 依序讀取：

1. `docs/yuanxi_sdd_pack_strategy_zhTW.md`
2. `docs/yuanxi_sdd_pack_strategy_implementation_review_zhTW.md`
3. `docs/yuanxi_sdd_pack_implementation_plan_zhTW.md`
4. 本文件

本文件只記錄「若現在依照 plan 實作會遇到什麼障礙」。正式修改仍應回到原 plan 的 Decisions Log / Open Questions 機制，或先啟動 Phase 0 SDD artifacts。

## 2. 總體判斷

原 plan 已經收斂很多前一輪 strategy draft 的問題，例如：

- 已採用 namespaced command surface：`speckit.yuanxi.discover`、`speckit.yuanxi.readiness`、`speckit.yuanxi.eci`
- 已決定 v0.1 納入 ECI，避免 readiness route 缺 dossier 流程
- 已明確 v0.1 不覆寫 official core commands 與 core templates
- 已把 Phase 0 正式 SDD bootstrap 放在實作前

但若今天直接實作，仍會先卡在 official Spec Kit CLI 能力、版本基準、Claude command registration、preset 實際生效方式，以及既有 script 抽取難度。

## 3. P0 Blockers

| ID | 障礙 | 觀察 | 影響 | 建議處理 |
|---|---|---|---|---|
| B-001 | 本機 `specify` CLI 沒有 `extension` / `preset` / `workflow` subcommands | `specify --help` 只列出 `init`、`check`、`version`；`specify extension add --help` 與 `specify preset add --help` 皆回報 no such command | T1.2、T1.3、T3.2、AC-2、AC-3、AC-4 無法照 plan 執行 | 新增 Q-017：先確認是否有不同安裝方式可取得 extension/preset CLI；若沒有，v0.1 需改成 installer 直接複製 Claude assets |
| B-002 | 版本基準已落後 | 官方 latest release 已是 `v0.8.7`；本機 `specify version` 顯示 Template Version `0.8.7`，Released `2026-05-07` | plan 仍以 `v0.8.6` 作為 governance basis 與 tested target，T3.2 / T5.2 敘事過期 | 新增 Q-018：是否把 declared range 保持 `>=0.8.6,<0.9.0`，但 tested versions 加上 `0.8.7`；或直接把 v0.1 baseline 改成 `0.8.7` |
| B-003 | `specify init` 參數不一致 | 本機 `specify init --help` 使用 `--ai claude`，不是 plan AC-1 寫的 `--integration claude` | AC-1 與 smoke test 第一關會失敗 | 新增 Q-019：將所有 v0.1 指令改成 `specify init <project> --ai claude` |
| B-004 | Claude command registration 路徑矛盾 | plan 鎖 Primary integration = Claude，但 T3.3 又說 installer 預設不寫 `.claude/commands/`；若 B-001 不解，沒有官方 extension install 會幫忙註冊 commands | AC-4「namespaced commands 可見」沒有可執行路徑 | 新增 Q-020：v0.1 是否允許 installer 在 Claude target 中寫入 `.claude/commands/speckit.yuanxi.*.md` |
| B-005 | Phase 0 artifacts 尚不存在 | `specs/yuanxi-sdd-pack-v0.1/` 目前不存在 | 依 Studio Constitution，正式實作前仍不能跳過 specify / clarify / readiness / plan / tasks / analyze | Phase 0 必須先執行，不能直接進 Phase 1 scaffold |

## 4. P1 設計風險

| ID | 風險 | 觀察 | 影響 | 建議處理 |
|---|---|---|---|---|
| R-001 | `governance-lite` supplemental templates 可能看得到但沒效果 | Official preset reference 說 presets 用 file resolution / replace strategy；若不覆寫 core templates，也沒有 command 主動讀 supplemental templates，core `spec` / `plan` / `tasks` 不會自動套用 | AC-6 可達成，但治理欄位可能完全沒有進入產物 | 明確定義 supplemental templates 由 `speckit.yuanxi.readiness` 或 installer docs 引用；若要影響 core artifacts，必須等 v0.2 評估 controlled override |
| R-002 | `setup-readiness.ps1` 不是可直接搬移的 extension script | 該 script 依賴 `common.ps1`、`Find-StudioRoot`、`studio/templates/sdd-docs/readiness-assessment-template.md` 與 workspace path assumptions | T2.7 的「路徑改寫」會比 plan 描述更重，可能需要抽出多個 helper 或重寫最小版 | v0.1 建議寫 pack-local minimal readiness setup script，不直接複製完整 workspace script |
| R-003 | Existing agent files 內含 top-level command references | `.github/agents/speckit.readiness.agent.md` 與 `.github/agents/speckit.eci.agent.md` 仍大量提到 `/speckit.readiness`、`/speckit.eci`、handoff `agent: speckit.readiness` | 直接 snapshot 抽取後會和 namespaced command surface 不一致 | T2.1 至 T2.3 需包含 command reference rewrite checklist |
| R-004 | `specify version` 解析需要穩健設計 | 本機 output 是 formatted table，CLI Version 是 `0.0.22`，Template Version 是 `0.8.7` | Installer 若只 regex 第一個 version，可能拿到 CLI `0.0.22` 而錯誤 abort | T3.2 應明確解析 Template Version，而不是 CLI Version |
| R-005 | Uninstall acceptance 在 direct-copy 模式下會改變 | 若 B-001 導致 installer 直接寫 `.claude/commands/`，`specify extension remove yuanxi` 不會清掉這些檔案 | AC-11 需要改寫，或 installer 需提供 `uninstall.ps1` | 若採 direct-copy，新增 `installer/uninstall.ps1`，並把 AC-11 改成 pack 自己的 uninstall path |

## 5. 建議新增 Open Questions

| ID | 問題 | 建議優先級 |
|---|---|---|
| Q-017 | 目前可用的 Spec Kit CLI 沒有 `extension` / `preset` subcommands。v0.1 要先找出可用的官方 extension-enabled 安裝方式，還是改成 installer direct-copy 模式？ | P0 |
| Q-018 | Compatibility baseline 要更新為 `0.8.7` 嗎？若保留 range `>=0.8.6,<0.9.0`，tested versions 是否至少加入 `0.8.7`？ | P0 |
| Q-019 | 所有 `specify init` 範例與 smoke test 是否改用 `--ai claude`，不再使用 `--integration claude`？ | P0 |
| Q-020 | 若官方 extension registration 不可用，v0.1 installer 是否允許預設寫入 `.claude/commands/speckit.yuanxi.*.md` 以滿足 AC-4？ | P0 |
| Q-021 | 若採 direct-copy 模式，AC-11 是否從 `specify extension remove yuanxi` 改成 `installer/uninstall.ps1`？ | P1 |
| Q-022 | `governance-lite` supplemental templates 在 v0.1 要由哪個 command 主動讀取？ | P1 |

## 6. 建議回寫到原 plan 的修改

| 原 plan 位置 | 建議修改 |
|---|---|
| Frontmatter `governance_basis` | 將 `Official Spec Kit v0.8.6` 改為 `Official Spec Kit v0.8.7`，或標成 `v0.8.6 to v0.8.7 under review` |
| AC-1 | 將 `--integration claude` 改為 `--ai claude` |
| AC-2 / AC-3 / AC-4 | 先標註 dependency：只有在 extension/preset CLI available 時成立；否則改為 direct-copy acceptance |
| D-016 | 補充 latest verified release `v0.8.7`，並說明 tested matrix 應分開記錄 `declared range` 與 `actually tested` |
| T1.2 / T1.3 | 加上 manifest 檔案本身驗證與 CLI installation path 驗證分離 |
| T3.2 | 加入 `specify --help` capability detection；若沒有 `extension` / `preset`，不得直接執行 `specify extension add --dev` |
| T3.3 | 若要滿足 Claude AC-4，需允許 opt-in 或 default 寫入 `.claude/commands/`，並補 uninstall 行為 |
| T4.2 | smoke test 需先檢查 `specify` command surface，再決定 official extension path 或 direct-copy path |
| T5.2 | tested versions 至少應可記錄 `0.8.7`；不要只寫 `0.8.6` |

## 7. 實作前建議順序

1. 先修正原 plan 的 Q-017 至 Q-020。
2. 用本機 `specify --help` 結果決定 v0.1 是 official extension install path 還是 direct-copy fallback path。
3. 更新 compatibility baseline 至 `0.8.7` 或新增 `0.8.7` tested target。
4. 將 smoke test 的 init 指令改成 `specify init <project> --ai claude`。
5. 建立 Phase 0 SDD artifacts：`spec.md`、clarification output、readiness、plan、tasks、analyze。
6. Phase 0 通過後再開始 `studio/packages/yuanxi-sdd-pack/` scaffold。

## 8. 本機檢查摘要

| 檢查 | 結果 |
|---|---|
| `specify version` | CLI Version `0.0.22`；Template Version `0.8.7`；Released `2026-05-07` |
| `specify --help` | commands: `init`、`check`、`version` |
| `specify extension add --help` | no such command |
| `specify preset add --help` | no such command |
| `specify workflow --help` | no such command |
| `specify init --help` | AI option is `--ai`, accepted values include `claude`, `copilot`, `codex` |
| `studio/packages/yuanxi-sdd-pack/` | missing |
| `specs/yuanxi-sdd-pack-v0.1/` | missing |
| Existing Claude assets | `.claude/agents/speckit-readiness.md` and related agents exist |

## 9. 參考來源

| 來源 | URL / Path | 用途 |
|---|---|---|
| Official Spec Kit v0.8.7 release | https://github.com/github/spec-kit/releases/tag/v0.8.7 | latest release baseline |
| Extension Development Guide | https://raw.githubusercontent.com/github/spec-kit/main/extensions/EXTENSION-DEVELOPMENT-GUIDE.md | extension manifest 與 command naming reference |
| Presets Reference | https://raw.githubusercontent.com/github/spec-kit/main/docs/reference/presets.md | preset resolution behavior |
| Workflows Reference | https://raw.githubusercontent.com/github/spec-kit/main/docs/reference/workflows.md | workflow feature reference |
| Studio Constitution | `studio/constitution/constitution.md` | SDD mandatory sequence 與 readiness / ECI governance |
| Implementation Plan | `docs/yuanxi_sdd_pack_implementation_plan_zhTW.md` | reviewed target |
