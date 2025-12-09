using System.ComponentModel.DataAnnotations;

namespace DuotifyMembership.Api.DTOs.Requests;

public class VerifyEmailRequest
{
    [Required(ErrorMessage = "驗證碼為必填")]
    [StringLength(6, MinimumLength = 6, ErrorMessage = "驗證碼必須為 6 位數")]
    public string Code { get; set; } = string.Empty;
}
