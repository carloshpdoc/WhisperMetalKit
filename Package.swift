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
        // Metal-enabled whisper.cpp, built by Scripts/build-xcframework.sh and attached to the
        // matching GitHub Release. For local development against a freshly built framework, swap
        // this for `.binaryTarget(name: "whisper", path: "whisper.xcframework")`.
        .binaryTarget(
            name: "whisper",
            url: "https://github.com/carloshpdoc/WhisperMetalKit/releases/download/v0.1.0/whisper.xcframework.zip",
            checksum: "f31972d9cb88d4b5ee57174934e8a6dc2c243b0b84a2254b06a6b9e3612e7197"
        ),
        .target(name: "WhisperMetalKit", dependencies: ["whisper"]),
        .testTarget(
            name: "WhisperMetalKitTests",
            dependencies: ["WhisperMetalKit"],
            resources: [.copy("Resources/jfk.wav")]
        ),
    ]
)
