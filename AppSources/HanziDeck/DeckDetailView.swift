import SwiftData
import SwiftUI

struct DeckDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var deck: Deck

    @State private var mode: StudyMode = .word
    @State private var learningMethod: LearningMethod = .hanziRecognition
    @State private var searchText = ""
    @State private var editingWord: WordCard?
    @State private var showingAddCard = false
    @State private var showingImageImport = false
    @State private var studyConfiguration: StudyConfiguration?
    @State private var deleteTarget: WordCard?

    private var filteredWords: [WordCard] {
        deck.wordCards
            .filter {
                searchText.isEmpty
                    || $0.hanzi.localizedCaseInsensitiveContains(searchText)
                    || $0.pinyin.localizedCaseInsensitiveContains(searchText)
                    || $0.meaning.localizedCaseInsensitiveContains(searchText)
            }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var filteredCharacters: [CharacterCard] {
        deck.characterCards
            .filter { character in
                searchText.isEmpty
                    || character.glyph.contains(searchText)
                    || character.contexts.contains {
                        $0.pinyin.localizedCaseInsensitiveContains(searchText)
                            || ($0.sourceWord?.hanzi.contains(searchText) ?? false)
                    }
            }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var dueCount: Int {
        sessionCount(.due)
    }

    private var totalCount: Int {
        mode == .word ? deck.wordCards.count : deck.characterCards.count
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(AppTheme.divider)
            cardList
        }
        .background(AppTheme.background)
        .sheet(isPresented: $showingAddCard) {
            CardEditorView(deck: deck)
        }
        .sheet(isPresented: $showingImageImport) {
            ImageImportView(deck: deck)
        }
        .sheet(item: $editingWord) { word in
            CardEditorView(deck: deck, word: word)
        }
        .sheet(item: $studyConfiguration) { configuration in
            StudyView(configuration: configuration)
                .frame(minWidth: 820, minHeight: 620)
        }
        .alert("Delete this card?", isPresented: Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        )) {
            Button("Cancel", role: .cancel) { deleteTarget = nil }
            Button("Delete", role: .destructive) {
                if let deleteTarget {
                    try? CardRepository.deleteWord(deleteTarget, context: modelContext)
                }
                deleteTarget = nil
            }
        } message: {
            Text("Its character contexts will also be removed. Review progress for characters still used by other words will be preserved.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(deck.name)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                    Text("\(deck.wordCards.count) words · \(deck.characterCards.count) unique characters")
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
                Button {
                    showingImageImport = true
                } label: {
                    Label("Import Images", systemImage: "text.viewfinder")
                }
                .accessibilityLabel("Import Chinese words from images or screenshots")
                Button {
                    showingAddCard = true
                } label: {
                    Label("Add Word", systemImage: "plus")
                }
                .buttonStyle(OrangeButtonStyle())
                .accessibilityLabel("Add a Chinese word")
            }

            studyControls

            HStack(spacing: 14) {
                Picker("Browse", selection: $mode) {
                    ForEach(StudyMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 260)

                Text("Browse and manage cards")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                Spacer()
            }

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppTheme.secondaryText)
                TextField("Search cards", text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundStyle(AppTheme.primaryText)
            }
            .padding(10)
            .background(AppTheme.surface)
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(AppTheme.divider))
            .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .padding(24)
    }

    private var studyControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Label("Learning method", systemImage: learningMethod.symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)

                Picker("Learning method", selection: $learningMethod) {
                    ForEach(LearningMethod.allCases) { method in
                        Text(method.title).tag(method)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 220)

                Text(learningMethod.shortDescription)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                Spacer()
            }

            HStack(spacing: 12) {
                Button("Study This Deck · \(dueCount) Due") {
                    beginStudy(.due)
                }
                .buttonStyle(OrangeButtonStyle())
                .disabled(dueCount == 0)

                Menu {
                    ForEach(StudySessionKind.allCases) { kind in
                        Button {
                            beginStudy(kind)
                        } label: {
                            Label("\(kind.title) (\(sessionCount(kind)))", systemImage: kind.symbol)
                        }
                        .disabled(sessionCount(kind) == 0)
                    }
                } label: {
                    Label("Choose Session", systemImage: "chevron.down")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Text("Cram, Difficult, and Free Practice never alter due dates.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                Spacer()
            }
        }
        .padding(16)
        .darkPanel()
    }

    @ViewBuilder
    private var cardList: some View {
        if totalCount == 0 {
            VStack(spacing: 12) {
                Image(systemName: mode == .word ? "textformat" : "character.book.closed")
                    .font(.system(size: 34))
                    .foregroundStyle(AppTheme.orange)
                Text(mode == .word ? "Add your first Chinese word" : "Characters are created from your word cards")
                    .font(.headline)
                    .foregroundStyle(AppTheme.primaryText)
                if mode == .word {
                    HStack {
                        Button("Import Images") { showingImageImport = true }
                        Button("Add Word") { showingAddCard = true }
                            .buttonStyle(OrangeButtonStyle())
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    if mode == .word {
                        ForEach(filteredWords) { word in
                            WordRow(
                                word: word,
                                onEdit: { editingWord = word },
                                onDelete: { deleteTarget = word }
                            )
                        }
                    } else {
                        ForEach(filteredCharacters) { character in
                            CharacterRow(character: character)
                        }
                    }
                }
                .padding(24)
            }
        }
    }

    private func beginStudy(_ kind: StudySessionKind) {
        let configuration = StudySessionBuilder.build(
            deck: deck,
            method: learningMethod,
            kind: kind
        )
        guard !configuration.prompts.isEmpty else { return }
        studyConfiguration = configuration
    }

    private func sessionCount(_ kind: StudySessionKind) -> Int {
        StudySessionBuilder.count(
            deck: deck,
            method: learningMethod,
            kind: kind
        )
    }
}

private struct WordRow: View {
    let word: WordCard
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            Text(word.hanzi)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
                .frame(width: 150, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                Text(word.pinyin)
                    .foregroundStyle(AppTheme.orange)
                Text(word.meaning)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(2)
            }
            Spacer()
            DueBadge(date: word.reviewState?.dueAt)
            Button(action: onEdit) { Image(systemName: "pencil") }
                .buttonStyle(.plain)
                .help("Edit card")
            Button(action: onDelete) { Image(systemName: "trash") }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.secondaryText)
                .help("Delete card")
        }
        .padding(16)
        .darkPanel()
    }
}

private struct CharacterRow: View {
    let character: CharacterCard

    private var contextLines: [String] {
        let lines = character.contexts.compactMap { context -> String? in
            guard let word = context.sourceWord else { return nil }
            return "\(context.pinyin) — \(word.hanzi)"
        }
        return Array(Set(lines)).sorted()
    }

    var body: some View {
        HStack(spacing: 18) {
            Text(character.glyph)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
                .frame(width: 90)
            VStack(alignment: .leading, spacing: 5) {
                ForEach(contextLines, id: \.self) { line in
                    Text(line)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
            Spacer()
            DueBadge(date: character.reviewState?.dueAt)
        }
        .padding(16)
        .darkPanel()
    }
}

private struct DueBadge: View {
    let date: Date?

    var body: some View {
        let due = date.map { $0 <= .now } ?? false
        Text(due ? "Due" : "Scheduled")
            .font(.caption.weight(.semibold))
            .foregroundStyle(due ? AppTheme.orange : AppTheme.secondaryText)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background((due ? AppTheme.orange : AppTheme.secondaryText).opacity(0.10))
            .clipShape(Capsule())
    }
}
