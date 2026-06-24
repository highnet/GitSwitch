// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GitSwitch",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "GitSwitch",
            path: "Sources/GitSwitch"
        )
    ]
)
