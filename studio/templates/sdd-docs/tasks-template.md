# Tasks: [FEATURE NAME]

<!--
  STUDIO TEMPLATE v1.1.0
  Canonical task line format:
  - [ ] T### [P#] [Risk: X] [Story: ...] Description
-->

**Feature ID**: `[NNN-feature-name]`  
**Date**: [DATE]  
**Prerequisites**: `spec.md`, `plan.md`  
**Version**: 1.1.0

## Canonical Format

Every task entry MUST begin with a checklist line in this format:

```text
- [ ] T001 [P1] [Risk: Low] [Story: Foundation] 建立專案基礎結構
```

Rules:

- `T###` is the stable task ID.
- `[P1]`, `[P2]`, `[P3]` indicates priority.
- `[Risk: Low|Medium|High]` is required.
- `[Story: ...]` is required when the task maps to a user story or cross-cutting theme.
- Use exact file paths inside descriptions when useful.
- Put dependencies and Definition of Done on the lines immediately following the task.

## Summary (Optional)

| Phase | Focus | Estimated |
|------|-------|-----------|
| Setup | 專案初始化與開發環境 | 0.5 day |
| Foundation | 核心基礎能力 | 1 day |
| Story Delivery | 使用者故事實作 | 1.5 days |
| Polish | 文件、驗證、收尾 | 0.5 day |

## Phase 1: Setup

- [ ] T001 [P1] [Risk: Low] [Story: Foundation] 建立 `src/`、`tests/`、設定檔與基礎專案結構
  Definition of Done:
  - [ ] 必要資料夾與基礎設定檔已建立
  - [ ] 專案可執行最小建置或測試命令
  Depends on: None

- [ ] T002 [P1] [Risk: Low] [Story: Foundation] 安裝核心相依並確認本地開發環境
  Definition of Done:
  - [ ] 相依安裝成功
  - [ ] 本地啟動命令或測試命令可通過
  Depends on: T001

## Phase 2: Foundation

- [ ] T010 [P1] [Risk: Medium] [Story: Foundation] 建立共用資料模型、錯誤處理與設定管理
  Definition of Done:
  - [ ] 基礎模型與設定可被應用程式載入
  - [ ] 錯誤回應與日誌格式已定義
  Depends on: T002

- [ ] T011 [P1] [Risk: Medium] [Story: Foundation] 建立資料存取與測試基礎設施
  Definition of Done:
  - [ ] Repository 或 data access layer 可運作
  - [ ] 測試環境可執行最小 smoke test
  Depends on: T010

## Phase 3: Story Delivery

### User Story 1

- [ ] T020 [P1] [Risk: Medium] [Story: US-001] 實作第一個使用者故事的核心服務
  Definition of Done:
  - [ ] 服務行為符合 `spec.md`
  - [ ] 對應測試通過
  Depends on: T011

- [ ] T021 [P1] [Risk: Medium] [Story: US-001] 串接對外介面或應用層入口
  Definition of Done:
  - [ ] 入口層可呼叫核心服務
  - [ ] 成功與錯誤情境皆被覆蓋
  Depends on: T020

### User Story 2

- [ ] T030 [P2] [Risk: Medium] [Story: US-002] 實作第二個使用者故事的核心能力
  Definition of Done:
  - [ ] 使用者故事可獨立驗證
  - [ ] 與既有故事整合不破壞既有行為
  Depends on: T021

## Phase 4: Polish

- [ ] T090 [P2] [Risk: Low] [Story: Polish] 更新 README、quickstart、運維或交付文件
  Definition of Done:
  - [ ] 文件與實際行為一致
  - [ ] 主要操作流程已可被新成員重現
  Depends on: T030

- [ ] T091 [P2] [Risk: Low] [Story: Polish] 執行最終驗證並整理剩餘風險
  Definition of Done:
  - [ ] 測試、lint 或既定驗證已執行
  - [ ] 已知風險已記錄
  Depends on: T090

## Dependency Summary

| Task | Depends on |
|------|------------|
| `T001` | None |
| `T002` | `T001` |
| `T010` | `T002` |
| `T011` | `T010` |
| `T020` | `T011` |
| `T021` | `T020` |
| `T030` | `T021` |
| `T090` | `T030` |
| `T091` | `T090` |

## Notes

- Keep task size in the 0.5 to 2 day range.
- Keep each task traceable to `spec.md` and `plan.md`.
- Update status by switching `- [ ]` to `- [x]`.
- If blocked, record the blocker instead of silently skipping the task.

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.1.0 | [DATE] | Switch to checklist-first canonical task format |
| 1.0.0 | [DATE] | Initial task decomposition |
