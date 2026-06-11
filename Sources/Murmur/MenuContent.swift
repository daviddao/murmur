import AppKit
import SwiftUI

struct MenuContent: View {
    @ObservedObject var state: AppState
    @AppStorage("engine") private var engine = EngineKind.parakeet.rawValue
    @AppStorage("hotkey") private var hotkey = HotkeyChoice.rightCommand.rawValue

    var body: some View {
        Text("Hold \(hotkeyTitle) to dictate")
        if engine == EngineKind.parakeet.rawValue {
            Text("Parakeet: \(state.parakeetStatus)")
        }

        Divider()

        Picker("Engine", selection: $engine) {
            ForEach(EngineKind.allCases) { kind in
                Text(kind.title).tag(kind.rawValue)
            }
        }
        .pickerStyle(.inline)
        .onChange(of: engine) { _, newValue in
            if newValue == EngineKind.parakeet.rawValue {
                state.warmUpParakeet()
            }
        }

        if !state.lastTranscript.isEmpty {
            Divider()
            Button("Copy Last Transcription") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(state.lastTranscript, forType: .string)
            }
        }

        Divider()

        SettingsLink {
            Text("Settings…")
        }
        .keyboardShortcut(",")

        Button("Quit Murmur") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private var hotkeyTitle: String {
        (HotkeyChoice(rawValue: hotkey) ?? .rightCommand).title
    }
}
