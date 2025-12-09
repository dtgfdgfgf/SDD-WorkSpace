using DuotifyMembership.Core.Entities;
using DuotifyMembership.Core.Exceptions;
using DuotifyMembership.Core.Interfaces;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Logging;

namespace DuotifyMembership.Core.Services;

public class MemberService : IMemberService
{
    private readonly IMemberRepository _memberRepository;
    private readonly IVerificationCodeRepository _verificationCodeRepository;
    private readonly IEmailService _emailService;
    private readonly ICaptchaValidator _captchaValidator;
    private readonly IPasswordHasher<Member> _passwordHasher;
    private readonly ILogger<MemberService> _logger;

    public MemberService(
        IMemberRepository memberRepository,
        IVerificationCodeRepository verificationCodeRepository,
        IEmailService emailService,
        ICaptchaValidator captchaValidator,
        ILogger<MemberService> logger)
    {
        _memberRepository = memberRepository;
        _verificationCodeRepository = verificationCodeRepository;
        _emailService = emailService;
        _captchaValidator = captchaValidator;
        _passwordHasher = new PasswordHasher<Member>();
        _logger = logger;
    }

    public async Task<Member> RegisterAsync(string idNumber, string name, string email, string password, string captchaToken, CancellationToken cancellationToken = default)
    {
        // Validate CAPTCHA
        if (!await _captchaValidator.ValidateAsync(captchaToken, cancellationToken))
        {
            throw new InvalidOperationException("CAPTCHA validation failed");
        }

        // Check for duplicate ID number
        if (await _memberRepository.ExistsByIdNumberAsync(idNumber, cancellationToken))
        {
            throw new DuplicateIdNumberException(idNumber);
        }

        // Check for duplicate email
        if (await _memberRepository.ExistsByEmailAsync(email, cancellationToken))
        {
            throw new DuplicateEmailException(email);
        }

        // Create member
        var member = new Member
        {
            Id = Guid.NewGuid(),
            IdNumber = idNumber,
            Name = name,
            Email = email,
            IsEmailVerified = false,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        // Hash password
        member.PasswordHash = _passwordHasher.HashPassword(member, password);

        await _memberRepository.AddAsync(member, cancellationToken);
        await _memberRepository.SaveChangesAsync(cancellationToken);

        // Generate and send verification code
        var verificationCode = new VerificationCode
        {
            Id = Guid.NewGuid(),
            MemberId = member.Id,
            Code = GenerateVerificationCode(),
            ExpiresAt = DateTime.UtcNow.AddMinutes(5),
            IsUsed = false,
            CreatedAt = DateTime.UtcNow
        };

        await _verificationCodeRepository.AddAsync(verificationCode, cancellationToken);
        await _verificationCodeRepository.SaveChangesAsync(cancellationToken);

        await _emailService.SendVerificationCodeAsync(member.Email, verificationCode.Code, cancellationToken);

        _logger.LogInformation("Member registered successfully: {MemberId}", member.Id);

        return member;
    }

    public async Task<Member?> GetMemberByIdAsync(Guid memberId, CancellationToken cancellationToken = default)
    {
        return await _memberRepository.GetByIdAsync(memberId, cancellationToken);
    }

    public async Task<bool> GetMemberStatusAsync(Guid memberId, CancellationToken cancellationToken = default)
    {
        var member = await _memberRepository.GetByIdAsync(memberId, cancellationToken);
        return member?.IsEmailVerified ?? false;
    }

    private string GenerateVerificationCode()
    {
        var random = new Random();
        return random.Next(100000, 999999).ToString();
    }
}
