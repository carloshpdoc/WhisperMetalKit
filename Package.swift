// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WhisperMetalKit",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(name: "WhisperMetalKit", targets: ["WhisperMetalKit"]),
    ],
    targets: [
        // The Swift API layer. The Metal-enabled `whisper.xcframework` binary target is added
        // here once it is built/hosted (see Scripts/build-xcframework.sh).
        .target(name: "WhisperMetalKit"),
        .testTarget(name: "WhisperMetalKitTests", dependencies: ["WhisperMetalKit"]),
    ]
)
