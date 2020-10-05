// swift-tools-version:5.3
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
        .library(name: "Shadow", targets: ["Shadow"]),
        .library(name: "Protean", targets: ["Protean"]),
        .library(name: "Replicant", targets: ["Replicant"]),
        .library(name: "Optimizer", targets: ["Optimizer"]),
        .library(name: "Flow", targets: ["Flow"]),
        .library(name: "LoggerQueue", targets: ["LoggerQueue"]),
        .library(name: "ExampleTransports", targets: ["ExampleTransports"])
        ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/apple/swift-log.git", from: "1.4.0"),
        .package(url: "https://github.com/OperatorFoundation/ProteanSwift.git", from: "1.2.0"),
        .package(url: "https://github.com/OperatorFoundation/ReplicantSwift.git", from: "0.6.0"),
        .package(url: "https://github.com/OperatorFoundation/Transport.git", from: "2.2.0"),
        .package(name: "Sodium", url: "https://github.com/OperatorFoundation/swift-sodium", from: "0.8.4"),
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "1.3.0"),
        .package(url: "https://github.com/OperatorFoundation/HKDF.git", from: "3.0.2"),
        .package(url: "https://github.com/OperatorFoundation/Elligator.git", from: "0.1.0"),
        .package(url: "https://github.com/OperatorFoundation/SwiftQueue.git", from: "0.0.3"),
        .package(url: "https://github.com/OperatorFoundation/Flower.git", from: "0.1.0"),
        .package(url: "https://github.com/OperatorFoundation/Datable.git", from: "3.0.2"),
        .package(url: "https://github.com/OperatorFoundation/Chord.git", from: "0.0.5"),
        .package(url: "https://github.com/OperatorFoundation/SwiftHexTools.git", from: "1.2.2"),
        .package(url: "https://github.com/OperatorFoundation/NetworkLinux.git", from: "0.1.0"),
        ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.

        .target(name: "Wisp", dependencies: ["Transport", "Sodium", "CryptoSwift", "HKDF", "Elligator", "SwiftQueue", .product(name: "Logging", package: "swift-log"), "Datable"]),
        .target(name: "Shadow", dependencies: ["Transport", "Datable", "Chord", .product(name: "Logging", package: "swift-log")]),
        .target(name: "Flow", dependencies: ["Flower", .product(name: "Logging", package: "swift-log"), "Datable"]),
        .target(name: "Protean", dependencies: ["Transport", "ProteanSwift", "SwiftQueue", .product(name: "Logging", package: "swift-log"), "Datable"]),
        .target(name: "Replicant", dependencies: ["Transport", "ReplicantSwift", "SwiftQueue", "Datable", "Flower", .product(name: "Logging", package: "swift-log")]),
        .target(name: "Optimizer", dependencies: [
		"Transport", "SwiftQueue",
		.product(name: "Logging", package: "swift-log"),
		.product(name: "NetworkLinux", package: "NetworkLinux", condition: .when(platforms: [.linux])),
	]),
        .target(name: "LoggerQueue", dependencies: [.product(name: "Logging", package: "swift-log"), "Datable"]),
        .target(name: "ExampleTransports", dependencies: ["Transport", .product(name: "Logging", package: "swift-log"), "Datable"]),
        .testTarget(name: "WispTests", dependencies: ["Wisp", .product(name: "Logging", package: "swift-log"), "Datable"]),
        .testTarget(name: "ShadowTests", dependencies: ["Shadow", "SwiftHexTools", .product(name: "Logging", package: "swift-log"), "Datable"]),
        .testTarget(name: "ProteanTests", dependencies: ["Protean", .product(name: "Logging", package: "swift-log"), "Datable"]),
        .testTarget(name: "ReplicantTests", dependencies: ["Replicant", .product(name: "Logging", package: "swift-log"), "Datable"]),
        .testTarget(name: "OptimizerTests", dependencies: ["Optimizer", "Wisp", "Protean", .product(name: "Logging", package: "swift-log"), "Datable"]),
        .testTarget(name: "ExampleTransportsTests", dependencies: ["ExampleTransports", .product(name: "Logging", package: "swift-log"), "Datable"])
        ],
    swiftLanguageVersions: [.v5]
)
