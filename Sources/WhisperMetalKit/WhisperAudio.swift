import Foundation
import AVFoundation

/// Helpers to produce the `[Float]` **16 kHz mono** PCM that ``WhisperModel`` expects.
public enum WhisperAudio {
    /// Whisper's required sample rate.
    public static let sampleRate: Double = 16_000

    public enum AudioError: Error, Sendable {
        case cannotOpenFile(URL)
        case conversionFailed
    }

    /// Decodes and resamples any audio file readable by AVFoundation (m4a, wav, mp3, caf, …) into
    /// 16 kHz mono `Float` samples ready for ``WhisperModel/transcribe(samples:options:)``.
    public static func samples(fromFile url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        return try samples(from: file)
    }

    static func samples(from file: AVAudioFile) throws -> [Float] {
        guard let target = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else { throw AudioError.conversionFailed }

        let source = file.processingFormat
        guard let converter = AVAudioConverter(from: source, to: target) else {
            throw AudioError.conversionFailed
        }

        // Read the whole file in chunks, feeding the converter on demand.
        let sourceChunk: AVAudioFrameCount = 16_384
        var output: [Float] = []
        var reachedEnd = false

        while !reachedEnd {
            guard let outBuffer = AVAudioPCMBuffer(
                pcmFormat: target,
                frameCapacity: AVAudioFrameCount(sampleRate) // ~1s of 16 kHz output per pass
            ) else { throw AudioError.conversionFailed }

            var conversionError: NSError?
            let status = converter.convert(to: outBuffer, error: &conversionError) { _, inputStatus in
                guard let inBuffer = AVAudioPCMBuffer(pcmFormat: source, frameCapacity: sourceChunk) else {
                    inputStatus.pointee = .noDataNow
                    return nil
                }
                do {
                    try file.read(into: inBuffer, frameCount: sourceChunk)
                } catch {
                    inputStatus.pointee = .noDataNow
                    return nil
                }
                if inBuffer.frameLength == 0 {
                    inputStatus.pointee = .endOfStream
                    return nil
                }
                inputStatus.pointee = .haveData
                return inBuffer
            }

            if let conversionError { throw conversionError }

            if let channel = outBuffer.floatChannelData, outBuffer.frameLength > 0 {
                output.append(contentsOf: UnsafeBufferPointer(start: channel[0], count: Int(outBuffer.frameLength)))
            }

            if status == .endOfStream || status == .error || outBuffer.frameLength == 0 {
                reachedEnd = true
            }
        }
        return output
    }
}
