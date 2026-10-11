// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BadiDateSwift",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .watchOS(.v6),
        .tvOS(.v13),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "BadiDateSwift", targets: ["BadiDateSwift"]),
    ],
    targets: [
        .target(name: "BadiDateSwift"),
        .testTarget(
            name: "BadiDateSwiftTests",
            dependencies: ["BadiDateSwift"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
