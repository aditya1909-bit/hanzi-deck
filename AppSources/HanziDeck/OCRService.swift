@preconcurrency import AppKit
import Foundation
@preconcurrency import Vision

enum OCRServiceError: LocalizedError {
    case unreadableImage
    case noTextFound

    var errorDescription: String? {
        switch self {
        case .unreadableImage:
            "One of the selected images could not be read."
        case .noTextFound:
            "No Chinese text was found in the selected images."
        }
    }
}

enum OCRService {
    static func recognizeChineseText(in urls: [URL]) async throws -> [String] {
        let lines = try await Task.detached(priority: .userInitiated) {
            var allLines: [String] = []
            for url in urls {
                let accessed = url.startAccessingSecurityScopedResource()
                defer {
                    if accessed { url.stopAccessingSecurityScopedResource() }
                }
                guard let image = NSImage(contentsOf: url),
                      let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                    throw OCRServiceError.unreadableImage
                }

                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.recognitionLanguages = ["zh-Hans", "zh-Hant"]
                request.usesLanguageCorrection = true
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try handler.perform([request])
                allLines.append(contentsOf: (request.results ?? []).compactMap {
                    $0.topCandidates(1).first?.string
                })
            }
            return allLines
        }.value

        guard !lines.isEmpty else { throw OCRServiceError.noTextFound }
        return lines
    }
}
