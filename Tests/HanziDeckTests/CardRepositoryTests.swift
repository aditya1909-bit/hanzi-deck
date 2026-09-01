import SwiftData
import XCTest
@testable import HanziDeck

@MainActor
final class CardRepositoryTests: XCTestCase {
    func testCharacterCardsAreUniqueAndKeepPolyphonicContexts() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let deck = Deck(name: "Chinese")
        context.insert(deck)

        _ = try CardRepository.addWord(
            to: deck,
            hanzi: "银行",
            pinyin: "yín háng",
            meaning: "bank",
            breakdown: [
                CharacterDraft(glyph: "银", pinyin: "yín", position: 0),
                CharacterDraft(glyph: "行", pinyin: "háng", position: 1)
            ],
            context: context
        )
        _ = try CardRepository.addWord(
            to: deck,
            hanzi: "旅行",
            pinyin: "lǚ xíng",
            meaning: "to travel",
            breakdown: [
                CharacterDraft(glyph: "旅", pinyin: "lǚ", position: 0),
                CharacterDraft(glyph: "行", pinyin: "xíng", position: 1)
            ],
            context: context
        )

        let xingCards = deck.characters.filter { $0.glyph == "行" }
        XCTAssertEqual(xingCards.count, 1)
        XCTAssertEqual(Set(xingCards[0].sourceContexts.map(\.pinyin)), Set(["háng", "xíng"]))
        XCTAssertNotEqual(
            deck.words.first?.reviewState?.id,
            xingCards[0].reviewState?.id
        )
    }

    func testDuplicateWordIsRejected() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let deck = Deck(name: "Chinese")
        context.insert(deck)
        let breakdown = [CharacterDraft(glyph: "学", pinyin: "xué", position: 0)]
        _ = try CardRepository.addWord(
            to: deck,
            hanzi: "学",
            pinyin: "xué",
            meaning: "to learn",
            breakdown: breakdown,
            context: context
        )
        XCTAssertThrowsError(
            try CardRepository.addWord(
                to: deck,
                hanzi: "学",
                pinyin: "xué",
                meaning: "to learn",
                breakdown: breakdown,
                context: context
            )
        )
    }

    func testDeletingLastSourceRemovesOrphanCharacter() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let deck = Deck(name: "Chinese")
        context.insert(deck)
        let word = try CardRepository.addWord(
            to: deck,
            hanzi: "学",
            pinyin: "xué",
            meaning: "to learn",
            breakdown: [CharacterDraft(glyph: "学", pinyin: "xué", position: 0)],
            context: context
        )
        XCTAssertEqual(deck.characters.count, 1)
        try CardRepository.deleteWord(word, context: context)
        XCTAssertEqual(deck.characters.count, 0)
    }

    func testDeletingDeckCascadesItsCardsAndReviewData() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let deck = Deck(name: "Temporary")
        context.insert(deck)
        _ = try CardRepository.addWord(
            to: deck,
            hanzi: "学",
            pinyin: "xué",
            meaning: "to learn",
            breakdown: [CharacterDraft(glyph: "学", pinyin: "xué", position: 0)],
            context: context
        )

        context.delete(deck)
        try context.save()

        XCTAssertTrue(try context.fetch(FetchDescriptor<Deck>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<WordCard>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<CharacterCard>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<WordReviewState>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<CharacterReviewState>()).isEmpty)
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
