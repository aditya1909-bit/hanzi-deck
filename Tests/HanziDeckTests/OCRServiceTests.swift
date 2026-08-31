import AppKit
import XCTest
@testable import HanziDeck

final class OCRServiceTests: XCTestCase {
    func testRecognizesMultipleChineseWordsFromScreenshot() async throws {
        let image = NSImage(size: NSSize(width: 720, height: 360))
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: image.size).fill()
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 58, weight: .medium),
            .foregroundColor: NSColor.black
        ]
        NSString(string: "学习\n银行\n旅行").draw(
            in: NSRect(x: 50, y: 35, width: 620, height: 290),
            withAttributes: attributes
        )
        image.unlockFocus()

        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(image.tiffRepresentation)))
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("hanzi-deck-ocr-\(UUID().uuidString).png")
        try png.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let lines = try await OCRService.recognizeChineseText(in: [url])
        let recognized = Set(lines.flatMap(\.hanIdeographRuns))
        XCTAssertTrue(recognized.contains("学习"))
        XCTAssertTrue(recognized.contains("银行"))
        XCTAssertTrue(recognized.contains("旅行"))
    }
}
