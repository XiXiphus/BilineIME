// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BilineModules",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "BilineCore", targets: ["BilineCore"]),
        .library(name: "BilineHost", targets: ["BilineHost"]),
        .library(name: "BilinePreview", targets: ["BilinePreview"]),
        .library(name: "BilineRime", targets: ["BilineRime"]),
        .library(name: "BilineSettings", targets: ["BilineSettings"]),
        .library(name: "BilineOperations", targets: ["BilineOperations"]),
        .library(name: "BilineSession", targets: ["BilineSession"]),
        .library(name: "BilineMocks", targets: ["BilineMocks"]),
        .library(name: "BilineTestSupport", targets: ["BilineTestSupport"]),
        .executable(name: "bilinectl", targets: ["bilinectl"]),
    ],
    targets: [
        .target(
            name: "BilineCore"
        ),
        .target(
            name: "BilineHost",
            dependencies: ["BilineCore"]
        ),
        .target(
            name: "BilinePreview",
            dependencies: ["BilineCore"]
        ),
        .target(
            name: "CBilineRime",
            path: "Sources/CBilineRime",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("../../Vendor/librime/src"),
                .headerSearchPath("../../Vendor/librime/include"),
            ]
        ),
        .target(
            name: "BilineRime",
            dependencies: ["BilineCore", "CBilineRime"],
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "BilineSession",
            dependencies: ["BilineCore", "BilinePreview"]
        ),
        .target(
            name: "BilineSettings",
            dependencies: ["BilineCore", "BilinePreview"]
        ),
        .target(
            name: "BilineOperations",
            dependencies: ["BilineSettings"]
        ),
        .executableTarget(
            name: "bilinectl",
            dependencies: ["BilineOperations"]
        ),
        .target(
            name: "BilineMocks",
            dependencies: ["BilineCore", "BilinePreview"],
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "BilineTestSupport",
            dependencies: ["BilineCore", "BilinePreview", "BilineSession", "BilineMocks"]
        ),
        .testTarget(
            name: "BilineCoreTests",
            dependencies: ["BilineCore", "BilineMocks", "BilineTestSupport"]
        ),
        .testTarget(
            name: "BilineRimeTests",
            dependencies: ["BilineRime", "BilineCore"]
        ),
        .testTarget(
            name: "BilineHostTests",
            dependencies: ["BilineHost", "BilineCore"]
        ),
        .testTarget(
            name: "BilinePreviewTests",
            dependencies: ["BilinePreview", "BilineMocks", "BilineTestSupport"]
        ),
        .testTarget(
            name: "BilineSessionTests",
            dependencies: ["BilineSession", "BilineMocks", "BilineTestSupport"]
        ),
        .testTarget(
            name: "BilineSettingsTests",
            dependencies: ["BilineSettings", "BilineCore"]
        ),
        .testTarget(
            name: "BilineOperationsTests",
            dependencies: ["BilineOperations", "BilineSettings"]
        ),
    ]
)
