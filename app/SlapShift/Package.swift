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
    dependencies: [
        // Sparkle — auto-update framework for non-Mac-App-Store apps.
        // Used by Bartender, Raycast, CleanShot, Transmit, etc. Reads an
        // appcast.xml from slapshift.app, downloads the new DMG, verifies
        // EdDSA signature, swaps the app, relaunches. License key lives in
        // Keychain so it survives the swap.
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .executableTarget(
            name: "SlapShift",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
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
