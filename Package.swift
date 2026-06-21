// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "autopilot",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AutopilotCore", targets: ["AutopilotCore"]),
        .library(name: "AutopilotMacOS", targets: ["AutopilotMacOS"]),
        .executable(name: "autopilot", targets: ["autopilot"]),
        .executable(name: "AutopilotMCP", targets: ["AutopilotMCP"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .target(name: "AutopilotCore",
                swiftSettings: [.swiftLanguageMode(.v5)]),
        .target(name: "AutopilotMacOS",
                dependencies: ["AutopilotCore"],
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
            dependencies: ["AutopilotCore", "AutopilotMacOS"],
            swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(
            name: "AutopilotMCPKitTests",
            dependencies: ["AutopilotMCPKit"],
            swiftSettings: [.swiftLanguageMode(.v5)]),
    ]
)
