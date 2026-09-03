using CommunityToolkit.Maui.Storage;

namespace HanziDeck;

public sealed class DeckListPage : ContentPage
{
    private readonly DeckStore store;
    private readonly DictionaryService dictionary;
    private readonly OcrService ocr;
    private readonly CollectionView deckList;
    private readonly SearchBar search;

    public DeckListPage(DeckStore store, DictionaryService dictionary, OcrService ocr)
    {
        this.store = store;
        this.dictionary = dictionary;
        this.ocr = ocr;
        Title = "Hanzi Deck";

        var logo = new Border
        {
            BackgroundColor = Theme.Surface,
            Stroke = Theme.Orange,
            StrokeThickness = 2,
            WidthRequest = 48,
            HeightRequest = 48,
            StrokeShape = new Microsoft.Maui.Controls.Shapes.RoundRectangle { CornerRadius = 12 },
            Content = new Label
            {
                Text = "字",
                FontSize = 26,
                FontAttributes = FontAttributes.Bold,
                HorizontalTextAlignment = TextAlignment.Center,
                VerticalTextAlignment = TextAlignment.Center
            }
        };
        var title = new VerticalStackLayout
        {
            Spacing = 1,
            VerticalOptions = LayoutOptions.Center,
            Children =
            {
                new Label { Text = "HANZI DECK", FontSize = 21, FontAttributes = FontAttributes.Bold },
                Theme.Secondary("Chinese character study")
            }
        };
        var add = new Button { Text = "+", Style = (Style)Application.Current!.Resources["PrimaryButton"] };
        add.Clicked += AddDeck;

        var header = new Grid
        {
            ColumnDefinitions =
            {
                new ColumnDefinition(GridLength.Auto),
                new ColumnDefinition(GridLength.Star),
                new ColumnDefinition(GridLength.Auto)
            },
            ColumnSpacing = 12
        };
        header.Add(logo, 0);
        header.Add(title, 1);
        header.Add(add, 2);

        search = new SearchBar
        {
            Placeholder = "Search decks",
            TextColor = Theme.PrimaryText,
            PlaceholderColor = Theme.SecondaryText,
            BackgroundColor = Theme.Surface
        };
        search.TextChanged += (_, _) => RefreshList();

        deckList = new CollectionView
        {
            SelectionMode = SelectionMode.None,
            EmptyView = EmptyState(),
            ItemsLayout = new LinearItemsLayout(ItemsLayoutOrientation.Vertical) { ItemSpacing = 10 },
            ItemTemplate = new DataTemplate(CreateDeckRow)
        };

        var import = new Button
        {
            Text = "Import Deck",
            Style = (Style)Application.Current.Resources["SecondaryButton"],
            HorizontalOptions = LayoutOptions.Start
        };
        import.Clicked += ImportDeck;

        Content = new Grid
        {
            Padding = new Thickness(22),
            RowSpacing = 16,
            RowDefinitions =
            {
                new RowDefinition(GridLength.Auto),
                new RowDefinition(GridLength.Auto),
                new RowDefinition(GridLength.Star),
                new RowDefinition(GridLength.Auto)
            },
            Children = { header, search, deckList, import }
        };
        Grid.SetRow(search, 1);
        Grid.SetRow(deckList, 2);
        Grid.SetRow(import, 3);
    }

    protected override async void OnAppearing()
    {
        base.OnAppearing();
        await store.LoadAsync();
        RefreshList();
        if (!Preferences.Default.Get("welcomeShown", false))
        {
            Preferences.Default.Set("welcomeShown", true);
            await DisplayAlertAsync("Welcome to Hanzi Deck",
                "Create a deck, add Chinese words, and the offline dictionary fills in pinyin and meaning. Split large decks into parts, then use Adaptive Learn for a personalized working set.", "Get Started");
        }
    }

    private View CreateDeckRow()
    {
        var name = new Label { FontSize = 18, FontAttributes = FontAttributes.Bold };
        var details = Theme.Secondary("");
        var arrow = new Label { Text = "›", FontSize = 26, TextColor = Theme.SecondaryText };
        var layout = new Grid
        {
            ColumnDefinitions =
            {
                new ColumnDefinition(GridLength.Star),
                new ColumnDefinition(GridLength.Auto)
            }
        };
        var labels = new VerticalStackLayout { Spacing = 4, Children = { name, details } };
        layout.Add(labels, 0);
        layout.Add(arrow, 1);
        var panel = Theme.Panel(layout);
        panel.BindingContextChanged += (_, _) =>
        {
            if (panel.BindingContext is not DeckModel deck) return;
            name.Text = deck.Name;
            var wordDue = deck.Words.Count(word => word.ReviewState.DueAt <= DateTimeOffset.UtcNow);
            var characterDue = deck.Characters.Count(item => item.ReviewState.DueAt <= DateTimeOffset.UtcNow);
            details.Text = $"{deck.Words.Count} words · {wordDue} word due · {characterDue} character due";
        };
        var tap = new TapGestureRecognizer();
        tap.Tapped += async (_, _) =>
        {
            if (panel.BindingContext is DeckModel deck)
                await Navigation.PushAsync(new DeckPage(deck, store, dictionary, ocr));
        };
        panel.GestureRecognizers.Add(tap);
        return panel;
    }

    private static View EmptyState() => new VerticalStackLayout
    {
        Spacing = 10,
        HorizontalOptions = LayoutOptions.Center,
        VerticalOptions = LayoutOptions.Center,
        Children =
        {
            new Label
            {
                Text = "字",
                FontSize = 58,
                TextColor = Theme.Orange,
                HorizontalTextAlignment = TextAlignment.Center
            },
            new Label
            {
                Text = "Create your first deck",
                FontSize = 20,
                FontAttributes = FontAttributes.Bold,
                HorizontalTextAlignment = TextAlignment.Center
            },
            Theme.Secondary("Your words and review progress stay on this device.")
        }
    };

    private void RefreshList()
    {
        var query = search.Text?.Trim() ?? "";
        deckList.ItemsSource = store.Decks
            .Where(deck => query.Length == 0 || deck.Name.Contains(query, StringComparison.CurrentCultureIgnoreCase))
            .OrderBy(deck => deck.Name, StringComparer.CurrentCultureIgnoreCase)
            .ToList();
    }

    private async void AddDeck(object? sender, EventArgs e)
    {
        var name = await DisplayPromptAsync("New Deck", "Deck name", "Create", "Cancel");
        if (string.IsNullOrWhiteSpace(name)) return;
        var deck = store.CreateDeck(name);
        await store.SaveAsync();
        RefreshList();
        await Navigation.PushAsync(new DeckPage(deck, store, dictionary, ocr));
    }

    private async void ImportDeck(object? sender, EventArgs e)
    {
        try
        {
            var file = await FilePicker.Default.PickAsync(new PickOptions { PickerTitle = "Import a Hanzi Deck" });
            if (file is null) return;
            await using var stream = await file.OpenReadAsync();
            using var reader = new StreamReader(stream);
            var deck = store.Import(await reader.ReadToEndAsync());
            await store.SaveAsync();
            RefreshList();
            await Navigation.PushAsync(new DeckPage(deck, store, dictionary, ocr));
        }
        catch (Exception error)
        {
            await DisplayAlertAsync("Couldn’t Import Deck", error.Message, "OK");
        }
    }
}
