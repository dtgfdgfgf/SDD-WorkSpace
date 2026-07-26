---
title: "Yuanxi SDD Pack 實作計畫(meta plan)"
version: "0.1.0-iter5"
date: "2026-05-08"
language: "zh-TW"
owner: "元熙"
status: "decisions-complete-v0.1"
parent_documents:
  - "docs/yuanxi_sdd_pack_strategy_zhTW.md"
  - "docs/yuanxi_sdd_pack_strategy_implementation_review_zhTW.md"
governance_basis:
  - "studio/constitution/constitution.md v1.8.0"
  - "Official Spec Kit v0.8.6"
purpose: "把 Yuanxi SDD Pack overlay 策略轉成可逐條實現的 implementation plan,並透過 LLM 多輪迭代收斂未決議題。"
iteration_model: "Open Questions + Decisions Log;每輪 LLM 從 Open Questions 取題目向使用者提問,答覆後移至 Decisions Log。"
current_iteration: 5
---

# Yuanxi SDD Pack 實作計畫(meta plan)

## 0. 文件性質與使用方式

本 plan 為 **iterative-draft**,不是正式 SDD `plan.md`(後者會在 Phase 0 結束後寫入 `specs/yuanxi-sdd-pack-v0.1/plan.md`)。

本 plan 的責任範圍:

| 區段 | 責任 |
|---|---|
| Phase 0 | 啟動正式 SDD 流程(specify、clarify、readiness、plan、tasks、analyze) |
| Phase 1 至 Phase 5 | 描述 SDD 流程外的工程工作(scaffold、extract、installer、smoke test、release) |
| Open Questions | 尚未收斂的決策,由 LLM 在每輪迭代中提問 |
| Decisions Log | 已收斂決策的事實紀錄(含日期、理由、影響範圍) |

迭代規則:

1. 每輪由 LLM 從 Open Questions 取 1 至 4 題向使用者提問。
2. 使用者答覆後,LLM 將題目從 Open Questions 移至 Decisions Log,並更新對應 phase tasks。
3. LLM 在迭代中發現新議題時,新增 Q-XXX 至 Open Questions。
4. 不直接覆寫主體 phase tasks 而失去脈絡;受影響 task 應參照對應 D-XXX。
5. 文件 frontmatter 的 `current_iteration` 每輪 +1,`version` 在實質決策變更時 bump。

---

## 1. 目標與 v0.1 acceptance criteria

### 1.1 目標

將既有 `SDD-WorkSpace` 的個人化 SDD 治理、commands、templates、agent assets,重構為可安裝至任意 official spec-kit project 的 overlay pack,並維持與 upstream spec-kit 的低 drift。

### 1.2 v0.1 acceptance criteria(初版,可在 Phase 0 spec 階段細化)

| 編號 | Acceptance |
|---|---|
| AC-1 | 可在 official `specify init <project> --integration claude` 之後成功安裝 |
| AC-2 | 安裝後 `specify extension list` 看得到 `yuanxi` extension |
| AC-3 | 安裝後 `specify preset list` 看得到 `yuanxi-governance-lite` preset |
| AC-4 | 安裝後 namespaced commands 可見:`speckit.yuanxi.discover`、`speckit.yuanxi.readiness`、`speckit.yuanxi.eci` |
| AC-5 | 官方 core commands(specify、plan、tasks、implement)未被覆寫 |
| AC-6 | 官方 core templates(spec-template、plan-template、tasks-template)未被覆寫 |
| AC-7 | Smoke test 可在乾淨 spec-kit project 執行並通過 |
| AC-8 | `docs/COMPATIBILITY.md` 至少記錄 v0.8.6 為 tested target |
| AC-9 | Readiness command 可產出 `specs/<feature>/readiness/readiness-assessment.md` |
| AC-10 | ECI command 可產出 `specs/<feature>/readiness/eci/` 下四個 dossier 文件 |
| AC-11 | Uninstall 路徑(`specify extension remove yuanxi`)後不殘留破壞性 state |

### 1.3 v0.1 out of scope

- 既有 `projects/`、`learning/` 的 migration。
- Copilot、Codex 整合(列為 v0.2 候選)。
- 公開發行(license、SECURITY.md、CHANGELOG 自動化)。
- 覆寫 official core templates。
- Telemetry 與遠端 installer 公開頁面。
- 多語言(i18n);v0.1 僅 zh-TW。

---

## 2. Decisions Log(已收斂決策)

| ID | 日期 | 決策 | 理由 | 影響範圍 |
|---|---|---|---|---|
| D-001 | 2026-05-08 | Plan 文件性質採 **Meta plan**,放 `docs/yuanxi_sdd_pack_implementation_plan_zhTW.md` | 避免「用 SDD 治理工具治理 SDD 治理工具」的 chicken-and-egg;Phase 0 才啟動正式 SDD | 本文件位置與結構 |
| D-002 | 2026-05-08 | 迭代機制採 **Open Questions + Decisions Log** | 決策追蹤對長期迭代有價值,符合 Studio Constitution 的 surface truthfulness 與 intent ledger 精神 | 本文件 §11、§12 結構 |
| D-003 | 2026-05-08 | v0.1 **納入 ECI**(Path A) | readiness 若保留 `ROUTE_TO_ECI` 必須有 dossier 流程,符合 Studio Constitution §5、§5.1 | Phase 2 須包含 ECI command 與 4 個 dossier templates;v0.1 規模 +30% |
| D-004 | 2026-05-08 | Primary integration target = **Claude** | workspace 已有 `.claude/`、`CLAUDE.md`(直接 import Studio Constitution)、claude-mem 等完整 Claude assets | Phase 3 installer 寫入 `.claude/commands/`;Phase 4 smoke test 鎖 Claude integration |
| D-005 | 2026-05-08 | Pack location 採 **monorepo 過渡 → v1.0 拆 repo** | v0.1 共用 SDD-WorkSpace repo 降低初期 setup 成本;穩定後拆出獨立 repo 以取得乾淨 package boundary | v0.1 路徑為 `studio/packages/yuanxi-sdd-pack/`;新增 Phase 6 追蹤拆 repo 工作 |
| D-006 | 2026-05-08 | Smoke test **v0.1 不 CI 化** | 降低 v0.1 規模;CI 化留待 v0.2,屆時可同步處理跨平台與 Q-014 版本鎖定 | Phase 4 task 數從 4 → 3;移除 T4.4 |
| D-007 | 2026-05-08 | Installer **v0.1 僅 PowerShell** | 主環境為 Windows + PowerShell;bash 版本留待 v0.2 | Phase 3 task 數從 5 → 4;移除原 T3.3(install.sh) |
| D-008 | 2026-05-08 | v0.1 **僅本地 dev install**,不支援遠端安裝 | 不需建立 GitHub release tag 與 mutable URL 風險;對應 Q-002 catalog 可標為 placeholder | Phase 5 task 數從 4 → 3;移除原 T5.4(release 自動化);Phase 5 工作集中在 INSTALL/COMPATIBILITY/UPGRADE 文件 |
| D-009 | 2026-05-08 | Studio Constitution 採 **optional ship**,installer 加 `--include-constitution` flag,預設不 ship | 個人使用方便、未來公開保留彈性;不強制 target project 接受特定治理 | Phase 3 installer 須處理 flag;default 與 opt-in 兩條 path 在 INSTALL_REPORT 中各自記錄 |
| D-010 | 2026-05-08 | Installer 一律建立 target project 的 `.specify/memory/constitution.md` **empty skeleton**(與 D-009 不衝突:skeleton 是 project constitution 空殼,Studio Constitution 是 source 在別處) | 對齊憲法 §11 結構要求,讓使用者可立即填寫 project-specific 規則;`--include-constitution` flag 啟用時 skeleton frontmatter 標註 governing parent | Phase 3 +1 task:T3.5(skeleton 建立 + flag-aware frontmatter) |
| D-011 | 2026-05-08 | Readiness gate 採 **v0.1 純文件 guardrail**,不引入 spec-kit workflow / hooks | 降低 v0.1 規模、不依賴 upstream workflow API 穩定性;readiness command body 自行宣告 next steps,plan 前提示寫於 INSTALL.md 與 readiness output | Phase 2 T2.2 新增「Next steps section + 不修改 official `/speckit.plan`」要求;不引入 wrapper command |
| D-012 | 2026-05-08 | SDD-WorkSpace migration 採 **漸進式**:新專案用 pack,舊 `projects/`、`learning/` 不動 | 避免大量重構,保留實驗區自由度;Phase 6 拆 repo 後 workspace 仍為 studio dev repo,不消費 pack | Phase 6 T6.5 改寫為「workspace 不 dogfood pack,新專案在 workspace 外使用」;v0.1 out of scope 確認 |
| D-013 | 2026-05-08 | Catalog 採 **empty placeholder + draft 標記**(`status: draft, not consumed by spec-kit until v1.0`) | 保留 v1.0 公開所需結構,避免 v1.0 重做 schema design;標 draft 防止使用者誤以為已生效 | Phase 1 T1.5 task 內容明確化;v0.1 catalog 不被 installer / spec-kit 實際消費 |
| D-014 | 2026-05-08 | `studio/runtime/shared-runtime-contract.json` **pack 範圍排除**,workspace 自管;pack 不引用、不複製、不複製為 fixture | 避免 dual maintenance;尊重憲法 §12 該檔之 source of truth 定位;Phase 6 拆 repo 時再評估 pack 是否需自己的 contract | Phase 4 smoke test 不引用此檔;新 Open Question Q-016 留待 Phase 6 觸發 |
| D-015 | 2026-05-08 | Generated artifacts(`.github/agents/*`、`resources/agent-skill-packs/`)**v0.1 不建立 build/export script**,Phase 2 採 snapshot 一次性抽取 | 降低 v0.1 規模;build script 留待 v1.0 拆 repo 後視 dogfooding 需求評估;snapshot 抽取已是 Phase 2 的既定路徑 | Phase 2 task 數不變;v0.1 完成後不保證 export-back 能力;此事實寫入 INSTALL_REPORT 與 docs/UPGRADE.md |
| D-016 | 2026-05-08 | Spec Kit version 鎖定策略採 **寬鬆 range `>=0.8.6,<0.9.0` + COMPATIBILITY.md 顯式 tested matrix** | 平衡使用者升級彈性與誠實揭露;tested matrix 提供「真正驗證過的版本」資訊;升 patch 不需 pack release | Phase 3 T3.2 須含 range 檢查邏輯;Phase 5 T5.2 COMPATIBILITY.md 必含 `spec-kit declared range` 與 `tested versions` 兩欄 |
| D-017 | 2026-05-08 | Phase 6 後 pack **不需自己的 shared-runtime-contract**(extension.yml + preset.yml + COMPATIBILITY.md 已足夠描述介面與相容性) | Contract verification 為 workspace 內部工具;pack 是 distributable artifact 不需 contract;避免 dual maintenance | Phase 6 task 數不變;Q-016 提前 lock |
| D-018 | 2026-05-08 | License 採 **MIT** | Permissive、簡單、與 spec-kit base 生態一致;對 commands/templates 內容合適 | Phase 6 T6.3 直接寫入 MIT LICENSE;Q-012 lock |
| D-019 | 2026-05-08 | i18n 採 **v0.1 不預留路徑結構**,需時重構 | v0.1 鎖 zh-TW 已是 §1.3 out of scope;預留路徑增加 v0.1 內在複雜度;未來 migration 成本可接受 | templates 直接放 `extensions/yuanxi/templates/`,不分子目錄 |
| D-020 | 2026-05-08 | **永不加 telemetry** | Pack 為個人 studio 工具,telemetry 無決定性價值;隱私優先 | 不寫入任何 telemetry hook;Q-015 lock |

---

## 3. Phase 總覽

| Phase | 名稱 | scope | 目的 | 主要產出 | 預估 task 數 |
|---|---|---|---|---|---|
| 0 | SDD bootstrap | v0.1 | 把策略轉成正式 SDD 治理產物 | `specs/yuanxi-sdd-pack-v0.1/{spec, readiness, plan, tasks}.md` | 6 |
| 1 | Package scaffold | v0.1 | 建立 pack 目錄結構與 manifest | `studio/packages/yuanxi-sdd-pack/` 初骨架 | 5 |
| 2 | Extension content | v0.1 | 抽取既有 assets 並 namespace 化為 extension commands、templates、scripts | `extensions/yuanxi/{commands,templates,scripts}/` | 8 |
| 3 | Preset & installer | v0.1 | 建立 governance-lite preset 與 PowerShell installer(含 constitution flag、skeleton 邏輯) | `presets/yuanxi-governance-lite/`、`installer/install.ps1` | 5 |
| 4 | Smoke test | v0.1 | 建立可重跑驗證(本地手動) | `tests/smoke-test.{md,ps1}`、`tests/fixtures/` | 3 |
| 5 | Compatibility 文件 | v0.1 | Compatibility matrix、INSTALL、UPGRADE 文件 | `docs/{INSTALL,COMPATIBILITY,UPGRADE}.md` | 3 |
| 6 | Repo extraction | v1.0+ | 從 monorepo 拆為獨立 repo 並啟用公開發行所需 metadata | 新 repo `dtgfdgfgf/yuanxi-sdd-pack`、CI、license、SECURITY、CHANGELOG | 5 |

---

## 4. Phase 0:啟動正式 SDD 治理

目的:讓 yuanxi-sdd-pack v0.1 自身先通過 Studio Constitution §2 的 mandatory sequence,避免 v0.1 在憲法層面就站不住腳。

| Task | 說明 | DoD |
|---|---|---|
| T0.1 | 在 workspace 根建立 `specs/yuanxi-sdd-pack-v0.1/spec.md`。內容以 `docs/yuanxi_sdd_pack_strategy_zhTW.md` 為 source basis,補上 Studio Constitution §3 必填欄位(actors、scenarios、FR、NFR、edge cases、success criteria、out of scope) | spec.md 通過憲法 §3 所有必填欄位檢查 |
| T0.2 | 執行 `/speckit.clarify`,解決 P0 阻礙(Q-001 至 Q-004 等已在本 plan 中收斂者直接寫入,其餘標為待 clarify) | clarification 文件無高風險 ambiguity |
| T0.3 | 執行 `/speckit.readiness`,產出 `specs/yuanxi-sdd-pack-v0.1/readiness/readiness-assessment.md`;若 ECI 為 v0.1 scope(D-003 已決),readiness 須驗證自身不需要 `ROUTE_TO_ECI`(因為本 pack 不引入新 external capability) | readiness 主分類為 `READY_FOR_PLAN` |
| T0.4 | 若 spec 階段任何 core item 被 represented_by_substitute 或 deferred,建立 `specs/yuanxi-sdd-pack-v0.1/intent-ledger.md`(憲法 §5 secondary artifact) | 若需要,intent-ledger.md 欄位齊全;若全範圍未壓縮,則略過 |
| T0.5 | 執行 `/speckit.plan`,產出 `specs/yuanxi-sdd-pack-v0.1/plan.md`,涵蓋憲法 §6 必填(架構、技術決策、整合點、資料流、Intent Recovery Obligations、約束、Why Not、預估、版本歷史) | plan.md 通過憲法 §6 必填欄位檢查 |
| T0.6 | 執行 `/speckit.tasks` 與 `/speckit.analyze`,產出 tasks.md 並通過 Intent Drift Check;analyze 結果無 critical 或 major finding | tasks.md 符合憲法 §7 格式;analyze 通過 |

Phase 0 完成後,Phase 1 起的 task 可開始撰寫程式碼與資產。

---

## 5. Phase 1:Package scaffold

目的:建立 pack 目錄與最小 manifest,確認 official spec-kit 可辨識本 pack 為合法 extension + preset。

| Task | 說明 | DoD |
|---|---|---|
| T1.1 | 建立 `studio/packages/yuanxi-sdd-pack/` 根目錄與 `README.md`(指向本 plan 與 spec) | 目錄存在,README 含 INSTALL 簡要指引 |
| T1.2 | 建立 `extensions/yuanxi/extension.yml`,extension_id = `yuanxi`,聲明 v0.1 commands(discover、readiness、eci) | 通過 official spec-kit extension manifest schema 驗證 |
| T1.3 | 建立 `presets/yuanxi-governance-lite/preset.yml`,聲明 supplemental templates(不覆寫 core) | 通過 official preset manifest schema 驗證 |
| T1.4 | 建立 `installer/`、`tests/`、`docs/` 子目錄與 placeholder 檔案 | 目錄結構符合策略文件 §3 與 implementation review §5 |
| T1.5 | 建立 `catalog/extension-catalog.json` 與 `catalog/preset-catalog.json`,內容為 **empty placeholder + draft 標記**(D-013):至少含 `status: "draft"`、`note: "v0.1 仅本地 dev install,catalog 未实际使用;v1.0 公開時以 official schema 填寫"`、最小 `extensions[]`/`presets[]` 陣列(僅 id 與 version) | catalog 格式 valid JSON;`status` 欄位明確標 draft;不被 installer 引用 |

---

## 6. Phase 2:Extension content(commands、templates、scripts)

目的:把 `.github/agents/`、`.github/prompts/`、`studio/templates/sdd-docs/` 中既有資產抽取為 namespaced extension content。

| Task | 來源 | 目的地 | DoD |
|---|---|---|---|
| T2.1 | `.github/agents/speckit.discover.agent.md` | `extensions/yuanxi/commands/discover.md` | command 註冊名為 `speckit.yuanxi.discover`,移除 workspace-only 語句 |
| T2.2 | `.github/agents/speckit.readiness.agent.md` | `extensions/yuanxi/commands/readiness.md` | 保留所有 8 種 readiness primary status 分類能力;移除 ROUTE_TO_ECI 失敗 fallback 至 ECI 之矛盾(若有);command 註冊名為 `speckit.yuanxi.readiness`;**輸出末段必須含 `## Next steps` 區段**(D-011),依當前 primary status 給出下一步指令(若 `READY_FOR_PLAN`,提示執行 `/speckit.plan` 並提醒 plan 前須確認 readiness assessment 存在且為 READY_FOR_PLAN);**不修改 official `/speckit.plan`** |
| T2.3 | `.github/agents/speckit.eci.agent.md` | `extensions/yuanxi/commands/eci.md` | command 註冊名為 `speckit.yuanxi.eci`;output contract 對齊憲法 §5.1 四個 dossier artifacts |
| T2.4 | `studio/templates/sdd-docs/readiness-assessment-template.md` | `extensions/yuanxi/templates/readiness-assessment-template.md` | 路徑與 readiness command output contract 一致 |
| T2.5 | `studio/templates/sdd-docs/intent-ledger-template.md` | `extensions/yuanxi/templates/intent-ledger-template.md` | 欄位對齊憲法 §5 列出的 9 個固定欄位 |
| T2.6 | `studio/templates/sdd-docs/eci-{assessment,source-manifest,adoption-record,authorization-record}.md` | `extensions/yuanxi/templates/eci-*.md` | 四份 dossier templates 齊全(因 D-003) |
| T2.7 | `studio/scripts/powershell/setup-readiness.ps1` | `extensions/yuanxi/scripts/powershell/setup-readiness.ps1` | 路徑改寫為 extension 相對路徑;無 workspace-only 假設 |
| T2.8 | (新增)為每個 yuanxi command 加 artifact compatibility check header(spec-kit 版本、required sections、graceful degradation) | `extensions/yuanxi/commands/_lib/check-artifact.md` 或 inline | 命令在 spec-kit drift 時可給出可讀錯誤,而非崩潰 |

---

## 7. Phase 3:Preset 與 installer

目的:建立 governance-lite preset 與本地 dev installer。

| Task | 說明 | DoD |
|---|---|---|
| T3.1 | `presets/yuanxi-governance-lite/templates/`:新增 supplemental sections(business-risk、merchant-perspective、KPI 等),不覆寫 core templates | preset.yml 中只引用 supplemental,不 override `spec-template.md` 等 |
| T3.2 | `installer/install.ps1`:檢查目前目錄為 spec-kit project、檢查 `specify version` **在 `>=0.8.6,<0.9.0` 範圍內**(D-016),不在範圍內 abort 並顯示 COMPATIBILITY.md 連結;執行 `specify extension add --dev`、`specify preset add --dev`、顯示驗證指令 | 在乾淨 spec-kit project 中執行成功且不修改 core;range 檢查邏輯在 spec-kit 0.8.5 與 0.9.0 兩個邊界皆能正確 abort |
| T3.3 | Installer 不自動覆寫 project-local agent adapters(`.claude/commands/` 等);若需寫入,須使用者明確 opt-in flag | installer 預設行為不破壞既有 adapters |
| T3.4 | Installer 寫一份 `INSTALL_REPORT.md`(在 target project)記錄安裝版本、命令清單、constitution flag 狀態、下一步驗證指令 | report 內容與實際安裝結果一致 |
| T3.5 | Installer 處理 **constitution skeleton + flag**(D-009、D-010):一律建立 `target/.specify/memory/constitution.md` 空 skeleton;若使用者傳入 `-IncludeConstitution` flag,skeleton frontmatter 標註 `governing_parent: studio/constitution/constitution.md` 與版本(目前 v1.8.0),並額外寫入 `target/studio-constitution-link.md` 指向 source repo;skeleton 已存在時 default 不覆寫(可選 `-Force` 強制) | 兩種 path 皆能在 smoke test 中驗證;skeleton 結構符合憲法 §11 的 Project Constitution 預期 |

---

## 8. Phase 4:Smoke test

目的:建立可重跑驗證,降低 upstream drift 帶來的回歸成本。

| Task | 說明 | DoD |
|---|---|---|
| T4.1 | 建立 `tests/smoke-test.md`:固定 toy feature,一份逐步指令清單,可由人工或 agent 執行 | 文件可在乾淨環境執行 |
| T4.2 | 建立 `tests/smoke-test.ps1`:自動化版本,涵蓋 §1.2 的 AC-1 至 AC-11(可自動檢查者) | 全部可自動化 AC 通過 |
| T4.3 | 建立 fixture:`tests/fixtures/toy-feature/expected-readiness.md`、`expected-tasks.md` | fixtures 與 smoke-test 期望輸出一致 |

---

## 9. Phase 5:Compatibility 文件

目的:建立版本相容矩陣與升級流程文件。release 機制(license、CHANGELOG 等)已移至 Phase 6,因 D-008 v0.1 不需公開發行。

| Task | 說明 | DoD |
|---|---|---|
| T5.1 | `docs/INSTALL.md`:official-first 安裝流程(`specify init` 後執行本地 installer) | 文件可被新使用者照做 |
| T5.2 | `docs/COMPATIBILITY.md`:matrix 欄位**必含**(D-016)`pack version`、`spec-kit declared range`、`tested versions`、`status`、`notes`;v0.1 至少一筆,`spec-kit declared range = >=0.8.6,<0.9.0`、`tested versions = 0.8.6` | matrix 至少一筆;欄位齊全;tested versions 與 declared range 不混淆 |
| T5.3 | `docs/UPGRADE.md`:upstream spec-kit 升級時的 smoke test checklist | 文件指向 §8 smoke-test |

---

## 10. Phase 6:Repo extraction(v1.0+ scope tracking)

目的:tracking-only。本 phase 在 v0.1 不執行,僅在此 plan 中保留以避免長期決策被遺忘。觸發條件為 v0.1 穩定後或公開發行決策成立。

| Task | 說明 | DoD |
|---|---|---|
| T6.1 | 建立新 repo `dtgfdgfgf/yuanxi-sdd-pack`,從 monorepo 抽出 `studio/packages/yuanxi-sdd-pack/` 內容 | 新 repo 含完整 git history(以 git filter-repo 或 subtree 抽取) |
| T6.2 | 設置 GitHub Actions CI,涵蓋 smoke test 跨平台執行(對應 Q-003 升級) | CI 在 push/PR 時自動跑 smoke test |
| T6.3 | 加入 `LICENSE`(D-018:**MIT**)、`SECURITY.md`、`CHANGELOG.md`、`CODE_OF_CONDUCT.md` | repo 符合公開發行最低 metadata;LICENSE 為 standard MIT text |
| T6.4 | 建立 release tag 機制(v1.0.0 起);installer 同步加入 tagged 遠端安裝入口 | `irm <tag-url> \| iex` 可用,不依賴 mutable `main` |
| T6.5 | (依 D-012 漸進式 migration)SDD-WorkSpace 在 pack 拆出後**仍保留為 studio dev repo,不消費 pack**;新專案在 workspace 之外建立並安裝 pack。本 task 產出 `templates/new-project-bootstrap.md` 描述 workspace 之外的新專案啟動流程 | 文件可被使用者照做啟動新專案;workspace 自身不被迫 migrate |

---

## 11. 跨 phase 風險與 mitigation

| 風險 | 來源 | Mitigation |
|---|---|---|
| Spec Kit core command drift | upstream | T2.8 加 artifact compatibility check;每次 upstream 升級先跑 smoke test |
| Template drift | preset 過度覆寫 | AC-6 與 §1.3 out of scope 已限定:v0.1 僅 supplemental,不覆寫 core templates |
| Readiness gate 弱化 | 不覆寫 `/speckit.plan` 但要求 readiness 強制 | D-011 已決:v0.1 採純文件 guardrail;readiness command 輸出含 Next steps 區段;workflow/hooks 機制留待 v0.2 評估 |
| Studio Constitution 與 pack 版本綁定 | 憲法升級時 pack 未同步 | D-009 已決:Constitution optional ship,skeleton frontmatter 標註 governing parent 版本;**pack release 時須同步檢查 Studio Constitution 版本**(列為 Phase 5 UPGRADE.md 必備章節);長期綁定機制留待 v0.2 設計 |
| 既有 SDD-WorkSpace migration | 策略未談 | D-012 已決:漸進式,新專案才用 pack;v0.1 不 migrate `projects/`、`learning/` |

---

## 12. Open Questions

每輪迭代由 LLM 從此清單取 1 至 4 題向使用者提問。已決議題目移至 §2 Decisions Log,保留 Q-XXX ID 供追溯。

**v0.1 + Phase 6 範圍內所有 Open Questions 皆已收斂(iter 5 完成)**。本區塊保持為 placeholder,供未來在 plan 執行階段(Phase 0 起)發現新議題時加入。

新題目命名沿用 `Q-NNN` 流水號,從 Q-017 起。

---

## 13. Iteration Log

| Iteration | 日期 | 摘要 | 變更 |
|---|---|---|---|
| 1 | 2026-05-08 | 初版生成 | D-001、D-002、D-003、D-004 收斂;Open Questions Q-001 至 Q-015 列出 |
| 2 | 2026-05-08 | 高優先 Q-001、Q-003、Q-004、Q-005 收斂 | D-005(monorepo 過渡)、D-006(不 CI 化)、D-007(僅 PowerShell)、D-008(僅本地 install);新增 Phase 6(repo extraction tracking);Phase 3 task 5→4;Phase 4 task 4→3;Phase 5 task 4→3;Q-002 改寫(catalog placeholder 內容) |
| 3 | 2026-05-08 | 治理邊界 Q-006、Q-007、Q-008、Q-009 收斂 | D-009(optional ship Constitution)、D-010(empty skeleton 一律建立)、D-011(純文件 guardrail)、D-012(漸進 migration);Phase 3 task 4→5(新增 T3.5 constitution flag 處理);Phase 2 T2.2 加 Next steps 要求;Phase 6 T6.5 改寫 |
| 4 | 2026-05-08 | 中優先 Q-002、Q-010、Q-011、Q-014 收斂 | D-013(catalog draft placeholder)、D-014(shared-runtime-contract 排除)、D-015(snapshot 抽取無 build script)、D-016(寬鬆 range + tested matrix);Phase 1 T1.5、Phase 3 T3.2、Phase 5 T5.2 內容明確化;新增 Q-016(Phase 6 觸發) |
| 5 | 2026-05-08 | 低優先 Q-016、Q-012、Q-013、Q-015 收斂(plan v0.1 範圍內 Open Questions 全部清空) | D-017(pack 不需自己的 contract)、D-018(MIT license)、D-019(不預留 i18n)、D-020(永不加 telemetry);Phase 6 T6.3 license 寫入 MIT;狀態從 `iterative-draft` 升至 `decisions-complete-v0.1` |

---

## 14. 參考來源

| 來源 | 用途 |
|---|---|
| `docs/yuanxi_sdd_pack_strategy_zhTW.md` | 策略 source basis |
| `docs/yuanxi_sdd_pack_strategy_implementation_review_zhTW.md` | implementation gap 補充 |
| `studio/constitution/constitution.md` v1.8.0 | 治理規則(SDD sequence、readiness、ECI、formatting) |
| Official Spec Kit v0.8.6 release | compatibility baseline |
| Spec Kit Extension Development Guide | extension 命名與 manifest 規範 |
| Spec Kit Presets Reference | preset 安裝與 catalog 模型 |
| Spec Kit Workflows Reference | Q-008 評估依據 |
