namespace HanziDeck;

public sealed class StudyPage : ContentPage
{
    private readonly StudyConfiguration configuration;
    private readonly DeckStore store;
    private readonly Label progress;
    private readonly Label front;
    private readonly Label instruction;
    private readonly VerticalStackLayout answer;
    private readonly Button reveal;
    private readonly Grid grades;
    private int index;

    public StudyPage(StudyConfiguration configuration, DeckStore store)
    {
        this.configuration = configuration;
        this.store = store;
        Title = configuration.Deck.Name;

        var close = new ToolbarItem { Text = "Close" };
        close.Clicked += async (_, _) => await Navigation.PopModalAsync();
        ToolbarItems.Add(close);

        progress = Theme.Secondary("");
        progress.HorizontalTextAlignment = TextAlignment.Center;
        front = new Label
        {
            FontSize = 76,
            FontAttributes = FontAttributes.Bold,
            HorizontalTextAlignment = TextAlignment.Center,
            VerticalTextAlignment = TextAlignment.Center,
            LineBreakMode = LineBreakMode.WordWrap
        };
        instruction = Theme.Secondary("");
        instruction.HorizontalTextAlignment = TextAlignment.Center;
        answer = new VerticalStackLayout
        {
            Spacing = 10,
            HorizontalOptions = LayoutOptions.Fill,
            IsVisible = false
        };
        reveal = new Button { Text = "Reveal Answer", Style = (Style)Application.Current!.Resources["PrimaryButton"] };
        reveal.Clicked += RevealOrFinish;

        grades = new Grid
        {
            ColumnSpacing = 8,
            IsVisible = false,
            ColumnDefinitions =
            {
                new ColumnDefinition(GridLength.Star),
                new ColumnDefinition(GridLength.Star),
                new ColumnDefinition(GridLength.Star),
                new ColumnDefinition(GridLength.Star)
            }
        };
        foreach (var grade in Enum.GetValues<ReviewGrade>())
        {
            var captured = grade;
            var button = new Button
            {
                Text = grade.ToString(),
                Style = (Style)Application.Current.Resources[grade == ReviewGrade.Good ? "PrimaryButton" : "SecondaryButton"],
                FontSize = 12
            };
            button.Clicked += async (_, _) => await Rate(captured);
            grades.Add(button, (int)grade - 1);
        }

        var bottom = new VerticalStackLayout { Spacing = 12, Children = { reveal, grades } };
        var answerPanel = Theme.Panel(answer);
        var content = new Grid
        {
            Padding = new Thickness(24),
            RowDefinitions =
            {
                new RowDefinition(GridLength.Auto),
                new RowDefinition(GridLength.Star),
                new RowDefinition(GridLength.Auto),
                new RowDefinition(GridLength.Star),
                new RowDefinition(GridLength.Auto)
            },
            Children = { progress, front, instruction, answerPanel, bottom }
        };
        Grid.SetRow(front, 1);
        Grid.SetRow(instruction, 2);
        Grid.SetRow(answerPanel, 3);
        Grid.SetRow(bottom, 4);
        Content = content;
        ShowPrompt();
    }

    private void ShowPrompt()
    {
        if (index >= configuration.Prompts.Count)
        {
            ShowCompletion();
            return;
        }
        var prompt = configuration.Prompts[index];
        progress.Text = $"{configuration.SessionKind.Title()} · {index + 1} of {configuration.Prompts.Count}";
        front.Text = prompt.Front;
        front.FontSize = prompt.Character is not null ? 108 : prompt.Style == WordPromptStyle.MeaningRecall ? 38 : 76;
        instruction.Text = prompt.Character is not null
            ? "Recall the reading and source words."
            : prompt.Style switch
            {
                WordPromptStyle.MeaningRecall => "Recall the Chinese word.",
                WordPromptStyle.PinyinRecall => "Recall the characters and meaning.",
                _ => "Recall the pronunciation and meaning."
            };
        answer.Children.Clear();
        answer.IsVisible = false;
        reveal.IsVisible = true;
        grades.IsVisible = false;
    }

    private void Reveal()
    {
        var prompt = configuration.Prompts[index];
        if (prompt.Word is { } word)
        {
            if (prompt.Style != WordPromptStyle.HanziRecognition)
                answer.Add(AnswerLabel(word.Hanzi, 44));
            if (prompt.Style != WordPromptStyle.PinyinRecall)
            {
                var label = AnswerLabel(word.Pinyin, 24);
                label.TextColor = Theme.Orange;
                answer.Add(label);
            }
            if (prompt.Style != WordPromptStyle.MeaningRecall)
                answer.Add(AnswerLabel(word.Meaning, 18));
        }
        else
        {
            foreach (var line in prompt.ContextLines)
                answer.Add(AnswerLabel(line, 20));
        }
        answer.IsVisible = true;
        reveal.IsVisible = false;
        grades.IsVisible = true;
    }

    private async void RevealOrFinish(object? sender, EventArgs e)
    {
        if (index >= configuration.Prompts.Count)
            await Navigation.PopModalAsync();
        else
            Reveal();
    }

    private static Label AnswerLabel(string text, double size) => new()
    {
        Text = text,
        FontSize = size,
        HorizontalTextAlignment = TextAlignment.Center,
        TextColor = Theme.PrimaryText
    };

    private async Task Rate(ReviewGrade grade)
    {
        var prompt = configuration.Prompts[index];
        if (configuration.SessionKind.UpdatesSchedule())
        {
            Scheduler.Apply(grade, prompt.ReviewState,
                configuration.Deck.SchedulerAlgorithm, configuration.Deck.DesiredRetention);
            configuration.Deck.UpdatedAt = DateTimeOffset.UtcNow;
            await store.SaveAsync();
        }
        index++;
        ShowPrompt();
    }

    private void ShowCompletion()
    {
        progress.Text = "";
        front.Text = "✓";
        front.FontSize = 70;
        front.TextColor = Theme.Orange;
        instruction.Text = $"Session complete · {configuration.Prompts.Count} cards reviewed";
        answer.IsVisible = false;
        grades.IsVisible = false;
        reveal.Text = "Done";
        reveal.IsVisible = true;
    }
}
