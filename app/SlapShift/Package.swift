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
            path: "Sources/SlapShift"
        ),
        .testTarget(
            name: "SlapShiftTests",
            dependencies: ["SlapShift"],
            path: "Tests/SlapShiftTests"
        )
    ]
)
