// swift-tools-version: 5.9

import CompilerPluginSupport
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
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "601.0.1-latest")
    ],
    targets: [
        .target(
            name: "SwiftAI",
            dependencies: ["SwiftAIMacros"]
        ),
        .macro(
            name: "SwiftAIMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "SwiftAITests",
            dependencies: ["SwiftAI"]
        ),
        .testTarget(
            name: "SwiftAIMacrosTests",
            dependencies: [
                "SwiftAIMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ],
        ),
    ]
)
