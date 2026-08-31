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
        let configuration = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: cloudDatabase
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
