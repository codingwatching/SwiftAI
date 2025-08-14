// swift-tools-version: 5.10

import CompilerPluginSupport
import PackageDescription

let package = Package(
  name: "swift-ai",
  platforms: [
    .macOS(.v10_15),
    .iOS(.v13),
    .tvOS(.v13),
    .watchOS(.v6),
    .macCatalyst(.v13),
  ],
  products: [
    .library(name: "SwiftAI", targets: ["SwiftAI"])
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-syntax.git", from: "510.0.0"),
    .package(url: "https://github.com/apple/swift-format.git", from: "510.0.0"),
    .package(url: "https://github.com/MacPaw/OpenAI.git", from: "0.4.6")
  ],
  targets: [
    .target(
      name: "SwiftAI",
      dependencies: [
        "SwiftAIMacros",
        .product(name: "OpenAI", package: "OpenAI")
      ]
    ),
    .macro(
      name: "SwiftAIMacros",
      dependencies: [
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
        .product(name: "SwiftFormat", package: "swift-format")
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
        .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax")
      ]
    ),
  ]
)
