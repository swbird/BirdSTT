import AVFoundation
import Combine

final class AudioCaptureService {
    let audioChunk = PassthroughSubject<Data, Never>()
    let audioLevel = PassthroughSubject<Float, Never>()

    private let engine = AVAudioEngine()
    private let targetSampleRate: Double = 16000
    private var isRunning = false

    func start() throws {
        guard !isRunning else { return }

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        )!

        let converter = AVAudioConverter(from: inputFormat, to: targetFormat)

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }

            let level = self.calculateRMS(buffer: buffer)
            self.audioLevel.send(level)

            guard let converter = converter else { return }

            let frameCapacity = AVAudioFrameCount(
                targetSampleRate * Double(buffer.frameLength) / inputFormat.sampleRate
            )
            guard let convertedBuffer = AVAudioPCMBuffer(
                pcmFormat: targetFormat,
                frameCapacity: frameCapacity
            ) else { return }

            var error: NSError?
            let status = converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            guard status != .error, error == nil else { return }

            let pcmData = self.float32ToInt16(buffer: convertedBuffer)
            self.audioChunk.send(pcmData)
        }

        engine.prepare()
        try engine.start()
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
    }

    private func calculateRMS(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }
        let count = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<count {
            sum += channelData[i] * channelData[i]
        }
        let rms = sqrt(sum / Float(count))
        return min(rms * 5.0, 1.0)
    }

    private func float32ToInt16(buffer: AVAudioPCMBuffer) -> Data {
        guard let channelData = buffer.floatChannelData?[0] else { return Data() }
        let count = Int(buffer.frameLength)
        var int16Array = [Int16](repeating: 0, count: count)
        for i in 0..<count {
            let clamped = max(-1.0, min(1.0, channelData[i]))
            int16Array[i] = Int16(clamped * Float(Int16.max))
        }
        return int16Array.withUnsafeBufferPointer { ptr in
            Data(buffer: ptr)
        }
    }
}
