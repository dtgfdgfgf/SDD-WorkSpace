namespace DuotifyMembership.Core.Interfaces;

public interface ICaptchaValidator
{
    Task<bool> ValidateAsync(string captchaToken);
}
