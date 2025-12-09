using DuotifyMembership.Core.Interfaces;
using Microsoft.Extensions.Logging;

namespace DuotifyMembership.Infrastructure.Services;

public class EmailService : IEmailService
{
    private readonly ILogger<EmailService> _logger;

    public EmailService(ILogger<EmailService> logger)
    {
        _logger = logger;
    }

    public async Task SendVerificationCodeAsync(string email, string code, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Sending verification code {Code} to {Email}", code, email);
        
        await Task.Delay(100, cancellationToken);
        
        _logger.LogInformation("Verification code sent successfully to {Email}", email);
    }
}
