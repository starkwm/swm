// swift-tools-version:5.10

import PackageDescription

let package = Package(
  name: "swm",
  platforms: [
    .macOS(.v14)
  ],
  dependencies: [
    .package(url: "https://github.com/Kitura/BlueSocket.git", from: "2.0.2"),
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.2"),
  ],
  targets: [
    .executableTarget(
      name: "swm",
      dependencies: [
        "swmlib",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ],
      linkerSettings: [
        .unsafeFlags([
          "-Xlinker", "-F",
          "-Xlinker", "/System/Library/PrivateFrameworks",
          "-Xlinker", "-framework",
          "-Xlinker", "SkyLight",
        ])
      ]
    ),
    .target(
      name: "swmlib",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "Socket", package: "BlueSocket"),
      ]
    ),
    .testTarget(
      name: "swmlibTests",
      dependencies: ["swmlib"]
    ),
  ]
)
