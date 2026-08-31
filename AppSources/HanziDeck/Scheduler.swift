import Foundation

enum Scheduler {
    static let day: TimeInterval = 86_400

    static func apply(
        _ grade: ReviewGrade,
        to state: ReviewStateFields,
        now: Date = .now
    ) {
        switch state.phase {
        case .new, .learning:
            applyLearning(grade, to: state, now: now)
        case .review:
            applyReview(grade, to: state, now: now)
        case .relearning:
            applyRelearning(grade, to: state, now: now)
        }
    }

    private static func applyLearning(
        _ grade: ReviewGrade,
        to state: ReviewStateFields,
        now: Date
    ) {
        switch grade {
        case .again:
            state.phase = .learning
            state.dueAt = now.addingTimeInterval(60)
        case .hard:
            state.phase = .learning
            state.dueAt = now.addingTimeInterval(6 * 60)
        case .good:
            graduate(state, interval: 1, now: now)
        case .easy:
            state.easeFactor += 0.15
            graduate(state, interval: 4, now: now)
        }
    }

    private static func applyReview(
        _ grade: ReviewGrade,
        to state: ReviewStateFields,
        now: Date
    ) {
        let previous = max(1, state.intervalDays)
        switch grade {
        case .again:
            state.lapses += 1
            state.easeFactor = max(1.3, state.easeFactor - 0.20)
            state.relearningBaseInterval = max(1, (previous * 0.5).rounded())
            state.intervalDays = state.relearningBaseInterval
            state.phase = .relearning
            state.dueAt = now.addingTimeInterval(10 * 60)
        case .hard:
            state.easeFactor = max(1.3, state.easeFactor - 0.15)
            let interval = max(previous + 1, (previous * 1.2).rounded())
            scheduleReview(state, interval: interval, now: now)
        case .good:
            let interval = max(previous + 1, (previous * state.easeFactor).rounded())
            scheduleReview(state, interval: interval, now: now)
        case .easy:
            let interval = max(previous + 2, (previous * state.easeFactor * 1.3).rounded())
            state.easeFactor += 0.15
            scheduleReview(state, interval: interval, now: now)
        }
    }

    private static func applyRelearning(
        _ grade: ReviewGrade,
        to state: ReviewStateFields,
        now: Date
    ) {
        let base = max(1, state.relearningBaseInterval)
        switch grade {
        case .again:
            state.dueAt = now.addingTimeInterval(10 * 60)
        case .hard:
            scheduleReview(state, interval: 1, now: now)
        case .good:
            scheduleReview(state, interval: base, now: now)
        case .easy:
            scheduleReview(state, interval: max(4, (base * 1.3).rounded()), now: now)
        }
    }

    private static func graduate(
        _ state: ReviewStateFields,
        interval: Double,
        now: Date
    ) {
        state.repetitions += 1
        scheduleReview(state, interval: interval, now: now)
    }

    private static func scheduleReview(
        _ state: ReviewStateFields,
        interval: Double,
        now: Date
    ) {
        state.phase = .review
        state.intervalDays = interval
        state.relearningBaseInterval = 0
        state.dueAt = now.addingTimeInterval(interval * day)
    }
}
