// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AprendeCore",
    defaultLocalization: "es",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .visionOS(.v2),
    ],
    products: [
        .library(name: "AprendeCore", targets: ["AprendeCore"]),
    ],
    targets: [
        .target(
            name: "AprendeCore",
            resources: [
                .process("Resources/brand.json"),
                .copy("Resources/Content"),
                .copy("Resources/Audio"),
                .copy("Resources/Data"),
                .copy("Resources/Media"),
                .copy("Resources/Feed"),
                .copy("Resources/Spatial"),
            ]
        ),
        .testTarget(
            name: "AprendeCoreTests",
            dependencies: ["AprendeCore"]
        ),
    ]
)
