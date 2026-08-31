#if os(iOS)
import SwiftData
import SwiftUI

struct MobileRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Deck.createdAt) private var decks: [Deck]

    @State private var showingNewDeck = false
    @State private var showingAbout = false

    var body: some View {
        NavigationStack {
            Group {
                if decks.isEmpty {
                    emptyState
                } else {
                    List {
                        Section {
                            ForEach(decks) { deck in
                                NavigationLink {
                                    MobileDeckView(deck: deck)
                                } label: {
                                    MobileDeckRow(deck: deck)
                                }
                                .listRowBackground(AppTheme.surface)
                            }
                            .onDelete(perform: deleteDecks)
                        } header: {
                            Text("Your decks")
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(AppTheme.background)
            .navigationTitle("Hanzi Deck")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingAbout = true } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel("About Hanzi Deck and iCloud sync")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingNewDeck = true } label: {
                        Image(systemName: "plus")
                            .fontWeight(.bold)
                            .foregroundStyle(Color.black)
                            .frame(width: 32, height: 32)
                            .background(AppTheme.orange)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Create a new deck")
                }
            }
            .sheet(isPresented: $showingNewDeck) {
                MobileNewDeckView { name in
                    let deck = Deck(name: name)
                    modelContext.insert(deck)
                    try? modelContext.save()
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showingAbout) {
                MobileAboutView()
            }
        }
        .tint(AppTheme.orange)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Start your first deck", systemImage: "character.book.closed")
                .foregroundStyle(AppTheme.orange)
        } description: {
            Text("Add Chinese words manually or import them from screenshots.")
                .foregroundStyle(AppTheme.secondaryText)
        } actions: {
            Button("Create Deck") { showingNewDeck = true }
                .buttonStyle(OrangeButtonStyle())
        }
    }

    private func deleteDecks(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(decks[index]) }
        try? modelContext.save()
    }
}

private struct MobileDeckRow: View {
    let deck: Deck

    private var wordDue: Int {
        deck.words.filter { ($0.reviewState?.dueAt ?? .distantFuture) <= .now }.count
    }

    private var characterDue: Int {
        deck.characters.filter { ($0.reviewState?.dueAt ?? .distantFuture) <= .now }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(deck.name)
                .font(.headline)
                .foregroundStyle(AppTheme.primaryText)
            HStack(spacing: 14) {
                Label("\(wordDue) words due", systemImage: "textformat")
                Label("\(characterDue) characters", systemImage: "character.book.closed")
            }
            .font(.caption)
            .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(.vertical, 6)
    }
}

private struct MobileNewDeckView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    let onSave: (String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Deck name", text: $name)
                    .textInputAutocapitalization(.words)
                    .onSubmit(save)
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.background)
            .navigationTitle("New Deck")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        onSave(cleanName)
        dismiss()
    }
}

private struct MobileAboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Text("字")
                        .font(.system(size: 72, weight: .bold))
                        .foregroundStyle(AppTheme.orange)
                    Text("Hanzi Deck")
                        .font(.title.bold())
                        .foregroundStyle(AppTheme.primaryText)
                    Label("Decks sync automatically with iCloud", systemImage: "icloud.fill")
                        .foregroundStyle(AppTheme.orange)
                    Text("Use the same Apple Account on your devices. Changes are stored locally first and synchronize when iCloud is available.")
                        .foregroundStyle(AppTheme.secondaryText)
                        .multilineTextAlignment(.center)
                    Divider().overlay(AppTheme.divider)
                    Text("Dictionary data is provided by CC-CEDICT under CC BY-SA 4.0. Recognition, OCR, scheduling, and storage all work without a separate Hanzi Deck account.")
                        .foregroundStyle(AppTheme.secondaryText)
                    Link("CC-CEDICT attribution", destination: URL(string: "https://www.mdbg.net/chinese/dictionary?page=cc-cedict")!)
                        .foregroundStyle(AppTheme.orange)
                }
                .padding(24)
            }
            .background(AppTheme.background)
            .navigationTitle("About")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
#endif
