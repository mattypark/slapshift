// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SlapShift",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "SlapShift", targets: ["SlapShift"])
    ],
    targets: [
        .executableTarget(
            name: "SlapShift",
            path: "Sources/SlapShift",
            resources: [
                // Brand logos for the onboarding source picker. Rasterized
                // 112×112 PNGs from simpleicons (CC0). Bundled so onboarding
                // works offline.
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "SlapShiftTests",
            dependencies: ["SlapShift"],
            path: "Tests/SlapShiftTests"
        )
    ]
)
