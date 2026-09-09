// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ChattyKit",
    platforms: [.iOS("26.0"), .macOS(.v15)],
    products: [
        .library(name: "ChattyCore", targets: ["ChattyCore"]),
        .library(name: "ChattyFixtureSupport", targets: ["ChattyFixtureSupport"]),
    ],
    dependencies: [
        .package(url: "git@github.com:swiftlang/swift-markdown.git", exact: "0.8.0"),
    ],
    targets: [
        .target(name: "ChattyCore", dependencies: [.product(name: "Markdown", package: "swift-markdown")]),
        .target(name: "ChattyFixtureSupport", dependencies: ["ChattyCore"]),
        .testTarget(name: "ChattyCoreTests", dependencies: ["ChattyCore", "ChattyFixtureSupport"], resources: [.copy("Fixtures")]),
    ]
)
