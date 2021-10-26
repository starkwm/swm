// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "swm",
    platforms: [
        .macOS(.v11),
    ],
    dependencies: [
        .package(url: "https://github.com/Kitura/BlueSocket.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "0.5.0"),
    ],
    targets: [
        .executableTarget(
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
