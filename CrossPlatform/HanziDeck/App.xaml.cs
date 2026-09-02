namespace HanziDeck;

public partial class App : Application
{
    private readonly DeckListPage deckListPage;

    public App(DeckListPage deckListPage)
    {
        InitializeComponent();
        this.deckListPage = deckListPage;
        UserAppTheme = AppTheme.Dark;
    }

    protected override Window CreateWindow(IActivationState? activationState)
    {
        var navigation = new NavigationPage(deckListPage)
        {
            BarBackgroundColor = Theme.Background,
            BarTextColor = Theme.PrimaryText
        };
        return new Window(navigation) { Title = "Hanzi Deck" };
    }
}
