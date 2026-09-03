#if os(macOS)
import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dictionary: DictionaryService
    @Query(sort: \Deck.createdAt) private var decks: [Deck]

    @State private var selectedDeckID: UUID?
    @State private var showingNewDeck = false
    @State private var showingAbout = false
    @State private var showingTutorial = false
    @State private var deckSearchText = ""
    @State private var deckToRename: Deck?
    @State private var deckToDelete: Deck?
    @State private var exportDocument: DeckTransferDocument?
    @State private var exportFilename = "Hanzi Deck"
    @State private var showingDeckExporter = false
    @State private var showingDeckImporter = false
    @State private var importErrorMessage: String?
    @AppStorage("hasCompletedWelcome") private var hasCompletedWelcome = false
    @AppStorage("deckSortOrder") private var deckSortOrderRaw = DeckSortOrder.alphabetical.rawValue

    private var selectedDeck: Deck? {
        decks.first { $0.id == selectedDeckID }
    }

    private var organizedDecks: [Deck] {
        let filtered = decks.filter {
            deckSearchText.isEmpty || $0.name.localizedCaseInsensitiveContains(deckSearchText)
        }
        return switch DeckSortOrder(rawValue: deckSortOrderRaw) ?? .alphabetical {
        case .alphabetical:
            filtered.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .recentlyUpdated:
            filtered.sorted { $0.updatedAt > $1.updatedAt }
        case .mostDue:
            filtered.sorted {
                let leftDue = dueCount(for: $0)
                let rightDue = dueCount(for: $1)
                return leftDue == rightDue
                    ? $0.name.localizedStandardCompare($1.name) == .orderedAscending
                    : leftDue > rightDue
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 250, ideal: 280, max: 340)
        } detail: {
            if let selectedDeck {
                DeckDetailView(
                    deck: selectedDeck,
                    onRename: { deckToRename = selectedDeck },
                    onExport: { export(selectedDeck) },
                    onDelete: { deckToDelete = selectedDeck }
                )
            } else {
                emptyDetail
            }
        }
        .background(AppTheme.background)
        .sheet(isPresented: $showingNewDeck) {
            DeckNameView(title: "New Deck", initialName: "", actionTitle: "Create") { name in
                let deck = Deck(name: name)
                modelContext.insert(deck)
                try? modelContext.save()
                selectedDeckID = deck.id
            }
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
        .sheet(isPresented: $showingTutorial) {
            WelcomeView {
                hasCompletedWelcome = true
                showingTutorial = false
            }
        }
        .sheet(item: $deckToRename) { deck in
            DeckNameView(title: "Rename Deck", initialName: deck.name, actionTitle: "Save") { name in
                deck.name = name
                deck.updatedAt = .now
                try? modelContext.save()
            }
        }
        .fileExporter(
            isPresented: $showingDeckExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: exportFilename
        ) { _ in
            exportDocument = nil
        }
        .fileImporter(
            isPresented: $showingDeckImporter,
            allowedContentTypes: [.json]
        ) { result in
            importDeck(from: result)
        }
        .alert("Delete Deck?", isPresented: Binding(
            get: { deckToDelete != nil },
            set: { if !$0 { deckToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { deckToDelete = nil }
            Button("Delete", role: .destructive) {
                if let deckToDelete { delete(deckToDelete) }
            }
        } message: {
            Text("This permanently deletes the deck, its cards, and its review history.")
        }
        .alert("Couldn’t Import Deck", isPresented: Binding(
            get: { importErrorMessage != nil },
            set: { if !$0 { importErrorMessage = nil } }
        )) {
            Button("OK") { importErrorMessage = nil }
        } message: {
            Text(importErrorMessage ?? "The selected file could not be imported.")
        }
        .onReceive(NotificationCenter.default.publisher(for: .newDeckRequested)) { _ in
            showingNewDeck = true
        }
        .onAppear {
            cleanPreviouslyImportedMeanings()
            if !hasCompletedWelcome {
                showingTutorial = true
            }
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 38, height: 38)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("HANZI DECK")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.primaryText)
                    Text("Chinese character study")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
                Menu {
                    Button {
                        showingDeckImporter = true
                    } label: {
                        Label("Import Deck", systemImage: "square.and.arrow.down")
                    }
                    if let selectedDeck {
                        Divider()
                        Button("Rename \(selectedDeck.name)") { deckToRename = selectedDeck }
                        Button("Export \(selectedDeck.name)") { export(selectedDeck) }
                        Button("Delete \(selectedDeck.name)", role: .destructive) {
                            deckToDelete = selectedDeck
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18))
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .menuStyle(.borderlessButton)
                .help("Deck options")
                Button {
                    showingNewDeck = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.black)
                        .frame(width: 30, height: 30)
                        .background(AppTheme.orange)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("New Deck")
                .accessibilityLabel("Create a new deck")
            }
            .padding(18)

            Divider().overlay(AppTheme.divider)

            if decks.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "rectangle.stack")
                        .font(.system(size: 28))
                        .foregroundStyle(AppTheme.orange)
                    Text("No decks yet")
                        .foregroundStyle(AppTheme.primaryText)
                    Text("Create a deck to add your first Chinese word.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(28)
                Spacer()
            } else {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(AppTheme.secondaryText)
                        TextField("Search decks", text: $deckSearchText)
                            .textFieldStyle(.plain)
                        Menu {
                            ForEach(DeckSortOrder.allCases) { order in
                                Button {
                                    deckSortOrderRaw = order.rawValue
                                } label: {
                                    if deckSortOrderRaw == order.rawValue {
                                        Label(order.title, systemImage: "checkmark")
                                    } else {
                                        Text(order.title)
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        .menuStyle(.borderlessButton)
                        .help("Sort decks")
                    }
                    .padding(9)
                    .background(AppTheme.elevatedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 10)
                    .padding(.top, 10)

                    if organizedDecks.isEmpty {
                        Text("No matching decks")
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 6) {
                                ForEach(organizedDecks) { deck in
                                    DeckSidebarRow(deck: deck, isSelected: deck.id == selectedDeckID)
                                        .contentShape(Rectangle())
                                        .onTapGesture { selectedDeckID = deck.id }
                                        .contextMenu {
                                            Button("Rename") { deckToRename = deck }
                                            Button("Export") { export(deck) }
                                            Divider()
                                            Button("Delete", role: .destructive) { deckToDelete = deck }
                                        }
                                        .accessibilityAddTraits(deck.id == selectedDeckID ? .isSelected : [])
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.bottom, 10)
                        }
                    }
                }
            }

            Divider().overlay(AppTheme.divider)
            VStack(spacing: 0) {
                Button {
                    showingDeckImporter = true
                } label: {
                    Label("Import Deck", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(AppTheme.secondaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)

                Button {
                    showingTutorial = true
                } label: {
                    Label("How to Use", systemImage: "questionmark.circle")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(AppTheme.secondaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)

                Button {
                    showingAbout = true
                } label: {
                    Label("About & Dictionary", systemImage: "info.circle")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(AppTheme.secondaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 6)
        }
        .background(AppTheme.surface)
    }

    private var emptyDetail: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 112, height: 112)
                .accessibilityLabel("Hanzi Deck logo")
            Text("Learn words. Know every character.")
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppTheme.primaryText)
            Text("Choose a deck or create one to begin.")
                .foregroundStyle(AppTheme.secondaryText)
            Button("Create Deck") { showingNewDeck = true }
                .buttonStyle(OrangeButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
    }

    private func cleanPreviouslyImportedMeanings() {
        var changed = false
        for word in decks.flatMap(\.words) {
            if let cleaned = dictionary.cleanedMeaning(
                for: word.hanzi,
                pinyin: word.pinyin,
                storedMeaning: word.meaning
            ) {
                word.meaning = cleaned
                changed = true
            }
        }
        if changed {
            try? modelContext.save()
        }
    }

    private func dueCount(for deck: Deck) -> Int {
        deck.words.filter { ($0.reviewState?.dueAt ?? .distantFuture) <= .now }.count
            + deck.characters.filter { ($0.reviewState?.dueAt ?? .distantFuture) <= .now }.count
    }

    private func export(_ deck: Deck) {
        exportDocument = DeckTransferDocument(deck: deck)
        let cleanName = deck.name.replacingOccurrences(of: "/", with: "-")
        exportFilename = "\(cleanName).hanzideck.json"
        showingDeckExporter = true
    }

    private func importDeck(from result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            let document = try DeckTransferDocument(data: Data(contentsOf: url))
            let deck = try DeckTransferService.importDeck(
                document.archive,
                existingNames: Set(decks.map(\.name)),
                context: modelContext
            )
            selectedDeckID = deck.id
        } catch {
            importErrorMessage = error.localizedDescription
        }
    }

    private func delete(_ deck: Deck) {
        if selectedDeckID == deck.id { selectedDeckID = nil }
        modelContext.delete(deck)
        try? modelContext.save()
        deckToDelete = nil
    }
}

private enum DeckSortOrder: String, CaseIterable, Identifiable {
    case alphabetical
    case recentlyUpdated
    case mostDue

    var id: String { rawValue }

    var title: String {
        switch self {
        case .alphabetical: "Name"
        case .recentlyUpdated: "Recently Updated"
        case .mostDue: "Most Due"
        }
    }
}

private struct WelcomeView: View {
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 88, height: 88)
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text("Welcome to Hanzi Deck")
                    .font(.title.bold())
                    .foregroundStyle(AppTheme.primaryText)
                Text("Your Chinese study space, ready in three steps.")
                    .foregroundStyle(AppTheme.secondaryText)
            }

            VStack(spacing: 12) {
                TutorialStep(
                    number: "1",
                    title: "Create a deck",
                    detail: "Keep words together by class, topic, or textbook."
                )
                TutorialStep(
                    number: "2",
                    title: "Add Chinese words",
                    detail: "Type a word for automatic pinyin and meaning, or import many words from a screenshot."
                )
                TutorialStep(
                    number: "3",
                    title: "Study your way",
                    detail: "Split large decks into parts, then use Adaptive Learn to build a personalized working set. Other study methods remain available in each deck."
                )
            }

            Text("During study: Space reveals the answer • 1–4 rates it • Escape exits")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)

            Button("Get Started", action: onFinish)
                .buttonStyle(OrangeButtonStyle())
                .keyboardShortcut(.defaultAction)
        }
        .padding(32)
        .frame(width: 560)
        .background(AppTheme.background)
    }
}

private struct TutorialStep: View {
    let number: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 14) {
            Text(number)
                .font(.headline)
                .foregroundStyle(Color.black)
                .frame(width: 32, height: 32)
                .background(AppTheme.orange)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.primaryText)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .darkPanel()
        .accessibilityElement(children: .combine)
    }
}

private struct DeckSidebarRow: View {
    let deck: Deck
    let isSelected: Bool

    private var wordDue: Int {
        deck.words.filter { ($0.reviewState?.dueAt ?? .distantFuture) <= .now }.count
    }

    private var characterDue: Int {
        deck.characters.filter { ($0.reviewState?.dueAt ?? .distantFuture) <= .now }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(deck.name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
            HStack(spacing: 12) {
                Label("\(wordDue)", systemImage: "textformat")
                Label("\(characterDue)", systemImage: "character.book.closed")
            }
            .font(.caption)
            .foregroundStyle(isSelected ? AppTheme.orange : AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(isSelected ? AppTheme.orange.opacity(0.12) : Color.clear)
        .overlay(alignment: .leading) {
            if isSelected {
                Rectangle().fill(AppTheme.orange).frame(width: 3)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct DeckNameView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    let title: String
    let actionTitle: String
    let onSave: (String) -> Void

    init(
        title: String,
        initialName: String,
        actionTitle: String,
        onSave: @escaping (String) -> Void
    ) {
        self.title = title
        self.actionTitle = actionTitle
        self.onSave = onSave
        _name = State(initialValue: initialName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(AppTheme.primaryText)
            TextField("Deck name", text: $name)
                .textFieldStyle(DarkFieldStyle())
                .onSubmit(save)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(actionTitle, action: save)
                    .buttonStyle(OrangeButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 420)
        .background(AppTheme.background)
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSave(trimmed)
        dismiss()
    }
}
#endif
