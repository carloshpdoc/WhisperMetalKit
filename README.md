# WhisperMetalKit

On-device speech-to-text for Apple platforms, powered by [whisper.cpp](https://github.com/ggml-org/whisper.cpp) with **Metal GPU acceleration** — distributed via the **Swift Package Manager**.

```swift
.package(url: "https://github.com/carloshpdoc/WhisperMetalKit.git", from: "0.1.0")
```

## Why

If you want OpenAI's Whisper running locally on iPhone/Mac via SPM today, your options are rough:

| Option | Runtime | Metal GPU | Maintained | Notes |
|--------|---------|:---------:|:----------:|-------|
| [`ggerganov/whisper.spm`](https://github.com/ggerganov/whisper.spm) | whisper.cpp | ❌ | ❌ (2024) | `ggml-metal` is explicitly excluded — "I can't figure out how to build it in SPM" |
| [`exPHAT/SwiftWhisper`](https://github.com/exPHAT/SwiftWhisper) | whisper.cpp | ❌ | ❌ (2024) | CPU + CoreML encoder, stale |
| [`argmaxinc/WhisperKit`](https://github.com/argmaxinc/WhisperKit) | **CoreML** | ⚠️ ANE/GPU via CoreML | ✅ | Great, but CoreML-only — some large models fail to compile on the iPhone ANE (`std::bad_alloc` / CoreML `-14`) or crash in MPSGraph |

Compiling whisper.cpp's Metal shaders inside SPM has been an [open TODO upstream for two years](https://github.com/ggerganov/whisper.spm/blob/master/Package.swift), which is why the project moved to a CMake-built **xcframework**.

**WhisperMetalKit** closes the gap: it wraps the official, Metal-enabled `whisper.xcframework` as an SPM `binaryTarget` behind a small, modern, async Swift API. You get the real GGML/Metal runtime — including models that the CoreML path can't compile — with a one-line SPM install.

## Goals

- ✅ whisper.cpp on **Metal GPU** (not CPU-only), via SPM
- ✅ Runs **GGML / GGUF** models CoreML can't (any size, including quantized `q5_0` / `q8_0`)
- ✅ Small async Swift API: load a model, feed `[Float]` 16 kHz mono, get text + segments
- ✅ Tracks upstream whisper.cpp releases (binary target → bump URL + checksum)
- ✅ iOS 16+ / macOS 13+ (visionOS / tvOS to follow)

## Status

🚧 Early development. The `whisper.xcframework` binary target and the transcription API are landing now. Not yet ready for production use.

## License

[MIT](LICENSE). whisper.cpp and ggml are also MIT-licensed.
