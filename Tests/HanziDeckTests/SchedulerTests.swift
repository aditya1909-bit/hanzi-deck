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

    func testFSRSInitializesMemoryStateAndSchedulesReview() {
        let state = WordReviewState(card: makeWord(), now: now)

        Scheduler.apply(.good, to: state, algorithm: .fsrs6, now: now)

        XCTAssertEqual(state.phase, .review)
        XCTAssertEqual(state.fsrsStability, 2.3065, accuracy: 0.0001)
        XCTAssertTrue((1...10).contains(state.fsrsDifficulty))
        XCTAssertGreaterThanOrEqual(state.intervalDays, 1)
        XCTAssertEqual(state.lastReviewAt, now)
    }

    func testFSRSHigherRetentionProducesShorterInterval() {
        let lowerRetention = WordReviewState(card: makeWord(), now: now)
        let higherRetention = WordReviewState(card: makeWord(), now: now)

        Scheduler.apply(
            .easy,
            to: lowerRetention,
            algorithm: .fsrs6,
            desiredRetention: 0.80,
            now: now
        )
        Scheduler.apply(
            .easy,
            to: higherRetention,
            algorithm: .fsrs6,
            desiredRetention: 0.95,
            now: now
        )

        XCTAssertGreaterThan(lowerRetention.intervalDays, higherRetention.intervalDays)
    }

    func testSM2UsesClassicOneThenSixDayIntervals() {
        let state = WordReviewState(card: makeWord(), now: now)

        Scheduler.apply(.good, to: state, algorithm: .sm2, now: now)
        XCTAssertEqual(state.intervalDays, 1)

        let secondReview = now.addingTimeInterval(Scheduler.day)
        Scheduler.apply(.good, to: state, algorithm: .sm2, now: secondReview)
        XCTAssertEqual(state.intervalDays, 6)
        XCTAssertEqual(state.dueAt, secondReview.addingTimeInterval(6 * Scheduler.day))
    }

    func testLeitnerMovesCardsBetweenBoxes() {
        let state = WordReviewState(card: makeWord(), now: now)

        Scheduler.apply(.good, to: state, algorithm: .leitner, now: now)
        XCTAssertEqual(state.leitnerBox, 2)
        XCTAssertEqual(state.intervalDays, 2)

        Scheduler.apply(.again, to: state, algorithm: .leitner, now: now)
        XCTAssertEqual(state.leitnerBox, 1)
        XCTAssertEqual(state.phase, .relearning)
        XCTAssertEqual(state.dueAt, now.addingTimeInterval(10 * 60))
    }

    private func makeWord() -> WordCard {
        let deck = Deck(name: "Test", now: now)
        return WordCard(hanzi: "学习", pinyin: "xué xí", meaning: "to study", deck: deck, now: now)
    }
}
