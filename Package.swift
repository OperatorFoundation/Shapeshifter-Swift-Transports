// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

#if os(macOS) || os(iOS)
let package = Package(
    name: "Shapeshifter-Swift-Transports",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13)
    ],
    products: [
        .library(name: "Wisp", targets: ["Wisp"]),
        .library(name: "Shadow", targets: ["Shadow"]),
        .library(name: "Protean", targets: ["Protean"]),
        .library(name: "Optimizer", targets: ["Optimizer"]),
        .library(name: "Replicant", targets: ["Replicant"]),
        .library(name: "LoggerQueue", targets: ["LoggerQueue"]),
        .library(name: "ExampleTransports", targets: ["ExampleTransports"])
    ],
    dependencies: [
        .package(url: "https://github.com/OperatorFoundation/Chord.git", from: "0.0.5"),
        .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "1.3.0"),
        .package(url: "https://github.com/OperatorFoundation/Datable.git", from: "3.0.2"),
        .package(url: "https://github.com/OperatorFoundation/Elligator.git", from: "0.1.0"),
        .package(url: "https://github.com/OperatorFoundation/HKDF.git", from: "3.0.2"),
        .package(url: "https://github.com/OperatorFoundation/NetworkLinux.git", from: "0.2.4"),
        .package(url: "https://github.com/OperatorFoundation/ProteanSwift.git", from: "1.2.0"),
        .package(url: "https://github.com/OperatorFoundation/ReplicantSwift.git", from: "0.8.3"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.4.0"),
        .package(name: "Sodium", url: "https://github.com/OperatorFoundation/swift-sodium.git", from: "0.8.4"),
        .package(url: "https://github.com/OperatorFoundation/SwiftHexTools.git", from: "1.2.2"),
        .package(url: "https://github.com/OperatorFoundation/SwiftQueue.git", from: "0.0.3"),
        .package(url: "https://github.com/OperatorFoundation/Transmission.git", from: "0.1.12"),
        .package(url: "https://github.com/OperatorFoundation/Transport.git", from: "2.3.3")
    ],
    targets: [
        .target(name: "Wisp", dependencies: [
            "CryptoSwift",
            "Datable",
            "Elligator",
            "HKDF",
            "Sodium",
            "SwiftQueue",
            "Transmission",
            "Transport",
            .product(name: "Logging", package: "swift-log"),
            .product(name: "NetworkLinux", package: "NetworkLinux", condition: .when(platforms: [.linux])),
        ]),
        
        .target(name: "Shadow", dependencies: [
            "Chord",
            "Datable",
            "Transmission",
            "Transport",
            .product(name: "Logging", package: "swift-log"),
            .product(name: "NetworkLinux", package: "NetworkLinux", condition: .when(platforms: [.linux])),
        ]),
        
        .target(name: "Protean", dependencies: [
            "Datable",
            "ProteanSwift",
            "SwiftQueue",
            "Transport",
            .product(name: "Logging", package: "swift-log"),
            .product(name: "NetworkLinux", package: "NetworkLinux", condition: .when(platforms: [.linux])),
        ]),
        
        .target(name: "Optimizer", dependencies: [
            "SwiftQueue",
            "Transport",
            .product(name: "Logging", package: "swift-log"),
            .product(name: "NetworkLinux", package: "NetworkLinux", condition: .when(platforms: [.linux])),
        ]),
        
        .target(name:"Replicant", dependencies:[
            "ReplicantSwift",
            "Transmission"
        ]),
        
        .target(name: "LoggerQueue", dependencies: [
            "Datable",
            .product(name: "Logging", package: "swift-log"),
            .product(name: "NetworkLinux", package: "NetworkLinux", condition: .when(platforms: [.linux])),
        ]),
        
        .target(name: "ExampleTransports", dependencies: [
            "Datable",
            "Transport",
            .product(name: "Logging", package: "swift-log"),
            .product(name: "NetworkLinux", package: "NetworkLinux", condition: .when(platforms: [.linux])),
        ]),

        .testTarget(name: "WispTests",
                    dependencies: [
                        "Datable",
                        "Wisp",
                        .product(name: "Logging", package: "swift-log")],
                    resources: [.process("Resources")]
        ),
        
        .testTarget(name: "ShadowTests", dependencies: [
                        "Datable",
                        "Shadow",
                        "SwiftHexTools",
                        .product(name: "Logging", package: "swift-log")]),
        
        .testTarget(name: "ProteanTests", dependencies: [
                        "Datable",
                        "Protean",
                        .product(name: "Logging", package: "swift-log")]),
        
        .testTarget(name: "OptimizerTests", dependencies: [
                        "Optimizer",
                        "Protean",
                        "Replicant",
                        "Wisp",
                        .product(name: "Logging", package: "swift-log"), "Datable"]),
        
        .testTarget(name: "ExampleTransportsTests", dependencies: [
                        "Datable",
                        "ExampleTransports",
                        .product(name: "Logging", package: "swift-log")])
    ],
    swiftLanguageVersions: [.v5]
)
#else
let package = Package(
    name: "Shapeshifter-Swift-Transports",
    products: [
        .library(name: "Shadow", targets: ["Shadow"]),
        .library(name: "Optimizer", targets: ["Optimizer"]),
        .library(name: "Replicant", targets: ["Replicant"]),
        .library(name: "LoggerQueue", targets: ["LoggerQueue"]),
        .library(name: "ExampleTransports", targets: ["ExampleTransports"])
    ],
    dependencies: [
        .package(url: "https://github.com/OperatorFoundation/Chord.git", from: "0.0.5"),
        .package(url: "https://github.com/OperatorFoundation/Datable.git", from: "3.0.2"),
        .package(url: "https://github.com/OperatorFoundation/NetworkLinux.git", from: "0.2.4"),
        .package(url: "https://github.com/OperatorFoundation/ReplicantSwift.git", from: "0.8.3"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "1.1.2"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.4.0"),
        .package(url: "https://github.com/OperatorFoundation/SwiftHexTools.git", from: "1.2.2"),
        .package(url: "https://github.com/OperatorFoundation/SwiftQueue.git", from: "0.0.3"),
        .package(url: "https://github.com/OperatorFoundation/Transmission.git", from: "0.1.12"),
        .package(url: "https://github.com/OperatorFoundation/Transport.git", from: "2.3.3"),
    ],
    targets: [
        .target(name: "Shadow", dependencies: [
            "Chord",
            "Datable",
            "Transport",
            .product(name: "Crypto", package: "swift-crypto"),
            .product(name: "Logging", package: "swift-log"),
            .product(name: "NetworkLinux", package: "NetworkLinux"),
            .product(name: "TransmissionLinux", package: "Transmission")
        ]),
        
        .target(name: "Optimizer", dependencies: [
            "SwiftQueue",
            "Transport",
            .product(name: "Logging", package: "swift-log"),
            .product(name: "NetworkLinux", package: "NetworkLinux"),
        ]),
        
        .target(name:"Replicant", dependencies:[
            "ReplicantSwift",
            .product(name: "Crypto", package: "swift-crypto"),
            .product(name: "TransmissionLinux", package: "Transmission"),
        ]),
        
        .target(name: "LoggerQueue", dependencies: [
            "Datable",
            .product(name: "Logging", package: "swift-log"),
            .product(name: "NetworkLinux", package: "NetworkLinux", condition: .when(platforms: [.linux])),
        ]),
        
        .target(name: "ExampleTransports", dependencies: [
            "Datable",
            "Transport",
            .product(name: "Logging", package: "swift-log"),
            .product(name: "NetworkLinux", package: "NetworkLinux", condition: .when(platforms: [.linux])),
        ]),
        
        .testTarget(name: "ShadowTests", dependencies: [
                        "Datable",
                        "Shadow",
                        "SwiftHexTools",
                        .product(name: "Logging", package: "swift-log")]),
        
        .testTarget(name: "OptimizerTests", dependencies: [
                        "Optimizer",
                        "Replicant",
                        .product(name: "Logging", package: "swift-log"), "Datable"]),
        
        .testTarget(name: "ExampleTransportsTests", dependencies: [
                        "Datable",
                        "ExampleTransports",
                        .product(name: "Logging", package: "swift-log")])
    ],
    swiftLanguageVersions: [.v5]
)
#endif
