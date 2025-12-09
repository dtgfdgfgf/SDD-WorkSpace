# Specification Analysis Report

**功能分支**: `001-member-registration`  
**分析日期**: 2025-12-02  
**分析範圍**: spec.md, plan.md, tasks.md

---

## 發現摘要

| ID | Category | Severity | Location(s) | Summary | Recommendation |
|----|----------|----------|-------------|---------|----------------|
| A1 | Ambiguity | MEDIUM | spec.md:FR-012 | 「限制部分功能」未明確定義哪些功能受限 | 於 spec.md 新增受限功能清單或說明由後續規格定義 |
| A2 | Underspecification | MEDIUM | spec.md:FR-001b | 「失焦驗證」為前端行為，但專案為純後端 API | 移除 FR-001b 或標註為前端實作責任 |
| A3 | Underspecification | MEDIUM | spec.md:FR-007, FR-013 | 「驗證碼輸入介面」、「註冊流程單向」為 UI 概念，與純後端 API 範圍衝突 | 重新定義為 API 行為規格或標註為前端責任 |
| A4 | Coverage Gap | MEDIUM | tasks.md:US4 | US4「未驗證會員登入受限」無完整登入 API 任務，僅有 GetMemberStatusAsync | 新增登入 API 端點任務或明確說明登入由其他功能規格實作 |
| A5 | Inconsistency | LOW | plan.md, tasks.md | plan.md 列出 ResendVerificationRequest.cs，但 tasks.md 無此 DTO 建立任務 | 新增 T054a 或確認此 DTO 不需要（使用路徑參數） |
| A6 | Inconsistency | LOW | plan.md, tasks.md | plan.md Exceptions/ 列 3 個例外，tasks.md T025 列 4 個（多 VerificationCodeInvalidException） | 統一例外類別清單 |
| A7 | Underspecification | LOW | spec.md:邊界情況 | 「密碼欄位包含特殊字元」未定義可接受的特殊字元範圍 | 明確列出允許或禁止的特殊字元 |
| A8 | Coverage Gap | LOW | tasks.md | 無 E2E 測試任務，Constitution II 要求關鍵用戶旅程需有 E2E 測試 | 評估是否需要新增 E2E 測試任務 |

---

## Coverage Summary Table

| Requirement Key | Has Task? | Task IDs | Notes |
|-----------------|-----------|----------|-------|
| FR-001 (註冊表單) | ✅ | T035, T039, T040 | RegisterMemberRequest, MemberService, MemberController |
| FR-001a (輸入標準化) | ✅ | T039 | MemberService.RegisterAsync |
| FR-001b (失焦驗證) | ⚠️ | - | 前端行為，純後端無法實作 |
| FR-002 (身分證驗證) | ✅ | T033, T029 | TaiwanIdValidator + 測試 |
| FR-003 (身分證唯一) | ✅ | T039 | MemberService 重複檢查 |
| FR-003a (E-Mail 唯一) | ✅ | T039 | MemberService 重複檢查 |
| FR-004 (密碼規則) | ✅ | T034, T030 | PasswordValidator + 測試 |
| FR-004a (密碼確認) | ✅ | T034 | PasswordValidator |
| FR-004b (CAPTCHA) | ✅ | T020, T024, T041 | ICaptchaValidator, CaptchaValidator, MemberService |
| FR-005 (發送驗證碼) | ✅ | T019, T023, T039 | IEmailService, EmailService, MemberService |
| FR-006 (5 分鐘有效) | ✅ | T050 | VerificationService |
| FR-007 (驗證碼輸入介面) | ⚠️ | - | 前端 UI，後端僅提供 API |
| FR-008 (更新已驗證) | ✅ | T048, T051 | VerificationService.VerifyCodeAsync |
| FR-009 (重送驗證碼) | ✅ | T055, T058 | VerificationService.ResendCodeAsync |
| FR-010 (60 秒冷卻) | ✅ | T057 | 冷卻時間檢查 |
| FR-011 (未驗證可登入) | ⚠️ | T060 | GetMemberStatusAsync，但無完整登入 API |
| FR-012 (功能受限) | ⚠️ | T061, T062 | 僅回傳狀態，未定義受限功能 |
| FR-013 (單向流程) | ⚠️ | - | 前端 UI 行為 |
| FR-014 (不自動登入) | ⚠️ | - | 前端行為 |
| FR-015 (無社群註冊) | ✅ | - | 排除性需求，無需任務 |
| FR-016 (無密碼強度提示) | ✅ | - | 排除性需求，無需任務 |
| FR-017 (無連結驗證) | ✅ | - | 排除性需求，無需任務 |
| FR-018 (7 天清理) | ✅ | T064, T065 | CleanupUnverifiedMembersJob |

---

## Constitution Alignment Issues

| Principle | Issue | Severity |
|-----------|-------|----------|
| Constitution IV (Scalability) | plan.md 約束「無 Redis」，但 Constitution IV 要求「Caching strategy (Redis) required for frequently accessed data」 | **CRITICAL** |
| Constitution II (E2E Testing) | tasks.md 無 E2E 測試任務，Constitution II 要求「Critical user journeys MUST have automated E2E tests」 | HIGH |
| Constitution IV (Monitoring) | plan.md 列「監控與告警 ⏳ 待規劃」但無對應 tasks.md 任務 | MEDIUM |

---

## Unmapped Tasks

| Task ID | Description | Issue |
|---------|-------------|-------|
| T010 | 設定 .editorconfig 與程式碼風格規範 | 無對應 spec/plan 需求，但為良好實踐 ✅ |
| T066 | 補充 XML 文件註解 | 支援 Constitution I，可接受 ✅ |
| T067 | Swagger/OpenAPI 文件 | 支援 API 文件化，可接受 ✅ |
| T068 | 繁體中文錯誤訊息資源檔 | 支援 Constitution V，可接受 ✅ |
| T069 | 程式碼清理與重構 | 一般性任務，可接受 ✅ |
| T070 | quickstart.md 驗證 | 文件驗證，可接受 ✅ |
| T071 | 確認測試覆蓋率 | 支援 Constitution II，可接受 ✅ |

---

## Metrics

| 指標 | 數值 |
|------|------|
| Total Requirements | 22 (FR-001 ~ FR-018 含子項) |
| Total Tasks | 71 |
| Requirements with ≥1 Task | 17 (77.3%) |
| Requirements without Direct Coverage | 5 (22.7%) |
| Ambiguity Count | 2 |
| Underspecification Count | 4 |
| Coverage Gap Count | 2 |
| Inconsistency Count | 2 |
| **Critical Issues Count** | **1** |
| High Issues Count | 1 |
| Medium Issues Count | 5 |
| Low Issues Count | 3 |

---

## Critical Issue Detail

### C1: Constitution IV Caching Conflict

**位置**: `.specify/memory/constitution.md` (IV. Performance Requirements) vs `checklists/tech-spec.md`

**問題**: 
- Constitution IV 明確要求：「Caching strategy (Redis) required for frequently accessed data」
- tech-spec.md 明確約束：「I don't want to use Redis」
- 這是 Constitution MUST 原則與專案約束的直接衝突

**影響**: 依據 Constitution Authority，constitution 原則優先於其他標準。但使用者明確排除 Redis，需要解決此衝突。

**建議解決方案**:
1. **Option A**: 在 plan.md Complexity Tracking 中明確記錄此違規，說明本專案規模（10,000 使用者）不需要 Redis 快取
2. **Option B**: 修改 Constitution IV 允許例外情況（需走 Amendment Process）
3. **Option C**: 採用其他快取策略（如 In-Memory Cache）替代 Redis

---

## Next Actions

### 若有 CRITICAL 問題:

1. ⚠️ **解決 Constitution IV 快取衝突** - 在 plan.md Complexity Tracking 中新增違規說明，記錄為何不使用 Redis（專案規模小、複雜度考量）
2. 考慮使用 `IMemoryCache` 作為替代方案，符合精神但不引入 Redis

### 若僅有 LOW/MEDIUM 問題:

1. **A1 (FR-012)**: 於 spec.md Clarifications 新增說明「受限功能範圍將由後續功能規格定義」
2. **A2, A3 (前端行為需求)**: 於 spec.md 新增 Scope 章節，明確標註 FR-001b, FR-007, FR-013, FR-014 為前端實作責任
3. **A4 (US4 登入 API)**: 於 spec.md 假設章節新增「登入功能將由獨立功能規格定義」
4. **A5, A6 (不一致)**: 同步 plan.md 與 tasks.md 的例外類別清單
5. **A8 (E2E 測試)**: 評估是否需要新增 E2E 測試任務，或在 Complexity Tracking 中說明本階段僅實作單元/整合測試

### 建議的 /speckit.clarify 問題:

1. 專案是否需要 Redis 或其他快取機制？（若否，請確認違反 Constitution IV 的理由）
2. 登入功能是否屬於本功能規格範圍？或由後續規格定義？
3. 前端行為相關的需求（FR-001b, FR-007, FR-013, FR-014）應如何處理？

---

## Remediation Offer

是否需要我針對前 3 項問題提供具體的修正建議？（不會自動套用，需您確認後手動執行）
