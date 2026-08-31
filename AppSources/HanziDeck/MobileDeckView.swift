#if os(iOS)
import SwiftData
import SwiftUI

struct MobileDeckView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var deck: Deck

    @State private var browseMode: StudyMode = .word
    @State private var learningMethod: LearningMethod = .hanziRecognition
    @State private var showingAddWord = false
    @State private var showingImageImport = false
    @State private var studyConfiguration: StudyConfiguration?
    @State private var editingWord: WordCard?

    private var dueCount: Int {
        StudySessionBuilder.count(deck: deck, method: learningMethod, kind: .due)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                progressPanel
                studyPanel

                Picker("Cards", selection: $browseMode) {
                    ForEach(StudyMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if browseMode == .word {
                    ForEach(deck.words.sorted { $0.createdAt < $1.createdAt }) { word in
                        MobileWordRow(word: word) { editingWord = word }
                            .contextMenu {
                                Button("Delete", role: .destructive) { delete(word) }
                            }
                    }
                } else {
                    ForEach(deck.characters.sorted { $0.createdAt < $1.createdAt }) { character in
                        MobileCharacterRow(character: character)
                    }
                }
            }
            .padding()
        }
        .background(AppTheme.background)
        .navigationTitle(deck.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { showingImageImport = true } label: {
                    Image(systemName: "text.viewfinder")
                }
                .accessibilityLabel("Import Chinese words from photos")
                Button { showingAddWord = true } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add a word")
            }
        }
        .sheet(isPresented: $showingAddWord) {
            MobileCardEditorView(deck: deck)
        }
        .sheet(item: $editingWord) { word in
            MobileCardEditorView(deck: deck, word: word)
        }
        .sheet(isPresented: $showingImageImport) {
            MobileImageImportView(deck: deck)
        }
        .fullScreenCover(item: $studyConfiguration) { configuration in
            MobileStudyView(configuration: configuration)
        }
    }

    private var progressPanel: some View {
        HStack(spacing: 0) {
            metric(value: deck.words.count, label: "Words")
            Divider().overlay(AppTheme.divider)
            metric(value: deck.characters.count, label: "Characters")
            Divider().overlay(AppTheme.divider)
            metric(value: dueCount, label: "Due")
        }
        .padding(.vertical, 14)
        .darkPanel()
    }

    private var studyPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Study", systemImage: learningMethod.symbol)
                    .font(.headline)
                    .foregroundStyle(AppTheme.primaryText)
                Spacer()
                Menu(learningMethod.title) {
                    ForEach(LearningMethod.allCases) { method in
                        Button(method.title) { learningMethod = method }
                    }
                }
            }

            Text(learningMethod.shortDescription)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)

            HStack {
                Menu {
                    ForEach(SchedulerAlgorithm.allCases) { algorithm in
                        Button(algorithm.title) {
                            deck.schedulerAlgorithm = algorithm
                            persistDeckSettings()
                        }
                    }
                } label: {
                    Label(deck.schedulerAlgorithm.title, systemImage: "calendar.badge.clock")
                }
                Spacer()
                if deck.schedulerAlgorithm == .fsrs6 {
                    Text("\(deck.desiredRetention, format: .percent.precision(.fractionLength(0))) target")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }

            if deck.schedulerAlgorithm == .fsrs6 {
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
                .accessibilityLabel("FSRS target retention")
            }

            Button {
                beginStudy(.due)
            } label: {
                Text("Study This Deck · \(dueCount) Due")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(OrangeButtonStyle())
            .disabled(dueCount == 0)

            Menu {
                ForEach(StudySessionKind.allCases) { kind in
                    Button("\(kind.title) (\(sessionCount(kind)))") { beginStudy(kind) }
                        .disabled(sessionCount(kind) == 0)
                }
            } label: {
                Label("Choose another session", systemImage: "ellipsis.circle")
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .darkPanel()
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
            kind: kind
        )
        guard !configuration.prompts.isEmpty else { return }
        studyConfiguration = configuration
    }

    private func sessionCount(_ kind: StudySessionKind) -> Int {
        StudySessionBuilder.count(deck: deck, method: learningMethod, kind: kind)
    }

    private func persistDeckSettings() {
        deck.updatedAt = .now
        try? modelContext.save()
    }

    private func delete(_ word: WordCard) {
        try? CardRepository.deleteWord(word, context: modelContext)
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

    private var contextLines: [String] {
        let lines = character.sourceContexts.compactMap { context -> String? in
            guard let word = context.sourceWord else { return nil }
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
