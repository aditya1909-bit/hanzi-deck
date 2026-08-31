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
}

struct StudyConfiguration: Identifiable {
    let id = UUID()
    let deckName: String
    let method: LearningMethod
    let sessionKind: StudySessionKind
    let schedulerAlgorithm: SchedulerAlgorithm
    let desiredRetention: Double
    let prompts: [StudyPrompt]

    var updatesSchedule: Bool { sessionKind.updatesSchedule }
}

@MainActor
enum StudySessionBuilder {
    static func build(
        deck: Deck,
        method: LearningMethod,
        kind: StudySessionKind,
        now: Date = .now
    ) -> StudyConfiguration {
        let wordCards = selectWords(from: deck.words, kind: kind, now: now)
        let characterCards = selectCharacters(from: deck.characters, kind: kind, now: now)
        let prompts: [StudyPrompt]

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
            prompts = (wordPrompts + characterCards.map(StudyPrompt.character)).shuffled()
        }

        return StudyConfiguration(
            deckName: deck.name,
            method: method,
            sessionKind: kind,
            schedulerAlgorithm: deck.schedulerAlgorithm,
            desiredRetention: deck.desiredRetention,
            prompts: prompts
        )
    }

    static func count(
        deck: Deck,
        method: LearningMethod,
        kind: StudySessionKind,
        now: Date = .now
    ) -> Int {
        switch method {
        case .hanziRecognition, .meaningRecall, .pinyinRecall:
            selectWords(from: deck.words, kind: kind, now: now).count
        case .characterContext:
            selectCharacters(from: deck.characters, kind: kind, now: now).count
        case .mixed:
            selectWords(from: deck.words, kind: kind, now: now).count
                + selectCharacters(from: deck.characters, kind: kind, now: now).count
        }
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
