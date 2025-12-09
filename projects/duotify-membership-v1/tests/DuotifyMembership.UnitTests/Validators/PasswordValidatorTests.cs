using DuotifyMembership.Api.Validators;
using Xunit;

namespace DuotifyMembership.UnitTests.Validators;

public class PasswordValidatorTests
{
    [Theory]
    [InlineData("Password1", true)]
    [InlineData("Abc12345", true)]
    [InlineData("MyP@ssw0rd", true)]
    [InlineData("password1", false)] // No uppercase
    [InlineData("PASSWORD1", false)] // No lowercase
    [InlineData("Password", false)]  // No digit
    [InlineData("Pass1", false)]     // Too short
    [InlineData("", false)]          // Empty
    [InlineData(null, false)]        // Null
    public void Validate_ShouldReturnExpectedResult(string password, bool expected)
    {
        // Act
        var result = PasswordValidator.Validate(password, out var errorMessage);

        // Assert
        Assert.Equal(expected, result);
        if (!expected)
        {
            Assert.NotNull(errorMessage);
        }
    }

    [Fact]
    public void Validate_PasswordTooLong_ShouldReturnFalse()
    {
        // Arrange
        var password = new string('A', 101) + "a1";

        // Act
        var result = PasswordValidator.Validate(password, out var errorMessage);

        // Assert
        Assert.False(result);
        Assert.Equal("密碼長度不可超過 100 個字元", errorMessage);
    }
}
