// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "URLProtocolParallelTesting",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
        .watchOS(.v8),
        .tvOS(.v15)
    ],
    products: [
        .library(
            name: "URLProtocolParallelTesting",
            targets: ["URLProtocolParallelTesting"]
        ),
    ],
    targets: [
        .target(
            name: "URLProtocolParallelTesting",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "URLProtocolParallelTestingTests",
            dependencies: ["URLProtocolParallelTesting"]
        ),
    ]
)
