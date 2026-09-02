namespace HanziDeck;

public static class Scheduler
{
    private static readonly double[] FsrsWeights =
    [
        0.212, 1.2931, 2.3065, 8.2956, 6.4133, 0.8334, 3.0194,
        0.001, 1.8722, 0.1666, 0.796, 1.4835, 0.0614, 0.2629,
        1.6483, 0.6014, 1.8729, 0.5425, 0.0912, 0.0658, 0.1542
    ];

    public static void Apply(ReviewGrade grade, ReviewStateModel state,
        SchedulerAlgorithm algorithm, double desiredRetention, DateTimeOffset? clock = null)
    {
        var now = clock ?? DateTimeOffset.UtcNow;
        switch (algorithm)
        {
            case SchedulerAlgorithm.Fsrs6: ApplyFsrs(grade, state, desiredRetention, now); break;
            case SchedulerAlgorithm.Sm2: ApplySm2(grade, state, now); break;
            case SchedulerAlgorithm.Leitner: ApplyLeitner(grade, state, now); break;
            default: ApplySimple(grade, state, now); break;
        }
        state.LastReviewAt = now;
    }

    private static void ApplySimple(ReviewGrade grade, ReviewStateModel state, DateTimeOffset now)
    {
        if (state.Phase is ReviewPhase.New or ReviewPhase.Learning)
        {
            switch (grade)
            {
                case ReviewGrade.Again: state.Phase = ReviewPhase.Learning; state.DueAt = now.AddMinutes(1); return;
                case ReviewGrade.Hard: state.Phase = ReviewPhase.Learning; state.DueAt = now.AddMinutes(6); return;
                case ReviewGrade.Good: Graduate(state, 1, now); return;
                case ReviewGrade.Easy: state.EaseFactor += .15; Graduate(state, 4, now); return;
            }
        }

        if (state.Phase == ReviewPhase.Relearning)
        {
            var baseInterval = Math.Max(1, state.RelearningBaseInterval);
            switch (grade)
            {
                case ReviewGrade.Again: state.DueAt = now.AddMinutes(10); return;
                case ReviewGrade.Hard: Schedule(state, 1, now); return;
                case ReviewGrade.Good: Schedule(state, baseInterval, now); return;
                case ReviewGrade.Easy: Schedule(state, Math.Max(4, Math.Round(baseInterval * 1.3)), now); return;
            }
        }

        var previous = Math.Max(1, state.IntervalDays);
        switch (grade)
        {
            case ReviewGrade.Again:
                state.Lapses++;
                state.EaseFactor = Math.Max(1.3, state.EaseFactor - .2);
                state.RelearningBaseInterval = Math.Max(1, Math.Round(previous * .5));
                state.IntervalDays = state.RelearningBaseInterval;
                state.Phase = ReviewPhase.Relearning;
                state.DueAt = now.AddMinutes(10);
                break;
            case ReviewGrade.Hard:
                state.EaseFactor = Math.Max(1.3, state.EaseFactor - .15);
                Schedule(state, Math.Max(previous + 1, Math.Round(previous * 1.2)), now);
                break;
            case ReviewGrade.Good:
                Schedule(state, Math.Max(previous + 1, Math.Round(previous * state.EaseFactor)), now);
                break;
            case ReviewGrade.Easy:
                var interval = Math.Max(previous + 2, Math.Round(previous * state.EaseFactor * 1.3));
                state.EaseFactor += .15;
                Schedule(state, interval, now);
                break;
        }
    }

    private static void ApplySm2(ReviewGrade grade, ReviewStateModel state, DateTimeOffset now)
    {
        var quality = grade switch { ReviewGrade.Again => 1, ReviewGrade.Hard => 3, ReviewGrade.Good => 4, _ => 5 };
        var difference = 5d - quality;
        state.EaseFactor = Math.Max(1.3, state.EaseFactor + .1 - difference * (.08 + difference * .02));
        if (quality < 3)
        {
            state.Repetitions = 0;
            state.Lapses++;
            state.IntervalDays = 1;
        }
        else
        {
            state.IntervalDays = state.Repetitions switch
            {
                0 => 1,
                1 => 6,
                _ => Math.Max(1, Math.Round(state.IntervalDays * state.EaseFactor))
            };
            state.Repetitions++;
        }
        Schedule(state, state.IntervalDays, now);
    }

    private static void ApplyLeitner(ReviewGrade grade, ReviewStateModel state, DateTimeOffset now)
    {
        int[] intervals = [1, 2, 4, 8, 16, 32, 64];
        var current = state is { Repetitions: > 0, LeitnerBox: >= 1 and <= 7 }
            ? state.LeitnerBox
            : Math.Clamp((int)Math.Floor(Math.Log2(Math.Max(1, state.IntervalDays))) + 1, 1, 7);
        if (grade == ReviewGrade.Again)
        {
            state.LeitnerBox = 1;
            state.Lapses++;
            state.Phase = ReviewPhase.Relearning;
            state.IntervalDays = 1;
            state.DueAt = now.AddMinutes(10);
            return;
        }
        state.LeitnerBox = grade switch
        {
            ReviewGrade.Hard => current,
            ReviewGrade.Good => Math.Min(7, current + 1),
            _ => Math.Min(7, current + 2)
        };
        if (grade != ReviewGrade.Hard) state.Repetitions++;
        Schedule(state, intervals[state.LeitnerBox - 1], now);
    }

    private static void ApplyFsrs(ReviewGrade grade, ReviewStateModel state,
        double desiredRetention, DateTimeOffset now)
    {
        var oldPhase = state.Phase;
        var rating = (int)grade;
        if (state.FsrsStability <= 0 || state.FsrsDifficulty <= 0)
        {
            state.FsrsStability = FsrsWeights[rating - 1];
            state.FsrsDifficulty = InitialDifficulty(rating);
        }
        else
        {
            var elapsed = Math.Max(0, (now - (state.LastReviewAt ?? now)).TotalDays);
            var decay = FsrsWeights[20];
            var factor = Math.Pow(.9, -1 / decay) - 1;
            var recall = Math.Pow(1 + factor * elapsed / Math.Max(.001, state.FsrsStability), -decay);
            var delta = -(FsrsWeights[6] * (rating - 3));
            var easyDifficulty = InitialDifficulty((int)ReviewGrade.Easy);
            var difficulty = ClampDifficulty(FsrsWeights[7] * easyDifficulty +
                (1 - FsrsWeights[7]) * (state.FsrsDifficulty + (10 - state.FsrsDifficulty) * delta / 9));
            double stability;
            if (elapsed < 1)
            {
                var increase = Math.Exp(FsrsWeights[17] * (rating - 3 + FsrsWeights[18])) *
                               Math.Pow(state.FsrsStability, -FsrsWeights[19]);
                if (rating >= (int)ReviewGrade.Hard) increase = Math.Max(1, increase);
                stability = state.FsrsStability * increase;
            }
            else if (grade == ReviewGrade.Again)
            {
                var longTerm = FsrsWeights[11] * Math.Pow(difficulty, -FsrsWeights[12]) *
                    (Math.Pow(state.FsrsStability + 1, FsrsWeights[13]) - 1) *
                    Math.Exp((1 - recall) * FsrsWeights[14]);
                stability = Math.Min(longTerm,
                    state.FsrsStability / Math.Exp(FsrsWeights[17] * FsrsWeights[18]));
            }
            else
            {
                var hardPenalty = grade == ReviewGrade.Hard ? FsrsWeights[15] : 1;
                var easyBonus = grade == ReviewGrade.Easy ? FsrsWeights[16] : 1;
                stability = state.FsrsStability * (1 + Math.Exp(FsrsWeights[8]) * (11 - difficulty) *
                    Math.Pow(state.FsrsStability, -FsrsWeights[9]) *
                    (Math.Exp((1 - recall) * FsrsWeights[10]) - 1) * hardPenalty * easyBonus);
            }
            state.FsrsDifficulty = difficulty;
            state.FsrsStability = Math.Max(.001, stability);
        }

        var interval = FsrsInterval(state.FsrsStability, desiredRetention);
        state.IntervalDays = interval;
        if (grade == ReviewGrade.Again)
        {
            if (oldPhase == ReviewPhase.Review) state.Lapses++;
            state.Phase = oldPhase is ReviewPhase.New or ReviewPhase.Learning
                ? ReviewPhase.Learning : ReviewPhase.Relearning;
            state.DueAt = state.Phase == ReviewPhase.Learning ? now.AddMinutes(1) : now.AddMinutes(10);
            return;
        }
        if (grade == ReviewGrade.Hard && oldPhase is ReviewPhase.New or ReviewPhase.Learning)
        {
            state.Phase = ReviewPhase.Learning;
            state.DueAt = now.AddMinutes(6);
            return;
        }
        state.Repetitions++;
        Schedule(state, interval, now);
    }

    private static double InitialDifficulty(int rating) =>
        ClampDifficulty(FsrsWeights[4] - Math.Exp(FsrsWeights[5] * (rating - 1)) + 1);

    private static double ClampDifficulty(double value) => Math.Clamp(value, 1, 10);

    private static int FsrsInterval(double stability, double retention)
    {
        retention = Math.Clamp(retention, .70, .97);
        var decay = FsrsWeights[20];
        var factor = Math.Pow(.9, -1 / decay) - 1;
        var interval = stability / factor * (Math.Pow(retention, -1 / decay) - 1);
        return Math.Clamp((int)Math.Round(interval), 1, 36500);
    }

    private static void Graduate(ReviewStateModel state, double interval, DateTimeOffset now)
    {
        state.Repetitions++;
        Schedule(state, interval, now);
    }

    private static void Schedule(ReviewStateModel state, double interval, DateTimeOffset now)
    {
        state.Phase = ReviewPhase.Review;
        state.IntervalDays = interval;
        state.RelearningBaseInterval = 0;
        state.DueAt = now.AddDays(interval);
    }
}
