// swift-tools-version: 6.0
import PackageDescription

#if os(macOS)
    let platformProducts: [Product] = [.library(name: "PinkPlatform", targets: ["PinkPlatform"])]
    let platformTargets: [Target] = [
        .target(name: "PinkPlatform", dependencies: ["PinkCore"], exclude: ["AGENTS.md"]),
        .testTarget(name: "PinkPlatformTests", dependencies: ["PinkPlatform"]),
    ]
#else
    let platformProducts: [Product] = []
    let platformTargets: [Target] = []
#endif

let package = Package(
    name: "Pink",
    platforms: [.macOS(.v15)],
    products: [.library(name: "PinkCore", targets: ["PinkCore"])] + platformProducts,
    targets: [
        .target(name: "PinkCore"),
        .testTarget(name: "PinkCoreTests", dependencies: ["PinkCore"]),
    ] + platformTargets
)
