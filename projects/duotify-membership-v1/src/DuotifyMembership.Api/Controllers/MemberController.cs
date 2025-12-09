using DuotifyMembership.Api.DTOs.Requests;
using DuotifyMembership.Api.DTOs.Responses;
using DuotifyMembership.Api.Validators;
using DuotifyMembership.Core.Interfaces;
using Microsoft.AspNetCore.Mvc;

namespace DuotifyMembership.Api.Controllers;

[ApiController]
[Route("v1/members")]
public class MemberController : ControllerBase
{
    private readonly IMemberService _memberService;
    private readonly IVerificationService _verificationService;
    private readonly ILogger<MemberController> _logger;

    public MemberController(
        IMemberService memberService,
        IVerificationService verificationService,
        ILogger<MemberController> logger)
    {
        _memberService = memberService;
        _verificationService = verificationService;
        _logger = logger;
    }

    [HttpPost("register")]
    public async Task<ActionResult<RegisterMemberResponse>> Register(
        [FromBody] RegisterMemberRequest request,
        CancellationToken cancellationToken)
    {
        // Validate Taiwan ID
        if (!TaiwanIdValidator.Validate(request.IdNumber))
        {
            return BadRequest(new ApiErrorResponse
            {
                ErrorCode = "INVALID_ID_NUMBER",
                Message = "身分證字號格式不正確",
                Timestamp = DateTime.UtcNow
            });
        }

        // Validate password
        if (!PasswordValidator.Validate(request.Password, out var passwordError))
        {
            return BadRequest(new ApiErrorResponse
            {
                ErrorCode = "INVALID_PASSWORD",
                Message = passwordError!,
                Timestamp = DateTime.UtcNow
            });
        }

        var member = await _memberService.RegisterAsync(
            request.IdNumber,
            request.Name,
            request.Email,
            request.Password,
            request.CaptchaToken,
            cancellationToken);

        return CreatedAtAction(
            nameof(GetStatus),
            new { memberId = member.Id },
            new RegisterMemberResponse
            {
                MemberId = member.Id,
                Message = "註冊成功，驗證碼已發送至您的 E-Mail"
            });
    }

    [HttpPost("{memberId:guid}/verify-email")]
    public async Task<ActionResult<VerifyEmailResponse>> VerifyEmail(
        Guid memberId,
        [FromBody] VerifyEmailRequest request,
        CancellationToken cancellationToken)
    {
        var isVerified = await _verificationService.VerifyCodeAsync(
            memberId,
            request.Code,
            cancellationToken);

        return Ok(new VerifyEmailResponse
        {
            IsVerified = isVerified,
            Message = "E-Mail 驗證成功"
        });
    }

    [HttpPost("{memberId:guid}/resend-verification")]
    public async Task<ActionResult<ResendVerificationResponse>> ResendVerification(
        Guid memberId,
        CancellationToken cancellationToken)
    {
        await _verificationService.ResendCodeAsync(memberId, cancellationToken);

        return Ok(new ResendVerificationResponse
        {
            Message = "驗證碼已重新發送至您的 E-Mail"
        });
    }

    [HttpGet("{memberId:guid}/status")]
    public async Task<ActionResult<MemberStatusResponse>> GetStatus(
        Guid memberId,
        CancellationToken cancellationToken)
    {
        var member = await _memberService.GetMemberByIdAsync(memberId, cancellationToken);
        
        if (member == null)
        {
            return NotFound(new ApiErrorResponse
            {
                ErrorCode = "MEMBER_NOT_FOUND",
                Message = "會員不存在",
                Timestamp = DateTime.UtcNow
            });
        }

        return Ok(new MemberStatusResponse
        {
            MemberId = member.Id,
            IsEmailVerified = member.IsEmailVerified,
            Message = member.IsEmailVerified 
                ? "E-Mail 已驗證" 
                : "請完成 E-Mail 驗證以使用完整功能"
        });
    }
}
