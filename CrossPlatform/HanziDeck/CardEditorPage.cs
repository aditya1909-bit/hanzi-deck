namespace HanziDeck;

public sealed class CardEditorPage : ContentPage
{
    private readonly DeckModel deck;
    private readonly DeckStore store;
    private readonly DictionaryService dictionary;
    private readonly WordModel? existing;
    private readonly Entry hanzi;
    private readonly Entry pinyin;
    private readonly Editor meaning;
    private readonly Picker candidates;
    private readonly Label lookupStatus;
    private readonly VerticalStackLayout characterFields;
    private readonly List<Entry> characterPinyinEntries = [];
    private CancellationTokenSource? lookupCancellation;
    private IReadOnlyList<DictionaryCandidate> results = [];

    public CardEditorPage(DeckModel deck, DeckStore store, DictionaryService dictionary,
        WordModel? existing = null)
    {
        this.deck = deck;
        this.store = store;
        this.dictionary = dictionary;
        this.existing = existing;
        Title = existing is null ? "Add Word" : "Edit Word";

        hanzi = new Entry { Placeholder = "Chinese word", FontSize = 26, Text = existing?.Hanzi ?? "" };
        pinyin = new Entry { Placeholder = "Pinyin", Text = existing?.Pinyin ?? "" };
        meaning = new Editor
        {
            Placeholder = "English meaning",
            Text = existing?.Meaning ?? "",
            AutoSize = EditorAutoSizeOption.TextChanges,
            MinimumHeightRequest = 90
        };
        candidates = new Picker { Title = "Dictionary match" };
        candidates.SelectedIndexChanged += CandidateChanged;
        lookupStatus = Theme.Secondary("Type Chinese characters to look them up automatically.");
        characterFields = new VerticalStackLayout { Spacing = 8 };
        hanzi.TextChanged += HanziChanged;
        pinyin.TextChanged += (_, _) => RefreshCharacterFields();

        var save = new Button { Text = "Save Word", Style = (Style)Application.Current!.Resources["PrimaryButton"] };
        save.Clicked += Save;
        var delete = new Button
        {
            Text = "Delete Word",
            TextColor = Colors.IndianRed,
            BackgroundColor = Theme.ElevatedSurface,
            CornerRadius = 10,
            IsVisible = existing is not null
        };
        delete.Clicked += Delete;

        Content = new ScrollView
        {
            Content = new VerticalStackLayout
            {
                Padding = new Thickness(22),
                Spacing = 14,
                Children =
                {
                    Field("Chinese", hanzi),
                    lookupStatus,
                    candidates,
                    Field("Pinyin", pinyin),
                    Field("Meaning", meaning),
                    Field("Character readings", characterFields),
                    Theme.Secondary("Confirm the pronunciation used by each character in this word."),
                    Theme.Secondary("Pinyin and meaning are suggestions. You can change either before saving."),
                    save,
                    delete
                }
            }
        };
        RefreshCharacterFields(existing?.Characters.OrderBy(item => item.Position).Select(item => item.Pinyin).ToList());
    }

    private static View Field(string title, View control) => new VerticalStackLayout
    {
        Spacing = 6,
        Children =
        {
            new Label { Text = title, FontSize = 13, FontAttributes = FontAttributes.Bold },
            control
        }
    };

    private async void HanziChanged(object? sender, TextChangedEventArgs e)
    {
        lookupCancellation?.Cancel();
        lookupCancellation = new CancellationTokenSource();
        var token = lookupCancellation.Token;
        var entered = e.NewTextValue?.Trim() ?? "";
        RefreshCharacterFields();
        if (ChineseText.Ideographs(entered).Count == 0)
        {
            results = [];
            candidates.ItemsSource = null;
            lookupStatus.Text = "Enter at least one Chinese character.";
            return;
        }

        try
        {
            lookupStatus.Text = "Looking up…";
            await Task.Delay(250, token);
            results = await dictionary.LookupAsync(entered);
            if (token.IsCancellationRequested || entered != hanzi.Text?.Trim()) return;
            candidates.ItemsSource = results.Select(result => result.Display).ToList();
            if (results.Count > 0)
            {
                candidates.SelectedIndex = 0;
                lookupStatus.Text = results.Count == 1 ? "Dictionary match found" : $"{results.Count} dictionary matches";
            }
            else
            {
                lookupStatus.Text = "No dictionary match. Add pinyin and meaning manually.";
            }
        }
        catch (OperationCanceledException)
        {
        }
        catch
        {
            lookupStatus.Text = "Dictionary lookup is unavailable. You can still enter the details manually.";
        }
    }

    private void CandidateChanged(object? sender, EventArgs e)
    {
        if (candidates.SelectedIndex < 0 || candidates.SelectedIndex >= results.Count) return;
        var selected = results[candidates.SelectedIndex];
        pinyin.Text = selected.Pinyin;
        meaning.Text = selected.Meaning;
        RefreshCharacterFields(PinyinConverter.Syllables(selected.NumberedPinyin));
    }

    private async void Save(object? sender, EventArgs e)
    {
        var cleanHanzi = hanzi.Text?.Trim() ?? "";
        var cleanPinyin = pinyin.Text?.Trim() ?? "";
        var cleanMeaning = meaning.Text?.Trim() ?? "";
        var glyphs = ChineseText.Ideographs(cleanHanzi);
        var characterReadings = characterPinyinEntries.Select(entry => entry.Text?.Trim() ?? "").ToList();
        if (glyphs.Count == 0 || cleanPinyin.Length == 0 || cleanMeaning.Length == 0 ||
            characterReadings.Count != glyphs.Count || characterReadings.Any(string.IsNullOrWhiteSpace))
        {
            await DisplayAlertAsync("Complete This Card",
                "Chinese, pinyin, meaning, and each character reading are required.", "OK");
            return;
        }

        var promptChanged = existing is not null && existing.Hanzi != cleanHanzi;
        var word = new WordModel
        {
            Id = existing?.Id ?? Guid.NewGuid(),
            Hanzi = cleanHanzi,
            Pinyin = cleanPinyin,
            Meaning = cleanMeaning,
            CreatedAt = existing?.CreatedAt ?? DateTimeOffset.UtcNow,
            UpdatedAt = DateTimeOffset.UtcNow,
            ReviewState = existing is not null && !promptChanged ? existing.ReviewState : new ReviewStateModel(),
            Characters = glyphs.Select((glyph, index) => new CharacterContextModel
            {
                Glyph = glyph,
                Position = index,
                Pinyin = characterReadings[index]
            }).ToList()
        };

        try
        {
            store.AddOrUpdateWord(deck, word, existing?.Id);
            await store.SaveAsync();
            await Navigation.PopAsync();
        }
        catch (Exception error)
        {
            await DisplayAlertAsync("Couldn’t Save Word", error.Message, "OK");
        }
    }

    private void RefreshCharacterFields(IReadOnlyList<string>? preferred = null)
    {
        var glyphs = ChineseText.Ideographs(hanzi.Text ?? "");
        var inferred = preferred ?? PinyinConverter.Syllables(pinyin.Text ?? "");
        characterFields.Children.Clear();
        characterPinyinEntries.Clear();
        for (var index = 0; index < glyphs.Count; index++)
        {
            var entry = new Entry
            {
                Placeholder = "Contextual pinyin",
                Text = inferred.Count == glyphs.Count ? inferred[index] : "",
                HorizontalOptions = LayoutOptions.Fill
            };
            characterPinyinEntries.Add(entry);
            var row = new Grid
            {
                ColumnDefinitions =
                {
                    new ColumnDefinition(new GridLength(48)),
                    new ColumnDefinition(GridLength.Star)
                },
                ColumnSpacing = 10
            };
            row.Add(new Label
            {
                Text = glyphs[index],
                FontSize = 28,
                FontAttributes = FontAttributes.Bold,
                VerticalTextAlignment = TextAlignment.Center
            }, 0);
            row.Add(entry, 1);
            characterFields.Add(row);
        }
    }

    private async void Delete(object? sender, EventArgs e)
    {
        if (existing is null) return;
        if (!await DisplayAlertAsync("Delete Word?", "Its unused character cards will also be removed.", "Delete", "Cancel")) return;
        store.DeleteWord(deck, existing);
        await store.SaveAsync();
        await Navigation.PopAsync();
    }
}
