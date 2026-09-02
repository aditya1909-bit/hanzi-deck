using SQLite;

namespace HanziDeck;

public sealed class DictionaryService
{
    private SQLiteAsyncConnection? connection;

    public async Task<IReadOnlyList<DictionaryCandidate>> LookupAsync(string hanzi)
    {
        var clean = hanzi.Trim();
        if (clean.Length == 0) return [];
        var database = await ConnectionAsync();
        var rows = await database.QueryAsync<DictionaryRow>(
            "SELECT traditional, simplified, pinyin, meaning FROM entries " +
            "WHERE simplified = ? OR traditional = ? " +
            "ORDER BY CASE WHEN simplified = ? THEN 0 ELSE 1 END, id LIMIT 12",
            clean, clean, clean);
        return rows.Select(row => new DictionaryCandidate(
                row.Traditional,
                row.Simplified,
                PinyinConverter.ToToneMarks(row.Pinyin),
                row.Pinyin,
                row.Meaning))
            .ToList();
    }

    private async Task<SQLiteAsyncConnection> ConnectionAsync()
    {
        if (connection is not null) return connection;
        var path = Path.Combine(FileSystem.AppDataDirectory, "cedict.sqlite");
        if (!File.Exists(path))
        {
            await using var bundled = await FileSystem.OpenAppPackageFileAsync("cedict.sqlite");
            await using var destination = File.Create(path);
            await bundled.CopyToAsync(destination);
        }
        connection = new SQLiteAsyncConnection(path, SQLiteOpenFlags.ReadOnly);
        return connection;
    }

    private sealed class DictionaryRow
    {
        [Column("traditional")] public string Traditional { get; set; } = "";
        [Column("simplified")] public string Simplified { get; set; } = "";
        [Column("pinyin")] public string Pinyin { get; set; } = "";
        [Column("meaning")] public string Meaning { get; set; } = "";
    }
}

public sealed record DictionaryCandidate(
    string Traditional,
    string Simplified,
    string Pinyin,
    string NumberedPinyin,
    string Meaning)
{
    public string Display => $"{Pinyin} — {Meaning}";
}
