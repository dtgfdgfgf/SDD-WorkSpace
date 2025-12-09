# 資料模型設計：會員註冊流程

**功能分支**: `001-member-registration`  
**建立日期**: 2025-12-01  
**Phase**: 1 - Design

---

## 實體概覽

本功能涉及兩個核心實體：

| 實體 | 說明 | 對應需求 |
|------|------|----------|
| Member | 會員資料 | FR-001 ~ FR-004, FR-011 ~ FR-018 |
| VerificationCode | E-Mail 驗證碼 | FR-005 ~ FR-010 |

---

## 實體詳細設計

### 1. Member (會員)

**說明**: 代表一位註冊會員，包含個人資料、驗證狀態及帳號資訊。

#### 欄位定義

| 欄位 | 型別 | 必填 | 說明 | 對應需求 |
|------|------|------|------|----------|
| Id | Guid | ✅ | 主鍵，自動產生 | - |
| IdNumber | string(10) | ✅ | 身分證字號，儲存時轉大寫 | FR-001, FR-002, FR-003 |
| Name | string(50) | ✅ | 會員姓名 | FR-001 |
| Email | string(256) | ✅ | E-Mail，儲存時轉小寫 | FR-001, FR-003a |
| PasswordHash | string(256) | ✅ | 密碼雜湊值（使用 `PasswordHasher<Member>`，PBKDF2 演算法） | FR-004 |
| IsEmailVerified | bool | ✅ | E-Mail 是否已驗證，預設 false | FR-008, FR-011, FR-012 |
| CreatedAt | DateTime | ✅ | 帳號建立時間 (UTC) | FR-018 |
| EmailVerifiedAt | DateTime? | ❌ | E-Mail 驗證完成時間 (UTC) | FR-008 |

#### 索引設計

| 索引名稱 | 欄位 | 類型 | 說明 |
|----------|------|------|------|
| IX_Member_IdNumber | IdNumber | UNIQUE | 確保身分證字號唯一 |
| IX_Member_Email | Email | UNIQUE | 確保 E-Mail 唯一 |
| IX_Member_Cleanup | (IsEmailVerified, CreatedAt) | NON-UNIQUE | 清理未驗證帳號用 |

#### 驗證規則

| 欄位 | 驗證規則 | 錯誤訊息 |
|------|----------|----------|
| IdNumber | 長度 = 10，台灣身分證格式 | 「身分證字號格式不正確」 |
| Name | 長度 1-50 | 「姓名為必填欄位」 |
| Email | 有效 E-Mail 格式，長度 ≤ 256 | 「E-Mail 格式不正確」 |
| Password | 8-20 碼，含大小寫英文及數字 | 「密碼需為 8-20 碼，並包含英文大小寫及數字」 |

#### Entity 類別

```csharp
namespace DuotifyMembership.Core.Entities;

public class Member
{
    public Guid Id { get; set; }
    
    /// <summary>身分證字號（大寫）</summary>
    public string IdNumber { get; set; } = string.Empty;
    
    /// <summary>會員姓名</summary>
    public string Name { get; set; } = string.Empty;
    
    /// <summary>E-Mail（小寫）</summary>
    public string Email { get; set; } = string.Empty;
    
    /// <summary>密碼雜湊值</summary>
    public string PasswordHash { get; set; } = string.Empty;
    
    /// <summary>E-Mail 是否已驗證</summary>
    public bool IsEmailVerified { get; set; } = false;
    
    /// <summary>帳號建立時間 (UTC)</summary>
    public DateTime CreatedAt { get; set; }
    
    /// <summary>E-Mail 驗證完成時間 (UTC)</summary>
    public DateTime? EmailVerifiedAt { get; set; }
    
    // 導覽屬性
    public ICollection<VerificationCode> VerificationCodes { get; set; } = new List<VerificationCode>();
}
```

#### EF Core 設定

```csharp
namespace DuotifyMembership.Infrastructure.Data.Configurations;

public class MemberConfiguration : IEntityTypeConfiguration<Member>
{
    public void Configure(EntityTypeBuilder<Member> builder)
    {
        builder.ToTable("Members");
        
        builder.HasKey(m => m.Id);
        
        builder.Property(m => m.IdNumber)
            .IsRequired()
            .HasMaxLength(10);
            
        builder.Property(m => m.Name)
            .IsRequired()
            .HasMaxLength(50);
            
        builder.Property(m => m.Email)
            .IsRequired()
            .HasMaxLength(256);
            
        builder.Property(m => m.PasswordHash)
            .IsRequired()
            .HasMaxLength(256);
            
        builder.Property(m => m.CreatedAt)
            .IsRequired();
        
        // 索引
        builder.HasIndex(m => m.IdNumber)
            .IsUnique()
            .HasDatabaseName("IX_Member_IdNumber");
            
        builder.HasIndex(m => m.Email)
            .IsUnique()
            .HasDatabaseName("IX_Member_Email");
            
        builder.HasIndex(m => new { m.IsEmailVerified, m.CreatedAt })
            .HasDatabaseName("IX_Member_Cleanup");
    }
}
```

---

### 2. VerificationCode (驗證碼)

**說明**: 代表一組 E-Mail 驗證碼，關聯至會員。

#### 欄位定義

| 欄位 | 型別 | 必填 | 說明 | 對應需求 |
|------|------|------|------|----------|
| Id | Guid | ✅ | 主鍵，自動產生 | - |
| MemberId | Guid | ✅ | 關聯的會員 Id（外鍵） | - |
| Code | string(6) | ✅ | 6 位數驗證碼 | FR-005 |
| CreatedAt | DateTime | ✅ | 建立時間 (UTC) | FR-010 |
| ExpiresAt | DateTime | ✅ | 到期時間 (UTC)，CreatedAt + 5 分鐘 | FR-006 |
| IsUsed | bool | ✅ | 是否已使用，預設 false | FR-008 |

#### 索引設計

| 索引名稱 | 欄位 | 類型 | 說明 |
|----------|------|------|------|
| IX_VerificationCode_MemberId | MemberId | NON-UNIQUE | 外鍵索引 |
| IX_VerificationCode_Active | (MemberId, IsUsed, ExpiresAt) | NON-UNIQUE | 查詢有效驗證碼 |

#### 業務規則

| 規則 | 說明 | 對應需求 |
|------|------|----------|
| 有效期 5 分鐘 | ExpiresAt = CreatedAt + 5 minutes | FR-006 |
| 使用後失效 | 驗證成功後設定 IsUsed = true | FR-008 |
| 重送使舊碼失效 | 重送時將舊碼的 IsUsed 設為 true | FR-009 |
| 冷卻時間 60 秒 | 上次發送後 60 秒內不可重送 | FR-010 |

#### Entity 類別

```csharp
namespace DuotifyMembership.Core.Entities;

public class VerificationCode
{
    public Guid Id { get; set; }
    
    /// <summary>關聯的會員 Id</summary>
    public Guid MemberId { get; set; }
    
    /// <summary>6 位數驗證碼</summary>
    public string Code { get; set; } = string.Empty;
    
    /// <summary>建立時間 (UTC)</summary>
    public DateTime CreatedAt { get; set; }
    
    /// <summary>到期時間 (UTC)</summary>
    public DateTime ExpiresAt { get; set; }
    
    /// <summary>是否已使用</summary>
    public bool IsUsed { get; set; } = false;
    
    // 導覽屬性
    public Member Member { get; set; } = null!;
    
    /// <summary>檢查驗證碼是否有效</summary>
    public bool IsValid(DateTime utcNow) => !IsUsed && ExpiresAt > utcNow;
}
```

#### EF Core 設定

```csharp
namespace DuotifyMembership.Infrastructure.Data.Configurations;

public class VerificationCodeConfiguration : IEntityTypeConfiguration<VerificationCode>
{
    public void Configure(EntityTypeBuilder<VerificationCode> builder)
    {
        builder.ToTable("VerificationCodes");
        
        builder.HasKey(v => v.Id);
        
        builder.Property(v => v.Code)
            .IsRequired()
            .HasMaxLength(6)
            .IsFixedLength();
            
        builder.Property(v => v.CreatedAt)
            .IsRequired();
            
        builder.Property(v => v.ExpiresAt)
            .IsRequired();
        
        // 外鍵關聯
        builder.HasOne(v => v.Member)
            .WithMany(m => m.VerificationCodes)
            .HasForeignKey(v => v.MemberId)
            .OnDelete(DeleteBehavior.Cascade);
        
        // 索引
        builder.HasIndex(v => v.MemberId)
            .HasDatabaseName("IX_VerificationCode_MemberId");
            
        builder.HasIndex(v => new { v.MemberId, v.IsUsed, v.ExpiresAt })
            .HasDatabaseName("IX_VerificationCode_Active");
    }
}
```

---

## 實體關聯圖 (ER Diagram)

```text
┌─────────────────────────────────────────┐
│                 Member                   │
├─────────────────────────────────────────┤
│ PK  Id: Guid                            │
│     IdNumber: string(10) [UNIQUE]       │
│     Name: string(50)                    │
│     Email: string(256) [UNIQUE]         │
│     PasswordHash: string(256)           │
│     IsEmailVerified: bool               │
│     CreatedAt: DateTime                 │
│     EmailVerifiedAt: DateTime?          │
└──────────────────┬──────────────────────┘
                   │ 1
                   │
                   │ *
┌──────────────────┴──────────────────────┐
│           VerificationCode               │
├─────────────────────────────────────────┤
│ PK  Id: Guid                            │
│ FK  MemberId: Guid                      │
│     Code: string(6)                     │
│     CreatedAt: DateTime                 │
│     ExpiresAt: DateTime                 │
│     IsUsed: bool                        │
└─────────────────────────────────────────┘
```

**關聯說明**:
- Member : VerificationCode = 1 : N（一對多）
- 刪除 Member 時，連帶刪除其所有 VerificationCode（Cascade Delete）

---

## 狀態轉換

### Member 狀態

```text
[註冊中] ──(提交表單)──> [待驗證] ──(驗證成功)──> [已驗證]
                              │
                              └──(7 天未驗證)──> [已刪除]
```

| 狀態 | IsEmailVerified | 可執行動作 |
|------|-----------------|------------|
| 待驗證 | false | 登入（受限）、驗證、重送驗證碼 |
| 已驗證 | true | 登入（完整功能） |

### VerificationCode 狀態

```text
[建立] ──(驗證成功)──> [已使用]
   │
   ├──(過期)──> [已過期]
   │
   └──(重送新碼)──> [已失效]
```

| 狀態 | IsUsed | ExpiresAt | 說明 |
|------|--------|-----------|------|
| 有效 | false | > now | 可用於驗證 |
| 已使用 | true | - | 驗證成功後 |
| 已過期 | false | ≤ now | 超過 5 分鐘 |
| 已失效 | true | - | 重送新碼後 |

---

## SQL Schema (參考)

```sql
-- Members 資料表
CREATE TABLE [dbo].[Members] (
    [Id] UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
    [IdNumber] NVARCHAR(10) NOT NULL,
    [Name] NVARCHAR(50) NOT NULL,
    [Email] NVARCHAR(256) NOT NULL,
    [PasswordHash] NVARCHAR(256) NOT NULL,
    [IsEmailVerified] BIT NOT NULL DEFAULT 0,
    [CreatedAt] DATETIME2 NOT NULL,
    [EmailVerifiedAt] DATETIME2 NULL,
    
    CONSTRAINT [UQ_Member_IdNumber] UNIQUE ([IdNumber]),
    CONSTRAINT [UQ_Member_Email] UNIQUE ([Email])
);

CREATE INDEX [IX_Member_Cleanup] ON [dbo].[Members] ([IsEmailVerified], [CreatedAt]);

-- VerificationCodes 資料表
CREATE TABLE [dbo].[VerificationCodes] (
    [Id] UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWSEQUENTIALID(),
    [MemberId] UNIQUEIDENTIFIER NOT NULL,
    [Code] NCHAR(6) NOT NULL,
    [CreatedAt] DATETIME2 NOT NULL,
    [ExpiresAt] DATETIME2 NOT NULL,
    [IsUsed] BIT NOT NULL DEFAULT 0,
    
    CONSTRAINT [FK_VerificationCode_Member] FOREIGN KEY ([MemberId]) 
        REFERENCES [dbo].[Members] ([Id]) ON DELETE CASCADE
);

CREATE INDEX [IX_VerificationCode_MemberId] ON [dbo].[VerificationCodes] ([MemberId]);
CREATE INDEX [IX_VerificationCode_Active] ON [dbo].[VerificationCodes] ([MemberId], [IsUsed], [ExpiresAt]);
```

---

## 測試資料範例

### 有效會員

```json
{
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "idNumber": "A123456789",
    "name": "王小明",
    "email": "xiaoming.wang@example.com",
    "passwordHash": "AQAAAAEAACcQAAAAE...",
    "isEmailVerified": true,
    "createdAt": "2025-12-01T10:00:00Z",
    "emailVerifiedAt": "2025-12-01T10:05:00Z"
}
```

### 待驗證會員

```json
{
    "id": "550e8400-e29b-41d4-a716-446655440001",
    "idNumber": "B234567890",
    "name": "李小華",
    "email": "xiaohua.li@example.com",
    "passwordHash": "AQAAAAEAACcQAAAAE...",
    "isEmailVerified": false,
    "createdAt": "2025-12-01T11:00:00Z",
    "emailVerifiedAt": null
}
```

### 有效驗證碼

```json
{
    "id": "660e8400-e29b-41d4-a716-446655440000",
    "memberId": "550e8400-e29b-41d4-a716-446655440001",
    "code": "123456",
    "createdAt": "2025-12-01T11:00:00Z",
    "expiresAt": "2025-12-01T11:05:00Z",
    "isUsed": false
}
```
