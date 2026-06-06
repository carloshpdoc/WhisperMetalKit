import Foundation
import whisper

/// Options controlling a single transcription.
public struct WhisperOptions: Sendable {
    /// ISO language code (e.g. `"en"`, `"pt"`). `nil` auto-detects the spoken language.
    public var language: String?
    /// Translate the result to English instead of transcribing in the spoken language.
    public var translate: Bool
    /// CPU threads to use. `nil` picks a sensible default for the device.
    public var threadCount: Int?
    /// An optional initial prompt to bias decoding (e.g. domain vocabulary / prior context).
    public var initialPrompt: String?

    public init(
        language: String? = nil,
        translate: Bool = false,
        threadCount: Int? = nil,
        initialPrompt: String? = nil
    ) {
        self.language = language
        self.translate = translate
        self.threadCount = threadCount
        self.initialPrompt = initialPrompt
    }
}

/// A single transcribed segment with its time range.
public struct WhisperSegment: Sendable, Equatable {
    public let text: String
    public let start: TimeInterval
    public let end: TimeInterval
}

/// The result of a transcription.
public struct WhisperResult: Sendable, Equatable {
    /// Full text (all segments joined and trimmed).
    public let text: String
    public let segments: [WhisperSegment]
}

public enum WhisperError: Error, Sendable {
    case modelLoadFailed(path: String)
    case emptyAudio
    case transcriptionFailed(code: Int32)
}

/// On-device Whisper model backed by whisper.cpp (GGML) with Metal GPU acceleration.
///
/// `WhisperModel` is an `actor`: whisper.cpp requires single-threaded access to a context, and the
/// actor enforces exactly that. Load a model once and reuse it across recordings.
///
/// ```swift
/// let model = try await WhisperModel(modelPath: url)            // ggml-*.bin
/// let result = try await model.transcribe(samples: pcm16kMono)  // [Float], 16 kHz mono
/// print(result.text)
/// ```
public actor WhisperModel {
    private let context: OpaquePointer

    /// Loads a GGML/GGUF Whisper model from disk.
    /// - Parameters:
    ///   - modelPath: A `ggml-*.bin` / `*.gguf` Whisper model file.
    ///   - useGPU: Run on the Metal GPU (default) or CPU only.
    public init(modelPath: URL, useGPU: Bool = true) throws {
        var cparams = whisper_context_default_params()
        cparams.use_gpu = useGPU
        cparams.flash_attn = useGPU
        guard let ctx = whisper_init_from_file_with_params(modelPath.path, cparams) else {
            throw WhisperError.modelLoadFailed(path: modelPath.path)
        }
        self.context = ctx
    }

    deinit {
        whisper_free(context)
    }

    /// Transcribes 16 kHz mono PCM samples.
    /// - Parameters:
    ///   - samples: Audio as `[Float]` in `[-1, 1]`, **16 kHz mono**. See ``WhisperAudio``.
    ///   - options: Language, translation and decoding options.
    public func transcribe(samples: [Float], options: WhisperOptions = .init()) throws -> WhisperResult {
        guard !samples.isEmpty else { throw WhisperError.emptyAudio }

        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.print_progress = false
        params.print_realtime = false
        params.print_timestamps = false
        params.translate = options.translate
        params.n_threads = Int32(options.threadCount ?? Self.defaultThreadCount)
        params.no_context = true

        let language = options.language ?? "auto"
        if options.language == nil { params.detect_language = true }

        // `language` (and `initial_prompt`) are borrowed by `whisper_full` for the duration of the
        // call, so the C strings must outlive it — keep them alive via nested `withCString` closures.
        let code = language.withCString { langPtr -> Int32 in
            params.language = langPtr
            return Self.withOptionalCString(options.initialPrompt) { promptPtr in
                params.initial_prompt = promptPtr
                return samples.withUnsafeBufferPointer { buf in
                    whisper_full(context, params, buf.baseAddress, Int32(buf.count))
                }
            }
        }
        guard code == 0 else { throw WhisperError.transcriptionFailed(code: code) }

        var segments: [WhisperSegment] = []
        let n = whisper_full_n_segments(context)
        segments.reserveCapacity(Int(n))
        for i in 0..<n {
            let text = String(cString: whisper_full_get_segment_text(context, i))
            // whisper timestamps are in centiseconds (10 ms units).
            let start = TimeInterval(whisper_full_get_segment_t0(context, i)) / 100.0
            let end = TimeInterval(whisper_full_get_segment_t1(context, i)) / 100.0
            segments.append(WhisperSegment(text: text, start: start, end: end))
        }
        let fullText = segments.map(\.text).joined().trimmingCharacters(in: .whitespacesAndNewlines)
        return WhisperResult(text: fullText, segments: segments)
    }

    // MARK: - Helpers

    private static var defaultThreadCount: Int {
        max(1, min(8, ProcessInfo.processInfo.activeProcessorCount - 2))
    }

    private static func withOptionalCString<R>(
        _ string: String?,
        _ body: (UnsafePointer<CChar>?) -> R
    ) -> R {
        guard let string else { return body(nil) }
        return string.withCString { body($0) }
    }
}
