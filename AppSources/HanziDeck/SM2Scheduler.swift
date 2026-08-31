import Foundation

enum SM2Scheduler {
    static func apply(
        _ grade: ReviewGrade,
        to state: ReviewStateFields,
        now: Date
    ) {
        let quality = qualityScore(for: grade)
        updateEase(state, quality: quality)

        if quality < 3 {
            state.repetitions = 0
            state.lapses += 1
            state.intervalDays = 1
        } else {
            switch state.repetitions {
            case 0:
                state.intervalDays = 1
            case 1:
                state.intervalDays = 6
            default:
                state.intervalDays = max(1, (state.intervalDays * state.easeFactor).rounded())
            }
            state.repetitions += 1
        }

        state.phase = .review
        state.relearningBaseInterval = 0
        state.dueAt = now.addingTimeInterval(state.intervalDays * Scheduler.day)
    }

    private static func qualityScore(for grade: ReviewGrade) -> Int {
        switch grade {
        case .again: 1
        case .hard: 3
        case .good: 4
        case .easy: 5
        }
    }

    private static func updateEase(_ state: ReviewStateFields, quality: Int) {
        let difference = Double(5 - quality)
        let adjustment = 0.1 - difference * (0.08 + difference * 0.02)
        state.easeFactor = max(1.3, state.easeFactor + adjustment)
    }
}
