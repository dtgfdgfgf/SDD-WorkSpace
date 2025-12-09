using DuotifyMembership.Core.Entities;

namespace DuotifyMembership.Core.Interfaces;

public interface IVerificationCodeRepository
{
    Task<VerificationCode?> GetLatestByMemberIdAsync(Guid memberId);
    Task<VerificationCode?> GetValidCodeAsync(Guid memberId, string code);
    Task AddAsync(VerificationCode verificationCode);
    Task UpdateAsync(VerificationCode verificationCode);
    Task InvalidateAllByMemberIdAsync(Guid memberId);
}
