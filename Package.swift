// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WMZRenderer",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "WMZRenderer",
            path: "Sources"
        )
    ]
)
