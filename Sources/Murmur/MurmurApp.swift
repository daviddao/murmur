import SwiftUI

@main
enum Entry {
    static func main() {
        let args = CommandLine.arguments
        // Hidden debug mode: `Murmur transcribe <audio-file>` runs Parakeet on a file.
        if args.count >= 3, args[1] == "transcribe" {
            transcribeCLI(path: args[2])
            return
        }
        MurmurApp.main()
    }

    private static func transcribeCLI(path: String) {
        let url = URL(fileURLWithPath: path)
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            do {
                let text = try await ParakeetTranscriber.shared.transcribeFile(
                    url,
                    version: Defaults.parakeetModel
                )
                print(text)
            } catch {
                FileHandle.standardError.write(Data("error: \(error)\n".utf8))
            }
            semaphore.signal()
        }
        semaphore.wait()
    }
}

struct MurmurApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra("Murmur", systemImage: "waveform") {
            MenuContent(state: delegate.state)
        }

        Settings {
            SettingsView(state: delegate.state)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let state = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        state.start()
    }
}
