using CommunityToolkit.Maui.Storage;
using System.Text;

namespace HanziDeck;

public sealed class DeckPage : ContentPage
{
    private readonly DeckModel deck;
    private readonly DeckStore store;
    private readonly DictionaryService dictionary;
    private readonly OcrService ocr;
    private readonly CollectionView cards;
    private readonly Label studyStatus;
    private readonly Label studyMethod;
    private readonly Button studyButton;
    private readonly Button wordsButton;
    private readonly Button charactersButton;
    private readonly Picker subsetPicker;
    private readonly Label wordCount;
    private readonly Label characterCount;
    private readonly Label dueCount;
    private LearningMethod method = LearningMethod.HanziRecognition;
    private bool showingWords = true;

    public DeckPage(DeckModel deck, DeckStore store, DictionaryService dictionary, OcrService ocr)
    {
        this.deck = deck;
        this.store = store;
        this.dictionary = dictionary;
        this.ocr = ocr;
        Title = deck.Name;

        var add = new ToolbarItem { Text = "Add" };
        add.Clicked += async (_, _) => await Navigation.PushAsync(
            new CardEditorPage(deck, store, dictionary, initialSubset: SelectedSubset));
        ToolbarItems.Add(add);
        var more = new ToolbarItem { Text = "•••" };
        more.Clicked += DeckOptions;
        ToolbarItems.Add(more);

        subsetPicker = new Picker { Title = "Deck part", HorizontalOptions = LayoutOptions.Fill };
        RefreshSubsetChoices();

        var metrics = new Grid
        {
            ColumnDefinitions =
            {
                new ColumnDefinition(GridLength.Star),
                new ColumnDefinition(GridLength.Star),
                new ColumnDefinition(GridLength.Star)
            }
        };
        wordCount = MetricValue();
        characterCount = MetricValue();
        dueCount = MetricValue();
        metrics.Add(Metric(wordCount, "Words"), 0);
        metrics.Add(Metric(characterCount, "Characters"), 1);
        metrics.Add(Metric(dueCount, "Due"), 2);

        studyStatus = new Label { FontSize = 18, FontAttributes = FontAttributes.Bold };
        studyMethod = Theme.Secondary("");
        var methodStack = new VerticalStackLayout { Spacing = 3, Children = { studyStatus, studyMethod } };
        var studyMore = new Button
        {
            Text = "•••",
            Style = (Style)Application.Current!.Resources["SecondaryButton"],
            WidthRequest = 54
        };
        studyMore.Clicked += StudyOptions;
        var studyHeader = new Grid
        {
            ColumnDefinitions =
            {
                new ColumnDefinition(GridLength.Star),
                new ColumnDefinition(GridLength.Auto)
            },
            Children = { methodStack, studyMore }
        };
        Grid.SetColumn(studyMore, 1);
        studyButton = new Button { Style = (Style)Application.Current.Resources["PrimaryButton"] };
        studyButton.Clicked += StartPrimaryStudy;
        var studyLayout = new VerticalStackLayout { Spacing = 12, Children = { studyHeader, studyButton } };

        subsetPicker.SelectedIndexChanged += (_, _) => Refresh();
        var newSubset = new Button
        {
            Text = "New Part",
            Style = (Style)Application.Current.Resources["SecondaryButton"]
        };
        newSubset.Clicked += NewSubset;
        var subsetRow = new Grid
        {
            ColumnSpacing = 8,
            ColumnDefinitions =
            {
                new ColumnDefinition(GridLength.Star),
                new ColumnDefinition(GridLength.Auto)
            },
            Children = { subsetPicker, newSubset }
        };
        Grid.SetColumn(newSubset, 1);

        wordsButton = new Button { Text = "Words" };
        charactersButton = new Button { Text = "Characters" };
        wordsButton.Clicked += (_, _) => { showingWords = true; Refresh(); };
        charactersButton.Clicked += (_, _) => { showingWords = false; Refresh(); };
        var mode = new Grid
        {
            ColumnSpacing = 8,
            ColumnDefinitions =
            {
                new ColumnDefinition(GridLength.Star),
                new ColumnDefinition(GridLength.Star)
            },
            Children = { wordsButton, charactersButton }
        };
        Grid.SetColumn(charactersButton, 1);

        cards = new CollectionView
        {
            SelectionMode = SelectionMode.None,
            ItemsLayout = new LinearItemsLayout(ItemsLayoutOrientation.Vertical) { ItemSpacing = 9 }
        };

        var metricsPanel = Theme.Panel(metrics, new Thickness(4, 14));
        var studyPanel = Theme.Panel(studyLayout);
        var page = new Grid
        {
            Padding = new Thickness(20),
            RowSpacing = 14,
            RowDefinitions =
            {
                new RowDefinition(GridLength.Auto),
                new RowDefinition(GridLength.Auto),
                new RowDefinition(GridLength.Auto),
                new RowDefinition(GridLength.Auto),
                new RowDefinition(GridLength.Star)
            },
            Children = { metricsPanel, studyPanel, subsetRow, mode, cards }
        };
        Grid.SetRow(studyPanel, 1);
        Grid.SetRow(subsetRow, 2);
        Grid.SetRow(mode, 3);
        Grid.SetRow(cards, 4);
        Content = page;
    }

    protected override void OnAppearing()
    {
        base.OnAppearing();
        Refresh();
    }

    private static Label MetricValue() => new()
    {
        FontSize = 20,
        FontAttributes = FontAttributes.Bold,
        HorizontalTextAlignment = TextAlignment.Center
    };

    private View Metric(Label value, string label) => new VerticalStackLayout
    {
        Spacing = 2,
        Children =
        {
            value,
            new Label
            {
                Text = label,
                FontSize = 12,
                TextColor = Theme.SecondaryText,
                HorizontalTextAlignment = TextAlignment.Center
            }
        }
    };

    private void Refresh()
    {
        var due = DueCount();
        wordCount.Text = ScopedWords().Count().ToString();
        characterCount.Text = ScopedCharacters().Count().ToString();
        dueCount.Text = due.ToString();
        studyStatus.Text = due == 0 ? "You’re caught up" : $"{due} card{(due == 1 ? "" : "s")} due";
        studyMethod.Text = method.Title();
        studyButton.Text = "Adaptive Learn";
        wordsButton.BackgroundColor = showingWords ? Theme.Orange : Theme.ElevatedSurface;
        wordsButton.TextColor = showingWords ? Theme.Background : Theme.PrimaryText;
        charactersButton.BackgroundColor = showingWords ? Theme.ElevatedSurface : Theme.Orange;
        charactersButton.TextColor = showingWords ? Theme.PrimaryText : Theme.Background;
        if (showingWords)
        {
            cards.ItemTemplate = new DataTemplate(CreateWordRow);
            cards.ItemsSource = ScopedWords().OrderBy(word => word.CreatedAt).ToList();
        }
        else
        {
            cards.ItemTemplate = new DataTemplate(CreateCharacterRow);
            cards.ItemsSource = ScopedCharacters().OrderBy(item => item.Glyph).ToList();
        }
    }

    private View CreateWordRow()
    {
        var hanzi = new Label { FontSize = 29, FontAttributes = FontAttributes.Bold, WidthRequest = 120 };
        var pinyin = new Label { TextColor = Theme.Orange, FontSize = 15 };
        var meaning = Theme.Secondary("");
        var detail = new VerticalStackLayout { Spacing = 3, Children = { pinyin, meaning } };
        var layout = new HorizontalStackLayout { Spacing = 16, Children = { hanzi, detail } };
        var panel = Theme.Panel(layout);
        panel.BindingContextChanged += (_, _) =>
        {
            if (panel.BindingContext is not WordModel word) return;
            hanzi.Text = word.Hanzi;
            pinyin.Text = word.Pinyin;
            meaning.Text = word.Meaning;
        };
        var tap = new TapGestureRecognizer();
        tap.Tapped += async (_, _) =>
        {
            if (panel.BindingContext is WordModel word)
                await Navigation.PushAsync(new CardEditorPage(deck, store, dictionary, word));
        };
        panel.GestureRecognizers.Add(tap);
        return panel;
    }

    private View CreateCharacterRow()
    {
        var glyph = new Label { FontSize = 40, FontAttributes = FontAttributes.Bold, WidthRequest = 64 };
        var contexts = Theme.Secondary("");
        var layout = new HorizontalStackLayout { Spacing = 16, Children = { glyph, contexts } };
        var panel = Theme.Panel(layout);
        panel.BindingContextChanged += (_, _) =>
        {
            if (panel.BindingContext is not CharacterReviewModel character) return;
            glyph.Text = character.Glyph;
            contexts.Text = string.Join("\n", ScopedWords().SelectMany(word => word.Characters
                    .Where(item => item.Glyph == character.Glyph)
                    .Select(item => $"{item.Pinyin} — {word.Hanzi}"))
                .Distinct());
        };
        return panel;
    }

    private string? SelectedSubset => subsetPicker.SelectedIndex switch
    {
        0 => null,
        1 => "",
        > 1 => (string)subsetPicker.SelectedItem,
        _ => null
    };

    private IEnumerable<WordModel> ScopedWords() => deck.Words
        .Where(word => SelectedSubset is null || word.SubsetName == SelectedSubset);

    private IEnumerable<CharacterReviewModel> ScopedCharacters() => deck.Characters
        .Where(character => SelectedSubset is null || ScopedWords().Any(word =>
            word.Characters.Any(context => context.Glyph == character.Glyph)));

    private int DueCount() => StudySessionBuilder.Count(
        deck, method, SessionKind.DueReviews, SelectedSubset);

    private async void StartPrimaryStudy(object? sender, EventArgs e)
    {
        await StartStudy(SessionKind.AdaptiveLearn);
    }

    private async Task StartStudy(SessionKind kind)
    {
        var configuration = StudySessionBuilder.Build(deck, method, kind, SelectedSubset);
        if (configuration.Prompts.Count == 0)
        {
            await DisplayAlertAsync("No Cards", "There are no cards for this session.", "OK");
            return;
        }
        await Navigation.PushModalAsync(new NavigationPage(new StudyPage(configuration, store))
        {
            BarBackgroundColor = Theme.Background,
            BarTextColor = Theme.PrimaryText
        });
    }

    private async void StudyOptions(object? sender, EventArgs e)
    {
        var choice = await DisplayActionSheetAsync("Study", "Cancel", null,
            "Choose Learning Method", "Adaptive Learn", "Due Reviews", "Learn New", "Difficult Practice",
            "Quick Cram", "Free Practice", "Scheduling Settings");
        switch (choice)
        {
            case "Choose Learning Method": await ChooseMethod(); break;
            case "Adaptive Learn": await StartStudy(SessionKind.AdaptiveLearn); break;
            case "Due Reviews": await StartStudy(SessionKind.DueReviews); break;
            case "Learn New": await StartStudy(SessionKind.LearnNew); break;
            case "Difficult Practice": await StartStudy(SessionKind.DifficultPractice); break;
            case "Quick Cram": await StartStudy(SessionKind.QuickCram); break;
            case "Free Practice": await StartStudy(SessionKind.FreePractice); break;
            case "Scheduling Settings": await ChooseScheduler(); break;
        }
    }

    private async Task ChooseMethod()
    {
        var choices = Enum.GetValues<LearningMethod>().Select(value => value.Title()).ToArray();
        var choice = await DisplayActionSheetAsync("Learning Method", "Cancel", null, choices);
        var selected = Enum.GetValues<LearningMethod>().FirstOrDefault(value => value.Title() == choice);
        if (choice is not null) method = selected;
        Refresh();
    }

    private async Task ChooseScheduler()
    {
        var choices = Enum.GetValues<SchedulerAlgorithm>().Select(value => value.Title()).ToArray();
        var choice = await DisplayActionSheetAsync("Scheduler", "Cancel", null, choices);
        if (choice is null) return;
        deck.SchedulerAlgorithm = Enum.GetValues<SchedulerAlgorithm>()
            .First(value => value.Title() == choice);
        if (deck.SchedulerAlgorithm == SchedulerAlgorithm.Fsrs6)
        {
            var retention = await DisplayPromptAsync("Target Retention", "Enter 70–97", "Save", "Cancel",
                initialValue: Math.Round(deck.DesiredRetention * 100).ToString(), keyboard: Keyboard.Numeric);
            if (double.TryParse(retention, out var percent))
                deck.DesiredRetention = Math.Clamp(percent / 100, .70, .97);
        }
        await store.SaveAsync();
    }

    private async void DeckOptions(object? sender, EventArgs e)
    {
        var choice = await DisplayActionSheetAsync(deck.Name, "Cancel", "Delete Deck",
            "Import from Images", "Export Deck", "New Deck Part", "Delete Current Part", "Rename Deck");
        switch (choice)
        {
            case "Import from Images":
                await Navigation.PushAsync(new ImageImportPage(deck, store, dictionary, ocr, SelectedSubset));
                break;
            case "Export Deck": await ExportDeck(); break;
            case "New Deck Part": await CreateSubset(); break;
            case "Delete Current Part": await DeleteSubset(); break;
            case "Rename Deck":
                var name = await DisplayPromptAsync("Rename Deck", "Deck name", "Save", "Cancel",
                    initialValue: deck.Name);
                if (!string.IsNullOrWhiteSpace(name))
                {
                    deck.Name = name.Trim();
                    Title = deck.Name;
                    await store.SaveAsync();
                }
                break;
            case "Delete Deck":
                if (await DisplayAlertAsync("Delete Deck?", "This removes its cards and review history.", "Delete", "Cancel"))
                {
                    store.DeleteDeck(deck);
                    await store.SaveAsync();
                    await Navigation.PopAsync();
                }
                break;
        }
    }

    private async void NewSubset(object? sender, EventArgs e) => await CreateSubset();

    private async Task CreateSubset()
    {
        var name = await DisplayPromptAsync("New Deck Part", "Part name", "Create", "Cancel");
        var clean = name?.Trim() ?? "";
        if (clean.Length == 0) return;
        if (!deck.Subsets.Contains(clean)) deck.Subsets.Add(clean);
        deck.Subsets = deck.Subsets.Distinct().Order().ToList();
        deck.UpdatedAt = DateTimeOffset.UtcNow;
        await store.SaveAsync();
        RefreshSubsetChoices(clean);
        Refresh();
    }

    private async Task DeleteSubset()
    {
        var selected = SelectedSubset;
        if (string.IsNullOrEmpty(selected)) return;
        if (!await DisplayAlertAsync("Delete this part?",
                "The words will remain in the deck as Unfiled.", "Delete", "Cancel")) return;
        foreach (var word in deck.Words.Where(word => word.SubsetName == selected))
            word.SubsetName = "";
        deck.Subsets.Remove(selected);
        deck.UpdatedAt = DateTimeOffset.UtcNow;
        await store.SaveAsync();
        RefreshSubsetChoices();
        Refresh();
    }

    private void RefreshSubsetChoices(string? select = null)
    {
        var current = select ?? (subsetPicker.SelectedIndex > 1 ? subsetPicker.SelectedItem as string : null);
        subsetPicker.ItemsSource = new[] { "All Cards", "Unfiled" }.Concat(deck.Subsets.Order()).ToList();
        subsetPicker.SelectedIndex = current is null
            ? 0
            : ((IList<string>)subsetPicker.ItemsSource).IndexOf(current);
    }

    private async Task ExportDeck()
    {
        await using var stream = new MemoryStream(Encoding.UTF8.GetBytes(store.Export(deck)));
        var filename = $"{deck.Name.Replace('/', '-')}.hanzideck.json";
        var result = await FileSaver.Default.SaveAsync(filename, stream, CancellationToken.None);
        if (!result.IsSuccessful)
            await DisplayAlertAsync("Couldn’t Export Deck", result.Exception?.Message ?? "The deck could not be saved.", "OK");
    }
}
