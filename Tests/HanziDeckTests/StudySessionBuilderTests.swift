import XCTest
@testable import HanziDeck

@MainActor
final class StudySessionBuilderTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testEachWordLearningMethodUsesTheExpectedPromptDirection() {
        let deck = makeDeck()

        let recognition = StudySessionBuilder.build(
            deck: deck,
            method: .hanziRecognition,
            kind: .due,
            now: now
        )
        let meaning = StudySessionBuilder.build(
            deck: deck,
            method: .meaningRecall,
            kind: .due,
            now: now
        )
        let pinyin = StudySessionBuilder.build(
            deck: deck,
            method: .pinyinRecall,
            kind: .due,
            now: now
        )

        assertWordStyle(recognition.prompts.first, equals: .hanziRecognition)
        assertWordStyle(meaning.prompts.first, equals: .meaningRecall)
        assertWordStyle(pinyin.prompts.first, equals: .pinyinRecall)
    }

    func testCharacterAndMixedMethodsIncludeTheRightCardTypes() {
        let deck = makeDeck()
        let character = CharacterCard(glyph: "学", deck: deck, now: now)
        let state = CharacterReviewState(card: character, now: now)
        character.reviewState = state
        deck.characterCards.append(character)

        let characterOnly = StudySessionBuilder.build(
            deck: deck,
            method: .characterContext,
            kind: .due,
            now: now
        )
        let mixed = StudySessionBuilder.build(
            deck: deck,
            method: .mixed,
            kind: .due,
            now: now
        )

        XCTAssertEqual(characterOnly.prompts.count, 1)
        XCTAssertEqual(mixed.prompts.count, 2)
    }

    func testSessionKindsFilterAndLimitCards() {
        let deck = Deck(name: "Test", now: now)
        for index in 0..<25 {
            let card = WordCard(
                hanzi: "词\(index)",
                pinyin: "cí",
                meaning: "word",
                deck: deck,
                now: now.addingTimeInterval(Double(index))
            )
            let state = WordReviewState(card: card, now: now)
            state.phase = index == 0 ? .relearning : .review
            state.lapses = index == 0 ? 2 : 0
            state.dueAt = index < 3 ? now : now.addingTimeInterval(Scheduler.day)
            card.reviewState = state
            deck.wordCards.append(card)
        }

        XCTAssertEqual(
            StudySessionBuilder.count(deck: deck, method: .hanziRecognition, kind: .due, now: now),
            3
        )
        XCTAssertEqual(
            StudySessionBuilder.count(deck: deck, method: .hanziRecognition, kind: .difficult, now: now),
            1
        )
        XCTAssertEqual(
            StudySessionBuilder.count(deck: deck, method: .hanziRecognition, kind: .cram, now: now),
            20
        )
        XCTAssertFalse(StudySessionKind.cram.updatesSchedule)
        XCTAssertTrue(StudySessionKind.due.updatesSchedule)
    }

    func testSessionUsesTheDeckSchedulerConfiguration() {
        let deck = makeDeck()
        deck.schedulerAlgorithm = .sm2
        deck.desiredRetention = 0.93

        let configuration = StudySessionBuilder.build(
            deck: deck,
            method: .hanziRecognition,
            kind: .due,
            now: now
        )

        XCTAssertEqual(configuration.schedulerAlgorithm, .sm2)
        XCTAssertEqual(configuration.desiredRetention, 0.93, accuracy: 0.0001)
    }

    private func makeDeck() -> Deck {
        let deck = Deck(name: "Test", now: now)
        let card = WordCard(
            hanzi: "学习",
            pinyin: "xué xí",
            meaning: "to study",
            deck: deck,
            now: now
        )
        let state = WordReviewState(card: card, now: now)
        card.reviewState = state
        deck.wordCards.append(card)
        return deck
    }

    private func assertWordStyle(
        _ prompt: StudyPrompt?,
        equals expected: WordPromptStyle,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .word(_, let style) = prompt else {
            XCTFail("Expected a word prompt", file: file, line: line)
            return
        }
        XCTAssertEqual(style, expected, file: file, line: line)
    }
}
