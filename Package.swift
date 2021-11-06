// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "swm",
    platforms: [
        .macOS(.v12),
    ],
    dependencies: [
        .package(url: "https://github.com/Kitura/BlueSocket.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "0.5.0"),
        .package(url: "https://github.com/tombell/skylight", from: "0.0.1"),
    ],
    targets: [
        .executableTarget(
            name: "swm",
            dependencies: [
                "swmlib",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SkyLight", package: "skylight"),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-F",
                    "-Xlinker", "/System/Library/PrivateFrameworks",
                    "-Xlinker", "-framework",
                    "-Xlinker", "SkyLight",
                ]),
            ]
        ),
        .target(
            name: "swmlib",
            dependencies: [
                .product(name: "Socket", package: "BlueSocket"),
            ]
        ),
        .testTarget(
            name: "SwmTests",
            dependencies: ["swm"]
        ),
        .testTarget(
            name: "SwmLibTests",
            dependencies: ["swmlib"]
        ),
    ]
)
