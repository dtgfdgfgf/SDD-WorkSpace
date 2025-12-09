namespace DuotifyMembership.Api.DTOs.Responses;

public class RegisterMemberResponse
{
    public Guid MemberId { get; set; }
    public string Message { get; set; } = string.Empty;
}
