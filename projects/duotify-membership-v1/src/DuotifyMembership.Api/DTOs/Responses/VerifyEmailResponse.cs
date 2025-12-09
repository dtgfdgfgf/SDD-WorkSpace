namespace DuotifyMembership.Api.DTOs.Responses;

public class VerifyEmailResponse
{
    public bool IsVerified { get; set; }
    public string Message { get; set; } = string.Empty;
}
