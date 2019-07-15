// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Shapeshifter-Swift-Transports",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(name: "Wisp", targets: ["Wisp"]),
        .library(name: "Protean", targets: ["Protean"]),
        .library(name: "Replicant", targets: ["Replicant"]),
        .library(name: "Flow", targets: ["Flow"]),
        .library(name: "ExampleTransports", targets: ["ExampleTransports"])
        ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/OperatorFoundation/ProteanSwift.git", from: "1.1.0"),
        .package(url: "https://github.com/OperatorFoundation/ReplicantSwift.git", from: "0.3.0"),
        .package(url: "https://github.com/OperatorFoundation/Transport.git", from: "0.0.22"),
        //.package(url: "https://github.com/OperatorFoundation/WireGuard.git", from: "0.0.5"),
        .package(url: "https://github.com/OperatorFoundation/swift-sodium", from: "0.8.2"),
        //.package(url: "https://github.com/jedisct1/swift-sodium", from: "0.8.0"),
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "1.0.0"),
        .package(url: "https://github.com/OperatorFoundation/HKDF.git", from: "3.0.2"),
        .package(url: "https://github.com/OperatorFoundation/Elligator.git", from: "0.1.0"),
        .package(url: "https://github.com/OperatorFoundation/SwiftQueue.git", from: "0.0.3"),
        .package(url: "https://github.com/OperatorFoundation/Flower.git", from: "0.0.4")
        ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.

        .target(name: "Wisp", dependencies: ["Sodium", "CryptoSwift", "HKDF", "Elligator", "Transport", "SwiftQueue"]),
        .target(name: "Flow", dependencies: ["Flower"]),
        .target(name: "Protean", dependencies: ["ProteanSwift", "Transport", "SwiftQueue"]),
        .target(name: "Replicant", dependencies: ["ReplicantSwift", "Transport", "SwiftQueue"]),
        .target(name: "ExampleTransports", dependencies: ["Transport"]),
        .testTarget(name: "WispTests", dependencies: ["Wisp"]),
        .testTarget(name: "ProteanTests", dependencies: ["Protean"]),
        .testTarget(name: "ReplicantTests", dependencies: ["Replicant"]),
        .testTarget(name: "ExampleTransportsTests", dependencies: ["ExampleTransports"])
        ]
)
