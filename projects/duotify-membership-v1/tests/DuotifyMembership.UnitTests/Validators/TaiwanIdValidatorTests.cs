using DuotifyMembership.Api.Validators;
using Xunit;

namespace DuotifyMembership.UnitTests.Validators;

public class TaiwanIdValidatorTests
{
    [Theory]
    [InlineData("A123456789", true)]
    [InlineData("B234567890", false)]
    [InlineData("F131104093", true)]
    [InlineData("Z199999999", false)]
    [InlineData("", false)]
    [InlineData(null, false)]
    [InlineData("12345", false)]
    [InlineData("A12345678", false)]
    [InlineData("A1234567890", false)]
    [InlineData("a123456789", false)]
    public void Validate_ShouldReturnExpectedResult(string idNumber, bool expected)
    {
        // Act
        var result = TaiwanIdValidator.Validate(idNumber);

        // Assert
        Assert.Equal(expected, result);
    }
}
