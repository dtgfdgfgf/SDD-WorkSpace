namespace DuotifyMembership.Core.Interfaces;

public interface IEmailService
{
    Task SendVerificationCodeAsync(string email, string name, string code);
}
