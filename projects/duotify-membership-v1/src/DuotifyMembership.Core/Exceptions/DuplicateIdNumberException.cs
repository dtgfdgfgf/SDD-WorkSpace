namespace DuotifyMembership.Core.Exceptions;

public class DuplicateIdNumberException : Exception
{
    public DuplicateIdNumberException(string idNumber) 
        : base($"身分證字號 {idNumber} 已被註冊")
    {
    }
}
