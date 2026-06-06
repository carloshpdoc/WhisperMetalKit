/// WhisperMetalKit — on-device speech-to-text powered by [whisper.cpp](https://github.com/ggml-org/whisper.cpp)
/// with **Metal GPU acceleration**, distributed via the Swift Package Manager.
///
/// Why this exists: the existing whisper.cpp SPM wrappers are unmaintained and ship **without
/// Metal** (CPU only), and upstream dropped SPM support in favour of an xcframework built through
/// CMake. WhisperMetalKit closes that gap by wrapping the official, Metal-enabled
/// `whisper.xcframework` as a binary target behind a small, modern Swift API.
///
public enum WhisperMetalKit {
    /// Package version.
    public static let version = "0.1.0"
}
