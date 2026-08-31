import XCTest
@testable import HanziDeck

final class SchedulerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testNewCardSteps() {
        let card = makeWord()
        let state = WordReviewState(card: card, now: now)
        Scheduler.apply(.again, to: state, now: now)
        XCTAssertEqual(state.phase, .learning)
        XCTAssertEqual(state.dueAt, now.addingTimeInterval(60))

        Scheduler.apply(.good, to: state, now: now)
        XCTAssertEqual(state.phase, .review)
        XCTAssertEqual(state.intervalDays, 1)
        XCTAssertEqual(state.dueAt, now.addingTimeInterval(Scheduler.day))
    }

    func testReviewGradesAndEaseFloor() {
        let card = makeWord()
        let state = WordReviewState(card: card, now: now)
        state.phase = .review
        state.intervalDays = 10
        state.easeFactor = 1.35

        Scheduler.apply(.again, to: state, now: now)
        XCTAssertEqual(state.phase, .relearning)
        XCTAssertEqual(state.easeFactor, 1.3)
        XCTAssertEqual(state.relearningBaseInterval, 5)
        XCTAssertEqual(state.dueAt, now.addingTimeInterval(600))

        Scheduler.apply(.good, to: state, now: now)
        XCTAssertEqual(state.phase, .review)
        XCTAssertEqual(state.intervalDays, 5)
    }

    func testEasyGraduatesNewCardAtFourDays() {
        let card = makeWord()
        let state = WordReviewState(card: card, now: now)
        Scheduler.apply(.easy, to: state, now: now)
        XCTAssertEqual(state.intervalDays, 4)
        XCTAssertEqual(state.easeFactor, 2.65, accuracy: 0.0001)
    }

    private func makeWord() -> WordCard {
        let deck = Deck(name: "Test", now: now)
        return WordCard(hanzi: "学习", pinyin: "xué xí", meaning: "to study", deck: deck, now: now)
    }
}
