using System.Text.RegularExpressions;

namespace DuotifyMembership.Api.Validators;

public static class TaiwanIdValidator
{
    private static readonly Dictionary<char, int> CityCodeMap = new()
    {
        {'A', 10}, {'B', 11}, {'C', 12}, {'D', 13}, {'E', 14},
        {'F', 15}, {'G', 16}, {'H', 17}, {'I', 34}, {'J', 18},
        {'K', 19}, {'L', 20}, {'M', 21}, {'N', 22}, {'O', 35},
        {'P', 23}, {'Q', 24}, {'R', 25}, {'S', 26}, {'T', 27},
        {'U', 28}, {'V', 29}, {'W', 32}, {'X', 30}, {'Y', 31},
        {'Z', 33}
    };

    public static bool Validate(string idNumber)
    {
        if (string.IsNullOrWhiteSpace(idNumber) || idNumber.Length != 10)
            return false;

        // Check format: 1 letter + 9 digits
        if (!Regex.IsMatch(idNumber, @"^[A-Z][12]\d{8}$"))
            return false;

        char cityCode = idNumber[0];
        if (!CityCodeMap.TryGetValue(cityCode, out int cityValue))
            return false;

        // Calculate checksum
        int sum = (cityValue / 10) + (cityValue % 10) * 9;

        int[] weights = { 8, 7, 6, 5, 4, 3, 2, 1, 1 };
        for (int i = 0; i < 9; i++)
        {
            sum += (idNumber[i + 1] - '0') * weights[i];
        }

        return sum % 10 == 0;
    }
}
