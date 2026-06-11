import AppKit
import ApplicationServices
import AVFoundation
import SwiftUI

/// Central coordinator: hotkey → record → transcribe → paste, plus HUD state.
@MainActor
final class AppState: ObservableObject {
    enum Phase: Equatable {
        case idle
        case recording
        case transcribing
        case success(String)
        case error(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var levels: [Float] = AppState.flatLevels
    @Published private(set) var lastTranscript = ""
    @Published private(set) var parakeetStatus = "not loaded"
    @Published private(set) var accessibilityGranted = false
    @Published private(set) var microphoneGranted = false

    static let levelCount = 30
    private static var flatLevels: [Float] { Array(repeating: 0, count: levelCount) }

    private let hotkey = HotkeyMonitor()
    private let recorder = AudioRecorder()
    private var hud: HUDController?
    private var dismissTask: Task<Void, Never>?
    private static let minimumDuration = 0.35 // ignore accidental taps

    func start() {
        hud = HUDController(state: self)
        refreshPermissions(prompt: true)

        recorder.onLevel = { [weak self] level in
            self?.pushLevel(level)
        }
        hotkey.onHoldBegan = { [weak self] in
            MainActor.assumeIsolated { self?.beginRecording() }
        }
        hotkey.onHoldEnded = { [weak self] in
            MainActor.assumeIsolated { self?.finishRecording() }
        }
        hotkey.onCancel = { [weak self] in
            MainActor.assumeIsolated { self?.cancelRecording() }
        }
        hotkey.start()

        if Defaults.engine == .parakeet {
            warmUpParakeet()
        }
    }

    // MARK: - Permissions

    func refreshPermissions(prompt: Bool = false) {
        if prompt {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            accessibilityGranted = AXIsProcessTrustedWithOptions(options)
        } else {
            accessibilityGranted = AXIsProcessTrusted()
        }

        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        microphoneGranted = status == .authorized
        if prompt, status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                Task { @MainActor [weak self] in self?.microphoneGranted = granted }
            }
        }
    }

    // MARK: - Recording lifecycle

    private func beginRecording() {
        switch phase {
        case .recording, .transcribing: return
        default: break
        }

        refreshPermissions()
        guard microphoneGranted else {
            showError("Microphone access needed — see Settings")
            return
        }

        do {
            try recorder.start()
        } catch {
            showError(error.localizedDescription)
            return
        }

        dismissTask?.cancel()
        hotkey.isCapturing = true
        levels = Self.flatLevels
        phase = .recording
        hud?.show()
        Sound.play(.start)
    }

    private func finishRecording() {
        guard phase == .recording else { return }
        hotkey.isCapturing = false
        let samples = recorder.stop()

        let duration = Double(samples.count) / AudioRecorder.sampleRate
        guard duration >= Self.minimumDuration else {
            phase = .idle
            hud?.hide()
            return
        }

        phase = .transcribing
        Sound.play(.stop)

        let engine = Defaults.engine
        let parakeetVersion = Defaults.parakeetModel
        Task { [weak self] in
            do {
                let raw: String
                switch engine {
                case .parakeet:
                    raw = try await ParakeetTranscriber.shared.transcribe(samples, version: parakeetVersion)
                case .elevenlabs:
                    raw = try await ElevenLabs.transcribe(samples: samples)
                }
                self?.handleResult(raw.trimmingCharacters(in: .whitespacesAndNewlines))
            } catch {
                self?.showError(error.localizedDescription)
            }
            self?.syncParakeetStatus()
        }
    }

    private func cancelRecording() {
        guard phase == .recording else { return }
        hotkey.isCapturing = false
        recorder.cancel()
        phase = .idle
        hud?.hide()
    }

    private func handleResult(_ text: String) {
        guard phase == .transcribing else { return }
        guard !text.isEmpty else {
            showError("No speech detected")
            return
        }
        lastTranscript = text
        TextInserter.paste(text)
        Sound.play(.done)
        phase = .success(text)
        scheduleDismiss(after: 1.6)
    }

    private func showError(_ message: String) {
        hotkey.isCapturing = false
        if recorder.isRunning { recorder.cancel() }
        phase = .error(message)
        hud?.show()
        Sound.play(.error)
        scheduleDismiss(after: 2.6)
    }

    private func scheduleDismiss(after seconds: Double) {
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, let self else { return }
            switch self.phase {
            case .success, .error:
                self.phase = .idle
                self.hud?.hide()
            default:
                break
            }
        }
    }

    private func pushLevel(_ level: Float) {
        guard phase == .recording else { return }
        var next = levels
        next.removeFirst()
        next.append(level)
        levels = next
    }

    // MARK: - Parakeet warm-up

    func warmUpParakeet() {
        parakeetStatus = "preparing model…"
        let version = Defaults.parakeetModel
        Task { [weak self] in
            do {
                try await ParakeetTranscriber.shared.prepare(version: version)
            } catch {
                // status reflected below
            }
            self?.syncParakeetStatus()
        }
    }

    private func syncParakeetStatus() {
        Task { [weak self] in
            let state = await ParakeetTranscriber.shared.state
            self?.parakeetStatus = state.label
        }
    }
}
