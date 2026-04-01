// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "SFTPSlim",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "SFTPSlim",
            targets: ["SFTPSlim"]
        )
    ],
    dependencies: [
        // Recommended real SSH/SFTP library for production integration.
        // .package(url: "https://github.com/orlandos-nl/Citadel.git", from: "0.17.0")
    ],
    targets: [
        .executableTarget(
            name: "SFTPSlim",
            dependencies: [],
            path: "Sources",
            resources: [
                .process("../Resources")
            ]
        )
    ]
)
