using DuotifyMembership.Core.Interfaces;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace DuotifyMembership.Jobs;

public class CleanupUnverifiedMembersJob : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<CleanupUnverifiedMembersJob> _logger;
    private readonly TimeSpan _interval = TimeSpan.FromHours(24);

    public CleanupUnverifiedMembersJob(
        IServiceProvider serviceProvider,
        ILogger<CleanupUnverifiedMembersJob> logger)
    {
        _serviceProvider = serviceProvider;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("CleanupUnverifiedMembersJob is starting");

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await CleanupUnverifiedMembers(stoppingToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error occurred while cleaning up unverified members");
            }

            await Task.Delay(_interval, stoppingToken);
        }

        _logger.LogInformation("CleanupUnverifiedMembersJob is stopping");
    }

    private async Task CleanupUnverifiedMembers(CancellationToken cancellationToken)
    {
        using var scope = _serviceProvider.CreateScope();
        var memberRepository = scope.ServiceProvider.GetRequiredService<IMemberRepository>();

        var thresholdDate = DateTime.UtcNow.AddDays(-7);
        var unverifiedMembers = await memberRepository.GetUnverifiedMembersOlderThanAsync(thresholdDate, cancellationToken);

        var count = 0;
        foreach (var member in unverifiedMembers)
        {
            memberRepository.Remove(member);
            count++;
        }

        if (count > 0)
        {
            await memberRepository.SaveChangesAsync(cancellationToken);
            _logger.LogInformation("Cleaned up {Count} unverified members", count);
        }
        else
        {
            _logger.LogInformation("No unverified members to clean up");
        }
    }
}
