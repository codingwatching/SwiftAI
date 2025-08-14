// swift-tools-version: 5.10

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
    .package(url: "https://github.com/apple/swift-syntax.git", from: "510.0.0"),
    .package(url: "https://github.com/apple/swift-format.git", from: "510.0.0"),
    .package(url: "https://github.com/MacPaw/OpenAI.git", from: "0.4.6"),
  ],
  targets: [
    .target(
      name: "SwiftAI",
      dependencies: [
        "SwiftAIMacros",
        .product(name: "OpenAI", package: "OpenAI"),
      ]
    ),
    .macro(
      name: "SwiftAIMacros",
      dependencies: [
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
        .product(name: "SwiftFormat", package: "swift-format"),
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
      ]
    ),
  ]
)
