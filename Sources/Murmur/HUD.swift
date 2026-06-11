import AppKit
import SwiftUI

/// A borderless, non-activating, click-through panel that floats above
/// everything at the bottom-center of the screen — the recording HUD.
@MainActor
final class HUDController {
    private let panel: NSPanel

    init(state: AppState) {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 110),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: HUDView(state: state))
        panel.alphaValue = 0
    }

    func show() {
        position()
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            panel.animator().alphaValue = 0
        }, completionHandler: { [panel] in
            panel.orderOut(nil)
        })
    }

    private func position() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: frame.midX - size.width / 2, y: frame.minY + 48))
    }
}

// MARK: - SwiftUI content

struct HUDView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack {
            Spacer()
            content
                .padding(.horizontal, 20)
                .frame(height: 40)
                .background(Capsule().fill(Color.black.opacity(0.84)))
                .background(Capsule().fill(.ultraThinMaterial))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
                .shadow(color: .black.opacity(0.35), radius: 16, y: 5)
                .animation(.spring(response: 0.3, dampingFraction: 0.85), value: state.phase)
        }
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var content: some View {
        switch state.phase {
        case .idle:
            Color.clear.frame(width: 60)

        case .recording:
            HStack(spacing: 10) {
                PulsingDot()
                WaveformView(levels: state.levels)
            }

        case .transcribing:
            HStack(spacing: 9) {
                ThinkingDots()
                Text("transcribing")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
            }

        case .success(let text):
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.green)
                Text(text)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 400)
            }

        case .error(let message):
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.yellow)
                Text(message)
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(2)
                    .frame(maxWidth: 420)
            }
        }
    }
}

struct WaveformView: View {
    let levels: [Float]

    var body: some View {
        HStack(spacing: 2.5) {
            ForEach(levels.indices, id: \.self) { index in
                Capsule()
                    .fill(Color.white.opacity(0.92))
                    .frame(width: 2.5, height: CGFloat(4 + levels[index] * 20))
            }
        }
        .frame(height: 26)
        .animation(.easeOut(duration: 0.09), value: levels)
    }
}

struct PulsingDot: View {
    @State private var pulsing = false

    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 7, height: 7)
            .opacity(pulsing ? 0.35 : 1)
            .animation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true), value: pulsing)
            .onAppear { pulsing = true }
    }
}

struct ThinkingDots: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: 5, height: 5)
                    .scaleEffect(animating ? 1 : 0.5)
                    .opacity(animating ? 1 : 0.35)
                    .animation(
                        .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.16),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
    }
}
