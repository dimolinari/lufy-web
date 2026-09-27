// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LufyCore",
    // La app exige iOS 17 y macOS 14. Sin esta lista, SwiftPM elige un
    // destino anterior y APIs como TimeZone.gmt no compilan en Apple.
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "LufyCore", targets: ["LufyCore"])
    ],
    targets: [
        .target(
            name: "LufyCore",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "LufyCoreTests",
            dependencies: ["LufyCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
