using DuotifyMembership.Core.Exceptions;
using DuotifyMembership.Core.Interfaces;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;

namespace DuotifyMembership.Core.Services;

public class VerificationService : IVerificationService
{
    private readonly IMemberRepository _memberRepository;
    private readonly IVerificationCodeRepository _verificationCodeRepository;
    private readonly IEmailService _emailService;
    private readonly IMemoryCache _memoryCache;
    private readonly ILogger<VerificationService> _logger;
    private const int ResendCooldownSeconds = 60;

    public VerificationService(
        IMemberRepository memberRepository,
        IVerificationCodeRepository verificationCodeRepository,
        IEmailService emailService,
        IMemoryCache memoryCache,
        ILogger<VerificationService> logger)
    {
        _memberRepository = memberRepository;
        _verificationCodeRepository = verificationCodeRepository;
        _emailService = emailService;
        _memoryCache = memoryCache;
        _logger = logger;
    }

    public async Task<bool> VerifyCodeAsync(Guid memberId, string code, CancellationToken cancellationToken = default)
    {
        var member = await _memberRepository.GetByIdAsync(memberId, cancellationToken);
        if (member == null)
        {
            throw new InvalidOperationException("Member not found");
        }

        if (member.IsEmailVerified)
        {
            _logger.LogInformation("Member {MemberId} is already verified", memberId);
            return true;
        }

        var verificationCode = await _verificationCodeRepository.GetValidCodeAsync(memberId, code, cancellationToken);
        if (verificationCode == null)
        {
            var latestCode = await _verificationCodeRepository.GetLatestByMemberIdAsync(memberId, cancellationToken);
            if (latestCode != null && latestCode.ExpiresAt < DateTime.UtcNow)
            {
                throw new VerificationCodeExpiredException();
            }
            throw new VerificationCodeInvalidException();
        }

        // Mark code as used
        verificationCode.IsUsed = true;
        _verificationCodeRepository.Update(verificationCode);

        // Update member verification status
        member.IsEmailVerified = true;
        member.UpdatedAt = DateTime.UtcNow;
        _memberRepository.Update(member);

        await _memberRepository.SaveChangesAsync(cancellationToken);
        await _verificationCodeRepository.SaveChangesAsync(cancellationToken);

        _logger.LogInformation("Member {MemberId} verified successfully", memberId);

        return true;
    }

    public async Task ResendCodeAsync(Guid memberId, CancellationToken cancellationToken = default)
    {
        var cacheKey = $"resend_cooldown_{memberId}";
        if (_memoryCache.TryGetValue(cacheKey, out _))
        {
            throw new InvalidOperationException("Please wait before requesting a new verification code");
        }

        var member = await _memberRepository.GetByIdAsync(memberId, cancellationToken);
        if (member == null)
        {
            throw new InvalidOperationException("Member not found");
        }

        if (member.IsEmailVerified)
        {
            throw new InvalidOperationException("Member is already verified");
        }

        // Invalidate all previous codes
        await _verificationCodeRepository.InvalidateAllForMemberAsync(memberId, cancellationToken);
        await _verificationCodeRepository.SaveChangesAsync(cancellationToken);

        // Generate new code
        var verificationCode = new Core.Entities.VerificationCode
        {
            Id = Guid.NewGuid(),
            MemberId = memberId,
            Code = GenerateVerificationCode(),
            ExpiresAt = DateTime.UtcNow.AddMinutes(5),
            IsUsed = false,
            CreatedAt = DateTime.UtcNow
        };

        await _verificationCodeRepository.AddAsync(verificationCode, cancellationToken);
        await _verificationCodeRepository.SaveChangesAsync(cancellationToken);

        await _emailService.SendVerificationCodeAsync(member.Email, verificationCode.Code, cancellationToken);

        // Set cooldown
        _memoryCache.Set(cacheKey, true, TimeSpan.FromSeconds(ResendCooldownSeconds));

        _logger.LogInformation("Verification code resent to member {MemberId}", memberId);
    }

    private string GenerateVerificationCode()
    {
        var random = new Random();
        return random.Next(100000, 999999).ToString();
    }
}
