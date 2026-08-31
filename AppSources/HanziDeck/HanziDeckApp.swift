#if os(macOS)
import SwiftData
import SwiftUI

@main
struct HanziDeckApp: App {
    private let modelContainer: ModelContainer = {
        do {
            return try ModelContainerFactory.make(cloudSyncEnabled: false)
        } catch {
            fatalError("Could not create the local data store: \(error)")
        }
    }()

    @StateObject private var dictionary = DictionaryService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dictionary)
                .preferredColorScheme(.dark)
                .frame(minWidth: 900, minHeight: 620)
        }
        .modelContainer(modelContainer)
        .defaultSize(width: 1160, height: 760)
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Deck") {
                    NotificationCenter.default.post(name: .newDeckRequested, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}

extension Notification.Name {
    static let newDeckRequested = Notification.Name("HanziDeck.newDeckRequested")
}
#endif
