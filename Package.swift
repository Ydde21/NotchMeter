// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "NotchMeter",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "NotchMeter",
            path: "Sources/NotchMeter"
        )
    ]
)
