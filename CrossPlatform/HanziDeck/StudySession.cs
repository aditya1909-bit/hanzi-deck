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
    string? SubsetName,
    List<StudyPrompt> Prompts);

public sealed class StudyQueue(
    List<StudyPrompt> prompts,
    bool adaptive = false,
    AdaptiveProfileModel? adaptiveProfile = null)
{
    public List<StudyPrompt> Prompts { get; } = [.. prompts];
    public int Index { get; private set; }
    public int ReviewedCount { get; private set; }
    public StudyPrompt? Current => Index < Prompts.Count ? Prompts[Index] : null;
    private readonly Dictionary<StudyPrompt, int> repeatCounts = [];

    public void Advance(ReviewGrade grade)
    {
        if (Current is not { } current) return;
        if (adaptive && ShouldRepeat(grade, current))
        {
            var gap = Math.Max(1, (int)Math.Round((adaptiveProfile ?? new()).Policy(grade).Gap));
            Prompts.Insert(Math.Min(Index + gap + 1, Prompts.Count), current);
            repeatCounts[current] = repeatCounts.GetValueOrDefault(current) + 1;
        }
        else if (grade == ReviewGrade.Again)
            Prompts.Insert(Math.Min(Index + 4, Prompts.Count), current);
        ReviewedCount++;
        Index++;
    }

    private bool ShouldRepeat(ReviewGrade grade, StudyPrompt prompt)
    {
        var policy = (adaptiveProfile ?? new()).Policy(grade);
        var uncertainty = 1 / Math.Sqrt(policy.Observations + 1.0);
        var needToRetry = 1 - policy.SuccessEstimate + 0.18 * uncertainty;
        var limit = grade switch
        {
            ReviewGrade.Again => 4,
            ReviewGrade.Hard => 2,
            _ => 1
        };
        var threshold = grade switch
        {
            ReviewGrade.Again => 0,
            ReviewGrade.Hard => 0.28,
            ReviewGrade.Good => 0.38,
            _ => 0.52
        };
        return repeatCounts.GetValueOrDefault(prompt) < limit && needToRetry >= threshold;
    }
}

public static class StudySessionBuilder
{
    public static int Count(DeckModel deck, LearningMethod method, SessionKind kind,
        string? subsetName = null) =>
        Build(deck, method, kind, subsetName, shuffle: false).Prompts.Count;

    public static StudyConfiguration Build(DeckModel deck, LearningMethod method,
        SessionKind kind, string? subsetName = null, bool shuffle = true)
    {
        var prompts = method switch
        {
            LearningMethod.CharacterContext => CharacterPrompts(deck, subsetName),
            LearningMethod.MixedReview => MixedPrompts(deck, subsetName),
            _ => WordPrompts(deck, method, subsetName)
        };

        prompts = Filter(prompts, kind);
        if (kind == SessionKind.AdaptiveLearn)
            prompts = AdaptiveStudy.Select(prompts, deck.AdaptiveProfile.WorkingSetSize);
        else if (shuffle)
            prompts = prompts.OrderBy(_ => Random.Shared.Next()).ToList();
        if (kind == SessionKind.QuickCram) prompts = prompts.Take(20).ToList();
        return new StudyConfiguration(deck, method, kind, subsetName, prompts);
    }

    private static List<StudyPrompt> WordPrompts(
        DeckModel deck, LearningMethod method, string? subsetName)
    {
        var style = method switch
        {
            LearningMethod.MeaningRecall => WordPromptStyle.MeaningRecall,
            LearningMethod.PinyinRecall => WordPromptStyle.PinyinRecall,
            _ => WordPromptStyle.HanziRecognition
        };
        return deck.Words
            .Where(word => subsetName is null || word.SubsetName == subsetName)
            .Select(word => new StudyPrompt { Word = word, Style = style })
            .ToList();
    }

    private static List<StudyPrompt> CharacterPrompts(DeckModel deck, string? subsetName) => deck.Characters
        .Where(character => subsetName is null || deck.Words.Any(word =>
            word.SubsetName == subsetName && word.Characters.Any(context => context.Glyph == character.Glyph)))
        .Select(character => new StudyPrompt
        {
            Character = character,
            ContextLines = deck.Words
                .Where(word => subsetName is null || word.SubsetName == subsetName)
                .SelectMany(word => word.Characters
                    .Where(context => context.Glyph == character.Glyph)
                    .Select(context => $"{context.Pinyin} — {word.Hanzi}"))
                .Distinct()
                .Order()
                .ToList()
        })
        .ToList();

    private static List<StudyPrompt> MixedPrompts(DeckModel deck, string? subsetName)
    {
        var styles = new[]
        {
            WordPromptStyle.HanziRecognition,
            WordPromptStyle.MeaningRecall,
            WordPromptStyle.PinyinRecall
        };
        var words = deck.Words
            .Where(word => subsetName is null || word.SubsetName == subsetName)
            .Select((word, index) => new StudyPrompt
        {
            Word = word,
            Style = styles[index % styles.Length]
        });
        return words.Concat(CharacterPrompts(deck, subsetName)).ToList();
    }

    private static List<StudyPrompt> Filter(List<StudyPrompt> prompts, SessionKind kind)
    {
        var now = DateTimeOffset.UtcNow;
        IEnumerable<StudyPrompt> filtered = kind switch
        {
            SessionKind.AdaptiveLearn => prompts,
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

public static class AdaptiveStudy
{
    public static List<StudyPrompt> Select(List<StudyPrompt> prompts, int workingSetSize)
    {
        var totalAttempts = prompts.Sum(prompt => prompt.ReviewState.AdaptiveAttempts);
        var now = DateTimeOffset.UtcNow;
        return prompts
            .OrderBy(_ => Random.Shared.Next())
            .OrderByDescending(prompt => Priority(prompt.ReviewState, totalAttempts, now))
            .Take(workingSetSize)
            .OrderBy(_ => Random.Shared.Next())
            .ToList();
    }

    public static void Record(ReviewGrade grade, ReviewStateModel state, DeckModel deck)
    {
        var reward = grade switch
        {
            ReviewGrade.Again => 0,
            ReviewGrade.Hard => 0.35,
            ReviewGrade.Good => 0.75,
            _ => 1
        };
        var learningRate = Math.Max(0.15, 0.5 / Math.Sqrt(state.AdaptiveAttempts + 1));
        state.AdaptiveMastery = Math.Clamp(
            state.AdaptiveMastery + learningRate * (reward - state.AdaptiveMastery), 0, 1);
        state.AdaptiveAttempts++;

        var profile = deck.AdaptiveProfile;
        if (Enum.IsDefined(typeof(ReviewGrade), state.AdaptivePreviousGradeRaw))
        {
            var previous = (ReviewGrade)state.AdaptivePreviousGradeRaw;
            var policy = profile.Policy(previous);
            var observationRate = Math.Max(0.1, 0.5 / Math.Sqrt(policy.Observations + 1));
            policy.SuccessEstimate += observationRate * (reward - policy.SuccessEstimate);
            policy.Gap = Math.Clamp(policy.Gap + (grade switch
            {
                ReviewGrade.Again => -0.45,
                ReviewGrade.Hard => -0.2,
                ReviewGrade.Good => 0.15,
                _ => 0.3
            }), 1, 10);
            policy.Observations++;
        }
        state.AdaptivePreviousGradeRaw = (int)grade;

        var profileRate = Math.Max(0.04, 0.25 / Math.Sqrt(profile.RatingsCount + 1));
        profile.RollingReward += profileRate * (reward - profile.RollingReward);
        profile.WorkingSetEstimate = Math.Clamp(profile.WorkingSetEstimate + (grade switch
        {
            ReviewGrade.Again => -0.3,
            ReviewGrade.Hard => -0.1,
            ReviewGrade.Good => 0.08,
            _ => 0.16
        }), 4, 16);
        profile.RatingsCount++;
    }

    private static double Priority(ReviewStateModel state, int totalAttempts, DateTimeOffset now)
    {
        var need = 1 - state.AdaptiveMastery;
        var exploration = Math.Sqrt(Math.Log(totalAttempts + 2.0) / (state.AdaptiveAttempts + 1.0));
        var overdueDays = Math.Max(0, (now - state.DueAt).TotalDays);
        var dueBoost = state.DueAt <= now ? 0.35 + Math.Min(0.3, overdueDays * 0.03) : 0;
        var phaseBoost = state.Phase switch
        {
            ReviewPhase.New => 0.25,
            ReviewPhase.Learning => 0.2,
            ReviewPhase.Relearning => 0.4,
            _ => 0
        };
        var lapseBoost = Math.Min(0.25, state.Lapses * 0.05);
        return need + 0.22 * exploration + dueBoost + phaseBoost + lapseBoost;
    }
}
