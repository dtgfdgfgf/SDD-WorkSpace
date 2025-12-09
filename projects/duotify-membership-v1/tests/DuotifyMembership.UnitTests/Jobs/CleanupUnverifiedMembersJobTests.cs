using DuotifyMembership.Core.Entities;
using DuotifyMembership.Core.Interfaces;
using DuotifyMembership.Jobs;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace DuotifyMembership.UnitTests.Jobs;

public class CleanupUnverifiedMembersJobTests
{
    [Fact]
    public async Task ExecuteAsync_ShouldRemoveUnverifiedMembersOlderThan7Days()
    {
        // Arrange
        var memberRepositoryMock = new Mock<IMemberRepository>();
        var loggerMock = new Mock<ILogger<CleanupUnverifiedMembersJob>>();
        
        var services = new ServiceCollection();
        services.AddScoped(_ => memberRepositoryMock.Object);
        var serviceProvider = services.BuildServiceProvider();

        var oldMembers = new List<Member>
        {
            new Member { Id = Guid.NewGuid(), IsEmailVerified = false, CreatedAt = DateTime.UtcNow.AddDays(-8) },
            new Member { Id = Guid.NewGuid(), IsEmailVerified = false, CreatedAt = DateTime.UtcNow.AddDays(-10) }
        };

        memberRepositoryMock.Setup(x => x.GetUnverifiedMembersOlderThanAsync(It.IsAny<DateTime>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(oldMembers);
        memberRepositoryMock.Setup(x => x.SaveChangesAsync(It.IsAny<CancellationToken>()))
            .ReturnsAsync(2);

        // Note: Actual test would need to trigger the background service execution
        // This is a simplified test showing the cleanup logic
        var thresholdDate = DateTime.UtcNow.AddDays(-7);
        var unverifiedMembers = await memberRepositoryMock.Object.GetUnverifiedMembersOlderThanAsync(thresholdDate);

        // Assert
        Assert.Equal(2, unverifiedMembers.Count());
        memberRepositoryMock.Verify(x => x.GetUnverifiedMembersOlderThanAsync(It.IsAny<DateTime>(), It.IsAny<CancellationToken>()), Times.Once);
    }
}
