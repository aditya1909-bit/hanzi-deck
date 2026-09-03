namespace HanziDeck;

public enum WordPromptStyle { HanziRecognition, MeaningRecall, PinyinRecall }

public sealed class StudyPrompt
{
    public WordModel? Word { get; init; }
    public CharacterReviewModel? Character { get; init; }
    public WordPromptStyle Style { get; init; }
    public List<string> ContextLines { get; init; } = [];

    public ReviewStateModel ReviewState => Word?.ReviewState ?? Character!.ReviewState;

    public string Front => Word is not null
        ? Style switch
        {
            WordPromptStyle.MeaningRecall => Word.Meaning,
            WordPromptStyle.PinyinRecall => Word.Pinyin,
            _ => Word.Hanzi
        }
        : Character!.Glyph;
}

public sealed record StudyConfiguration(
    DeckModel Deck,
    LearningMethod Method,
    SessionKind SessionKind,
    List<StudyPrompt> Prompts);

public sealed class StudyQueue(List<StudyPrompt> prompts)
{
    public List<StudyPrompt> Prompts { get; } = [.. prompts];
    public int Index { get; private set; }
    public int ReviewedCount { get; private set; }
    public StudyPrompt? Current => Index < Prompts.Count ? Prompts[Index] : null;

    public void Advance(ReviewGrade grade)
    {
        if (Current is not { } current) return;
        if (grade == ReviewGrade.Again)
            Prompts.Insert(Math.Min(Index + 4, Prompts.Count), current);
        ReviewedCount++;
        Index++;
    }
}

public static class StudySessionBuilder
{
    public static int Count(DeckModel deck, LearningMethod method, SessionKind kind) =>
        Build(deck, method, kind, shuffle: false).Prompts.Count;

    public static StudyConfiguration Build(DeckModel deck, LearningMethod method,
        SessionKind kind, bool shuffle = true)
    {
        var prompts = method switch
        {
            LearningMethod.CharacterContext => CharacterPrompts(deck),
            LearningMethod.MixedReview => MixedPrompts(deck),
            _ => WordPrompts(deck, method)
        };

        prompts = Filter(prompts, kind);
        if (shuffle)
            prompts = prompts.OrderBy(_ => Random.Shared.Next()).ToList();
        if (kind == SessionKind.QuickCram) prompts = prompts.Take(20).ToList();
        return new StudyConfiguration(deck, method, kind, prompts);
    }

    private static List<StudyPrompt> WordPrompts(DeckModel deck, LearningMethod method)
    {
        var style = method switch
        {
            LearningMethod.MeaningRecall => WordPromptStyle.MeaningRecall,
            LearningMethod.PinyinRecall => WordPromptStyle.PinyinRecall,
            _ => WordPromptStyle.HanziRecognition
        };
        return deck.Words.Select(word => new StudyPrompt { Word = word, Style = style }).ToList();
    }

    private static List<StudyPrompt> CharacterPrompts(DeckModel deck) => deck.Characters
        .Select(character => new StudyPrompt
        {
            Character = character,
            ContextLines = deck.Words.SelectMany(word => word.Characters
                    .Where(context => context.Glyph == character.Glyph)
                    .Select(context => $"{context.Pinyin} — {word.Hanzi}"))
                .Distinct()
                .Order()
                .ToList()
        })
        .ToList();

    private static List<StudyPrompt> MixedPrompts(DeckModel deck)
    {
        var styles = new[]
        {
            WordPromptStyle.HanziRecognition,
            WordPromptStyle.MeaningRecall,
            WordPromptStyle.PinyinRecall
        };
        var words = deck.Words.Select((word, index) => new StudyPrompt
        {
            Word = word,
            Style = styles[index % styles.Length]
        });
        return words.Concat(CharacterPrompts(deck)).ToList();
    }

    private static List<StudyPrompt> Filter(List<StudyPrompt> prompts, SessionKind kind)
    {
        var now = DateTimeOffset.UtcNow;
        IEnumerable<StudyPrompt> filtered = kind switch
        {
            SessionKind.DueReviews => prompts.Where(prompt => prompt.ReviewState.DueAt <= now),
            SessionKind.LearnNew => prompts.Where(prompt =>
                prompt.ReviewState.Phase is ReviewPhase.New or ReviewPhase.Learning),
            SessionKind.DifficultPractice => prompts.Where(prompt =>
                prompt.ReviewState.Lapses > 0 || prompt.ReviewState.EaseFactor < 2),
            _ => prompts
        };
        return kind is SessionKind.DueReviews or SessionKind.LearnNew
            ? filtered.OrderBy(prompt => prompt.ReviewState.DueAt).ToList()
            : filtered.ToList();
    }
}
