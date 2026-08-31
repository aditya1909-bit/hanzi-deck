import Foundation
import SwiftData

enum StudyMode: String, CaseIterable, Identifiable {
    case word = "Words"
    case character = "Characters"

    var id: String { rawValue }
}

enum LearningMethod: String, CaseIterable, Identifiable {
    case hanziRecognition
    case meaningRecall
    case pinyinRecall
    case characterContext
    case mixed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hanziRecognition: "Hanzi Recognition"
        case .meaningRecall: "Meaning Recall"
        case .pinyinRecall: "Pinyin Recall"
        case .characterContext: "Character Context"
        case .mixed: "Mixed Review"
        }
    }

    var shortDescription: String {
        switch self {
        case .hanziRecognition: "Chinese → pinyin and meaning"
        case .meaningRecall: "English → Chinese and pinyin"
        case .pinyinRecall: "Pinyin → Chinese and meaning"
        case .characterContext: "Character → readings and source words"
        case .mixed: "A shuffled mix of every method"
        }
    }

    var symbol: String {
        switch self {
        case .hanziRecognition: "character.cursor.ibeam"
        case .meaningRecall: "text.bubble"
        case .pinyinRecall: "waveform"
        case .characterContext: "square.grid.2x2"
        case .mixed: "shuffle"
        }
    }
}

enum StudySessionKind: String, CaseIterable, Identifiable {
    case due
    case newCards
    case difficult
    case cram
    case freePractice

    var id: String { rawValue }

    var title: String {
        switch self {
        case .due: "Due Reviews"
        case .newCards: "Learn New"
        case .difficult: "Difficult Practice"
        case .cram: "Quick Cram"
        case .freePractice: "Free Practice"
        }
    }

    var description: String {
        switch self {
        case .due: "Review everything currently due"
        case .newCards: "Focus on unseen and learning cards"
        case .difficult: "Practice lapsed and low-ease cards"
        case .cram: "Review up to 20 random cards"
        case .freePractice: "Shuffle and review the entire deck"
        }
    }

    var symbol: String {
        switch self {
        case .due: "clock"
        case .newCards: "sparkles"
        case .difficult: "exclamationmark.triangle"
        case .cram: "bolt"
        case .freePractice: "infinity"
        }
    }

    var updatesSchedule: Bool {
        self == .due || self == .newCards
    }
}

enum ReviewPhase: String {
    case new
    case learning
    case review
    case relearning
}

enum ReviewGrade: Int, CaseIterable, Identifiable {
    case again = 1
    case hard = 2
    case good = 3
    case easy = 4

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .again: "Again"
        case .hard: "Hard"
        case .good: "Good"
        case .easy: "Easy"
        }
    }
}

@Model
final class Deck {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \WordCard.deck)
    var wordCards: [WordCard]

    @Relationship(deleteRule: .cascade, inverse: \CharacterCard.deck)
    var characterCards: [CharacterCard]

    init(name: String, now: Date = .now) {
        id = UUID()
        self.name = name
        createdAt = now
        updatedAt = now
        wordCards = []
        characterCards = []
    }
}

@Model
final class WordCard {
    @Attribute(.unique) var id: UUID
    var hanzi: String
    var pinyin: String
    var meaning: String
    var createdAt: Date
    var updatedAt: Date
    var deck: Deck?

    @Relationship(deleteRule: .cascade, inverse: \WordReviewState.card)
    var reviewState: WordReviewState?

    @Relationship(deleteRule: .cascade, inverse: \CharacterContext.sourceWord)
    var characterContexts: [CharacterContext]

    init(hanzi: String, pinyin: String, meaning: String, deck: Deck, now: Date = .now) {
        id = UUID()
        self.hanzi = hanzi
        self.pinyin = pinyin
        self.meaning = meaning
        createdAt = now
        updatedAt = now
        self.deck = deck
        characterContexts = []
    }
}

@Model
final class CharacterCard {
    @Attribute(.unique) var id: UUID
    var glyph: String
    var createdAt: Date
    var deck: Deck?

    @Relationship(deleteRule: .cascade, inverse: \CharacterReviewState.card)
    var reviewState: CharacterReviewState?

    @Relationship(deleteRule: .cascade, inverse: \CharacterContext.characterCard)
    var contexts: [CharacterContext]

    init(glyph: String, deck: Deck, now: Date = .now) {
        id = UUID()
        self.glyph = glyph
        createdAt = now
        self.deck = deck
        contexts = []
    }
}

@Model
final class CharacterContext {
    @Attribute(.unique) var id: UUID
    var pinyin: String
    var position: Int
    var characterCard: CharacterCard?
    var sourceWord: WordCard?

    init(pinyin: String, position: Int, characterCard: CharacterCard, sourceWord: WordCard) {
        id = UUID()
        self.pinyin = pinyin
        self.position = position
        self.characterCard = characterCard
        self.sourceWord = sourceWord
    }
}

protocol ReviewStateFields: AnyObject {
    var dueAt: Date { get set }
    var phaseRaw: String { get set }
    var intervalDays: Double { get set }
    var easeFactor: Double { get set }
    var repetitions: Int { get set }
    var lapses: Int { get set }
    var relearningBaseInterval: Double { get set }
}

extension ReviewStateFields {
    var phase: ReviewPhase {
        get { ReviewPhase(rawValue: phaseRaw) ?? .new }
        set { phaseRaw = newValue.rawValue }
    }
}

@Model
final class WordReviewState: ReviewStateFields {
    @Attribute(.unique) var id: UUID
    var dueAt: Date
    var phaseRaw: String
    var intervalDays: Double
    var easeFactor: Double
    var repetitions: Int
    var lapses: Int
    var relearningBaseInterval: Double
    var card: WordCard?

    init(card: WordCard, now: Date = .now) {
        id = UUID()
        dueAt = now
        phaseRaw = ReviewPhase.new.rawValue
        intervalDays = 0
        easeFactor = 2.5
        repetitions = 0
        lapses = 0
        relearningBaseInterval = 0
        self.card = card
    }
}

@Model
final class CharacterReviewState: ReviewStateFields {
    @Attribute(.unique) var id: UUID
    var dueAt: Date
    var phaseRaw: String
    var intervalDays: Double
    var easeFactor: Double
    var repetitions: Int
    var lapses: Int
    var relearningBaseInterval: Double
    var card: CharacterCard?

    init(card: CharacterCard, now: Date = .now) {
        id = UUID()
        dueAt = now
        phaseRaw = ReviewPhase.new.rawValue
        intervalDays = 0
        easeFactor = 2.5
        repetitions = 0
        lapses = 0
        relearningBaseInterval = 0
        self.card = card
    }
}

struct CharacterDraft: Identifiable, Equatable {
    let id: UUID
    var glyph: String
    var pinyin: String
    var position: Int

    init(glyph: String, pinyin: String, position: Int) {
        id = UUID()
        self.glyph = glyph
        self.pinyin = pinyin
        self.position = position
    }
}
