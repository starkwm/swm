// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "swm",
    platforms: [
        .macOS(.v13),
    ],
    dependencies: [
        .package(url: "https://github.com/Kitura/BlueSocket.git", from: "2.0.2"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.2"),
        .package(url: "https://github.com/starkwm/skylight", from: "0.0.1"),
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
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Socket", package: "BlueSocket"),
            ]
        ),
    ]
)
