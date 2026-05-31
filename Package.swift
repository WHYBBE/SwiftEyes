// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftEyes",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "SwiftEyes",
            path: "Sources/SwiftEyes"
        )
    ]
)
