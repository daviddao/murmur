import AppKit
import ApplicationServices

/// Watches the keyboard via a CGEventTap and reports press-and-hold of the
/// configured right-hand modifier key (default: right ⌘).
///
/// While a hold is active:
///   - Esc cancels (and is swallowed so it doesn't reach the frontmost app).
///   - Any other key press cancels too, but is passed through, so regular
///     ⌘-shortcuts keep working even when they involve the right ⌘ key.
final class HotkeyMonitor {
    var onHoldBegan: () -> Void = {}
    var onHoldEnded: () -> Void = {}
    var onCancel: () -> Void = {}

    /// Set by AppState while audio is being captured.
    var isCapturing = false

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var retryTimer: Timer?
    private var holdActive = false

    func start() {
        guard tap == nil else { return }
        if installTap() { return }
        // Accessibility not granted yet — retry until it is.
        retryTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.installTap() {
                self.retryTimer?.invalidate()
                self.retryTimer = nil
            }
        }
    }

    private func installTap() -> Bool {
        guard AXIsProcessTrusted() else { return false }
        let mask: CGEventMask =
            (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(refcon).takeUnretainedValue()
                return monitor.handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)

        case .flagsChanged:
            let hotkey = Defaults.hotkey
            guard event.getIntegerValueField(.keyboardEventKeycode) == hotkey.keyCode else {
                return Unmanaged.passUnretained(event)
            }
            let down = (event.flags.rawValue & hotkey.deviceFlag) != 0
            if down, !holdActive {
                holdActive = true
                onHoldBegan()
            } else if !down, holdActive {
                holdActive = false
                onHoldEnded()
            }
            return Unmanaged.passUnretained(event)

        case .keyDown:
            guard isCapturing else { return Unmanaged.passUnretained(event) }
            if event.getIntegerValueField(.keyboardEventKeycode) == 53 { // Esc
                onCancel()
                return nil // swallow
            }
            // Another key while holding: this is a keyboard shortcut, not dictation.
            onCancel()
            return Unmanaged.passUnretained(event)

        default:
            return Unmanaged.passUnretained(event)
        }
    }
}
