import Foundation
import SwiftData

enum CardRepositoryError: LocalizedError {
    case invalidHanzi
    case missingPinyin
    case missingMeaning
    case incompleteCharacterPinyin
    case duplicateWord

    var errorDescription: String? {
        switch self {
        case .invalidHanzi: "Enter at least one Chinese character."
        case .missingPinyin: "Pinyin is required."
        case .missingMeaning: "An English meaning is required."
        case .incompleteCharacterPinyin: "Confirm the pinyin for every character."
        case .duplicateWord: "This word is already in the deck. Edit the existing card instead."
        }
    }
}

@MainActor
enum CardRepository {
    static func addWord(
        to deck: Deck,
        hanzi: String,
        pinyin: String,
        meaning: String,
        breakdown: [CharacterDraft],
        context: ModelContext,
        now: Date = .now
    ) throws -> WordCard {
        let cleanHanzi = hanzi.trimmingCharacters(in: .whitespacesAndNewlines)
        try validate(
            hanzi: cleanHanzi,
            pinyin: pinyin,
            meaning: meaning,
            breakdown: breakdown,
            deck: deck,
            excluding: nil
        )

        let word = WordCard(
            hanzi: cleanHanzi,
            pinyin: pinyin.trimmingCharacters(in: .whitespacesAndNewlines),
            meaning: meaning.trimmingCharacters(in: .whitespacesAndNewlines),
            deck: deck,
            now: now
        )
        let state = WordReviewState(card: word, now: now)
        word.reviewState = state
        context.insert(word)
        context.insert(state)
        deriveCharacters(for: word, breakdown: breakdown, deck: deck, context: context, now: now)
        deck.updatedAt = now
        try context.save()
        return word
    }

    static func updateWord(
        _ word: WordCard,
        hanzi: String,
        pinyin: String,
        meaning: String,
        breakdown: [CharacterDraft],
        context: ModelContext,
        now: Date = .now
    ) throws {
        guard let deck = word.deck else { return }
        let cleanHanzi = hanzi.trimmingCharacters(in: .whitespacesAndNewlines)
        try validate(
            hanzi: cleanHanzi,
            pinyin: pinyin,
            meaning: meaning,
            breakdown: breakdown,
            deck: deck,
            excluding: word
        )

        let promptChanged = word.hanzi != cleanHanzi
        removeContexts(for: word, context: context)

        word.hanzi = cleanHanzi
        word.pinyin = pinyin.trimmingCharacters(in: .whitespacesAndNewlines)
        word.meaning = meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        word.updatedAt = now
        if promptChanged, let state = word.reviewState {
            reset(state, now: now)
        }
        deriveCharacters(for: word, breakdown: breakdown, deck: deck, context: context, now: now)
        deck.updatedAt = now
        try context.save()
    }

    static func deleteWord(_ word: WordCard, context: ModelContext) throws {
        let deck = word.deck
        removeContexts(for: word, context: context)
        context.delete(word)
        deck?.updatedAt = .now
        try context.save()
    }

    private static func validate(
        hanzi: String,
        pinyin: String,
        meaning: String,
        breakdown: [CharacterDraft],
        deck: Deck,
        excluding word: WordCard?
    ) throws {
        guard hanzi.containsHanIdeograph else { throw CardRepositoryError.invalidHanzi }
        guard !pinyin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CardRepositoryError.missingPinyin
        }
        guard !meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CardRepositoryError.missingMeaning
        }
        guard !breakdown.isEmpty,
              breakdown.allSatisfy({ !$0.pinyin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw CardRepositoryError.incompleteCharacterPinyin
        }
        if deck.wordCards.contains(where: { $0.id != word?.id && $0.hanzi == hanzi }) {
            throw CardRepositoryError.duplicateWord
        }
    }

    private static func deriveCharacters(
        for word: WordCard,
        breakdown: [CharacterDraft],
        deck: Deck,
        context: ModelContext,
        now: Date
    ) {
        for draft in breakdown {
            let character: CharacterCard
            if let existing = deck.characterCards.first(where: { $0.glyph == draft.glyph }) {
                character = existing
            } else {
                character = CharacterCard(glyph: draft.glyph, deck: deck, now: now)
                let state = CharacterReviewState(card: character, now: now)
                character.reviewState = state
                context.insert(character)
                context.insert(state)
            }
            let source = CharacterContext(
                pinyin: draft.pinyin.trimmingCharacters(in: .whitespacesAndNewlines),
                position: draft.position,
                characterCard: character,
                sourceWord: word
            )
            context.insert(source)
        }
    }

    private static func removeContexts(for word: WordCard, context: ModelContext) {
        let oldContexts = word.characterContexts
        let affectedCharacters = oldContexts.compactMap(\.characterCard)
        for source in oldContexts {
            context.delete(source)
        }
        for character in affectedCharacters where character.contexts.allSatisfy({ $0.sourceWord?.id == word.id }) {
            context.delete(character)
        }
    }

    private static func reset(_ state: ReviewStateFields, now: Date) {
        state.dueAt = now
        state.phase = .new
        state.intervalDays = 0
        state.easeFactor = 2.5
        state.repetitions = 0
        state.lapses = 0
        state.relearningBaseInterval = 0
        state.lastReviewAt = nil
        state.fsrsStability = 0
        state.fsrsDifficulty = 0
        state.leitnerBox = 1
    }
}
