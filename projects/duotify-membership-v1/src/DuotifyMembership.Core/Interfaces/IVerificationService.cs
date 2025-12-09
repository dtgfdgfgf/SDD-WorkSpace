namespace DuotifyMembership.Core.Interfaces;

public interface IVerificationService
{
    Task<bool> VerifyCodeAsync(Guid memberId, string code);
    Task ResendCodeAsync(Guid memberId);
}
