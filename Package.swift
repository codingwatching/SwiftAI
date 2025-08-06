// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SwiftAI",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .macCatalyst(.v17),
    ],
    products: [
        .library(
            name: "SwiftAI",
            targets: ["SwiftAI"]
        )
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SwiftAI"
        ),
        .testTarget(
            name: "SwiftAITests",
            dependencies: ["SwiftAI"]
        ),
    ]
)
