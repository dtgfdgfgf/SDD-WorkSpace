# Tasks: 會員註冊流程

**Input**: Design documents from `/specs/001-member-registration/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅

**Tests**: 本專案依據 Constitution II 要求，需達成 80% 測試覆蓋率及關鍵業務邏輯 100% 覆蓋。

**Organization**: 任務依使用者故事分組，以支援各故事的獨立實作與測試。

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: 可平行執行（不同檔案、無相依性）
- **[Story]**: 該任務所屬的使用者故事（如 US1, US2, US3, US4）
- 描述包含確切檔案路徑

## Path Conventions

- **專案結構**: `src/DuotifyMembership.*/`, `tests/DuotifyMembership.*/`
- 依據 plan.md 的 Clean Architecture 分層架構

---

## Phase 1: Setup (專案初始化)

**Purpose**: 專案結構建立與基本設定

- [ ] T001 建立 .NET 8.0 解決方案及專案結構 (DuotifyMembership.sln)
- [ ] T002 [P] 建立 DuotifyMembership.Api 專案於 src/DuotifyMembership.Api/
- [ ] T003 [P] 建立 DuotifyMembership.Core 專案於 src/DuotifyMembership.Core/
- [ ] T004 [P] 建立 DuotifyMembership.Infrastructure 專案於 src/DuotifyMembership.Infrastructure/
- [ ] T005 [P] 建立 DuotifyMembership.Jobs 專案於 src/DuotifyMembership.Jobs/
- [ ] T006 [P] 建立 DuotifyMembership.UnitTests 專案於 tests/DuotifyMembership.UnitTests/
- [ ] T007 [P] 建立 DuotifyMembership.IntegrationTests 專案於 tests/DuotifyMembership.IntegrationTests/
- [ ] T008 設定專案參考關係 (Api → Core, Infrastructure, Jobs; Infrastructure → Core; Jobs → Core)
- [ ] T009 [P] 安裝 NuGet 套件 (EF Core, xUnit, Moq, FluentAssertions, Swashbuckle)
- [ ] T010 [P] 設定 .editorconfig 與程式碼風格規範

---

## Phase 2: Foundational (基礎架構)

**Purpose**: 所有使用者故事所需的核心基礎設施

**⚠️ 關鍵**: 此階段完成前，無法開始任何使用者故事實作

- [ ] T011 建立 Member 實體於 src/DuotifyMembership.Core/Entities/Member.cs
- [ ] T012 [P] 建立 VerificationCode 實體於 src/DuotifyMembership.Core/Entities/VerificationCode.cs
- [ ] T013 建立 ApplicationDbContext 於 src/DuotifyMembership.Infrastructure/Data/ApplicationDbContext.cs
- [ ] T014 [P] 建立 MemberConfiguration 於 src/DuotifyMembership.Infrastructure/Data/Configurations/MemberConfiguration.cs
- [ ] T015 [P] 建立 VerificationCodeConfiguration 於 src/DuotifyMembership.Infrastructure/Data/Configurations/VerificationCodeConfiguration.cs
- [ ] T016 建立 EF Core Initial Migration 於 src/DuotifyMembership.Infrastructure/Migrations/
- [ ] T017 [P] 建立 IMemberRepository 介面於 src/DuotifyMembership.Core/Interfaces/IMemberRepository.cs
- [ ] T018 [P] 建立 IVerificationCodeRepository 介面於 src/DuotifyMembership.Core/Interfaces/IVerificationCodeRepository.cs
- [ ] T019 [P] 建立 IEmailService 介面於 src/DuotifyMembership.Core/Interfaces/IEmailService.cs
- [ ] T020 [P] 建立 ICaptchaValidator 介面於 src/DuotifyMembership.Core/Interfaces/ICaptchaValidator.cs
- [ ] T021 建立 MemberRepository 實作於 src/DuotifyMembership.Infrastructure/Repositories/MemberRepository.cs
- [ ] T022 [P] 建立 VerificationCodeRepository 實作於 src/DuotifyMembership.Infrastructure/Repositories/VerificationCodeRepository.cs
- [ ] T023 [P] 建立 EmailService 實作於 src/DuotifyMembership.Infrastructure/Services/EmailService.cs
- [ ] T024 [P] 建立 CaptchaValidator 實作於 src/DuotifyMembership.Infrastructure/Services/CaptchaValidator.cs
- [ ] T025 [P] 建立自訂例外類別於 src/DuotifyMembership.Core/Exceptions/ (DuplicateIdNumberException, DuplicateEmailException, VerificationCodeExpiredException, VerificationCodeInvalidException)
- [ ] T026 建立 ExceptionHandlingMiddleware 於 src/DuotifyMembership.Api/Middleware/ExceptionHandlingMiddleware.cs
- [ ] T027 設定 Program.cs 相依性注入與中介軟體於 src/DuotifyMembership.Api/Program.cs
- [ ] T027a [P] 設定 IMemoryCache 服務於 Program.cs（Constitution IV 替代方案）
- [ ] T028 設定 appsettings.json 資料庫連線與組態於 src/DuotifyMembership.Api/appsettings.json

**Checkpoint**: 基礎架構就緒，可開始實作使用者故事

---

## Phase 3: User Story 1 - 新會員完成基本資料填寫 (Priority: P1) MVP

**Goal**: 使用者可填寫身分證字號、姓名、E-Mail 及密碼完成註冊，系統建立待驗證帳號並發送驗證碼

**Independent Test**: 透過 POST /v1/members/register 送出有效資料，應建立會員並回傳 201

### Tests for User Story 1

- [ ] T029 [P] [US1] 建立 TaiwanIdValidatorTests 於 tests/DuotifyMembership.UnitTests/Validators/TaiwanIdValidatorTests.cs
- [ ] T030 [P] [US1] 建立 PasswordValidatorTests 於 tests/DuotifyMembership.UnitTests/Validators/PasswordValidatorTests.cs
- [ ] T031 [P] [US1] 建立 MemberServiceTests (RegisterAsync) 於 tests/DuotifyMembership.UnitTests/Services/MemberServiceTests.cs
- [ ] T032 [P] [US1] 建立 MemberControllerTests (Register) 於 tests/DuotifyMembership.IntegrationTests/Controllers/MemberControllerTests.cs

### Implementation for User Story 1

- [ ] T033 [P] [US1] 建立 TaiwanIdValidator 於 src/DuotifyMembership.Api/Validators/TaiwanIdValidator.cs (FR-002)
- [ ] T034 [P] [US1] 建立 PasswordValidator 於 src/DuotifyMembership.Api/Validators/PasswordValidator.cs (FR-004, FR-004a)
- [ ] T035 [P] [US1] 建立 RegisterMemberRequest DTO 於 src/DuotifyMembership.Api/DTOs/Requests/RegisterMemberRequest.cs
- [ ] T036 [P] [US1] 建立 RegisterMemberResponse DTO 於 src/DuotifyMembership.Api/DTOs/Responses/RegisterMemberResponse.cs
- [ ] T037 [P] [US1] 建立 ApiErrorResponse DTO 於 src/DuotifyMembership.Api/DTOs/Responses/ApiErrorResponse.cs
- [ ] T038 [US1] 建立 IMemberService 介面於 src/DuotifyMembership.Core/Interfaces/IMemberService.cs
- [ ] T039 [US1] 建立 MemberService.RegisterAsync 實作於 src/DuotifyMembership.Core/Services/MemberService.cs (FR-001, FR-001a, FR-003, FR-003a, FR-005)
- [ ] T040 [US1] 建立 MemberController.Register 端點於 src/DuotifyMembership.Api/Controllers/MemberController.cs (POST /v1/members/register)
- [ ] T041 [US1] 實作 CAPTCHA 驗證邏輯於 MemberService (FR-004b)
- [ ] T042 [US1] 實作密碼雜湊儲存於 MemberService (使用 PasswordHasher<T>)

**Checkpoint**: User Story 1 完成 - 會員可成功註冊並收到驗證碼

---

## Phase 4: User Story 2 - 完成 E-Mail 驗證碼驗證 (Priority: P1)

**Goal**: 使用者輸入正確的 6 位數驗證碼，帳號狀態變更為已驗證

**Independent Test**: 透過 POST /v1/members/{memberId}/verify-email 送出正確驗證碼，應回傳 200

### Tests for User Story 2

- [ ] T043 [P] [US2] 建立 VerificationServiceTests 於 tests/DuotifyMembership.UnitTests/Services/VerificationServiceTests.cs
- [ ] T044 [P] [US2] 建立 MemberControllerTests (VerifyEmail) 於 tests/DuotifyMembership.IntegrationTests/Controllers/MemberControllerTests.cs (擴充)

### Implementation for User Story 2

- [ ] T045 [P] [US2] 建立 VerifyEmailRequest DTO 於 src/DuotifyMembership.Api/DTOs/Requests/VerifyEmailRequest.cs
- [ ] T046 [P] [US2] 建立 VerifyEmailResponse DTO 於 src/DuotifyMembership.Api/DTOs/Responses/VerifyEmailResponse.cs
- [ ] T047 [US2] 建立 IVerificationService 介面於 src/DuotifyMembership.Core/Interfaces/IVerificationService.cs
- [ ] T048 [US2] 建立 VerificationService.VerifyCodeAsync 實作於 src/DuotifyMembership.Core/Services/VerificationService.cs (FR-006, FR-007, FR-008)
- [ ] T049 [US2] 建立 MemberController.VerifyEmail 端點於 src/DuotifyMembership.Api/Controllers/MemberController.cs (POST /v1/members/{memberId}/verify-email)
- [ ] T050 [US2] 實作驗證碼過期檢查邏輯 (5 分鐘有效期限)
- [ ] T051 [US2] 實作驗證碼使用後失效邏輯

**Checkpoint**: User Story 2 完成 - 會員可輸入驗證碼完成帳號驗證

---

## Phase 5: User Story 3 - 重新發送驗證碼 (Priority: P2)

**Goal**: 使用者可重新請求驗證碼，舊碼失效，需遵守 60 秒冷卻時間

**Independent Test**: 透過 POST /v1/members/{memberId}/resend-verification，應發送新驗證碼

### Tests for User Story 3

- [ ] T052 [P] [US3] 建立 VerificationServiceTests (ResendCode) 於 tests/DuotifyMembership.UnitTests/Services/VerificationServiceTests.cs (擴充)
- [ ] T053 [P] [US3] 建立 MemberControllerTests (ResendVerification) 於 tests/DuotifyMembership.IntegrationTests/Controllers/MemberControllerTests.cs (擴充)

### Implementation for User Story 3

- [ ] T054 [P] [US3] 建立 ResendVerificationResponse DTO 於 src/DuotifyMembership.Api/DTOs/Responses/ResendVerificationResponse.cs
- [ ] T055 [US3] 建立 VerificationService.ResendCodeAsync 實作於 src/DuotifyMembership.Core/Services/VerificationService.cs (FR-009, FR-010)
- [ ] T056 [US3] 建立 MemberController.ResendVerification 端點於 src/DuotifyMembership.Api/Controllers/MemberController.cs (POST /v1/members/{memberId}/resend-verification)
- [ ] T057 [US3] 實作 60 秒冷卻時間檢查邏輯
- [ ] T058 [US3] 實作舊驗證碼失效邏輯

**Checkpoint**: User Story 3 完成 - 會員可重新發送驗證碼

---

## Phase 6: User Story 4 - 會員驗證狀態查詢 (Priority: P2)

**Goal**: 提供 API 查詢會員驗證狀態，支援前端顯示功能受限提示

**Independent Test**: 透過 GET /v1/members/{memberId}/status，應回傳驗證狀態

**Note**: 登入 API 將由 `002-member-login` 功能規格定義，本 US4 僅實作狀態查詢 API

### Tests for User Story 4

- [ ] T059 [P] [US4] 建立 MemberServiceTests (GetMemberStatus) 於 tests/DuotifyMembership.UnitTests/Services/MemberServiceTests.cs (擴充)

### Implementation for User Story 4

- [ ] T060 [US4] 實作 MemberService.GetMemberStatusAsync 方法 — 查詢會員驗證狀態
- [ ] T061 [US4] 建立 MemberController.GetStatus 端點 (GET /v1/members/{memberId}/status) — 回應包含 IsEmailVerified 狀態欄位
- [ ] T062 [US4] 新增狀態相關錯誤訊息常數「請完成 E-Mail 驗證以使用完整功能」「此功能需要完成 E-Mail 驗證」

**Checkpoint**: User Story 4 完成 - 可查詢會員驗證狀態

---

## Phase 7: 背景工作 - 未驗證帳號清理 (Cross-Cutting)

**Purpose**: 7 天後自動清除未完成驗證的帳號

- [ ] T063 [P] 建立 CleanupUnverifiedMembersJobTests 於 tests/DuotifyMembership.UnitTests/Jobs/CleanupUnverifiedMembersJobTests.cs
- [ ] T064 建立 CleanupUnverifiedMembersJob 於 src/DuotifyMembership.Jobs/CleanupUnverifiedMembersJob.cs (FR-018)
- [ ] T065 註冊 BackgroundService 於 Program.cs

**Checkpoint**: 背景工作完成 - 系統自動清理過期未驗證帳號

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: 跨故事的改進與品質強化

- [ ] T066 [P] 補充 XML 文件註解於所有公開 API 方法
- [ ] T067 [P] 設定 Swagger/OpenAPI 文件產生 (Swashbuckle)
- [ ] T068 [P] 新增 API 回應的繁體中文錯誤訊息資源檔
- [ ] T069 程式碼清理與重構
- [ ] T070 [P] 執行 quickstart.md 驗證
- [ ] T071 確認測試覆蓋率達到 80% 以上

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: 無相依性 - 可立即開始
- **Foundational (Phase 2)**: 相依 Setup 完成 - **阻擋所有使用者故事**
- **User Stories (Phase 3-6)**: 相依 Foundational 完成
  - User Story 1 & 2 為 P1，應優先完成
  - User Story 3 & 4 為 P2，可延後
- **背景工作 (Phase 7)**: 相依 Phase 2，可與 User Stories 平行
- **Polish (Phase 8)**: 相依所有功能完成

### User Story Dependencies

- **User Story 1 (P1)**: Phase 2 完成後可開始 - 無其他故事相依
- **User Story 2 (P1)**: 需 US1 的 Member 建立邏輯存在
- **User Story 3 (P2)**: 需 US2 的驗證碼機制存在
- **User Story 4 (P2)**: 需 US1 的會員存在

### Within Each User Story

- 測試 MUST 先撰寫並確認 FAIL
- 實作順序: Entity, then Repository, then Service, then Controller
- 核心實作完成後再處理整合

### Parallel Opportunities

- Phase 1: T002-T007, T009-T010 可平行
- Phase 2: T011-T012, T014-T015, T017-T025 可平行
- 各 User Story 的測試可平行撰寫
- Phase 7 可與 Phase 3-6 平行

---

## Parallel Example: Phase 2 Foundational

```bash
# 可平行執行的實體與設定
Task: T011 建立 Member 實體
Task: T012 建立 VerificationCode 實體 [P]
Task: T014 建立 MemberConfiguration [P]
Task: T015 建立 VerificationCodeConfiguration [P]

# 可平行執行的介面
Task: T017 建立 IMemberRepository [P]
Task: T018 建立 IVerificationCodeRepository [P]
Task: T019 建立 IEmailService [P]
Task: T020 建立 ICaptchaValidator [P]
```

---

## Implementation Strategy

### MVP First (User Story 1 + 2)

1. 完成 Phase 1: Setup
2. 完成 Phase 2: Foundational (關鍵 - 阻擋所有故事)
3. 完成 Phase 3: User Story 1 (會員註冊)
4. 完成 Phase 4: User Story 2 (驗證碼驗證)
5. **驗證**: 測試 US1 + US2 可獨立運作
6. 部署/展示 MVP

### Incremental Delivery

1. Setup + Foundational: 基礎就緒
2. User Story 1: 測試, 部署 (MVP - 可註冊)
3. User Story 2: 測試, 部署 (可驗證)
4. User Story 3: 測試, 部署 (可重送)
5. User Story 4: 測試, 部署 (登入受限)
6. Phase 7: 背景清理上線

---

## Notes

- [P] 任務 = 不同檔案、無相依性，可平行執行
- [Story] 標籤將任務對應至特定使用者故事
- 每個使用者故事應可獨立完成並測試
- 實作前先驗證測試失敗
- 每個任務或邏輯群組完成後應提交
- 任何 checkpoint 都可停下來驗證
- 避免: 模糊任務、同檔案衝突、破壞獨立性的跨故事相依
