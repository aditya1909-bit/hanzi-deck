import XCTest
@testable import HanziDeck

final class PinyinConverterTests: XCTestCase {
    func testConvertsNumberedPinyinToToneMarks() {
        XCTAssertEqual(PinyinConverter.toneMarked("xue2 xi2"), "xué xí")
        XCTAssertEqual(PinyinConverter.toneMarked("nu:3 ren2"), "nǚ rén")
        XCTAssertEqual(PinyinConverter.toneMarked("lü4 se4"), "lǜ sè")
        XCTAssertEqual(PinyinConverter.toneMarked("ma5"), "ma")
    }

    func testPreservesPunctuationTokens() {
        XCTAssertEqual(PinyinConverter.toneMarked("ren2 , niao3"), "rén , niǎo")
    }

    func testExtractsOnlyNumberedSyllableTokens() {
        XCTAssertEqual(PinyinConverter.syllableTokens("ren2 , niao3"), ["ren2", "niao3"])
    }
}
