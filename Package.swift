// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "swm",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(name: "swm", targets: ["Swm"])
  ],
  dependencies: [
    .package(url: "https://github.com/Kitura/BlueSocket.git", from: "2.0.2"),
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.2"),
  ],
  targets: [
    .executableTarget(
      name: "Swm",
      dependencies: [
        "SwmLib",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ],
      exclude: ["version.swift.tmpl"],
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
      name: "SwmLib",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "Socket", package: "BlueSocket"),
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
    .testTarget(
      name: "SwmLibTests",
      dependencies: ["SwmLib"]
    ),
  ],
  swiftLanguageModes: [.v6]
)
