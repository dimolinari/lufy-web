// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LufyCore",
    defaultLocalization: "es",
    products: [
        .library(name: "LufyCore", targets: ["LufyCore"])
    ],
    targets: [
        .target(
            name: "LufyCore",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "LufyCoreTests",
            dependencies: ["LufyCore"]
        )
    ]
)
