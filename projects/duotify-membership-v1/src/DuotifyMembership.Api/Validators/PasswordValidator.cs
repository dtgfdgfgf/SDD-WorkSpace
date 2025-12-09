using System.Text.RegularExpressions;

namespace DuotifyMembership.Api.Validators;

public static class PasswordValidator
{
    public static bool Validate(string password, out string? errorMessage)
    {
        errorMessage = null;

        if (string.IsNullOrWhiteSpace(password))
        {
            errorMessage = "密碼不可為空";
            return false;
        }

        if (password.Length < 8)
        {
            errorMessage = "密碼長度至少為 8 個字元";
            return false;
        }

        if (password.Length > 100)
        {
            errorMessage = "密碼長度不可超過 100 個字元";
            return false;
        }

        bool hasUpper = Regex.IsMatch(password, @"[A-Z]");
        bool hasLower = Regex.IsMatch(password, @"[a-z]");
        bool hasDigit = Regex.IsMatch(password, @"\d");

        if (!hasUpper || !hasLower || !hasDigit)
        {
            errorMessage = "密碼必須包含大寫字母、小寫字母及數字";
            return false;
        }

        return true;
    }
}
