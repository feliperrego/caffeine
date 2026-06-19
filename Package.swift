// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Caffeine",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "CaffeineCore"),
        .executableTarget(name: "Caffeine", dependencies: ["CaffeineCore"]),
        .testTarget(name: "CaffeineCoreTests", dependencies: ["CaffeineCore"]),
    ]
)
