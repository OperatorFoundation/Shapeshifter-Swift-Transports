// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Shapeshifter-Swift-Transports",
    platforms: [
       .macOS(.v10_15)
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(name: "Wisp", targets: ["Wisp"]),
        .library(name: "Protean", targets: ["Protean"]),
        .library(name: "Replicant", targets: ["Replicant"]),
        .library(name: "Optimizer", targets: ["Optimizer"]),
        .library(name: "Flow", targets: ["Flow"]),
        .library(name: "ExampleTransports", targets: ["ExampleTransports"])
        ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/OperatorFoundation/ProteanSwift.git", from: "1.1.0"),
        .package(url: "https://github.com/OperatorFoundation/ReplicantSwift.git", from: "0.4.2"),
        .package(url: "https://github.com/OperatorFoundation/Transport.git", from: "0.2.1"),
        .package(url: "https://github.com/OperatorFoundation/swift-sodium", from: "0.8.4"),
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "1.3.0"),
        .package(url: "https://github.com/OperatorFoundation/HKDF.git", from: "3.0.2"),
        .package(url: "https://github.com/OperatorFoundation/Elligator.git", from: "0.1.0"),
        .package(url: "https://github.com/OperatorFoundation/SwiftQueue.git", from: "0.0.3"),
        .package(url: "https://github.com/OperatorFoundation/Flower.git", from: "0.0.9"),
        .package(url: "https://github.com/OperatorFoundation/Datable.git", from: "1.1.1")
        ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.

        .target(name: "Wisp", dependencies: ["Sodium", "CryptoSwift", "HKDF", "Elligator", "Transport", "SwiftQueue"]),
        .target(name: "Flow", dependencies: ["Flower"]),
        .target(name: "Protean", dependencies: ["ProteanSwift", "Transport", "SwiftQueue"]),
        .target(name: "Replicant", dependencies: ["ReplicantSwift", "Transport", "SwiftQueue", "Datable"]),
        .target(name: "Optimizer", dependencies: ["Transport", "SwiftQueue"]),
        .target(name: "ExampleTransports", dependencies: ["Transport"]),
        .testTarget(name: "WispTests", dependencies: ["Wisp"]),
        .testTarget(name: "ProteanTests", dependencies: ["Protean"]),
        .testTarget(name: "ReplicantTests", dependencies: ["Replicant"]),
        .testTarget(name: "OptimizerTests", dependencies: ["Optimizer", "Wisp", "Protean"]),
        .testTarget(name: "ExampleTransportsTests", dependencies: ["ExampleTransports"])
        ],
    swiftLanguageVersions: [.v5]
)
