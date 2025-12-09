# Specification Analysis Report

**分析日期**: 2025-12-01  
**版本**: analyze-03 (修正後重新分析)  
**前次分析**: analyze-02.md  
**狀態**: ✅ 可進行實作

---

## Executive Summary

本次分析為修正後的重新分析，針對 `analyze-02.md` 中發現的問題進行驗證。所有 **CRITICAL** 和 **HIGH** 級別問題已透過適當的文件修正解決。整體規格品質已達到實作標準。

### Key Improvements Since analyze-02.md

| 問題 | analyze-02 狀態 | 修正方式 | analyze-03 狀態 |
|------|----------------|----------|----------------|
| Redis 快取違反 Constitution IV | CRITICAL | 新增 Complexity Tracking 於 plan.md | ✅ RESOLVED |
| 無 E2E 測試 | HIGH | 新增 Complexity Tracking 說明替代方案 | ✅ RESOLVED |
| 前端需求混入後端規格 | MEDIUM | 新增「範圍說明」章節於 spec.md | ✅ RESOLVED |
| IMemoryCache 任務缺失 | - | 新增 T027a 任務於 tasks.md | ✅ RESOLVED |

---

## Findings Table

| ID | Category | Severity | Location(s) | Summary | Recommendation |
|----|----------|----------|-------------|---------|----------------|
| D1 | Duplication | LOW | spec.md:L89, L109 | FR-011 與 US4 重複描述「未驗證會員可登入」 | 可接受，FR 提供正式需求定義，US 提供情境上下文 |
| A1 | Ambiguity | LOW | spec.md:L90 | FR-012 「部分功能」未明確定義 | 已在假設中說明將由後續規格定義，可接受 |
| U1 | Underspec | LOW | data-model.md | Member.PasswordHash 未指定雜湊演算法 | 建議於 data-model.md 補充說明使用 PasswordHasher<T> |
| U2 | Underspec | LOW | spec.md:L87 | FR-004b CAPTCHA 未指定第三方服務 | 建議於 research.md 補充 CAPTCHA 服務選型 |
| C1 | Consistency | MEDIUM | tasks.md:T060-T062 | US4 任務涉及登入功能，但登入 API 不在此規格範圍 | 建議調整 US4 任務描述，明確限制為「狀態查詢」非「登入驗證」 |
| G1 | Coverage | LOW | tasks.md | NFR: API < 200ms (p95) 無明確效能測試任務 | 可於 Phase 8 補充效能基準測試任務 |

---

## Coverage Summary Table

| Requirement Key | Has Task? | Task IDs | Notes |
|-----------------|-----------|----------|-------|
| FR-001 (註冊表單) | ✅ | T035, T039, T040 | Request DTO + Service + Controller |
| FR-001a (輸入標準化) | ✅ | T039 | MemberService.RegisterAsync |
| FR-001b (失焦驗證) | ⚠️ | - | 前端實作責任（已於範圍說明釐清） |
| FR-002 (身分證驗證) | ✅ | T029, T033 | TaiwanIdValidator + Tests |
| FR-003 (身分證唯一) | ✅ | T031, T039 | MemberService + Tests |
| FR-003a (Email 唯一) | ✅ | T031, T039 | MemberService + Tests |
| FR-004 (密碼規則) | ✅ | T030, T034 | PasswordValidator + Tests |
| FR-004a (密碼確認) | ✅ | T034 | PasswordValidator |
| FR-004b (CAPTCHA) | ✅ | T020, T024, T041 | ICaptchaValidator + Impl + Logic |
| FR-005 (發送驗證碼) | ✅ | T019, T023, T039 | EmailService + Integration |
| FR-006 (5分鐘有效) | ✅ | T043, T048, T050 | VerificationService + Tests |
| FR-007 (驗證碼輸入) | ⚠️ | T045 | 僅 Request DTO，UI 為前端責任 |
| FR-008 (更新已驗證) | ✅ | T048, T051 | VerificationService |
| FR-009 (重新發送) | ✅ | T052, T055 | ResendCodeAsync |
| FR-010 (60秒冷卻) | ✅ | T052, T055, T057 | Cooldown logic + Tests |
| FR-011 (未驗證可登入) | ⚠️ | T060 | 狀態查詢（登入 API 由其他規格定義） |
| FR-012 (功能受限) | ⚠️ | T061, T062 | 狀態回應（具體清單由其他規格定義） |
| FR-013 (單向流程) | ⚠️ | - | 前端實作責任 |
| FR-014 (不自動登入) | ⚠️ | - | 前端實作責任 |
| FR-015 (無社群登入) | ✅ | - | 排除需求，無需實作 |
| FR-016 (無密碼提示) | ✅ | - | 排除需求，無需實作 |
| FR-017 (無連結驗證) | ✅ | - | 排除需求，無需實作 |
| FR-018 (7天清理) | ✅ | T063, T064, T065 | CleanupJob + Tests |

### Coverage Legend

- ✅ 完整覆蓋（後端 API）
- ⚠️ 部分覆蓋或不在範圍內（已說明）

---

## Constitution Alignment Issues

### ✅ RESOLVED: Constitution IV - 無 Redis 快取

**位置**: `plan.md` > Complexity Tracking

**狀態**: 已透過 Complexity Tracking 正式記錄並說明替代方案

| Violation | Why Needed | Simpler Alternative |
|-----------|------------|---------------------|
| Constitution IV: 無 Redis 快取 | 專案規模小（初期 10,000 使用者） | 使用 `IMemoryCache` 作為輕量替代 |

**驗證**: T027a 已新增於 tasks.md 以實作 IMemoryCache 設定。

### ✅ RESOLVED: Constitution II - 無 E2E 測試

**位置**: `plan.md` > Complexity Tracking

**狀態**: 已透過 Complexity Tracking 正式記錄並說明替代方案

| Violation | Why Needed | Simpler Alternative |
|-----------|------------|---------------------|
| Constitution II: 無 E2E 測試 | 純後端 API 專案，無前端整合 | 整合測試覆蓋 API 端點，E2E 待前端開發時補充 |

**驗證**: 整合測試任務 T032, T044, T053 已涵蓋關鍵 API 路徑。

---

## Unmapped Tasks

所有任務均已對應至需求或跨領域關注點，無孤立任務。

| Task | Purpose |
|------|---------|
| T001-T010 | 專案初始化（Setup） |
| T011-T028 | 基礎架構（Foundational） |
| T027a | IMemoryCache 設定（Constitution IV 替代方案）✨ 新增 |
| T029-T042 | US1 - 會員註冊 |
| T043-T051 | US2 - 驗證碼驗證 |
| T052-T058 | US3 - 重新發送 |
| T059-T062 | US4 - 未驗證登入 |
| T063-T065 | 背景工作 - 清理 |
| T066-T071 | Polish & QA |

---

## Metrics

| 指標 | 數值 | 說明 |
|------|------|------|
| Total Functional Requirements | 22 | FR-001 ~ FR-018（含子項） |
| Total Non-Functional Requirements | 5 | SC-001 ~ SC-005 |
| Total Tasks | 72 | T001 ~ T071 + T027a |
| Backend Coverage % | **86.4%** | 19/22 FR 有明確後端任務 |
| Overall Coverage % | **100%** | 所有 FR 已釐清責任歸屬 |
| Ambiguity Count | 2 | FR-012, CAPTCHA 服務 (LOW) |
| Duplication Count | 1 | FR-011/US4 (LOW，可接受) |
| Critical Issues Count | **0** | ⬇ from 1 |
| High Issues Count | **0** | ⬇ from 1 |
| Medium Issues Count | **1** | C1: US4 範圍調整 |
| Low Issues Count | **5** | 文件改進建議 |

---

## Comparison: analyze-02 vs analyze-03

| 指標 | analyze-02 | analyze-03 | 變化 |
|------|------------|------------|------|
| CRITICAL | 1 | 0 | 🟢 -1 |
| HIGH | 1 | 0 | 🟢 -1 |
| MEDIUM | 5 | 1 | 🟢 -4 |
| LOW | 3 | 5 | 🟡 +2 (新發現) |
| Coverage % | 77.3% | 86.4% (Backend) | 🟢 +9.1% |
| | | 100% (Overall) | 🟢 責任釐清 |

---

## Next Actions

### 🟢 可進行實作

所有 CRITICAL 和 HIGH 問題已解決，規格品質已達到實作標準。

### 建議改進（Optional）

1. **C1 - US4 任務範圍調整** (MEDIUM)
   - 修改 T060-T062 描述，明確說明為「狀態查詢 API」而非「登入驗證」
   - 新增假設：登入 API 將由 `002-member-login` 功能規格定義

2. **U1 - 密碼雜湊說明** (LOW)
   - 於 `data-model.md` 補充：「使用 ASP.NET Core Identity 的 `PasswordHasher<T>` 進行密碼雜湊」

3. **U2 - CAPTCHA 服務選型** (LOW)
   - 於 `research.md` 補充 CAPTCHA 服務比較（reCAPTCHA v3 / hCaptcha / Cloudflare Turnstile）

4. **G1 - 效能測試任務** (LOW)
   - 於 Phase 8 新增效能基準測試任務：驗證 API 回應時間 < 200ms (p95)

### 執行指令建議

若需處理 MEDIUM 級別問題：
```
手動編輯 tasks.md T060-T062 描述，限制範圍為狀態查詢
```

若直接進入實作：
```
/speckit.implement
```

---

## Remediation Offer

是否需要我針對以下 TOP 3 問題提供具體修正建議？

1. **C1**: 調整 US4 任務描述（T060-T062）
2. **U1**: 補充 data-model.md 密碼雜湊說明
3. **U2**: 補充 research.md CAPTCHA 選型

（請明確核准後我會提供具體編輯內容，本工具不會自動修改檔案）
