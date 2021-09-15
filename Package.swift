// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

#if os(macOS) || os(iOS)
let package = Package(
    name: "Shapeshifter-Swift-Transports",
    platforms: [
        .macOS(.v11),
        .iOS(.v14)],
    
    products: [
        .library(name: "Protean", targets: ["Protean"]),
        .library(name: "Optimizer", targets: ["Optimizer"]),
        .library(name: "LoggerQueue", targets: ["LoggerQueue"]),
        .library(name: "ExampleTransports", targets: ["ExampleTransports"])],
    
    dependencies: [
        .package(url: "https://github.com/OperatorFoundation/Datable.git", from: "3.0.6"),
        .package(url: "https://github.com/OperatorFoundation/ProteanSwift.git", from: "1.2.3"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.4.2"),
        .package(url: "https://github.com/OperatorFoundation/SwiftQueue.git", from: "0.1.0"),
        .package(url: "https://github.com/OperatorFoundation/Transport.git", from: "2.3.6")],
    
    targets: [
        .target(
            name: "Protean",
            dependencies: [
            "Datable",
            "ProteanSwift",
            "SwiftQueue",
            "Transport",
            .product(name: "Logging", package: "swift-log")]),
        
        .target(
            name: "Optimizer",
            dependencies: [
            "SwiftQueue",
            "Transport",
            .product(name: "Logging", package: "swift-log")],
            exclude: ["Info.plist", "README.md"]),
        
        .target(
            name: "LoggerQueue",
            dependencies: [
            "Datable",
            .product(name: "Logging", package: "swift-log")]),
        
        .target(
            name: "ExampleTransports",
            dependencies: [
            "Datable",
            "Transport",
            .product(name: "Logging", package: "swift-log")]),
        
        .testTarget(
            name: "ProteanTests",
            dependencies: [
                    "Datable",
                    "Protean",
                    .product(name: "Logging", package: "swift-log")]),
        
        .testTarget(
            name: "OptimizerTests",
            dependencies: [
                "Datable",
                "Optimizer",
                "Protean",
                .product(name: "Logging", package: "swift-log"),],
            exclude: ["Info.plist"]),
        
        .testTarget(
            name: "ExampleTransportsTests",
            dependencies: [
            "Datable",
            "ExampleTransports",
            .product(name: "Logging", package: "swift-log")])],
    
    swiftLanguageVersions: [.v5]
)
#else
let package = Package(
    name: "Shapeshifter-Swift-Transports",
    products: [
        .library(name: "Optimizer", targets: ["Optimizer"]),
        .library(name: "LoggerQueue", targets: ["LoggerQueue"]),
        .library(name: "ExampleTransports", targets: ["ExampleTransports"])],
    
    dependencies: [
        .package(url: "https://github.com/OperatorFoundation/Datable.git", from: "3.0.6"),
        .package(url: "https://github.com/OperatorFoundation/NetworkLinux.git", from: "0.4.1"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "1.1.2"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.4.2"),
        .package(url: "https://github.com/OperatorFoundation/SwiftHexTools.git", from: "1.2.3"),
        .package(url: "https://github.com/OperatorFoundation/SwiftQueue.git", from: "0.1.0"),
        .package(url: "https://github.com/OperatorFoundation/TransmissionLinux.git", from: "0.3.4"),
        .package(url: "https://github.com/OperatorFoundation/Transport.git", from: "2.3.6")],
    
    targets: [
        .target(
		name: "Optimizer",
		dependencies: [
			"SwiftQueue",
			"Transport",
			.product(name: "Logging", package: "swift-log"),
			.product(name: "NetworkLinux", package: "NetworkLinux"),
			.product(name: "TransmissionLinux", package: "TransmissionLinux")],
		exclude: ["Info.plist", "README.md"]),
        
        .target(
            name: "LoggerQueue",
                dependencies: [
                "Datable",
                .product(name: "Logging", package: "swift-log"),
                .product(name: "NetworkLinux", package: "NetworkLinux"),
                .product(name: "TransmissionLinux", package: "TransmissionLinux")]),
        
        .target(
            name: "ExampleTransports",
            dependencies: [
                "Datable",
                "Transport",
                .product(name: "Logging", package: "swift-log"),
                .product(name: "NetworkLinux", package: "NetworkLinux"),
                .product(name: "TransmissionLinux", package: "TransmissionLinux")]),
        
        .testTarget(
            name: "OptimizerTests",
            dependencies: [
                "Datable",
                "Optimizer",
                .product(name: "Logging", package: "swift-log")],
            exclude: ["Info.plist"]),
        
        .testTarget(
            name: "ExampleTransportsTests",
            dependencies: [
                "Datable",
                "ExampleTransports",
                .product(name: "Logging", package: "swift-log")])
    ],
    swiftLanguageVersions: [.v5]
)
#endif
