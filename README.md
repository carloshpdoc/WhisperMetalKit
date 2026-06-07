# WhisperMetalKit

On-device speech-to-text for Apple platforms, powered by [whisper.cpp](https://github.com/ggml-org/whisper.cpp) with **Metal GPU acceleration**, distributed via the **Swift Package Manager**.

```swift
.package(url: "https://github.com/carloshpdoc/WhisperMetalKit.git", from: "0.1.0")
```

## Why

This started as a real problem in a shipping app: `large-v3-turbo` ran great on macOS via
[WhisperKit](https://github.com/argmaxinc/WhisperKit) (CoreML), but on iPhone it **wouldn't run at all**:
the Apple Neural Engine couldn't compile the encoder (`std::bad_alloc` → CoreML **error -14**), and forcing
the GPU compute units crashed the process inside MetalPerformanceShadersGraph (an **uncatchable abort**).
The model was fine; CoreML was hitting hardware/compiler limits on the phone.

whisper.cpp has a different runtime, **GGML with a Metal backend**, that never touches CoreML, the ANE
compiler, or MPSGraph, so those failure modes simply don't exist. Same Whisper weights, same iPhone, the
model just runs (in our case **16.8 s of audio → ~1.1 s** on an A19 Pro). The catch is the Swift packaging:

| Option | Runtime | Metal | Swift API | Maintained | Via SPM |
|--------|---------|:-----:|:---------:|:----------:|:-------:|
| [whisper.cpp official](https://github.com/ggml-org/whisper.cpp/releases) `xcframework` | GGML | ✅ | ❌ raw C | ✅ | ⚠️ zip asset, not a package |
| [`ggerganov/whisper.spm`](https://github.com/ggerganov/whisper.spm/blob/master/Package.swift) | GGML | ❌ Metal excluded (2-yr TODO) | C | ❌ (2024) | ✅ |
| [`exPHAT/SwiftWhisper`](https://github.com/exPHAT/SwiftWhisper) | GGML | ❌ CPU + CoreML encoder | ✅ | ❌ (2024) | ✅ |
| [`argmaxinc/WhisperKit`](https://github.com/argmaxinc/WhisperKit) | **CoreML** | via CoreML (ANE/GPU) | ✅ | ✅ | ✅ |
| **WhisperMetalKit** | **GGML** | ✅ | ✅ async | ✅ | ✅ one line |

So this package is **not** "the only Metal whisper.cpp build". whisper.cpp itself now publishes a
Metal-enabled `whisper.xcframework` on its releases. What's missing is a **maintained Swift package that
exposes that GGML/Metal runtime behind a modern API**: the upstream xcframework is raw C, and the existing
SPM wrappers are stale and CPU-only. WhisperKit gives you the lovely API, but via CoreML, i.e. the path
that failed above.

**WhisperMetalKit** fills exactly that slot: it wraps the Metal `whisper.xcframework` as an SPM
`binaryTarget` and adds a small, modern, async Swift API (plus audio resampling and a model downloader), so
you can use whisper.cpp's GGML/Metal runtime as easily as WhisperKit, and run models CoreML can't compile
on-device.

> **WhisperKit vs WhisperMetalKit:** use WhisperKit when CoreML/ANE works for your model and device (often
> excellent, and it uses the ANE). Reach for WhisperMetalKit when you want the GGML/Metal runtime: larger
> or quantized models that CoreML can't compile on the phone, GGUF support, or to dodge the `-14` / MPSGraph
> failures above.

## Goals

- ✅ whisper.cpp on **Metal GPU** (not CPU-only), via SPM
- ✅ Runs **GGML / GGUF** models CoreML can't (any size, including quantized `q5_0` / `q8_0`)
- ✅ Small async Swift API: load a model, feed `[Float]` 16 kHz mono, get text + segments
- ✅ Tracks upstream whisper.cpp releases (binary target → bump URL + checksum)
- ✅ iOS 16+ / macOS 13+ (visionOS / tvOS to follow)

## Usage

```swift
import WhisperMetalKit

// 1. Get a model (one-time download; cache the URL). Quantized variants are smaller.
let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
let modelURL = try await WhisperModelDownloader.download(.mediumQuantized, to: cache)

// 2. Load it once (runs on the Metal GPU by default).
let model = try WhisperModel(modelPath: modelURL)

// 3. Transcribe. Feed 16 kHz mono Float samples, or decode a file with WhisperAudio.
let samples = try WhisperAudio.samples(fromFile: recordingURL)   // m4a, wav, mp3, caf…
let result = try await model.transcribe(samples: samples, options: .init(language: "pt"))

print(result.text)
for segment in result.segments {
    print("[\(segment.start)s-\(segment.end)s] \(segment.text)")
}
```

Pass `language: nil` to auto-detect, or `translate: true` to translate to English.

## Status

Working: Metal GPU transcription verified end-to-end (model load → decode → segments). The
`whisper.xcframework` ships all Apple slices (iOS device + sim, macOS, visionOS, tvOS). Early days;
API may still change before 1.0.

## License

[Apache License 2.0](LICENSE). whisper.cpp and ggml are MIT-licensed (compatible).
