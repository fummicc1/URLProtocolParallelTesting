// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TodoApp",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
        .watchOS(.v8),
        .tvOS(.v15)
    ],
    products: [
        .library(
            name: "TodoApp",
            targets: ["TodoApp"]
        ),
    ],
    dependencies: [
        // Local dependency to URLProtocolParallelTesting
        .package(path: "../..")
    ],
    targets: [
        .target(
            name: "TodoApp",
            dependencies: [],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "TodoAppTests",
            dependencies: [
                "TodoApp",
                .product(name: "URLProtocolParallelTesting", package: "URLProtocolParallelTesting")
            ],
            swiftSettings: [
                .define("DEBUG"),
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
    ]
)
