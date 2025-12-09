using DuotifyMembership.Core.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace DuotifyMembership.Infrastructure.Data.Configurations;

public class VerificationCodeConfiguration : IEntityTypeConfiguration<VerificationCode>
{
    public void Configure(EntityTypeBuilder<VerificationCode> builder)
    {
        builder.ToTable("VerificationCodes");

        builder.HasKey(v => v.Id);

        builder.Property(v => v.MemberId)
            .IsRequired();

        builder.HasIndex(v => v.MemberId);

        builder.Property(v => v.Code)
            .IsRequired()
            .HasMaxLength(6);

        builder.Property(v => v.ExpiresAt)
            .IsRequired();

        builder.Property(v => v.IsUsed)
            .IsRequired();

        builder.Property(v => v.CreatedAt)
            .IsRequired();

        builder.HasOne<Member>()
            .WithMany()
            .HasForeignKey(v => v.MemberId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
