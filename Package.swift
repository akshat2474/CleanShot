// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CleanShot",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "CleanShot",
            targets: ["CleanShot"]
        )
    ],
    targets: [
        .executableTarget(
            name: "CleanShot",
            path: "Sources/CleanShot",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "CleanShotTests",
            dependencies: ["CleanShot"],
            path: "Tests/CleanShotTests"
        )
    ]
)
