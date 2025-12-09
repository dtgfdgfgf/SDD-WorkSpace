using DuotifyMembership.Core.Entities;
using DuotifyMembership.Core.Interfaces;
using DuotifyMembership.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace DuotifyMembership.Infrastructure.Repositories;

public class MemberRepository : IMemberRepository
{
    private readonly ApplicationDbContext _context;

    public MemberRepository(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<Member?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
    {
        return await _context.Members.FindAsync(new object[] { id }, cancellationToken);
    }

    public async Task<Member?> GetByIdNumberAsync(string idNumber, CancellationToken cancellationToken = default)
    {
        return await _context.Members.FirstOrDefaultAsync(m => m.IdNumber == idNumber, cancellationToken);
    }

    public async Task<Member?> GetByEmailAsync(string email, CancellationToken cancellationToken = default)
    {
        return await _context.Members.FirstOrDefaultAsync(m => m.Email == email, cancellationToken);
    }

    public async Task<bool> ExistsByIdNumberAsync(string idNumber, CancellationToken cancellationToken = default)
    {
        return await _context.Members.AnyAsync(m => m.IdNumber == idNumber, cancellationToken);
    }

    public async Task<bool> ExistsByEmailAsync(string email, CancellationToken cancellationToken = default)
    {
        return await _context.Members.AnyAsync(m => m.Email == email, cancellationToken);
    }

    public async Task AddAsync(Member member, CancellationToken cancellationToken = default)
    {
        await _context.Members.AddAsync(member, cancellationToken);
    }

    public void Update(Member member)
    {
        _context.Members.Update(member);
    }

    public void Remove(Member member)
    {
        _context.Members.Remove(member);
    }

    public async Task<IEnumerable<Member>> GetUnverifiedMembersOlderThanAsync(DateTime thresholdDate, CancellationToken cancellationToken = default)
    {
        return await _context.Members
            .Where(m => !m.IsEmailVerified && m.CreatedAt < thresholdDate)
            .ToListAsync(cancellationToken);
    }

    public async Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        return await _context.SaveChangesAsync(cancellationToken);
    }
}
