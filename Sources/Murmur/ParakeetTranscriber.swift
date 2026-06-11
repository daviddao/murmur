import Foundation
import FluidAudio

/// On-device transcription with NVIDIA Parakeet TDT (CoreML, via FluidAudio).
/// The model (~1 GB) is downloaded from Hugging Face on first use and cached.
actor ParakeetTranscriber {
    static let shared = ParakeetTranscriber()

    enum ModelState: Equatable {
        case cold
        case loading
        case ready(version: String)
        case failed(String)

        var label: String {
            switch self {
            case .cold: return "not loaded"
            case .loading: return "preparing model…"
            case .ready(let v): return "ready (\(v))"
            case .failed(let message): return "failed — \(message)"
            }
        }
    }

    enum TranscriberError: LocalizedError {
        case notReady
        var errorDescription: String? { "Parakeet model is not loaded yet." }
    }

    private(set) var state: ModelState = .cold
    private var manager: AsrManager?
    private var loadedVersion: String?

    func prepare(version: String) async throws {
        if loadedVersion == version, manager != nil { return }
        state = .loading
        manager = nil
        loadedVersion = nil
        do {
            let modelVersion: AsrModelVersion = version == "v2" ? .v2 : .v3
            let models = try await AsrModels.downloadAndLoad(version: modelVersion)
            let asr = AsrManager(config: .default)
            try await asr.loadModels(models)
            manager = asr
            loadedVersion = version
            state = .ready(version: version)
        } catch {
            state = .failed(error.localizedDescription)
            throw error
        }
    }

    func transcribe(_ samples: [Float], version: String) async throws -> String {
        try await prepare(version: version)
        guard let manager else { throw TranscriberError.notReady }
        var decoderState = TdtDecoderState.make()
        let result = try await manager.transcribe(samples, decoderState: &decoderState)
        return result.text
    }

    func transcribeFile(_ url: URL, version: String) async throws -> String {
        try await prepare(version: version)
        guard let manager else { throw TranscriberError.notReady }
        var decoderState = TdtDecoderState.make()
        let result = try await manager.transcribe(url, decoderState: &decoderState)
        return result.text
    }
}
