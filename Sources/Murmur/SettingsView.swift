import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var state: AppState

    @AppStorage("engine") private var engine = EngineKind.parakeet.rawValue
    @AppStorage("hotkey") private var hotkey = HotkeyChoice.rightCommand.rawValue
    @AppStorage("parakeetModel") private var parakeetModel = "v3"
    @AppStorage("elevenLabsKey") private var elevenLabsKey = ""
    @AppStorage("elevenLabsModel") private var elevenLabsModel = "scribe_v2"
    @AppStorage("languageCode") private var languageCode = ""
    @AppStorage("playSounds") private var playSounds = true
    @AppStorage("customVocabulary") private var customVocabulary = ""
    @State private var vocabularyReload: Task<Void, Never>?

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    private let permissionTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            Section {
                Picker("Hold to dictate", selection: $hotkey) {
                    ForEach(HotkeyChoice.allCases) { choice in
                        Text(choice.title).tag(choice.rawValue)
                    }
                }
                Picker("Engine", selection: $engine) {
                    ForEach(EngineKind.allCases) { kind in
                        Text(kind.title).tag(kind.rawValue)
                    }
                }
                .onChange(of: engine) { _, newValue in
                    if newValue == EngineKind.parakeet.rawValue {
                        state.warmUpParakeet()
                    }
                }
                Toggle("Play sounds", isOn: $playSounds)
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            if enabled {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            } header: {
                Text("General")
            } footer: {
                Text("Hold the key, speak, release — the text is typed into the active app. Press Esc while recording to cancel.")
            }

            Section {
                Picker("Model", selection: $parakeetModel) {
                    Text("v3 · multilingual (25 languages)").tag("v3")
                    Text("v2 · English only (best accuracy)").tag("v2")
                }
                .onChange(of: parakeetModel) { _, _ in
                    if engine == EngineKind.parakeet.rawValue {
                        state.warmUpParakeet()
                    }
                }
                LabeledContent("Status", value: state.parakeetStatus)
            } header: {
                Text("Parakeet — on-device")
            } footer: {
                Text("Runs fully offline via Core ML (NVIDIA Parakeet TDT 0.6B). The first run downloads the model from Hugging Face and caches it.")
            }

            Section {
                TextEditor(text: $customVocabulary)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 110)
                    .onChange(of: customVocabulary) { _, _ in
                        vocabularyChanged()
                    }
            } header: {
                Text("Custom vocabulary")
            } footer: {
                Text("One name or term per line, e.g. Supportman. Add misheard versions after =, e.g. Supportman = support man, supper man. Parakeet only; the first term downloads a small extra model (~100 MB).")
            }

            Section {
                SecureField("API key", text: $elevenLabsKey, prompt: Text("xi-…"))
                Picker("Model", selection: $elevenLabsModel) {
                    Text("Scribe v2").tag("scribe_v2")
                    Text("Scribe v1").tag("scribe_v1")
                }
                TextField("Language hint", text: $languageCode, prompt: Text("en, de, … (optional)"))
            } header: {
                Text("ElevenLabs — cloud")
            }

            Section("Permissions") {
                permissionRow(
                    "Microphone",
                    granted: state.microphoneGranted,
                    pane: "Privacy_Microphone"
                )
                permissionRow(
                    "Accessibility",
                    granted: state.accessibilityGranted,
                    pane: "Privacy_Accessibility"
                )
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 620)
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
            state.refreshPermissions()
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
        .onReceive(permissionTimer) { _ in
            state.refreshPermissions()
        }
    }

    /// Rebuilds the boosting session shortly after the user stops typing.
    private func vocabularyChanged() {
        vocabularyReload?.cancel()
        vocabularyReload = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled, engine == EngineKind.parakeet.rawValue else { return }
            state.warmUpParakeet()
        }
    }

    private func permissionRow(_ name: String, granted: Bool, pane: String) -> some View {
        LabeledContent(name) {
            HStack(spacing: 10) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(granted ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(granted ? "Granted" : "Not granted")
                        .foregroundStyle(.secondary)
                }
                if !granted {
                    Button("Open System Settings…") {
                        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")!
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }
}
