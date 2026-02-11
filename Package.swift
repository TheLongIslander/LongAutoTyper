// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LongAutoTyper",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "LongAutoTyper", targets: ["LongAutoTyper"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "LongAutoTyper",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
