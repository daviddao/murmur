import Foundation

enum EngineKind: String, CaseIterable, Identifiable {
    case parakeet
    case elevenlabs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .parakeet: return "Parakeet — local"
        case .elevenlabs: return "ElevenLabs — cloud"
        }
    }
}

enum HotkeyChoice: String, CaseIterable, Identifiable {
    case rightCommand
    case rightOption
    case rightControl

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rightCommand: return "Right ⌘"
        case .rightOption: return "Right ⌥"
        case .rightControl: return "Right ⌃"
        }
    }

    /// Virtual key code reported in flagsChanged events.
    var keyCode: Int64 {
        switch self {
        case .rightCommand: return 54
        case .rightOption: return 61
        case .rightControl: return 62
        }
    }

    /// Device-dependent CGEventFlags bit that distinguishes left/right modifiers.
    var deviceFlag: UInt64 {
        switch self {
        case .rightCommand: return 0x0000_0010 // NX_DEVICERCMDKEYMASK
        case .rightOption: return 0x0000_0040  // NX_DEVICERALTKEYMASK
        case .rightControl: return 0x0000_2000 // NX_DEVICERCTLKEYMASK
        }
    }
}

/// UserDefaults-backed settings, shared between the UI (@AppStorage) and the engine code.
enum Defaults {
    private static var store: UserDefaults { .standard }

    static var engine: EngineKind {
        EngineKind(rawValue: store.string(forKey: "engine") ?? "") ?? .parakeet
    }

    static var hotkey: HotkeyChoice {
        HotkeyChoice(rawValue: store.string(forKey: "hotkey") ?? "") ?? .rightCommand
    }

    /// "v3" (multilingual) or "v2" (English-only) Parakeet TDT variant.
    static var parakeetModel: String {
        store.string(forKey: "parakeetModel") ?? "v3"
    }

    static var elevenLabsKey: String {
        store.string(forKey: "elevenLabsKey") ?? ""
    }

    static var elevenLabsModel: String {
        store.string(forKey: "elevenLabsModel") ?? "scribe_v2"
    }

    /// Optional ISO language hint for ElevenLabs ("en", "de", ...). Empty = autodetect.
    static var languageCode: String {
        store.string(forKey: "languageCode") ?? ""
    }

    static var playSounds: Bool {
        store.object(forKey: "playSounds") as? Bool ?? true
    }
}
