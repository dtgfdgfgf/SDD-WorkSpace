# Workspace Analysis Records

本目錄集中保存 workspace 級分析、治理評估、維護策略、設計決策記錄與 mainline
更新說明。

## Authority

本檔與本節所列分析文件的 authority 為 `informational`。它們提供可追溯的證據、判斷與
建議，但不取代以下正式來源：

- `studio/constitution/constitution.md`
- `.specify/memory/constitution.md`（存在時）
- `studio/runtime/shared-runtime-contract.json`
- `studio/runtime/impact-registry.json`
- 各 runtime source、schema、script、agent 與 test

## Workspace-Wide Analysis Convention

當分析範圍涵蓋整體 workspace、shared governance、runtime agents、workflow、extension、
跨專案維護狀態或長期演進策略時，採用以下保存慣例：

1. 在最終回覆前，將完整分析直接寫入 `docs/`，不只保留在對話中。
2. 使用日期化檔名，例如
   `sdd-workspace-<topic>-YYYY-MM-DD_zhTW.md`。
3. 文件 frontmatter 至少記錄 `date`、`status`、`authority`、分析分支、base/head commit
   與 scope。
4. 文件至少包含治理基準、範圍、結論、依嚴重度排序的 findings、驗證證據、已知限制
   與後續行動。
5. 建立新分析後，在本檔的索引新增一列。
6. 歷史分析是時間點快照。後續狀態改變時，優先新增日期化分析或明確的版本歷史，
   不靜默改寫舊結論。

## Environment Analysis Index

| Date | Record | Status | Scope |
|------|--------|--------|-------|
| 2026-07-14 | [`sdd-workspace-wave-3-remediation-plan-2026-07-14_zhTW.md`](./sdd-workspace-wave-3-remediation-plan-2026-07-14_zhTW.md) | Plan | 依 2026-07-14 re-review 的 12 條 RVR findings 制定的分批修復計畫；三聯表對映 ledger、標出被推翻的 R-B02/R-B05 closure，排定 R2.1 誠實性還原 + RB-1 至 RB-5 + R6 合併 main |
| 2026-07-14 | [`sdd-workspace-wave-3-governance-review-2026-07-14_zhTW.md`](./sdd-workspace-wave-3-governance-review-2026-07-14_zhTW.md) | Review record; not ready to merge | `feature/wave-3-security-and-workflows` 相對 `main` 的 26 commits 治理導向 re-review；記錄 workflow completion/authorization、mandatory gates、mainline evidence、ECI、extension trust、consumer isolation 與 upgrade atomicity findings |
| 2026-07-12 | [`sdd-workspace-repair-inventory-and-update-plan-2026-07-12_zhTW.md`](./sdd-workspace-repair-inventory-and-update-plan-2026-07-12_zhTW.md) | R0/R1 completed; R2 partial (R-B02/B05 reopened); R2.1 done | 共享層 123 條修復總清單（v1.6.0）；2026-07-14 re-review 以反例推翻 R-B02/B05 closure，兩者重開並移交 R-B19/B20；新增 9 條 RVR findings；後續 RB-1 至 RB-5 + R6 見 remediation plan；分支目前 NOT READY TO MERGE |
| 2026-07-12 | [`sdd-workspace-deep-analysis-and-career-value-2026-07-12_zhTW.md`](./sdd-workspace-deep-analysis-and-career-value-2026-07-12_zhTW.md) | Analysis | 整體環境深度分析、上游同步策略、面試方視角與求職價值評估、優先序改善路線圖 |
| 2026-07-12 | [`sdd-workspace-wave-3-governance-review-2026-07-12_zhTW.md`](./sdd-workspace-wave-3-governance-review-2026-07-12_zhTW.md) | Review record | `feature/wave-3-security-and-workflows` 相對 `main` 的 13 commits 治理導向 review |
| 2026-07-11 | [`sdd-workspace-purpose-governance-maintenance-usage-analysis-2026-07-11_zhTW.md`](./sdd-workspace-purpose-governance-maintenance-usage-analysis-2026-07-11_zhTW.md) | Analysis | Workspace 目的、治理、維護與使用理念 |
| 2026-07-08 | [`sdd-workspace-deep-review-2026-07-08_zhTW.md`](./sdd-workspace-deep-review-2026-07-08_zhTW.md) | Session record | 整體環境評估與長期維護策略 |

其他類型的文件由各子目錄或既有命名慣例管理：

| Path | Purpose |
|------|---------|
| `docs/mainline-updates/` | main-bound shared-layer update notes |
| `docs/readiness_source/` | readiness 設計參考資料，不是 runtime acceptance source |
| `docs/0308upstreams/` | upstream alignment records |
