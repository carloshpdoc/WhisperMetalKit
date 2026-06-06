import XCTest
@testable import WhisperMetalKit

final class WhisperMetalKitTests: XCTestCase {
    func testVersionIsSet() {
        XCTAssertFalse(WhisperMetalKit.version.isEmpty)
    }

    func testRemoteURLForKnownModels() {
        XCTAssertEqual(
            WhisperModelDownloader.remoteURL(for: .tiny).absoluteString,
            "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin"
        )
        XCTAssertEqual(
            WhisperModelDownloader.remoteURL(for: .mediumQuantized).lastPathComponent,
            "ggml-medium-q5_0.bin"
        )
    }

    /// End-to-end smoke test of the full Metal path: download a tiny model, decode the bundled
    /// `jfk.wav` to 16 kHz mono, transcribe, and assert recognizable text comes back.
    /// Skips (rather than fails) when the model can't be fetched (e.g. offline CI).
    func testTranscribesBundledSample() async throws {
        guard let audioURL = Bundle.module.url(forResource: "jfk", withExtension: "wav") else {
            return XCTFail("Missing bundled jfk.wav resource")
        }

        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WhisperMetalKitTests", isDirectory: true)
        let modelURL: URL
        do {
            modelURL = try await WhisperModelDownloader.download(.tiny, to: cacheDir)
        } catch {
            throw XCTSkip("Could not download model (offline?): \(error)")
        }

        let samples = try WhisperAudio.samples(fromFile: audioURL)
        XCTAssertGreaterThan(samples.count, 16_000, "Expected at least ~1s of 16 kHz audio")

        let model = try WhisperModel(modelPath: modelURL)
        let result = try await model.transcribe(samples: samples, options: .init(language: "en"))

        // JFK: "...ask not what your country can do for you..."
        XCTAssertFalse(result.text.isEmpty, "Transcription was empty")
        XCTAssertTrue(
            result.text.lowercased().contains("country"),
            "Expected JFK quote, got: \(result.text)"
        )
        XCTAssertFalse(result.segments.isEmpty, "Expected at least one segment")
    }
}
