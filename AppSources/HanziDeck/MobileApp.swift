#if os(iOS)
import SwiftData
import SwiftUI

@main
struct HanziDeckMobileApp: App {
    private let modelContainer: ModelContainer = {
        do {
            return try ModelContainerFactory.make(cloudSyncEnabled: true)
        } catch let cloudError {
            do {
                return try ModelContainerFactory.make(cloudSyncEnabled: false)
            } catch {
                fatalError("Could not create a data store. iCloud: \(cloudError); local: \(error)")
            }
        }
    }()

    @StateObject private var dictionary = DictionaryService()

    var body: some Scene {
        WindowGroup {
            MobileRootView()
                .environmentObject(dictionary)
                .preferredColorScheme(.dark)
        }
        .modelContainer(modelContainer)
    }
}
#endif
