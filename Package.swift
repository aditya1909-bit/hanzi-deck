// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "HanziDeck",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "HanziDeck", targets: ["HanziDeck"])
    ],
    targets: [
        .executableTarget(
            name: "HanziDeck",
            path: "AppSources/HanziDeck",
            resources: [.process("Resources")],
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .testTarget(
            name: "HanziDeckTests",
            dependencies: ["HanziDeck"]
        )
    ]
)
