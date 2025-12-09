namespace DuotifyMembership.Core.Entities;

/// <summary>
/// 會員實體
/// </summary>
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
