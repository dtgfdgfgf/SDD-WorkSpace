using DuotifyMembership.Core.Entities;

namespace DuotifyMembership.Core.Interfaces;

public interface IMemberService
{
    Task<Member> RegisterAsync(string idNumber, string name, string email, string password, string? captchaToken);
    Task<Member?> GetMemberStatusAsync(Guid memberId);
}
