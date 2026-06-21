// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "autopilot",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AutopilotMacOS", targets: ["AutopilotMacOS"]),
        .executable(name: "autopilot", targets: ["autopilot"]),
        .executable(name: "AutopilotMCP", targets: ["AutopilotMCP"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        // Pinned by revision until the gated v2.0.0 release (Task 15 switches to from: "2.0.0").
        .package(url: "https://github.com/jschwefel-CBB/autopilot-core", revision: "e1863da742c887048d43584f27014e2491dbf483"),
    ],
    targets: [
        .target(
            name: "AutopilotMacOS",
            dependencies: [.product(name: "AutopilotCore", package: "autopilot-core")],
            swiftSettings: [.swiftLanguageMode(.v5)]),
        .executableTarget(
            name: "autopilot",
            dependencies: [
                "AutopilotMacOS",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]),
        .target(name: "AutopilotMCPKit",
                dependencies: ["AutopilotMacOS"],
                swiftSettings: [.swiftLanguageMode(.v5)]),
        .executableTarget(
            name: "AutopilotMCP",
            dependencies: ["AutopilotMCPKit"],
            swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(
            name: "AutopilotCoreTests",
            dependencies: ["AutopilotMacOS", .product(name: "AutopilotCore", package: "autopilot-core")],
            swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(
            name: "AutopilotMCPKitTests",
            dependencies: ["AutopilotMCPKit"],
            swiftSettings: [.swiftLanguageMode(.v5)]),
    ]
)
