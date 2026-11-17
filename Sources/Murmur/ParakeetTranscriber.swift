import Foundation
import FluidAudio

/// On-device transcription with NVIDIA Parakeet TDT (CoreML, via FluidAudio).
/// The model (~500 MB) is downloaded from Hugging Face on first use and cached.
///
/// Optional custom vocabulary boosting: when the user lists terms in Settings,
/// a small CTC model (~100 MB) is loaded alongside and the transcript is
/// rescored so names and jargon come out spelled the user's way.
actor ParakeetTranscriber {
    static let shared = ParakeetTranscriber()

    enum ModelState: Equatable {
        case cold
        case loading
        case ready(version: String, vocabularyTerms: Int)
        case failed(String)

        var label: String {
            switch self {
            case .cold: return "not loaded"
            case .loading: return "preparing model…"
            case .ready(let v, let terms):
                return terms > 0 ? "ready (\(v), \(terms) vocab terms)" : "ready (\(v))"
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

    // MARK: - Vocabulary boosting

    private var ctcModels: CtcModels?
    private var boostingSession: VocabularyBoostingSession?
    private var loadedVocabulary: String?

    /// The default rescue pass can swap an unrelated word for a term on audio
    /// evidence alone (e.g. "Tani" → "Supportman"). Dictation should never do
    /// that, so require the misheard word to look a bit like the term.
    private static let rescorerConfig = VocabularyRescorer.Config(
        spotterRescueMinSimilarity: 0.30,
        spotterRescueMultiWordMinSimilarity: 0.50
    )

    /// Stricter than FluidAudio's 0.52 so near names don't swap
    /// ("Oscar" → "Orca" at 0.6). Misheard forms that look very different
    /// belong in the term's aliases instead.
    private static let minSimilarity: Float = 0.65

    private var vocabularyEntries: [VocabularyList.Entry] = []

    func prepare(version: String, vocabulary: String = Defaults.customVocabulary) async throws {
        try await prepareAsr(version: version)
        await prepareVocabulary(vocabulary)
        state = .ready(version: version, vocabularyTerms: boostingSession?.vocabulary.terms.count ?? 0)
    }

    private func prepareAsr(version: String) async throws {
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
        } catch {
            state = .failed(error.localizedDescription)
            throw error
        }
    }

    /// Builds (or clears) the boosting session when the vocabulary text changed.
    /// Failures are absorbed: boosting must never break plain transcription.
    private func prepareVocabulary(_ text: String) async {
        if loadedVocabulary == text { return }
        let terms = VocabularyList.parse(text)
        guard !terms.isEmpty else {
            boostingSession = nil
            vocabularyEntries = []
            loadedVocabulary = text
            return
        }
        do {
            if ctcModels == nil {
                ctcModels = try await CtcModels.downloadAndLoad(variant: .ctc110m)
            }
            guard let ctcModels else { return }
            let context = CustomVocabularyContext(
                terms: terms.map {
                    CustomVocabularyTerm(text: $0.text, aliases: $0.aliases.isEmpty ? nil : $0.aliases)
                },
                minSimilarity: Self.minSimilarity
            )
            vocabularyEntries = terms
            boostingSession = try await VocabularyBoostingSession(
                vocabulary: context,
                ctcModels: ctcModels,
                config: Self.rescorerConfig
            )
            loadedVocabulary = text
        } catch {
            boostingSession = nil
            vocabularyEntries = []
            loadedVocabulary = nil
        }
    }

    // MARK: - Transcription

    func transcribe(_ samples: [Float], version: String) async throws -> String {
        try await prepare(version: version)
        guard let manager else { throw TranscriberError.notReady }
        var decoderState = TdtDecoderState.make(decoderLayers: await manager.decoderLayerCount)
        let result = try await manager.transcribe(samples, decoderState: &decoderState)
        return await boost(result, samples: samples)
    }

    func transcribeFile(_ url: URL, version: String) async throws -> String {
        let samples = try AudioConverter().resampleAudioFile(url)
        return try await transcribe(samples, version: version)
    }

    private func boost(_ result: ASRResult, samples: [Float]) async -> String {
        guard let boostingSession else { return result.text }
        let output = await boostingSession.rescore(
            text: result.text,
            tokenTimings: result.tokenTimings ?? [],
            audioSamples: samples
        )
        return VocabularyList.applyCasing(output?.text ?? result.text, entries: vocabularyEntries)
    }
}

/// Parses the Settings vocabulary box: one term per line, optional aliases
/// after "=" separated by commas, e.g. `Supportman = support man, supper man`.
/// Blank lines and lines starting with `#` are ignored.
enum VocabularyList {
    struct Entry: Equatable {
        let text: String
        let aliases: [String]
    }

    static func parse(_ text: String) -> [Entry] {
        text.split(whereSeparator: \.isNewline).compactMap { rawLine in
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { return nil }
            let parts = line.split(separator: "=", maxSplits: 1)
            let term = parts[0].trimmingCharacters(in: .whitespaces)
            guard !term.isEmpty else { return nil }
            let aliases = parts.count > 1
                ? parts[1].split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                : []
            return Entry(text: term, aliases: aliases)
        }
    }

    /// The rescorer leaves words that already match a term apart from case
    /// ("supportman"), so restore the user's spelling for whole-word matches.
    static func applyCasing(_ text: String, entries: [Entry]) -> String {
        // All-lowercase terms ("fork") carry no casing to restore, and forcing
        // them would lowercase a capital at the start of a sentence.
        entries.filter { $0.text != $0.text.lowercased() }.reduce(text) { result, entry in
            let pattern = "(?<![\\p{L}\\p{N}])" + NSRegularExpression.escapedPattern(for: entry.text) + "(?![\\p{L}\\p{N}])"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
                return result
            }
            let range = NSRange(result.startIndex..., in: result)
            let template = NSRegularExpression.escapedTemplate(for: entry.text)
            return regex.stringByReplacingMatches(in: result, range: range, withTemplate: template)
        }
    }
}
