// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Shapeshifter-Swift-Transports",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "Meek",
            targets: ["Meek"]),
        .library(
            name: "Wisp",
            targets: ["Wisp"]),
        ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
         .package(url: "https://github.com/IBM-Swift/CommonCrypto.git", from: "0.1.5"),
         .package(url: "https://github.com/OperatorFoundation/swift-sodium.git", from: "0.5.3"),
         .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "0.7.2"),
         .package(url: "https://github.com/Bouke/HKDF.git", from: "3.0.1"),
         .package(url: "https://github.com/OperatorFoundation/Elligator.git", from: "0.1.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        
        .target(
            name: "Meek",
            dependencies: ["CryptoSwift", "ShapeshifterTesting"]),
        .testTarget(
            name: "MeekTests",
            dependencies: ["Meek"]),
        .target(
            name: "Wisp",
            dependencies: ["CommonCrypto", "Sodium", "CryptoSwift", "HKDF", "Elligator", "ShapeshifterTesting"]),
        .testTarget(
            name: "WispTests",
            dependencies: ["Wisp"]),
        .target(
            name: "ShapeshifterTesting",
            dependencies: []),
        ]
)
