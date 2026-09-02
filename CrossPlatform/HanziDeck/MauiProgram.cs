using CommunityToolkit.Maui;
namespace HanziDeck;

public static class MauiProgram
{
    public static MauiApp CreateMauiApp()
    {
        var builder = MauiApp.CreateBuilder();
        builder
            .UseMauiApp<App>()
            .UseMauiCommunityToolkit();

        builder.Services.AddSingleton<DeckStore>();
        builder.Services.AddSingleton<DictionaryService>();
        builder.Services.AddSingleton<OcrService>();
        builder.Services.AddSingleton<DeckListPage>();

        return builder.Build();
    }
}
