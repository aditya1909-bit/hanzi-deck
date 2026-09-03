#if os(iOS)
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct MobileDeckView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var deck: Deck

    @State private var browseMode: StudyMode = .word
    @State private var learningMethod: LearningMethod = .hanziRecognition
    @State private var showingAddWord = false
    @State private var showingImageImport = false
    @State private var showingStudySettings = false
    @State private var studyConfiguration: StudyConfiguration?
    @State private var editingWord: WordCard?
    @State private var exportDocument: DeckTransferDocument?
    @State private var showingDeckExporter = false
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

    private var dueCount: Int {
        StudySessionBuilder.count(deck: deck, method: learningMethod, kind: .due)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                progressPanel
                studyPanel

                Picker("Deck part", selection: $selectedSubset) {
                    Text("All Cards").tag(String?.none)
                    Text("Unfiled").tag(Optional(""))
                    ForEach(deck.subsetNames, id: \.self) { name in
                        Text(name).tag(Optional(name))
                    }
                }
                .pickerStyle(.menu)

                Picker("Cards", selection: $browseMode) {
                    ForEach(StudyMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if browseMode == .word {
                    ForEach(scopedWords.sorted { $0.createdAt < $1.createdAt }) { word in
                        MobileWordRow(word: word) { editingWord = word }
                            .contextMenu {
                                Button("Delete", role: .destructive) { delete(word) }
                            }
                    }
                } else {
                    ForEach(scopedCharacters.sorted { $0.createdAt < $1.createdAt }) { character in
                        MobileCharacterRow(character: character, subsetName: selectedSubset)
                    }
                }
            }
            .padding()
        }
        .background(AppTheme.background)
        .navigationTitle(deck.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Import from Photos", systemImage: "text.viewfinder") {
                        showingImageImport = true
                    }
                    Button("Export Deck", systemImage: "square.and.arrow.up") {
                        exportDeck()
                    }
                    Button("New Deck Part", systemImage: "folder.badge.plus") {
                        showingNewSubset = true
                    }
                    if selectedSubset?.isEmpty == false {
                        Button("Delete Current Part", systemImage: "folder.badge.minus", role: .destructive) {
                            showingDeleteSubset = true
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Deck options")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingAddWord = true } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add a word")
            }
        }
        .sheet(isPresented: $showingAddWord) {
            MobileCardEditorView(deck: deck, initialSubset: selectedSubset)
        }
        .sheet(item: $editingWord) { word in
            MobileCardEditorView(deck: deck, word: word)
        }
        .sheet(isPresented: $showingImageImport) {
            MobileImageImportView(deck: deck, subsetName: selectedSubset)
        }
        .sheet(isPresented: $showingStudySettings) {
            studySettings
        }
        .fullScreenCover(item: $studyConfiguration) { configuration in
            MobileStudyView(configuration: configuration)
        }
        .fileExporter(
            isPresented: $showingDeckExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: exportFilename
        ) { _ in
            exportDocument = nil
        }
        .alert("New Deck Part", isPresented: $showingNewSubset) {
            TextField("Part name", text: $newSubsetName)
            Button("Cancel", role: .cancel) { newSubsetName = "" }
            Button("Create", action: createSubset)
        } message: {
            Text("Parts let you study a smaller group of words.")
        }
        .alert("Delete this part?", isPresented: $showingDeleteSubset) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive, action: deleteSelectedSubset)
        } message: {
            Text("The words will remain in the deck as Unfiled.")
        }
    }

    private var progressPanel: some View {
        HStack(spacing: 0) {
            metric(value: scopedWords.count, label: "Words")
            Divider().overlay(AppTheme.divider)
            metric(value: scopedCharacters.count, label: "Characters")
            Divider().overlay(AppTheme.divider)
            metric(value: dueCount, label: "Due")
        }
        .padding(.vertical, 14)
        .darkPanel()
    }

    private var studyPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: learningMethod.symbol)
                    .font(.title3)
                    .foregroundStyle(AppTheme.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(dueCount == 0 ? "You’re caught up" : "\(dueCount) card\(dueCount == 1 ? "" : "s") due")
                        .font(.headline)
                        .foregroundStyle(AppTheme.primaryText)
                    Text(learningMethod.title)
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
                Menu {
                    Section("Sessions") {
                        ForEach(StudySessionKind.allCases) { kind in
                            Button("\(kind.title) (\(sessionCount(kind)))") { beginStudy(kind) }
                                .disabled(sessionCount(kind) == 0)
                        }
                    }
                    Divider()
                    Button("Study Settings") { showingStudySettings = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
                .accessibilityLabel("More study options")
            }

            Button {
                beginStudy(.adaptive)
            } label: {
                Text("Adaptive Learn")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(OrangeButtonStyle())
            .disabled(sessionCount(.adaptive) == 0)
        }
        .padding(16)
        .darkPanel()
    }

    private var studySettings: some View {
        NavigationStack {
            Form {
                Section("Learning Method") {
                    Picker("Method", selection: $learningMethod) {
                        ForEach(LearningMethod.allCases) { method in
                            Text(method.title).tag(method)
                        }
                    }
                    Text(learningMethod.shortDescription)
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Section("Scheduling") {
                    Picker("Scheduler", selection: Binding(
                        get: { deck.schedulerAlgorithm },
                        set: {
                            deck.schedulerAlgorithm = $0
                            persistDeckSettings()
                        }
                    )) {
                        ForEach(SchedulerAlgorithm.allCases) { algorithm in
                            Text(algorithm.title).tag(algorithm)
                        }
                    }

                    if deck.schedulerAlgorithm == .fsrs6 {
                        VStack(alignment: .leading) {
                            Text("Target Retention: \(deck.desiredRetention, format: .percent.precision(.fractionLength(0)))")
                            Slider(
                                value: Binding(
                                    get: { deck.desiredRetention },
                                    set: {
                                        deck.desiredRetention = $0
                                        persistDeckSettings()
                                    }
                                ),
                                in: 0.70...0.97,
                                step: 0.01
                            )
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle("Study Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingStudySettings = false }
                }
            }
        }
        .tint(AppTheme.orange)
    }

    private func metric(value: Int, label: String) -> some View {
        VStack(spacing: 3) {
            Text("\(value)")
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(AppTheme.primaryText)
            Text(label)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
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

    private func persistDeckSettings() {
        deck.updatedAt = .now
        try? modelContext.save()
    }

    private func delete(_ word: WordCard) {
        try? CardRepository.deleteWord(word, context: modelContext)
    }

    private var exportFilename: String {
        "\(deck.name.replacingOccurrences(of: "/", with: "-")).hanzideck.json"
    }

    private func exportDeck() {
        exportDocument = DeckTransferDocument(deck: deck)
        showingDeckExporter = true
    }

    private func createSubset() {
        let cleanName = newSubsetName.trimmingCharacters(in: .whitespacesAndNewlines)
        newSubsetName = ""
        guard !cleanName.isEmpty else { return }
        deck.subsetNames = deck.subsetNames + [cleanName]
        selectedSubset = cleanName
        persistDeckSettings()
    }

    private func deleteSelectedSubset() {
        guard let name = selectedSubset, !name.isEmpty else { return }
        for word in deck.words where word.subsetName == name {
            word.subsetName = ""
        }
        deck.subsetNames = deck.subsetNames.filter { $0 != name }
        selectedSubset = nil
        persistDeckSettings()
    }
}

private struct MobileWordRow: View {
    let word: WordCard
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 14) {
                Text(word.hanzi)
                    .font(.system(size: 29, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(minWidth: 82, alignment: .leading)
                VStack(alignment: .leading, spacing: 3) {
                    Text(word.pinyin)
                        .foregroundStyle(AppTheme.orange)
                    Text(word.meaning)
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .padding(14)
            .darkPanel()
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens this card for editing")
    }
}

private struct MobileCharacterRow: View {
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
        HStack(spacing: 16) {
            Text(character.glyph)
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
                .frame(width: 58)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(contextLines, id: \.self) { line in
                    Text(line)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
            Spacer()
        }
        .padding(14)
        .darkPanel()
    }
}
#endif
