namespace DuotifyMembership.Api.DTOs.Responses;

public class MemberStatusResponse
{
    public Guid MemberId { get; set; }
    public bool IsEmailVerified { get; set; }
    public string Message { get; set; } = string.Empty;
}
