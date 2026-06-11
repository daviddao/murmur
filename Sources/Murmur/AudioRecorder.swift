import AVFoundation

/// Captures microphone audio and accumulates 16 kHz mono Float32 samples —
/// exactly what both Parakeet (CoreML) and a WAV upload need.
final class AudioRecorder {
    static let sampleRate = 16_000.0

    enum RecorderError: LocalizedError {
        case noInputDevice
        case formatSetup

        var errorDescription: String? {
            switch self {
            case .noInputDevice: return "No microphone input device found."
            case .formatSetup: return "Could not configure the audio converter."
            }
        }
    }

    /// Called on the main queue with a 0...1 loudness level for the HUD waveform.
    var onLevel: ((Float) -> Void)?

    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private let lock = NSLock()
    private var samples: [Float] = []
    private(set) var isRunning = false

    func start() throws {
        guard !isRunning else { return }
        lock.lock()
        samples.removeAll(keepingCapacity: true)
        lock.unlock()

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw RecorderError.noInputDevice
        }
        guard
            let target = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: Self.sampleRate,
                channels: 1,
                interleaved: false
            ),
            let converter = AVAudioConverter(from: inputFormat, to: target)
        else { throw RecorderError.formatSetup }
        self.converter = converter

        input.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { [weak self] pcm, _ in
            self?.consume(pcm, target: target)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw error
        }
        isRunning = true
    }

    /// Stops capture and returns everything recorded as 16 kHz mono samples.
    @discardableResult
    func stop() -> [Float] {
        guard isRunning else { return [] }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
        converter = nil
        lock.lock()
        defer { lock.unlock() }
        return samples
    }

    func cancel() {
        stop()
    }

    private func consume(_ pcm: AVAudioPCMBuffer, target: AVAudioFormat) {
        guard let converter else { return }

        // Loudness for the waveform HUD.
        if let channel = pcm.floatChannelData?[0] {
            let n = Int(pcm.frameLength)
            var acc: Float = 0
            for i in 0..<n { acc += channel[i] * channel[i] }
            let rms = n > 0 ? sqrtf(acc / Float(n)) : 0
            let level = min(1.0, powf(rms, 0.5) * 1.9)
            DispatchQueue.main.async { [weak self] in self?.onLevel?(level) }
        }

        // Resample to 16 kHz mono.
        let ratio = target.sampleRate / pcm.format.sampleRate
        let capacity = AVAudioFrameCount(Double(pcm.frameLength) * ratio) + 64
        guard let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }
        var fed = false
        var conversionError: NSError?
        let status = converter.convert(to: out, error: &conversionError) { _, outStatus in
            if fed {
                outStatus.pointee = .noDataNow
                return nil
            }
            fed = true
            outStatus.pointee = .haveData
            return pcm
        }
        guard status != .error, let data = out.floatChannelData?[0] else { return }
        let count = Int(out.frameLength)
        guard count > 0 else { return }
        lock.lock()
        samples.append(contentsOf: UnsafeBufferPointer(start: data, count: count))
        lock.unlock()
    }
}
