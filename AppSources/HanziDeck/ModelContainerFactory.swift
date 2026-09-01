import Foundation
import SwiftData

enum ModelContainerFactory {
    static let cloudContainerIdentifier = "iCloud.com.aditya1909.HanziDeck"

    static let schema = Schema([
        Deck.self,
        WordCard.self,
        CharacterCard.self,
        CharacterContext.self,
        WordReviewState.self,
        CharacterReviewState.self
    ])

    static func make(cloudSyncEnabled: Bool) throws -> ModelContainer {
        let cloudDatabase: ModelConfiguration.CloudKitDatabase = cloudSyncEnabled
            ? .private(cloudContainerIdentifier)
            : .none
#if os(macOS)
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        let storeDirectory = applicationSupport.appending(
            path: "HanziDeck",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: storeDirectory,
            withIntermediateDirectories: true
        )
        let configuration = ModelConfiguration(
            "HanziDeck",
            schema: schema,
            url: storeDirectory.appending(path: "HanziDeck.store"),
            cloudKitDatabase: cloudDatabase
        )
#else
        let configuration = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: cloudDatabase
        )
#endif
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
