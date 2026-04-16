// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BilineModules",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "BilineCore", targets: ["BilineCore"]),
        .library(name: "BilinePreview", targets: ["BilinePreview"]),
        .library(name: "BilineMocks", targets: ["BilineMocks"]),
        .library(name: "BilineTestSupport", targets: ["BilineTestSupport"]),
    ],
    targets: [
        .target(
            name: "BilineCore"
        ),
        .target(
            name: "BilinePreview",
            dependencies: ["BilineCore"]
        ),
        .target(
            name: "BilineMocks",
            dependencies: ["BilineCore", "BilinePreview"],
            resources: [
                .process("Resources"),
            ]
        ),
        .target(
            name: "BilineTestSupport",
            dependencies: ["BilineCore", "BilinePreview", "BilineMocks"]
        ),
        .testTarget(
            name: "BilineCoreTests",
            dependencies: ["BilineCore", "BilineMocks", "BilineTestSupport"]
        ),
        .testTarget(
            name: "BilinePreviewTests",
            dependencies: ["BilinePreview", "BilineMocks", "BilineTestSupport"]
        ),
    ]
)
