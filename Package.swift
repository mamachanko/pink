// swift-tools-version: 6.0
import PackageDescription

#if os(macOS)
    let platformProducts: [Product] = [.library(name: "RefPastePlatform", targets: ["RefPastePlatform"])]
    let platformTargets: [Target] = [
        .target(name: "RefPastePlatform", dependencies: ["RefPasteCore"], exclude: ["AGENTS.md"]),
        .testTarget(name: "RefPastePlatformTests", dependencies: ["RefPastePlatform"]),
    ]
#else
    let platformProducts: [Product] = []
    let platformTargets: [Target] = []
#endif

let package = Package(
    name: "RefPaste",
    platforms: [.macOS(.v15)],
    products: [.library(name: "RefPasteCore", targets: ["RefPasteCore"])] + platformProducts,
    targets: [
        .target(name: "RefPasteCore"),
        .testTarget(name: "RefPasteCoreTests", dependencies: ["RefPasteCore"]),
    ] + platformTargets
)
