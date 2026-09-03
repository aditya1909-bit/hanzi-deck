import Foundation

enum WordPromptStyle: CaseIterable {
    case hanziRecognition
    case meaningRecall
    case pinyinRecall
}

enum StudyPrompt: Identifiable {
    case word(WordCard, WordPromptStyle)
    case character(CharacterCard)

    var id: UUID {
        switch self {
        case .word(let card, _): card.id
        case .character(let card): card.id
        }
    }

    var reviewState: ReviewStateFields? {
        switch self {
        case .word(let card, _): card.reviewState
        case .character(let card): card.reviewState
        }
    }
}

struct StudyConfiguration: Identifiable {
    let id = UUID()
    let deckName: String
    let method: LearningMethod
    let sessionKind: StudySessionKind
    let schedulerAlgorithm: SchedulerAlgorithm
    let desiredRetention: Double
    let subsetName: String?
    let adaptiveProfile: AdaptiveProfile
    let prompts: [StudyPrompt]

    var updatesSchedule: Bool { sessionKind.updatesSchedule }
}

@MainActor
enum StudySessionBuilder {
    static func build(
        deck: Deck,
        method: LearningMethod,
        kind: StudySessionKind,
        subsetName: String? = nil,
        now: Date = .now
    ) -> StudyConfiguration {
        let wordsInScope = deck.words.filter { subsetName == nil || $0.subsetName == subsetName }
        let charactersInScope = deck.characters.filter { character in
            subsetName == nil || character.sourceContexts.contains {
                $0.sourceWord?.subsetName == subsetName
            }
        }
        let wordCards = selectWords(from: wordsInScope, kind: kind, now: now)
        let characterCards = selectCharacters(from: charactersInScope, kind: kind, now: now)
        var prompts: [StudyPrompt]

        switch method {
        case .hanziRecognition:
            prompts = wordCards.map { .word($0, .hanziRecognition) }
        case .meaningRecall:
            prompts = wordCards.map { .word($0, .meaningRecall) }
        case .pinyinRecall:
            prompts = wordCards.map { .word($0, .pinyinRecall) }
        case .characterContext:
            prompts = characterCards.map(StudyPrompt.character)
        case .mixed:
            let wordPrompts = wordCards.enumerated().map { index, card in
                let styles = WordPromptStyle.allCases
                return StudyPrompt.word(card, styles[index % styles.count])
            }
            prompts = wordPrompts + characterCards.map(StudyPrompt.character)
        }
        if kind == .adaptive {
            prompts = AdaptiveStudy.select(
                from: prompts,
                workingSetSize: deck.adaptiveProfile.workingSetSize,
                now: now
            )
        } else {
            prompts.shuffle()
        }

        return StudyConfiguration(
            deckName: deck.name,
            method: method,
            sessionKind: kind,
            schedulerAlgorithm: deck.schedulerAlgorithm,
            desiredRetention: deck.desiredRetention,
            subsetName: subsetName,
            adaptiveProfile: deck.adaptiveProfile,
            prompts: prompts
        )
    }

    static func count(
        deck: Deck,
        method: LearningMethod,
        kind: StudySessionKind,
        subsetName: String? = nil,
        now: Date = .now
    ) -> Int {
        build(
            deck: deck,
            method: method,
            kind: kind,
            subsetName: subsetName,
            now: now
        ).prompts.count
    }

    private static func selectWords(
        from cards: [WordCard],
        kind: StudySessionKind,
        now: Date
    ) -> [WordCard] {
        let selected = cards.filter { card in
            guard let state = card.reviewState else { return false }
            return includes(state, in: kind, now: now)
        }
        return order(selected, kind: kind) { ($0.reviewState, $0.createdAt) }
    }

    private static func selectCharacters(
        from cards: [CharacterCard],
        kind: StudySessionKind,
        now: Date
    ) -> [CharacterCard] {
        let selected = cards.filter { card in
            guard let state = card.reviewState else { return false }
            return includes(state, in: kind, now: now)
        }
        return order(selected, kind: kind) { ($0.reviewState, $0.createdAt) }
    }

    private static func includes(
        _ state: ReviewStateFields,
        in kind: StudySessionKind,
        now: Date
    ) -> Bool {
        switch kind {
        case .adaptive:
            true
        case .due:
            state.dueAt <= now
        case .newCards:
            state.phase == .new || state.phase == .learning
        case .difficult:
            state.lapses > 0 || state.easeFactor <= 2.0 || state.phase == .relearning
        case .cram, .freePractice:
            true
        }
    }

    private static func order<Card>(
        _ cards: [Card],
        kind: StudySessionKind,
        details: (Card) -> (ReviewStateFields?, Date)
    ) -> [Card] {
        switch kind {
        case .adaptive:
            cards
        case .due, .newCards:
            cards.sorted { left, right in
                let leftDetails = details(left)
                let rightDetails = details(right)
                let leftDue = leftDetails.0?.dueAt ?? .distantFuture
                let rightDue = rightDetails.0?.dueAt ?? .distantFuture
                return leftDue == rightDue
                    ? leftDetails.1 < rightDetails.1
                    : leftDue < rightDue
            }
        case .difficult:
            cards.sorted { left, right in
                let leftState = details(left).0
                let rightState = details(right).0
                if leftState?.lapses != rightState?.lapses {
                    return (leftState?.lapses ?? 0) > (rightState?.lapses ?? 0)
                }
                return (leftState?.easeFactor ?? 2.5) < (rightState?.easeFactor ?? 2.5)
            }
        case .cram:
            Array(cards.shuffled().prefix(20))
        case .freePractice:
            cards.shuffled()
        }
    }
}

enum AdaptiveStudy {
    static func select(
        from prompts: [StudyPrompt],
        workingSetSize: Int,
        now: Date
    ) -> [StudyPrompt] {
        let totalAttempts = prompts.reduce(0) { $0 + ($1.reviewState?.adaptiveAttempts ?? 0) }
        return Array(prompts
            .shuffled()
            .sorted {
                priority($0.reviewState, totalAttempts: totalAttempts, now: now)
                    > priority($1.reviewState, totalAttempts: totalAttempts, now: now)
            }
            .prefix(workingSetSize))
            .shuffled()
    }

    static func record(_ grade: ReviewGrade, to state: ReviewStateFields, deck: Deck) {
        let reward: Double = switch grade {
        case .again: 0
        case .hard: 0.35
        case .good: 0.75
        case .easy: 1
        }
        let learningRate = max(0.15, 0.5 / sqrt(Double(state.adaptiveAttempts + 1)))
        state.adaptiveMastery = min(1, max(0,
            state.adaptiveMastery + learningRate * (reward - state.adaptiveMastery)
        ))
        state.adaptiveAttempts += 1

        var profile = deck.adaptiveProfile
        if let previousGrade = ReviewGrade(rawValue: state.adaptivePreviousGradeRaw) {
            var policy = profile.policy(for: previousGrade)
            let observationRate = max(0.1, 0.5 / sqrt(Double(policy.observations + 1)))
            policy.successEstimate += observationRate * (reward - policy.successEstimate)
            let gapAdjustment: Double = switch grade {
            case .again: -0.45
            case .hard: -0.2
            case .good: 0.15
            case .easy: 0.3
            }
            policy.gap = min(10, max(1, policy.gap + gapAdjustment))
            policy.observations += 1
            profile.setPolicy(policy, for: previousGrade)
        }
        state.adaptivePreviousGradeRaw = grade.rawValue

        let profileRate = max(0.04, 0.25 / sqrt(Double(profile.ratingsCount + 1)))
        profile.rollingReward += profileRate * (reward - profile.rollingReward)
        let setAdjustment: Double = switch grade {
        case .again: -0.3
        case .hard: -0.1
        case .good: 0.08
        case .easy: 0.16
        }
        profile.workingSetEstimate = min(16, max(4, profile.workingSetEstimate + setAdjustment))
        profile.ratingsCount += 1
        deck.adaptiveProfile = profile
    }

    private static func priority(
        _ state: ReviewStateFields?,
        totalAttempts: Int,
        now: Date
    ) -> Double {
        guard let state else { return 0 }
        let need = 1 - state.adaptiveMastery
        let exploration = sqrt(
            log(Double(totalAttempts + 2)) / Double(state.adaptiveAttempts + 1)
        )
        let overdueDays = max(0, now.timeIntervalSince(state.dueAt) / Scheduler.day)
        let dueBoost = state.dueAt <= now ? 0.35 + min(0.3, overdueDays * 0.03) : 0
        let phaseBoost: Double = switch state.phase {
        case .new: 0.25
        case .learning: 0.2
        case .relearning: 0.4
        case .review: 0
        }
        let lapseBoost = min(0.25, Double(state.lapses) * 0.05)
        return need + 0.22 * exploration + dueBoost + phaseBoost + lapseBoost
    }
}

struct StudySessionQueue {
    private(set) var prompts: [StudyPrompt]
    private(set) var index = 0
    private(set) var reviewedCount = 0
    let adaptive: Bool
    let adaptiveProfile: AdaptiveProfile
    private var repeatCounts: [UUID: Int] = [:]

    init(
        prompts: [StudyPrompt],
        adaptive: Bool = false,
        adaptiveProfile: AdaptiveProfile = AdaptiveProfile()
    ) {
        self.prompts = prompts
        self.adaptive = adaptive
        self.adaptiveProfile = adaptiveProfile
    }

    var current: StudyPrompt? {
        prompts.indices.contains(index) ? prompts[index] : nil
    }

    mutating func advance(after grade: ReviewGrade) {
        guard let current else { return }
        if adaptive, shouldRepeat(grade, prompt: current) {
            let gap = max(1, Int(adaptiveProfile.policy(for: grade).gap.rounded()))
            let insertionIndex = min(index + gap + 1, prompts.count)
            prompts.insert(current, at: insertionIndex)
            repeatCounts[current.id, default: 0] += 1
        } else if grade == .again {
            let insertionIndex = min(index + 4, prompts.count)
            prompts.insert(current, at: insertionIndex)
        }
        reviewedCount += 1
        index += 1
    }

    private func shouldRepeat(_ grade: ReviewGrade, prompt: StudyPrompt) -> Bool {
        let policy = adaptiveProfile.policy(for: grade)
        let uncertainty = 1 / sqrt(Double(policy.observations + 1))
        let needToRetry = 1 - policy.successEstimate + 0.18 * uncertainty
        let limit: Int = switch grade {
        case .again: 4
        case .hard: 2
        case .good, .easy: 1
        }
        let threshold: Double = switch grade {
        case .again: 0
        case .hard: 0.28
        case .good: 0.38
        case .easy: 0.52
        }
        return repeatCounts[prompt.id, default: 0] < limit && needToRetry >= threshold
    }
}
