import Foundation

enum WAV {
    /// Encodes 16 kHz mono Float32 samples as a 16-bit PCM WAV file.
    static func encode16kMono(_ samples: [Float]) -> Data {
        let sampleRate: UInt32 = 16_000
        var pcm = Data(capacity: samples.count * 2)
        for sample in samples {
            let clamped = max(-1.0, min(1.0, sample))
            var value = Int16(clamped * 32_767).littleEndian
            withUnsafeBytes(of: &value) { pcm.append(contentsOf: $0) }
        }

        var data = Data(capacity: pcm.count + 44)
        data.append(ascii: "RIFF")
        data.append(uint32: UInt32(36 + pcm.count))
        data.append(ascii: "WAVE")
        data.append(ascii: "fmt ")
        data.append(uint32: 16)                 // fmt chunk size
        data.append(uint16: 1)                  // PCM
        data.append(uint16: 1)                  // mono
        data.append(uint32: sampleRate)
        data.append(uint32: sampleRate * 2)     // byte rate
        data.append(uint16: 2)                  // block align
        data.append(uint16: 16)                 // bits per sample
        data.append(ascii: "data")
        data.append(uint32: UInt32(pcm.count))
        data.append(pcm)
        return data
    }
}

extension Data {
    mutating func append(ascii string: String) {
        append(contentsOf: string.utf8)
    }

    mutating func append(uint32 value: UInt32) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }

    mutating func append(uint16 value: UInt16) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }
}
