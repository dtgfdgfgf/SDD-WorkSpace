# Duotify Membership System - 會員註冊功能

會員管理系統的註冊與驗證模組，採用 Clean Architecture 設計。

## 🚀 快速開始

### 前置需求
- .NET 8.0 SDK 或更高版本
- SQL Server (LocalDB 或完整版)
- Visual Studio 2022 或 VS Code

### 1. 還原套件
```bash
dotnet restore
```

### 2. 建立資料庫
```bash
cd src/DuotifyMembership.Infrastructure
dotnet ef migrations add InitialCreate --startup-project ../DuotifyMembership.Api
dotnet ef database update --startup-project ../DuotifyMembership.Api
```

### 3. 執行測試
```bash
dotnet test
```

### 4. 啟動 API
```bash
cd src/DuotifyMembership.Api
dotnet run
```

應用程式將在 `https://localhost:5001` 和 `http://localhost:5000` 啟動。

## 📋 API 端點

### 會員註冊
```http
POST /v1/members/register
Content-Type: application/json

{
  "idNumber": "A123456789",
  "name": "王小明",
  "email": "user@example.com",
  "password": "Password123",
  "captchaToken": "captcha-token"
}
```

### 驗證 E-Mail
```http
POST /v1/members/{memberId}/verify-email
Content-Type: application/json

{
  "code": "123456"
}
```

### 重新發送驗證碼
```http
POST /v1/members/{memberId}/resend-verification
```

### 查詢會員狀態
```http
GET /v1/members/{memberId}/status
```

## 🏗️ 專案結構

```
duotify-membership-v1/
├── src/
│   ├── DuotifyMembership.Api/          # Web API 層
│   ├── DuotifyMembership.Core/         # 核心業務邏輯
│   ├── DuotifyMembership.Infrastructure/ # 資料存取
│   └── DuotifyMembership.Jobs/         # 背景任務
├── tests/
│   ├── DuotifyMembership.UnitTests/    # 單元測試
│   └── DuotifyMembership.IntegrationTests/ # 整合測試
└── specs/
    └── 001-member-registration/        # 功能規格文件
```

## 🧪 測試

執行所有測試:
```bash
dotnet test
```

執行特定測試專案:
```bash
dotnet test tests/DuotifyMembership.UnitTests
```

## 📦 使用的套件

- **Entity Framework Core 10.0**: 資料存取
- **xUnit**: 測試框架
- **Moq**: Mock 框架
- **FluentAssertions**: 測試斷言
- **ASP.NET Core Identity**: 密碼雜湊

## 🔐 安全性

- 密碼使用 ASP.NET Core Identity 的 PasswordHasher 進行雜湊
- 驗證碼 5 分鐘有效期限
- 重新發送驗證碼有 60 秒冷卻時間
- CAPTCHA 驗證防止機器人註冊
- 身分證字號與 E-Mail 唯一性檢查

## ⚙️ 設定

編輯 `src/DuotifyMembership.Api/appsettings.json`:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=(localdb)\\mssqllocaldb;Database=DuotifyMembership;..."
  },
  "VerificationCode": {
    "ExpirationMinutes": 5,
    "ResendCooldownSeconds": 60
  }
}
```

## 📝 功能特色

- ✅ 會員註冊 (身分證字號 + 姓名 + E-Mail + 密碼)
- ✅ E-Mail 驗證碼驗證
- ✅ 重新發送驗證碼 (60 秒冷卻)
- ✅ 會員驗證狀態查詢
- ✅ 7 天自動清理未驗證帳號
- ✅ 台灣身分證字號格式驗證
- ✅ 密碼強度驗證 (8+ 字元, 大小寫+數字)
- ✅ CAPTCHA 驗證
- ✅ 集中式例外處理

## 📖 更多文件

- [實作狀態](./IMPLEMENTATION_STATUS.md)
- [功能規格](./specs/001-member-registration/spec.md)
- [實作計畫](./specs/001-member-registration/plan.md)
- [任務清單](./specs/001-member-registration/tasks.md)

## 🤝 貢獻

請參考 [Constitution](./specs/001-member-registration/constitution.md) 了解開發原則。

## 📄 授權

此專案為私有專案。
