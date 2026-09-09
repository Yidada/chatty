// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "RedirectProbe", platforms: [.macOS(.v15)], dependencies: [.package(path: "../../Packages/ChattyKit")], targets: [.executableTarget(name: "RedirectProbe", dependencies: [.product(name: "ChattyFixtureSupport", package: "ChattyKit"), .product(name: "ChattyCore", package: "ChattyKit")], path: "Sources")])
