namespace DuotifyMembership.Core.Exceptions;

public class DuplicateEmailException : Exception
{
    public DuplicateEmailException(string email) 
        : base($"E-Mail {email} 已被註冊")
    {
    }
}
