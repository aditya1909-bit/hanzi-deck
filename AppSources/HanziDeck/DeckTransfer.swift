import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct DeckTransferDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var archive: DeckArchive

    init(deck: Deck) {
        archive = DeckArchive(deck: deck)
    }

    init(data: Data) throws {
        archive = try Self.decode(data)
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw DeckTransferError.invalidFile
        }
        archive = try Self.decode(data)
    }

    private static func decode(_ data: Data) throws -> DeckArchive {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let archive = try decoder.decode(DeckArchive.self, from: data)
        guard archive.formatVersion == DeckArchive.currentFormatVersion else {
            throw DeckTransferError.unsupportedVersion
        }
        return archive
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return FileWrapper(regularFileWithContents: try encoder.encode(archive))
    }
}

struct DeckArchive: Codable {
    static let currentFormatVersion = 1

    let formatVersion: Int
    let exportedAt: Date
    let name: String
    let createdAt: Date
    let updatedAt: Date
    let schedulerAlgorithmRaw: String
    let desiredRetention: Double
    let words: [WordArchive]
    let characters: [CharacterReviewArchive]

    init(deck: Deck, exportedAt: Date = .now) {
        formatVersion = Self.currentFormatVersion
        self.exportedAt = exportedAt
        name = deck.name
        createdAt = deck.createdAt
        updatedAt = deck.updatedAt
        schedulerAlgorithmRaw = deck.schedulerAlgorithmRaw
        desiredRetention = deck.desiredRetention
        words = deck.words
            .sorted { $0.createdAt < $1.createdAt }
            .map(WordArchive.init)
        characters = deck.characters
            .sorted { $0.glyph < $1.glyph }
            .map(CharacterReviewArchive.init)
    }
}

struct WordArchive: Codable {
    let hanzi: String
    let pinyin: String
    let meaning: String
    let createdAt: Date
    let updatedAt: Date
    let characters: [CharacterContextArchive]
    let reviewState: ReviewStateArchive?

    init(word: WordCard) {
        hanzi = word.hanzi
        pinyin = word.pinyin
        meaning = word.meaning
        createdAt = word.createdAt
        updatedAt = word.updatedAt
        characters = word.contexts
            .compactMap { context -> CharacterContextArchive? in
                guard let glyph = context.characterCard?.glyph else { return nil }
                return CharacterContextArchive(
                    glyph: glyph,
                    pinyin: context.pinyin,
                    position: context.position
                )
            }
            .sorted { $0.position < $1.position }
        reviewState = word.reviewState.map(ReviewStateArchive.init)
    }
}

struct CharacterContextArchive: Codable {
    let glyph: String
    let pinyin: String
    let position: Int
}

struct CharacterReviewArchive: Codable {
    let glyph: String
    let reviewState: ReviewStateArchive?

    init(character: CharacterCard) {
        glyph = character.glyph
        reviewState = character.reviewState.map(ReviewStateArchive.init)
    }
}

struct ReviewStateArchive: Codable {
    let dueAt: Date
    let phaseRaw: String
    let intervalDays: Double
    let easeFactor: Double
    let repetitions: Int
    let lapses: Int
    let relearningBaseInterval: Double
    let lastReviewAt: Date?
    let fsrsStability: Double
    let fsrsDifficulty: Double
    let leitnerBox: Int

    init(state: ReviewStateFields) {
        dueAt = state.dueAt
        phaseRaw = state.phaseRaw
        intervalDays = state.intervalDays
        easeFactor = state.easeFactor
        repetitions = state.repetitions
        lapses = state.lapses
        relearningBaseInterval = state.relearningBaseInterval
        lastReviewAt = state.lastReviewAt
        fsrsStability = state.fsrsStability
        fsrsDifficulty = state.fsrsDifficulty
        leitnerBox = state.leitnerBox
    }

    func apply(to state: ReviewStateFields) {
        state.dueAt = dueAt
        state.phaseRaw = ReviewPhase(rawValue: phaseRaw)?.rawValue ?? ReviewPhase.new.rawValue
        state.intervalDays = max(0, intervalDays)
        state.easeFactor = max(1.3, easeFactor)
        state.repetitions = max(0, repetitions)
        state.lapses = max(0, lapses)
        state.relearningBaseInterval = max(0, relearningBaseInterval)
        state.lastReviewAt = lastReviewAt
        state.fsrsStability = max(0, fsrsStability)
        state.fsrsDifficulty = max(0, fsrsDifficulty)
        state.leitnerBox = max(1, leitnerBox)
    }
}

enum DeckTransferError: LocalizedError {
    case invalidFile
    case unsupportedVersion
    case invalidDeck

    var errorDescription: String? {
        switch self {
        case .invalidFile: "This file does not contain a Hanzi Deck export."
        case .unsupportedVersion: "This deck was created by an unsupported export version."
        case .invalidDeck: "This deck contains incomplete or duplicate cards."
        }
    }
}

@MainActor
enum DeckTransferService {
    static func importDeck(
        _ archive: DeckArchive,
        existingNames: Set<String>,
        context: ModelContext
    ) throws -> Deck {
        guard archive.formatVersion == DeckArchive.currentFormatVersion,
              !archive.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DeckTransferError.invalidDeck
        }
        try validate(archive.words)

        let deck = Deck(name: uniqueName(for: archive.name, existingNames: existingNames))
        deck.schedulerAlgorithmRaw = SchedulerAlgorithm(rawValue: archive.schedulerAlgorithmRaw)?.rawValue
            ?? SchedulerAlgorithm.fsrs6.rawValue
        deck.desiredRetention = min(0.97, max(0.70, archive.desiredRetention))
        context.insert(deck)

        do {
            for archivedWord in archive.words {
                let word = try CardRepository.addWord(
                    to: deck,
                    hanzi: archivedWord.hanzi,
                    pinyin: archivedWord.pinyin,
                    meaning: archivedWord.meaning,
                    breakdown: archivedWord.characters.map {
                        CharacterDraft(glyph: $0.glyph, pinyin: $0.pinyin, position: $0.position)
                    },
                    context: context,
                    now: archivedWord.createdAt
                )
                word.createdAt = archivedWord.createdAt
                word.updatedAt = archivedWord.updatedAt
                if let state = word.reviewState, let archivedState = archivedWord.reviewState {
                    archivedState.apply(to: state)
                }
            }

            for archivedCharacter in archive.characters {
                guard let state = deck.characters
                    .first(where: { $0.glyph == archivedCharacter.glyph })?
                    .reviewState,
                      let archivedState = archivedCharacter.reviewState else {
                    continue
                }
                archivedState.apply(to: state)
            }

            deck.createdAt = archive.createdAt
            deck.updatedAt = archive.updatedAt
            try context.save()
            return deck
        } catch {
            context.delete(deck)
            try? context.save()
            throw error
        }
    }

    private static func validate(_ words: [WordArchive]) throws {
        var seen: Set<String> = []
        for word in words {
            guard word.hanzi.containsHanIdeograph,
                  seen.insert(word.hanzi).inserted,
                  !word.pinyin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !word.meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !word.characters.isEmpty,
                  word.characters.allSatisfy({
                      $0.glyph.containsHanIdeograph
                          && !$0.pinyin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                  }) else {
                throw DeckTransferError.invalidDeck
            }
        }
    }

    private static func uniqueName(for proposedName: String, existingNames: Set<String>) -> String {
        let cleanName = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard existingNames.contains(cleanName) else { return cleanName }
        var number = 1
        while true {
            let suffix = number == 1 ? "Imported" : "Imported \(number)"
            let candidate = "\(cleanName) (\(suffix))"
            if !existingNames.contains(candidate) { return candidate }
            number += 1
        }
    }
}
