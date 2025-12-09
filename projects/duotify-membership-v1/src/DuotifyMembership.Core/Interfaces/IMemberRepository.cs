using DuotifyMembership.Core.Entities;

namespace DuotifyMembership.Core.Interfaces;

public interface IMemberRepository
{
    Task<Member?> GetByIdAsync(Guid id);
    Task<Member?> GetByIdNumberAsync(string idNumber);
    Task<Member?> GetByEmailAsync(string email);
    Task<bool> ExistsByIdNumberAsync(string idNumber);
    Task<bool> ExistsByEmailAsync(string email);
    Task AddAsync(Member member);
    Task UpdateAsync(Member member);
    Task<IEnumerable<Member>> GetUnverifiedMembersOlderThanAsync(DateTime cutoffDate);
    Task DeleteAsync(Member member);
}
