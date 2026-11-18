import AppKit
import UniformTypeIdentifiers
import SwiftUI

/// One picker per feedback sound: default, none, a system sound, or a custom file.
struct SoundSettingsSection: View {
    var body: some View {
        Section {
            ForEach(Sound.allCases) { sound in
                SoundRow(sound: sound)
            }
        } header: {
            Text("Sounds")
        } footer: {
            Text("Pick a system sound or choose your own audio file (.aiff, .wav, .mp3, .m4a). Sounds play only when Play sounds is on.")
        }
    }
}

private struct SoundRow: View {
    let sound: Sound
    @AppStorage private var choice: String

    private static let chooseFileTag = "__choose_file__"
    private let systemNames = Sound.systemSoundNames

    init(sound: Sound) {
        self.sound = sound
        _choice = AppStorage(wrappedValue: "", sound.settingsKey)
    }

    var body: some View {
        Picker(sound.title, selection: $choice) {
            Text("Default (\(sound.defaultName))").tag("")
            Text("None").tag(Sound.noneValue)
            Divider()
            ForEach(systemNames.filter { $0 != sound.defaultName }, id: \.self) { name in
                Text(name).tag(name)
            }
            Divider()
            if choice.hasPrefix("/") {
                Text(URL(fileURLWithPath: choice).lastPathComponent).tag(choice)
            }
            Text("Choose file…").tag(Self.chooseFileTag)
        }
        .onChange(of: choice) { oldValue, newValue in
            if newValue == Self.chooseFileTag {
                choice = pickFile() ?? oldValue
            }
            if choice != Self.chooseFileTag {
                sound.preview(choice)
            }
        }
    }

    private func pickFile() -> String? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a sound for “\(sound.title)”"
        return panel.runModal() == .OK ? panel.url?.path : nil
    }
}
