#if os(macOS)
import SwiftData
import SwiftUI

struct DeckDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var deck: Deck
    let onRename: () -> Void
    let onExport: () -> Void
    let onDelete: () -> Void

    @State private var mode: StudyMode = .word
    @State private var learningMethod: LearningMethod = .hanziRecognition
    @State private var searchText = ""
    @State private var editingWord: WordCard?
    @State private var showingAddCard = false
    @State private var showingImageImport = false
    @State private var showingStudySettings = false
    @State private var studyConfiguration: StudyConfiguration?
    @State private var deleteTarget: WordCard?
    @State private var selectedSubset: String?
    @State private var showingNewSubset = false
    @State private var newSubsetName = ""
    @State private var showingDeleteSubset = false

    private var scopedWords: [WordCard] {
        deck.words.filter { selectedSubset == nil || $0.subsetName == selectedSubset }
    }

    private var scopedCharacters: [CharacterCard] {
        deck.characters.filter { character in
            selectedSubset == nil || character.sourceContexts.contains {
                $0.sourceWord?.subsetName == selectedSubset
            }
        }
    }

    private var filteredWords: [WordCard] {
        scopedWords
            .filter {
                searchText.isEmpty
                    || $0.hanzi.localizedCaseInsensitiveContains(searchText)
                    || $0.pinyin.localizedCaseInsensitiveContains(searchText)
                    || $0.meaning.localizedCaseInsensitiveContains(searchText)
            }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var filteredCharacters: [CharacterCard] {
        scopedCharacters
            .filter { character in
                searchText.isEmpty
                    || character.glyph.contains(searchText)
                    || character.sourceContexts.contains {
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
        mode == .word ? scopedWords.count : scopedCharacters.count
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(AppTheme.divider)
            cardList
        }
        .background(AppTheme.background)
        .sheet(isPresented: $showingAddCard) {
            CardEditorView(deck: deck, initialSubset: selectedSubset)
        }
        .sheet(isPresented: $showingImageImport) {
            ImageImportView(deck: deck, subsetName: selectedSubset)
        }
        .popover(isPresented: $showingStudySettings, arrowEdge: .top) {
            studySettings
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
        .alert("New Deck Part", isPresented: $showingNewSubset) {
            TextField("Part name", text: $newSubsetName)
            Button("Cancel", role: .cancel) { newSubsetName = "" }
            Button("Create", action: createSubset)
        } message: {
            Text("Parts let you study a smaller group of words without creating another deck.")
        }
        .alert("Delete this part?", isPresented: $showingDeleteSubset) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive, action: deleteSelectedSubset)
        } message: {
            Text("The words will remain in the deck as Unfiled.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(deck.name)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                    Text("\(scopedWords.count) words · \(scopedCharacters.count) unique characters")
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
                Menu {
                    Button("Rename Deck", action: onRename)
                    Button("Export Deck", action: onExport)
                    Button("Import from Images", action: { showingImageImport = true })
                    Button("New Deck Part…", action: { showingNewSubset = true })
                    if selectedSubset?.isEmpty == false {
                        Button("Delete Current Part", role: .destructive) {
                            showingDeleteSubset = true
                        }
                    }
                    Divider()
                    Button("Delete Deck", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .help("Deck options")
                Button {
                    showingAddCard = true
                } label: {
                    Label("Add Word", systemImage: "plus")
                }
                .buttonStyle(OrangeButtonStyle())
                .accessibilityLabel("Add a Chinese word")
            }

            studyControls

            HStack(spacing: 10) {
                Text("PART")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.secondaryText)
                Picker("Deck part", selection: $selectedSubset) {
                    Text("All Cards").tag(String?.none)
                    Text("Unfiled").tag(Optional(""))
                    ForEach(deck.subsetNames, id: \.self) { name in
                        Text(name).tag(Optional(name))
                    }
                }
                .labelsHidden()
                .frame(width: 220)
                Spacer()
                Button("New Part") { showingNewSubset = true }
            }

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
        HStack(spacing: 16) {
            Image(systemName: learningMethod.symbol)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(AppTheme.orange)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(dueCount == 0 ? "You’re caught up" : "\(dueCount) card\(dueCount == 1 ? "" : "s") due")
                    .font(.headline)
                    .foregroundStyle(AppTheme.primaryText)
                Text(learningMethod.title)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer()

            Button("Adaptive Learn") {
                beginStudy(.adaptive)
            }
            .buttonStyle(OrangeButtonStyle())
            .disabled(sessionCount(.adaptive) == 0)

            Menu {
                Section("Sessions") {
                    ForEach(StudySessionKind.allCases) { kind in
                        Button {
                            beginStudy(kind)
                        } label: {
                            Label("\(kind.title) (\(sessionCount(kind)))", systemImage: kind.symbol)
                        }
                        .disabled(sessionCount(kind) == 0)
                    }
                }
                Divider()
                Button("Study Settings…") { showingStudySettings = true }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 17))
            }
            .menuStyle(.borderlessButton)
            .help("More study options")
        }
        .padding(16)
        .darkPanel()
    }

    private var studySettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Study Settings")
                .font(.headline)

            Picker("Method", selection: $learningMethod) {
                ForEach(LearningMethod.allCases) { method in
                    Text(method.title).tag(method)
                }
            }

            Text(learningMethod.shortDescription)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)

            Divider()

            Picker("Scheduler", selection: schedulerSelection) {
                ForEach(SchedulerAlgorithm.allCases) { algorithm in
                    Text(algorithm.title).tag(algorithm)
                }
            }

            Text(deck.schedulerAlgorithm.description)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)

            if deck.schedulerAlgorithm == .fsrs6 {
                HStack {
                    Text("Target retention")
                    Slider(value: retentionSelection, in: 0.70...0.97, step: 0.01)
                    Text(deck.desiredRetention, format: .percent.precision(.fractionLength(0)))
                        .monospacedDigit()
                        .frame(width: 42, alignment: .trailing)
                }
            }
        }
        .padding(20)
        .frame(width: 390)
    }

    private var schedulerSelection: Binding<SchedulerAlgorithm> {
        Binding(
            get: { deck.schedulerAlgorithm },
            set: { algorithm in
                deck.schedulerAlgorithm = algorithm
                deck.updatedAt = .now
                try? modelContext.save()
            }
        )
    }

    private var retentionSelection: Binding<Double> {
        Binding(
            get: { deck.desiredRetention },
            set: { retention in
                deck.desiredRetention = retention
                deck.updatedAt = .now
                try? modelContext.save()
            }
        )
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
                            CharacterRow(character: character, subsetName: selectedSubset)
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
            kind: kind,
            subsetName: selectedSubset
        )
        guard !configuration.prompts.isEmpty else { return }
        studyConfiguration = configuration
    }

    private func sessionCount(_ kind: StudySessionKind) -> Int {
        StudySessionBuilder.count(
            deck: deck,
            method: learningMethod,
            kind: kind,
            subsetName: selectedSubset
        )
    }

    private func createSubset() {
        let cleanName = newSubsetName.trimmingCharacters(in: .whitespacesAndNewlines)
        newSubsetName = ""
        guard !cleanName.isEmpty else { return }
        deck.subsetNames = deck.subsetNames + [cleanName]
        deck.updatedAt = .now
        selectedSubset = cleanName
        try? modelContext.save()
    }

    private func deleteSelectedSubset() {
        guard let name = selectedSubset, !name.isEmpty else { return }
        for word in deck.words where word.subsetName == name {
            word.subsetName = ""
        }
        deck.subsetNames = deck.subsetNames.filter { $0 != name }
        deck.updatedAt = .now
        selectedSubset = nil
        try? modelContext.save()
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
            if !word.subsetName.isEmpty {
                Text(word.subsetName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.secondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.elevatedSurface)
                    .clipShape(Capsule())
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
    let subsetName: String?

    private var contextLines: [String] {
        let lines = character.sourceContexts.compactMap { context -> String? in
            guard let word = context.sourceWord,
                  subsetName == nil || word.subsetName == subsetName else { return nil }
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
#endif
