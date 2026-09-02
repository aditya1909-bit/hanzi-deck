namespace HanziDeck;

internal static class Theme
{
    public static readonly Color Background = Color.FromArgb("#050505");
    public static readonly Color Surface = Color.FromArgb("#111111");
    public static readonly Color ElevatedSurface = Color.FromArgb("#191919");
    public static readonly Color Orange = Color.FromArgb("#FF8000");
    public static readonly Color PrimaryText = Color.FromArgb("#F5F5F5");
    public static readonly Color SecondaryText = Color.FromArgb("#A3A3A3");
    public static readonly Color Divider = Color.FromArgb("#292929");

    public static Border Panel(View content, Thickness? padding = null)
    {
        return new Border
        {
            BackgroundColor = Surface,
            Stroke = Divider,
            StrokeThickness = 1,
            Padding = padding ?? new Thickness(16),
            StrokeShape = new Microsoft.Maui.Controls.Shapes.RoundRectangle { CornerRadius = 12 },
            Content = content
        };
    }

    public static Label Secondary(string text, double size = 13) => new()
    {
        Text = text,
        TextColor = SecondaryText,
        FontSize = size
    };
}
