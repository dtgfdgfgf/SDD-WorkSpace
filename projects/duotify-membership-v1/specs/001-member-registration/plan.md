````markdown
# Implementation Plan: 會員註冊流程

**Branch**: `001-member-registration` | **Date**: 2025-12-01 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-member-registration/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

建立一個安全、完整的會員註冊流程 REST API，支援身分證字號、姓名、E-Mail 及密碼收集，並透過 6 位數驗證碼完成 E-Mail 驗證。使用 ASP.NET Core 8.0 Web API 搭配 SQL Server 與 EF Core Code First，遵循 Controller/Service/Repository 分層架構。

## Technical Context

**Language/Version**: C# 12 / .NET 8.0  
**Primary Dependencies**: ASP.NET Core 8.0 Web API, Entity Framework Core 8.0, SQL Server  
**Storage**: SQL Server (使用 EF Core Code First 建立資料表)  
**Testing**: xUnit, Moq, FluentAssertions  
**Target Platform**: Windows/Linux Server (Backend REST API only)
**Project Type**: single (純後端 API，無前端)  
**Performance Goals**: API 回應時間 < 200ms (p95)，支援 1000 concurrent users  
**Constraints**: 無 AutoMapper (使用 POCO 手動映射)、無 Redis、無 Minimal APIs、純後端無前端  
**Scale/Scope**: 會員註冊模組，預估初期 10,000 使用者

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Pre-Development Gates

| 驗證項目 | 狀態 | 說明 |
|----------|------|------|
| 功能規格已核准並有明確驗收條件 | ✅ PASS | spec.md 包含 4 個使用者故事及 22+ 功能需求 |
| 技術設計符合架構準則 | ✅ PASS | 採用 Controller/Service/Repository 分層架構 |
| 關鍵路徑效能影響評估 | ✅ PASS | API 回應時間目標 < 200ms (p95) |

### Code Quality (Constitution I)

| 驗證項目 | 狀態 | 說明 |
|----------|------|------|
| 命名規範 (PascalCase/camelCase) | ⏳ 待實作驗證 | C# 命名慣例將於實作階段遵循 |
| 公開 API 文件 (XML Comments) | ⏳ 待實作驗證 | 所有公開 API 需有 XML 文件註解 |
| DI 相依性注入 | ⏳ 待實作驗證 | 所有 Service 將使用建構函式注入 |
| 不直接從 Controller 存取資料庫 | ✅ PASS | 透過 Service/Repository 層存取 |

### Testing Standards (Constitution II)

| 驗證項目 | 狀態 | 說明 |
|----------|------|------|
| 單元測試覆蓋率 ≥ 80% | ⏳ 待實作驗證 | 將使用 xUnit + Moq 達成 |
| 關鍵業務邏輯 100% 覆蓋 | ⏳ 待實作驗證 | 密碼驗證、身分證驗證、驗證碼邏輯 |
| API 端點整合測試 | ⏳ 待實作驗證 | Happy path + error cases + edge cases |
| 測試命名: should_[expected]_when_[condition] | ⏳ 待實作驗證 | 測試命名規範 |

### User Experience Consistency (Constitution III)

| 驗證項目 | 狀態 | 說明 |
|----------|------|------|
| WCAG 2.1 Level AA | ⚠️ N/A | 純後端 API，無 UI 實作 |
| 錯誤訊息需可操作 | ⏳ 待實作驗證 | API 回應需包含明確的錯誤訊息與狀態碼 |
| 即時回饋 (Loading/Success/Error) | ⚠️ N/A | 純後端 API，由前端處理 |

### Performance Requirements (Constitution IV)

| 驗證項目 | 狀態 | 說明 |
|----------|------|------|
| API GET < 200ms (p95) | ⏳ 待實作驗證 | 需實作效能測試 |
| API POST/PUT/DELETE < 500ms (p95) | ⏳ 待實作驗證 | 註冊 API 目標 < 500ms |
| 資料庫查詢最佳化 (Index) | ⏳ 待設計 | IdNumber, Email 欄位需建立索引 |
| 監控與告警 | ⏳ 待規劃 | 關鍵路徑效能監控 |

### Language and Localization (Constitution V)

| 驗證項目 | 狀態 | 說明 |
|----------|------|------|
| 規格文件使用繁體中文 (zh-TW) | ✅ PASS | spec.md, plan.md 均為繁體中文 |
| API 錯誤訊息使用繁體中文 | ⏳ 待實作驗證 | 所有使用者可見錯誤需繁體中文 |
| 程式碼識別符使用英文 | ⏳ 待實作驗證 | 變數、函式、類別名稱使用英文 |

## Project Structure

### Documentation (this feature)

```text
specs/001-member-registration/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output - 技術研究與決策
├── data-model.md        # Phase 1 output - 資料模型設計
├── quickstart.md        # Phase 1 output - 快速開始指南
├── contracts/           # Phase 1 output - API 契約
│   └── openapi.yaml     # OpenAPI 3.0 規格
├── checklists/          # 品質檢查清單
│   ├── requirements.md
│   ├── quality.md
│   └── tech-spec.md
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
src/
├── DuotifyMembership.Api/              # ASP.NET Core Web API 專案
│   ├── Controllers/
│   │   └── MemberController.cs         # 會員相關 API 端點
│   ├── DTOs/
│   │   ├── Requests/
│   │   │   ├── RegisterMemberRequest.cs
│   │   │   ├── VerifyEmailRequest.cs
│   │   │   └── ResendVerificationRequest.cs
│   │   └── Responses/
│   │       ├── RegisterMemberResponse.cs
│   │       ├── VerifyEmailResponse.cs
│   │       └── ApiErrorResponse.cs
│   ├── Validators/
│   │   ├── TaiwanIdValidator.cs        # 台灣身分證驗證
│   │   └── PasswordValidator.cs        # 密碼規則驗證
│   ├── Middleware/
│   │   └── ExceptionHandlingMiddleware.cs
│   └── Program.cs
│
├── DuotifyMembership.Core/             # 核心業務邏輯
│   ├── Entities/
│   │   ├── Member.cs                   # 會員實體
│   │   └── VerificationCode.cs         # 驗證碼實體
│   ├── Interfaces/
│   │   ├── IMemberService.cs
│   │   ├── IVerificationService.cs
│   │   ├── IEmailService.cs
│   │   ├── IMemberRepository.cs
│   │   └── IVerificationCodeRepository.cs
│   ├── Services/
│   │   ├── MemberService.cs            # 會員業務邏輯
│   │   └── VerificationService.cs      # 驗證碼業務邏輯
│   └── Exceptions/
│       ├── DuplicateIdNumberException.cs
│       ├── DuplicateEmailException.cs
│       └── VerificationCodeExpiredException.cs
│
├── DuotifyMembership.Infrastructure/   # 基礎設施層
│   ├── Data/
│   │   ├── ApplicationDbContext.cs     # EF Core DbContext
│   │   └── Configurations/
│   │       ├── MemberConfiguration.cs
│   │       └── VerificationCodeConfiguration.cs
│   ├── Repositories/
│   │   ├── MemberRepository.cs
│   │   └── VerificationCodeRepository.cs
│   ├── Services/
│   │   └── EmailService.cs             # E-Mail 發送服務實作
│   └── Migrations/                     # EF Core Migrations
│
└── DuotifyMembership.Jobs/             # 背景工作
    └── CleanupUnverifiedMembersJob.cs  # 7 天未驗證帳號清理

tests/
├── DuotifyMembership.UnitTests/        # 單元測試
│   ├── Validators/
│   │   ├── TaiwanIdValidatorTests.cs
│   │   └── PasswordValidatorTests.cs
│   └── Services/
│       ├── MemberServiceTests.cs
│       └── VerificationServiceTests.cs
│
└── DuotifyMembership.IntegrationTests/ # 整合測試
    └── Controllers/
        └── MemberControllerTests.cs
```

**Structure Decision**: 採用 Clean Architecture 分層架構，分為 API 層、Core 層（業務邏輯）、Infrastructure 層（資料存取與外部服務）。使用 Controller-based API（非 Minimal APIs）以符合技術約束。

## Complexity Tracking

> **Constitution Check 違規說明**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Constitution IV: 無 Redis 快取 | 專案規模小（初期 10,000 使用者），無高頻快取需求 | Redis 增加維運複雜度，改用 ASP.NET Core 內建 `IMemoryCache` 作為輕量替代方案 |
| Constitution II: 無 E2E 測試 | 純後端 API 專案，無前端整合 | 整合測試已覆蓋 API 端點，E2E 測試需前端環境配合，延後至前端開發時實作 |

**替代方案**:
- **快取**: 使用 `IMemoryCache` 快取 CAPTCHA 驗證結果與驗證碼冷卻時間檢查
- **E2E 測試**: 以整合測試 (`MemberControllerTests`) 覆蓋關鍵 API 路徑，待前端開發時補充 E2E

---

*以下為 Phase 0 及 Phase 1 產出物*

````
