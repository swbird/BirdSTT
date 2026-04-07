// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BirdSTT",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "BirdSTT",
            path: "Sources/BirdSTT",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreGraphics"),
                .linkedLibrary("z"),
            ]
        ),
        .testTarget(
            name: "BirdSTTTests",
            dependencies: ["BirdSTT"],
            path: "Tests/BirdSTTTests"
        ),
    ]
)
