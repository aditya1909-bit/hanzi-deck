using HanziDeck;

static void Check(bool condition, string message)
{
    if (!condition) throw new InvalidOperationException(message);
}

Check(PinyinConverter.ToToneMarks("yin2 hang2") == "yín háng", "Tone-mark conversion failed.");
Check(PinyinConverter.Syllables("yín háng").SequenceEqual(["yín", "háng"]),
    "Tone-marked syllable splitting failed.");
Check(ChineseText.Ideographs("银行 123!").SequenceEqual(["银", "行"]), "Hanzi extraction failed.");

var now = new DateTimeOffset(2026, 1, 1, 12, 0, 0, TimeSpan.Zero);
var learning = new ReviewStateModel { DueAt = now };
Scheduler.Apply(ReviewGrade.Good, learning, SchedulerAlgorithm.Simple, .9, now);
Check(learning.Phase == ReviewPhase.Review && learning.IntervalDays == 1,
    "Simple scheduler graduation failed.");

var again = new ReviewStateModel
{
    Phase = ReviewPhase.Review,
    DueAt = now,
    IntervalDays = 10,
    EaseFactor = 1.35
};
Scheduler.Apply(ReviewGrade.Again, again, SchedulerAlgorithm.Simple, .9, now);
Check(again.Phase == ReviewPhase.Relearning && again.EaseFactor == 1.3 && again.Lapses == 1,
    "Simple scheduler relearning failed.");

var word = new WordModel
{
    Hanzi = "银行",
    Pinyin = "yín háng",
    Meaning = "bank",
    Characters =
    [
        new CharacterContextModel { Glyph = "银", Pinyin = "yín", Position = 0 },
        new CharacterContextModel { Glyph = "行", Pinyin = "háng", Position = 1 }
    ]
};
var deck = new DeckModel
{
    Name = "Test",
    Words = [word],
    Characters =
    [
        new CharacterReviewModel { Glyph = "银" },
        new CharacterReviewModel { Glyph = "行" }
    ]
};
var context = StudySessionBuilder.Build(deck, LearningMethod.CharacterContext, SessionKind.FreePractice, false);
Check(context.Prompts.Count == 2 && context.Prompts.Any(prompt => prompt.ContextLines.Contains("háng — 银行")),
    "Character context generation failed.");

Console.WriteLine("All Hanzi Deck cross-platform core checks passed.");
