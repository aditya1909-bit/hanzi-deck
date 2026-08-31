#if os(iOS)
import ImageIO
import PhotosUI
import SwiftData
import SwiftUI
@preconcurrency import Vision

private struct MobileImportItem: Identifiable {
    let id = UUID()
    var isSelected: Bool
    var hanzi: String
    var pinyin: String
    var meaning: String
    var breakdown: [CharacterDraft]
}

struct MobileImageImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dictionary: DictionaryService

    let deck: Deck

    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var items: [MobileImportItem] = []
    @State private var isProcessing = false
    @State private var errorMessage: String?

    private var importableCount: Int {
        items.filter(isImportable).count
    }

    var body: some View {
        NavigationStack {
            Group {
                if isProcessing {
                    VStack(spacing: 14) {
                        ProgressView().tint(AppTheme.orange)
                        Text("Reading Chinese text…")
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                } else if items.isEmpty {
                    emptyState
                } else {
                    preview
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.background)
            .navigationTitle("Import Images")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import \(importableCount)", action: importCards)
                        .disabled(importableCount == 0 || isProcessing)
                }
            }
            .onChange(of: selectedPhotos) { _, photos in
                process(photos)
            }
        }
        .tint(AppTheme.orange)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Turn screenshots into cards", systemImage: "text.viewfinder")
                .foregroundStyle(AppTheme.orange)
        } description: {
            Text("Choose one or more screenshots or photos. Everything stays on your iPhone.")
                .foregroundStyle(AppTheme.secondaryText)
        } actions: {
            PhotosPicker(
                selection: $selectedPhotos,
                maxSelectionCount: 20,
                matching: .images
            ) {
                Label("Choose Images", systemImage: "photo.on.rectangle.angled")
            }
            .buttonStyle(OrangeButtonStyle())
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(AppTheme.orange)
            }
        }
    }

    private var preview: some View {
        List {
            Section {
                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: 20,
                    matching: .images
                ) {
                    Label("Choose different images", systemImage: "photo.badge.plus")
                }
            }

            Section("Detected words") {
                ForEach($items) { $item in
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: $item.isSelected) {
                            TextField("Chinese word", text: $item.hanzi)
                                .font(.title3.bold())
                        }
                        TextField("Pinyin", text: $item.pinyin)
                            .foregroundStyle(AppTheme.orange)
                            .autocorrectionDisabled()
                        TextField("English meaning", text: $item.meaning, axis: .vertical)
                            .lineLimit(1...3)
                        if deck.words.contains(where: { $0.hanzi == item.hanzi }) {
                            Label("Already in this deck", systemImage: "exclamationmark.circle")
                                .font(.caption)
                                .foregroundStyle(AppTheme.orange)
                        }
                    }
                    .padding(.vertical, 5)
                }
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.circle")
                        .foregroundStyle(AppTheme.orange)
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func process(_ photos: [PhotosPickerItem]) {
        guard !photos.isEmpty else { return }
        isProcessing = true
        errorMessage = nil
        Task {
            do {
                let lines = try await MobileOCRService.recognizeChineseText(in: photos)
                let words = dictionary.detectedWords(from: lines)
                guard !words.isEmpty else { throw MobileOCRService.Error.noTextFound }
                items = words.map(makeItem)
            } catch {
                errorMessage = error.localizedDescription
            }
            isProcessing = false
        }
    }

    private func makeItem(for hanzi: String) -> MobileImportItem {
        let entry = dictionary.lookup(hanzi).first
        return MobileImportItem(
            isSelected: entry != nil && !deck.words.contains(where: { $0.hanzi == hanzi }),
            hanzi: hanzi,
            pinyin: entry?.displayPinyin ?? "",
            meaning: entry?.meaning ?? "",
            breakdown: dictionary.characterDrafts(for: hanzi, entry: entry)
        )
    }

    private func isImportable(_ item: MobileImportItem) -> Bool {
        item.isSelected
            && !deck.words.contains(where: { $0.hanzi == item.hanzi })
            && item.hanzi.containsHanIdeograph
            && !item.pinyin.isEmpty
            && !item.meaning.isEmpty
            && !item.breakdown.isEmpty
            && item.breakdown.allSatisfy { !$0.pinyin.isEmpty }
    }

    private func importCards() {
        do {
            for item in items where isImportable(item) {
                _ = try CardRepository.addWord(
                    to: deck,
                    hanzi: item.hanzi,
                    pinyin: item.pinyin,
                    meaning: item.meaning,
                    breakdown: item.breakdown,
                    context: modelContext
                )
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private enum MobileOCRService {
    enum Error: LocalizedError {
        case unreadableImage
        case noTextFound

        var errorDescription: String? {
            switch self {
            case .unreadableImage: "One of the selected images could not be read."
            case .noTextFound: "No Chinese text was found in the selected images."
            }
        }
    }

    static func recognizeChineseText(in photos: [PhotosPickerItem]) async throws -> [String] {
        var allLines: [String] = []
        for photo in photos {
            guard let data = try await photo.loadTransferable(type: Data.self),
                  let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                throw Error.unreadableImage
            }

            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "zh-Hant"]
            request.usesLanguageCorrection = true
            try VNImageRequestHandler(cgImage: image).perform([request])
            allLines.append(contentsOf: (request.results ?? []).compactMap {
                $0.topCandidates(1).first?.string
            })
        }
        guard !allLines.isEmpty else { throw Error.noTextFound }
        return allLines
    }
}
#endif
