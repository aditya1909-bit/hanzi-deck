namespace HanziDeck;

public sealed class ImageImportPage : ContentPage
{
    private readonly DeckModel deck;
    private readonly DeckStore store;
    private readonly DictionaryService dictionary;
    private readonly OcrService ocr;
    private readonly Editor recognizedText;
    private readonly Label status;
    private readonly string subsetName;

    public ImageImportPage(
        DeckModel deck,
        DeckStore store,
        DictionaryService dictionary,
        OcrService ocr,
        string? subsetName = null)
    {
        this.deck = deck;
        this.store = store;
        this.dictionary = dictionary;
        this.ocr = ocr;
        this.subsetName = subsetName ?? "";
        Title = "Import from Images";

        recognizedText = new Editor
        {
            Placeholder = "Recognized Chinese words appear here. Put one word on each line.",
            AutoSize = EditorAutoSizeOption.TextChanges,
            MinimumHeightRequest = 220
        };
        status = Theme.Secondary("Choose screenshots or photos containing Chinese words.");
        var choose = new Button { Text = "Choose Images", Style = (Style)Application.Current!.Resources["SecondaryButton"] };
        choose.Clicked += ChooseImages;
        var import = new Button { Text = "Import All Words", Style = (Style)Application.Current.Resources["PrimaryButton"] };
        import.Clicked += ImportWords;

        Content = new ScrollView
        {
            Content = new VerticalStackLayout
            {
                Padding = new Thickness(22),
                Spacing = 14,
                Children =
                {
                    new Label { Text = "Scan several words at once", FontSize = 22, FontAttributes = FontAttributes.Bold },
                    status,
                    choose,
                    recognizedText,
                    Theme.Secondary("Review the text before importing. Unknown words are left for manual entry."),
                    import
                }
            }
        };
    }

    private async void ChooseImages(object? sender, EventArgs e)
    {
        try
        {
            var files = await MediaPicker.Default.PickPhotosAsync(new MediaPickerOptions
            {
                Title = "Choose Chinese screenshots",
                SelectionLimit = 20,
                MaximumWidth = 2400,
                MaximumHeight = 2400
            });
            if (files.Count == 0) return;
            status.Text = "Reading images…";
            var allRuns = new List<string>();
            foreach (var file in files.Take(20))
                allRuns.AddRange(ChineseText.Runs(await ocr.RecognizeAsync(file)));
            var words = allRuns.Distinct().ToList();
            recognizedText.Text = string.Join(Environment.NewLine, words);
            status.Text = words.Count == 0
                ? "No Chinese words were found."
                : $"Found {words.Count} possible word{(words.Count == 1 ? "" : "s")}.";
        }
        catch (Exception error)
        {
            await DisplayAlertAsync("Couldn’t Read Images", error.Message, "OK");
            status.Text = "Image recognition did not finish.";
        }
    }

    private async void ImportWords(object? sender, EventArgs e)
    {
        var words = ChineseText.Runs(recognizedText.Text ?? "");
        var imported = 0;
        var skipped = 0;
        foreach (var hanzi in words)
        {
            if (deck.Words.Any(word => word.Hanzi == hanzi)) { skipped++; continue; }
            var candidate = (await dictionary.LookupAsync(hanzi)).FirstOrDefault();
            if (candidate is null) { skipped++; continue; }
            var glyphs = ChineseText.Ideographs(hanzi);
            var syllables = PinyinConverter.Syllables(candidate.NumberedPinyin);
            var word = new WordModel
            {
                Hanzi = hanzi,
                Pinyin = candidate.Pinyin,
                Meaning = candidate.Meaning,
                SubsetName = subsetName,
                Characters = glyphs.Select((glyph, index) => new CharacterContextModel
                {
                    Glyph = glyph,
                    Position = index,
                    Pinyin = syllables.Count == glyphs.Count ? syllables[index] : candidate.Pinyin
                }).ToList()
            };
            store.AddOrUpdateWord(deck, word);
            imported++;
        }
        await store.SaveAsync();
        await DisplayAlertAsync("Import Complete", $"Added {imported} words. Skipped {skipped} unknown or duplicate entries.", "Done");
        if (imported > 0) await Navigation.PopAsync();
    }
}
