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
    targets: [
        .executableTarget(
            name: "LongAutoTyper",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
