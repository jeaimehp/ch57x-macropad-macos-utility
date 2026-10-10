// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "MicroPadStudio",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "MicroPadCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "MicroPadStudio",
            dependencies: ["MicroPadCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "MicroPadCoreTests",
            dependencies: ["MicroPadCore"]
        ),
    ]
)
