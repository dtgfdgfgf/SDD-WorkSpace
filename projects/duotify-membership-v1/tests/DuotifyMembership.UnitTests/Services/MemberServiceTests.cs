using DuotifyMembership.Core.Entities;
using DuotifyMembership.Core.Exceptions;
using DuotifyMembership.Core.Interfaces;
using DuotifyMembership.Core.Services;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace DuotifyMembership.UnitTests.Services;

public class MemberServiceTests
{
    private readonly Mock<IMemberRepository> _memberRepositoryMock;
    private readonly Mock<IVerificationCodeRepository> _verificationCodeRepositoryMock;
    private readonly Mock<IEmailService> _emailServiceMock;
    private readonly Mock<ICaptchaValidator> _captchaValidatorMock;
    private readonly Mock<ILogger<MemberService>> _loggerMock;
    private readonly MemberService _sut;

    public MemberServiceTests()
    {
        _memberRepositoryMock = new Mock<IMemberRepository>();
        _verificationCodeRepositoryMock = new Mock<IVerificationCodeRepository>();
        _emailServiceMock = new Mock<IEmailService>();
        _captchaValidatorMock = new Mock<ICaptchaValidator>();
        _loggerMock = new Mock<ILogger<MemberService>>();

        _sut = new MemberService(
            _memberRepositoryMock.Object,
            _verificationCodeRepositoryMock.Object,
            _emailServiceMock.Object,
            _captchaValidatorMock.Object,
            _loggerMock.Object);
    }

    [Fact]
    public async Task RegisterAsync_ValidInput_ShouldCreateMemberAndSendVerificationCode()
    {
        // Arrange
        var idNumber = "A123456789";
        var name = "Test User";
        var email = "test@example.com";
        var password = "Password123";
        var captchaToken = "valid-token";

        _captchaValidatorMock.Setup(x => x.ValidateAsync(captchaToken, It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);
        _memberRepositoryMock.Setup(x => x.ExistsByIdNumberAsync(idNumber, It.IsAny<CancellationToken>()))
            .ReturnsAsync(false);
        _memberRepositoryMock.Setup(x => x.ExistsByEmailAsync(email, It.IsAny<CancellationToken>()))
            .ReturnsAsync(false);
        _memberRepositoryMock.Setup(x => x.SaveChangesAsync(It.IsAny<CancellationToken>()))
            .ReturnsAsync(1);
        _verificationCodeRepositoryMock.Setup(x => x.SaveChangesAsync(It.IsAny<CancellationToken>()))
            .ReturnsAsync(1);

        // Act
        var result = await _sut.RegisterAsync(idNumber, name, email, password, captchaToken);

        // Assert
        Assert.NotNull(result);
        Assert.Equal(idNumber, result.IdNumber);
        Assert.Equal(name, result.Name);
        Assert.Equal(email, result.Email);
        Assert.False(result.IsEmailVerified);
        _memberRepositoryMock.Verify(x => x.AddAsync(It.IsAny<Member>(), It.IsAny<CancellationToken>()), Times.Once);
        _verificationCodeRepositoryMock.Verify(x => x.AddAsync(It.IsAny<VerificationCode>(), It.IsAny<CancellationToken>()), Times.Once);
        _emailServiceMock.Verify(x => x.SendVerificationCodeAsync(email, It.IsAny<string>(), It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task RegisterAsync_InvalidCaptcha_ShouldThrowException()
    {
        // Arrange
        _captchaValidatorMock.Setup(x => x.ValidateAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(false);

        // Act & Assert
        await Assert.ThrowsAsync<InvalidOperationException>(() =>
            _sut.RegisterAsync("A123456789", "Test", "test@example.com", "Password123", "invalid"));
    }

    [Fact]
    public async Task RegisterAsync_DuplicateIdNumber_ShouldThrowDuplicateIdNumberException()
    {
        // Arrange
        var idNumber = "A123456789";
        _captchaValidatorMock.Setup(x => x.ValidateAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);
        _memberRepositoryMock.Setup(x => x.ExistsByIdNumberAsync(idNumber, It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);

        // Act & Assert
        await Assert.ThrowsAsync<DuplicateIdNumberException>(() =>
            _sut.RegisterAsync(idNumber, "Test", "test@example.com", "Password123", "valid"));
    }

    [Fact]
    public async Task RegisterAsync_DuplicateEmail_ShouldThrowDuplicateEmailException()
    {
        // Arrange
        var email = "test@example.com";
        _captchaValidatorMock.Setup(x => x.ValidateAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);
        _memberRepositoryMock.Setup(x => x.ExistsByIdNumberAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(false);
        _memberRepositoryMock.Setup(x => x.ExistsByEmailAsync(email, It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);

        // Act & Assert
        await Assert.ThrowsAsync<DuplicateEmailException>(() =>
            _sut.RegisterAsync("A123456789", "Test", email, "Password123", "valid"));
    }

    [Fact]
    public async Task GetMemberStatusAsync_MemberExists_ShouldReturnVerificationStatus()
    {
        // Arrange
        var memberId = Guid.NewGuid();
        var member = new Member { Id = memberId, IsEmailVerified = true };
        _memberRepositoryMock.Setup(x => x.GetByIdAsync(memberId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(member);

        // Act
        var result = await _sut.GetMemberStatusAsync(memberId);

        // Assert
        Assert.True(result);
    }

    [Fact]
    public async Task GetMemberStatusAsync_MemberNotExists_ShouldReturnFalse()
    {
        // Arrange
        var memberId = Guid.NewGuid();
        _memberRepositoryMock.Setup(x => x.GetByIdAsync(memberId, It.IsAny<CancellationToken>()))
            .ReturnsAsync((Member?)null);

        // Act
        var result = await _sut.GetMemberStatusAsync(memberId);

        // Assert
        Assert.False(result);
    }
}
