import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ImageImportItem: Identifiable {
    let id = UUID()
    var isSelected: Bool
    var hanzi: String
    var pinyin: String
    var meaning: String
    var breakdown: [CharacterDraft]
}

struct ImageImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dictionary: DictionaryService

    let deck: Deck

    @State private var showingFileImporter = false
    @State private var isProcessing = false
    @State private var items: [ImageImportItem] = []
    @State private var errorMessage: String?

    private var importableCount: Int {
        items.filter(isImportable).count
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(AppTheme.divider)

            if isProcessing {
                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(AppTheme.orange)
                    Text("Reading Chinese text and preparing cards…")
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if items.isEmpty {
                emptyState
            } else {
                importPreview
            }

            Divider().overlay(AppTheme.divider)
            footer
        }
        .frame(width: 820, height: 760)
        .background(AppTheme.background)
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls): process(urls)
            case .failure(let error): errorMessage = error.localizedDescription
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Import from Images")
                    .font(.title2.bold())
                    .foregroundStyle(AppTheme.primaryText)
                Text("Choose screenshots or photos containing one or more Chinese words.")
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Spacer()
            Button { dismiss() } label: { Image(systemName: "xmark") }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("Close image importer")
        }
        .padding(22)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.viewfinder")
                .font(.system(size: 54))
                .foregroundStyle(AppTheme.orange)
            Text("Turn a screenshot into cards")
                .font(.title3.bold())
                .foregroundStyle(AppTheme.primaryText)
            Text("The app reads simplified and traditional Chinese, separates multiple words, and fills pinyin and meanings automatically. You can correct everything before importing.")
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)
            Button {
                showingFileImporter = true
            } label: {
                Label("Choose Images", systemImage: "photo.on.rectangle.angled")
            }
            .buttonStyle(OrangeButtonStyle())
            if let errorMessage {
                feedback(errorMessage)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    private var importPreview: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(items.count) words detected")
                    .font(.headline)
                    .foregroundStyle(AppTheme.primaryText)
                Spacer()
                Button("Choose More Images") { showingFileImporter = true }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach($items) { $item in
                        ImageImportRow(
                            item: $item,
                            isDuplicate: isDuplicate(item.hanzi)
                        )
                    }
                }
                .padding(22)
            }

            if let errorMessage {
                feedback(errorMessage)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 12)
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Cancel") { dismiss() }
            Spacer()
            Text("\(importableCount) ready")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
            Button("Import \(importableCount) Cards", action: importCards)
                .buttonStyle(OrangeButtonStyle())
                .disabled(importableCount == 0 || isProcessing)
                .keyboardShortcut(.defaultAction)
        }
        .padding(18)
    }

    private func process(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        isProcessing = true
        errorMessage = nil
        Task {
            do {
                let lines = try await OCRService.recognizeChineseText(in: urls)
                let words = dictionary.detectedWords(from: lines)
                guard !words.isEmpty else { throw OCRServiceError.noTextFound }
                let existingHanzi = Set(items.map(\.hanzi))
                let newWords = words.filter { !existingHanzi.contains($0) }
                items.append(contentsOf: newWords.map(makeItem))
            } catch {
                errorMessage = error.localizedDescription
            }
            isProcessing = false
        }
    }

    private func makeItem(for hanzi: String) -> ImageImportItem {
        let entry = dictionary.lookup(hanzi).first
        return ImageImportItem(
            isSelected: entry != nil && !isDuplicate(hanzi),
            hanzi: hanzi,
            pinyin: entry?.displayPinyin ?? "",
            meaning: entry?.meaning ?? "",
            breakdown: dictionary.characterDrafts(for: hanzi, entry: entry)
        )
    }

    private func isDuplicate(_ hanzi: String) -> Bool {
        deck.wordCards.contains { $0.hanzi == hanzi }
    }

    private func importCards() {
        errorMessage = nil
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

    private func isImportable(_ item: ImageImportItem) -> Bool {
        item.isSelected
            && !isDuplicate(item.hanzi)
            && item.hanzi.containsHanIdeograph
            && !item.pinyin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !item.meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !item.breakdown.isEmpty
            && item.breakdown.allSatisfy {
                !$0.pinyin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
    }

    private func feedback(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.circle")
            .font(.caption)
            .foregroundStyle(AppTheme.orange)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.orange.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct ImageImportRow: View {
    @EnvironmentObject private var dictionary: DictionaryService
    @Binding var item: ImageImportItem
    let isDuplicate: Bool

    @State private var lookupTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Toggle("Import", isOn: $item.isSelected)
                    .labelsHidden()
                    .toggleStyle(.checkbox)
                    .disabled(isDuplicate)
                    .accessibilityLabel("Import \(item.hanzi)")
                TextField("Chinese word", text: $item.hanzi)
                    .textFieldStyle(DarkFieldStyle())
                    .font(.system(size: 22, weight: .semibold))
                    .frame(width: 170)
                VStack(spacing: 8) {
                    TextField("Pinyin", text: $item.pinyin)
                        .textFieldStyle(DarkFieldStyle())
                    TextField("English meaning", text: $item.meaning, axis: .vertical)
                        .textFieldStyle(DarkFieldStyle())
                        .lineLimit(1...3)
                }
            }

            if isDuplicate {
                Label("Already in this deck", systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(AppTheme.orange)
            } else if item.pinyin.isEmpty || item.meaning.isEmpty {
                Label("No exact dictionary match. Complete the missing fields to import.", systemImage: "pencil")
                    .font(.caption)
                    .foregroundStyle(AppTheme.orange)
            }

            if !item.breakdown.isEmpty {
                HStack(spacing: 8) {
                    Text("Characters")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                    ForEach($item.breakdown) { $draft in
                        HStack(spacing: 4) {
                            Text(draft.glyph)
                                .foregroundStyle(AppTheme.primaryText)
                            TextField("Pinyin", text: $draft.pinyin)
                                .textFieldStyle(.plain)
                                .foregroundStyle(AppTheme.orange)
                                .frame(width: 70)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                        .background(AppTheme.elevatedSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
        .padding(14)
        .darkPanel()
        .onChange(of: item.hanzi) { _, newValue in
            scheduleLookup(for: newValue)
        }
        .onDisappear { lookupTask?.cancel() }
    }

    private func scheduleLookup(for text: String) {
        lookupTask?.cancel()
        guard text.containsHanIdeograph else { return }
        lookupTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            let entry = dictionary.lookup(text).first
            item.pinyin = entry?.displayPinyin ?? ""
            item.meaning = entry?.meaning ?? ""
            item.breakdown = dictionary.characterDrafts(for: text, entry: entry)
            item.isSelected = entry != nil && !isDuplicate
        }
    }
}
