namespace DuotifyMembership.Core.Entities;

/// <summary>
/// 驗證碼實體
/// </summary>
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
