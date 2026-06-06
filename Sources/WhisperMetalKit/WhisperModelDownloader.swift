import Foundation

/// Downloads GGML Whisper models from Hugging Face (`ggerganov/whisper.cpp`).
///
/// Models are large one-time downloads; cache the returned file URL and reuse it.
public enum WhisperModelDownloader {

    /// A known Whisper model. `quantized` variants (`q5_0`, `q8_0`) are much smaller with a small
    /// quality cost, and are the practical choice for on-device use.
    public enum Model: Sendable {
        case tiny, base, small, medium
        case largeV3Turbo
        case largeV3TurboQuantized      // large-v3-turbo, q5_0 (~574 MB)
        case mediumQuantized            // medium, q5_0 (~514 MB)
        /// Any model by its `ggml-<name>.bin` suffix, e.g. `"large-v3"`, `"small.en"`.
        case named(String)

        /// The `ggml-<fileName>.bin` suffix on Hugging Face.
        public var fileName: String {
            switch self {
            case .tiny: return "tiny"
            case .base: return "base"
            case .small: return "small"
            case .medium: return "medium"
            case .largeV3Turbo: return "large-v3-turbo"
            case .largeV3TurboQuantized: return "large-v3-turbo-q5_0"
            case .mediumQuantized: return "medium-q5_0"
            case .named(let name): return name
            }
        }
    }

    public enum DownloadError: Error, Sendable {
        case badResponse(status: Int)
    }

    private static let repoBase = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/")!

    /// The remote URL for a model file.
    public static func remoteURL(for model: Model) -> URL {
        repoBase.appendingPathComponent("ggml-\(model.fileName).bin")
    }

    /// Downloads `model` into `directory` (created if needed) and returns the local file URL.
    /// If the file already exists it is returned without re-downloading.
    /// - Parameter progress: optional 0...1 progress callback.
    public static func download(
        _ model: Model,
        to directory: URL,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent("ggml-\(model.fileName).bin")
        if FileManager.default.fileExists(atPath: destination.path) {
            progress?(1)
            return destination
        }

        let (tempURL, response) = try await downloadWithProgress(from: remoteURL(for: model), progress: progress)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw DownloadError.badResponse(status: http.statusCode)
        }
        // Move into place (atomic-ish): remove any partial, then move.
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: tempURL, to: destination)
        return destination
    }

    private static func downloadWithProgress(
        from url: URL,
        progress: (@Sendable (Double) -> Void)?
    ) async throws -> (URL, URLResponse) {
        guard let progress else {
            return try await URLSession.shared.download(from: url)
        }
        let (bytes, response) = try await URLSession.shared.bytes(from: url)
        let expected = response.expectedContentLength
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("whispermetalkit-\(UUID().uuidString).bin")
        FileManager.default.createFile(atPath: tempURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: tempURL)
        defer { try? handle.close() }

        var received: Int64 = 0
        var buffer = Data()
        buffer.reserveCapacity(1 << 20)
        for try await byte in bytes {
            buffer.append(byte)
            if buffer.count >= (1 << 20) {
                try handle.write(contentsOf: buffer)
                received += Int64(buffer.count)
                buffer.removeAll(keepingCapacity: true)
                if expected > 0 { progress(min(1, Double(received) / Double(expected))) }
            }
        }
        if !buffer.isEmpty {
            try handle.write(contentsOf: buffer)
            received += Int64(buffer.count)
        }
        progress(1)
        return (tempURL, response)
    }
}
