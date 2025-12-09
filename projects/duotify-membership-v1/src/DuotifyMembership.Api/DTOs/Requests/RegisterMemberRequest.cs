using System.ComponentModel.DataAnnotations;

namespace DuotifyMembership.Api.DTOs.Requests;

public class RegisterMemberRequest
{
    [Required(ErrorMessage = "身分證字號為必填")]
    public string IdNumber { get; set; } = string.Empty;

    [Required(ErrorMessage = "姓名為必填")]
    [MaxLength(100, ErrorMessage = "姓名長度不可超過 100 字元")]
    public string Name { get; set; } = string.Empty;

    [Required(ErrorMessage = "E-Mail 為必填")]
    [EmailAddress(ErrorMessage = "E-Mail 格式不正確")]
    public string Email { get; set; } = string.Empty;

    [Required(ErrorMessage = "密碼為必填")]
    public string Password { get; set; } = string.Empty;

    [Required(ErrorMessage = "CAPTCHA 為必填")]
    public string CaptchaToken { get; set; } = string.Empty;
}
