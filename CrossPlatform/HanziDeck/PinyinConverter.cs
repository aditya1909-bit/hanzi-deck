using System.Text;
using System.Text.RegularExpressions;

namespace HanziDeck;

public static partial class PinyinConverter
{
    private static readonly Dictionary<char, string[]> MarkedVowels = new()
    {
        ['a'] = ["a", "ā", "á", "ǎ", "à"],
        ['e'] = ["e", "ē", "é", "ě", "è"],
        ['i'] = ["i", "ī", "í", "ǐ", "ì"],
        ['o'] = ["o", "ō", "ó", "ǒ", "ò"],
        ['u'] = ["u", "ū", "ú", "ǔ", "ù"],
        ['ü'] = ["ü", "ǖ", "ǘ", "ǚ", "ǜ"]
    };

    public static string ToToneMarks(string numbered)
    {
        var normalized = numbered.Replace("u:", "ü", StringComparison.OrdinalIgnoreCase)
            .Replace('v', 'ü');
        return NumberedSyllable().Replace(normalized, match => MarkSyllable(match.Value));
    }

    public static List<string> Syllables(string pinyin) =>
        Regex.Matches(pinyin, @"[A-Za-züÜvV:āáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜńňǹḿ]+[1-5]?")
            .Select(match => ToToneMarks(match.Value))
            .Where(value => value.Length > 0)
            .ToList();

    private static string MarkSyllable(string syllable)
    {
        var tone = syllable[^1] - '0';
        var body = syllable[..^1];
        if (tone is 0 or 5) return body;
        var lower = body.ToLowerInvariant();
        var index = lower.IndexOf('a');
        if (index < 0) index = lower.IndexOf('e');
        if (index < 0)
        {
            var ou = lower.IndexOf("ou", StringComparison.Ordinal);
            index = ou >= 0 ? ou : LastVowelIndex(lower);
        }
        if (index < 0) return body;
        var vowel = lower[index];
        if (!MarkedVowels.TryGetValue(vowel, out var marks)) return body;
        var replacement = marks[tone];
        if (char.IsUpper(body[index])) replacement = replacement.ToUpperInvariant();
        var builder = new StringBuilder(body);
        builder.Remove(index, 1).Insert(index, replacement);
        return builder.ToString();
    }

    private static int LastVowelIndex(string text)
    {
        for (var index = text.Length - 1; index >= 0; index--)
            if ("aeiouü".Contains(text[index])) return index;
        return -1;
    }

    [GeneratedRegex(@"[A-Za-züÜvV:]+[1-5]")]
    private static partial Regex NumberedSyllable();
}
