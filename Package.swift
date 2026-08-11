// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "open-profile-manager",
  defaultLocalization: "en-US",
  platforms: [
    .macOS(.v15)
  ],
  products: [
    .executable(name: "opm", targets: ["opm"]),
    .executable(name: "OpenProfileManager", targets: ["OpenProfileManager"]),
  ],
  dependencies: [
    .package(
      url: "https://github.com/apple/swift-argument-parser.git",
      exact: "1.8.2"
    )
  ],
  targets: [
    .target(name: "ProfileCore"),
    .executableTarget(
      name: "opm",
      dependencies: [
        "ProfileCore",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ]
    ),
    .executableTarget(
      name: "OpenProfileManager",
      dependencies: ["ProfileCore"],
      resources: [.process("Resources")],
      swiftSettings: [
        .defaultIsolation(MainActor.self),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
      ]
    ),
    .testTarget(
      name: "ProfileCoreTests",
      dependencies: ["ProfileCore"]
    ),
    .testTarget(
      name: "OpenProfileManagerTests",
      dependencies: ["OpenProfileManager", "ProfileCore"]
    ),
  ],
  swiftLanguageModes: [.v6]
)
