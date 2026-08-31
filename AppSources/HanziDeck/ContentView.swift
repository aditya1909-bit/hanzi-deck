import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Deck.createdAt) private var decks: [Deck]

    @State private var selectedDeckID: UUID?
    @State private var showingNewDeck = false
    @State private var showingAbout = false

    private var selectedDeck: Deck? {
        decks.first { $0.id == selectedDeckID }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 250, ideal: 280, max: 340)
        } detail: {
            if let selectedDeck {
                DeckDetailView(deck: selectedDeck)
            } else {
                emptyDetail
            }
        }
        .background(AppTheme.background)
        .sheet(isPresented: $showingNewDeck) {
            NewDeckView { name in
                let deck = Deck(name: name)
                modelContext.insert(deck)
                try? modelContext.save()
                selectedDeckID = deck.id
            }
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .newDeckRequested)) { _ in
            showingNewDeck = true
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("HANZI DECK")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.primaryText)
                    Text("Chinese character study")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
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
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(decks) { deck in
                            DeckSidebarRow(deck: deck, isSelected: deck.id == selectedDeckID)
                                .contentShape(Rectangle())
                                .onTapGesture { selectedDeckID = deck.id }
                                .accessibilityAddTraits(deck.id == selectedDeckID ? .isSelected : [])
                        }
                    }
                    .padding(10)
                }
            }

            Divider().overlay(AppTheme.divider)
            Button {
                showingAbout = true
            } label: {
                Label("About & Dictionary", systemImage: "info.circle")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(AppTheme.secondaryText)
                    .padding(14)
            }
            .buttonStyle(.plain)
        }
        .background(AppTheme.surface)
    }

    private var emptyDetail: some View {
        VStack(spacing: 14) {
            Text("字")
                .font(.system(size: 96, weight: .semibold))
                .foregroundStyle(AppTheme.orange)
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
}

private struct DeckSidebarRow: View {
    let deck: Deck
    let isSelected: Bool

    private var wordDue: Int {
        deck.wordCards.filter { ($0.reviewState?.dueAt ?? .distantFuture) <= .now }.count
    }

    private var characterDue: Int {
        deck.characterCards.filter { ($0.reviewState?.dueAt ?? .distantFuture) <= .now }.count
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

private struct NewDeckView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    let onSave: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("New Deck")
                .font(.title2.bold())
                .foregroundStyle(AppTheme.primaryText)
            TextField("Deck name", text: $name)
                .textFieldStyle(DarkFieldStyle())
                .onSubmit(save)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Create", action: save)
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
