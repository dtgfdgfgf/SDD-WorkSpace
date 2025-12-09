# 技術研究報告：會員註冊流程

**功能分支**: `001-member-registration`  
**建立日期**: 2025-12-01  
**Phase**: 0 - Research

---

## 研究摘要

本文件記錄會員註冊流程功能開發前的技術研究與決策，解決所有 Technical Context 中的 NEEDS CLARIFICATION 項目。

---

## 研究項目

### 1. 密碼雜湊演算法選擇

**決策**: 使用 ASP.NET Core Identity 的 `PasswordHasher<T>`

**理由**:
- 內建於 ASP.NET Core，無需額外相依套件
- 使用 PBKDF2 with HMAC-SHA256（可自動升級演算法）
- 包含自動 Salt 產生與驗證
- 符合 OWASP 密碼儲存建議

**替代方案**:
| 方案 | 優點 | 缺點 | 結論 |
|------|------|------|------|
| BCrypt.Net | 業界標準 | 需額外套件 | 不選用 |
| Argon2 | 最新標準 | 需額外套件、複雜度高 | 不選用 |
| SHA256 + Salt | 簡單 | 不建議用於密碼 | 不選用 |
| PasswordHasher<T> | 內建、自動升級 | 無 | ✅ 選用 |

---

### 2. 台灣身分證驗證邏輯

**決策**: 自行實作驗證邏輯（僅本國身分證）

**驗證規則**:
- 格式: 第一碼英文（A-Z）+ 第二碼（1 或 2）+ 8 位數字
- 檢查碼驗證: 使用標準加權驗證演算法
- 排除: 外籍居留證（統一證號，第二碼為 A-D）

**實作方式**:
```csharp
// 驗證步驟
// 1. 長度檢查 (10 碼)
// 2. 第一碼英文轉換為數字 (A=10, B=11, ..., Z=35)
// 3. 第二碼為 1 或 2
// 4. 後 8 碼為數字
// 5. 加權驗證碼計算
```

**替代方案**:
| 方案 | 優點 | 缺點 | 結論 |
|------|------|------|------|
| 第三方函式庫 | 現成實作 | 無適合的 NuGet 套件 | 不選用 |
| 正規表示式 only | 簡單 | 無法驗證檢查碼 | 不選用 |
| 自行實作完整驗證 | 完整控制 | 需測試 | ✅ 選用 |

---

### 3. E-Mail 驗證碼產生策略

**決策**: 使用 `RandomNumberGenerator` 產生 6 位純數字驗證碼

**理由**:
- 密碼學安全的隨機數產生器
- 符合 FR-005 需求（6 位純數字 000000-999999）
- 避免使用 `Random` 類別（不夠安全）

**實作方式**:
```csharp
using System.Security.Cryptography;

public string GenerateVerificationCode()
{
    var code = RandomNumberGenerator.GetInt32(0, 1000000);
    return code.ToString("D6"); // 確保 6 位數，補前導零
}
```

**替代方案**:
| 方案 | 優點 | 缺點 | 結論 |
|------|------|------|------|
| Random 類別 | 簡單 | 非密碼學安全 | 不選用 |
| GUID 取前 6 碼 | 唯一性高 | 包含英文字母 | 不選用 |
| RandomNumberGenerator | 安全、適用 | 無 | ✅ 選用 |

---

### 4. E-Mail 發送服務介面設計

**決策**: 定義 `IEmailService` 介面，使用相依性注入

**理由**:
- 遵循 DI 原則
- 便於測試（可 Mock）
- 未來可替換實作（SMTP、SendGrid、AWS SES 等）

**介面設計**:
```csharp
public interface IEmailService
{
    Task<bool> SendVerificationCodeAsync(string email, string code, CancellationToken cancellationToken = default);
}
```

**實作考量**:
- 初期可使用 SMTP 實作
- 假設系統已有 E-Mail 發送服務可用（spec.md 假設）
- 發送失敗不自動重試，回傳 false 讓使用者手動重送

---

### 5. CAPTCHA 驗證整合

**決策**: 使用 Google reCAPTCHA v3（背景評分）

**理由**:
- 無介面干擾，使用者體驗更佳
- 免費額度充足（100 萬次/月）
- 官方 .NET 整合套件支援
- 符合 FR-004b 需求

**整合方式**:
- 前端整合 reCAPTCHA v3 JavaScript SDK
- 後端透過 `ICaptchaValidator` 介面呼叫 Google API 驗證 token
- 評分閾值設為 **0.5**（可調整）
- 定義 `ICaptchaValidator` 介面以便測試

**選項比較**:
| 服務 | 免費額度 | 隱私合規 | 整合難度 | 建議 |
|------|----------|----------|----------|------|
| Google reCAPTCHA v3 | 100 萬次/月 | 需注意 GDPR | 低 | ⭐ 推薦 |
| Google reCAPTCHA v2 | 100 萬次/月 | 需注意 GDPR | 低 | 備選 |
| hCaptcha | 100 萬次/月 | GDPR 友善 | 低 | 備選 |
| Cloudflare Turnstile | 無限 (Free 方案) | 隱私優先 | 低 | 備選 |
| 自行實作圖形驗證碼 | - | 完整控制 | 高 | 不選用 |

**實作範例**:
```csharp
public interface ICaptchaValidator
{
    Task<bool> ValidateAsync(string token, CancellationToken cancellationToken = default);
}

// Google reCAPTCHA v3 實作
public class GoogleRecaptchaValidator : ICaptchaValidator
{
    private const double ScoreThreshold = 0.5;
    
    public async Task<bool> ValidateAsync(string token, CancellationToken cancellationToken)
    {
        // POST to https://www.google.com/recaptcha/api/siteverify
        // 驗證 success = true && score >= ScoreThreshold
    }
}
```

---

### 6. 未驗證帳號清理排程

**決策**: 使用 `IHostedService` 實作背景排程工作

**理由**:
- 內建於 ASP.NET Core，無需額外套件
- 簡單且足以滿足需求
- 符合「無 Redis」約束

**實作方式**:
```csharp
public class CleanupUnverifiedMembersJob : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            await CleanupExpiredMembers();
            await Task.Delay(TimeSpan.FromHours(24), stoppingToken);
        }
    }
}
```

**替代方案**:
| 方案 | 優點 | 缺點 | 結論 |
|------|------|------|------|
| Hangfire | 功能豐富 | 需額外套件 | 可考慮未來 |
| Quartz.NET | 強大排程 | 過度設計 | 不選用 |
| BackgroundService | 簡單內建 | 功能基本 | ✅ 選用 |

---

### 7. 資料庫索引策略

**決策**: 對 `IdNumber` 和 `Email` 建立唯一索引

**理由**:
- 符合 FR-003、FR-003a 唯一性需求
- 加速查詢效能
- 透過 EF Core Fluent API 設定

**索引設計**:
```csharp
// MemberConfiguration.cs
builder.HasIndex(m => m.IdNumber).IsUnique();
builder.HasIndex(m => m.Email).IsUnique();
builder.HasIndex(m => new { m.IsEmailVerified, m.CreatedAt }); // 清理 Job 用
```

---

### 8. API 錯誤回應格式

**決策**: 使用 RFC 7807 Problem Details 格式

**理由**:
- ASP.NET Core 內建支援
- 標準化錯誤回應
- 包含 status、title、detail 等結構

**回應範例**:
```json
{
    "type": "https://tools.ietf.org/html/rfc7807",
    "title": "此身分證字號已註冊",
    "status": 409,
    "detail": "身分證字號 A123456789 已被其他帳號使用",
    "instance": "/api/members/register"
}
```

---

### 9. 驗證碼有效期追蹤

**決策**: 資料庫儲存 `CreatedAt` + `ExpiresAt` 欄位

**理由**:
- 明確記錄有效期限
- 無需 Redis（符合約束）
- 簡化過期判斷邏輯

**欄位設計**:
```csharp
public class VerificationCode
{
    public DateTime CreatedAt { get; set; }  // UTC
    public DateTime ExpiresAt { get; set; }  // CreatedAt + 5 分鐘
    public bool IsUsed { get; set; }         // 是否已使用
}
```

---

## 相依套件選擇

| 套件 | 版本 | 用途 | 備註 |
|------|------|------|------|
| Microsoft.EntityFrameworkCore.SqlServer | 8.0.x | SQL Server Provider | 必要 |
| Microsoft.EntityFrameworkCore.Design | 8.0.x | EF Core Migrations | 開發時 |
| Microsoft.AspNetCore.Identity | 8.0.x | PasswordHasher<T> | 僅使用密碼雜湊 |
| xUnit | 2.x | 測試框架 | 測試專案 |
| Moq | 4.x | Mocking | 測試專案 |
| FluentAssertions | 6.x | 斷言語法 | 測試專案 |
| Swashbuckle.AspNetCore | 6.x | OpenAPI/Swagger | API 文件 |

**排除套件**:
- ❌ AutoMapper（使用 POCO 手動映射）
- ❌ StackExchange.Redis（無 Redis 需求）
- ❌ Hangfire（使用內建 BackgroundService）

---

## 安全性考量

### 密碼儲存
- ✅ 使用 PBKDF2 雜湊
- ✅ 自動 Salt
- ✅ 不可逆儲存

### 驗證碼安全
- ✅ 密碼學安全隨機數
- ✅ 5 分鐘有效期
- ✅ 使用後立即失效
- ✅ 重送時舊碼失效

### API 安全
- ✅ CAPTCHA 防止自動化攻擊
- ✅ 60 秒重送冷卻時間
- ⚠️ 建議未來加入 Rate Limiting

---

## 結論

所有技術決策已完成研究，無 NEEDS CLARIFICATION 項目。本專案將使用：

1. **密碼雜湊**: ASP.NET Core Identity PasswordHasher<T>
2. **身分證驗證**: 自行實作完整驗證邏輯
3. **驗證碼產生**: RandomNumberGenerator
4. **E-Mail 服務**: IEmailService 介面 + DI
5. **CAPTCHA**: Google reCAPTCHA v3（背景評分，評分閾值 0.5）
6. **排程清理**: BackgroundService
7. **資料庫索引**: IdNumber + Email 唯一索引
8. **錯誤回應**: RFC 7807 Problem Details
9. **驗證碼過期**: 資料庫時間戳記

準備進入 Phase 1: Design & Contracts。
