using DuotifyMembership.Core.Entities;
using DuotifyMembership.Core.Interfaces;
using DuotifyMembership.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;

namespace DuotifyMembership.Infrastructure.Repositories;

public class VerificationCodeRepository : IVerificationCodeRepository
{
    private readonly ApplicationDbContext _context;

    public VerificationCodeRepository(ApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<VerificationCode?> GetLatestByMemberIdAsync(Guid memberId, CancellationToken cancellationToken = default)
    {
        return await _context.VerificationCodes
            .Where(v => v.MemberId == memberId)
            .OrderByDescending(v => v.CreatedAt)
            .FirstOrDefaultAsync(cancellationToken);
    }

    public async Task<VerificationCode?> GetValidCodeAsync(Guid memberId, string code, CancellationToken cancellationToken = default)
    {
        var now = DateTime.UtcNow;
        return await _context.VerificationCodes
            .FirstOrDefaultAsync(v => v.MemberId == memberId 
                && v.Code == code 
                && !v.IsUsed 
                && v.ExpiresAt > now, cancellationToken);
    }

    public async Task AddAsync(VerificationCode verificationCode, CancellationToken cancellationToken = default)
    {
        await _context.VerificationCodes.AddAsync(verificationCode, cancellationToken);
    }

    public void Update(VerificationCode verificationCode)
    {
        _context.VerificationCodes.Update(verificationCode);
    }

    public async Task InvalidateAllForMemberAsync(Guid memberId, CancellationToken cancellationToken = default)
    {
        var codes = await _context.VerificationCodes
            .Where(v => v.MemberId == memberId && !v.IsUsed)
            .ToListAsync(cancellationToken);

        foreach (var code in codes)
        {
            code.IsUsed = true;
        }
    }

    public async Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        return await _context.SaveChangesAsync(cancellationToken);
    }
}
