namespace DuotifyMembership.Core.Exceptions;

public class VerificationCodeInvalidException : Exception
{
    public VerificationCodeInvalidException() 
        : base("驗證碼錯誤")
    {
    }
}
