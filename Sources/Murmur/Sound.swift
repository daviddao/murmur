import AppKit

/// Feedback sounds. Each event can use its default system sound, any other
/// system sound, a custom audio file, or nothing (Settings → Sounds).
enum Sound: String, CaseIterable, Identifiable {
    case start
    case stop
    case done
    case error

    var id: String { rawValue }

    var title: String {
        switch self {
        case .start: return "Start recording"
        case .stop: return "Stop recording"
        case .done: return "Text inserted"
        case .error: return "Error"
        }
    }

    var defaultName: String {
        switch self {
        case .start: return "Pop"
        case .stop: return "Bottle"
        case .done: return "Tink"
        case .error: return "Basso"
        }
    }

    /// UserDefaults key. Value: "" = default, "none" = silent,
    /// a system sound name, or an absolute path to an audio file.
    var settingsKey: String { "sound.\(rawValue)" }

    static let noneValue = "none"

    @MainActor
    static func play(_ sound: Sound) {
        guard Defaults.playSounds else { return }
        let choice = UserDefaults.standard.string(forKey: sound.settingsKey) ?? ""
        guard let nsSound = sound.resolve(choice) else { return }
        nsSound.volume = 0.3
        nsSound.play()
    }

    /// Plays a choice immediately, for previewing in Settings.
    @MainActor
    func preview(_ choice: String) {
        guard let nsSound = resolve(choice) else { return }
        nsSound.volume = 0.3
        nsSound.play()
    }

    private func resolve(_ choice: String) -> NSSound? {
        if choice == Self.noneValue { return nil }
        if choice.hasPrefix("/") {
            // Fall back to the default if the custom file was moved or deleted.
            return NSSound(contentsOf: URL(fileURLWithPath: choice), byReference: true)
                ?? NSSound(named: defaultName)
        }
        return NSSound(named: choice.isEmpty ? defaultName : choice)
    }

    /// Sound names from the system and the user's ~/Library/Sounds.
    static var systemSoundNames: [String] {
        let dirs = [
            URL(fileURLWithPath: "/System/Library/Sounds"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Sounds"),
        ]
        let names = dirs.flatMap { dir in
            ((try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [])
                .map { $0.deletingPathExtension().lastPathComponent }
        }
        return Array(Set(names)).sorted()
    }
}
