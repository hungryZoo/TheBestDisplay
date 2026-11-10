// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TheBestDisplay",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "TBDCore", targets: ["TBDCore"]),
        .library(name: "TBDPlatform", targets: ["TBDPlatform"]),
        .executable(name: "TheBestDisplay", targets: ["TBDApp"]),
        .executable(name: "tbdctl", targets: ["tbdctl"]),
    ],
    targets: [
        .target(name: "TBDCore", swiftSettings: [.swiftLanguageMode(.v5)]),
        .target(name: "TBDPlatform", dependencies: ["TBDCore"], swiftSettings: [.swiftLanguageMode(.v5)]),
        .executableTarget(name: "TBDApp", dependencies: ["TBDCore", "TBDPlatform"], swiftSettings: [.swiftLanguageMode(.v5)]),
        .executableTarget(name: "tbdctl", dependencies: ["TBDCore", "TBDPlatform"], swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "TBDCoreTests", dependencies: ["TBDCore"], resources: [.copy("Fixtures")], swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(name: "TBDPlatformTests", dependencies: ["TBDPlatform"], swiftSettings: [.swiftLanguageMode(.v5)]),
    ]
)
