#if os(iOS)
import SwiftData
import SwiftUI

struct MobileCardEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dictionary: DictionaryService

    let deck: Deck
    let word: WordCard?

    @State private var hanzi: String
    @State private var pinyin: String
    @State private var meaning: String
    @State private var subsetName: String
    @State private var candidates: [DictionaryEntry] = []
    @State private var selectedCandidateID: Int64?
    @State private var breakdown: [CharacterDraft]
    @State private var hasLookedUp = false
    @State private var isLookingUp = false
    @State private var errorMessage: String?
    @State private var lookupTask: Task<Void, Never>?

    init(deck: Deck, word: WordCard? = nil, initialSubset: String? = nil) {
        self.deck = deck
        self.word = word
        _hanzi = State(initialValue: word?.hanzi ?? "")
        _pinyin = State(initialValue: word?.pinyin ?? "")
        _meaning = State(initialValue: word?.meaning ?? "")
        _subsetName = State(initialValue: word?.subsetName ?? initialSubset ?? "")
        let drafts = word?.contexts
            .sorted { $0.position < $1.position }
            .compactMap { context -> CharacterDraft? in
                guard let glyph = context.characterCard?.glyph else { return nil }
                return CharacterDraft(
                    glyph: glyph,
                    pinyin: context.pinyin,
                    position: context.position
                )
            } ?? []
        _breakdown = State(initialValue: drafts)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Chinese word") {
                    TextField("学习 or 學習", text: $hanzi)
                        .font(.title2)
                        .autocorrectionDisabled()
                    if isLookingUp {
                        Label("Looking up automatically…", systemImage: "sparkle.magnifyingglass")
                            .font(.caption)
                            .foregroundStyle(AppTheme.orange)
                    }
                }

                if !candidates.isEmpty {
                    Section("Dictionary matches") {
                        ForEach(candidates) { candidate in
                            Button { select(candidate) } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: selectedCandidateID == candidate.id
                                          ? "largecircle.fill.circle"
                                          : "circle")
                                        .foregroundStyle(AppTheme.orange)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("\(candidate.traditional) · \(candidate.simplified)")
                                            .foregroundStyle(AppTheme.primaryText)
                                        Text(candidate.displayPinyin)
                                            .foregroundStyle(AppTheme.orange)
                                        Text(candidate.meaning)
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.secondaryText)
                                            .lineLimit(3)
                                    }
                                }
                            }
                        }
                    }
                } else if hasLookedUp {
                    Section {
                        Label("No exact match. Complete the fields manually.", systemImage: "pencil")
                            .font(.caption)
                            .foregroundStyle(AppTheme.orange)
                    }
                }

                Section("Card back") {
                    TextField("Tone-marked pinyin", text: $pinyin)
                        .autocorrectionDisabled()
                    TextField("English meaning", text: $meaning, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section("Deck part") {
                    Picker("Part", selection: $subsetName) {
                        Text("Unfiled").tag("")
                        ForEach(deck.subsetNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                }

                if !breakdown.isEmpty {
                    Section("Character readings") {
                        Text("Confirm the pronunciation used in this word.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                        ForEach($breakdown) { $draft in
                            HStack {
                                Text(draft.glyph)
                                    .font(.title2.bold())
                                    .frame(width: 42)
                                TextField("Pinyin", text: $draft.pinyin)
                                    .autocorrectionDisabled()
                            }
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.circle")
                            .font(.caption)
                            .foregroundStyle(AppTheme.orange)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle(word == nil ? "Add Word" : "Edit Word")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                }
            }
            .onChange(of: hanzi) { oldValue, newValue in
                guard oldValue != newValue, newValue != word?.hanzi else { return }
                candidates = []
                selectedCandidateID = nil
                hasLookedUp = false
                breakdown = dictionary.characterDrafts(for: newValue, entry: nil)
                scheduleLookup(for: newValue)
            }
            .onDisappear { lookupTask?.cancel() }
        }
        .tint(AppTheme.orange)
    }

    private func scheduleLookup(for text: String) {
        lookupTask?.cancel()
        guard text.containsHanIdeograph, dictionary.isAvailable else {
            isLookingUp = false
            return
        }
        isLookingUp = true
        lookupTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            lookup()
        }
    }

    private func lookup() {
        let cleanHanzi = hanzi.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanHanzi.containsHanIdeograph else { return }
        candidates = dictionary.lookup(cleanHanzi)
        hasLookedUp = true
        isLookingUp = false
        if let first = candidates.first {
            select(first)
        } else {
            breakdown = dictionary.characterDrafts(for: cleanHanzi, entry: nil)
        }
    }

    private func select(_ candidate: DictionaryEntry) {
        selectedCandidateID = candidate.id
        pinyin = candidate.displayPinyin
        meaning = candidate.meaning
        breakdown = dictionary.characterDrafts(for: hanzi, entry: candidate)
    }

    private func save() {
        do {
            if let word {
                try CardRepository.updateWord(
                    word,
                    hanzi: hanzi,
                    pinyin: pinyin,
                    meaning: meaning,
                    subsetName: subsetName,
                    breakdown: breakdown,
                    context: modelContext
                )
            } else {
                _ = try CardRepository.addWord(
                    to: deck,
                    hanzi: hanzi,
                    pinyin: pinyin,
                    meaning: meaning,
                    subsetName: subsetName,
                    breakdown: breakdown,
                    context: modelContext
                )
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
#endif
