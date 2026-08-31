import SwiftData
import SwiftUI

struct CardEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dictionary: DictionaryService

    let deck: Deck
    let word: WordCard?

    @State private var hanzi: String
    @State private var pinyin: String
    @State private var meaning: String
    @State private var candidates: [DictionaryEntry] = []
    @State private var selectedCandidateID: Int64?
    @State private var breakdown: [CharacterDraft] = []
    @State private var errorMessage: String?
    @State private var hasLookedUp = false
    @State private var isLookingUp = false
    @State private var lookupTask: Task<Void, Never>?

    init(deck: Deck, word: WordCard? = nil) {
        self.deck = deck
        self.word = word
        _hanzi = State(initialValue: word?.hanzi ?? "")
        _pinyin = State(initialValue: word?.pinyin ?? "")
        _meaning = State(initialValue: word?.meaning ?? "")
        let contexts = word?.characterContexts
            .sorted { $0.position < $1.position }
            .compactMap { context -> CharacterDraft? in
                guard let glyph = context.characterCard?.glyph else { return nil }
                return CharacterDraft(glyph: glyph, pinyin: context.pinyin, position: context.position)
            } ?? []
        _breakdown = State(initialValue: contexts)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(word == nil ? "Add Word" : "Edit Word")
                        .font(.title2.bold())
                        .foregroundStyle(AppTheme.primaryText)
                    Text("\(deck.name) · Dictionary results stay editable")
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("Close card editor")
            }
            .padding(22)

            Divider().overlay(AppTheme.divider)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    fieldLabel("Chinese word")
                    TextField("学习 or 學習", text: $hanzi)
                        .textFieldStyle(DarkFieldStyle())
                        .font(.system(size: 24))
                        .onSubmit(lookup)
                    if isLookingUp {
                        Label("Looking up automatically…", systemImage: "sparkle.magnifyingglass")
                            .font(.caption)
                            .foregroundStyle(AppTheme.orange)
                    }

                    if let dictionaryError = dictionary.errorMessage {
                        feedback(dictionaryError)
                    }

                    if !candidates.isEmpty {
                        VStack(alignment: .leading, spacing: 9) {
                            fieldLabel("Dictionary matches")
                            ForEach(candidates) { candidate in
                                Button {
                                    select(candidate)
                                } label: {
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: selectedCandidateID == candidate.id ? "largecircle.fill.circle" : "circle")
                                            .foregroundStyle(AppTheme.orange)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("\(candidate.traditional) · \(candidate.simplified)")
                                                .foregroundStyle(AppTheme.primaryText)
                                            Text(candidate.displayPinyin)
                                                .foregroundStyle(AppTheme.orange)
                                            Text(candidate.meaning)
                                                .font(.caption)
                                                .foregroundStyle(AppTheme.secondaryText)
                                                .lineLimit(2)
                                        }
                                        Spacer()
                                    }
                                    .padding(12)
                                    .background(selectedCandidateID == candidate.id ? AppTheme.orange.opacity(0.08) : AppTheme.elevatedSurface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 9)
                                            .stroke(selectedCandidateID == candidate.id ? AppTheme.orange.opacity(0.7) : AppTheme.divider)
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 9))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else if hasLookedUp {
                        feedback("No exact dictionary entry was found. Enter the pinyin and meaning manually, then confirm each character below.")
                    }

                    fieldLabel("Pinyin")
                    TextField("Tone-marked pinyin", text: $pinyin)
                        .textFieldStyle(DarkFieldStyle())

                    fieldLabel("English meaning")
                    TextField("Meaning", text: $meaning, axis: .vertical)
                        .textFieldStyle(DarkFieldStyle())
                        .lineLimit(2...5)

                    if !breakdown.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            fieldLabel("Character Mode preview")
                            Text("Confirm the pronunciation used by each character in this word.")
                                .font(.caption)
                                .foregroundStyle(AppTheme.secondaryText)
                            ForEach($breakdown) { $draft in
                                HStack(spacing: 14) {
                                    Text(draft.glyph)
                                        .font(.system(size: 30, weight: .semibold))
                                        .foregroundStyle(AppTheme.primaryText)
                                        .frame(width: 50)
                                    TextField("Pinyin", text: $draft.pinyin)
                                        .textFieldStyle(DarkFieldStyle())
                                    Text("from \(hanzi)")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.secondaryText)
                                }
                            }
                        }
                        .padding(16)
                        .darkPanel()
                    }

                    if let errorMessage {
                        feedback(errorMessage)
                    }
                }
                .padding(24)
            }

            Divider().overlay(AppTheme.divider)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button(word == nil ? "Add Card" : "Save Changes", action: save)
                    .buttonStyle(OrangeButtonStyle())
                    .keyboardShortcut(.defaultAction)
            }
            .padding(18)
        }
        .frame(width: 680, height: 760)
        .background(AppTheme.background)
        .onChange(of: hanzi) { oldValue, newValue in
            guard oldValue != newValue else { return }
            candidates = []
            selectedCandidateID = nil
            hasLookedUp = false
            if newValue != word?.hanzi {
                breakdown = dictionary.characterDrafts(for: newValue, entry: nil)
                scheduleLookup(for: newValue)
            }
        }
        .onDisappear { lookupTask?.cancel() }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.bold))
            .tracking(0.8)
            .foregroundStyle(AppTheme.secondaryText)
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

    private func lookup() {
        let clean = hanzi.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.containsHanIdeograph else {
            isLookingUp = false
            return
        }
        hanzi = clean
        candidates = dictionary.lookup(clean)
        hasLookedUp = true
        isLookingUp = false
        errorMessage = nil
        if let first = candidates.first {
            select(first)
        } else {
            pinyin = ""
            meaning = ""
            breakdown = dictionary.characterDrafts(for: clean, entry: nil)
        }
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
                    breakdown: breakdown,
                    context: modelContext
                )
            } else {
                _ = try CardRepository.addWord(
                    to: deck,
                    hanzi: hanzi,
                    pinyin: pinyin,
                    meaning: meaning,
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
