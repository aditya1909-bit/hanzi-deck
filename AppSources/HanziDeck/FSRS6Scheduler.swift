import Foundation

enum FSRS6Scheduler {
    // Canonical FSRS-6 defaults from the Open Spaced Repetition project.
    private static let weights = [
        0.212, 1.2931, 2.3065, 8.2956, 6.4133, 0.8334, 3.0194,
        0.001, 1.8722, 0.1666, 0.796, 1.4835, 0.0614, 0.2629,
        1.6483, 0.6014, 1.8729, 0.5425, 0.0912, 0.0658, 0.1542
    ]

    static func apply(
        _ grade: ReviewGrade,
        to state: ReviewStateFields,
        desiredRetention: Double,
        now: Date
    ) {
        let previousPhase = state.phase
        let rating = grade.rawValue
        let isFirstReview = state.fsrsStability <= 0 || state.fsrsDifficulty <= 0

        if isFirstReview {
            state.fsrsStability = weights[rating - 1]
            state.fsrsDifficulty = initialDifficulty(rating: rating)
        } else {
            updateMemoryState(state, rating: rating, now: now)
        }

        let interval = nextInterval(
            stability: state.fsrsStability,
            desiredRetention: desiredRetention
        )
        state.intervalDays = Double(interval)

        if grade == .again {
            state.lapses += previousPhase == .review ? 1 : 0
            state.phase = previousPhase == .new || previousPhase == .learning
                ? .learning
                : .relearning
            let delay: TimeInterval = state.phase == .learning ? 60 : 10 * 60
            state.dueAt = now.addingTimeInterval(delay)
            return
        }

        if grade == .hard && (previousPhase == .new || previousPhase == .learning) {
            state.phase = .learning
            state.dueAt = now.addingTimeInterval(6 * 60)
            return
        }

        state.phase = .review
        state.repetitions += 1
        state.relearningBaseInterval = 0
        state.dueAt = now.addingTimeInterval(Double(interval) * Scheduler.day)
    }

    private static func updateMemoryState(
        _ state: ReviewStateFields,
        rating: Int,
        now: Date
    ) {
        let elapsedDays = max(
            0,
            now.timeIntervalSince(state.lastReviewAt ?? now) / Scheduler.day
        )
        let retrievability = recallProbability(
            elapsedDays: elapsedDays,
            stability: state.fsrsStability
        )
        let difficulty = nextDifficulty(current: state.fsrsDifficulty, rating: rating)

        let stability: Double
        if elapsedDays < 1 {
            stability = shortTermStability(current: state.fsrsStability, rating: rating)
        } else if rating == ReviewGrade.again.rawValue {
            stability = forgetStability(
                difficulty: difficulty,
                stability: state.fsrsStability,
                retrievability: retrievability
            )
        } else {
            stability = recallStability(
                difficulty: difficulty,
                stability: state.fsrsStability,
                retrievability: retrievability,
                rating: rating
            )
        }

        state.fsrsDifficulty = difficulty
        state.fsrsStability = max(0.001, stability)
    }

    private static func initialDifficulty(rating: Int) -> Double {
        clampDifficulty(weights[4] - exp(weights[5] * Double(rating - 1)) + 1)
    }

    private static func nextDifficulty(current: Double, rating: Int) -> Double {
        let delta = -(weights[6] * Double(rating - 3))
        let dampedDelta = (10 - current) * delta / 9
        let easyDifficulty = initialDifficulty(rating: ReviewGrade.easy.rawValue)
        return clampDifficulty(weights[7] * easyDifficulty + (1 - weights[7]) * (current + dampedDelta))
    }

    private static func recallProbability(elapsedDays: Double, stability: Double) -> Double {
        let decay = weights[20]
        let factor = pow(0.9, -1 / decay) - 1
        return pow(1 + factor * elapsedDays / max(0.001, stability), -decay)
    }

    private static func shortTermStability(current: Double, rating: Int) -> Double {
        var increase = exp(weights[17] * (Double(rating - 3) + weights[18]))
            * pow(current, -weights[19])
        if rating >= ReviewGrade.hard.rawValue {
            increase = max(1, increase)
        }
        return current * increase
    }

    private static func forgetStability(
        difficulty: Double,
        stability: Double,
        retrievability: Double
    ) -> Double {
        let longTerm = weights[11]
            * pow(difficulty, -weights[12])
            * (pow(stability + 1, weights[13]) - 1)
            * exp((1 - retrievability) * weights[14])
        let shortTerm = stability / exp(weights[17] * weights[18])
        return min(longTerm, shortTerm)
    }

    private static func recallStability(
        difficulty: Double,
        stability: Double,
        retrievability: Double,
        rating: Int
    ) -> Double {
        let hardPenalty = rating == ReviewGrade.hard.rawValue ? weights[15] : 1
        let easyBonus = rating == ReviewGrade.easy.rawValue ? weights[16] : 1
        return stability * (
            1
                + exp(weights[8])
                * (11 - difficulty)
                * pow(stability, -weights[9])
                * (exp((1 - retrievability) * weights[10]) - 1)
                * hardPenalty
                * easyBonus
        )
    }

    private static func nextInterval(
        stability: Double,
        desiredRetention: Double
    ) -> Int {
        let retention = min(0.97, max(0.70, desiredRetention))
        let decay = weights[20]
        let factor = pow(0.9, -1 / decay) - 1
        let interval = (stability / factor) * (pow(retention, -1 / decay) - 1)
        return min(36_500, max(1, Int(interval.rounded())))
    }

    private static func clampDifficulty(_ value: Double) -> Double {
        min(10, max(1, value))
    }
}
