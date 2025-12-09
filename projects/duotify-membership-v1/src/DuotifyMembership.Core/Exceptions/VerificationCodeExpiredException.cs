namespace DuotifyMembership.Core.Exceptions;

public class VerificationCodeExpiredException : Exception
{
    public VerificationCodeExpiredException() 
        : base("驗證碼已過期，請重新取得")
    {
    }
}
