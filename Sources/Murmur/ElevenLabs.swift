import Foundation

/// Cloud transcription with the ElevenLabs Scribe speech-to-text API.
enum ElevenLabs {
    struct APIError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static func transcribe(samples: [Float]) async throws -> String {
        let apiKey = Defaults.elevenLabsKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            throw APIError(message: "Add your ElevenLabs API key in Settings")
        }

        let wav = WAV.encode16kMono(samples)
        let boundary = "murmur-\(UUID().uuidString)"

        var request = URLRequest(url: URL(string: "https://api.elevenlabs.io/v1/speech-to-text")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func appendField(_ name: String, _ value: String) {
            body.append(ascii: "--\(boundary)\r\n")
            body.append(ascii: "Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            body.append(ascii: "\(value)\r\n")
        }
        appendField("model_id", Defaults.elevenLabsModel)
        let language = Defaults.languageCode.trimmingCharacters(in: .whitespacesAndNewlines)
        if !language.isEmpty {
            appendField("language_code", language)
        }
        body.append(ascii: "--\(boundary)\r\n")
        body.append(ascii: "Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n")
        body.append(ascii: "Content-Type: audio/wav\r\n\r\n")
        body.append(wav)
        body.append(ascii: "\r\n--\(boundary)--\r\n")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError(message: "No response from ElevenLabs")
        }
        guard http.statusCode == 200 else {
            let detail = String(data: data, encoding: .utf8) ?? ""
            throw APIError(message: "ElevenLabs \(http.statusCode): \(detail.prefix(140))")
        }

        struct TranscriptResponse: Decodable { let text: String }
        return try JSONDecoder().decode(TranscriptResponse.self, from: data).text
    }
}
