import Foundation

enum LeitnerScheduler {
    private static let intervals = [1, 2, 4, 8, 16, 32, 64]

    static func apply(
        _ grade: ReviewGrade,
        to state: ReviewStateFields,
        now: Date
    ) {
        let currentBox = normalizedBox(for: state)
        switch grade {
        case .again:
            state.leitnerBox = 1
            state.lapses += 1
            state.phase = .relearning
            state.intervalDays = 1
            state.dueAt = now.addingTimeInterval(10 * 60)
            return
        case .hard:
            state.leitnerBox = currentBox
        case .good:
            state.leitnerBox = min(7, currentBox + 1)
            state.repetitions += 1
        case .easy:
            state.leitnerBox = min(7, currentBox + 2)
            state.repetitions += 1
        }

        state.phase = .review
        state.relearningBaseInterval = 0
        state.intervalDays = Double(intervals[state.leitnerBox - 1])
        state.dueAt = now.addingTimeInterval(state.intervalDays * Scheduler.day)
    }

    private static func normalizedBox(for state: ReviewStateFields) -> Int {
        if (1...7).contains(state.leitnerBox), state.repetitions > 0 {
            return state.leitnerBox
        }
        let interval = max(1, state.intervalDays)
        return min(7, max(1, Int(log2(interval).rounded(.down)) + 1))
    }
}
