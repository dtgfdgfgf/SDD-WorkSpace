# 快速開始指南：會員註冊流程

**功能分支**: `001-member-registration`  
**建立日期**: 2025-12-01  
**Phase**: 1 - Design

---

## 概述

本文件提供會員註冊功能的快速開發指南，協助開發人員快速上手專案。

---

## 環境需求

### 必要軟體

| 軟體 | 版本 | 說明 |
|------|------|------|
| .NET SDK | 8.0+ | [下載連結](https://dotnet.microsoft.com/download/dotnet/8.0) |
| SQL Server | 2019+ | LocalDB 或完整版本皆可 |
| Visual Studio 2022 / VS Code | 最新版 | 推薦使用 Visual Studio |
| Git | 2.x | 版本控制 |

### 可選軟體

| 軟體 | 用途 |
|------|------|
| SQL Server Management Studio (SSMS) | 資料庫管理 |
| Postman / Insomnia | API 測試 |
| Azure Data Studio | 跨平台資料庫工具 |

---

## 快速開始

### 1. 複製專案

```powershell
git clone <repository-url>
cd duotify-membership-v1
git checkout 001-member-registration
```

### 2. 建立專案結構

```powershell
# 建立解決方案
dotnet new sln -n DuotifyMembership

# 建立 API 專案
dotnet new webapi -n DuotifyMembership.Api -o src/DuotifyMembership.Api
dotnet sln add src/DuotifyMembership.Api

# 建立 Core 專案（類別庫）
dotnet new classlib -n DuotifyMembership.Core -o src/DuotifyMembership.Core
dotnet sln add src/DuotifyMembership.Core

# 建立 Infrastructure 專案（類別庫）
dotnet new classlib -n DuotifyMembership.Infrastructure -o src/DuotifyMembership.Infrastructure
dotnet sln add src/DuotifyMembership.Infrastructure

# 建立 Jobs 專案（類別庫）
dotnet new classlib -n DuotifyMembership.Jobs -o src/DuotifyMembership.Jobs
dotnet sln add src/DuotifyMembership.Jobs

# 建立單元測試專案
dotnet new xunit -n DuotifyMembership.UnitTests -o tests/DuotifyMembership.UnitTests
dotnet sln add tests/DuotifyMembership.UnitTests

# 建立整合測試專案
dotnet new xunit -n DuotifyMembership.IntegrationTests -o tests/DuotifyMembership.IntegrationTests
dotnet sln add tests/DuotifyMembership.IntegrationTests
```

### 3. 設定專案參考

```powershell
# API -> Core, Infrastructure, Jobs
dotnet add src/DuotifyMembership.Api reference src/DuotifyMembership.Core
dotnet add src/DuotifyMembership.Api reference src/DuotifyMembership.Infrastructure
dotnet add src/DuotifyMembership.Api reference src/DuotifyMembership.Jobs

# Infrastructure -> Core
dotnet add src/DuotifyMembership.Infrastructure reference src/DuotifyMembership.Core

# Jobs -> Core
dotnet add src/DuotifyMembership.Jobs reference src/DuotifyMembership.Core

# 測試專案參考
dotnet add tests/DuotifyMembership.UnitTests reference src/DuotifyMembership.Core
dotnet add tests/DuotifyMembership.UnitTests reference src/DuotifyMembership.Api
dotnet add tests/DuotifyMembership.IntegrationTests reference src/DuotifyMembership.Api
```

### 4. 安裝 NuGet 套件

```powershell
# Infrastructure 專案
dotnet add src/DuotifyMembership.Infrastructure package Microsoft.EntityFrameworkCore.SqlServer --version 8.0.*
dotnet add src/DuotifyMembership.Infrastructure package Microsoft.EntityFrameworkCore.Design --version 8.0.*

# API 專案
dotnet add src/DuotifyMembership.Api package Microsoft.AspNetCore.Identity --version 8.0.*
dotnet add src/DuotifyMembership.Api package Swashbuckle.AspNetCore --version 6.*

# 測試專案
dotnet add tests/DuotifyMembership.UnitTests package Moq --version 4.*
dotnet add tests/DuotifyMembership.UnitTests package FluentAssertions --version 6.*
dotnet add tests/DuotifyMembership.IntegrationTests package Microsoft.AspNetCore.Mvc.Testing --version 8.0.*
dotnet add tests/DuotifyMembership.IntegrationTests package Microsoft.EntityFrameworkCore.InMemory --version 8.0.*
```

### 5. 設定資料庫連線

編輯 `src/DuotifyMembership.Api/appsettings.Development.json`：

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=(localdb)\\mssqllocaldb;Database=DuotifyMembership;Trusted_Connection=True;MultipleActiveResultSets=true"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "Captcha": {
    "SiteKey": "YOUR_RECAPTCHA_SITE_KEY",
    "SecretKey": "YOUR_RECAPTCHA_SECRET_KEY"
  },
  "Email": {
    "SmtpHost": "localhost",
    "SmtpPort": 25,
    "FromAddress": "noreply@example.com"
  }
}
```

### 6. 建立資料庫

```powershell
# 建立初始 Migration
dotnet ef migrations add InitialCreate -p src/DuotifyMembership.Infrastructure -s src/DuotifyMembership.Api

# 更新資料庫
dotnet ef database update -p src/DuotifyMembership.Infrastructure -s src/DuotifyMembership.Api
```

### 7. 執行專案

```powershell
# 執行 API
dotnet run --project src/DuotifyMembership.Api

# API 將在 https://localhost:5001 執行
# Swagger UI: https://localhost:5001/swagger
```

---

## 專案結構說明

```text
DuotifyMembership/
├── src/
│   ├── DuotifyMembership.Api/          # Web API 入口點
│   │   ├── Controllers/                 # API 控制器
│   │   ├── DTOs/                        # 請求/回應 DTO
│   │   ├── Validators/                  # 驗證器（身分證、密碼）
│   │   └── Middleware/                  # 中介軟體
│   │
│   ├── DuotifyMembership.Core/         # 核心業務邏輯
│   │   ├── Entities/                    # 實體類別
│   │   ├── Interfaces/                  # 服務介面
│   │   ├── Services/                    # 業務服務實作
│   │   └── Exceptions/                  # 自訂例外
│   │
│   ├── DuotifyMembership.Infrastructure/ # 基礎設施
│   │   ├── Data/                        # EF Core DbContext
│   │   ├── Repositories/                # Repository 實作
│   │   ├── Services/                    # 外部服務實作（Email）
│   │   └── Migrations/                  # 資料庫遷移
│   │
│   └── DuotifyMembership.Jobs/         # 背景工作
│       └── CleanupUnverifiedMembersJob.cs
│
├── tests/
│   ├── DuotifyMembership.UnitTests/    # 單元測試
│   └── DuotifyMembership.IntegrationTests/ # 整合測試
│
└── specs/
    └── 001-member-registration/         # 功能規格文件
```

---

## 開發工作流程

### TDD 開發流程

1. **紅燈**: 先寫失敗的測試
2. **綠燈**: 寫最少程式碼使測試通過
3. **重構**: 改善程式碼品質

### 命名規範

| 類型 | 規範 | 範例 |
|------|------|------|
| 類別 | PascalCase | `MemberService` |
| 介面 | I + PascalCase | `IMemberService` |
| 方法 | PascalCase | `RegisterAsync` |
| 變數 | camelCase | `memberId` |
| 常數 | UPPER_SNAKE_CASE | `MAX_PASSWORD_LENGTH` |
| 私有欄位 | _camelCase | `_memberRepository` |

### 測試命名

```csharp
[Fact]
public async Task should_create_member_when_valid_data_provided()
{
    // Arrange
    // Act
    // Assert
}
```

---

## API 端點一覽

| 方法 | 路徑 | 說明 |
|------|------|------|
| POST | `/v1/members/register` | 會員註冊 |
| POST | `/v1/members/{memberId}/verify-email` | 驗證 E-Mail |
| POST | `/v1/members/{memberId}/resend-verification` | 重送驗證碼 |

詳細 API 規格請參考 `contracts/openapi.yaml`。

---

## 常見問題

### Q: 如何重置資料庫？

```powershell
dotnet ef database drop -p src/DuotifyMembership.Infrastructure -s src/DuotifyMembership.Api
dotnet ef database update -p src/DuotifyMembership.Infrastructure -s src/DuotifyMembership.Api
```

### Q: 如何執行測試？

```powershell
# 執行所有測試
dotnet test

# 執行特定測試專案
dotnet test tests/DuotifyMembership.UnitTests

# 產生覆蓋率報告
dotnet test --collect:"XPlat Code Coverage"
```

### Q: 如何新增 EF Core Migration？

```powershell
dotnet ef migrations add <MigrationName> -p src/DuotifyMembership.Infrastructure -s src/DuotifyMembership.Api
```

---

## 相關文件

| 文件 | 說明 |
|------|------|
| [spec.md](./spec.md) | 功能規格 |
| [plan.md](./plan.md) | 實作計畫 |
| [research.md](./research.md) | 技術研究 |
| [data-model.md](./data-model.md) | 資料模型 |
| [contracts/openapi.yaml](./contracts/openapi.yaml) | API 契約 |
| [checklists/quality.md](./checklists/quality.md) | 品質檢查清單 |
