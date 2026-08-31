import XCTest
@testable import HanziDeck

final class CEDICTLineParserTests: XCTestCase {
    func testParsesTraditionalSimplifiedPinyinAndDefinitions() {
        let entry = CEDICTLineParser.parse("學習 学习 [xue2 xi2] /to learn/to study/")
        XCTAssertEqual(
            entry,
            ParsedCEDICTEntry(
                traditional: "學習",
                simplified: "学习",
                pinyin: "xue2 xi2",
                meaning: "to learn; to study"
            )
        )
    }

    func testRejectsCommentsAndMalformedEntries() {
        XCTAssertNil(CEDICTLineParser.parse("# comment"))
        XCTAssertNil(CEDICTLineParser.parse("not an entry"))
        XCTAssertNil(CEDICTLineParser.parse("學習 学习 [xue2 xi2] //"))
    }

    func testExtractsChineseRunsFromOCRText() {
        XCTAssertEqual("1. 学习  xue2 xi2".hanIdeographRuns, ["学习"])
        XCTAssertEqual("銀行, 旅行 / vocabulary".hanIdeographRuns, ["銀行", "旅行"])
        XCTAssertEqual("No Chinese here".hanIdeographRuns, [])
    }
}
