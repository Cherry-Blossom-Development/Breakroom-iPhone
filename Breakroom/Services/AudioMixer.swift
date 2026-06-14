import Foundation
import AVFoundation

enum AudioMixerError: LocalizedError {
    case fileNotFound
    case invalidAudioFormat
    case processingFailed(String)
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Audio file not found"
        case .invalidAudioFormat:
            return "Invalid audio format"
        case .processingFailed(let message):
            return "Audio processing failed: \(message)"
        case .exportFailed(let message):
            return "Export failed: \(message)"
        }
    }
}

enum AudioMixer {
    // MARK: - Constants

    private static let targetSampleRate: Double = 44100
    private static let targetChannels: AVAudioChannelCount = 1
    private static let normalizationTarget: Float = 0.7

    // MARK: - Download

    /// Download a session's audio file with authentication
    static func downloadSessionAudio(sessionId: Int) async throws -> URL {
        return try await SessionsAPIService.downloadSession(sessionId: sessionId)
    }

    // MARK: - Normalization

    /// Normalize audio to peak level of 0.7 (matching Android implementation)
    /// - Parameter url: URL of the audio file to normalize
    /// - Returns: URL of the normalized audio file (WAV format)
    static func normalizeAudio(at url: URL) throws -> URL {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw AudioMixerError.fileNotFound
        }

        let audioFile = try AVAudioFile(forReading: url)
        let format = audioFile.processingFormat
        let frameCount = AVAudioFrameCount(audioFile.length)

        guard frameCount > 0 else {
            throw AudioMixerError.invalidAudioFormat
        }

        // Read all samples
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw AudioMixerError.processingFailed("Could not create buffer")
        }
        try audioFile.read(into: buffer)

        // Find peak value
        var peak: Float = 0
        if let channelData = buffer.floatChannelData {
            for channel in 0..<Int(format.channelCount) {
                for frame in 0..<Int(buffer.frameLength) {
                    let sample = abs(channelData[channel][frame])
                    if sample > peak {
                        peak = sample
                    }
                }
            }
        }

        // Calculate gain to reach target level
        let gain: Float = peak > 0 ? normalizationTarget / peak : 1.0

        // Apply gain if needed
        if abs(gain - 1.0) > 0.01 {
            if let channelData = buffer.floatChannelData {
                for channel in 0..<Int(format.channelCount) {
                    for frame in 0..<Int(buffer.frameLength) {
                        channelData[channel][frame] *= gain
                    }
                }
            }
        }

        // Write normalized audio to WAV file
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("normalized_\(UUID().uuidString).wav")

        let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: format.sampleRate,
            channels: format.channelCount,
            interleaved: false
        )!

        let outputFile = try AVAudioFile(
            forWriting: outputURL,
            settings: outputFormat.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        try outputFile.write(from: buffer)

        return outputURL
    }

    // MARK: - Mixing

    /// Mix two audio files with adjustable volumes
    /// - Parameters:
    ///   - backingURL: URL of the backing track
    ///   - backingVolume: Volume for backing track (0.0 - 1.0)
    ///   - recordingURL: URL of the recording
    ///   - recordingVolume: Volume for recording (0.0 - 1.0)
    /// - Returns: URL of the mixed audio file (WAV format)
    static func mixAudio(
        backing backingURL: URL,
        backingVolume: Float,
        recording recordingURL: URL,
        recordingVolume: Float
    ) throws -> URL {
        // Load both audio files
        let backingFile = try AVAudioFile(forReading: backingURL)
        let recordingFile = try AVAudioFile(forReading: recordingURL)

        // Determine common format (use backing track's sample rate, mono)
        let sampleRate = backingFile.processingFormat.sampleRate
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw AudioMixerError.processingFailed("Could not create output format")
        }

        // Read backing track
        let backingFrameCount = AVAudioFrameCount(backingFile.length)
        guard let backingBuffer = AVAudioPCMBuffer(pcmFormat: backingFile.processingFormat, frameCapacity: backingFrameCount) else {
            throw AudioMixerError.processingFailed("Could not create backing buffer")
        }
        try backingFile.read(into: backingBuffer)

        // Read recording
        let recordingFrameCount = AVAudioFrameCount(recordingFile.length)
        guard let recordingBuffer = AVAudioPCMBuffer(pcmFormat: recordingFile.processingFormat, frameCapacity: recordingFrameCount) else {
            throw AudioMixerError.processingFailed("Could not create recording buffer")
        }
        try recordingFile.read(into: recordingBuffer)

        // Convert both to mono if needed
        let monoBackingBuffer = try convertToMono(buffer: backingBuffer, targetSampleRate: sampleRate)
        let monoRecordingBuffer = try convertToMono(buffer: recordingBuffer, targetSampleRate: sampleRate)

        // Determine output length (use longer of the two)
        let outputFrameCount = max(monoBackingBuffer.frameLength, monoRecordingBuffer.frameLength)

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputFrameCount) else {
            throw AudioMixerError.processingFailed("Could not create output buffer")
        }
        outputBuffer.frameLength = outputFrameCount

        guard let outputData = outputBuffer.floatChannelData?[0],
              let backingData = monoBackingBuffer.floatChannelData?[0],
              let recordingData = monoRecordingBuffer.floatChannelData?[0] else {
            throw AudioMixerError.processingFailed("Could not access audio data")
        }

        // Mix samples
        for frame in 0..<Int(outputFrameCount) {
            var sample: Float = 0

            // Add backing track sample if within bounds
            if frame < Int(monoBackingBuffer.frameLength) {
                sample += backingData[frame] * backingVolume
            }

            // Add recording sample if within bounds
            if frame < Int(monoRecordingBuffer.frameLength) {
                sample += recordingData[frame] * recordingVolume
            }

            // Clamp to [-1, 1]
            outputData[frame] = max(-1.0, min(1.0, sample))
        }

        // Write output
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mashup_\(UUID().uuidString).wav")

        let outputFile = try AVAudioFile(
            forWriting: outputURL,
            settings: outputFormat.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        try outputFile.write(from: outputBuffer)

        return outputURL
    }

    // MARK: - Helpers

    /// Convert a buffer to mono at a target sample rate
    private static func convertToMono(buffer: AVAudioPCMBuffer, targetSampleRate: Double) throws -> AVAudioPCMBuffer {
        let inputFormat = buffer.format
        let inputChannels = Int(inputFormat.channelCount)
        let inputSampleRate = inputFormat.sampleRate

        // Calculate output frame count (accounting for sample rate conversion)
        let sampleRateRatio = targetSampleRate / inputSampleRate
        let outputFrameCount = AVAudioFrameCount(Double(buffer.frameLength) * sampleRateRatio)

        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw AudioMixerError.processingFailed("Could not create mono format")
        }

        // If already mono and same sample rate, return a copy
        if inputChannels == 1 && abs(inputSampleRate - targetSampleRate) < 1 {
            guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: buffer.frameLength) else {
                throw AudioMixerError.processingFailed("Could not create output buffer")
            }
            outputBuffer.frameLength = buffer.frameLength

            if let inputData = buffer.floatChannelData?[0],
               let outputData = outputBuffer.floatChannelData?[0] {
                for i in 0..<Int(buffer.frameLength) {
                    outputData[i] = inputData[i]
                }
            }
            return outputBuffer
        }

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputFrameCount) else {
            throw AudioMixerError.processingFailed("Could not create output buffer")
        }
        outputBuffer.frameLength = outputFrameCount

        guard let inputData = buffer.floatChannelData,
              let outputData = outputBuffer.floatChannelData?[0] else {
            throw AudioMixerError.processingFailed("Could not access audio data")
        }

        // Simple linear interpolation for sample rate conversion + mono mixdown
        for outputFrame in 0..<Int(outputFrameCount) {
            let inputPosition = Double(outputFrame) / sampleRateRatio
            let inputFrame = Int(inputPosition)
            let fraction = Float(inputPosition - Double(inputFrame))

            var sample: Float = 0

            // Mix all channels to mono
            for channel in 0..<inputChannels {
                let channelData = inputData[channel]

                if inputFrame < Int(buffer.frameLength) {
                    let currentSample = channelData[inputFrame]
                    let nextSample = (inputFrame + 1 < Int(buffer.frameLength)) ? channelData[inputFrame + 1] : currentSample

                    // Linear interpolation
                    sample += currentSample + (nextSample - currentSample) * fraction
                }
            }

            // Average across channels
            outputData[outputFrame] = sample / Float(inputChannels)
        }

        return outputBuffer
    }

    // MARK: - Cleanup

    /// Clean up temporary audio files
    static func cleanupTempFiles(_ urls: [URL]) {
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
