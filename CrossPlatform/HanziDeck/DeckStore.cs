using System.Text.Json;
using System.Text.Json.Serialization;

namespace HanziDeck;

public sealed class DeckStore
{
    private readonly SemaphoreSlim gate = new(1, 1);
    private readonly string storePath = Path.Combine(FileSystem.AppDataDirectory, "decks.json");
    private readonly JsonSerializerOptions options = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        PropertyNameCaseInsensitive = true,
        WriteIndented = true,
        Converters = { new PortableDateConverter() }
    };

    public List<DeckModel> Decks { get; private set; } = [];

    public async Task LoadAsync()
    {
        await gate.WaitAsync();
        try
        {
            if (!File.Exists(storePath)) return;
            await using var stream = File.OpenRead(storePath);
            Decks = await JsonSerializer.DeserializeAsync<List<DeckModel>>(stream, options) ?? [];
        }
        finally
        {
            gate.Release();
        }
    }

    public async Task SaveAsync()
    {
        await gate.WaitAsync();
        try
        {
            Directory.CreateDirectory(FileSystem.AppDataDirectory);
            await using var stream = File.Create(storePath);
            await JsonSerializer.SerializeAsync(stream, Decks, options);
        }
        finally
        {
            gate.Release();
        }
    }

    public DeckModel CreateDeck(string name)
    {
        var cleanName = name.Trim();
        var deck = new DeckModel { Name = UniqueName(cleanName) };
        Decks.Add(deck);
        return deck;
    }

    public void DeleteDeck(DeckModel deck) => Decks.Remove(deck);

    public void AddOrUpdateWord(DeckModel deck, WordModel word, Guid? replacingId = null)
    {
        if (deck.Words.Any(item => item.Hanzi == word.Hanzi && item.Id != replacingId))
            throw new InvalidOperationException("That word already exists in this deck.");

        if (replacingId is { } id)
        {
            var index = deck.Words.FindIndex(item => item.Id == id);
            if (index >= 0) deck.Words[index] = word;
            else deck.Words.Add(word);
        }
        else
        {
            deck.Words.Add(word);
        }

        RebuildCharacters(deck);
        deck.UpdatedAt = DateTimeOffset.UtcNow;
    }

    public void DeleteWord(DeckModel deck, WordModel word)
    {
        deck.Words.Remove(word);
        RebuildCharacters(deck);
        deck.UpdatedAt = DateTimeOffset.UtcNow;
    }

    public string Export(DeckModel deck)
    {
        var archive = new DeckArchive
        {
            Name = deck.Name,
            CreatedAt = deck.CreatedAt,
            UpdatedAt = deck.UpdatedAt,
            SchedulerAlgorithmRaw = deck.SchedulerAlgorithmRaw,
            DesiredRetention = deck.DesiredRetention,
            SubsetNames = deck.Subsets,
            AdaptiveProfile = deck.AdaptiveProfile,
            Words = deck.Words.Select(word => new WordArchive
            {
                Hanzi = word.Hanzi,
                Pinyin = word.Pinyin,
                Meaning = word.Meaning,
                SubsetName = word.SubsetName,
                CreatedAt = word.CreatedAt,
                UpdatedAt = word.UpdatedAt,
                Characters = word.Characters.Select(context => new CharacterContextArchive
                {
                    Glyph = context.Glyph,
                    Pinyin = context.Pinyin,
                    Position = context.Position
                }).ToList(),
                ReviewState = ReviewStateArchive.FromModel(word.ReviewState)
            }).ToList(),
            Characters = deck.Characters.Select(character => new CharacterReviewArchive
            {
                Glyph = character.Glyph,
                ReviewState = ReviewStateArchive.FromModel(character.ReviewState)
            }).ToList()
        };
        return JsonSerializer.Serialize(archive, options);
    }

    public DeckModel Import(string json)
    {
        var archive = JsonSerializer.Deserialize<DeckArchive>(json, options)
            ?? throw new InvalidDataException("This file is not a Hanzi Deck export.");
        if (archive.FormatVersion != 1 || string.IsNullOrWhiteSpace(archive.Name))
            throw new InvalidDataException("This deck export is not supported.");

        var deck = new DeckModel
        {
            Name = UniqueName(archive.Name),
            CreatedAt = archive.CreatedAt,
            UpdatedAt = archive.UpdatedAt,
            SchedulerAlgorithmRaw = archive.SchedulerAlgorithmRaw,
            DesiredRetention = Math.Clamp(archive.DesiredRetention, 0.70, 0.97),
            Subsets = archive.SubsetNames
                .Where(name => !string.IsNullOrWhiteSpace(name))
                .Select(name => name.Trim())
                .Distinct()
                .Order()
                .ToList(),
            AdaptiveProfile = archive.AdaptiveProfile ?? new AdaptiveProfileModel(),
            Words = archive.Words.Select(word => new WordModel
            {
                Hanzi = word.Hanzi,
                Pinyin = word.Pinyin,
                Meaning = word.Meaning,
                SubsetName = word.SubsetName?.Trim() ?? "",
                CreatedAt = word.CreatedAt,
                UpdatedAt = word.UpdatedAt,
                Characters = word.Characters.Select(context => new CharacterContextModel
                {
                    Glyph = context.Glyph,
                    Pinyin = context.Pinyin,
                    Position = context.Position
                }).ToList(),
                ReviewState = word.ReviewState?.ToModel() ?? new ReviewStateModel()
            }).ToList()
        };

        if (deck.Words.Any(word => string.IsNullOrWhiteSpace(word.Hanzi) ||
                                   string.IsNullOrWhiteSpace(word.Pinyin) ||
                                   string.IsNullOrWhiteSpace(word.Meaning)) ||
            deck.Words.Select(word => word.Hanzi).Distinct().Count() != deck.Words.Count)
            throw new InvalidDataException("This deck contains incomplete or duplicate cards.");

        RebuildCharacters(deck);
        foreach (var archived in archive.Characters)
        {
            var character = deck.Characters.FirstOrDefault(item => item.Glyph == archived.Glyph);
            if (character is not null && archived.ReviewState is not null)
                character.ReviewState = archived.ReviewState.ToModel();
        }
        Decks.Add(deck);
        return deck;
    }

    private string UniqueName(string proposed)
    {
        var clean = string.IsNullOrWhiteSpace(proposed) ? "Untitled Deck" : proposed.Trim();
        if (Decks.All(deck => deck.Name != clean)) return clean;
        var number = 1;
        while (true)
        {
            var suffix = number == 1 ? "Imported" : $"Imported {number}";
            var candidate = $"{clean} ({suffix})";
            if (Decks.All(deck => deck.Name != candidate)) return candidate;
            number++;
        }
    }

    private static void RebuildCharacters(DeckModel deck)
    {
        var existing = deck.Characters.ToDictionary(item => item.Glyph, item => item.ReviewState);
        deck.Characters = deck.Words
            .SelectMany(word => word.Characters)
            .Select(context => context.Glyph)
            .Distinct()
            .Select(glyph => new CharacterReviewModel
            {
                Glyph = glyph,
                ReviewState = existing.GetValueOrDefault(glyph) ?? new ReviewStateModel()
            })
            .OrderBy(item => item.Glyph)
            .ToList();
    }
}

internal sealed class PortableDateConverter : JsonConverter<DateTimeOffset>
{
    private const string Format = "yyyy-MM-dd'T'HH:mm:ss'Z'";

    public override DateTimeOffset Read(ref Utf8JsonReader reader, Type type, JsonSerializerOptions options) =>
        DateTimeOffset.Parse(reader.GetString()!, null, System.Globalization.DateTimeStyles.AssumeUniversal);

    public override void Write(Utf8JsonWriter writer, DateTimeOffset value, JsonSerializerOptions options) =>
        writer.WriteStringValue(value.UtcDateTime.ToString(Format, System.Globalization.CultureInfo.InvariantCulture));
}
