// swift-tools-version:5.9
import PackageDescription

// OddlyTownCore is pure Foundation so its tests also run on Linux (e.g. in Docker).
// The OddlyTown app target uses AppKit/SpriteKit/SwiftUI and is only added on macOS.
var products: [Product] = [
    .library(name: "OddlyTownCore", targets: ["OddlyTownCore"]),
]
var targets: [Target] = [
    .target(name: "OddlyTownCore"),
    .testTarget(name: "OddlyTownCoreTests", dependencies: ["OddlyTownCore"]),
]

#if os(macOS)
products.append(.executable(name: "OddlyTown", targets: ["OddlyTown"]))
targets.append(.executableTarget(name: "OddlyTown", dependencies: ["OddlyTownCore"]))
#endif

let package = Package(
    name: "OddlyTown",
    platforms: [.macOS(.v14)],
    products: products,
    targets: targets
)
