using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;

namespace HanziDeck;

public static partial class ChineseText
{
    public static IReadOnlyList<string> Ideographs(string text)
    {
        var result = new List<string>();
        foreach (var rune in text.EnumerateRunes())
            if (IsHan(rune.Value)) result.Add(rune.ToString());
        return result;
    }

    public static IReadOnlyList<string> Runs(string text) => HanRun()
        .Matches(text)
        .Select(match => match.Value)
        .Distinct()
        .ToList();

    private static bool IsHan(int scalar) =>
        scalar is >= 0x3400 and <= 0x4DBF or
        >= 0x4E00 and <= 0x9FFF or
        >= 0x20000 and <= 0x2FA1F;

    [GeneratedRegex(@"[\p{IsCJKUnifiedIdeographs}\p{IsCJKUnifiedIdeographsExtensionA}]+")]
    private static partial Regex HanRun();
}
