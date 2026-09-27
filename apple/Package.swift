// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LufyCore",
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
