// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "swm",
    platforms: [
        .macOS(.v10_15),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.1"),
    ],
    targets: [
        .target(
            name: "swm",
            dependencies: [
              "swmlib",
              .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]),
        .target(
            name: "swmlib",
            dependencies: []
        ),
        .testTarget(
            name: "SwmTests",
            dependencies: ["swm"]),
        .testTarget(
            name: "SwmLibTests",
            dependencies: ["swmlib"]),
    ]
)
