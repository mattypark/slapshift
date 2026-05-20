// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SlapSpike",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "SlapSpike",
            path: "Sources/SlapSpike"
        )
    ]
)
