// swift-tools-version: 6.4

import PackageDescription

let releaseDebugSettings: [SwiftSetting] = [
  .unsafeFlags(["-g"], .when(configuration: .release))
]

let privateFrameworkLinkerSettings: [LinkerSetting] = [
  .unsafeFlags([
    "-Xlinker", "-F",
    "-Xlinker", "/System/Library/PrivateFrameworks",
    "-Xlinker", "-framework",
    "-Xlinker", "SkyLight",
  ])
]

let package = Package(
  name: "swm",
  platforms: [
    .macOS(.v26)
  ],
  products: [
    .executable(name: "swm", targets: ["Swm"])
  ],
  dependencies: [
    .package(
      url: "https://github.com/starkwm/stark-skylight",
      revision: "23a5df35d8a6357b1b4f63639005d00a82fb679c"
    ),
    .package(
      url: "https://github.com/starkwm/stark-ipc",
      exact: "0.0.3"
    ),
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.7.1"),
  ],
  targets: [
    .executableTarget(
      name: "Swm",
      dependencies: [
        "SwmLib",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ],
      exclude: ["Version.swift.tmpl"],
      swiftSettings: releaseDebugSettings
    ),
    .target(
      name: "SwmLib",
      dependencies: [
        .product(name: "StarkIPC", package: "stark-ipc"),
        .product(name: "StarkSkyLight", package: "stark-skylight"),
      ],
      swiftSettings: releaseDebugSettings,
      linkerSettings: privateFrameworkLinkerSettings
    ),
    .testTarget(
      name: "SwmLibTests",
      dependencies: ["SwmLib"]
    ),
    .testTarget(
      name: "SwmTests",
      dependencies: ["Swm"]
    ),
  ],
  swiftLanguageModes: [.v6]
)
