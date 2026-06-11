import AppKit

enum Sound: String {
    case start = "Pop"
    case stop = "Bottle"
    case done = "Tink"
    case error = "Basso"

    @MainActor
    static func play(_ sound: Sound) {
        guard Defaults.playSounds else { return }
        guard let nsSound = NSSound(named: sound.rawValue) else { return }
        nsSound.volume = 0.3
        nsSound.play()
    }
}
