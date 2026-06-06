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
        // Metal-enabled whisper.cpp, built via Scripts/build-xcframework.sh.
        // For development this points at the locally built framework; releases switch to a
        // .binaryTarget(url:checksum:) attached to a GitHub Release (see Scripts/build-xcframework.sh).
        .binaryTarget(name: "whisper", path: "whisper.xcframework"),
        .target(name: "WhisperMetalKit", dependencies: ["whisper"]),
        .testTarget(
            name: "WhisperMetalKitTests",
            dependencies: ["WhisperMetalKit"],
            resources: [.copy("Resources/jfk.wav")]
        ),
    ]
)
