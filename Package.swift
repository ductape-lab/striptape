// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "striptape",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "striptape", targets: ["striptape"]),
        .executable(name: "test_runner", targets: ["test_runner"]),
        .library(name: "StriptapeCore", targets: ["StriptapeCore"])
    ],
    targets: [
        .target(
            name: "StriptapeCore",
            path: "Sources/StriptapeCore"
        ),
        .executableTarget(
            name: "striptape",
            dependencies: ["StriptapeCore"],
            path: "Sources/striptape"
        ),
        .executableTarget(
            name: "test_runner",
            dependencies: ["StriptapeCore"],
            path: "Sources/test_runner"
        )
    ]
)
