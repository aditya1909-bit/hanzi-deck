using System.Text.Json.Serialization;

namespace HanziDeck;

public enum LearningMethod
{
    HanziRecognition,
    MeaningRecall,
    PinyinRecall,
    CharacterContext,
    MixedReview
}

public enum SessionKind
{
    AdaptiveLearn,
    DueReviews,
    LearnNew,
    DifficultPractice,
    QuickCram,
    FreePractice
}

public enum ReviewGrade { Again = 1, Hard = 2, Good = 3, Easy = 4 }
public enum ReviewPhase { New, Learning, Review, Relearning }
public enum SchedulerAlgorithm { Fsrs6, Sm2, Leitner, Simple }

public sealed class AdaptiveGradePolicyModel
{
    public double SuccessEstimate { get; set; }
    public int Observations { get; set; }
    public double Gap { get; set; }
}

public sealed class AdaptiveProfileModel
{
    public double WorkingSetEstimate { get; set; } = 8;
    public double RollingReward { get; set; } = 0.65;
    public int RatingsCount { get; set; }
    public AdaptiveGradePolicyModel Again { get; set; } = new() { SuccessEstimate = 0.25, Gap = 3 };
    public AdaptiveGradePolicyModel Hard { get; set; } = new() { SuccessEstimate = 0.55, Gap = 4 };
    public AdaptiveGradePolicyModel Good { get; set; } = new() { SuccessEstimate = 0.82, Gap = 6 };
    public AdaptiveGradePolicyModel Easy { get; set; } = new() { SuccessEstimate = 0.94, Gap = 8 };

    [JsonIgnore]
    public int WorkingSetSize => Math.Clamp((int)Math.Round(WorkingSetEstimate), 4, 16);

    public AdaptiveGradePolicyModel Policy(ReviewGrade grade) => grade switch
    {
        ReviewGrade.Again => Again,
        ReviewGrade.Hard => Hard,
        ReviewGrade.Good => Good,
        _ => Easy
    };
}

public static class StudyNames
{
    public static string Title(this LearningMethod method) => method switch
    {
        LearningMethod.HanziRecognition => "Hanzi Recognition",
        LearningMethod.MeaningRecall => "Meaning Recall",
        LearningMethod.PinyinRecall => "Pinyin Recall",
        LearningMethod.CharacterContext => "Character Context",
        _ => "Mixed Review"
    };

    public static string Description(this LearningMethod method) => method switch
    {
        LearningMethod.HanziRecognition => "Chinese → pinyin and meaning",
        LearningMethod.MeaningRecall => "English → Chinese and pinyin",
        LearningMethod.PinyinRecall => "Pinyin → Chinese and meaning",
        LearningMethod.CharacterContext => "Character → readings and source words",
        _ => "A shuffled mix of every method"
    };

    public static string Title(this SessionKind kind) => kind switch
    {
        SessionKind.AdaptiveLearn => "Adaptive Learn",
        SessionKind.DueReviews => "Due Reviews",
        SessionKind.LearnNew => "Learn New",
        SessionKind.DifficultPractice => "Difficult Practice",
        SessionKind.QuickCram => "Quick Cram",
        _ => "Free Practice"
    };

    public static bool UpdatesSchedule(this SessionKind kind) =>
        kind is SessionKind.AdaptiveLearn or SessionKind.DueReviews or SessionKind.LearnNew;

    public static string Title(this SchedulerAlgorithm algorithm) => algorithm switch
    {
        SchedulerAlgorithm.Fsrs6 => "FSRS-6",
        SchedulerAlgorithm.Sm2 => "SM-2 Classic",
        SchedulerAlgorithm.Leitner => "Leitner Boxes",
        _ => "Simple"
    };

    public static string RawValue(this SchedulerAlgorithm algorithm) => algorithm switch
    {
        SchedulerAlgorithm.Fsrs6 => "fsrs6",
        SchedulerAlgorithm.Sm2 => "sm2",
        SchedulerAlgorithm.Leitner => "leitner",
        _ => "simple"
    };

    public static SchedulerAlgorithm SchedulerFromRaw(string value) => value switch
    {
        "sm2" => SchedulerAlgorithm.Sm2,
        "leitner" => SchedulerAlgorithm.Leitner,
        "simple" => SchedulerAlgorithm.Simple,
        _ => SchedulerAlgorithm.Fsrs6
    };
}

public sealed class DeckModel
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Name { get; set; } = "";
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;
    public string SchedulerAlgorithmRaw { get; set; } = "fsrs6";
    public double DesiredRetention { get; set; } = 0.9;
    public List<string> Subsets { get; set; } = [];
    public AdaptiveProfileModel AdaptiveProfile { get; set; } = new();
    public List<WordModel> Words { get; set; } = [];
    public List<CharacterReviewModel> Characters { get; set; } = [];

    [JsonIgnore]
    public SchedulerAlgorithm SchedulerAlgorithm
    {
        get => StudyNames.SchedulerFromRaw(SchedulerAlgorithmRaw);
        set => SchedulerAlgorithmRaw = value.RawValue();
    }
}

public sealed class WordModel
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Hanzi { get; set; } = "";
    public string Pinyin { get; set; } = "";
    public string Meaning { get; set; } = "";
    public string SubsetName { get; set; } = "";
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.UtcNow;
    public List<CharacterContextModel> Characters { get; set; } = [];
    public ReviewStateModel ReviewState { get; set; } = new();
}

public sealed class CharacterContextModel
{
    public string Glyph { get; set; } = "";
    public string Pinyin { get; set; } = "";
    public int Position { get; set; }
}

public sealed class CharacterReviewModel
{
    public string Glyph { get; set; } = "";
    public ReviewStateModel ReviewState { get; set; } = new();
}

public sealed class ReviewStateModel
{
    public DateTimeOffset DueAt { get; set; } = DateTimeOffset.UtcNow;
    public string PhaseRaw { get; set; } = "new";
    public double IntervalDays { get; set; }
    public double EaseFactor { get; set; } = 2.5;
    public int Repetitions { get; set; }
    public int Lapses { get; set; }
    public double RelearningBaseInterval { get; set; }
    public DateTimeOffset? LastReviewAt { get; set; }
    public double FsrsStability { get; set; }
    public double FsrsDifficulty { get; set; }
    public int LeitnerBox { get; set; } = 1;
    public double AdaptiveMastery { get; set; } = 0.5;
    public int AdaptiveAttempts { get; set; }
    public int AdaptivePreviousGradeRaw { get; set; }

    [JsonIgnore]
    public ReviewPhase Phase
    {
        get => PhaseRaw switch
        {
            "learning" => ReviewPhase.Learning,
            "review" => ReviewPhase.Review,
            "relearning" => ReviewPhase.Relearning,
            _ => ReviewPhase.New
        };
        set => PhaseRaw = value.ToString().ToLowerInvariant();
    }
}

public sealed class DeckArchive
{
    [JsonPropertyName("formatVersion")] public int FormatVersion { get; set; } = 1;
    [JsonPropertyName("exportedAt")] public DateTimeOffset ExportedAt { get; set; } = DateTimeOffset.UtcNow;
    [JsonPropertyName("name")] public string Name { get; set; } = "";
    [JsonPropertyName("createdAt")] public DateTimeOffset CreatedAt { get; set; }
    [JsonPropertyName("updatedAt")] public DateTimeOffset UpdatedAt { get; set; }
    [JsonPropertyName("schedulerAlgorithmRaw")] public string SchedulerAlgorithmRaw { get; set; } = "fsrs6";
    [JsonPropertyName("desiredRetention")] public double DesiredRetention { get; set; } = 0.9;
    [JsonPropertyName("subsetNames")] public List<string> SubsetNames { get; set; } = [];
    [JsonPropertyName("adaptiveProfile")] public AdaptiveProfileModel? AdaptiveProfile { get; set; }
    [JsonPropertyName("words")] public List<WordArchive> Words { get; set; } = [];
    [JsonPropertyName("characters")] public List<CharacterReviewArchive> Characters { get; set; } = [];
}

public sealed class WordArchive
{
    [JsonPropertyName("hanzi")] public string Hanzi { get; set; } = "";
    [JsonPropertyName("pinyin")] public string Pinyin { get; set; } = "";
    [JsonPropertyName("meaning")] public string Meaning { get; set; } = "";
    [JsonPropertyName("subsetName")] public string SubsetName { get; set; } = "";
    [JsonPropertyName("createdAt")] public DateTimeOffset CreatedAt { get; set; }
    [JsonPropertyName("updatedAt")] public DateTimeOffset UpdatedAt { get; set; }
    [JsonPropertyName("characters")] public List<CharacterContextArchive> Characters { get; set; } = [];
    [JsonPropertyName("reviewState")] public ReviewStateArchive? ReviewState { get; set; }
}

public sealed class CharacterContextArchive
{
    [JsonPropertyName("glyph")] public string Glyph { get; set; } = "";
    [JsonPropertyName("pinyin")] public string Pinyin { get; set; } = "";
    [JsonPropertyName("position")] public int Position { get; set; }
}

public sealed class CharacterReviewArchive
{
    [JsonPropertyName("glyph")] public string Glyph { get; set; } = "";
    [JsonPropertyName("reviewState")] public ReviewStateArchive? ReviewState { get; set; }
}

public sealed class ReviewStateArchive
{
    [JsonPropertyName("dueAt")] public DateTimeOffset DueAt { get; set; }
    [JsonPropertyName("phaseRaw")] public string PhaseRaw { get; set; } = "new";
    [JsonPropertyName("intervalDays")] public double IntervalDays { get; set; }
    [JsonPropertyName("easeFactor")] public double EaseFactor { get; set; } = 2.5;
    [JsonPropertyName("repetitions")] public int Repetitions { get; set; }
    [JsonPropertyName("lapses")] public int Lapses { get; set; }
    [JsonPropertyName("relearningBaseInterval")] public double RelearningBaseInterval { get; set; }
    [JsonPropertyName("lastReviewAt")] public DateTimeOffset? LastReviewAt { get; set; }
    [JsonPropertyName("fsrsStability")] public double FsrsStability { get; set; }
    [JsonPropertyName("fsrsDifficulty")] public double FsrsDifficulty { get; set; }
    [JsonPropertyName("leitnerBox")] public int LeitnerBox { get; set; } = 1;
    [JsonPropertyName("adaptiveMastery")] public double? AdaptiveMastery { get; set; }
    [JsonPropertyName("adaptiveAttempts")] public int? AdaptiveAttempts { get; set; }
    [JsonPropertyName("adaptivePreviousGradeRaw")] public int? AdaptivePreviousGradeRaw { get; set; }

    public ReviewStateModel ToModel() => new()
    {
        DueAt = DueAt,
        PhaseRaw = PhaseRaw,
        IntervalDays = Math.Max(0, IntervalDays),
        EaseFactor = Math.Max(1.3, EaseFactor),
        Repetitions = Math.Max(0, Repetitions),
        Lapses = Math.Max(0, Lapses),
        RelearningBaseInterval = Math.Max(0, RelearningBaseInterval),
        LastReviewAt = LastReviewAt,
        FsrsStability = Math.Max(0, FsrsStability),
        FsrsDifficulty = Math.Max(0, FsrsDifficulty),
        LeitnerBox = Math.Max(1, LeitnerBox),
        AdaptiveMastery = Math.Clamp(AdaptiveMastery ?? 0.5, 0, 1),
        AdaptiveAttempts = Math.Max(0, AdaptiveAttempts ?? 0),
        AdaptivePreviousGradeRaw = Enum.IsDefined(typeof(ReviewGrade), AdaptivePreviousGradeRaw ?? 0)
            ? AdaptivePreviousGradeRaw ?? 0
            : 0
    };

    public static ReviewStateArchive FromModel(ReviewStateModel state) => new()
    {
        DueAt = state.DueAt,
        PhaseRaw = state.PhaseRaw,
        IntervalDays = state.IntervalDays,
        EaseFactor = state.EaseFactor,
        Repetitions = state.Repetitions,
        Lapses = state.Lapses,
        RelearningBaseInterval = state.RelearningBaseInterval,
        LastReviewAt = state.LastReviewAt,
        FsrsStability = state.FsrsStability,
        FsrsDifficulty = state.FsrsDifficulty,
        LeitnerBox = state.LeitnerBox,
        AdaptiveMastery = state.AdaptiveMastery,
        AdaptiveAttempts = state.AdaptiveAttempts,
        AdaptivePreviousGradeRaw = state.AdaptivePreviousGradeRaw
    };
}
