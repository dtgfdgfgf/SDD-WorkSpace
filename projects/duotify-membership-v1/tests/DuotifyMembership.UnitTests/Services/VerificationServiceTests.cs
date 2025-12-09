using DuotifyMembership.Core.Entities;
using DuotifyMembership.Core.Exceptions;
using DuotifyMembership.Core.Interfaces;
using DuotifyMembership.Core.Services;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace DuotifyMembership.UnitTests.Services;

public class VerificationServiceTests
{
    private readonly Mock<IMemberRepository> _memberRepositoryMock;
    private readonly Mock<IVerificationCodeRepository> _verificationCodeRepositoryMock;
    private readonly Mock<IEmailService> _emailServiceMock;
    private readonly IMemoryCache _memoryCache;
    private readonly Mock<ILogger<VerificationService>> _loggerMock;
    private readonly VerificationService _sut;

    public VerificationServiceTests()
    {
        _memberRepositoryMock = new Mock<IMemberRepository>();
        _verificationCodeRepositoryMock = new Mock<IVerificationCodeRepository>();
        _emailServiceMock = new Mock<IEmailService>();
        _memoryCache = new MemoryCache(new MemoryCacheOptions());
        _loggerMock = new Mock<ILogger<VerificationService>>();

        _sut = new VerificationService(
            _memberRepositoryMock.Object,
            _verificationCodeRepositoryMock.Object,
            _emailServiceMock.Object,
            _memoryCache,
            _loggerMock.Object);
    }

    [Fact]
    public async Task VerifyCodeAsync_ValidCode_ShouldVerifyMemberAndMarkCodeAsUsed()
    {
        // Arrange
        var memberId = Guid.NewGuid();
        var code = "123456";
        var member = new Member { Id = memberId, IsEmailVerified = false };
        var verificationCode = new VerificationCode
        {
            Id = Guid.NewGuid(),
            MemberId = memberId,
            Code = code,
            ExpiresAt = DateTime.UtcNow.AddMinutes(5),
            IsUsed = false
        };

        _memberRepositoryMock.Setup(x => x.GetByIdAsync(memberId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(member);
        _verificationCodeRepositoryMock.Setup(x => x.GetValidCodeAsync(memberId, code, It.IsAny<CancellationToken>()))
            .ReturnsAsync(verificationCode);
        _memberRepositoryMock.Setup(x => x.SaveChangesAsync(It.IsAny<CancellationToken>()))
            .ReturnsAsync(1);
        _verificationCodeRepositoryMock.Setup(x => x.SaveChangesAsync(It.IsAny<CancellationToken>()))
            .ReturnsAsync(1);

        // Act
        var result = await _sut.VerifyCodeAsync(memberId, code);

        // Assert
        Assert.True(result);
        Assert.True(member.IsEmailVerified);
        Assert.True(verificationCode.IsUsed);
        _memberRepositoryMock.Verify(x => x.Update(member), Times.Once);
        _verificationCodeRepositoryMock.Verify(x => x.Update(verificationCode), Times.Once);
    }

    [Fact]
    public async Task VerifyCodeAsync_MemberNotFound_ShouldThrowException()
    {
        // Arrange
        var memberId = Guid.NewGuid();
        _memberRepositoryMock.Setup(x => x.GetByIdAsync(memberId, It.IsAny<CancellationToken>()))
            .ReturnsAsync((Member?)null);

        // Act & Assert
        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            _sut.VerifyCodeAsync(memberId, "123456"));
    }

    [Fact]
    public async Task VerifyCodeAsync_ExpiredCode_ShouldThrowVerificationCodeExpiredException()
    {
        // Arrange
        var memberId = Guid.NewGuid();
        var member = new Member { Id = memberId, IsEmailVerified = false };
        var expiredCode = new VerificationCode
        {
            Id = Guid.NewGuid(),
            MemberId = memberId,
            Code = "123456",
            ExpiresAt = DateTime.UtcNow.AddMinutes(-1),
            IsUsed = false
        };

        _memberRepositoryMock.Setup(x => x.GetByIdAsync(memberId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(member);
        _verificationCodeRepositoryMock.Setup(x => x.GetValidCodeAsync(memberId, It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync((VerificationCode?)null);
        _verificationCodeRepositoryMock.Setup(x => x.GetLatestByMemberIdAsync(memberId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(expiredCode);

        // Act & Assert
        await Assert.ThrowsAsync<VerificationCodeExpiredException>(() =>
            _sut.VerifyCodeAsync(memberId, "123456"));
    }

    [Fact]
    public async Task VerifyCodeAsync_InvalidCode_ShouldThrowVerificationCodeInvalidException()
    {
        // Arrange
        var memberId = Guid.NewGuid();
        var member = new Member { Id = memberId, IsEmailVerified = false };

        _memberRepositoryMock.Setup(x => x.GetByIdAsync(memberId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(member);
        _verificationCodeRepositoryMock.Setup(x => x.GetValidCodeAsync(memberId, It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync((VerificationCode?)null);
        _verificationCodeRepositoryMock.Setup(x => x.GetLatestByMemberIdAsync(memberId, It.IsAny<CancellationToken>()))
            .ReturnsAsync((VerificationCode?)null);

        // Act & Assert
        await Assert.ThrowsAsync<VerificationCodeInvalidException>(() =>
            _sut.VerifyCodeAsync(memberId, "wrong"));
    }

    [Fact]
    public async Task ResendCodeAsync_ValidRequest_ShouldInvalidateOldCodesAndSendNewCode()
    {
        // Arrange
        var memberId = Guid.NewGuid();
        var member = new Member { Id = memberId, Email = "test@example.com", IsEmailVerified = false };

        _memberRepositoryMock.Setup(x => x.GetByIdAsync(memberId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(member);
        _verificationCodeRepositoryMock.Setup(x => x.SaveChangesAsync(It.IsAny<CancellationToken>()))
            .ReturnsAsync(1);

        // Act
        await _sut.ResendCodeAsync(memberId);

        // Assert
        _verificationCodeRepositoryMock.Verify(x => x.InvalidateAllForMemberAsync(memberId, It.IsAny<CancellationToken>()), Times.Once);
        _verificationCodeRepositoryMock.Verify(x => x.AddAsync(It.IsAny<VerificationCode>(), It.IsAny<CancellationToken>()), Times.Once);
        _emailServiceMock.Verify(x => x.SendVerificationCodeAsync(member.Email, It.IsAny<string>(), It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task ResendCodeAsync_WithinCooldown_ShouldThrowException()
    {
        // Arrange
        var memberId = Guid.NewGuid();
        var member = new Member { Id = memberId, Email = "test@example.com", IsEmailVerified = false };
        var cacheKey = $"resend_cooldown_{memberId}";

        _memberRepositoryMock.Setup(x => x.GetByIdAsync(memberId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(member);
        
        // Simulate cooldown
        _memoryCache.Set(cacheKey, true, TimeSpan.FromSeconds(60));

        // Act & Assert
        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            _sut.ResendCodeAsync(memberId));
    }
}
