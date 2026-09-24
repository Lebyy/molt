// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "molt",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "molt", targets: ["molt"])
    ],
    targets: [
        .target(name: "MoltCore"),
        .executableTarget(name: "molt", dependencies: ["MoltCore"]),
        // XCTest is not in the command line tools. This target is the check.
        .executableTarget(name: "molt-selfcheck", dependencies: ["MoltCore"])
    ]
)
