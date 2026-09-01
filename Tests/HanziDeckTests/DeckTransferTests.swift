import SwiftData
import XCTest
@testable import HanziDeck

@MainActor
final class DeckTransferTests: XCTestCase {
    func testExportAndImportPreservesCardsSettingsAndReviewProgress() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let deck = Deck(name: "HSK 3", now: now)
        deck.schedulerAlgorithm = .leitner
        deck.desiredRetention = 0.86
        context.insert(deck)

        let word = try CardRepository.addWord(
            to: deck,
            hanzi: "银行",
            pinyin: "yín háng",
            meaning: "bank",
            breakdown: [
                CharacterDraft(glyph: "银", pinyin: "yín", position: 0),
                CharacterDraft(glyph: "行", pinyin: "háng", position: 1)
            ],
            context: context,
            now: now
        )
        word.reviewState?.phase = .review
        word.reviewState?.dueAt = now.addingTimeInterval(7 * Scheduler.day)
        word.reviewState?.intervalDays = 7
        word.reviewState?.repetitions = 4
        deck.characters.first(where: { $0.glyph == "行" })?.reviewState?.lapses = 2
        try context.save()

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(DeckArchive(deck: deck, exportedAt: now))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedArchive = try decoder.decode(DeckArchive.self, from: data)

        let imported = try DeckTransferService.importDeck(
            decodedArchive,
            existingNames: [deck.name],
            context: context
        )

        XCTAssertEqual(imported.name, "HSK 3 (Imported)")
        XCTAssertEqual(imported.schedulerAlgorithm, .leitner)
        XCTAssertEqual(imported.desiredRetention, 0.86, accuracy: 0.001)
        XCTAssertEqual(imported.words.count, 1)
        XCTAssertEqual(imported.words[0].hanzi, "银行")
        XCTAssertEqual(imported.words[0].contexts.count, 2)
        XCTAssertEqual(imported.words[0].reviewState?.intervalDays, 7)
        XCTAssertEqual(imported.words[0].reviewState?.repetitions, 4)
        XCTAssertEqual(
            imported.characters.first(where: { $0.glyph == "行" })?.reviewState?.lapses,
            2
        )
    }

    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Deck.self,
            WordCard.self,
            CharacterCard.self,
            CharacterContext.self,
            WordReviewState.self,
            CharacterReviewState.self,
            configurations: configuration
        )
    }
}
