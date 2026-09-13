// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "ChattyNextKit", platforms: [.iOS("26.0"), .macOS(.v15)],
    products: [.library(name: "ChattyNextCore", targets: ["ChattyNextCore"])],
    targets: [.target(name: "ChattyNextCore"), .executableTarget(name: "NextProbe", dependencies: ["ChattyNextCore"]), .testTarget(name: "ChattyNextCoreTests", dependencies: ["ChattyNextCore"], resources: [.copy("Fixtures")])])
