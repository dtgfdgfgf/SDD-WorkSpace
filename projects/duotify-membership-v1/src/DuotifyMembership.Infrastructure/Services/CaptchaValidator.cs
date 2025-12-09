using DuotifyMembership.Core.Interfaces;
using Microsoft.Extensions.Logging;

namespace DuotifyMembership.Infrastructure.Services;

public class CaptchaValidator : ICaptchaValidator
{
    private readonly ILogger<CaptchaValidator> _logger;

    public CaptchaValidator(ILogger<CaptchaValidator> logger)
    {
        _logger = logger;
    }

    public async Task<bool> ValidateAsync(string token, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Validating CAPTCHA token");
        
        await Task.Delay(50, cancellationToken);
        
        if (string.IsNullOrWhiteSpace(token))
        {
            _logger.LogWarning("CAPTCHA validation failed: empty token");
            return false;
        }

        _logger.LogInformation("CAPTCHA validation successful");
        return true;
    }
}
