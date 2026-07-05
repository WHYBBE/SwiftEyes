// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwiftEyes",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "SwiftEyes",
            path: "Sources/SwiftEyes",
            exclude: ["Info.plist", "SwiftEyes.entitlements", "Assets.xcassets"]
        )
    ]
)
